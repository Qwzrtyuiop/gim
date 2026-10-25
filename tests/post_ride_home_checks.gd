extends RefCounted

const RESULTS_SCENE := "res://scenes/stage_results.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const SLEEP_SCENE := "res://scenes/sleep_transition.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_daytime_home_rest(host)
	await _test_night_home_sleep(host)
	await _test_day_one_and_used_rest(host)
	await _test_pending_benny_event(host)
	PlayerState.reset()
	print("PASS: post-ride Rest returns home without recovery/time changes, preserves locked offers and day-one entry, and home confirmation owns actual rest/sleep and pending night stories")


static func _setup(completed_phase: String, day := 3) -> void:
	PlayerState.reset()
	PlayerState.current_day = day
	PlayerState.current_phase = "noon" if completed_phase == "morning" else "night"
	PlayerState.current_stage_type = "short-%s-chill" % PlayerState.current_phase
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 2
	PlayerState.gas = 63.0
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	PlayerState.set_pending_trip_selection(RESULTS_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
	var rider := PlayerState.get_character_by_id("generic_guy")
	rider.merge({
		"active_distance": "short",
		"stage_traffic": "chill",
		"stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_NONE,
	}, true)
	PlayerState.lock_pending_trip_selection({"short": [rider], "medium": [], "long": []}, "short")
	PlayerState.set_last_stage_result({
		"character_id": "generic_guy",
		"day": day,
		"stage_type": "short-%s-chill" % completed_phase,
		"difficulty": "short",
		"time_of_day": completed_phase,
		"traffic": "chill",
		"distance": 620,
		"fare": 100,
		"bonus": 0,
		"total": 100,
		"completed": true,
	})


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"stage": PlayerState.current_stage_type,
		"round": PlayerState.stage_round,
		"last_rest": PlayerState.last_rest_day,
		"rests": PlayerState.rests_taken_today,
		"rest_day": PlayerState.rests_taken_day,
		"rest_times": PlayerState.tamad_rest_times_today.duplicate(),
		"night_skip": PlayerState.pending_skip_night_phase,
		"pending_story": PlayerState.get_pending_story(),
		"events": PlayerState.event_values.duplicate(true),
		"consumed": PlayerState.consumed_story_triggers.duplicate(true),
		"result": PlayerState.get_last_stage_result(),
		"pools": PlayerState.get_locked_pending_trip_character_pools(),
	}


static func _go_home(host: Node):
	var results = load(RESULTS_SCENE).instantiate()
	host.get_tree().root.add_child(results)
	await host.get_tree().process_frame
	assert(results.rest_button.visible, "Going home remains available regardless of the daily rest allowance")
	var original := _snapshot()
	results.rest_button.pressed.emit()
	# A second signal before the transition finishes must not grant recovery or
	# start a second scene handoff.
	results.rest_button.pressed.emit()
	await host.get_tree().scene_changed
	var home = host.get_tree().current_scene
	assert(home.scene_file_path == HOME_SCENE)
	assert(_snapshot() == original, "Post-ride Rest is navigation only: no resources, calendar, rest history, story consumption or offer changes")
	assert(not PlayerState.get_pending_trip_selection().is_empty(), "Day-one home must not bounce back to the opening passenger tutorial")
	assert(PlayerState.get_pending_trip_selection().transition_mode == PlayerState.TRANSITION_CURRENT_STAGE)
	assert(PlayerState.resume_scene_path == HOME_SCENE)
	results.free()
	return home


static func _test_daytime_home_rest(host: Node) -> void:
	_setup("morning")
	var home = await _go_home(host)
	assert(PlayerState.current_phase == "noon" and PlayerState.energy == 2)
	home.house.buttons.rest.pressed.emit()
	assert(home.info_overlay.visible and home.info_action == "rest")
	assert(PlayerState.energy == 2 and PlayerState.current_phase == "noon", "Opening the home confirmation also has no rest effects")
	home.rest_confirm.pressed.emit()
	home.rest_confirm.pressed.emit()
	await host.get_tree().create_timer(0.7).timeout
	assert(PlayerState.energy == 4 and PlayerState.current_phase == "night")
	assert(PlayerState.current_day == 3 and PlayerState.stage_round == 4)
	assert(PlayerState.rests_taken_today == 1, "Confirmed home rest recovers and records once")
	host.get_tree().current_scene = null
	home.free()


static func _test_night_home_sleep(host: Node) -> void:
	for completed_phase in ["noon", "night"]:
		_setup(completed_phase)
		var home = await _go_home(host)
		assert(PlayerState.current_phase == "night" and PlayerState.current_day == 3 and PlayerState.energy == 2)
		home.house.buttons.rest.pressed.emit()
		home.rest_confirm.pressed.emit()
		assert(PlayerState.energy == 5 and PlayerState.rests_taken_today == 1, "The home confirmation, not results navigation, grants the nightly recovery")
		await host.get_tree().scene_changed
		var sleep = host.get_tree().current_scene
		assert(sleep.scene_file_path == SLEEP_SCENE)
		await host.get_tree().scene_changed
		var next_home = host.get_tree().current_scene
		assert(next_home.scene_file_path == HOME_SCENE and PlayerState.current_day == 4 and PlayerState.current_phase == "morning")
		assert(PlayerState.energy == 5 and PlayerState.money == 600 and PlayerState.gas == 63.0)
		assert(PlayerState.get_locked_pending_trip_character_pools().is_empty(), "A real new day clears the previous day's offers")
		host.get_tree().current_scene = null
		next_home.free()


static func _test_day_one_and_used_rest(host: Node) -> void:
	_setup("morning", 1)
	PlayerState.last_rest_day = 1
	var home = await _go_home(host)
	assert(not home.tutorial_active and PlayerState.current_day == 1 and PlayerState.current_phase == "noon")
	assert(PlayerState.energy == 2 and PlayerState.last_rest_day == 1)
	host.get_tree().current_scene = null
	home.free()


static func _test_pending_benny_event(host: Node) -> void:
	_setup("noon")
	PlayerState._reset_story_triggers()
	PlayerState.set_event_value("day_2_station_bill", true)
	PlayerState.set_event_value("benny_class_clown_seen", true)
	PlayerState.set_event_value("benny_class_clown_drink_choice", "agree")
	PlayerState.set_pending_night_phase_skip(true)
	var home = await _go_home(host)
	assert(PlayerState.has_pending_night_phase_skip() and PlayerState.get_pending_story().is_empty())
	home.house.buttons.rest.pressed.emit()
	home.rest_confirm.pressed.emit()
	await host.get_tree().scene_changed
	if host.get_tree().current_scene == null or host.get_tree().current_scene.scene_file_path != STORY_SCENE:
		await host.get_tree().scene_changed
	var reader = host.get_tree().current_scene
	assert(reader.scene_file_path == STORY_SCENE and reader.story_id == "benny_tropa_night", "Going home defers the existing night story until the player actually sleeps")
	assert(PlayerState.consumed_story_triggers.get("benny_tropa_night", false))
	await host.get_tree().create_timer(1.1).timeout
	host.get_tree().current_scene = null
	reader.free()
