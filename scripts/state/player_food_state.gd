extends RefCounted

# Successful food purchases use the existing persisted event ledger.
const FOOD_PURCHASE_EVENT := "food_purchase_phase"


static func has_eaten_this_phase(state) -> bool:
	var claim: Variant = state.get_event_value(FOOD_PURCHASE_EVENT, {})
	if not claim is Dictionary:
		return false
	return (
		int(claim.get("day", 0)) == state.get_current_day()
		and str(claim.get("phase", "")) == state.get_current_time_of_day()
	)


static func record_purchase(state) -> bool:
	if not state.pending_memory_replay.is_empty() or has_eaten_this_phase(state):
		return false
	state.set_event_value(FOOD_PURCHASE_EVENT, {
		"day": state.get_current_day(),
		"phase": state.get_current_time_of_day(),
	})
	return true
