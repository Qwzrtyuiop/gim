extends RefCounted

const DIALOGUE_PATH := "res://scripts/ui/hub_dialogue.gd"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	var previous_instant: bool = ProjectSettings.get_setting("testing/instant_story_text", false)
	var previous_language: String = StoryLanguageManager.get_language()
	ProjectSettings.set_setting("testing/instant_story_text", false)
	await _test_queue_and_localization(host)
	await _test_reentrant_callbacks(host)
	await _test_reveal_and_clicks(host)
	await _test_gates_timers_and_targets(host)
	await _test_sprite_target(host)
	await _test_screen_integration(host)
	StoryLanguageManager.set_language(previous_language)
	ProjectSettings.set_setting("testing/instant_story_text", previous_instant)
	PlayerState.reset()
	print("PASS: local hub speech queues/localization, Unicode reveal and click isolation, gated timers/pause, tracked targets and viewport bounds, home/station/store integration without VN or state effects")


static func _fixture(host: Node) -> Dictionary:
	var parent := Control.new()
	parent.size = Vector2(1280, 720)
	host.get_tree().root.add_child(parent)
	var dialogue = load(DIALOGUE_PATH).new()
	parent.add_child(dialogue)
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _settle(host)
	return {"parent": parent, "dialogue": dialogue}


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"pending": PlayerState.get_pending_trip_selection(),
		"story": PlayerState.get_pending_story(),
		"events": PlayerState.event_values.duplicate(true),
		"consumed": PlayerState.consumed_story_triggers.duplicate(true),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}


static func _test_queue_and_localization(host: Node) -> void:
	PlayerState.reset()
	var fixture := await _fixture(host)
	var dialogue = fixture.dialogue
	var original := _snapshot()
	var completed: Array[bool] = []
	var started: Array[String] = []
	var finished: Array[String] = []
	dialogue.sequence_finished.connect(func(cancelled: bool) -> void: completed.append(cancelled))
	dialogue.message_started.connect(func(line: Dictionary) -> void: started.append(str(line.get("text", ""))))
	dialogue.message_finished.connect(func(line: Dictionary) -> void: finished.append(str(line.get("text", ""))))
	assert(dialogue.play([
		{"text": "One", "typewriter": false},
		{"text": "Two", "typewriter": false},
	]))
	assert(dialogue.queue_messages([{"text": "Three", "typewriter": false}]))
	assert(dialogue.bubble.body_label.text == "One")
	assert(not dialogue.say({"unsupported": "Missing localized text"}), "Invalid messages cannot replace a valid conversation")
	assert(not dialogue.play([{}]))
	assert(dialogue.bubble.body_label.text == "One" and completed.is_empty())
	dialogue.advance()
	assert(dialogue.bubble.body_label.text == "Two")
	dialogue.advance()
	assert(dialogue.bubble.body_label.text == "Three")
	dialogue.advance()
	assert(not dialogue.is_active() and completed == [false])
	assert(started == ["One", "Two", "Three"] and finished == started)
	dialogue.clear()
	assert(completed == [false], "Clearing an already drained queue emits no extra completion")
	assert(dialogue.say("Replace me", {"typewriter": false}))
	assert(dialogue.say("Replacement", {"typewriter": false}))
	assert(completed == [false, true])
	dialogue.clear()
	dialogue.clear()
	assert(completed == [false, true, true], "Replacement and cancellation each finish their sequence once")
	for language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(language)
		assert(dialogue.say({"english": "Good morning", "tagalog": "Magandang umaga"}, {"typewriter": false}))
		assert(dialogue.bubble.body_label.text == ("Magandang umaga" if language == "tagalog" else "Good morning"))
		dialogue.clear()
	StoryLanguageManager.set_language("english")
	assert(dialogue.say("Keep my name hidden", {"character_id": "jessa", "typewriter": false}))
	assert(dialogue.bubble.speaker_label.text == "???")
	dialogue.clear()
	assert(_snapshot() == original, "Local speech cannot save progress, consume story triggers or change the game clock/resources")
	fixture.parent.free()


