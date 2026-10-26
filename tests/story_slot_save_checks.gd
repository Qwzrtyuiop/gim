extends RefCounted

const Context := preload("res://scripts/save/save_game_context.gd")
const Payload := preload("res://scripts/story/story_payload.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Driving := preload("res://scripts/save/driving_save_snapshot.gd")
const Spawner := preload("res://scripts/game/vehicle_spawner.gd")
const STORY := "res://scenes/story_scene.tscn"
const MAIN := "res://scenes/main.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	var previous: bool = ProjectSettings.get_setting("testing/instant_story_text", false)
	ProjectSettings.set_setting("testing/instant_story_text", false)
	await _scrolling_and_choices(host)
	await _unfinished_action(host)
	await _intro_and_replay(host)
	await _inline_driving_story(host)
	ProjectSettings.set_setting("testing/instant_story_text", previous)
	PlayerState.reset()
	print("PASS: real Escape opens/closes pause during story reveal, choices, waits, intro and inline driving; repeat/release isolation, live save batches, once-only rewards and gallery save denial")


static func _reader(host: Node, payload: Dictionary, delay := 0.48):
	PlayerState.set_pending_story(Payload.normalize(payload))
	var reader = load(STORY).instantiate()
	host.get_tree().root.add_child(reader)
	host.get_tree().current_scene = reader
	if delay > 0.0:
		await host.get_tree().create_timer(delay).timeout
	return reader


static func _save_paused(host: Node, reader, slot: int) -> Resource:
	assert(SaveSlotManager.slot_path(slot).begins_with("res://test_user/"))
	var pending: Dictionary = PlayerState.get_pending_story()
	var payload: Dictionary = reader.story_payload.duplicate(true)
	var continuation: Dictionary = reader.checkpoint_continuation.duplicate(true)
	var depth: int = PlayerState._state_batch_depth
	var suppressed: bool = PlayerState._suppress_auto_save
	var deferred: bool = PlayerState._has_deferred_save
	var reader_depth: int = reader.checkpoint_batch_depth
	var line: int = reader.current_line_index
	var visible_characters: int = reader.body_label.visible_characters
	var money: int = PlayerState.money
	_open_pause_with_escape(host)
	assert(host.get_tree().paused and not PauseMenuManager.save_button.disabled)
	PauseMenuManager._show_save_screen("save")
	PauseMenuManager._save_requested(slot)
	assert(PauseMenuManager.save_screen.status_label.text == "Saved to slot %d." % slot)
	await host.get_tree().create_timer(0.15).timeout
	var saved: Resource = ResourceLoader.load(SaveSlotManager.slot_path(slot), "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(saved != null and saved.data.money == money)
	assert(PlayerState._state_batch_depth == depth and reader.checkpoint_batch_depth == reader_depth, "Manual saves must leave the live story batch open")
	assert(PlayerState._suppress_auto_save == suppressed and PlayerState._has_deferred_save == deferred)
	assert(PlayerState.get_pending_story() == pending and reader.checkpoint_continuation == continuation, "Capturing a slot must not commit the live checkpoint")
	assert(reader.story_payload == payload, "The slot checkpoint must not replace the live reader payload")
	assert(reader.current_line_index == line and reader.body_label.visible_characters == visible_characters)
	assert(PlayerState.money == money, "A paused save must not advance actions or repeat rewards")
	_escape(host, true)
	assert(not PauseMenuManager.save_screen.visible and PauseMenuManager.visible and host.get_tree().paused, "Escape first returns from the slot selector to the pause menu")
	_escape(host, false)
	_close_pause_with_escape(host)
	return saved


static func _escape(host: Node, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = pressed
	event.echo = echo
	host.get_viewport().push_input(event, true)


static func _open_pause_with_escape(host: Node) -> void:
	assert(not PauseMenuManager.visible and not host.get_tree().paused)
	_escape(host, true)
	assert(PauseMenuManager.visible and PauseMenuManager.overlay.visible and host.get_tree().paused, "One Escape press must open pause without being toggled again by another input handler")
	_escape(host, true, true)
	assert(PauseMenuManager.visible and host.get_tree().paused, "Held Escape repeats must keep the pause menu open")
	_escape(host, false)
	assert(PauseMenuManager.visible and host.get_tree().paused, "Releasing Escape must leave pause open")


static func _close_pause_with_escape(host: Node) -> void:
	assert(PauseMenuManager.visible and host.get_tree().paused and not PauseMenuManager.save_screen.visible)
	_escape(host, true)
	assert(not PauseMenuManager.visible and not host.get_tree().paused, "The next Escape press must close pause")
	_escape(host, true, true)
	assert(not PauseMenuManager.visible and not host.get_tree().paused, "Held Escape repeats must not reopen pause")
	_escape(host, false)
	assert(not PauseMenuManager.visible and not host.get_tree().paused)


static func _reload(host: Node, reader, slot: int):
	Context.prepare_scene_for_load(reader)
	host.get_tree().current_scene = null
	reader.free()
	assert(PlayerState._state_batch_depth == 0)
	assert(SaveSlotManager.load_slot(slot) and Context.resume_scene() == STORY)
	return await _reader(host, PlayerState.get_pending_story())


static func _discard(host: Node, reader) -> void:
	host.get_tree().current_scene = null
	reader.free()
	assert(PlayerState._state_batch_depth == 0)


static func _scrolling_and_choices(host: Node) -> void:
	PlayerState.reset()
	var reader = await _reader(host, {
		"story_id": "slot_reveal_fixture",
		"typewriter": {"characters_per_second": 10},
		"composition": [
			{"speaker": "John", "text": "Saving while this long sentence appears must preserve this line and its reward.", "actions": [{"type": "add_money", "amount": 10}]},
			{"text": "Choose a route.", "typewriter": false, "choices": [{"text": "Continue", "next_index": 2, "actions": [{"type": "add_money", "amount": 7}]}]},
			{"text": "Choice completed.", "typewriter": false},
		],
	})
	assert(reader.dialogue_playback.active and reader.is_input_locked and reader.checkpoint_batch_depth > 0)
	assert(reader.body_label.visible_characters > 0 and PlayerState.money == 10)
	PlayerState._begin_state_batch()
	assert(not Context.save_block_reason(reader).is_empty())
	assert(SaveSlotManager.save_slot(8, Context.capture(reader)) == ERR_BUSY, "Unrelated state batches must still block story saves")
	PlayerState._end_state_batch()
	var saved: Resource = await _save_paused(host, reader, 8)
	assert(saved.data.pending_story._checkpoint.line_index == 0)
	assert(saved.data.pending_story._checkpoint.continuation.kind == "line_end")
	reader = await _reload(host, reader, 8)
	assert(reader.current_line_index == 0 and PlayerState.money == 10)
	assert(reader.body_label.visible_characters == -1 and not reader.dialogue_playback.active)
	assert(not reader.is_input_locked and not reader.dialogue_playback.voice.player.playing)
	reader._advance_story()
	assert(reader.current_line_index == 1 and reader.choice_container.visible)
	await _save_paused(host, reader, 9)
	reader = await _reload(host, reader, 9)
	assert(reader.current_line_index == 1 and reader.choice_buttons.size() == 1 and not reader.is_input_locked)
	await reader._choose_branch(reader.story_lines[1].choices[0])
	assert(reader.current_line_index == 2 and PlayerState.money == 17)
	_discard(host, reader)


static func _unfinished_action(host: Node) -> void:
	PlayerState.reset()
	var reader = await _reader(host, {
		"story_id": "slot_wait_fixture",
		"typewriter": false,
		"composition": [{
			"text": "The second reward follows the wait.",
			"actions": [
				{"type": "add_money", "amount": 10},
				{"type": "wait", "duration": 1.0},
				{"type": "add_money", "amount": 20},
			],
		}],
	})
	assert(reader.is_input_locked and PlayerState.money == 10)
	var saved: Resource = await _save_paused(host, reader, 10)
	assert(saved.data.pending_story._checkpoint.continuation.kind == "line_actions")
	assert(saved.data.pending_story._checkpoint.continuation.action_index == 1)
	reader = await _reload(host, reader, 10)
	assert(reader.is_input_locked and PlayerState.money == 10)
	await host.get_tree().create_timer(1.0).timeout
	assert(reader.current_line_index == 0 and not reader.is_input_locked and PlayerState.money == 30)
	await _save_paused(host, reader, 10)
	reader = await _reload(host, reader, 10)
	assert(PlayerState.money == 30 and reader.checkpoint_continuation.is_empty(), "Completed rewards must not run again")
	_discard(host, reader)


static func _intro_and_replay(host: Node) -> void:
	PlayerState.reset()
	var reader = await _reader(host, {
		"story_id": "slot_intro_fixture",
		"typewriter": false,
		"composition": [{"text": "First line.", "actions": [{"type": "add_money", "amount": 5}]}],
	}, 0.0)
	assert(reader.current_line_index == -1 and PlayerState.money == 0)
	await _save_paused(host, reader, 8)
	reader = await _reload(host, reader, 8)
	assert(reader.current_line_index == 0 and PlayerState.money == 5, "Saving before the first section must resume section zero once")
	_discard(host, reader)
	SaveSlotManager.begin_new_run()
	assert(SaveSlotManager.save_slot(8, {"scene": STORY}) == OK)
	assert(SaveSlotManager.autosave_day({"scene": STORY}) == OK)
	PlayerState.set_pending_memory_replay(Payload.normalize({
		"story_id": "slot_replay_fixture",
		"replay": true,
		"composition": [{"text": "Memory.", "typewriter": false}],
	}))
	reader = await _reader(host, PlayerState.get_pending_story())
	assert(reader._is_replay_mode() and not Context.save_block_reason(reader).is_empty())
	var live_data: Dictionary = Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION).data.duplicate(true)
	var replay: Dictionary = PlayerState.get_pending_memory_replay()
	var payload: Dictionary = reader.story_payload.duplicate(true)
	var recovery: PackedByteArray = FileAccess.get_file_as_bytes(PlayerState.SAVE_PATH)
	var slots := _slot_snapshots()
	var daily_key: String = SaveSlotManager._last_daily_save_key
	_open_pause_with_escape(host)
	assert(PauseMenuManager.save_button.disabled, "Gallery replay must keep manual saving disabled")
	PauseMenuManager._show_save_screen("save")
	assert(PauseMenuManager.save_screen.slot_buttons[8].disabled)
	PauseMenuManager._save_requested(8)
	assert(not PauseMenuManager.save_screen.status_label.text.is_empty() and PauseMenuManager.save_screen.status_label.text != "Saved to slot 8.", "A forced UI callback must report replay save denial")
	var replay_context: Dictionary = Context.capture(reader)
	for context: Dictionary in [{}, replay_context]:
		assert(SaveSlotManager.save_slot(8, context) == ERR_UNAUTHORIZED, "Backend manual saves must reject replay even without supplied story context")
		assert(SaveSlotManager.save_slot(7, context) == ERR_UNAUTHORIZED)
		assert(SaveSlotManager.autosave_day(context) == ERR_UNAUTHORIZED, "Replay autosaves must be denied even when this day was already saved")
	assert(_slot_snapshots() == slots, "Replay save attempts must not create or replace any slot")
	assert(SaveSlotManager._last_daily_save_key == daily_key)
	assert(Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION).data == live_data, "Denied replay saves must leave the live run and checkpoint unchanged")
	assert(PlayerState.get_pending_memory_replay() == replay and reader.story_payload == payload)
	assert(FileAccess.get_file_as_bytes(PlayerState.SAVE_PATH) == recovery, "Denied replay saves must not rewrite the live recovery snapshot")
	_escape(host, true)
	assert(not PauseMenuManager.save_screen.visible and PauseMenuManager.visible and host.get_tree().paused)
	_escape(host, false)
	_close_pause_with_escape(host)
	_discard(host, reader)
	assert(PlayerState.get_pending_memory_replay().is_empty())
	assert(Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION).data == live_data)


