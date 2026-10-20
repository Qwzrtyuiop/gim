extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const StoryPayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const CONSUMED_KEY := "random_ride:malasakit"
const RESULTS_SCENE := "res://scenes/stage_results.tscn"


# Called only after scheduled/character stories have had first refusal.
static func prepare(state) -> Dictionary:
	var result: Dictionary = state.last_stage_result
	if result.is_empty() or not bool(result.get("completed", false)) or bool(result.get("paid_out", false)):
		return {}
	if bool(result.get("random_event_checked", false)):
		if result.get("random_ride_event", "") == "malasakit" and result.get("random_ride_outcome", "") == "" and state.pending_story.get("story_id", "") == "malasakit":
			return state.pending_story.duplicate(true)
		return {}
	state._begin_state_batch()
	result["random_event_checked"] = true
	var character: Dictionary = state.get_character_by_id(str(result.get("character_id", "")))
	var eligible := bool(character.get("is_generic", false)) and not bool(state.consumed_story_triggers.get(CONSUMED_KEY, false))
	var payload: Dictionary = {}
	if eligible and state.rng.randf() < clampf(GameTuning.MALASAKIT_EVENT_CHANCE, 0.0, 1.0):
		payload = StoryPayloadCatalog.build("malasakit")
		# Keep the exact post-modifier/penalty payout, even across save/resume.
		result["original_ride_earnings"] = {
			"fare": int(result.get("fare", 0)), "bonus": int(result.get("bonus", 0)),
			"passenger_penalty": int(result.get("passenger_penalty", 0)),
			"total": int(result.get("total", 0)),
		}
		result["random_ride_event"] = "malasakit"
		payload["original_ride_earnings"] = result["original_ride_earnings"].duplicate(true)
		payload["return_scene"] = RESULTS_SCENE
		payload["next_scene"] = RESULTS_SCENE
		state.consumed_story_triggers[CONSUMED_KEY] = true
		state.set_pending_story(payload)
	state.save_progress()
	state._end_state_batch()
	return payload


static func resolve_fare(state, story_payload: Dictionary, outcome: String) -> void:
	if bool(story_payload.get("replay", story_payload.get("memory_replay", false))):
		return
	var result: Dictionary = state.last_stage_result
	if story_payload.get("story_id", "") != "malasakit" or result.get("random_ride_event", "") != "malasakit":
		return
	if not outcome in ["collect", "waive"] or not str(result.get("random_ride_outcome", "")).is_empty() or bool(result.get("paid_out", false)):
		return
	state._begin_state_batch()
	result["random_ride_outcome"] = outcome
	if outcome == "waive":
		for key in ["fare", "bonus", "passenger_penalty", "total"]:
			result[key] = 0
		result["detail_lines"] = [
			"Distance: %dm" % int(result.get("distance", 0)),
			"Fare waived: PhP %d" % int(result["original_ride_earnings"]["total"]),
			"Total: PhP 0",
			"Malasakit: +%d%% to all fares" % roundi(GameTuning.MALASAKIT_FARE_BONUS * 100.0),
		]
		state.unlock_achievement("malasakit")
	state.set_event_value("malasakit_outcome", outcome)
	state.save_progress()
	state._end_state_batch()
