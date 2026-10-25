extends RefCounted
class_name SeededRiderRuntime

const CharacterAvailability := preload("res://scripts/story/character_availability.gd")

static func add_rule(player_state, rule_data: Dictionary) -> void:
	if rule_data.is_empty():
		return

	var normalized_rule: Dictionary = normalize_rule(player_state, rule_data)
	if normalized_rule.is_empty():
		return

	player_state.seeded_rider_rules.append(normalized_rule)
	player_state.save_progress()


static func seed_rider_for_stage(player_state, character_id: String, day: int, time_of_day := "", distance := "", slot := -1, forced_traffic := "", repeatable := false) -> void:
	var rule_data: Dictionary = {
		"character_id": character_id,
		"day": max(1, day),
		"repeatable": bool(repeatable),
	}
	if not str(time_of_day).strip_edges().is_empty():
		rule_data["time_of_day"] = time_of_day
	if not str(distance).strip_edges().is_empty():
		rule_data["distance"] = distance
	if int(slot) >= 0:
		rule_data["slot"] = int(slot)
	if not str(forced_traffic).strip_edges().is_empty():
		rule_data["forced_traffic"] = forced_traffic
	add_rule(player_state, rule_data)


static func clear_rules(player_state) -> void:
	player_state._reset_seeded_rider_state()
	player_state.save_progress()


static func get_rules(player_state) -> Array:
	return player_state.seeded_rider_rules.duplicate(true)


static func consume_player_rules(player_state, rule_ids: Array) -> void:
	if consume_rules(player_state.consumed_seeded_rider_rules, rule_ids):
		player_state.save_progress()


static func normalize_rule(player_state, rule_data: Dictionary) -> Dictionary:
	var explicit_rule_id := str(rule_data.get("id", "")).strip_edges()
	var character_id := str(rule_data.get("character_id", rule_data.get("passenger_id", ""))).strip_edges().to_lower()
	if character_id.is_empty():
		return {}
	if player_state.get_character_by_id(character_id).is_empty():
		return {}

	var normalized_rule: Dictionary = rule_data.duplicate(true)
	normalized_rule["character_id"] = character_id
	normalized_rule.erase("passenger_id")
	if explicit_rule_id.is_empty():
		normalized_rule.erase("id")
	else:
		normalized_rule["id"] = explicit_rule_id
	normalized_rule["id"] = rule_id(normalized_rule)
	if normalized_rule.has("distance"):
		normalized_rule["distance"] = normalize_distance(player_state, str(normalized_rule.get("distance", "")))
	if normalized_rule.has("distances") and normalized_rule.get("distances", null) is Array:
		var normalized_distances: Array[String] = []
		for distance_variant in normalized_rule.get("distances", []):
			var normalized_distance: String = normalize_distance(player_state, str(distance_variant))
			if normalized_distance.is_empty() or normalized_distances.has(normalized_distance):
				continue
			normalized_distances.append(normalized_distance)
		normalized_rule["distances"] = normalized_distances
	_normalize_time_field_aliases(player_state, normalized_rule, "time_of_day", ["phase_of_day", "phase"])
	_normalize_time_array_aliases(player_state, normalized_rule, "times", ["phases"])
	_normalize_time_field_aliases(player_state, normalized_rule, "current_time_of_day", ["current_phase"])
	_normalize_time_array_aliases(player_state, normalized_rule, "current_times", ["current_phases"])
	if normalized_rule.has("forced_traffic"):
		normalized_rule["forced_traffic"] = normalize_traffic(player_state, str(normalized_rule.get("forced_traffic", "")))
	if normalized_rule.has("traffic"):
		normalized_rule["traffic"] = normalize_traffic(player_state, str(normalized_rule.get("traffic", "")))
	return normalized_rule


static func consume_rules(consumed_seeded_rider_rules: Dictionary, rule_ids: Array) -> bool:
	var consumed_any := false
	for rule_id_variant in rule_ids:
		var rule_id := str(rule_id_variant).strip_edges()
		if rule_id.is_empty():
			continue
		if bool(consumed_seeded_rider_rules.get(rule_id, false)):
			continue
		consumed_seeded_rider_rules[rule_id] = true
		consumed_any = true
	return consumed_any


