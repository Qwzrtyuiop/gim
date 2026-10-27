extends RefCounted

const Flow := preload("res://scripts/game/game_flow_controller.gd")
const Economy := preload("res://scripts/game/game_economy_manager.gd")
const Interruption := preload("res://scripts/game/ride_story_interruption.gd")
const Triggers := preload("res://scripts/story/story_trigger_service.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const MemoryCatalog := preload("res://scripts/story/story_memory_catalog.gd")
const StoryFlow := preload("res://scripts/story/story_game_flow.gd")
const Spawner := preload("res://scripts/game/vehicle_spawner.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const Conditions := preload("res://scripts/story/story_conditions.gd")
const EVENT_ID := "isidro_first_encounter"
const SEEN_EVENT := "isidro_first_encounter_seen"
const STAGE := "short-morning-chill"
const MAIN := "res://scenes/main.tscn"
const STORY := "res://scenes/story_scene.tscn"
const REPAIR := "res://scenes/repair_transition.tscn"
const RESULTS := "res://scenes/stage_results.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_rule_content_and_migration()
	await _test_authored_outcomes(host)
	await _test_thresholds(host)
	_test_accepted_hits_and_reset(host)
	for language in ["english", "tagalog"]:
		for cause in ["speed", "collision"]:
			await _test_live_resume(host, language, cause)
	await _test_chain(host)
	await _test_fatal_live(host)
	await _test_standalone_checkpoint(host, false, "english")
	await _test_standalone_checkpoint(host, true, "tagalog")
	await _test_replay(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	StoryLanguageManager.set_language("english")
	print("PASS: Isidro unsafe-driving trigger, authored bribe/fine branches and capped payment, name reveal, no-fare results, generic live-pause/resume and checkpoint safeguards, fatal repair priority and replay isolation")


static func _setup(character_id := "ito", day := 1) -> void:
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = day
	PlayerState.stage_round = 3
	PlayerState.set_current_stage_time("morning")
	PlayerState.current_stage_type = STAGE
	PlayerState.money = 500
	PlayerState.energy = 8
	PlayerState.gas = 80
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.set_current_mock_character(character_id)
	PlayerState.ensure_daily_conditions_for_current_day()
	assert(PlayerState.get_unique_character_progress("ito") == 0)
	assert(not PlayerState.has_event_value("day_2_station_bill"))


static func _game(host: Node):
	# The controller's resumable-story contract is separate from Isidro's authored
	# early ending. Keep its pause/traffic/audio/restart cases on an explicit fixture.
	for rule: Dictionary in PlayerState.story_triggers:
		if str(rule.get("id", "")) == EVENT_ID:
			rule["payload_id"] = "isidro_runtime_fixture"
			rule["payload"] = {
				"story_id": "isidro_runtime_fixture",
				"return_scene": MAIN,
				"next_scene": MAIN,
				"composition": [{"speaker": "Isidro", "text": "Runtime fixture.", "actions": [{"type": "set_event_value", "id": SEEN_EVENT, "value": true}]}],
			}
	var game = load(MAIN).instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = STAGE
	host.get_tree().root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.distance = 123.0
	game.target_distance = 1000000.0
	game.time_left = 99.0
	game.overtime_seconds = 2.0
	game.passenger_rule_violation_count = 2
	game.rng.seed = 20261026
	return game


static func _speed(game, kmh: float) -> void:
	game.player_speed = kmh / game.SPEEDOMETER_BASE_MAX_KMH * game.SPEEDOMETER_REFERENCE_MAX_SPEED


static func _free_game(host: Node, game) -> void:
	if host.get_tree().current_scene == game:
		host.get_tree().current_scene = null
	# Matrix cases must cancel the reader's pending intro as well.
	if is_instance_valid(game.ride_story_interruption.overlay):
		game.ride_story_interruption.overlay.free()
	game.free()


static func _test_rule_content_and_migration() -> void:
	_setup()
	assert(is_equal_approx(Tuning.ISIDRO_FIRST_EVENT_SPEED_KMH, 70.0))
	assert(PlayerState.STORY_TRIGGER_DRIVING == "driving")
	var context := {"character_id": "ito", "unsafe_driving": true, "character_progress": 0, "time_of_day": "morning"}
	assert(PlayerState.find_story_trigger_for_phase("driving", 1, context).get("id") == EVENT_ID, "No bond, completed-ride count or Day 2 bill is required")
	context.unsafe_driving = false
	assert(PlayerState.find_story_trigger_for_phase("driving", 1, context).is_empty())
	context.erase("unsafe_driving")
	assert(PlayerState.find_story_trigger_for_phase("driving", 1, context).is_empty())
	for language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(language)
		var payload := PayloadCatalog.build(EVENT_ID)
		assert(payload.return_scene == MAIN and payload.next_scene == MAIN and payload.driving_outcome == "end_without_fare")
		if language == "tagalog":
			assert(payload.composition.size() == 2 and payload.chapter_title == "to be translated" and payload.composition[0].text == "to be translated")
		else:
			assert(payload.composition.size() == 84 and payload.composition[1].speaker == "Isidro")
			assert(payload.composition[1].speaker_display_name == "???")
	PlayerState.story_triggers = PlayerState.story_triggers.filter(func(rule: Dictionary): return rule.get("id") != EVENT_ID)
	PlayerState.consumed_story_triggers["existing_custom_event"] = true
	var path := "res://test_user/isidro_missing_builtin.tres"
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, path))
	assert(PlayerState.consumed_story_triggers.get("existing_custom_event", false))
	assert(PlayerState.find_story_trigger_for_phase("driving", 1, {"character_id": "ito", "unsafe_driving": true}).get("id") == EVENT_ID)
	var rules := PlayerState.story_triggers.duplicate(true)
	assert(not Triggers.ensure_required_story_triggers(PlayerState.story_triggers) and rules == PlayerState.story_triggers)
	_setup("ito", 2)
	assert(PlayerState.find_story_trigger_for_phase("stage_complete", 2, {"character_id": "ito", "time_of_day": "morning"}).get("id") == "day_2_station_bill", "Scheduled post-ride stories keep their separate phase and priority")
	assert(PlayerState.find_story_trigger_for_phase("driving", 2, {"character_id": "ito", "unsafe_driving": true}).get("id") == EVENT_ID)
	_setup()
	Economy.store_stage_result(STAGE, "short", "morning", "chill", "", "", 200.0, 200.0, 0.5, 0.0, 0.0, 10.0, 2.0, 0, {"peak_speed_kmh": 90.0, "vehicle_collision_count": 2})
	assert(Economy.stage_complete_story_payload(STAGE, "short", "morning", "chill").is_empty(), "The event is not delayed until results")
	assert(not PlayerState.consumed_story_triggers.get(EVENT_ID, false))


static func _test_authored_outcomes(host: Node) -> void:
	for language in ["english", "tagalog"]:
		for fixture: Dictionary in [{"cash": 500, "choice": 0}, {"cash": 75, "choice": 0}, {"cash": 2500, "choice": 1}]:
			_setup()
			StoryLanguageManager.set_language(language)
			PlayerState.money = fixture.cash
			var payload := PayloadCatalog.build(EVENT_ID)
			payload["music"] = {}
			payload["_driving_interruption"] = {"stage_type": STAGE, "difficulty": "short", "time_of_day": "morning", "traffic": "chill", "distance": 123.0, "target_distance": 1000.0, "peak_speed_kmh": 71.0, "vehicle_collision_count": 0}
			PlayerState.set_pending_story(payload)
			var destinations: Array = []
			var reader = load(STORY).instantiate()
			reader.inline_complete_callback = func(destination_scene: String): destinations.append(destination_scene)
			host.get_tree().root.add_child(reader)
			await _ready_reader(host, reader)
			if language == "english":
				assert(not PlayerState.get_event_value("isidro_name_revealed", false))
				await reader._show_line(21)
				await reader._show_line(28)
			assert(PlayerState.get_event_value("isidro_name_revealed", false))
			var choices: Array = reader._current_line().choices
			assert(Conditions.matches_story_conditions(choices[1]) == (int(fixture.cash) >= 2000))
			await reader._choose_branch(choices[int(fixture.choice)])
			if language == "english":
				await reader._show_line(34 if int(fixture.choice) == 0 else 67)
			var expected_cash := maxi(0, int(fixture.cash) - 200)
			assert(PlayerState.money == expected_cash)
			# A reached payment checkpoint reloads without charging a second time.
			var path := "res://test_user/isidro_authored_payment.tres"
			Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
			reader.free()
			PlayerState.reset()
			assert(Codec.load_from_path(PlayerState, path))
			reader = load(STORY).instantiate()
			reader.inline_complete_callback = func(destination: String): destinations.append(destination)
			host.get_tree().root.add_child(reader)
			await _ready_reader(host, reader)
			assert(PlayerState.money == expected_cash)
			if language == "english":
				await reader._show_line(49 if int(fixture.choice) == 0 else 82)
			assert(PlayerState.get_event_value(SEEN_EVENT, false))
			assert(PlayerState.get_event_value("isidro_first_encounter_choice") == ("bribe" if int(fixture.choice) == 0 else "fine"))
			await reader._finish_story()
			var result := PlayerState.get_last_stage_result()
			assert(destinations == [RESULTS] and result.completed and result.ended_early)
			assert(result.fare == 0 and result.bonus == 0 and result.total == 0 and PlayerState.money == expected_cash)
			assert(PlayerState.current_phase == "noon" and PlayerState.current_day == 1)
			var state := _economy()
			assert(Interruption.resolve_destination(reader.story_payload, MAIN) == RESULTS and _economy() == state)
			reader.free()
	# A fatal hit still takes the repair route even with the authored early ending.
	_setup()
	PlayerState.energy = 0
	PlayerState.set_event_value(SEEN_EVENT, true)
	var fatal_payload := PayloadCatalog.build(EVENT_ID)
	fatal_payload["_driving_interruption"] = {"stage_type": STAGE, "time_of_day": "morning", "distance": 123.0, "target_distance": 1000.0, "vehicle_collision_count": 1, "fatal_collision_detail": "Authored fatal ending."}
	assert(Interruption.resolve_destination(fatal_payload, MAIN) == REPAIR)
	_assert_repair_once(fatal_payload)


static func _test_thresholds(host: Node) -> void:
	for fixture: Dictionary in [
		{"speed": 0.0, "collisions": 0, "eligible": false},
		{"speed": 70.0, "collisions": 0, "eligible": false},
		{"speed": 70.0001, "collisions": 0, "eligible": true},
		{"speed": 12.0, "collisions": 1, "eligible": true},
		{"speed": 80.0, "collisions": 2, "eligible": true},
	]:
		_setup()
		var game = _game(host)
		_speed(game, fixture.speed)
		game.trip_vehicle_collision_count = fixture.collisions
		var before := _economy()
		var distance: float = game.distance
		var time: float = game.time_left
		Flow.update_progress(game, 0.1)
		assert(game.ride_story_interruption.active == fixture.eligible, "Strictly over 70 and one collision are independent alternatives")
		if fixture.eligible:
			assert(game.game_state == "story" and game.distance == distance and game.time_left == time and _economy() == before, "Interrupt before distance, fuel, time, costs or completion advance")
			assert(PlayerState.pending_story._driving_interruption.vehicle_collision_count == fixture.collisions)
			await _ready_reader(host, game.ride_story_interruption.reader)
		else:
			assert(game.game_state == "playing" and PlayerState.pending_story.is_empty())
		_free_game(host, game)
	_setup("generic_guy")
	var other = _game(host)
	_speed(other, 90.0)
	other.trip_vehicle_collision_count = 3
	Flow.update_progress(other, 0.1)
	assert(not other.ride_story_interruption.active and not PlayerState.consumed_story_triggers.get(EVENT_ID, false))
	_free_game(host, other)


static func _test_accepted_hits_and_reset(host: Node) -> void:
	_setup("generic_guy")
	var game = _game(host)
	game.player_hit_invincible_timer = 1.0
	Flow.handle_player_hit(game, "Invincible contact.", 1)
	assert(game.trip_vehicle_collision_count == 0 and PlayerState.energy == 8)
	game.player_hit_invincible_timer = 0.0
	Flow.handle_player_hit(game, "Accepted vehicle collision.", 1)
	assert(game.trip_vehicle_collision_count == 1 and PlayerState.energy == 7)
	Flow.handle_player_hit(game, "Duplicate overlap.", 1)
	assert(game.trip_vehicle_collision_count == 1 and PlayerState.energy == 7)
	game.player_hit_invincible_timer = 0.0
	game.game_state = "YOU MADE IT"
	Flow.handle_player_hit(game, "Contact after completion.", 1)
	assert(game.trip_vehicle_collision_count == 1 and PlayerState.energy == 7)
	game.trip_peak_speed_kmh = 99.0
	Flow.reset_game(game)
	assert(is_zero_approx(game.trip_peak_speed_kmh) and game.trip_vehicle_collision_count == 0)
	PlayerState.set_current_mock_character("ito")
	assert(not game.ride_story_interruption.try_start(game), "Reset cannot leak an older ride's unsafe conditions")
	_free_game(host, game)


static func _test_live_resume(host: Node, language: String, cause: String) -> void:
	_setup()
	StoryLanguageManager.set_language(language)
	var game = _game(host)
	host.get_tree().current_scene = game
	Spawner.spawn_traffic(game, 1)
	assert(not game.active_entities.is_empty())
	var timer := Timer.new()
	timer.wait_time = 5.0
	game.add_child(timer)
	timer.start()
	var bgm: AudioStreamPlayer = game.audio_manager.stage_bgm_player
	var playback = bgm.get_stream_playback()
	var paused_audio := AudioStreamPlayer.new()
	paused_audio.stream = bgm.stream
	game.add_child(paused_audio)
	AudioSettingsManager.register_player(paused_audio, "sfx")
	paused_audio.play()
	paused_audio.stream_paused = true
	var before := _economy()
	if cause == "speed":
		_speed(game, 70.25)
		Flow.update_progress(game, 0.25)
		assert(Flow.current_speed_kmh(game) == 70 and game.trip_peak_speed_kmh > 70.0)
	else:
		Flow.handle_player_hit(game, "Test vehicle collision.", 1)
		before.energy -= 1
	var helper = game.ride_story_interruption
	assert(helper.active and game.process_mode == Node.PROCESS_MODE_DISABLED and helper.overlay.layer == 600)
	assert(bgm.stream_paused and paused_audio.stream_paused)
	assert(PlayerState.resume_scene_path == STORY and PlayerState.pending_story._driving_interruption.stage_type == STAGE)
	assert(_economy() == before and PlayerState.last_stage_result.is_empty())
	var world := _world(game, timer)
	var reader = helper.reader
	await _ready_reader(host, reader)
	assert(PlayerState.get_event_value(SEEN_EVENT, false) and _world(game, timer) == world and _economy() == before)
	assert(PauseMenuManager.request_toggle() and host.get_tree().paused and PauseMenuManager.layer > helper.overlay.layer)
	await host.get_tree().create_timer(0.03).timeout
	assert(_world(game, timer) == world)
	PauseMenuManager.hide_pause_menu()
	assert(helper.active and game.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(not helper.try_start(game), "An active conversation cannot nest itself")
	await reader._finish_story()
	assert(not helper.active and helper.reader == null and helper.overlay == null)
	assert(host.get_tree().current_scene == game and game.game_state == "playing" and game.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(_world(game, timer) == world and _economy() == before and PlayerState.pending_story.is_empty(), "Resume the same live ride without restart, fare, recovery, costs, time or bond changes")
	assert(not bgm.stream_paused and bgm.get_stream_playback() == playback and paused_audio.stream_paused)
	game.trip_peak_speed_kmh = 100.0
	game.trip_vehicle_collision_count = 4
	assert(not helper.try_start(game), "The consumed first encounter cannot repeat")
	Flow.store_stage_result(game)
	var result := PlayerState.get_last_stage_result()
	assert(result.peak_speed_kmh == 100.0 and result.vehicle_collision_count == 4)
	_free_game(host, game)


static func _test_chain(host: Node) -> void:
	_setup()
	var game = _game(host)
	host.get_tree().current_scene = game
	_speed(game, 71.0)
	Flow.update_progress(game, 0.1)
	var helper = game.ride_story_interruption
	var reader = helper.reader
	await _ready_reader(host, reader)
	var before := _economy()
	var context: Dictionary = reader.story_payload._driving_interruption.duplicate(true)
	StoryFlow.run(reader, {"type": "queue_story", "id": "jessa_second_encounter"})
	await reader._finish_story()
	var deadline := Time.get_ticks_msec() + 5000
	while helper.reader == null or helper.reader == reader:
		assert(Time.get_ticks_msec() < deadline)
		await host.get_tree().process_frame
	var chained = helper.reader
	await _ready_reader(host, chained)
	assert(chained.story_payload.story_id == "jessa_second_encounter" and chained.story_payload._driving_interruption == context)
	assert(game.game_state == "story" and game.process_mode == Node.PROCESS_MODE_DISABLED and _economy() == before)
	await chained._finish_story()
	assert(not helper.active and game.game_state == "playing" and _economy() == before)
	_free_game(host, game)


static func _test_fatal_live(host: Node) -> void:
	_setup()
	var game = _game(host)
	host.get_tree().current_scene = game
	PlayerState.energy = 1
	Flow.handle_player_hit(game, "Fatal test vehicle collision.", 1)
	assert(game.game_state == "story" and game.trip_vehicle_collision_count == 1 and PlayerState.energy == 0)
	assert(PlayerState.pending_crash_repair.is_empty() and PlayerState.last_stage_result.is_empty() and PlayerState.money == 500, "Fatal hits show Isidro before charging the repair")
	var reader = game.ride_story_interruption.reader
	await _ready_reader(host, reader)
	var payload: Dictionary = reader.story_payload.duplicate(true)
	await reader._finish_story()
	await host.get_tree().scene_changed
	var repair = host.get_tree().current_scene
	_assert_repair_once(payload)
	assert(repair.scene_file_path == REPAIR and not is_instance_valid(game))
	host.get_tree().current_scene = null
	repair.free()


static func _test_standalone_checkpoint(host: Node, fatal: bool, language: String) -> void:
	_setup()
	StoryLanguageManager.set_language(language)
	var game = _game(host)
	if fatal:
		PlayerState.energy = 1
		Flow.handle_player_hit(game, "Saved fatal test vehicle collision.", 1)
	else:
		_speed(game, 71.0)
		Flow.update_progress(game, 0.1)
	var before := _economy()
	var path := "res://test_user/isidro_inline_%s.tres" % language
	assert(not PlayerState.get_event_value(SEEN_EVENT, false))
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	# Keep the saved pre-line checkpoint, but let this disposable intro finish
	# before freeing its reader so its awaited tween can release normally.
	await _ready_reader(host, game.ride_story_interruption.reader)
	_free_game(host, game)
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, path))
	assert(PlayerState.resume_scene_path == STORY and PlayerState.pending_story._driving_interruption.vehicle_collision_count == int(fatal))
	assert(_economy() == before and PlayerState.consumed_story_triggers.get(EVENT_ID, false))
	var reader = load(STORY).instantiate()
	host.get_tree().root.add_child(reader)
	await _ready_reader(host, reader)
	assert(PlayerState.get_event_value(SEEN_EVENT, false) and _economy() == before)
	var payload: Dictionary = reader.story_payload.duplicate(true)
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	reader.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, path))
	reader = load(STORY).instantiate()
	host.get_tree().root.add_child(reader)
	await _ready_reader(host, reader)
	assert(reader.current_line_index == 0 and _economy() == before and PlayerState.get_event_value(SEEN_EVENT, false))
	await reader._finish_story()
	await host.get_tree().scene_changed
	var destination = host.get_tree().current_scene
	if fatal:
		assert(destination.scene_file_path == REPAIR)
		_assert_repair_once(payload)
	else:
		destination.set_process(false)
		assert(destination.scene_file_path == MAIN and _economy() == before and PlayerState.pending_story.is_empty())
		assert(destination.distance == 0.0 and not PlayerState.pending_stage_energy_cost, "Standalone return restarts driving without another entry charge")
		destination.trip_peak_speed_kmh = 99.0
		assert(not destination.ride_story_interruption.try_start(destination))
	host.get_tree().current_scene = null
	destination.free()
	reader.free()


