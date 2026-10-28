extends RefCounted

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const StoryTime := preload("res://scripts/state/player_story_time_state.gd")


static func run() -> void:
	_test_phase_and_day_rules()
	_test_phase_weather()
	_test_collection_boundaries()
	_test_refusals()
	PlayerState.reset()
	print("PASS: narrative phase/day advancement, per-date debt/weather, explicit recovery, saved context and rejected invalid transitions")


static func _test_phase_and_day_rules() -> void:
	PlayerState.reset()
	PlayerState.energy = 4
	PlayerState.gas = 37.0
	PlayerState.stage_round = 9
	PlayerState.current_stage_type = "long-morning-traffic-jam"
	PlayerState.current_mock_character_id = "benny"
	PlayerState.pending_story = {"story_id": "skip_fixture", "composition": [{"text": "An afternoon passes."}]}
	PlayerState.resume_scene_path = "res://scenes/story_scene.tscn"
	PlayerState.set_last_stage_result({"total": 275})
	PlayerState.set_pending_trip_selection("res://scenes/stage_results.tscn", PlayerState.TRANSITION_CURRENT_STAGE)
	PlayerState.set_pending_sleep_transition_state({"resume_step": "old_step"})
	PlayerState.pending_skip_night_phase = true
	var story_before: Dictionary = PlayerState.get_pending_story()
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	assert(PlayerState.advance_story_time({"phases": 1}))
	assert(PlayerState.get_current_day() == 1 and PlayerState.get_current_time_of_day() == "noon")
	assert(PlayerState.current_stage_type == "long-noon-traffic-jam")
	assert(PlayerState.energy == 4 and PlayerState.gas == 37.0 and PlayerState.stage_round == 9)
	assert(PlayerState.money == 275 and PlayerState.last_stage_result.paid_out)
	assert(PlayerState.pending_trip_selection.is_empty() and PlayerState.pending_sleep_transition_state.is_empty())
	assert(not PlayerState.pending_skip_night_phase and not PlayerState.pending_stage_energy_cost)
	assert(PlayerState.pending_story == story_before and PlayerState.current_mock_character_id == "benny")
	assert(PlayerState.resume_scene_path == "res://scenes/story_scene.tscn")
	assert(PlayerState.get_meta("test_save_count", 0) - saves == 1)
	assert(PlayerState.advance_story_time({"phases": 2, "recover_energy": 2}))
	assert(PlayerState.get_current_day() == 2 and PlayerState.get_current_time_of_day() == "morning")
	assert(PlayerState.energy == 5 and PlayerState.money == 275 and PlayerState.stage_round == 9, "Explicit recovery is capped at the five-point daily energy budget")
	assert(PlayerState.daily_conditions_day == 2)
	assert(PlayerState.advance_story_time({"days": 2, "restore_energy": true}))
	assert(PlayerState.get_current_day() == 4 and PlayerState.get_current_time_of_day() == "morning")
	assert(PlayerState.energy == PlayerState.max_energy and PlayerState.gas == 37.0)
	Codec.save_to_path(PlayerState, "res://test_user/story_time.tres", PlayerState.SAVE_VERSION)
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/story_time.tres"))
	assert(PlayerState.get_current_day() == 4 and PlayerState.pending_story == story_before)
	assert(PlayerState.money == 275 and PlayerState.stage_round == 9)


static func _test_phase_weather() -> void:
	PlayerState.reset()
	PlayerState.prepare_day_start(2)
	PlayerState.weather_phase_cache[PlayerState._weather_phase_key(2, "morning")] = PlayerState.DEFAULT_WEATHER
	PlayerState.weather_phase_cache[PlayerState._weather_phase_key(2, "noon")] = PlayerState.WEATHER_RAIN
	PlayerState.current_weather = PlayerState.DEFAULT_WEATHER
	assert(PlayerState.advance_story_time({"phases": 1}))
	assert(PlayerState.get_current_time_of_day() == "noon")
	assert(PlayerState.current_weather == PlayerState.WEATHER_RAIN, "Time advancement must refresh the reached phase's weather snapshot")
	assert(PlayerState.get_stage_weather("noon") == PlayerState.WEATHER_RAIN)


static func _test_collection_boundaries() -> void:
	PlayerState.reset()
	PlayerState.current_day = 6
	PlayerState.current_phase = "night"
	PlayerState.money = 10000
	PlayerState.energy = 2
	assert(PlayerState.advance_story_time({"days": 10}))
	assert(PlayerState.get_current_day() == 16 and PlayerState.daily_conditions_day == 16)
	assert(PlayerState.last_debt_collection_day == 15)
	assert(PlayerState.money == 2500 and PlayerState.remaining_debt == 42500)
	assert(PlayerState.energy == 2)
	for day in range(7, 17):
		assert(PlayerState.weather_forecasts.has(day))
	PlayerState.reset()
	PlayerState.current_day = 14
	PlayerState.current_phase = "night"
	PlayerState.debt_goal_index = 1
	PlayerState.money = 100
	PlayerState.energy = 2
	assert(PlayerState.advance_story_time({"days": 10, "restore_energy": true}))
	assert(PlayerState.is_run_failed() and PlayerState.get_current_day() == 15)
	assert(PlayerState.energy == 2, "Failed collections stop the jump before recovery")


static func _test_refusals() -> void:
	for options in [{}, {"days": 0}, {"days": -1}, {"days": 1, "phases": 1}, {"phases": 1.5}, {"days": "2"}, {"days": StoryTime.MAX_DAYS + 1}, {"phases": StoryTime.MAX_PHASES + 1}, {"days": 1, "recover_energy": -1}, {"days": 1, "restore_energy": "yes"}, {"days": 1, "restore_energy": true, "recover_energy": 1}]:
		PlayerState.reset()
		var saves: int = PlayerState.get_meta("test_save_count", 0)
		assert(not PlayerState.advance_story_time(options))
		assert(PlayerState.get_current_day() == 1 and PlayerState.get_current_time_of_day() == "morning")
		assert(PlayerState.get_meta("test_save_count", 0) == saves)
	PlayerState.reset()
	PlayerState.pending_crash_repair = {"target_day": 2}
	assert(not PlayerState.advance_story_time({"days": 1}))
	assert(PlayerState.pending_crash_repair == {"target_day": 2})
	PlayerState.pending_crash_repair.clear()
	PlayerState.active_event_special_stage = {"id": "live_stage"}
	assert(not PlayerState.advance_story_time({"days": 1}))
	PlayerState.active_event_special_stage.clear()
	PlayerState.set_last_stage_result({"total": 100, "random_ride_event": "malasakit"})
	assert(not PlayerState.advance_story_time({"days": 1}))
	assert(PlayerState.money == 0 and not PlayerState.last_stage_result.paid_out)
