extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const REPAIR_SCENE := "res://scenes/repair_transition.tscn"
const SLEEP_SCENE := "res://scenes/sleep_transition.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"


static func begin(player_state) -> void:
	# Keep the original bill when resuming/re-entering a pending repair.
	if not player_state.pending_crash_repair.is_empty():
		return
	player_state._begin_state_batch()
	var cash: int = player_state.money
	var cap := clampi(GameTuning.CRASH_REPAIR_MAX_PERCENT, 0, 50)
	var base := clampi(GameTuning.CRASH_REPAIR_BASE_PERCENT, 0, cap)
	var extra: int = player_state.rng.randi_range(0, maxi(0, GameTuning.CRASH_REPAIR_RANDOM_PERCENT))
	var percent := mini(cap, base + extra)
	var bill := floori(float(cash) * float(percent) / 100.0)
	var days := maxi(1, GameTuning.CRASH_REPAIR_DAYS)
	player_state.pending_crash_repair = {
		"cash_before": cash,
		"cost": bill,
		"percent": percent,
		"cash_after": cash - bill,
		"days": days,
		"crash_day": player_state.get_current_day(),
		"target_day": player_state.get_current_day() + days,
		"transition_started": false,
		"recovery_applied": false,
	}
	player_state.money = cash - bill
	player_state.pending_stage_energy_cost = false
	player_state.pending_trip_selection.clear()
	player_state.pending_sleep_transition_state.clear()
	player_state.pending_story.clear()
	player_state.pending_result_music.clear()
	player_state.pending_gameplay_entry_fade_duration = 0.0
	player_state.current_mock_character_id = ""
	player_state.resume_scene_path = REPAIR_SCENE
	player_state._end_state_batch()


static func start_transition(player_state) -> bool:
	if player_state.pending_crash_repair.is_empty():
		return false
	if bool(player_state.pending_crash_repair.get("transition_started", false)):
		return true
	player_state._begin_state_batch()
	player_state.pending_crash_repair["transition_started"] = true
	player_state.set_pending_trip_selection(REPAIR_SCENE, player_state.TRANSITION_SLEEP_TO_NEXT_DAY, false)
	player_state.resume_scene_path = SLEEP_SCENE
	player_state._end_state_batch()
	return true


static func prepare_recovery_day(player_state) -> void:
	if player_state.pending_crash_repair.is_empty():
		return
	if bool(player_state.pending_crash_repair.get("recovery_applied", false)):
		return
	player_state._begin_state_batch()
	var target_day: int = int(player_state.pending_crash_repair["target_day"])
	# Resolve each crossed date so increasing repair duration cannot bypass debt.
	for day in range(player_state.get_current_day() + 1, target_day + 1):
		player_state.prepare_day_start(day)
		if player_state.is_run_failed():
			break
	var recovery := ceili(player_state.max_energy * clampf(GameTuning.CRASH_REPAIR_ENERGY_RECOVERY_RATIO, 0.0, 1.0))
	player_state.energy = maxi(player_state.energy, recovery)
	player_state.pending_crash_repair["recovery_applied"] = true
	player_state.pending_skip_night_phase = false
	player_state._end_state_batch()


static func finish(player_state) -> void:
	if player_state.pending_crash_repair.is_empty():
		return
	player_state._begin_state_batch()
	player_state.pending_crash_repair.clear()
	player_state.pending_trip_selection.clear()
	player_state.pending_sleep_transition_state.clear()
	player_state.resume_scene_path = GAME_OVER_SCENE if player_state.is_run_failed() else HOME_SCENE
	player_state.save_progress()
	player_state._end_state_batch()
