extends RefCounted
class_name StoryCatalog

const StoryCatalogData := preload("res://scripts/story/story_catalog_data.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")

static var _characters_by_id: Dictionary = {}
static var _unique_ids: Dictionary = {}
static var _speaker_ids: Dictionary = {}


static func _ensure_index() -> void:
	if not _characters_by_id.is_empty():
		return
	for character: Dictionary in StoryCatalogData.GENERIC_PASSENGERS:
		_characters_by_id[str(character.id)] = character
	for character: Dictionary in StoryCatalogData.MOCK_CHARACTERS:
		var id: String = str(character.id)
		_characters_by_id[id] = character
		_unique_ids[id] = true
		_speaker_ids[str(character.name).to_lower()] = id


static func get_character_display_name(player_state, character_id: String) -> String:
	_ensure_index()
	var character: Dictionary = _characters_by_id.get(character_id.strip_edges().to_lower(), {})
	if character.is_empty():
		return "???"
	var safe_id: String = str(character.get("id", ""))
	var name_unlock_event: String = str(character.get("name_unlock_event", ""))
	if not name_unlock_event.is_empty():
		return str(character.get("name", "???")) if bool(player_state.event_values.get(name_unlock_event, false)) else "???"
	if is_unique_character(safe_id) and int(player_state.character_completed_rides.get(safe_id, 0)) < GameTuning.CHARACTER_NAME_UNLOCK_RIDES:
		return "???"
	return str(character.get("name", "???"))


static func get_speaker_display_name(player_state, speaker: String) -> String:
	_ensure_index()
	var id: String = str(_speaker_ids.get(speaker.strip_edges().to_lower(), ""))
	if not id.is_empty():
		return get_character_display_name(player_state, id)
	return speaker

static func get_generic_passengers() -> Array:
	return StoryCatalogData.GENERIC_PASSENGERS.duplicate(true)


static func get_unique_passengers(player_state) -> Array:
	var unique_passengers: Array = []
	for character_data in StoryCatalogData.MOCK_CHARACTERS:
		if character_data is Dictionary:
			unique_passengers.append(_character_with_progress(player_state, character_data))
	return unique_passengers


static func get_mock_characters(player_state) -> Array:
	var combined_characters: Array = []
	combined_characters.append_array(get_generic_passengers())
	combined_characters.append_array(get_unique_passengers(player_state))
	return combined_characters


static func get_character_by_id(player_state, character_id: String) -> Dictionary:
	_ensure_index()
	var safe_id: String = str(character_id).strip_edges().to_lower()
	if not _characters_by_id.has(safe_id):
		return {}
	var character: Dictionary = _characters_by_id[safe_id]
	return _character_with_progress(player_state, character) if _unique_ids.has(safe_id) else character.duplicate(true)


static func is_unique_character(character_id: String) -> bool:
	_ensure_index()
	return _unique_ids.has(character_id.strip_edges().to_lower())


static func get_unique_character_story_state(player_state, character_id: String, context: Dictionary = {}) -> Dictionary:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return {}

	var character_data: Dictionary = _get_unique_character_base_data(safe_id)
	if character_data.is_empty():
		return {}

	var story_stages: Array = _resolve_story_stages(player_state, character_data, context)
	if story_stages.is_empty():
		return {}

	var progress: int = player_state.get_unique_character_progress(safe_id)
	var stage_index: int = _resolve_story_stage_index(story_stages, progress)
	var current_stage: Dictionary = story_stages[stage_index]
	var next_stage: Dictionary = story_stages[stage_index + 1] if stage_index + 1 < story_stages.size() else {}
	var resolved_modifiers: Dictionary = _resolve_story_stage_modifiers(current_stage, context)
	var base_ride_modifiers: Variant = character_data.get("ride_modifiers", {})
	if base_ride_modifiers is Dictionary:
		var merged_modifiers: Dictionary = (base_ride_modifiers as Dictionary).duplicate(true)
		merged_modifiers.merge(resolved_modifiers, true)
		resolved_modifiers = merged_modifiers

	return {
		"character_id": safe_id,
		"progress": progress,
		"stage_index": stage_index,
		"stage_count": story_stages.size(),
		"stage_data": current_stage.duplicate(true),
		"stage_id": str(current_stage.get("id", "")),
		"stage_title": str(current_stage.get("title", "")),
		"arc_id": str(current_stage.get("arc_id", "")),
		"arc_title": str(current_stage.get("arc_title", "")),
		"stage_progress_required": int(current_stage.get("progress_required", 0)),
		"next_stage_id": str(next_stage.get("id", "")),
		"next_stage_title": str(next_stage.get("title", "")),
		"next_arc_id": str(next_stage.get("arc_id", "")),
		"next_arc_title": str(next_stage.get("arc_title", "")),
		"next_stage_progress_required": int(next_stage.get("progress_required", progress)),
		"story_stages": story_stages.duplicate(true),
		"modifiers": resolved_modifiers,
	}


