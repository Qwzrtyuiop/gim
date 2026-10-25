extends RefCounted

# Interrupt a selected passenger before paying for or entering their ride.
# The continuation lives in pending_story, which already uses the save codec.
const Departure := preload("res://scripts/ride_selection/ride_departure.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"


static func begin(character: Dictionary, distance: String, transition_mode: String, forced_first := false) -> bool:
	if PlayerState.is_run_failed() or not PlayerState.get_pending_story().is_empty():
		return false
	var traffic := "chill" if forced_first else str(character.get("stage_traffic", ""))
	var selected_time := PlayerState.get_next_stage_time(transition_mode)
	var context := {
		"character_id": str(character.get("id", "")),
		"time_of_day": selected_time,
		"difficulty": distance,
		"traffic": traffic,
		"stage_type": PlayerState.build_stage_type(distance, selected_time, traffic),
	}
	var trigger := PlayerState.find_story_trigger_for_phase(
		PlayerState.STORY_TRIGGER_PASSENGER_SELECTED,
		PlayerState.get_transition_display_day(transition_mode),
		context,
	)
	if trigger.is_empty():
		return false
	var payload := PlayerState.get_story_payload_for_trigger(trigger)
	if payload.is_empty():
		return false
	var selected_character := character.duplicate(true)
	selected_character["stage_traffic"] = traffic
	payload["_passenger_selection"] = {
		"character": selected_character,
		"distance": distance,
		"transition_mode": transition_mode,
		"day": PlayerState.get_current_day(),
		"time_of_day": PlayerState.get_current_time_of_day(),
		"stage_round": int(PlayerState.stage_round),
		"passengers_open": bool(PlayerState.get_pending_trip_selection().get("passengers_open", false)),
	}
	# Custom passenger stories get the same safe default as Jessa's event.
	if str(payload.get("return_scene", "")).is_empty():
		payload["return_scene"] = SELECTION_SCENE
	if str(payload.get("next_scene", "")).is_empty():
		payload["next_scene"] = SELECTION_SCENE
	PlayerState._begin_state_batch()
	PlayerState.consume_story_trigger(trigger)
	# Character actions without an explicit id belong to this passenger.
	PlayerState.set_current_mock_character(str(character.get("id", "")))
	PlayerState.set_last_seen_story_section(str(payload.get("story_id", "")), 0)
	PlayerState.set_pending_story(payload)
	PlayerState.set_resume_scene(STORY_SCENE)
	PlayerState._end_state_batch()
	return true


static func set_outcome(owner, outcome: String) -> void:
	if _is_replay(owner.story_payload):
		return
	if outcome not in ["return", "ride", "skip"]:
		return
	if not owner.story_payload.has("_passenger_selection"):
		push_warning("selection_outcome requires a passenger-selected story.")
		return
	if outcome == "skip":
		if not PlayerState.advance_story_time({"phases": 1}):
			push_warning("Passenger story phase skip rejected; resolve pending fare, repair, or special trip first.")
			return
		outcome = "return"
	owner.story_payload["_selection_outcome"] = outcome
	owner.story_payload["_story_destination"] = "ride_selection"
	PlayerState.set_pending_story(owner.story_payload)


static func complete(payload: Dictionary, target_scene: String) -> String:
	if _is_replay(payload) or PlayerState.is_run_failed() or target_scene != SELECTION_SCENE:
		return target_scene
	var context: Dictionary = payload.get("_passenger_selection", {})
	if context.is_empty():
		return target_scene
	if payload.has("_selection_completed_scene"):
		return str(payload["_selection_completed_scene"])
	var changed_time := (
		int(context.get("day", -1)) != PlayerState.get_current_day()
		or str(context.get("time_of_day", "")) != PlayerState.get_current_time_of_day()
		or int(context.get("stage_round", -1)) != int(PlayerState.stage_round)
	)
	var pending := PlayerState.get_pending_trip_selection()
	if changed_time or pending.is_empty():
		# New time means new offers, with no additional ride/rest advancement.
		PlayerState.clear_pending_trip_selection()
		PlayerState.set_pending_trip_selection(HOME_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
		pending = PlayerState.get_pending_trip_selection()
	if str(payload.get("_selection_outcome", "return")) == "ride":
		var mode := PlayerState.TRANSITION_CURRENT_STAGE if changed_time else str(context.get("transition_mode", PlayerState.TRANSITION_CURRENT_STAGE))
		var departure := Departure.start(
			Dictionary(context.get("character", {})),
			str(context.get("distance", "short")),
			mode,
			str(pending.get("return_scene", "")),
		)
		if not str(departure.get("scene", "")).is_empty():
			target_scene = str(departure.scene)
		else:
			PlayerState.set_pending_trip_selection_error(str(departure.get("error", "")))
	if target_scene == SELECTION_SCENE and bool(context.get("passengers_open", true)):
		PlayerState.set_pending_passengers_open(true)
	payload["_selection_completed_scene"] = target_scene
	return target_scene


static func _is_replay(payload: Dictionary) -> bool:
	return bool(payload.get("replay", payload.get("memory_replay", false)))
