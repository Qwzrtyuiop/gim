extends RefCounted

# Individual catches stay hidden until an inventory screen is designed.
const FishSpecies := preload("res://scripts/home/fishing_species_catalog.gd")
const PHASES := ["morning", "noon", "night", "midnight"]


static func record_catch(state, catch_data: Dictionary) -> Dictionary:
	if not state.pending_memory_replay.is_empty():
		return {}
	var catch_details := _validated_catch(catch_data)
	if catch_details.is_empty():
		return {}
	var ranges: Dictionary = {}
	var next_id := 1
	for previous: Dictionary in state.fish_catches:
		next_id = maxi(next_id, int(previous.catch_id) + 1)
		_update_range(ranges, str(previous.fish_id), float(previous.length_cm))
	var record := _make_record(catch_details, next_id, state.get_current_day(), state.get_current_time_of_day(), ranges)
	state.fish_catches.append(record)
	state.save_progress()
	return record.duplicate(true)


static func get_catches(state) -> Array[Dictionary]:
	return state.fish_catches.duplicate(true)


static func size_records(state, fish_id: String) -> Dictionary:
	var smallest := INF
	var largest := -INF
	for record: Dictionary in state.fish_catches:
		if str(record.fish_id) != fish_id:
			continue
		var length_cm := float(record.length_cm)
		smallest = minf(smallest, length_cm)
		largest = maxf(largest, length_cm)
	if not is_finite(smallest):
		return {}
	return {
		"smallest_cm": smallest,
		"largest_cm": largest,
	}


static func normalize_catches(value: Variant) -> Array[Dictionary]:
	var catches: Array[Dictionary] = []
	if not value is Array:
		return catches
	var ranges: Dictionary = {}
	var used_ids: Dictionary = {}
	var next_id := 1
	for entry: Variant in value:
		if not entry is Dictionary:
			continue
		var catch_details := _validated_catch(entry)
		if catch_details.is_empty():
			continue
		var catch_id := _positive_integer(entry.get("catch_id"), next_id)
		if used_ids.has(catch_id):
			catch_id = next_id
		used_ids[catch_id] = true
		next_id = maxi(next_id, catch_id + 1)
		var day := _positive_integer(entry.get("day"), 1)
		var phase := str(entry.get("phase", "morning"))
		catches.append(_make_record(catch_details, catch_id, day, phase, ranges))
	return catches


static func _validated_catch(catch_data: Dictionary) -> Dictionary:
	var fish_id: Variant = catch_data.get("fish_id", "")
	if not fish_id is String:
		return {}
	var definition := FishSpecies.find(fish_id)
	if definition.is_empty():
		return {}
	var length_value: Variant = catch_data.get("length_cm")
	if not (length_value is int or length_value is float):
		return {}
	var length_cm := float(length_value)
	if not is_finite(length_cm) or length_cm < float(definition.min_cm) or length_cm > float(definition.max_cm):
		return {}
	return {
		"fish_id": str(definition.id),
		"length_cm": snappedf(length_cm, 0.1),
	}


static func _make_record(catch_details: Dictionary, catch_id: int, day: int, phase: String, ranges: Dictionary) -> Dictionary:
	var fish_id := str(catch_details.fish_id)
	var length_cm := float(catch_details.length_cm)
	var first_catch := not ranges.has(fish_id)
	var previous_range: Vector2 = ranges.get(fish_id, Vector2(INF, -INF))
	var record := {
		"catch_id": catch_id,
		"fish_id": fish_id,
		"length_cm": length_cm,
		"day": maxi(1, day),
		"phase": phase if PHASES.has(phase) else "morning",
		"is_smallest": first_catch or length_cm < previous_range.x,
		"is_largest": first_catch or length_cm > previous_range.y,
		"first_catch": first_catch,
	}
	_update_range(ranges, fish_id, length_cm)
	return record


static func _update_range(ranges: Dictionary, fish_id: String, length_cm: float) -> void:
	var previous: Vector2 = ranges.get(fish_id, Vector2(INF, -INF))
	ranges[fish_id] = Vector2(minf(previous.x, length_cm), maxf(previous.y, length_cm))


static func _positive_integer(value: Variant, fallback: int) -> int:
	return value if value is int and value > 0 else fallback