static func _test_reentrant_callbacks(host: Node) -> void:
	var fixture := await _fixture(host)
	var dialogue = fixture.dialogue
	var started: Array[String] = []
	var finished: Array[String] = []
	var completed: Array[bool] = []
	var replaced := [false]
	dialogue.message_started.connect(func(line: Dictionary) -> void: started.append(str(line.text)))
	dialogue.message_finished.connect(func(line: Dictionary) -> void: finished.append(str(line.text)))
	dialogue.sequence_finished.connect(func(cancelled: bool) -> void:
		completed.append(cancelled)
		if cancelled and not replaced[0]:
			replaced[0] = true
			assert(dialogue.say("Callback replacement", {"typewriter": false}))
	)
	assert(dialogue.say("Original", {"typewriter": false}))
	assert(dialogue.say("Superseded request", {"typewriter": false}))
	assert(dialogue.bubble.body_label.text == "Callback replacement", "A cancellation callback's newer request takes precedence over the outer replacement")
	assert(started == ["Original", "Callback replacement"] and finished.is_empty(), "An overwritten replacement cannot emit a ghost message-start signal")
	assert(completed == [true])
	dialogue.advance()
	assert(finished == ["Callback replacement"] and completed == [true, false] and not dialogue.is_active())
	fixture.parent.free()
	fixture = await _fixture(host)
	dialogue = fixture.dialogue
	started.clear()
	finished.clear()
	completed.clear()
	var appended := [false]
	dialogue.message_started.connect(func(line: Dictionary) -> void: started.append(str(line.text)))
	dialogue.sequence_finished.connect(func(cancelled: bool) -> void: completed.append(cancelled))
	dialogue.message_finished.connect(func(line: Dictionary) -> void:
		finished.append(str(line.text))
		if not appended[0]:
			appended[0] = true
			assert(dialogue.queue_messages([{"text": "Immediate follow-up", "typewriter": false}]))
			dialogue.advance()
	)
	assert(dialogue.say("First", {"typewriter": false}))
	dialogue.advance()
	assert(started == ["First", "Immediate follow-up"] and finished == started)
	assert(completed == [false] and not dialogue.is_active(), "Synchronously completing a callback's queued message cannot finish the sequence twice")
	fixture.parent.free()


static func _test_reveal_and_clicks(host: Node) -> void:
	var fixture := await _fixture(host)
	var dialogue = fixture.dialogue
	var clicks := [0]
	var button := Button.new()
	button.size = fixture.parent.size
	button.pressed.connect(func() -> void: clicks[0] += 1)
	fixture.parent.add_child(button)
	fixture.parent.move_child(button, 0)
	assert(dialogue.play([
		{"text": "A\u0301🙂 slowly", "typewriter": {"characters_per_second": 10, "punctuation_pause": 0, "sound_enabled": false}},
		{"text": "Second message", "typewriter": false},
	], {"position": Vector2(0.5, 0.5)}))
	await host.get_tree().create_timer(0.12).timeout
	assert(dialogue.playback.active and dialogue.bubble.body_label.visible_characters >= 2, "The accented grapheme reveals together")
	assert(not dialogue.blocks_input())
	assert(not dialogue.handle_input(_key(KEY_ENTER)), "Ambient speech cannot steal a focused menu button's Enter")
	assert(not dialogue.handle_input(_key(KEY_ESCAPE)), "Ambient speech leaves normal menu Escape routing intact")
	await _click(host, dialogue.bubble.body_label.get_global_rect().get_center())
	assert(dialogue.bubble.body_label.text.begins_with("A\u0301") and not dialogue.playback.active)
	assert(dialogue.bubble.body_label.visible_characters == -1)
	assert(clicks[0] == 0, "Finishing speech cannot click the menu behind it")
	await _click(host, dialogue.bubble.body_label.get_global_rect().get_center())
	assert(dialogue.bubble.body_label.text == "Second message" and clicks[0] == 0)
	await _click(host, Vector2(10, 700))
	assert(clicks[0] == 1 and dialogue.is_active(), "Menus remain usable outside an ambient bubble")
	dialogue.clear()
	assert(dialogue.say("Blocking message", {"blocking": true, "typewriter": false}))
	assert(dialogue.blocks_input())
	assert(dialogue.handle_input(_key(KEY_ENTER)))
	assert(not dialogue.is_active())
	assert(dialogue.say("Cancel this", {"blocking": true, "typewriter": false}))
	assert(dialogue.handle_input(_key(KEY_ESCAPE)))
	assert(not dialogue.is_active())
	assert(dialogue.play([
		{"text": "Blocking click one", "typewriter": false},
		{"text": "Blocking click two", "typewriter": false},
	], {"blocking": true}))
	await _click(host, Vector2(10, 700))
	assert(dialogue.bubble.body_label.text == "Blocking click two" and clicks[0] == 1, "A blocking outside click advances speech without activating the background menu")
	await _click(host, Vector2(10, 700))
	assert(not dialogue.is_active() and clicks[0] == 1, "The final blocking click cannot fall through when the speech disappears")
	fixture.parent.free()


