extends RefCounted

const PlayerDayPhaseTracker := preload("res://scripts/state/player_day_phase_tracker.gd")
const SaveGameContext := preload("res://scripts/save/save_game_context.gd")


static func begin_stage_sequence(player_state) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var slots := tree.root.get_node_or_null("SaveSlotManager") if tree != null else null
	if slots != null:
		slots.begin_new_run()
	player_state._begin_state_batch()
	apply_new_run_defaults(player_state)
	player_state.last_stage_result.clear()
	player_state.save_progress()
	player_state._end_state_batch()
	SaveGameContext.request_daily_autosave(player_state)


static func current_stage_type(player_state) -> String:
	if player_state.current_stage_type.is_empty():
		player_state.current_stage_type = player_state.FIRST_STAGE_TYPE
	player_state.current_stage_type = PlayerDayPhaseTracker.stage_type_for_phase(player_state, player_state.current_stage_type, player_state.get_current_time_of_day())
	return player_state.current_stage_type


static func normalize_transition_mode(player_state, transition_mode: String) -> String:
	if transition_mode == player_state.TRANSITION_CURRENT_STAGE:
		return transition_mode
	if transition_mode == player_state.TRANSITION_REST_TO_NIGHT:
		return transition_mode
	if transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY:
		return transition_mode
	if transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		return transition_mode
	return player_state.TRANSITION_RIDE


static func can_rest_after_stage(player_state) -> bool:
	var current_time: String = player_state.get_current_time_of_day()
	return (current_time == "morning" or current_time == "noon") and player_state.last_rest_day != player_state.get_current_day()


static func can_rest_after_stage_result(player_state, stage_time_of_day: String, stage_day: int = -1) -> bool:
	var safe_time: String = str(stage_time_of_day).strip_edges().to_lower()
	if not player_state.STAGE_TIMES.has(safe_time):
		return false
	var safe_day: int = int(stage_day) if int(stage_day) > 0 else player_state.get_current_day()
	return (safe_time == "morning" or safe_time == "noon") and player_state.last_rest_day != safe_day


static func has_rested_today(player_state) -> bool:
	return player_state.last_rest_day == player_state.get_current_day()


static func advance_to_next_stage(player_state, transition_mode: String = "", selected_difficulty: String = "", forced_traffic: String = "") -> String:
	var safe_transition_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	var current_time_before_advance: String = player_state.get_current_time_of_day()
	var next_time: String = player_state.get_next_stage_time(safe_transition_mode)
	var current_day_before_advance: int = player_state.get_current_day()
	var next_day: int = current_day_before_advance
	var advances_day: bool = player_state.will_advance_day(safe_transition_mode)

	player_state._begin_state_batch()
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NIGHT or safe_transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY:
		player_state.last_rest_day = player_state.get_current_day()

	if advances_day:
		next_day += 1

	var next_stage: String = player_state._random_stage_type_for_time(next_time, selected_difficulty, forced_traffic)
	player_state.stage_round += 1
	player_state.current_day = next_day
	player_state.current_phase = next_time
	player_state.current_stage_type = next_stage
	if player_state.current_day != current_day_before_advance:
		player_state._reset_daily_consumable_counters(player_state.current_day)
		player_state._roll_daily_conditions_for_day(player_state.current_day)
	if advances_day:
		player_state._resolve_debt_collection_for_day(player_state.current_day)
	if player_state.pending_skip_night_phase and current_time_before_advance != "night" and next_time == "morning" and player_state.current_day > current_day_before_advance:
		player_state.pending_skip_night_phase = false
	player_state.save_progress()
	player_state._end_state_batch()
	if player_state.current_day != current_day_before_advance:
		SaveGameContext.request_daily_autosave(player_state)
	return player_state.current_stage_type


static func advance_phase_after_stage_result(player_state, stage_time_of_day: String) -> bool:
	var advanced: bool = PlayerDayPhaseTracker.advance_after_stage_result(player_state, stage_time_of_day)
	if advanced:
		player_state.save_progress()
	return advanced


static func prepare_day_start(player_state, target_day: int) -> void:
	var safe_target_day: int = maxi(1, target_day)
	if player_state.get_current_day() == safe_target_day and player_state.get_current_time_of_day() == "morning":
		return

	player_state._begin_state_batch()
	player_state.current_day = safe_target_day
	player_state.current_phase = "morning"
	player_state.current_stage_type = player_state.build_stage_type("short", "morning", "chill")
	player_state.current_stage_special_type = player_state.STAGE_SPECIAL_TYPE_NONE
	player_state.current_special_stage_id = ""
	player_state.pending_stage_stress_applied = false
	player_state._reset_daily_consumable_counters(player_state.current_day)
	player_state._roll_daily_conditions_for_day(player_state.current_day)
	player_state._resolve_debt_collection_for_day(player_state.current_day)
	player_state.save_progress()
	player_state._end_state_batch()
	SaveGameContext.request_daily_autosave(player_state)


static func set_current_stage_time(player_state, day_time: String) -> void:
	var safe_time: String = day_time if player_state.STAGE_TIMES.has(day_time) else "morning"
	var stage_parts: Dictionary = player_state._parse_stage_type(current_stage_type(player_state))
	player_state.current_phase = safe_time
	player_state.current_stage_type = player_state.build_stage_type(
		str(stage_parts.get("difficulty", "short")),
		safe_time,
		str(stage_parts.get("traffic", "chill"))
	)
	player_state.current_stage_special_type = player_state.STAGE_SPECIAL_TYPE_NONE
	player_state.current_special_stage_id = ""
	player_state.save_progress()


static func reset_daily_run_state(player_state) -> void:
	player_state.last_rest_day = 0
	player_state.yosi_bought_today = 0
	player_state.yosi_bought_day = 1
	player_state.yosi_bought_total = 0
	player_state.rests_taken_today = 0
	player_state.rests_taken_day = 1
	player_state.tamad_rest_day = 1
	player_state.tamad_rest_times_today.clear()
	player_state.rides_completed_today = 0
	player_state.rides_completed_day = 1
	player_state.non_gas_store_purchases_this_week = 0
	player_state.clean_stage_streak = 0
	player_state.current_trip_had_crash = false
	player_state.current_trip_high_stress = false
	player_state.current_trip_low_gas = false
	player_state.low_resource_trip_count = 0
	player_state.low_both_resource_trip_count = 0


static func apply_new_run_defaults(player_state) -> void:
	player_state.stage_round = 0
	player_state.current_stage_type = player_state.FIRST_STAGE_TYPE
	player_state.current_stage_special_type = player_state.STAGE_SPECIAL_TYPE_NONE
	player_state.current_special_stage_id = ""
	player_state.current_day = 1
	player_state.current_phase = "morning"
	player_state._reset_weather_state()
	player_state._reset_pending_runtime_state()
	reset_daily_run_state(player_state)
	player_state._reset_debt_and_failure_state()
	player_state._reset_story_triggers()


static func should_skip_night_phase_transition(player_state, transition_mode: String, current_time: String) -> bool:
	if not player_state.pending_skip_night_phase:
		return false
	var safe_transition_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	var safe_current_time: String = str(current_time).strip_edges().to_lower()
	if safe_current_time == "night":
		return false
	if safe_transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY or safe_transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY:
		return false
	if safe_current_time == "noon":
		return safe_transition_mode == player_state.TRANSITION_RIDE
	return safe_current_time == "morning" and safe_transition_mode == player_state.TRANSITION_REST_TO_NIGHT
