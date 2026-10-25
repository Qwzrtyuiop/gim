extends RefCounted

const SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_cancel_and_layout(host)
	await _test_stale_confirmation(host)
	await _test_confirmed_departure(host)
	PlayerState.reset()
	print("PASS: passenger confirmation cancellation/Escape isolation, background gating, structured trip layout, correct confirmed ride and one-time departure")


static func _setup() -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "noon"
	PlayerState.current_stage_type = "short-noon-chill"
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 5
	PlayerState.gas = 50.0
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE, true)
	var short_rider := PlayerState.get_character_by_id("generic_guy")
	short_rider.merge({
		"active_distance": "short",
		"stage_traffic": "chill",
		"stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_NONE,
		"special_stage_id": "",
	}, true)
	var long_rider := PlayerState.get_character_by_id("generic_student")
	long_rider.merge({
		"active_distance": "long",
		"stage_traffic": "speeders",
		"stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_URGENT,
		"special_stage_id": "",
	}, true)
	PlayerState.lock_pending_trip_selection({
		"short": [short_rider, {}, {}],
		"medium": [{}, {}, {}],
		"long": [long_rider, {}, {}],
	}, "short")


static func _snapshot(selection) -> Dictionary:
	return {
		"pending": PlayerState.get_pending_trip_selection(),
		"story": PlayerState.get_pending_story(),
		"consumed": PlayerState.consumed_story_triggers.duplicate(true),
		"events": PlayerState.event_values.duplicate(true),
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"distance": selection.selected_distance,
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}


static func _test_cancel_and_layout(host: Node) -> void:
	_setup()
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	selection._open_passengers()
	await host.get_tree().process_frame
	var original := _snapshot(selection)
	selection._choose_offer("long", 0)
	await host.get_tree().process_frame
	var dialog = selection.confirmation
	assert(dialog.visible and not selection.is_departing)
	assert(_snapshot(selection) == original, "Previewing a trip cannot select distance, save, charge, advance time or consume a story")
	assert(not selection.terminal_view.enabled)
	for passenger: Button in selection.terminal_view.buttons.values():
		assert(passenger.disabled, "The confirmation must block passenger controls behind it")
	assert(selection.terminal_view.close_button.disabled and selection.terminal_view.store_button.disabled)
	assert(dialog.cancel_button.has_focus(), "Cancel is the initial keyboard action")
	var card = dialog.card
	assert(card.name_label.text == "Student")
	assert(card.route_label.text.to_lower().contains("long") and card.route_label.text.to_lower().contains("noon"))
	assert(card.traffic_label.text.to_lower().contains("speeders"))
	assert(card.badge_label.text == "RUSH" and card.risk_label.text == "HIGH")
	assert(card.fare_label.text == "PHP %d" % PlayerState.estimate_stage_earnings("long-noon-speeders", "generic_student"))
	assert(card.fuel_label.text == "~%.1f%%" % PlayerState.estimate_stage_gas_usage("long-noon-speeders"))
	selection._choose_offer("short", 0)
	selection.terminal_view.buttons.generic_guy.pressed.emit()
	assert(dialog.visible and card.name_label.text == "Student", "Background input cannot replace a pending passenger confirmation")
	assert(_snapshot(selection) == original)
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		selection.size = viewport_size
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var bounds := Rect2(selection.global_position, selection.size)
		assert(bounds.encloses(dialog.panel.get_global_rect()), "The confirmation stays inside the screen")
		assert(bounds.encloses(dialog.confirm_button.get_global_rect()) and bounds.encloses(dialog.cancel_button.get_global_rect()))
		_assert_card_layout(card)
	selection.size = Vector2(1280, 720)
	await host.get_tree().process_frame
	await _key(host, KEY_ESCAPE)
	assert(not dialog.visible and selection.passenger_overlay.visible, "Escape closes confirmation before closing the passenger screen")
	assert(selection.terminal_view.enabled and _snapshot(selection) == original)
	selection._choose_offer("long", 0)
	await host.get_tree().process_frame
	await _key(host, KEY_ENTER)
	assert(not dialog.visible and not selection.is_departing, "Enter on the initial Cancel focus must not depart")
	assert(_snapshot(selection) == original)
	selection._choose_offer("long", 0)
	await host.get_tree().process_frame
	await _click(host, dialog.cancel_button.get_global_rect().get_center())
	assert(not dialog.visible and selection.terminal_view.enabled and _snapshot(selection) == original)
	# The hover card uses the same separated fields and must leave navigation clear.
	selection.terminal_view.buttons.generic_student.mouse_entered.emit()
	await host.get_tree().process_frame
	var preview = selection.terminal_view.info_panel
	_assert_card_layout(preview)
	assert(not preview.get_global_rect().intersects(selection.terminal_view.close_button.get_global_rect()))
	assert(not preview.get_global_rect().intersects(selection.terminal_view.store_button.get_global_rect()))
	assert(preview.name_label.text == card.name_label.text and preview.fare_label.text == card.fare_label.text)
	selection.free()