static func _test_gates_timers_and_targets(host: Node) -> void:
	var fixture := await _fixture(host)
	var dialogue = fixture.dialogue
	var allowed := [false]
	dialogue.set_gate(func() -> bool: return allowed[0])
	assert(dialogue.say("Wait for the menu", {"duration": 0.12, "typewriter": false}))
	await host.get_tree().create_timer(0.2).timeout
	assert(dialogue.is_active() and not dialogue.bubble.visible, "A covered menu cannot consume its unseen message")
	allowed[0] = true
	await _settle(host)
	assert(dialogue.bubble.visible)
	await host.get_tree().create_timer(0.18).timeout
	assert(not dialogue.is_active())
	assert(dialogue.say("Still revealing", {"duration": 0.12, "typewriter": {"characters_per_second": 2, "sound_enabled": false}}))
	await host.get_tree().create_timer(0.18).timeout
	assert(dialogue.is_active() and dialogue.playback.active, "Auto-dismiss begins after reveal instead of truncating it")
	dialogue.advance()
	await host.get_tree().create_timer(0.04).timeout
	assert(dialogue.is_active())
	await host.get_tree().create_timer(0.15).timeout
	assert(not dialogue.is_active())
	assert(dialogue.say("Paused typing", {"typewriter": {"characters_per_second": 5, "sound_enabled": false}}))
	await _settle(host)
	var revealed: int = dialogue.bubble.body_label.visible_characters
	host.get_tree().paused = true
	await host.get_tree().create_timer(0.22).timeout
	assert(dialogue.bubble.body_label.visible_characters == revealed, "Pause freezes local reveal")
	host.get_tree().paused = false
	dialogue.clear()
	var actor := Control.new()
	actor.position = Vector2(100, 320)
	actor.size = Vector2(70, 150)
	fixture.parent.add_child(actor)
	dialogue.register_control("actor", actor)
	assert(dialogue.say("Follow this person", {"target": "actor", "typewriter": false}))
	await _settle(host)
	var initial: Vector2 = dialogue.bubble.panel.get_global_rect().position
	actor.position.x += 650
	await _settle(host)
	assert(dialogue.bubble.panel.get_global_rect().position.distance_to(initial) > 10, "The box tracks moving/resized speaker geometry")
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(640, 360)]:
		fixture.parent.size = viewport_size
		actor.position = viewport_size - Vector2(12, 12)
		await _settle(host)
		await _settle(host)
		assert(Rect2(Vector2.ZERO, viewport_size).grow(0.5).encloses(dialogue.bubble.panel.get_global_rect()), "An edge speaker cannot place its speech off screen")
	actor.hide()
	assert(dialogue.say("Wait while hidden", {"target": "actor", "duration": 0.12, "typewriter": false}))
	await host.get_tree().create_timer(0.2).timeout
	assert(dialogue.is_active() and not dialogue.bubble.visible)
	actor.show()
	await _settle(host)
	assert(dialogue.bubble.visible)
	actor.free()
	await host.get_tree().create_timer(0.18).timeout
	assert(dialogue.is_active() and not dialogue.bubble.visible, "A freed speaker cannot leave stale text or consume its timer")
	dialogue.clear()
	assert(dialogue.say("Missing person", {"target": "missing", "typewriter": false}))
	await _settle(host)
	assert(dialogue.is_active() and not dialogue.bubble.visible)
	fixture.parent.free()


static func _test_sprite_target(host: Node) -> void:
	var fixture := await _fixture(host)
	var dialogue = fixture.dialogue
	var sprite_parent := Node2D.new()
	sprite_parent.position = Vector2(40, 20)
	sprite_parent.scale = Vector2(1.2, 0.8)
	fixture.parent.add_child(sprite_parent)
	var sprite := Sprite2D.new()
	var image := Image.create(50, 90, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.position = Vector2(180, 360)
	sprite_parent.add_child(sprite)
	dialogue.register_sprite("sprite", sprite)
	assert(dialogue.say("Follow a Sprite2D", {"target": "sprite", "typewriter": false}))
	await _settle(host)
	assert(dialogue.bubble.visible)
	var before: Vector2 = dialogue.bubble.panel.get_global_rect().position
	sprite_parent.position += Vector2(500, 60)
	sprite.rotation = 0.15
	await _settle(host)
	assert(dialogue.bubble.panel.get_global_rect().position.distance_to(before) > 10, "Sprite speech follows its canvas transform instead of its local position")
	sprite.hide()
	await _settle(host)
	assert(dialogue.is_active() and not dialogue.bubble.visible)
	sprite.show()
	await _settle(host)
	assert(dialogue.bubble.visible)
	sprite.free()
	await _settle(host)
	assert(dialogue.is_active() and not dialogue.bubble.visible, "Freed Sprite2D anchors use weak references and leave no stale speech")
	fixture.parent.free()


static func _setup_screen_state() -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "morning"
	PlayerState.current_stage_type = "short-morning-chill"
	PlayerState.stage_round = 3
	PlayerState.money = 500
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE, true)