static func get_character_stage_modifiers(player_state, character_id: String, context: Dictionary = {}) -> Dictionary:
	var story_state: Dictionary = get_unique_character_story_state(player_state, character_id, context)
	if story_state.is_empty():
		return {}
	var modifiers: Variant = story_state.get("modifiers", {})
	return (modifiers as Dictionary).duplicate(true) if modifiers is Dictionary else {}


static func get_character_session_dialogue(player_state, character_id: String, context: Dictionary = {}) -> Dictionary:
	if str(character_id).strip_edges().is_empty():
		return {}
	var resolved_dialogue: Dictionary = _duplicate_session_dialogue(StoryCatalogData.DEFAULT_SESSION_DIALOGUE)
	var character_data: Dictionary = get_character_by_id(player_state, character_id)
	if character_data.is_empty():
		return resolved_dialogue

	var safe_id: String = str(character_data.get("id", "")).strip_edges().to_lower()
	_merge_session_dialogue(resolved_dialogue, character_data.get("session_dialogue", {}))
	_merge_session_dialogue(resolved_dialogue, StoryCatalogData.UNIQUE_SESSION_DIALOGUE_OVERRIDES.get(safe_id, {}))

	if is_unique_character(safe_id):
		var story_state: Dictionary = get_unique_character_story_state(player_state, safe_id, context)
		if not story_state.is_empty():
			var stage_data: Variant = story_state.get("stage_data", {})
			if stage_data is Dictionary:
				_merge_session_dialogue(resolved_dialogue, (stage_data as Dictionary).get("session_dialogue", {}))

	return _resolve_progress_scoped_session_dialogue(player_state, safe_id, resolved_dialogue)


static func _character_with_progress(player_state, character_data: Dictionary) -> Dictionary:
	var character_copy: Dictionary = character_data.duplicate(true)
	var character_id: String = str(character_copy.get("id", ""))
	var intro_completion_event: String = str(character_copy.get("intro_completion_event", ""))
	var intro_times: Variant = character_copy.get("intro_eligible_times", [])
	var intro_completed := not intro_completion_event.is_empty() and bool(player_state.event_values.get(intro_completion_event, false))
	if not intro_completion_event.is_empty() and not intro_completed:
		if intro_times is Array and not intro_times.is_empty():
			character_copy["eligible_times"] = intro_times.duplicate(true)
	else:
		# The first event already stores its ride date with the unpaid fare. Reuse
		# that historical day so reloads/replays cannot start a new absence period.
		var day_event: String = str(character_copy.get("intro_absence_day_event", ""))
		var history: Variant = player_state.event_values.get(day_event, {})
		if intro_completed and not day_event.is_empty() and history is Dictionary:
			var first_day: Variant = history.get("day", 0)
			if first_day is int and first_day > 0:
				character_copy["unavailable_day"] = first_day
	character_copy["progress"] = player_state.get_unique_character_progress(character_id)
	var story_state: Dictionary = get_unique_character_story_state(player_state, character_id)
	if not story_state.is_empty():
		character_copy["story_stage_id"] = str(story_state.get("stage_id", ""))
		character_copy["story_stage_title"] = str(story_state.get("stage_title", ""))
		character_copy["story_arc_id"] = str(story_state.get("arc_id", ""))
		character_copy["story_arc_title"] = str(story_state.get("arc_title", ""))
		character_copy["story_stage_index"] = int(story_state.get("stage_index", 0))
		character_copy["story_stage_count"] = int(story_state.get("stage_count", 0))
		character_copy["next_story_stage_id"] = str(story_state.get("next_stage_id", ""))
		character_copy["next_story_stage_title"] = str(story_state.get("next_stage_title", ""))
		character_copy["next_story_arc_id"] = str(story_state.get("next_arc_id", ""))
		character_copy["next_story_arc_title"] = str(story_state.get("next_arc_title", ""))
		character_copy["next_story_stage_progress_required"] = int(story_state.get("next_stage_progress_required", 0))
	return character_copy


static func _get_unique_character_base_data(character_id: String) -> Dictionary:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	return Dictionary(_characters_by_id[safe_id]).duplicate(true) if is_unique_character(safe_id) else {}


