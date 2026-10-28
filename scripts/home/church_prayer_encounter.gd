extends RefCounted

# Select once for a successful arrival. The inline reader then persists the
# chosen payload/checkpoint, including a randomly selected later prayer.
static func record_visit() -> String:
	var visits: int = PlayerState.record_location_visit("church")
	if visits <= 0:
		return ""
	if visits <= 5:
		return "church_prayer_visit_%d" % visits
	return "church_prayer_short_%d" % PlayerState.rng.randi_range(1, 5)
