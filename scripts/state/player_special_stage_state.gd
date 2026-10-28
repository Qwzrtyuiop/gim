extends RefCounted

const SpecialStages := preload("res://scripts/config/special_stages.gd")
const AlmaDelivery := preload("res://scripts/home/alma_delivery_encounter.gd")
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
	if safe_id == AlmaDelivery.STORY_ID and (state.is_midnight() or not bool(state.get_event_value("alma_first_encounter_seen", false))):
		return false
	var definition := SpecialStages.get_definition(safe_id)
	var repeat_last_stage := bool(definition.get("repeat_last_stage", false))
	if repeat_last_stage:
		var previous_result: Dictionary = state.get_last_stage_result()
		if (
			not bool(previous_result.get("completed", false))
			or int(previous_result.get("day", -1)) != state.get_current_day()
			or str(previous_result.get("time_of_day", "")) != state.get_current_time_of_day()
			or str(previous_result.get("character_id", "")) != str(definition.get("character_id", ""))
		):
			push_warning("Cannot repeat a trip without its completed passenger and calendar slot.")
			return false
		definition["stage_type"] = str(previous_result.get("stage_type", ""))
		definition["target_distance"] = maxf(1.0, float(previous_result.get("target_distance", previous_result.get("distance", 1.0))))
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
	# Scripted driving still uses the daily activity budget and intact hull.
	state.pending_stage_stress_applied = false
	if not state.get_stage_start_error(str(definition["stage_type"]), safe_id).is_empty():
		state._end_state_batch()
		return false
	# Replacing an interrupted ride starts a new leg, never a second shielded ride.
	state.finish_ride_stress_shield()
	var parts: Dictionary = state._parse_stage_type(str(definition["stage_type"]))
	var phase := str(parts["time"])
	var current_phase: String = state.get_current_time_of_day()
	var last_result: Dictionary = state.last_stage_result
	var slot_already_used: bool = (
		int(last_result.get("day", -1)) == state.get_current_day()
		and str(last_result.get("time_of_day", "")) == phase
	)
	if not repeat_last_stage and (state.STAGE_TIMES.find(phase) < state.STAGE_TIMES.find(current_phase) or slot_already_used):
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
	var metadata: Dictionary = definition.get("metadata", {})
	if metadata.has("crash_protection"):
		state.active_event_special_stage["crash_protection_remaining"] = maxi(0, int(metadata.crash_protection))
	state.current_mock_character_id = str(definition.get("character_id", state.current_mock_character_id))
	state.prepare_stage_start(str(definition["stage_type"]))
	if safe_id == AlmaDelivery.STORY_ID:
		# The bar return belongs to successful delivery, not a crash/abandonment.
		state.set_event_value(AlmaDelivery.RETURN_EVENT, {})
	state.pending_story.clear()
	state.pending_result_music.clear()
	state.pending_gameplay_entry_fade_duration = 0.35
	state.resume_scene_path = GAME_SCENE
	# A repeated leg continues its spent slot; normal special stages replace one.
	# Each new driving leg pays entry energy and stress once, without a rider roll.
	state.save_progress()
	state._end_state_batch()
	return true


static func finish(state) -> String:
	if state.active_event_special_stage.is_empty():
		return HOME_SCENE
	state._begin_state_batch()
	state.claim_last_stage_total()
	var result: Dictionary = state.get_last_stage_result()
	var delivered: bool = (
		str(state.active_event_special_stage.get("id", "")) == AlmaDelivery.STORY_ID
		and bool(state.active_event_special_stage.get("completed", false))
		and bool(result.get("completed", false))
		and str(result.get("special_stage_id", "")) == AlmaDelivery.STORY_ID
	)
	state.active_event_special_stage = {}
	if delivered:
		var payload: Dictionary = load("res://scripts/story/story_payload_catalog.gd").build(AlmaDelivery.SUCCESS_STORY_ID)
		payload["return_scene"] = HOME_SCENE
		payload["next_scene"] = HOME_SCENE
		AlmaDelivery.prepare_bar_return()
		state.set_last_seen_story_section(AlmaDelivery.SUCCESS_STORY_ID, 0)
		state.set_pending_story(payload)
		state.resume_scene_path = "res://scenes/story_scene.tscn"
		state.save_progress()
		state._end_state_batch()
		return state.resume_scene_path
	state.resume_scene_path = RESULTS_SCENE
	state.save_progress()
	state._end_state_batch()
	return RESULTS_SCENE