static func _resolve_story_stages(player_state, character_data: Dictionary, context: Dictionary = {}) -> Array:
	var raw_stages: Variant = character_data.get("story_stages", [])
	var story_stages: Array = []
	if raw_stages is Array and not (raw_stages as Array).is_empty():
		for stage_data in raw_stages:
			if stage_data is Dictionary:
				story_stages.append((stage_data as Dictionary).duplicate(true))
	else:
		var stage_set_id: String = str(character_data.get("story_stage_set", StoryCatalogData.DEFAULT_UNIQUE_STORY_STAGE_SET_ID))
		var stage_overrides: Dictionary = character_data.get("story_stage_overrides", {})
		var fallback_stages: Array = StoryCatalogData.DEFAULT_UNIQUE_STORY_STAGES if stage_set_id == StoryCatalogData.DEFAULT_UNIQUE_STORY_STAGE_SET_ID else StoryCatalogData.DEFAULT_UNIQUE_STORY_STAGES
		for stage_data in fallback_stages:
			if not stage_data is Dictionary:
				continue
			var stage_copy: Dictionary = (stage_data as Dictionary).duplicate(true)
			var stage_id: String = str(stage_copy.get("id", ""))
			if stage_overrides.has(stage_id) and stage_overrides[stage_id] is Dictionary:
				stage_copy.merge((stage_overrides[stage_id] as Dictionary).duplicate(true), true)
			story_stages.append(stage_copy)

	story_stages.sort_custom(func(a, b):
		return int(a.get("progress_required", 0)) < int(b.get("progress_required", 0))
	)

	var effective_week: int = _resolve_story_stage_week(player_state, context)
	var available_story_stages: Array = []
	for stage_data in story_stages:
		if not stage_data is Dictionary:
			continue
		var stage_dict: Dictionary = stage_data
		if not _story_stage_available_for_week(stage_dict, effective_week):
			continue
		available_story_stages.append(stage_dict)
	if available_story_stages.is_empty():
		return story_stages
	return available_story_stages


static func _resolve_story_stage_index(story_stages: Array, progress: int) -> int:
	var resolved_index := 0
	for index in range(story_stages.size()):
		var stage_data = story_stages[index]
		if not stage_data is Dictionary:
			continue
		var required_progress := int((stage_data as Dictionary).get("progress_required", 0))
		if progress >= required_progress:
			resolved_index = index
	return resolved_index


static func _resolve_story_stage_week(player_state, context: Dictionary) -> int:
	if context.has("week"):
		return maxi(1, int(context.get("week", 1)))
	if context.has("day"):
		return maxi(1, player_state.get_week_number(int(context.get("day", player_state.get_current_day()))))
	return maxi(1, player_state.get_week_number())


static func _story_stage_available_for_week(stage_data: Dictionary, week_number: int) -> bool:
	var effective_week: int = maxi(1, int(week_number))
	if stage_data.has("min_week") and effective_week < int(stage_data.get("min_week", effective_week)):
		return false
	if stage_data.has("max_week") and effective_week > int(stage_data.get("max_week", effective_week)):
		return false
	var weeks_variant: Variant = stage_data.get("weeks", [])
	if weeks_variant is Array and not (weeks_variant as Array).is_empty():
		for allowed_week in weeks_variant:
			if int(allowed_week) == effective_week:
				return true
		return false
	return true


static func _resolve_story_stage_modifiers(stage_data: Dictionary, context: Dictionary) -> Dictionary:
	var resolved_modifiers: Dictionary = {}
	var base_modifiers: Variant = stage_data.get("modifiers", {})
	if base_modifiers is Dictionary:
		resolved_modifiers.merge((base_modifiers as Dictionary).duplicate(true), true)

	var rule_entries: Variant = stage_data.get("modifier_rules", [])
	if not rule_entries is Array:
		return resolved_modifiers

	for rule_data in rule_entries:
		if not rule_data is Dictionary:
			continue
		var rule: Dictionary = rule_data
		if not _modifier_rule_matches_context(rule, context):
			continue
		var rule_modifiers: Variant = rule.get("modifiers", {})
		if rule_modifiers is Dictionary:
			resolved_modifiers.merge((rule_modifiers as Dictionary).duplicate(true), true)
	return resolved_modifiers


static func _modifier_rule_matches_context(rule: Dictionary, context: Dictionary) -> bool:
	if not _matches_rule_value(context, rule, "stage_type", "stage_types"):
		return false
	if not _matches_rule_value(context, rule, "difficulty", "difficulties"):
		return false
	if not _matches_rule_value(context, rule, "time_of_day", "times_of_day", ["time"]):
		return false
	if not _matches_rule_value(context, rule, "traffic", "traffics"):
		return false
	return true


