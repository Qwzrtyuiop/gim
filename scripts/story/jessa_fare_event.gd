extends RefCounted

const STORY_ID := "jessa_runaway_fare"
const EARNINGS_KEY := "jessa_runaway_fare_earnings"


# Both branches end without payment. Settle when the story is queued, so even
# saving/resuming before the choice cannot accidentally pay the completed ride.
static func prepare(state, payload: Dictionary) -> void:
	if payload.get("story_id", "") != STORY_ID or bool(payload.get("replay", payload.get("memory_replay", false))):
		return
	var result: Dictionary = state.last_stage_result
	if not bool(result.get("completed", false)) or bool(result.get("paid_out", false)) or result.get("character_id", "") != "jessa":
		return
	state._begin_state_batch()
	if result.get("unpaid_story", "") != STORY_ID:
		var earnings := {
			"day": int(result.get("day", state.get_current_day())),
			"fare": int(result.get("fare", 0)),
			"bonus": int(result.get("bonus", 0)),
			"passenger_penalty": int(result.get("passenger_penalty", 0)),
			"total": int(result.get("total", 0)),
		}
		state.set_event_value(EARNINGS_KEY, earnings)
		result["unpaid_story"] = STORY_ID
		for key in ["fare", "bonus", "passenger_penalty", "total"]:
			result[key] = 0
		result["detail_lines"] = [
			"Distance: %dm" % int(result.get("distance", 0)),
			"Unpaid fare: PhP %d" % earnings.total,
			"Passenger left without paying.",
			"Total: PhP 0",
		]
	apply_saved_fare(state, payload)
	state.save_progress()
	state._end_state_batch()


# Memory replay uses the historical fare, never the most recent trip's payout.
static func apply_saved_fare(state, payload: Dictionary) -> void:
	if payload.get("story_id", "") != STORY_ID:
		return
	var earnings: Dictionary = state.event_values.get(EARNINGS_KEY, {})
	if not earnings.has("total"):
		return
	payload["original_ride_earnings"] = earnings.duplicate(true)
	for line: Dictionary in payload.get("composition", []):
		if bool(line.get("ride_fare_line", false)):
			line["text"] = "That'll be %d pesos." % int(earnings.total)
