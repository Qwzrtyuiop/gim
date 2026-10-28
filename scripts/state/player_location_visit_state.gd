extends RefCounted

# Location visit claims and counters use the existing persisted event ledger.
const DAILY_VISITS_EVENT := "daily_location_visit_days"
const VISIT_LOCATIONS := ["park", "church"]


static func has_visited_today(state, location_id: String) -> bool:
	var location := location_id.strip_edges().to_lower()
	if not VISIT_LOCATIONS.has(location):
		return false
	var visits := _visit_days(state)
	return int(visits.get(location, 0)) == state.get_current_day()


static func record_visit(state, location_id: String) -> int:
	var location := location_id.strip_edges().to_lower()
	if not VISIT_LOCATIONS.has(location) or not state.pending_memory_replay.is_empty() or has_visited_today(state, location):
		return 0
	var visits := _visit_days(state)
	var counter_event := "%s_visit_count" % location
	var visit_count := maxi(0, int(state.get_event_value(counter_event, 0))) + 1
	state._begin_state_batch()
	visits[location] = state.get_current_day()
	state.set_event_value(DAILY_VISITS_EVENT, visits)
	state.set_event_value(counter_event, visit_count)
	state._end_state_batch()
	return visit_count


static func _visit_days(state) -> Dictionary:
	var stored: Variant = state.get_event_value(DAILY_VISITS_EVENT, {})
	return stored.duplicate(true) if stored is Dictionary else {}
