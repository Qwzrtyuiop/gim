extends RefCounted

# A counted arrival selects one scene; the VN checkpoint saves that selection.
static func record_visit() -> String:
	var visits: int = PlayerState.record_location_visit("park")
	if visits <= 0:
		return ""
	if visits <= 5:
		return "park_visit_%d" % visits
	return "park_short_%d" % PlayerState.rng.randi_range(1, 5)
