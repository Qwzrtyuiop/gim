extends RefCounted

const Economy := preload("res://scripts/game/game_economy_manager.gd")
const Passenger := preload("res://scripts/results/result_passenger.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SCENE := "res://scenes/stage_results.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_passenger_identity()
	_test_result_identity_persistence()
	await _test_scene_and_layout(host)
	await _test_exceptional_receipts(host)
	await _test_actions(host)
	await _test_low_energy_cancel(host)
	PlayerState.reset()
	print("PASS: result passenger identity/portraits, completed and failed save reload, one-time payout, structured special receipts, responsive layout and available actions")


static func _test_passenger_identity() -> void:
	PlayerState.reset()
	var current := PlayerState.get_character_by_id("benny")
	var resolved := Passenger.resolve({"character_id": "jessa"}, current)
	assert(resolved.character_id == "jessa" and resolved.name == "???")
	assert(resolved.texture.resource_path == "res://assets/characters/Jessa.png")
	assert(not resolved.is_placeholder)
	PlayerState.set_event_value("jessa_name_revealed", true)
	assert(Passenger.resolve({"character_id": "jessa"}, current).name == "Jessa")
	for alias in {"elena": "ely", "magda": "faye", "celina": "cel", "isidro": "ito"}:
		resolved = Passenger.resolve({"character_id": alias}, current)
		assert(resolved.character_id == {"elena": "ely", "magda": "faye", "celina": "cel", "isidro": "ito"}[alias])
		assert(resolved.texture != null and not resolved.is_placeholder)
	resolved = Passenger.resolve({"character_id": "generic_student"}, current)
	assert(resolved.name == "Student" and resolved.is_generic and resolved.texture != null)
	resolved = Passenger.resolve({"character_id": "unknown_saved_rider"}, current)
	assert(resolved.character_id == "unknown_saved_rider" and resolved.texture != null and resolved.is_placeholder)
	assert(resolved.name != "Benny", "An unknown saved rider cannot borrow the current rider's identity")
	assert(Passenger.resolve({}, current).character_id == "benny", "Legacy results without identity retain a safe current-rider fallback")
	assert(Passenger.resolve({"character_id": ""}, current).character_id == "", "An explicitly empty saved identity must not become another passenger")
	assert(Passenger.resolve({}).texture != null)


static func _test_result_identity_persistence() -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "noon"
	PlayerState.current_stage_type = "short-noon-traffic-jam"
	PlayerState.set_current_mock_character("jessa")
	Economy.store_stage_result("short-noon-traffic-jam", "short", "noon", "traffic-jam", PlayerState.STAGE_SPECIAL_TYPE_CAREFUL, "", 620.0, 620.0, 0.2, 0.0, 1.0, 12.0, 2.0, 3)
	assert(PlayerState.get_last_stage_result().character_id == "jessa")
	PlayerState.set_current_mock_character("benny")
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	assert(PlayerState.get_last_stage_result().character_id == "jessa")
	assert(Passenger.resolve(PlayerState.get_last_stage_result(), PlayerState.get_character_by_id("benny")).character_id == "jessa")
	PlayerState.set_current_mock_character("faye")
	Economy.store_failed_stage_result("short-night-chill", "short", "night", "chill", PlayerState.STAGE_SPECIAL_TYPE_NONE, "", 200.0, 620.0, "Out of fuel")
	assert(PlayerState.get_last_stage_result().character_id == "faye", "Failed rides must retain their passenger before later events change the current rider")
	PlayerState.set_current_mock_character("benny")
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	assert(PlayerState.get_last_stage_result().character_id == "faye")


static func _result(phase := "noon") -> Dictionary:
	return {
		"character_id": "jessa",
		"day": 3,
		"stage_type": "short-%s-traffic-jam" % phase,
		"difficulty": "short",
		"time_of_day": phase,
		"traffic": "traffic-jam",
		"stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_CAREFUL,
		"distance": 620,
		"fare": 103,
		"bonus": 36,
		"passenger_rule_violation_count": 3,
		"passenger_penalty": 10,
		"total": 129,
		"completed": true,
		"detail_lines": ["Distance: 620m", "Fare: PhP 103", "Bonus: PhP 36", "Passenger Penalty: -PhP 10 (3 warnings)", "Total: PhP 129"],
	}


static func _setup(result: Dictionary) -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "night"
	PlayerState.current_stage_type = "short-night-chill"
	PlayerState.money = 500
	PlayerState.energy = 4
	PlayerState.gas = 87.9
	PlayerState.set_current_mock_character("benny")
	PlayerState.set_last_stage_result(result)


static func _screen(host: Node):
	var screen = load(SCENE).instantiate()
	host.get_tree().root.add_child(screen)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return screen


static func _test_scene_and_layout(host: Node) -> void:
	_setup(_result())
	var screen = await _screen(host)
	var view = screen.results_view
	assert(PlayerState.money == 629 and PlayerState.last_stage_result.paid_out)
	assert(view.heading_label.text == "RIDE COMPLETE")
	assert(view.date_label.text.to_lower().contains("noon") and view.date_label.text.contains("3"), "The receipt shows the completed trip rather than the advanced live clock")
	assert(view.route_label.text.to_lower().contains("short") and view.route_label.text.to_lower().contains("traffic"))
	assert(view.special_label.text.to_upper().contains("CAREFUL"))
	assert(view.passenger_name.text == "???" and view.portrait.texture.resource_path == "res://assets/characters/Jessa.png")
	assert(view.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert(view.total_label.text.contains("129"))
	assert(not view.goal_label.text.is_empty() and not view.goal_progress_label.text.is_empty())
	assert(view.goal_progress.value >= view.goal_progress.min_value and view.goal_progress.value <= view.goal_progress.max_value)
	var receipt := _labels_text(view.receipt_rows)
	assert(receipt.contains("103") and receipt.contains("36") and receipt.contains("10"))
	var original := PlayerState.get_last_stage_result()
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		screen.size = viewport_size
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var bounds := Rect2(screen.global_position, viewport_size).grow(0.5)
		assert(bounds.encloses(_global_bounds(view.canvas)), "The scaled result composition stays inside the viewport")
		var panels: Array[Control] = [view.passenger_panel, view.receipt_panel, view.goal_panel]
		for index in panels.size():
			assert(bounds.encloses(_global_bounds(panels[index])))
			for other_index in range(index + 1, panels.size()):
				assert(not _global_bounds(panels[index]).intersects(_global_bounds(panels[other_index])), "Portrait, receipt and goal panels cannot overlap")
		assert(_global_bounds(view.passenger_panel).grow(0.5).encloses(_global_bounds(view.portrait)))
		_assert_text_layout(view)
		for label in [view.passenger_name, view.total_label, view.goal_label, view.goal_progress_label, view.debt_label, view.due_label, view.footer_note]:
			assert(bounds.encloses(_global_bounds(label)), "Result labels stay inside the viewport")
		for button in [screen.rest_button, screen.store_button, screen.ride_button]:
			if button.visible:
				assert(bounds.encloses(_global_bounds(button)), "Available result actions remain visible")
	assert(PlayerState.get_last_stage_result() == original, "Resizing cannot rewrite the receipt")
	screen.free()
	screen = await _screen(host)
	assert(PlayerState.money == 629, "Reopening the result screen cannot claim a second payout")
	screen.free()


static func _test_exceptional_receipts(host: Node) -> void:
	_setup(_result())
	var screen = await _screen(host)
	var view = screen.results_view
	var unpaid := _result()
	unpaid.merge({
		"fare": 0,
		"bonus": 0,
		"passenger_penalty": 0,
		"total": 0,
		"unpaid_story": "jessa_runaway_fare",
		"detail_lines": ["Distance: 620m", "Unpaid fare: PhP 139", "Passenger left without paying.", "Total: PhP 0"],
	}, true)
	view.present(unpaid, Passenger.resolve(unpaid))
	await host.get_tree().process_frame
	var text := _labels_text(view).to_lower()
	assert(text.contains("139") and (text.contains("unpaid") or text.contains("without paying")), "The unpaid reason and historical fare survive the redesign")
	var waived := unpaid.duplicate(true)
	waived.erase("unpaid_story")
	waived.merge({
		"character_id": "generic_elder",
		"random_ride_event": "malasakit",
		"random_ride_outcome": "waive",
		"detail_lines": ["Distance: 620m", "Fare waived: PhP 139", "Total: PhP 0", "Malasakit: +5% to all fares"],
	}, true)
	view.present(waived, Passenger.resolve(waived))
	await host.get_tree().process_frame
	text = _labels_text(view).to_lower()
	assert(text.contains("waiv") and text.contains("139") and text.contains("malasakit"))
	var failed := _result()
	failed.merge({
		"completed": false,
		"distance": 200,
		"fare": 0,
		"bonus": 0,
		"total": 0,
		"failure_reason": "Out of fuel",
		"detail_lines": ["Progress: 200m / 620m", "Reason: Out of fuel", "Total: PhP 0"],
	}, true)
	view.present(failed, Passenger.resolve(failed))
	await host.get_tree().process_frame
	text = _labels_text(view).to_lower()
	assert(view.heading_label.text == "TRIP ENDED" and text.contains("out of fuel") and text.contains("200"))
	assert(not view.earnings_summary_label.text.to_lower().contains("you just earned"))
	var helped := _result()
	helped["bayanihan_skipped_phase"] = "night"
	view.present(helped, Passenger.resolve(helped))
	await host.get_tree().process_frame
	assert(_labels_text(view).to_lower().contains("bayanihan"))
	PlayerState.remaining_debt = 0
	view.update_goal(0, true)
	assert(not is_nan(view.goal_progress.value) and not is_inf(view.goal_progress.value), "Paid debt has a finite progress display")
	screen.free()


static func _test_actions(host: Node) -> void:
	for phase in ["morning", "noon", "night"]:
		_setup(_result(phase))
		var screen = await _screen(host)
		assert(screen.rest_button.visible)
		assert(screen.store_button.visible == (phase != "night"))
		assert(screen.ride_button.visible == (phase != "night"))
		screen.free()
	_setup(_result("morning"))
	PlayerState.last_rest_day = 3
	var screen = await _screen(host)
	assert(screen.rest_button.visible and screen.store_button.visible and screen.ride_button.visible, "Returning home remains available after the daily rest was used")
	screen.free()
	_setup(_result("noon"))
	PlayerState.set_pending_night_phase_skip(true)
	screen = await _screen(host)
	assert(screen.rest_button.visible and not screen.store_button.visible and not screen.ride_button.visible)
	assert(screen.results_view.footer_note.text.contains("Benny"), "The long pending-night-skip explanation remains visible")
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900)]:
		screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		screen.size = viewport_size
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		_assert_text_layout(screen.results_view)
		var footer: Label = screen.results_view.footer_note
		assert(_global_bounds(screen.results_view.canvas).grow(0.5).encloses(_global_bounds(footer)), "The full pending-night-skip note stays inside the design canvas")
		assert(not _global_bounds(footer).intersects(_global_bounds(screen.rest_button)), "A long footer cannot overlap the Rest action")
	screen.free()


