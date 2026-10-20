extends RefCounted

const SpecialStages := preload("res://scripts/config/special_stages.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const RESULTS_SCENE := "res://scenes/stage_results.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"


static func definition_error(state, definition: Dictionary) -> String:
	var descriptor := str(definition.get("stage_type", ""))
	var parts: Dictionary = state._parse_stage_type(descriptor)
	if descriptor.is_empty() or descriptor != state.build_stage_type(
		str(parts["difficulty"]), str(parts["time"]), str(parts["traffic"])
	):
		return "Special stage needs an explicit valid stage_type."
	return ""


static func begin(state, stage_id: String, _continuation: String) -> bool:
	var safe_id: String = state.normalize_special_stage_id(stage_id)
	if not state.active_event_special_stage.is_empty():
		return str(state.active_event_special_stage.get("id", "")) == safe_id
	var definition := SpecialStages.get_definition(safe_id)
	var error := definition_error(state, definition)
	if not error.is_empty():
		push_warning("Cannot start special stage '%s': %s" % [safe_id, error])
		return false

	state._begin_state_batch()
	# The event may have interrupted a results screen before its fare was paid.
	state.claim_last_stage_total()
	# A repair-day event may replace the trip after recovery.
	if not state.pending_crash_repair.is_empty():
		state.prepare_crash_repair_day()
		state.finish_crash_repair()
	var parts: Dictionary = state._parse_stage_type(str(definition["stage_type"]))
	var phase := str(parts["time"])
	var current_phase: String = state.get_current_time_of_day()
	var last_result: Dictionary = state.last_stage_result
	var slot_already_used: bool = (
		int(last_result.get("day", -1)) == state.get_current_day()
		and str(last_result.get("time_of_day", "")) == phase
	)
	if state.STAGE_TIMES.find(phase) < state.STAGE_TIMES.find(current_phase) or slot_already_used:
		state.prepare_day_start(state.get_current_day() + 1)
	state.pending_trip_selection.clear()
	state.pending_sleep_transition_state.clear()
	state.pending_story.clear()
	state.pending_skip_night_phase = false
	if state.is_run_failed():
		state.resume_scene_path = GAME_OVER_SCENE
		state.save_progress()
		state._end_state_batch()
		return true
	state.current_phase = phase
	state.current_stage_type = str(definition["stage_type"])
	state.current_stage_special_type = state.STAGE_SPECIAL_TYPE_SPECIAL
	state.current_special_stage_id = safe_id
	state.stage_round += 1
	state.active_event_special_stage = {
		"id": safe_id,
		"definition": definition,
		"completed": false,
	}
	state.current_mock_character_id = str(definition.get("character_id", state.current_mock_character_id))
	state.current_trip_had_crash = false
	state.current_trip_low_energy = false
	state.current_trip_low_gas = false
	state.pending_stage_energy_cost = false
	state.pending_story.clear()
	state.pending_result_music.clear()
	state.pending_gameplay_entry_fade_duration = 0.35
	state.resume_scene_path = GAME_SCENE
	# This replaces a calendar slot without an energy/fuel check or rider roll.
	state.save_progress()
	state._end_state_batch()
	return true


static func finish(state) -> String:
	if state.active_event_special_stage.is_empty():
		return HOME_SCENE
	state._begin_state_batch()
	state.claim_last_stage_total()
	state.active_event_special_stage = {}
	state.resume_scene_path = RESULTS_SCENE
	state.save_progress()
	state._end_state_batch()
	return RESULTS_SCENE
