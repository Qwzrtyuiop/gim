extends RefCounted

const TerminalView := preload("res://scripts/ride_selection/terminal_passenger_view.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const LINES := [
	"It's a trashcan",
	"It's not a passenger",
	"It can't go inside my tricycle",
	"Can it?",
	"Trash can.",
]


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_geometry_and_input(host)
	await _test_passenger_priority(host)
	await _test_progression_and_gates(host)
	AmbientAudioManager.stop_all()
	UIAudioManager.hover_player.stop()
	UIAudioManager.press_player.stop()
	# Real pointer tests start audio; allow its server-side playback references to drain.
	await host.get_tree().create_timer(0.1).timeout
	PlayerState.reset()
	print("PASS: terminal trashcan real pointer dispatch, unmarked hover/cursor, letterboxed hit regions, day/night and modal gates, passenger click priority, exact five-line progression and capped scene-local state")


static func _test_geometry_and_input(host: Node) -> void:
	var view := TerminalView.new()
	host.get_tree().root.add_child(view)
	view.set_offers([], false)
	var clicks: Array[String] = []
	view.object_pressed.connect(func(object_id: String) -> void: clicks.append(object_id))
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		view.size = viewport_size
		await _settle(host)
		var rect: Rect2 = view.object_rect_for("trashcan")
		var ratio := minf(viewport_size.x / 1672.0, viewport_size.y / 941.0)
		assert(rect.position.is_equal_approx((viewport_size - Vector2(1672, 941) * ratio) * 0.5 + Vector2(100, 440) * ratio))
		assert(rect.size.is_equal_approx(Vector2(98, 132) * ratio))
		assert(view.object_rect_for("missing_object") == Rect2())
		var child_count := view.get_child_count()
		var modulate: Color = view.modulate
		await _move(host, view.get_global_transform_with_canvas() * rect.get_center())
		assert(view.mouse_default_cursor_shape == Control.CURSOR_ARROW and view.tooltip_text.is_empty(), "Unmarked objects keep the ordinary cursor and have no tooltip")
		assert(view.active_offer_id().is_empty() and not view.info_panel.visible and view.modulate == modulate and view.get_child_count() == child_count, "Object hover creates no highlight, passenger detail or extra hover graphic")
		var before := clicks.size()
		await _click(host, view.get_global_transform_with_canvas() * rect.get_center())
		assert(clicks.size() == before + 1 and clicks.back() == "trashcan", "Actual GUI picking follows the fitted artwork at each aspect ratio")
		await _click(host, view.get_global_transform_with_canvas() * (rect.end + Vector2(8, 0)))
		assert(clicks.size() == before + 1, "Nearby background pixels are not part of the object")
	view.size = Vector2(1280, 720)
	await _settle(host)
	var point: Vector2 = view.get_global_transform_with_canvas() * view.object_rect_for("trashcan").get_center()
	var before := clicks.size()
	await _click(host, point, MOUSE_BUTTON_RIGHT)
	assert(clicks.size() == before, "Only a left press inspects objects")
	view.set_enabled(false)
	await _click(host, point)
	assert(clicks.size() == before, "Disabled terminal controls also disable background objects")
	view.set_enabled(true)
	view.set_offers([], true)
	assert(view.object_rect_for("trashcan") == Rect2())
	await _click(host, point)
	assert(clicks.size() == before, "The terminalday object cannot activate against night artwork")
	view.free()
	await _settle(host)


static func _test_passenger_priority(host: Node) -> void:
	var view := TerminalView.new()
	host.get_tree().root.add_child(view)
	view.size = Vector2(1280, 720)
	view.set_offers([{
		"character": {"id": "faye"},
		"distance": "short",
		"slot": 0,
		"summary": {"name": "Passenger"},
	}], false)
	await _settle(host)
	var objects: Array[String] = []
	var passengers: Array[int] = []
	view.object_pressed.connect(func(object_id: String) -> void: objects.append(object_id))
	view.offer_pressed.connect(func(_distance: String, slot: int) -> void: passengers.append(slot))
	var button: Button = view.buttons.faye
	var overlap: Rect2 = view.object_rect_for("trashcan").intersection(button.get_rect())
	var target := Vector2(-1, -1)
	for y in range(ceili(overlap.position.y), floori(overlap.end.y), 2):
		for x in range(ceili(overlap.position.x), floori(overlap.end.x), 2):
			var point := Vector2(x + 0.5, y + 0.5)
			if bool(button.call("_has_point", point - button.position)):
				target = point
				break
		if target.x >= 0:
			break
	assert(target.x >= 0, "The authored Faye pose supplies a genuine opaque passenger/object overlap")
	await _click(host, view.get_global_transform_with_canvas() * target)
	assert(passengers == [0] and objects.is_empty(), "A passenger drawn over the bin receives the click instead of inspecting the hidden object")
	view.free()
	await _settle(host)


