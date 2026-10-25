extends RefCounted

# One entry path for card clicks and rides queued by a passenger story.
const MAIN_SCENE := "res://scenes/main.tscn"
const DAY_START_SCENE := "res://scenes/day_start_transition.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"


static func start(character: Dictionary, distance: String, transition_mode: String, return_scene := "") -> Dictionary:
	if PlayerState.is_run_failed():
		return {"scene": GAME_OVER_SCENE, "error": ""}
	if character.is_empty() or str(character.get("id", "")).is_empty():
		return {"scene": "", "error": "That slot is empty."}
	PlayerState._begin_state_batch()
	if not PlayerState.prepare_stage_start_after_transition(distance, transition_mode):
		var error := PlayerState.get_stage_start_error_after_transition(distance, transition_mode)
		PlayerState._end_state_batch()
		return {"scene": "", "error": error}
	PlayerState.set_current_mock_character(str(character.get("id", "")))
	PlayerState.set_current_stage_special_type(str(character.get("stage_special_type", "")))
	PlayerState.set_current_special_stage_id(str(character.get("special_stage_id", "")))
	var show_day_start := PlayerState.will_advance_day(transition_mode) and PlayerState.get_transition_display_day(transition_mode) <= 1
	PlayerState.advance_to_next_stage(transition_mode, distance, str(character.get("stage_traffic", "")))
	PlayerState.clear_pending_trip_selection()
	var target := DAY_START_SCENE if show_day_start and return_scene != HOME_SCENE else MAIN_SCENE
	if PlayerState.is_run_failed():
		target = GAME_OVER_SCENE
	PlayerState.set_resume_scene(target)
	PlayerState._end_state_batch()
	return {"scene": target, "error": ""}