static func _test_screen_integration(host: Node) -> void:
	_setup_screen_state()
	var home = load("res://scenes/day_start_scene.tscn").instantiate()
	host.get_tree().root.add_child(home)
	await _settle(host)
	var original := _snapshot()
	assert(home.show_message("A note by the calendar", {"target": "calendar", "speaker": "John", "typewriter": false}))
	await _settle(host)
	assert(home.hub_dialogue.bubble.visible)
	home._show_info("calendar")
	await _settle(host)
	assert(not home.hub_dialogue.bubble.visible, "Home information panels take priority over local speech")
	home._close_info()
	await _settle(host)
	assert(home.hub_dialogue.bubble.visible)
	home.hub_dialogue.clear()
	var previous_scene: Node = host.get_tree().current_scene
	host.get_tree().current_scene = home
	assert(home.show_message("Finish this conversation first", {"blocking": true, "typewriter": false}))
	await _settle(host)
	assert(home.hub_dialogue.blocks_input() and not PauseMenuManager.is_menu_open())
	await _press_key(host, KEY_ESCAPE)
	assert(not home.hub_dialogue.is_active() and not PauseMenuManager.is_menu_open() and not host.get_tree().paused, "Blocking speech owns real Escape before the global pause menu")
	assert(home.show_message("Ambient speech permits pause", {"typewriter": false}))
	await _press_key(host, KEY_ESCAPE)
	assert(PauseMenuManager.is_menu_open() and host.get_tree().paused and home.hub_dialogue.is_active(), "Ordinary hub speech preserves normal Escape-to-pause")
	PauseMenuManager.hide_pause_menu()
	home.hub_dialogue.clear()
	host.get_tree().current_scene = previous_scene
	assert(_snapshot() == original)
	home.free()
	_setup_screen_state()
	var store = load("res://scenes/store.tscn").instantiate()
	host.get_tree().root.add_child(store)
	await _settle(host)
	store._open_shop("tricycle")
	await _settle(host)
	original = _snapshot()
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900)]:
		store.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		store.size = viewport_size
		for category in ["tricycle", "food"]:
			store._open_shop(category)
			await _settle(host)
			_assert_store_speech_bounds(store, viewport_size)
			assert(store.show_message("I can explain the available items while you browse. Take your time and choose whichever supplies you need for the next trip.", {"target": "shopkeeper", "typewriter": false}))
			await _settle(host)
			_assert_store_speech_bounds(store, viewport_size)
	store._open_shop("tricycle")
	assert(store.show_message("A message from Lito", {"target": "shopkeeper", "speaker": "Lito", "typewriter": false}))
	await _settle(host)
	assert(store.hub_dialogue.bubble.visible and store.hub_dialogue.bubble.speaker_label.text == "Lito")
	store.hub_dialogue.clear()
	assert(_snapshot() == original)
	store.free()
	_setup_screen_state()
	var rider := PlayerState.get_character_by_id("generic_guy")
	rider.merge({"active_distance": "short", "stage_traffic": "chill", "stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_NONE}, true)
	PlayerState.lock_pending_trip_selection({"short": [rider, {}, {}], "medium": [{}, {}, {}], "long": [{}, {}, {}]}, "short")
	var station = load("res://scenes/ride_selection.tscn").instantiate()
	host.get_tree().root.add_child(station)
	await _settle(host)
	station._open_passengers()
	await _settle(host)
	original = _snapshot()
	assert(station.show_message("Local passenger speech", {"target": "generic_guy", "character_id": "generic_guy", "typewriter": false}))
	await _settle(host)
	assert(station.hub_dialogue.bubble.visible)
	await _click(host, station.hub_dialogue.bubble.body_label.get_global_rect().get_center())
	assert(not station.confirmation.visible and not station.is_departing, "Clicking the speech box cannot select a passenger underneath")
	assert(_snapshot() == original)
	station.hub_dialogue.clear()
	station.free()


static func _assert_store_speech_bounds(store, viewport_size: Vector2) -> void:
	assert(store.hub_dialogue.bubble.visible, "A store greeting appears beside its visible owner")
	var bubble_bounds: Rect2 = store.hub_dialogue.bubble.panel.get_global_rect()
	assert(Rect2(Vector2.ZERO, viewport_size).grow(0.5).encloses(bubble_bounds))
	for button: BaseButton in store.store_buy_buttons:
		if button.is_visible_in_tree():
			assert(not bubble_bounds.intersects(button.get_global_rect()), "Owner speech cannot cover a visible BUY control")


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


static func _click(host: Node, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	host.get_viewport().push_input(motion, true)
	await _settle(host)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await _settle(host)


static func _settle(host: Node) -> void:
	# process_frame fires before node _process callbacks; the second signal lets
	# the previous update finish before observing a gate or target/layout change.
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _press_key(host: Node, code: Key) -> void:
	for pressed in [true, false]:
		var event := _key(code)
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await _settle(host)
