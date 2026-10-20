extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const StoryPayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const CONSUMED_KEY := "random_ride:malasakit"
const EPILOGUE_CONSUMED_KEY := "random_ride:malasakit_epilogue"
const WAIVED_EARNINGS_KEY := "malasakit_waived_earnings"
const REPAID_KEY := "malasakit_repaid"
const RESULTS_SCENE := "res://scenes/stage_results.tscn"


# Called only after scheduled/character stories have had first refusal.
static func prepare(state) -> Dictionary:
	var result: Dictionary = state.last_stage_result
	if result.is_empty() or not bool(result.get("completed", false)) or bool(result.get("paid_out", false)):
		return {}
	if bool(result.get("random_event_checked", false)):
		var selected_id := str(result.get("random_story_id", result.get("random_ride_event", "")))
		if not selected_id.is_empty() and state.pending_story.get("story_id", "") == selected_id:
			return state.pending_story.duplicate(true)
		return {}
	state._begin_state_batch()
	result["random_event_checked"] = true
	var character: Dictionary = state.get_character_by_id(str(result.get("character_id", "")))
	var is_generic := bool(character.get("is_generic", false))
	var eligible := is_generic and not bool(state.consumed_story_triggers.get(CONSUMED_KEY, false))
	var payload: Dictionary = {}
	if is_generic and epilogue_is_due(state):
		payload = StoryPayloadCatalog.build("malasakit_epilogue")
		payload["original_ride_earnings"] = state.event_values[WAIVED_EARNINGS_KEY].duplicate(true)
		state.consumed_story_triggers[EPILOGUE_CONSUMED_KEY] = true
	elif eligible and state.rng.randf() < clampf(GameTuning.MALASAKIT_EVENT_CHANCE, 0.0, 1.0):
		payload = StoryPayloadCatalog.build("malasakit")
		# Keep the exact post-modifier/penalty payout, even across save/resume.
		result["original_ride_earnings"] = {
			"fare": int(result.get("fare", 0)), "bonus": int(result.get("bonus", 0)),
			"passenger_penalty": int(result.get("passenger_penalty", 0)),
			"total": int(result.get("total", 0)),
		}
		result["random_ride_event"] = "malasakit"
		payload["original_ride_earnings"] = result["original_ride_earnings"].duplicate(true)
		state.consumed_story_triggers[CONSUMED_KEY] = true
	if not payload.is_empty():
		result["random_story_id"] = payload["story_id"]
		payload["return_scene"] = RESULTS_SCENE
		payload["next_scene"] = RESULTS_SCENE
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
		var waived_earnings: Dictionary = result["original_ride_earnings"].duplicate(true)
		waived_earnings["day"] = int(result.get("day", state.get_current_day()))
		state.set_event_value(WAIVED_EARNINGS_KEY, waived_earnings)
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


static func epilogue_is_due(state) -> bool:
	if state.event_values.get("malasakit_outcome", "") != "waive":
		return false
	if bool(state.consumed_story_triggers.get(EPILOGUE_CONSUMED_KEY, false)) or bool(state.event_values.get(REPAID_KEY, false)):
		return false
	var earnings: Dictionary = state.event_values.get(WAIVED_EARNINGS_KEY, {})
	if not earnings.has("total") or not earnings.has("day"):
		return false
	return state.get_current_day() >= int(earnings["day"]) + maxi(1, GameTuning.MALASAKIT_EPILOGUE_DELAY_DAYS)


static func repay_malasakit_fare(state, story_payload: Dictionary) -> void:
	if bool(story_payload.get("replay", story_payload.get("memory_replay", false))):
		return
	if story_payload.get("story_id", "") != "malasakit_epilogue" or state.event_values.get("malasakit_outcome", "") != "waive":
		return
	if not bool(state.consumed_story_triggers.get(EPILOGUE_CONSUMED_KEY, false)) or bool(state.event_values.get(REPAID_KEY, false)):
		return
	var earnings: Dictionary = state.event_values.get(WAIVED_EARNINGS_KEY, {})
	if not earnings.has("total"):
		return
	state._begin_state_batch()
	state.set_event_value(REPAID_KEY, true)
	state.add_money(maxi(0, int(earnings["total"])))
	state.save_progress()
	state._end_state_batch()


# Recover the exact historical amount from older saves when their snapshot remains.
# Never substitute a later ride's fare if the original snapshot is no longer there.
static func migrate_waived_earnings(state) -> bool:
	if state.event_values.get("malasakit_outcome", "") != "waive" or state.event_values.has(WAIVED_EARNINGS_KEY):
		return false
	var source: Dictionary = state.last_stage_result
	if source.get("random_ride_event", "") != "malasakit":
		source = state.pending_story if state.pending_story.get("story_id", "") == "malasakit" else {}
	var earnings: Dictionary = source.get("original_ride_earnings", {})
	if not earnings.has("total"):
		return false
	earnings = earnings.duplicate(true)
	earnings["day"] = int(source.get("day", state.get_current_day()))
	state.event_values[WAIVED_EARNINGS_KEY] = earnings
	return true
