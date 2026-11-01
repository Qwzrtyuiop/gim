extends RefCounted

# Roll only for a paid arrival; presentation and saved readers reuse the receipt.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")
const CURRENT_VISIT_EVENT := "basketball_current_visit"
const MEMORY_VISITS_EVENT := "basketball_memory_visits"
const OUTCOME_EVENT := "basketball_game_won"
const COURT_DAY := StoryConstants.BACKGROUND_BASKETBALL_DAY
const COURT_NIGHT := StoryConstants.BACKGROUND_BASKETBALL_NIGHT
const TYPES := ["empty", "pickup", "wager"]


static func record_visit() -> String:
	if not PlayerState.pending_memory_replay.is_empty():
		return ""
	var roll: float = PlayerState.rng.randf()
	var kind := "wager"
	if roll < GameTuning.BASKETBALL_EMPTY_CHANCE:
		kind = "empty"
	elif roll < GameTuning.BASKETBALL_EMPTY_CHANCE + GameTuning.BASKETBALL_PICKUP_CHANCE:
		kind = "pickup"
	var story_id := "basketball_" + kind
	if bool(PlayerState.get_event_value(_seen_event(kind), false)):
		story_id += "_short"
	var won: bool = kind != "empty" and PlayerState.rng.randf() < GameTuning.BASKETBALL_WIN_CHANCE
	var visit := {
		"type": kind,
		"won": won,
		"story_id": story_id,
		"background": COURT_NIGHT if PlayerState.get_current_time_of_day() == "night" else COURT_DAY,
	}
	var memories := _dictionary_event(MEMORY_VISITS_EVENT)
	memories[story_id] = visit.duplicate(true)
	PlayerState._begin_state_batch()
	PlayerState.set_event_value(CURRENT_VISIT_EVENT, visit)
	PlayerState.set_event_value(MEMORY_VISITS_EVENT, memories)
	PlayerState.set_event_value(OUTCOME_EVENT, won)
	PlayerState._end_state_batch()
	return story_id


static func players_visible() -> bool:
	return str(_dictionary_event(CURRENT_VISIT_EVENT).get("type", "pickup")) != "empty"


static func configure_payload(payload: Dictionary, use_memory := false) -> void:
	var story_id := str(payload.get("story_id", ""))
	var kind := story_id.trim_prefix("basketball_").trim_suffix("_short")
	if not story_id.begins_with("basketball_") or kind not in TYPES:
		return
	var visit: Dictionary = {}
	var embedded: Variant = payload.get("_basketball_visit", {})
	if embedded is Dictionary:
		visit = embedded.duplicate(true)
	if visit.is_empty():
		if use_memory:
			var remembered: Variant = _dictionary_event(MEMORY_VISITS_EVENT).get(story_id, {})
			if remembered is Dictionary:
				visit = remembered.duplicate(true)
		else:
			visit = _dictionary_event(CURRENT_VISIT_EVENT)
	if str(visit.get("story_id", "")) != story_id:
		# Debug-unlocked memories may not have a played visit to restore.
		visit = {
			"type": kind,
			"won": false,
			"story_id": story_id,
			"background": payload.get("background", COURT_DAY),
		}
	payload["_basketball_visit"] = visit.duplicate(true)
	payload["basketball_players"] = kind != "empty"
	payload["background"] = visit.get("background", COURT_DAY)
	var lines: Array = payload.get("composition", [])
	for line: Dictionary in lines:
		var conditions: Dictionary = line.get("conditions", {})
		var required: Dictionary = conditions.get("required_event_values", {})
		if required.has(OUTCOME_EVENT):
			# Freeze the selected branch into the saved payload, independent of later
			# visits or the active run's state during a gallery replay.
			line["conditions"] = {} if bool(visit.won) else {"any": []}
	if not story_id.ends_with("_short") and not lines.is_empty():
		var actions: Array = lines[0].get("actions", [])
		var seen_event := _seen_event(kind)
		for action: Dictionary in actions:
			if str(action.get("type", "")) == "set_event_value" and str(action.get("id", "")) == seen_event:
				return
		actions.append({
			"type": "set_event_value",
			"id": seen_event,
			"value": true,
		})
		lines[0]["actions"] = actions


static func _seen_event(kind: String) -> String:
	return "basketball_%s_seen" % kind


static func _dictionary_event(event_id: String) -> Dictionary:
	var value: Variant = PlayerState.get_event_value(event_id, {})
	return value.duplicate(true) if value is Dictionary else {}
