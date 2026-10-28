extends RefCounted

# Repeatable minor stories have no run-wide consumed flag. The ride result owns
# its one selection, while the ordinary story checkpoint owns reward delivery.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const STORY_IDS := [
	"generic_keep_the_change",
	"generic_a_compliment",
	"generic_an_extra_tip",
	"generic_lucky_day",
	"generic_a_quiet_ride",
	"generic_rounding_up",
	"generic_a_friendly_passenger",
	"generic_a_small_favor",
	"generic_an_unexpected_conversation",
	"generic_a_generous_stranger",
]


static func select(state, result: Dictionary) -> String:
	if state.rng.randf() >= clampf(GameTuning.GENERIC_PASSENGER_EVENT_CHANCE, 0.0, 1.0):
		return ""
	var candidates := eligible_story_ids(result)
	if candidates.is_empty():
		return ""
	return candidates[state.rng.randi_range(0, candidates.size() - 1)]


static func eligible_story_ids(result: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	var had_crash := bool(result.get("had_crash", false)) or int(result.get("vehicle_collision_count", 0)) > 0
	var phase := str(result.get("time_of_day", ""))
	for story_id: String in STORY_IDS:
		if story_id == "generic_a_quiet_ride" and had_crash:
			continue
		if story_id == "generic_keep_the_change" and float(result.get("overtime", 0.0)) > 0.0:
			continue
		if story_id == "generic_an_extra_tip" and phase not in ["morning", "noon"]:
			continue
		candidates.append(story_id)
	return candidates