static func _matches_rule_value(
	context: Dictionary,
	rule: Dictionary,
	singular_key: String,
	plural_key: String,
	context_aliases: Array = []
) -> bool:
	if not rule.has(singular_key) and not rule.has(plural_key):
		return true

	var context_value := ""
	if context.has(singular_key):
		context_value = str(context.get(singular_key, "")).strip_edges().to_lower()
	else:
		for alias_key in context_aliases:
			if context.has(alias_key):
				context_value = str(context.get(alias_key, "")).strip_edges().to_lower()
				break

	if context_value.is_empty():
		return false

	if rule.has(singular_key):
		return context_value == str(rule.get(singular_key, "")).strip_edges().to_lower()

	var allowed_values: Variant = rule.get(plural_key, [])
	if not allowed_values is Array:
		return false
	for value in allowed_values:
		if context_value == str(value).strip_edges().to_lower():
			return true
	return false


static func _duplicate_session_dialogue(source_dialogue: Dictionary) -> Dictionary:
	var duplicated: Dictionary = {}
	for category_variant in source_dialogue.keys():
		var category: String = str(category_variant)
		var entries: Variant = source_dialogue.get(category, [])
		var duplicated_entries: Array = []
		if entries is Array:
			for entry in entries:
				if entry is Dictionary:
					duplicated_entries.append((entry as Dictionary).duplicate(true))
				else:
					duplicated_entries.append(entry)
		duplicated[category] = duplicated_entries
	return duplicated


static func _merge_session_dialogue(target_dialogue: Dictionary, source_dialogue: Variant) -> void:
	if not source_dialogue is Dictionary:
		return

	for category_variant in (source_dialogue as Dictionary).keys():
		var category: String = str(category_variant)
		if not target_dialogue.has(category):
			target_dialogue[category] = []
		var target_entries: Array = target_dialogue.get(category, [])
		var source_entries: Variant = (source_dialogue as Dictionary).get(category, [])
		if not source_entries is Array:
			continue
		for entry in source_entries:
			if entry is Dictionary:
				target_entries.append((entry as Dictionary).duplicate(true))
			else:
				target_entries.append(entry)
		target_dialogue[category] = target_entries


static func _resolve_progress_scoped_session_dialogue(player_state, character_id: String, source_dialogue: Dictionary) -> Dictionary:
	var resolved_dialogue: Dictionary = {}
	var progress: int = player_state.get_unique_character_progress(character_id)
	for category_variant in source_dialogue.keys():
		var category: String = str(category_variant).strip_edges().to_lower()
		var entries: Variant = source_dialogue.get(category_variant, [])
		if not entries is Array:
			continue
		var scoped_info: Dictionary = _progress_scoped_dialogue_category_info(category)
		if scoped_info.is_empty():
			resolved_dialogue[category] = (entries as Array).duplicate(true)
			continue
		if int(scoped_info.get("progress", -1)) != progress:
			continue
		var base_category: String = str(scoped_info.get("base_category", ""))
		if not resolved_dialogue.has(base_category):
			resolved_dialogue[base_category] = []
		var target_entries: Array = resolved_dialogue.get(base_category, [])
		for entry_index in range((entries as Array).size()):
			var decorated_entry: Variant = _decorate_progress_scoped_dialogue_entry(
				player_state,
				character_id,
				base_category,
				category,
				entry_index,
				(entries as Array)[entry_index]
			)
			if decorated_entry == null:
				continue
			target_entries.append(decorated_entry)
		resolved_dialogue[base_category] = target_entries
	return resolved_dialogue


static func _progress_scoped_dialogue_category_info(category: String) -> Dictionary:
	var safe_category: String = str(category).strip_edges().to_lower()
	var underscore_index: int = safe_category.rfind("_")
	if underscore_index <= 0 or underscore_index >= safe_category.length() - 1:
		return {}
	var suffix: String = safe_category.substr(underscore_index + 1)
	if not suffix.is_valid_int():
		return {}
	return {
		"base_category": safe_category.substr(0, underscore_index),
		"progress": int(suffix),
	}


static func _decorate_progress_scoped_dialogue_entry(player_state, character_id: String, base_category: String, source_category: String, entry_index: int, entry: Variant) -> Variant:
	var entry_id: String = "%s:%s:%s:%d" % [character_id, base_category, source_category, entry_index]
	if player_state.has_consumed_unique_session_dialogue(entry_id):
		return null
	if entry is Dictionary:
		var entry_dict: Dictionary = (entry as Dictionary).duplicate(true)
		entry_dict["_session_dialogue_id"] = entry_id
		entry_dict["_session_dialogue_once"] = true
		entry_dict["_session_dialogue_ordered"] = true
		return entry_dict
	return {
		"english": str(entry),
		"_session_dialogue_id": entry_id,
		"_session_dialogue_once": true,
		"_session_dialogue_ordered": true,
	}