static func get_pool_setup(player_state, selection_context: Dictionary) -> Dictionary:
	if not player_state.are_passengers_available():
		return {"distance_slots": {"short": [], "medium": [], "long": []}, "rule_ids": []}
	var context: Dictionary = normalize_selection_context(player_state, selection_context)
	var distance_slots: Dictionary = {
		"short": [],
		"medium": [],
		"long": [],
	}
	var consumed_character_ids: Dictionary = {}
	var used_rule_ids: Array[String] = []

	for rule_data in player_state.seeded_rider_rules:
		var rule: Dictionary = rule_data
		if not matches_rule(player_state, rule, context):
			continue

		var current_rule_id: String = rule_id(rule)
		if not bool(rule.get("repeatable", false)) and not current_rule_id.is_empty() and bool(player_state.consumed_seeded_rider_rules.get(current_rule_id, false)):
			continue

		var character_id: String = str(rule.get("character_id", rule.get("passenger_id", ""))).strip_edges().to_lower()
		if character_id.is_empty() or consumed_character_ids.has(character_id):
			continue

		var character: Dictionary = player_state.get_character_by_id(character_id)
		if character.is_empty():
			continue
		if not supports_character_time(player_state, character, str(context.get("time_of_day", "")), int(context.get("day", player_state.get_transition_display_day()))):
			continue

		var target_distances: Array[String] = get_target_distances(player_state, rule, character)
		if target_distances.is_empty():
			continue

		for distance_variant in target_distances:
			var distance: String = str(distance_variant)
			if not player_state.STAGE_DIFFICULTIES.has(distance):
				continue

			var slot_index: int = resolve_slot_index(rule, distance_slots[distance])
			if slot_index < 0:
				continue

			var assignment := {
				"character": character.duplicate(true),
				"slot": slot_index,
				"forced_traffic": str(rule.get("forced_traffic", rule.get("traffic", ""))).strip_edges(),
				"forced_distance": distance,
				"rule_id": current_rule_id,
			}
			var existing_assignments: Array = distance_slots[distance]
			existing_assignments.append(assignment)
			distance_slots[distance] = existing_assignments
			consumed_character_ids[character_id] = true
			if not current_rule_id.is_empty():
				used_rule_ids.append(current_rule_id)
			break

	return {
		"distance_slots": distance_slots,
		"rule_ids": used_rule_ids,
	}


static func normalize_selection_context(player_state, selection_context: Dictionary) -> Dictionary:
	var context: Dictionary = selection_context.duplicate(true)
	_normalize_time_field_aliases(player_state, context, "time_of_day", ["phase_of_day", "phase"])
	_normalize_time_field_aliases(player_state, context, "current_time_of_day", ["current_phase"])
	return context


static func matches_rule(player_state, rule_data: Dictionary, selection_context: Dictionary) -> bool:
	if rule_data.is_empty():
		return false

	var upcoming_day: int = int(selection_context.get("day", player_state.get_transition_display_day()))
	var current_day_value: int = int(selection_context.get("current_day", player_state.get_current_day()))
	if rule_data.has("day") and int(rule_data.get("day", 0)) != upcoming_day:
		return false
	if rule_data.has("min_day") and upcoming_day < int(rule_data.get("min_day", upcoming_day)):
		return false
	if rule_data.has("max_day") and upcoming_day > int(rule_data.get("max_day", upcoming_day)):
		return false
	if not _matches_context_array(rule_data.get("days", []), upcoming_day):
		return false

	if rule_data.has("current_day") and int(rule_data.get("current_day", 0)) != current_day_value:
		return false
	if not _matches_context_array(rule_data.get("current_days", []), current_day_value):
		return false

	if not _matches_context_value(rule_data.get("time_of_day", null), selection_context.get("time_of_day", null)):
		return false
	if not _matches_context_array(rule_data.get("times", []), selection_context.get("time_of_day", null)):
		return false
	if not _matches_context_value(rule_data.get("current_time_of_day", null), selection_context.get("current_time_of_day", null)):
		return false
	if not _matches_context_array(rule_data.get("current_times", []), selection_context.get("current_time_of_day", null)):
		return false
	if not _matches_context_value(rule_data.get("current_stage_type", null), selection_context.get("current_stage_type", null)):
		return false
	if not _matches_context_array(rule_data.get("current_stage_types", []), selection_context.get("current_stage_type", null)):
		return false

	return true


static func get_target_distances(player_state, rule_data: Dictionary, character: Dictionary) -> Array[String]:
	var target_distances: Array[String] = []
	if rule_data.has("distance"):
		var normalized_distance: String = normalize_distance(player_state, str(rule_data.get("distance", "")))
		if not normalized_distance.is_empty():
			target_distances.append(normalized_distance)
	elif rule_data.has("distances") and rule_data.get("distances", null) is Array:
		for distance_variant in rule_data.get("distances", []):
			var normalized_distance: String = normalize_distance(player_state, str(distance_variant))
			if normalized_distance.is_empty() or target_distances.has(normalized_distance):
				continue
			target_distances.append(normalized_distance)
	else:
		for distance_variant in character.get("eligible_distances", []):
			var normalized_distance: String = normalize_distance(player_state, str(distance_variant))
			if normalized_distance.is_empty() or target_distances.has(normalized_distance):
				continue
			target_distances.append(normalized_distance)

	if target_distances.is_empty():
		var fallback_distance: String = normalize_distance(player_state, str(character.get("first_distance", "")))
		if not fallback_distance.is_empty():
			target_distances.append(fallback_distance)

	var filtered_distances: Array[String] = []
	for distance_variant in target_distances:
		var distance: String = str(distance_variant)
		var eligible_distances: Array = character.get("eligible_distances", [])
		if eligible_distances.is_empty() or eligible_distances.has(distance):
			filtered_distances.append(distance)
	return filtered_distances