static func _assert_repair_once(payload: Dictionary) -> void:
	var repair := PlayerState.get_pending_crash_repair()
	var result := PlayerState.get_last_stage_result()
	assert(not repair.is_empty() and not result.completed and result.vehicle_collision_count == 1)
	assert(result.total == 0 and PlayerState.money == 500 - int(repair.cost) and PlayerState.energy == 0)
	assert(PlayerState.get_unique_character_progress("ito") == 0 and PlayerState.character_completed_rides.is_empty())
	assert(PlayerState.get_event_value(SEEN_EVENT, false) and PlayerState.pending_story.is_empty())
	var cash := PlayerState.money
	assert(Interruption.resolve_destination(payload, MAIN) == REPAIR)
	assert(PlayerState.get_pending_crash_repair() == repair and PlayerState.get_last_stage_result() == result and PlayerState.money == cash, "Repeated fatal resolution cannot create a second repair bill")


static func _test_replay(host: Node) -> void:
	for language in ["english", "tagalog"]:
		_setup()
		StoryLanguageManager.set_language(language)
		var payload := MemoryCatalog.build_memory_payload(EVENT_ID, MAIN)
		payload["_driving_interruption"] = {"fatal_collision_detail": "Replay only.", "vehicle_collision_count": 1}
		PlayerState.energy = 0
		var before := _economy()
		var events := PlayerState.event_values.duplicate(true)
		var consumed := PlayerState.consumed_story_triggers.duplicate(true)
		PlayerState.set_pending_memory_replay(payload)
		var reader = load(STORY).instantiate()
		host.get_tree().root.add_child(reader)
		await _ready_reader(host, reader)
		if language == "english":
			await reader._show_line(21)
			await reader._show_line(34)
			await reader._show_line(49)
		else:
			await reader._show_line(1)
		assert(PlayerState.event_values == events and PlayerState.consumed_story_triggers == consumed and _economy() == before)
		assert(PlayerState.pending_story.is_empty() and PlayerState.pending_crash_repair.is_empty())
		assert(Interruption.resolve_destination(reader.story_payload, MAIN) == MAIN and PlayerState.pending_crash_repair.is_empty(), "Replays cannot mark, consume, charge or repair the live run")
		reader.free()
		assert(PlayerState.get_pending_memory_replay().is_empty())