static func _slot_snapshots() -> Dictionary:
	var snapshots := {}
	for slot in range(1, SaveSlotManager.SLOT_COUNT + 1):
		var path: String = SaveSlotManager.slot_path(slot)
		assert(path.begins_with("res://test_user/"))
		snapshots[slot] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return snapshots


static func _inline_driving_story(host: Node) -> void:
	PlayerState.reset()
	PlayerState.current_stage_type = "short-morning-chill"
	PlayerState.set_current_stage_time("morning")
	PlayerState.set_current_mock_character("ito")
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.ensure_daily_conditions_for_current_day()
	for rule: Dictionary in PlayerState.story_triggers:
		if str(rule.get("id", "")) == "isidro_first_encounter":
			rule["payload_id"] = "slot_inline_fixture"
			rule["payload"] = {
				"story_id": "slot_inline_fixture",
				"return_scene": MAIN,
				"next_scene": MAIN,
				"typewriter": {"characters_per_second": 10},
				"composition": [{"speaker": "Isidro", "text": "Escape must pause this inline reader while the live traffic and driving state remain intact."}],
			}
	var game = load(MAIN).instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = "short-morning-chill"
	host.get_tree().root.add_child(game)
	host.get_tree().current_scene = game
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.distance = 123.0
	game.time_left = 42.0
	game.rng.seed = 20261026
	assert(Spawner.spawn_traffic(game, 1))
	var live_driving: Dictionary = Driving.capture(game)
	game.trip_peak_speed_kmh = 71.0
	assert(game.ride_story_interruption.try_start(game))
	var helper = game.ride_story_interruption
	var reader = helper.reader
	await host.get_tree().create_timer(0.48).timeout
	assert(reader.dialogue_playback.active and game.game_state == "story" and game.process_mode == Node.PROCESS_MODE_DISABLED)
	var saved: Resource = await _save_paused(host, reader, 8)
	assert(saved.metadata.scene == STORY and saved.data.pending_story.story_id == "slot_inline_fixture")
	assert(helper.active and helper.reader == reader and host.get_tree().current_scene == game)
	assert(game.process_mode == Node.PROCESS_MODE_DISABLED and game.distance == 123.0 and game.time_left == 42.0)
	# The fixture's ordinary completion must restore the same driving instance.
	await reader._finish_story()
	assert(not helper.active and host.get_tree().current_scene == game and game.game_state == "playing")
	var resumed_driving: Dictionary = Driving.capture(game)
	live_driving.values["trip_peak_speed_kmh"] = 71.0
	assert(resumed_driving == live_driving, "Pausing and saving an inline VN must preserve every captured driving value, entity, timer and RNG state")
	host.get_tree().current_scene = null
	game.free()
	await host.get_tree().process_frame
	assert(PlayerState._state_batch_depth == 0)
	AmbientAudioManager.stop_all()
	# Give the audio mixer time to release the discarded ride's music stream.
	await host.get_tree().create_timer(0.1).timeout