static func supports_character_time(player_state, character: Dictionary, time_of_day: String, day := -1) -> bool:
	return CharacterAvailability.supports_time(
		character,
		normalize_time(player_state, time_of_day),
		day if day > 0 else player_state.get_current_day(),
	)


static func resolve_slot_index(rule_data: Dictionary, current_assignments: Array) -> int:
	var used_slots: Dictionary = {}
	for assignment_variant in current_assignments:
		if not assignment_variant is Dictionary:
			continue
		var assignment: Dictionary = assignment_variant
		used_slots[int(assignment.get("slot", -1))] = true

	if rule_data.has("slot"):
		var requested_slot := clampi(int(rule_data.get("slot", 0)), 0, 2)
		return -1 if used_slots.has(requested_slot) else requested_slot

	for slot_index in range(3):
		if not used_slots.has(slot_index):
			return slot_index
	return -1


static func rule_id(rule_data: Dictionary) -> String:
	var explicit_id := str(rule_data.get("id", "")).strip_edges()
	if not explicit_id.is_empty():
		return explicit_id
	return "seeded:%s:%s:%s:%s" % [
		str(rule_data.get("character_id", "")).strip_edges().to_lower(),
		str(rule_data.get("day", "")).strip_edges(),
		str(rule_data.get("time_of_day", "")).strip_edges().to_lower(),
		str(rule_data.get("distance", "")).strip_edges().to_lower(),
	]


static func normalize_distance(player_state, distance: String) -> String:
	var safe_distance := str(distance).strip_edges().to_lower()
	if safe_distance == "easy":
		safe_distance = "short"
	return safe_distance if player_state.STAGE_DIFFICULTIES.has(safe_distance) else ""


static func normalize_time(player_state, time_of_day: String) -> String:
	var safe_time := str(time_of_day).strip_edges().to_lower()
	return safe_time if player_state.STAGE_TIMES.has(safe_time) else ""


static func _normalize_time_field_aliases(player_state, data: Dictionary, canonical_key: String, alias_keys: Array[String]) -> void:
	var raw_value = data.get(canonical_key, null)
	for alias_key in alias_keys:
		if raw_value == null and data.has(alias_key):
			raw_value = data.get(alias_key)
		data.erase(alias_key)

	if raw_value == null:
		return

	var normalized_time := normalize_time(player_state, str(raw_value))
	if normalized_time.is_empty():
		data.erase(canonical_key)
		return
	data[canonical_key] = normalized_time


static func _normalize_time_array_aliases(player_state, data: Dictionary, canonical_key: String, alias_keys: Array[String]) -> void:
	var raw_values: Array = []
	var canonical_values = data.get(canonical_key, [])
	if canonical_values is Array:
		raw_values.append_array(canonical_values)
	for alias_key in alias_keys:
		var alias_values = data.get(alias_key, [])
		if alias_values is Array:
			raw_values.append_array(alias_values)
		data.erase(alias_key)

	if raw_values.is_empty():
		return

	var normalized_times: Array[String] = []
	for raw_value in raw_values:
		var normalized_time := normalize_time(player_state, str(raw_value))
		if normalized_time.is_empty() or normalized_times.has(normalized_time):
			continue
		normalized_times.append(normalized_time)

	if normalized_times.is_empty():
		data.erase(canonical_key)
		return
	data[canonical_key] = normalized_times


static func normalize_traffic(player_state, traffic_type: String) -> String:
	var safe_traffic := str(traffic_type).strip_edges().to_lower()
	return safe_traffic if player_state.STAGE_TRAFFIC_TYPES.has(safe_traffic) else ""


static func _matches_context_value(expected_value, actual_value) -> bool:
	if expected_value == null:
		return true
	var expected_text := str(expected_value).strip_edges()
	if expected_text.is_empty():
		return true
	return expected_text == str(actual_value).strip_edges()


static func _matches_context_array(expected_values, actual_value) -> bool:
	if not expected_values is Array:
		return true
	var expected_array := expected_values as Array
	if expected_array.is_empty():
		return true
	var actual_text := str(actual_value).strip_edges()
	for value in expected_array:
		if str(value).strip_edges() == actual_text:
			return true
	return false