static func _ready_reader(host: Node, reader) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while reader.current_line_index < 0 or reader.is_input_locked:
		if reader.current_line_index >= 0 and is_instance_valid(reader.dialogue_playback) and reader.dialogue_playback.active:
			reader.dialogue_playback.finish_now()
		assert(Time.get_ticks_msec() < deadline, "The story must finish its normal presentation/actions")
		await host.get_tree().create_timer(0.01).timeout
	assert(not reader.is_finishing_story)


static func _world(game, timer: Timer) -> Dictionary:
	var traffic: Array = []
	for entity: Dictionary in game.active_entities:
		traffic.append({"id": entity.sprite.get_instance_id(), "position": entity.sprite.position, "speed": entity.world_speed, "lane": entity.lane})
	return {"id": game.get_instance_id(), "distance": game.distance, "time": game.time_left, "overtime": game.overtime_seconds, "speed": game.player_speed, "lane": game.player_lane, "spawn": game.spawn_timers.duplicate(), "recovery": game.player_hit_recovery_timer, "invincibility": game.player_hit_invincible_timer, "warnings": game.passenger_rule_violation_count, "rng": game.rng.state, "timer": timer.time_left, "traffic": traffic}


static func _economy() -> Dictionary:
	return {"money": PlayerState.money, "energy": PlayerState.energy, "gas": PlayerState.gas, "day": PlayerState.current_day, "phase": PlayerState.current_phase, "round": PlayerState.stage_round, "karma": PlayerState.karma, "progress": PlayerState.get_unique_character_progress("ito"), "rides": PlayerState.character_completed_rides.duplicate(true)}
