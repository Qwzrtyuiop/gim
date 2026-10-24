extends RefCounted

const Payload := preload("res://scripts/story/story_payload.gd")
const Actions := preload("res://scripts/story/story_action_runner.gd")
const Catalog := preload("res://scripts/story/story_action_catalog.gd")
const Flow := preload("res://scripts/story/story_game_flow.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")


static func run(host: Node) -> void:
	assert(Catalog.canonical_type(" WAIT ") == "pause")
	var template: Dictionary = load("res://scripts/story/payloads/templates/gameplay_event_template.gd").build()
	assert(Payload.validate(template).is_empty(), "Gameplay authoring template must remain valid")
	assert(not Catalog.validate_action({"type": "advance_time", "days": 0}).is_empty())
	assert(not Catalog.validate_action({"type": "skip_days", "restore_energy": true, "recover_energy": 1}).is_empty())
	assert(not Catalog.validate_action({"type": "set_resource", "resource": "script", "value": 1}).is_empty())
	assert(not Catalog.validate_action({"type": "return_to", "destination": "invalid"}).is_empty())
	assert(not Payload.validate({"story_id": "bad_action", "composition": [{"actions": [{"type": "skip_dyas"}]}]}).is_empty())
	for type: String in ["advance_time", "skip_days", "skip_phases", "queue_story", "return_to", "end_run", "set_resource", "set_weather"]:
		assert(Actions.is_persistent_story_action({"type": type}), "New game commands must be filtered in memories")
	var reader = await _reader(host, [
		{"text": "Start", "choices": [{"text": "Take a day off", "next_index": 1, "actions": [{"type": "advance_time", "days": 1, "recover_energy": 2}, {"type": "add_gas", "amount": 5}]}]},
		{"text": "A new morning", "next_index": 2},
	])
	PlayerState.energy = 3
	PlayerState.gas = 50.0
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	await reader._choose_branch(reader.story_lines[0].choices[0])
	assert(PlayerState.get_current_day() == 2 and PlayerState.energy == 5 and PlayerState.gas == 55.0)
	assert(PlayerState.get_meta("test_save_count", 0) - saves == 1)
	assert(Flow.destination(reader, "res://scenes/stage_results.tscn") == "res://scenes/day_start_scene.tscn")
	reader.free()
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	reader = await _reader(host, [], false)
	assert(PlayerState.get_current_day() == 2 and PlayerState.energy == 5 and PlayerState.gas == 55.0, "Resuming must not repeat skipped time or rewards")
	assert(reader.body_label.text == "A new morning")
	await reader._run_story_action({"type": "return_to", "destination": "store"})
	await reader._run_story_action({"type": "queue_story", "id": "malasakit"})
	var target := Flow.destination(reader, "unused")
	var queued := Flow.queued_story(reader, target)
	assert(target == "res://scenes/store.tscn" and queued.story_id == "malasakit")
	assert(queued.next_scene == target and queued.return_scene == target)
	# Exercise the actual scene handoff and its saved checkpoint, not only the helper.
	await reader._finish_story()
	await host.get_tree().scene_changed
	var chained = host.get_tree().current_scene
	await host.get_tree().create_timer(1.1).timeout
	assert(chained.story_id == "malasakit" and PlayerState.pending_story.story_id == "malasakit")
	assert(PlayerState.get_last_seen_story_section("malasakit") == 0)
	host.get_tree().current_scene = null
	chained.free()
	reader.free()
	await _test_interrupted_control(host)
	await _test_finish_destinations(host)

	# The same commands are inert in a gallery replay, even through direct dispatch.
	PlayerState.reset()
	reader = await _reader(host, [{"text": "Memory"}], true, true)
	var day: int = PlayerState.get_current_day()
	await reader._run_story_action({"type": "skip_days", "amount": 2})
	await Actions.run(reader, {"type": "set_resource", "resource": "money", "value": 900})
	await Actions.run(reader, {"type": "queue_story", "id": "malasakit"})
	await Actions.run(reader, {"type": "end_run", "reason": "Memory only"})
	assert(PlayerState.get_current_day() == day and PlayerState.money == 0 and not PlayerState.is_run_failed())
	assert(not reader.story_payload.has("_queued_story_id"))
	reader.free()
	PlayerState.reset()
	print("PASS: action validation, event time/effects through real reader, one-save resume, chained story handoff and replay isolation")


static func _test_interrupted_control(host: Node) -> void:
	var reader = await _reader(host, [
		{"text": "Start", "choices": [{"text": "Rest", "next_index": 1, "actions": [
			{"type": "skip_days", "amount": 1},
			{"type": "wait", "duration": 0.4},
			{"type": "increment_event_value", "id": "rested_once"},
		]}]},
		{"text": "Rested"},
	])
	reader._choose_branch(reader.story_lines[0].choices[0])
	await host.get_tree().create_timer(0.1).timeout
	assert(PlayerState.get_current_day() == 2 and not PlayerState.has_event_value("rested_once"))
	reader.free()
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	reader = await _reader(host, [], false)
	await host.get_tree().create_timer(0.5).timeout
	assert(PlayerState.get_current_day() == 2 and PlayerState.get_event_value("rested_once") == 1)
	assert(reader.body_label.text == "Rested")
	reader.free()


static func _test_finish_destinations(host: Node) -> void:
	var reader = await _reader(host, [{"text": "Return", "actions": [{"type": "return_to", "destination": "home"}]}])
	await reader._finish_story()
	await host.get_tree().scene_changed
	var scene = host.get_tree().current_scene
	assert(scene.scene_file_path == "res://scenes/day_start_scene.tscn")
	assert(PlayerState.pending_story.is_empty() and PlayerState.resume_scene_path == scene.scene_file_path)
	host.get_tree().current_scene = null
	scene.free()
	reader.free()
	reader = await _reader(host, [{"text": "Run ends", "actions": [{"type": "end_run", "reason": "Authored event outcome"}]}])
	await reader._finish_story()
	await host.get_tree().scene_changed
	scene = host.get_tree().current_scene
	assert(scene.scene_file_path == "res://scenes/game_over.tscn" and PlayerState.is_run_failed())
	assert(PlayerState.get_run_fail_reason() == "Authored event outcome")
	host.get_tree().current_scene = null
	scene.free()
	reader.free()


static func _reader(host: Node, composition: Array, fresh := true, replay := false):
	if fresh:
		PlayerState.reset()
		var payload := Payload.normalize({"story_id": "game_control_fixture", "replay": replay, "composition": composition})
		if replay:
			PlayerState.set_pending_memory_replay(payload)
		else:
			PlayerState.set_pending_story(payload)
	var reader = load("res://scenes/story_scene.tscn").instantiate()
	host.get_tree().root.add_child(reader)
	await host.get_tree().create_timer(1.1).timeout
	assert(not reader.is_input_locked)
	return reader
