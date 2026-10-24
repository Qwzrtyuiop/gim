extends RefCounted

# Conditional line routing and story eligibility predicates.

const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")


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
	if nested_conditions is Dictionary:
		condition_source = (nested_conditions as Dictionary).duplicate(true)
		for key_variant in data.keys():
			var key: String = str(key_variant)
			if key == "conditions":
				continue
			if key.begins_with("required_") or key.begins_with("forbidden_"):
				condition_source[key] = data[key_variant]

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
	return true


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