static func _test_low_energy_cancel(host: Node) -> void:
	_setup(_result("noon"))
	PlayerState.energy = 1
	PlayerState.stress = 8
	var screen = await _screen(host)
	var original := {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"pending": PlayerState.get_pending_trip_selection(),
		"result": PlayerState.get_last_stage_result(),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}
	assert(screen.ride_button.visible)
	screen._attempt_next_stage()
	await host.get_tree().process_frame
	assert(screen.ride_confirm_dialog.visible, "A high-stress trip opens a warning while one energy still permits departure")
	screen.ride_confirm_dialog.get_cancel_button().pressed.emit()
	await host.get_tree().process_frame
	assert(not screen.ride_confirm_dialog.visible)
	assert(PlayerState.money == original.money and PlayerState.energy == original.energy and PlayerState.gas == original.gas)
	assert(PlayerState.current_day == original.day and PlayerState.current_phase == original.phase and PlayerState.stage_round == original.round)
	assert(PlayerState.get_pending_trip_selection() == original.pending and PlayerState.get_last_stage_result() == original.result)
	assert(int(PlayerState.get_meta("test_save_count", 0)) == original.saves, "Cancelling the high-stress warning cannot save, charge or change the clock")
	screen.free()


static func _assert_text_layout(view) -> void:
	for panel: Control in [view.passenger_panel, view.goal_panel]:
		var labels := _labels(panel)
		for label: Label in labels:
			_assert_text_fit(label)
			assert(_global_bounds(panel).grow(0.5).encloses(_global_bounds(label)), "Result text must fit its assigned panel after minimum-size layout: %s" % label.text)
		_assert_disjoint(labels)
	for label: Label in [view.route_label, view.special_label, view.total_label]:
		if label.visible:
			_assert_text_fit(label)
			assert(_global_bounds(view.receipt_panel).grow(0.5).encloses(_global_bounds(label)), "Receipt headings and total stay in the receipt panel")
	var previous: Control
	for row: Control in view.receipt_rows.get_children():
		# Long receipts may intentionally scroll vertically. Every row must still
		# fit horizontally and its own text columns must remain separate.
		var row_bounds := _global_bounds(row)
		var panel_bounds := _global_bounds(view.receipt_panel)
		assert(row_bounds.position.x >= panel_bounds.position.x - 0.5 and row_bounds.end.x <= panel_bounds.end.x + 0.5)
		if previous != null:
			assert(not _global_bounds(previous).intersects(row_bounds), "Receipt rows cannot overlap after text wrapping")
		previous = row
		var labels := _labels(row)
		for label: Label in labels:
			_assert_text_fit(label)
			assert(row_bounds.grow(0.5).encloses(_global_bounds(label)), "A receipt value must fit within its own row")
		_assert_disjoint(labels)
	_assert_text_fit(view.footer_note)


