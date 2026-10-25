extends RefCounted

# Shared by random offers, seeded offers and saved terminal offers. Always use
# the trip's projected day/phase, which can differ from the current clock.
static func supports_time(character: Dictionary, time_of_day: String, day: int) -> bool:
	if day > 0 and int(character.get("unavailable_day", 0)) == day:
		return false
	var times: Variant = character.get("eligible_times", [])
	if not times is Array or times.is_empty():
		return true
	var phase := time_of_day.strip_edges().to_lower()
	if phase.is_empty():
		return false
	for time in times:
		if str(time).strip_edges().to_lower() == phase:
			return true
	return false
