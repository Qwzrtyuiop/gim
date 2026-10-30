extends RefCounted

# Narrative commands queue the handoff; the current dialogue still finishes normally.
const Catalog := preload("res://scripts/story/story_action_catalog.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const StoryTime := preload("res://scripts/state/player_story_time_state.gd")
const PassengerStory := preload("res://scripts/ride_selection/passenger_story.gd")
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"


static func supports(action_type: String) -> bool:
	return action_type in ["advance_time", "skip_days", "skip_phases", "queue_story", "return_to", "selection_outcome", "end_run"]


static func run(owner, action: Dictionary) -> void:
	if bool(owner.story_payload.get("replay", owner.story_payload.get("memory_replay", false))):
		return
	var type := Catalog.canonical_type(str(action.get("type", "")))
	match type:
		"selection_outcome":
			PassengerStory.set_outcome(owner, str(action.get("outcome", "")))
		"advance_time", "skip_days", "skip_phases":
			var options := action.duplicate(true)
			if type == "skip_days":
				options["days"] = action.get("amount", 1)
			elif type == "skip_phases":
				options["phases"] = action.get("amount", 1)
			if PlayerState.advance_story_time(options):
				owner.story_payload["_story_destination"] = "home"
				PlayerState.set_pending_story(owner.story_payload)
			else:
				var reason := StoryTime.validation_error(options)
				push_warning("Story time advance rejected: %s" % (reason if not reason.is_empty() else "resolve any failed run, active repair/special trip, or pending fare choice first"))
		"return_to":
			var chosen_destination := str(action.get("destination", ""))
			if Catalog.DESTINATIONS.has(chosen_destination):
				owner.story_payload["_story_destination"] = chosen_destination
				PlayerState.set_pending_story(owner.story_payload)
		"queue_story":
			var id := str(action.get("id", "")).strip_edges().to_lower()
			if id == str(owner.story_payload.get("story_id", "")) or PayloadCatalog.build(id).is_empty():
				push_warning("Cannot queue unknown story or the current story: %s" % id)
				return
			owner.story_payload["_queued_story_id"] = id
			PlayerState.set_pending_story(owner.story_payload)
		"end_run":
			PlayerState.fail_run(str(action.get("reason", "")))


static func destination(owner, fallback: String) -> String:
	if bool(owner.story_payload.get("replay", owner.story_payload.get("memory_replay", false))):
		return fallback
	if PlayerState.is_run_failed():
		return GAME_OVER_SCENE
	var requested := str(owner.story_payload.get("_story_destination", ""))
	return str(Catalog.DESTINATIONS.get(requested, fallback))


static func queued_story(owner, target_scene: String) -> Dictionary:
	if bool(owner.story_payload.get("replay", owner.story_payload.get("memory_replay", false))) or PlayerState.is_run_failed():
		return {}
	var id := str(owner.story_payload.get("_queued_story_id", ""))
	if id.is_empty():
		return {}
	var payload := PayloadCatalog.build(id)
	if not payload.is_empty():
		payload["return_scene"] = target_scene
		payload["next_scene"] = target_scene
		for key in ["_passenger_selection", "_selection_outcome", "_driving_interruption"]:
			if owner.story_payload.has(key):
				var value = owner.story_payload[key]
				payload[key] = value.duplicate(true) if value is Dictionary else value
	return payload


static func prepare_destination(owner, target_scene: String) -> void:
	# Direct story handoffs enter the current calendar slot rather than advancing a ride.
	if not owner.story_payload.has("_story_destination"):
		return
	if owner.story_payload.has("_passenger_selection") and target_scene == Catalog.DESTINATIONS.ride_selection:
		# The passenger continuation preserves the original offers/rest mode, or
		# rebuilds selection for a changed clock at the final end of a story chain.
		return
	PlayerState.claim_last_stage_total()
	PlayerState.clear_pending_sleep_transition_state()
	if target_scene in [HOME_SCENE, Catalog.DESTINATIONS.store, Catalog.DESTINATIONS.ride_selection]:
		PlayerState.set_pending_trip_selection(HOME_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)


static func resume_destination(target_scene: String) -> String:
	# A chapter can end at the menu; Continue should then return to the hub.
	return HOME_SCENE if target_scene == Catalog.DESTINATIONS.main_menu else target_scene
