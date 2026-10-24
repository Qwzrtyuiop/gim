extends RefCounted

const Payload := preload("res://scripts/story/story_payload.gd")
const Conditions := preload("res://scripts/story/story_conditions.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")


static func run(host: Node) -> void:
	await _test_response_routes(host)
	await _test_replay_preserves_live_story(host)
	PlayerState.reset()


static func _reader(host: Node):
	var reader = load("res://scenes/story_scene.tscn").instantiate()
	host.get_tree().root.add_child(reader)
	# _ready starts the fade before it locks story input.
	await host.get_tree().create_timer(0.5).timeout
	assert(not reader.is_input_locked)
	return reader


static func _test_response_routes(host: Node) -> void:
	PlayerState.reset()
	PlayerState.money = 500
	var payload := Payload.normalize({
		"story_id": "response_routes",
		"composition": [
			{"text": "Choose", "choices": [{"text": "Continue", "response_text": "Response", "response_actions": [{"type": "add_money", "amount": 10}]}]},
			{"text": "Original next", "next_index": 3},
			{"text": "Unchosen"},
			{"text": "Original branch", "next_index": 4},
		],
	})
	PlayerState.set_pending_story(payload)
	var reader = await _reader(host)
	await reader._choose_branch(reader.story_lines[0].choices[0])
	assert(reader.body_label.text == "Response")
	assert(reader.story_lines[1].text == "Original next" and reader.story_lines[3].text == "Original branch", "Response must preserve authored indices")
	assert(reader._current_line().next_index == 1)
	assert(Conditions.resolve_visible_story_index(reader.story_lines, 4) == -1, "Original completion index must stay terminal")
	assert(PlayerState.money == 510)
	Codec.save_to_path(PlayerState, "res://test_user/story_response_resume.tres", PlayerState.SAVE_VERSION)
	reader.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/story_response_resume.tres"))
	reader = await _reader(host)
	assert(reader.body_label.text == "Response" and PlayerState.money == 510, "Response checkpoint must resume without repeating rewards")
	reader._advance_story()
	assert(reader.current_line_index == 1 and reader.body_label.text == "Original next", "Default response continuation must not loop on the response")
	reader._advance_story()
	assert(reader.current_line_index == 3 and reader.body_label.text == "Original branch", "Later authored jumps must keep their destinations")
	# Nested response choices without their own jump inherit the response return.
	await reader._show_line(0)
	await reader._choose_branch({"response": {"text": "Nested response", "choices": [{"text": "Continue"}]}, "next_index": 3})
	await reader._choose_branch(reader._current_line().choices[0])
	assert(reader.current_line_index == 3)
	reader.free()
	print("PASS: response default/jump routing, stable authored/end indices, nested response choices and saved response rewards")


static func _test_replay_preserves_live_story(host: Node) -> void:
	PlayerState.reset()
	var live := Payload.normalize({"story_id": "live_pending_story", "composition": [{"text": "Live checkpoint"}]})
	PlayerState.set_pending_story(live)
	PlayerState.set_resume_scene("res://scenes/story_scene.tscn")
	var replay := Payload.normalize({
		"story_id": "test_memory_replay",
		"replay": true,
		"next_scene": "res://scenes/gallery_library.tscn",
		"composition": [{"text": "Memory", "actions": [{"type": "add_money", "amount": 100}, {"type": "set_event_value", "id": "replay_effect", "value": true}]}],
	})
	PlayerState.set_pending_memory_replay(replay)
	var reader = await _reader(host)
	assert(reader.body_label.text == "Memory" and reader._is_replay_mode())
	assert(PlayerState.pending_story == live, "Opening a memory must retain the live pending story")
	assert(PlayerState.money == 0 and not PlayerState.event_values.has("replay_effect"))
	# An unrelated autosave while the memory is open must serialize live progress.
	PlayerState.save_progress()
	var saved = load(PlayerState.SAVE_PATH)
	assert(saved.data.pending_story == live)
	await reader._finish_story()
	await host.get_tree().scene_changed
	assert(PlayerState.pending_memory_replay.is_empty() and PlayerState.pending_story == live)
	assert(PlayerState.resume_scene_path == "res://scenes/story_scene.tscn")
	var gallery = host.get_tree().current_scene
	if is_instance_valid(gallery):
		host.get_tree().current_scene = null
		gallery.free()
	# This reader was added under root, rather than installed as current_scene.
	reader.free()
	PlayerState.pending_story.clear()
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	assert(PlayerState.pending_story == live, "Completing a memory must preserve the live checkpoint on disk")
	# Exiting a memory through the pause menu clears its transient entry as well.
	PlayerState.set_pending_memory_replay(replay)
	reader = await _reader(host)
	reader.free()
	assert(PlayerState.pending_memory_replay.is_empty() and PlayerState.pending_story == live)
	print("PASS: memory completion/interruption and autosaves preserve live pending story and suppress persistent effects")
