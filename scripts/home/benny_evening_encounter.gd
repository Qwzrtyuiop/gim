extends RefCounted

const TriggerService := preload("res://scripts/story/story_trigger_service.gd")
const TriggerRuntime := preload("res://scripts/story/story_trigger_runtime.gd")
const STORY_ID := "benny_tropa_night"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"


static func queue(state) -> bool:
	if state.get_current_time_of_day() != "night" or not state.has_pending_night_phase_skip() or state.is_run_failed():
		return false
	if not state.pending_story.is_empty() or not state.pending_memory_replay.is_empty() or not state.pending_crash_repair.is_empty() or not state.active_event_special_stage.is_empty():
		return false
	# Check only the reserved evening; other day-end events still belong to sleep.
	var evening_rules: Array = []
	for rule: Dictionary in state.get_story_triggers():
		if str(rule.get("id", "")) == STORY_ID:
			evening_rules.append(rule)
	var day: int = state.get_current_day()
	var trigger := TriggerService.find_story_trigger_for_phase(
		evening_rules,
		state.consumed_story_triggers,
		state.event_values,
		state.STORY_TRIGGER_DAY_END,
		day,
		null,
		TriggerRuntime.build_context(state, day)
	)
	if trigger.is_empty():
		return false
	var payload: Dictionary = state.get_story_payload_for_trigger(trigger)
	if payload.is_empty():
		return false
	payload["return_scene"] = HOME_SCENE
	payload["next_scene"] = HOME_SCENE
	state._begin_state_batch()
	state.clear_pending_trip_selection()
	state.set_pending_trip_selection(HOME_SCENE, state.TRANSITION_CURRENT_STAGE)
	state.clear_pending_sleep_transition_state()
	# Drinking spends tonight without pretending John has already slept.
	state.set_event_value("night_phase_consumed_day", day)
	state.set_pending_story(payload)
	state.consume_story_trigger(trigger)
	state.set_resume_scene(STORY_SCENE)
	state._end_state_batch()
	return true
