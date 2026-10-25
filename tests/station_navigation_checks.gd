extends RefCounted

const StationView := preload("res://scripts/ui/station_view.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_hotspots(host)
	await _test_pointer_focus(host)
	await _test_intro_handoff(host)
	await _test_modal_and_resume(host)
	await _test_terminal_header(host)
	await _test_store_navigation(host)
	PlayerState.reset()
	print("PASS: station polygon hotspots, mouse/keyboard highlight modes, shared terminal status header, day/night resizing, modal/tutorial gating, locked-offer save/resume and cost-free store navigation")


static func _test_intro_handoff(host: Node) -> void:
	var previous_language := StoryLanguageManager.get_language()
	for language in ["english", "tagalog"]:
		PlayerState.reset()
		StoryLanguageManager.set_language(language)
		var energy: int = PlayerState.energy
		var gas: float = PlayerState.gas
		var payload := PayloadCatalog.build("scene_01_intro", "res://scenes/day_start_scene.tscn", PlayerState.FIRST_STAGE_TYPE)
		# Resume at the final authored line, then use its normal Continue handoff.
		PlayerState.set_last_seen_story_section("scene_01_intro", payload.composition.size() - 1)
		var reader = await host._reader(payload)
		await reader._advance_story()
		await host.get_tree().scene_changed
		if host.get_tree().current_scene == null or host.get_tree().current_scene.scene_file_path != SELECTION_SCENE:
			await host.get_tree().scene_changed
		var selection = host.get_tree().current_scene
		assert(selection.scene_file_path == SELECTION_SCENE)
		assert(selection.passenger_overlay.visible and selection.terminal_view.visible, "The prologue must open passengers directly in both languages")
		assert(selection.tutorial.active and not selection.station.enabled)
		assert(not selection.terminal_view.enabled)
		for passenger: Button in selection.terminal_view.buttons.values():
			assert(passenger.disabled, "Tutorial input cannot start a passenger ride")
		assert(PlayerState.get_pending_trip_selection().passengers_open)
		assert(PlayerState.get_current_day() == 1 and PlayerState.get_current_time_of_day() == "morning" and PlayerState.stage_round == 0)
		assert(PlayerState.energy == energy - 1 and PlayerState.gas == gas, "Only the existing intro entry cost applies; station navigation cannot charge again")
		host.get_tree().current_scene = null
		selection.free()
		reader.free()
	StoryLanguageManager.set_language(previous_language)


static func _test_hotspots(host: Node) -> void:
	var station := StationView.new()
	host.get_tree().root.add_child(station)
	station.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	assert(StationView.DAY.get_size() == StationView.ART_SIZE)
	assert(StationView.NIGHT.get_size() == StationView.ART_SIZE)
	assert(StationView.DAY_SELECTED.get_size() == StationView.ART_SIZE)
	assert(StationView.NIGHT_SELECTED.get_size() == StationView.ART_SIZE)
	for night in [false, true]:
		station.set_night(night)
		for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
			station.size = viewport_size
			station._layout()
			var image: Rect2 = station.image_rect
			assert(image.position.x >= -0.01 and image.position.y >= -0.01)
			assert(image.end.x <= viewport_size.x + 0.01 and image.end.y <= viewport_size.y + 0.01)
			assert(_hit(station, "store", Vector2(0.02, 0.40)), "The left-edge entrance opens the store")
			assert(not _hit(station, "passengers", Vector2(0.02, 0.40)), "The store entrance must not open passengers")
			assert(_hit(station, "passengers", Vector2(0.75, 0.72)))
			assert(not _hit(station, "store", Vector2(0.75, 0.72)), "The foreground tricycle must not open the store")
			assert(_hit(station, "passengers", Vector2(0.90, 0.08)), "The upper canopy is part of the tricycle")
			assert(not _hit(station, "passengers", Vector2(0.75, 0.30)), "The gap below the canopy is not clickable")
			assert(not _hit(station, "store", Vector2(0.04, 0.40)), "The pole beside the outlined entrance is not clickable")
			assert(not _hit(station, "store", Vector2(0.02, 0.12)), "The tree above the entrance is not clickable")
			assert(not _hit(station, "store", Vector2(0.47, 0.20)), "The previous upper-building hotspot is no longer active")
			for action in ["passengers", "store"]:
				assert(not _hit(station, action, Vector2(0.15, 0.80)), "Empty road must not activate a hotspot")
				assert(not Geometry2D.triangulate_polygon(station.polygon_for(action)).is_empty())
				var highlights: Array[PackedVector2Array] = station._highlight_polygons(action)
				assert(not highlights.is_empty())
				for polygon in highlights:
					assert(not Geometry2D.triangulate_polygon(polygon).is_empty())
					for point in polygon:
						assert(Rect2(Vector2.ZERO, Vector2.ONE).grow(0.0001).has_point(point), "Hover art must stay inside the image, including letterboxed layouts")
		for action in ["passengers", "store"]:
			var day_polygon: PackedVector2Array = station.polygon_for(action)
			station.set_night(not night)
			assert(station.polygon_for(action) == day_polygon, "Day and night use identical selection areas")
			station.set_night(night)
	station.buttons.store.mouse_entered.emit()
	assert(station.hovered_action == "store")
	station.buttons.store.mouse_exited.emit()
	assert(station.hovered_action.is_empty())
	station.buttons.passengers.focus_entered.emit()
	assert(station.focused_action == "passengers")
	assert(station.active_action().is_empty(), "Automatic focus must not look like a pointer hover")
	station.set_enabled(false)
	assert(station.hovered_action.is_empty() and station.focused_action.is_empty())
	for button: Button in station.buttons.values():
		assert(button.disabled)
	station.set_enabled(true)
	for button: Button in station.buttons.values():
		assert(not button.disabled)
	station.free()


static func _test_pointer_focus(host: Node) -> void:
	var station := StationView.new()
	host.get_tree().root.add_child(station)
	station.size = Vector2(1280, 720)
	await host.get_tree().process_frame
	for night in [false, true]:
		station.set_night(night)
		var empty: Vector2 = station.image_rect.position + Vector2(0.15, 0.80) * station.image_rect.size
		var tricycle: Vector2 = station.image_rect.position + Vector2(0.75, 0.72) * station.image_rect.size
		await _move(host, empty)
		station.buttons.passengers.grab_focus()
		assert(station.active_action().is_empty(), "A focused tricycle cannot stay highlighted while the pointer is on empty road")
		await _click(host, tricycle)
		assert(station.active_action() == "passengers")
		await _move(host, empty)
		assert(station.active_action().is_empty(), "Moving off a clicked tricycle must clear its highlight")
		await _tab(host)
		assert(station.is_keyboard_navigation() and not station.active_action().is_empty(), "Intentional keyboard navigation retains a visible focus target")
		await _move(host, empty)
		assert(not station.is_keyboard_navigation() and station.active_action().is_empty(), "Pointer input must stop displaying the old keyboard focus")
		station.set_enabled(false)
		station.set_enabled(true)
		station.buttons.passengers.grab_focus()
		assert(station.active_action().is_empty(), "Re-enabling the station cannot turn its restored focus into hover")
	station.free()


static func _hit(station, action: String, normalized: Vector2) -> bool:
	var point: Vector2 = station.image_rect.position + normalized * station.image_rect.size
	var button: Button = station.buttons[action]
	return bool(button.call("_has_point", point - button.position))


static func _setup(mode := "current_stage", allow_back := true) -> void:
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
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", mode, allow_back)
	var character: Dictionary = PlayerState.get_character_by_id("jessa")
	character["active_distance"] = "medium"
	character["stage_traffic"] = "traffic-jam"
	character["stage_special_type"] = PlayerState.STAGE_SPECIAL_TYPE_NONE
	character["special_stage_id"] = ""
	PlayerState.lock_pending_trip_selection({
		"short": [character.duplicate(true), {}, {}],
		"medium": [character.duplicate(true), {}, {}],
		"long": [character.duplicate(true), {}, {}],
	}, "medium")


static func _snapshot() -> Array:
	return [
		PlayerState.get_current_day(),
		PlayerState.get_current_time_of_day(),
		PlayerState.stage_round,
		PlayerState.money,
		PlayerState.energy,
		PlayerState.gas,
		PlayerState.pending_stage_energy_cost,
		PlayerState.last_rest_day,
	]


static func _test_terminal_header(host: Node) -> void:
	_setup(PlayerState.TRANSITION_REST_TO_NIGHT)
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	var header = selection.status_header
	var original: Array = _snapshot()
	var style: StyleBox = header.get_theme_stylebox("panel")
	assert(header.day_label.text == "DAY 3 / Noon")
	selection._open_passengers()
	await host.get_tree().process_frame
	assert(header == selection.status_header and header.is_visible_in_tree(), "Passengers reuse the station's status header")
	assert(header.get_theme_stylebox("panel") == style)
	assert(header.day_label.text == "DAY 3 / Night", "The header previews the selected trip phase without advancing time")
	assert(header.z_index > selection.passenger_overlay.z_index)
	var stats: Dictionary = header.stats_refs
	assert(stats.money_label.text == "Money: PhP 500")
	assert(stats.energy_label.text == "%d/%d" % [PlayerState.energy, PlayerState.max_energy])
	assert(stats.gas_label.text == PlayerState.gas_text())
	assert(stats.row.get_child(1) is TextureRect and stats.row.get_child(3) is TextureRect, "Energy and fuel keep the shared header icons")
	assert(_snapshot() == original)
	PlayerState.add_money(17)
	PlayerState.add_energy(1)
	PlayerState.add_gas(2.0)
	assert(stats.money_label.text == "Money: PhP 517")
	assert(stats.energy_label.text == "%d/%d" % [PlayerState.energy, PlayerState.max_energy])
	assert(stats.gas_label.text == PlayerState.gas_text())
	assert(header.day_label.text == "DAY 3 / Night", "Live resource refreshes preserve the trip phase preview")
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		selection.size = viewport_size
		await host.get_tree().process_frame
		assert(is_equal_approx(header.position.x + header.size.x * 0.5, viewport_size.x * 0.5))
		assert(selection.status_label.position.y >= header.position.y + header.size.y, "Passenger instructions must sit below the shared header")
	selection._close_passengers()
	assert(header.is_visible_in_tree() and header.day_label.text == "DAY 3 / Noon")
	selection.free()


static func _test_modal_and_resume(host: Node) -> void:
	_setup(PlayerState.TRANSITION_CURRENT_STAGE, false)
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	var original: Array = _snapshot()
	var pools: Dictionary = selection.locked_character_pools.duplicate(true)
	assert(not selection.passenger_overlay.visible and not selection.terminal_view.is_visible_in_tree())
	assert(selection.station.enabled and not selection.tutorial.active)
	selection._choose_character(0)
	assert(_snapshot() == original and not selection.is_departing, "Hidden passengers cannot start a ride")
	var tricycle_point: Vector2 = selection.station.image_rect.position + Vector2(0.75, 0.72) * selection.station.image_rect.size
	await _click(host, tricycle_point)
	assert(selection.passenger_overlay.visible and selection.terminal_view.visible)
	assert(not selection.station.enabled)
	assert(selection.terminal_view.active_offer_id().is_empty() and selection.terminal_view.info_label.text.is_empty(), "Mouse entry cannot automatically hover the first passenger")
	assert(selection.terminal_view.buttons.size() == 1, "Repeated saved offers cannot spawn duplicate copies of the same character")
	assert(PlayerState.get_pending_trip_selection().passengers_open)
	assert(selection.terminal_view.close_button.visible, "Closing passengers remains possible when leaving station is disallowed")
	selection._set_distance("long")
	assert(selection.passenger_overlay.visible and selection.selected_distance == "long", "Saved distance selection must not close the terminal or reroll its offers")
	await _move(host, Vector2(320, 576))
	selection._handle_back_button_pressed()
	assert(not selection.passenger_overlay.visible and selection.station.enabled)
	assert(selection.station.active_action().is_empty(), "Closing passengers over empty road cannot leave the restored tricycle focus highlighted")
	assert(not bool(PlayerState.get_pending_trip_selection().get("passengers_open", false)))
	assert(_snapshot() == original and selection.locked_character_pools == pools)
	selection.station.buttons.passengers.pressed.emit()
	assert(selection.selected_distance == "long" and selection.locked_character_pools == pools)
	assert(selection.terminal_view.active_offer_id().is_empty() and selection.terminal_view.info_label.text.is_empty(), "Reopening in mouse mode cannot pin passenger details")
	Codec.save_to_path(PlayerState, "res://test_user/station_open_passengers.tres", PlayerState.SAVE_VERSION)
	selection.free()
	assert(Codec.load_from_path(PlayerState, "res://test_user/station_open_passengers.tres"))
	selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	assert(selection.passenger_overlay.visible and selection.terminal_view.visible)
	assert(selection.terminal_view.active_offer_id().is_empty(), "Restoring an open terminal must not invent a hovered passenger")
	assert(selection.selected_distance == "long" and selection.locked_character_pools == pools)
	assert(_snapshot() == original, "Restoring an open passenger screen cannot pay or advance a trip")
	selection._close_passengers()
	selection.free()


static func _click(host: Node, point: Vector2) -> void:
	await _move(host, point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame


static func _move(host: Node, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	host.get_viewport().push_input(motion, true)
	await host.get_tree().process_frame


static func _tab(host: Node) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame


static func _test_store_navigation(host: Node) -> void:
	_setup(PlayerState.TRANSITION_REST_TO_NIGHT)
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	var original := _snapshot()
	var pools: Dictionary = selection.locked_character_pools.duplicate(true)
	assert(selection.station.is_night, "The station matches the selected trip's projected phase")
	var store_point: Vector2 = selection.station.image_rect.position + Vector2(0.02, 0.40) * selection.station.image_rect.size
	await _click(host, store_point)
	if host.get_tree().current_scene == null or host.get_tree().current_scene.scene_file_path != STORE_SCENE:
		await host.get_tree().scene_changed
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == STORE_SCENE)
	assert(_snapshot() == original)
	assert(PlayerState.get_locked_pending_trip_character_pools() == pools)
	assert(PlayerState.get_pending_trip_selection().transition_mode == PlayerState.TRANSITION_REST_TO_NIGHT)
	store.street.buttons.station.pressed.emit()
	await host.get_tree().scene_changed
	var returned = host.get_tree().current_scene
	assert(returned.scene_file_path == SELECTION_SCENE)
	assert(not returned.passenger_overlay.visible and returned.station.enabled)
	assert(returned.station.is_night and returned.selected_distance == "medium")
	assert(returned.locked_character_pools == pools)
	assert(PlayerState.get_pending_trip_selection().transition_mode == PlayerState.TRANSITION_REST_TO_NIGHT)
	assert(_snapshot() == original, "Walking to the store and back cannot grant rest, charge entry, or advance time")
	host.get_tree().current_scene = null
	returned.free()
	selection.free()