static func _setup() -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "morning"
	PlayerState.current_stage_type = "short-morning-chill"
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 5
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE)
	var rider: Dictionary = PlayerState.get_character_by_id("generic_guy")
	rider.merge({"active_distance": "short", "stage_traffic": "chill", "stage_special_type": "", "special_stage_id": "", "pickup_location": "station", "pickup_variant": ""}, true)
	PlayerState.lock_pending_trip_selection({"short": [rider], "medium": [], "long": []}, "short")


static func _test_progression_and_gates(host: Node) -> void:
	_setup()
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await _settle(host)
	selection._open_passengers()
	await _settle(host)
	var view = selection.terminal_view
	var point: Vector2 = view.get_global_transform_with_canvas() * view.object_rect_for("trashcan").get_center()
	var original := _snapshot()
	for expected: String in LINES:
		await _click(host, point)
		assert(str(selection.hub_dialogue.active_line.get("text", "")) == expected)
		assert(selection.hub_dialogue.bubble.speaker_label.text == "John Toda" and selection.hub_dialogue.bubble.tail_points.is_empty())
		assert(not selection.hub_dialogue.blocks_input() and selection.passenger_overlay.visible and not selection.confirmation.visible)
		assert(_snapshot() == original, "Inspecting scenery cannot save, spend resources, advance time, consume stories or award bond")
	for _repeat in range(2):
		await _click(host, point)
		assert(str(selection.hub_dialogue.active_line.get("text", "")) == "Trash can.", "The fifth response caps rather than wrapping or indexing beyond the list")
	selection.hub_dialogue.clear()
	selection._close_passengers()
	selection._open_passengers()
	await _click(host, point)
	assert(str(selection.hub_dialogue.active_line.get("text", "")) == "Trash can.", "Opening the terminal again in the same scene preserves its object progression")
	selection.hub_dialogue.clear()
	var index: int = selection._trashcan_line_index
	selection.tutorial._set_active(true)
	await _click(host, point)
	assert(selection._trashcan_line_index == index and not selection.hub_dialogue.is_active(), "Tutorial input cannot inspect objects behind its overlay")
	selection.tutorial._end()
	selection._choose_offer("short", 0)
	assert(selection.confirmation.visible)
	await _click(host, point)
	assert(selection._trashcan_line_index == index and not selection.hub_dialogue.is_active(), "Cancelling confirmation from its backdrop cannot also inspect the object behind it")
	assert(not selection.confirmation.visible and not selection.is_departing, "An outside click retains the confirmation's normal safe-cancel behavior")
	selection._cancel_passenger()
	selection.is_departing = true
	await _click(host, point)
	assert(selection._trashcan_line_index == index and not selection.hub_dialogue.is_active(), "Departing screens reject inspection")
	selection.is_departing = false
	assert(selection.show_message("Another conversation", {"blocking": true, "typewriter": false}))
	await _click(host, point)
	assert(selection._trashcan_line_index == index, "A blocking conversation owns the click before background input")
	selection.hub_dialogue.clear()
	selection.free()
	await _settle(host)
	selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await _settle(host)
	selection._open_passengers()
	await _settle(host)
	view = selection.terminal_view
	point = view.get_global_transform_with_canvas() * view.object_rect_for("trashcan").get_center()
	await _click(host, point)
	assert(str(selection.hub_dialogue.active_line.get("text", "")) == LINES[0], "A new station visit starts its scene-local sequence from the first response")
	selection.free()
	await _settle(host)


static func _snapshot() -> Dictionary:
	return {
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"pending": PlayerState.get_pending_trip_selection(),
		"story": PlayerState.get_pending_story(),
		"events": PlayerState.event_values.duplicate(true),
		"consumed": PlayerState.consumed_story_triggers.duplicate(true),
		"bond": PlayerState.unique_character_progress.duplicate(true),
		"rides": PlayerState.character_completed_rides.duplicate(true),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _move(host: Node, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	host.get_viewport().push_input(motion, true)
	await host.get_tree().process_frame


static func _click(host: Node, point: Vector2, button_index := MOUSE_BUTTON_LEFT) -> void:
	await _move(host, point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button_index
		event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button_index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame
