extends RefCounted

# Conditional line routing and story eligibility predicates.

const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")
const PlayerUpgradeState := preload("res://scripts/state/player_upgrade_state.gd")
const MAX_CONDITION_DEPTH := 16
const NUMERIC_CONDITION_FIELDS := ["energy", "gas", "karma", "day", "week", "remaining_debt", "character_progress"]
const EVENT_RANGE_KEYS := ["equals", "min", "max", "less_than", "more_than"]


static func resolve_visible_story_index(story_lines: Array[Dictionary], index: int) -> int:
	var candidate_index: int = index
	var safety_limit: int = story_lines.size() + 1
	while candidate_index >= 0 and candidate_index < story_lines.size() and safety_limit > 0:
		var line: Dictionary = story_lines[candidate_index]
		if bool(line.get("_runtime_story_end", false)):
			return -1
		if matches_story_conditions(line):
			return candidate_index
		candidate_index = next_story_index_from_hidden_line(line, candidate_index)
		safety_limit -= 1
	return -1


static func next_story_index_from_hidden_line(line: Dictionary, fallback_index: int) -> int:
	var skip_index: int = int(line.get("skip_index", line.get("next_index_if_skipped", -1)))
	if skip_index >= 0:
		return skip_index
	return next_story_index_from_line(line, fallback_index)


static func next_story_index_from_line(line: Dictionary, fallback_index: int) -> int:
	var next_index: int = int(line.get("next_index", fallback_index + 1))
	if next_index == fallback_index:
		return fallback_index + 1
	return next_index


static func matches_story_conditions(data: Dictionary) -> bool:
	if data.is_empty():
		return true

	var condition_source: Dictionary = data
	var nested_conditions: Variant = data.get("conditions", null)
	if data.has("conditions") and not nested_conditions is Dictionary:
		return false
	if nested_conditions is Dictionary:
		condition_source = (nested_conditions as Dictionary).duplicate(true)
		for key_variant in data.keys():
			var key: String = str(key_variant)
			if key == "conditions":
				continue
			if key.begins_with("required_") or key.begins_with("forbidden_"):
				condition_source[key] = data[key_variant]
	if nested_conditions is Dictionary and not _valid_composition(condition_source, 0):
		return false
	return _matches_condition_source(condition_source, nested_conditions is Dictionary, 0)


static func _matches_condition_source(condition_source: Dictionary, allow_plain_keys: bool, depth: int) -> bool:
	if depth > MAX_CONDITION_DEPTH:
		return false

	var event_values: Dictionary = PlayerState.get_event_values()
	if not matches_required_achievements(condition_source):
		return false
	if not matches_forbidden_achievements(condition_source):
		return false
	if not StoryEventHandler.matches_required_events(event_values, condition_array(condition_source, "required_events", "required_event")):
		return false
	if not StoryEventHandler.matches_forbidden_events(event_values, condition_array(condition_source, "forbidden_events", "forbidden_event")):
		return false
	if not StoryEventHandler.matches_event_values(event_values, condition_dictionary(condition_source, "required_event_values", "required_event_value"), true):
		return false
	if not StoryEventHandler.matches_event_values(event_values, condition_dictionary(condition_source, "forbidden_event_values", "forbidden_event_value"), false):
		return false
	if not matches_money_conditions(condition_source):
		return false
	if not _matches_game_values(condition_source, allow_plain_keys):
		return false
	if not _matches_event_ranges(condition_source, event_values, allow_plain_keys):
		return false
	if allow_plain_keys and not _matches_composition(condition_source, depth):
		return false
	return true


static func _matches_game_values(source: Dictionary, allow_plain: bool) -> bool:
	var values := {
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"karma": PlayerState.karma,
		"day": PlayerState.get_current_day(),
		"week": PlayerState.get_week_number(),
		"remaining_debt": PlayerState.remaining_debt,
	}
	for field: String in values:
		if not _matches_numeric_field(source, field, float(values[field]), allow_plain):
			return false
	if _has_numeric_field(source, "character_progress", allow_plain):
		var character_id := str(source.get("character_id", source.get("required_character_id", ""))).strip_edges().to_lower()
		if character_id.is_empty() or PlayerState.get_character_by_id(character_id).is_empty():
			return false
		if not _matches_numeric_field(source, "character_progress", PlayerState.get_unique_character_progress(character_id), allow_plain):
			return false
	var phase: String = PlayerState.get_current_time_of_day()
	if not _matches_text_field(source, "phase", phase, allow_plain):
		return false
	if not _matches_text_field(source, "time_of_day", phase, allow_plain):
		return false
	# Read the active saved setting; evaluating conditions must not roll weather or save.
	if not _matches_text_field(source, "weather", str(PlayerState.current_weather), allow_plain):
		return false
	for prefix in ["", "min_", "max_"]:
		var key: String = "%supgrade_levels" % prefix
		var bounds: Variant = source.get(key, {}) if allow_plain else {}
		if source.has("required_%s" % key):
			bounds = source["required_%s" % key]
		if not bounds is Dictionary:
			return false
		for upgrade_id in bounds:
			var expected: Variant = bounds[upgrade_id]
			if not _is_number(expected) or float(expected) < 0.0 or float(expected) != floorf(float(expected)):
				return false
			if typeof(upgrade_id) not in [TYPE_STRING, TYPE_STRING_NAME]:
				return false
			var definition := PlayerUpgradeState.story_upgrade_definition(str(upgrade_id))
			if definition.is_empty():
				return false
			var actual: int = PlayerState.get_upgrade_level(str(definition.id))
			if prefix.is_empty() and not is_equal_approx(actual, float(expected)):
				return false
			if prefix == "min_" and actual < float(expected):
				return false
			if prefix == "max_" and actual > float(expected):
				return false
	return true


static func _has_numeric_field(source: Dictionary, field: String, allow_plain: bool) -> bool:
	for prefix in ["", "min_", "max_"]:
		if source.has("required_%s%s" % [prefix, field]) or (allow_plain and source.has("%s%s" % [prefix, field])):
			return true
	return false


static func _matches_numeric_field(source: Dictionary, field: String, actual: float, allow_plain: bool) -> bool:
	for prefix in ["", "min_", "max_"]:
		var keys: Array[String] = ["required_%s%s" % [prefix, field]]
		if allow_plain:
			keys.append("%s%s" % [prefix, field])
		for key in keys:
			if not source.has(key):
				continue
			var expected: Variant = source[key]
			if not _is_number(expected):
				return false
			if prefix.is_empty() and not is_equal_approx(actual, float(expected)):
				return false
			if prefix == "min_" and actual < float(expected):
				return false
			if prefix == "max_" and actual > float(expected):
				return false
	return true


static func _matches_text_field(source: Dictionary, field: String, actual: String, allow_plain: bool) -> bool:
	var keys: Array[String] = ["required_%s" % field]
	if allow_plain:
		keys.append(field)
	for key in keys:
		if source.has(key) and str(source[key]).strip_edges().to_lower() != actual.strip_edges().to_lower():
			return false
	return true


static func _matches_event_ranges(source: Dictionary, events: Dictionary, allow_plain: bool) -> bool:
	var ranges: Variant = source.get("event_value_ranges", {}) if allow_plain else {}
	if source.has("required_event_value_ranges"):
		ranges = source.required_event_value_ranges
	if not ranges is Dictionary:
		return false
	for event_id in ranges:
		if not events.has(event_id) or not _is_number(events[event_id]):
			return false
		var limits: Variant = ranges[event_id]
		if not limits is Dictionary:
			return false
		var value := float(events[event_id])
		for key in limits:
			if key not in EVENT_RANGE_KEYS or not _is_number(limits[key]):
				return false
			var expected := float(limits[key])
			if key == "equals" and not is_equal_approx(value, expected):
				return false
			if key == "min" and value < expected:
				return false
			if key == "max" and value > expected:
				return false
			if key == "less_than" and value >= expected:
				return false
			if key == "more_than" and value <= expected:
				return false
	return true


static func _matches_composition(source: Dictionary, depth: int) -> bool:
	for key in ["all", "any"]:
		if not source.has(key):
			continue
		var children: Variant = source[key]
		if not children is Array:
			return false
		var has_match := false
		for child in children:
			if not child is Dictionary:
				return false
			var matches := _matches_condition_source(child, true, depth + 1)
			if key == "all" and not matches:
				return false
			has_match = has_match or matches
		if key == "any" and not has_match:
			return false
	if source.has("not"):
		if not source["not"] is Dictionary or _matches_condition_source(source["not"], true, depth + 1):
			return false
	return true


static func _valid_composition(source: Dictionary, depth: int) -> bool:
	if depth > MAX_CONDITION_DEPTH or not _valid_leaf_conditions(source):
		return false
	for key in ["all", "any"]:
		if not source.has(key):
			continue
		if not source[key] is Array:
			return false
		for child in source[key]:
			if not child is Dictionary or not _valid_composition(child, depth + 1):
				return false
	if source.has("not"):
		if not source["not"] is Dictionary or not _valid_composition(source["not"], depth + 1):
			return false
	return true


static func _valid_leaf_conditions(source: Dictionary) -> bool:
	# Validate before applying all/any/not so invalid data cannot become true
	# merely because its failed comparison was negated.
	for field in NUMERIC_CONDITION_FIELDS:
		for prefix in ["", "min_", "max_"]:
			for key in ["%s%s" % [prefix, field], "required_%s%s" % [prefix, field]]:
				if source.has(key) and not _is_number(source[key]):
					return false
	if _has_numeric_field(source, "character_progress", true):
		var character_id := str(source.get("character_id", source.get("required_character_id", ""))).strip_edges().to_lower()
		if character_id.is_empty() or PlayerState.get_character_by_id(character_id).is_empty():
			return false
	for field in ["phase", "time_of_day", "weather"]:
		for key in [field, "required_%s" % field]:
			if not source.has(key):
				continue
			if typeof(source[key]) not in [TYPE_STRING, TYPE_STRING_NAME]:
				return false
			var value := str(source[key]).strip_edges().to_lower()
			var allowed: Array = PlayerState.WEATHER_TYPES if field == "weather" else PlayerState.STAGE_TIMES
			if value not in allowed:
				return false
	for prefix in ["", "min_", "max_"]:
		for key in ["%supgrade_levels" % prefix, "required_%supgrade_levels" % prefix]:
			if not source.has(key):
				continue
			if not source[key] is Dictionary:
				return false
			for upgrade_id in source[key]:
				var level: Variant = source[key][upgrade_id]
				if not _is_number(level) or float(level) < 0.0 or float(level) != floorf(float(level)):
					return false
				if typeof(upgrade_id) not in [TYPE_STRING, TYPE_STRING_NAME] or PlayerUpgradeState.story_upgrade_definition(str(upgrade_id)).is_empty():
					return false
	for key in ["event_value_ranges", "required_event_value_ranges"]:
		if not source.has(key):
			continue
		if not source[key] is Dictionary:
			return false
		for event_id in source[key]:
			if typeof(event_id) not in [TYPE_STRING, TYPE_STRING_NAME] or str(event_id).strip_edges().is_empty():
				return false
			var limits: Variant = source[key][event_id]
			if not limits is Dictionary:
				return false
			for bound in limits:
				if bound not in EVENT_RANGE_KEYS or not _is_number(limits[bound]):
					return false
	return true


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func matches_required_achievements(condition_source: Dictionary) -> bool:
	for achievement_id_variant in condition_array(condition_source, "required_achievements", "required_achievement"):
		if not PlayerState.has_achievement(str(achievement_id_variant)):
			return false
	return true


static func matches_forbidden_achievements(condition_source: Dictionary) -> bool:
	for achievement_id_variant in condition_array(condition_source, "forbidden_achievements", "forbidden_achievement"):
		if PlayerState.has_achievement(str(achievement_id_variant)):
			return false
	return true


static func condition_array(condition_source: Dictionary, plural_key: String, singular_key: String) -> Array:
	var values: Array = []
	var plural_variant: Variant = condition_source.get(plural_key, [])
	if plural_variant is Array:
		values.append_array(plural_variant as Array)
	var singular_variant: Variant = condition_source.get(singular_key, null)
	if singular_variant != null:
		values.append(singular_variant)
	return values


static func condition_dictionary(condition_source: Dictionary, plural_key: String, singular_key: String) -> Dictionary:
	var values: Dictionary = {}
	var plural_variant: Variant = condition_source.get(plural_key, {})
	if plural_variant is Dictionary:
		values.merge((plural_variant as Dictionary).duplicate(true), true)
	var singular_variant: Variant = condition_source.get(singular_key, null)
	if singular_variant is Dictionary:
		values.merge((singular_variant as Dictionary).duplicate(true), true)
	return values


static func matches_money_conditions(condition_source: Dictionary) -> bool:
	var current_money: int = int(PlayerState.money)
	var exact_money = first_condition_value(condition_source, ["money", "money_equals", "required_money"])
	if exact_money != null and current_money != int(exact_money):
		return false

	var min_money = first_condition_value(condition_source, ["min_money", "money_at_least", "required_min_money", "required_money_at_least"])
	if min_money != null and current_money < int(min_money):
		return false

	var max_money = first_condition_value(condition_source, ["max_money", "money_at_most", "required_max_money", "required_money_at_most"])
	if max_money != null and current_money > int(max_money):
		return false

	var money_less_than = first_condition_value(condition_source, ["money_less_than", "required_money_less_than"])
	if money_less_than != null and current_money >= int(money_less_than):
		return false

	var money_more_than = first_condition_value(condition_source, ["money_more_than", "required_money_more_than"])
	if money_more_than != null and current_money <= int(money_more_than):
		return false

	return true


static func first_condition_value(condition_source: Dictionary, keys: Array[String]):
	for key in keys:
		if condition_source.has(key):
			return condition_source[key]
	return null