static func _assert_text_fit(label: Label) -> void:
	if not label.visible or label.text.is_empty():
		return
	var minimum := label.get_minimum_size()
	assert(label.size.y + 0.5 >= minimum.y, "A result label cannot clip wrapped text vertically: %s" % label.text)
	if label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		assert(label.size.x + 0.5 >= minimum.x, "A result label cannot clip its text horizontally: %s" % label.text)


static func _labels(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label and node.visible and not node.text.is_empty():
		labels.append(node)
	for child in node.get_children():
		labels.append_array(_labels(child))
	return labels


static func _assert_disjoint(labels: Array[Label]) -> void:
	for index in labels.size():
		for other_index in range(index + 1, labels.size()):
			assert(not _global_bounds(labels[index]).intersects(_global_bounds(labels[other_index])), "Result text regions cannot overlap: %s / %s" % [labels[index].text, labels[other_index].text])


static func _labels_text(node: Node) -> String:
	var parts := PackedStringArray()
	if node is Label:
		parts.append(node.text)
	for child in node.get_children():
		parts.append(_labels_text(child))
	return "\n".join(parts)


static func _global_bounds(control: Control) -> Rect2:
	var transform := control.get_global_transform()
	var start: Vector2 = transform * Vector2.ZERO
	var end: Vector2 = transform * control.size
	return Rect2(start, end - start).abs()
