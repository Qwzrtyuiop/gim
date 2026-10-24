extends RefCounted

const Playback := preload("res://scripts/story/story_dialogue_playback.gd")
const Settings := preload("res://scripts/config/story_dialogue_settings.gd")
const Payload := preload("res://scripts/story/story_payload.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")


static func run(host: Node) -> void:
	var previous: bool = ProjectSettings.get_setting("testing/instant_story_text", false)
	ProjectSettings.set_setting("testing/instant_story_text", false)
	_test_reveal_clock(host)
	await _test_reader_input(host)
	await _test_saved_reveal(host)
	ProjectSettings.set_setting("testing/instant_story_text", previous)
	PlayerState.reset()
	print("PASS: gradual Unicode reveal, stable layout, punctuation pacing, first-press skip, delayed choices, pause, narration and silent checkpoint resume")


static func _test_reveal_clock(host: Node) -> void:
	var label := Label.new()
	label.size = Vector2(280, 120)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(label)
	var playback := Playback.new()
	host.add_child(playback)
	playback.setup(label)
	label.text = "Kumusta, kaibigan?"
	playback.start({}, {"typewriter": {"characters_per_second": 10, "punctuation_pause": 0.2}}, "John Toda")
	playback.set_process(false)
	assert(playback.active and label.visible_characters == 0)
	playback._process(0.11)
	assert(label.visible_characters == 1 and label.text == "Kumusta, kaibigan?")
	playback._process(0.7)
	assert(label.visible_characters == 8, "Comma is shown, then adds a pause")
	playback._process(0.1)
	assert(label.visible_characters == 8)
	var before_resize: int = label.visible_characters
	label.size.x = 500
	assert(label.visible_characters == before_resize)
	assert(playback.finish_now() and label.visible_characters == -1)
	assert(not playback.active and not playback.voice.player.playing)
	assert(not playback.finish_now(), "A second skip cannot release completion twice")
	label.text = "A\u0301🙂\nB"
	playback.start({}, {"typewriter": {"characters_per_second": 10, "punctuation_pause": 0.0}}, "Benny")
	playback.set_process(false)
	playback._process(0.11)
	assert(label.visible_characters == 2, "Combining accent must reveal with its base letter")
	playback._process(0.1)
	assert(label.visible_characters == 3, "Emoji remains a complete character")
	playback._process(1.0)
	assert(not playback.active and label.visible_characters == -1)
	assert(Settings.resolve({}, {}, "John").voice_pitch == Settings.resolve({}, {}, "John Toda").voice_pitch)
	assert(Settings.resolve({}, {}, "Benny").voice_pitch == Settings.resolve({}, {}, "Ben").voice_pitch)
	assert(not Settings.resolve({}, {}, "").sound_enabled)
	label.text = "Instant"
	playback.start({}, {"typewriter": false}, "John")
	assert(not playback.active and label.visible_characters == -1)
	playback.free()
	label.free()


static func _new_reader(host: Node, payload: Dictionary):
	PlayerState.set_pending_story(Payload.normalize(payload))
	var reader = load("res://scenes/story_scene.tscn").instantiate()
	host.get_tree().root.add_child(reader)
	await host.get_tree().create_timer(0.48).timeout
	return reader


static func _test_reader_input(host: Node) -> void:
	PlayerState.reset()
	var reader = await _new_reader(host, {
		"story_id": "typing_input",
		"typewriter": {"characters_per_second": 15},
		"composition": [
			{"speaker": "John Toda", "text": "This text should still be appearing after the intro fade.", "actions": [{"type": "add_money", "amount": 10}]},
			{"speaker": "Benny", "text": "Choose after this sentence finishes.", "choices": [{"text": "Continue", "next_index": 2}]},
			{"text": "Narration is silent.", "typewriter": {"characters_per_second": 240}},
		],
	})
	assert(reader.dialogue_playback.active and reader.is_input_locked)
	assert(reader.body_label.visible_characters > 0 and PlayerState.money == 10)
	var shown: int = reader.body_label.visible_characters
	host.get_tree().paused = true
	await host.get_tree().create_timer(0.15).timeout
	assert(reader.body_label.visible_characters == shown, "Pause freezes reveal")
	host.get_tree().paused = false
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	reader._input(confirm)
	assert(reader.current_line_index == 0 and reader.body_label.visible_characters == -1)
	assert(not reader.is_input_locked and not reader.dialogue_playback.voice.player.playing)
	reader._input(confirm)
	assert(reader.current_line_index == 1 and reader.dialogue_playback.active)
	assert(not reader.choice_container.visible and not reader.continue_label.visible, "Choices stay hidden while text reveals")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	reader._input(click)
	assert(reader.current_line_index == 1 and reader.choice_buttons.size() == 1)
	assert(not reader.is_input_locked and reader.choice_container.visible)
	reader._choose_branch(reader.story_lines[1].choices[0])
	assert(not reader.choice_container.visible, "Previous choices must disappear as the next line starts")
	await host.get_tree().create_timer(0.15).timeout
	assert(reader.current_line_index == 2 and not reader.dialogue_playback.voice.sound_enabled)
	assert(PlayerState.money == 10, "Skipping reveal cannot execute another line's effects")
	reader.free()
	assert(PlayerState._state_batch_depth == 0)


static func _test_saved_reveal(host: Node) -> void:
	PlayerState.reset()
	var reader = await _new_reader(host, {
		"story_id": "typing_checkpoint",
		"typewriter": {"characters_per_second": 10},
		"composition": [{"speaker": "Elena", "text": "An interrupted line must not repeat its money reward when restored.", "actions": [{"type": "add_money", "amount": 25}]}],
	})
	assert(reader.dialogue_playback.active and PlayerState.money == 25)
	reader.free()
	assert(PlayerState._state_batch_depth == 0)
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	var saved: Dictionary = PlayerState.get_pending_story()
	assert(saved._checkpoint.continuation.kind == "line_end")
	reader = await _new_reader(host, saved)
	assert(not reader.dialogue_playback.active and not reader.is_input_locked)
	assert(reader.body_label.visible_characters == -1 and PlayerState.money == 25)
	assert(not reader.dialogue_playback.voice.player.playing, "Completed reveal checkpoints restore silently")
	reader.free()