static func _assert_card_layout(card) -> void:
	var rect: Rect2 = card.get_global_rect()
	for label: Label in [card.name_label, card.route_label, card.traffic_label, card.fare_label, card.fuel_label, card.risk_label]:
		assert(rect.grow(0.1).encloses(label.get_global_rect()), "Trip fields must fit inside their card")
	var fare: Rect2 = card.fare_label.get_global_rect()
	var fuel: Rect2 = card.fuel_label.get_global_rect()
	var risk: Rect2 = card.risk_label.get_global_rect()
	assert(is_equal_approx(fare.position.y, fuel.position.y) and is_equal_approx(fuel.position.y, risk.position.y))
	assert(fare.end.x <= fuel.position.x and fuel.end.x <= risk.position.x, "Fare, fuel and risk occupy separate aligned columns")
	assert(card.route_label.get_global_rect().end.x <= card.traffic_label.get_global_rect().position.x)


static func _test_stale_confirmation(host: Node) -> void:
	_setup()
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	selection._open_passengers()
	selection._choose_offer("long", 0)
	assert(selection.confirmation.visible)
	# A scripted state change while a modal is open cannot confirm the old trip.
	PlayerState.current_phase = "night"
	selection.confirmation.confirm_button.pressed.emit()
	assert(not selection.confirmation.visible and not selection.is_departing)
	assert(PlayerState.energy == 5 and PlayerState.money == 500 and PlayerState.gas == 50.0)
	assert(PlayerState.stage_round == 4 and PlayerState.pending_story.is_empty())
	assert(selection.status_label.text.to_lower().contains("no longer available"))
	assert(selection.selected_distance == "short" and selection.passenger_overlay.visible)
	selection.free()
	await host.get_tree().process_frame
	_setup()
	selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	selection._open_passengers()
	selection._choose_offer("long", 0)
	selection.locked_character_pools["long"][0]["stage_traffic"] = "busy"
	selection.confirmation.confirm_button.pressed.emit()
	assert(not selection.is_departing and not selection.confirmation.visible, "Changed trip details require a fresh confirmation")
	assert(PlayerState.energy == 5 and PlayerState.stage_round == 4 and PlayerState.pending_story.is_empty())
	selection.free()
	await host.get_tree().process_frame


static func _test_confirmed_departure(host: Node) -> void:
	_setup()
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	selection._open_passengers()
	var original := _snapshot(selection)
	selection._choose_offer("long", 0)
	assert(_snapshot(selection) == original and PlayerState.pending_story.is_empty())
	selection.confirmation.confirm_button.pressed.emit()
	selection.confirmation.confirm_button.pressed.emit()
	selection._confirm_passenger()
	await host.get_tree().scene_changed
	var game = host.get_tree().current_scene
	game.set_process(false)
	assert(game.scene_file_path == MAIN_SCENE)
	assert(PlayerState.current_mock_character_id == "generic_student")
	assert(PlayerState.current_stage_type == "long-noon-speeders")
	assert(PlayerState.current_stage_special_type == PlayerState.STAGE_SPECIAL_TYPE_URGENT)
	assert(PlayerState.energy == 4 and PlayerState.stage_round == 5, "Confirming applies exactly one trip-entry charge and advancement")
	assert(PlayerState.money == 500 and PlayerState.current_day == 3 and PlayerState.current_phase == "noon")
	assert(PlayerState.pending_trip_selection.is_empty() and not PlayerState.pending_stage_energy_cost)
	host.get_tree().current_scene = null
	game.free()
	selection.free()


static func _key(host: Node, key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame


static func _click(host: Node, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	host.get_viewport().push_input(motion, true)
	await host.get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame
