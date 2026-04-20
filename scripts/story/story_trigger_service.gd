extends RefCounted
class_name StoryTriggerService

const Day02StationBillPayloadEnglish := preload("res://scripts/story/payloads/day_02_station_bill.gd")
const Day02StationBillPayloadTagalog := preload("res://scripts/story/payloads/day_02_station_bill_tagalog.gd")
const Scene03Day7NightPayloadEnglish := preload("res://scripts/story/payloads/scene_03_day7_night.gd")
const Scene03Day7NightPayloadTagalog := preload("res://scripts/story/payloads/scene_03_day7_night_tagalog.gd")
const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")

const STORY_TRIGGER_DAY_END := "day_end"
const STORY_TRIGGER_SLEEP_MIDPOINT := "sleep_midpoint"
const STORY_TRIGGER_DAY_START := "day_start"
const STORY_TRIGGER_STAGE_COMPLETE := "stage_complete"


static func build_default_story_triggers() -> Array[Dictionary]:
	return [
		{
			"id": "day_2_station_bill",
			"phase": STORY_TRIGGER_STAGE_COMPLETE,
			"min_day": 2,
			"times": ["morning", "noon"],
			"forbidden_events": ["day_2_station_bill"],
			"payload_id": "day_02_station_bill",
		},
		{
			"id": "day_7_night_scene_03",
			"phase": STORY_TRIGGER_DAY_END,
			"day": 7,
			"time_of_day": "night",
			"payload_id": "scene_03_day7_night",
		},
	]


static func normalize_story_trigger_phase(phase: String) -> String:
	match phase:
		STORY_TRIGGER_DAY_END, STORY_TRIGGER_SLEEP_MIDPOINT, STORY_TRIGGER_DAY_START, STORY_TRIGGER_STAGE_COMPLETE:
			return phase
	return ""


static func find_story_trigger_for_phase(story_triggers: Array, consumed_story_triggers: Dictionary, event_values: Dictionary, phase: String, day_number: int, context: Dictionary = {}) -> Dictionary:
	var safe_phase := normalize_story_trigger_phase(str(phase))
	if safe_phase.is_empty():
		return {}

	for trigger_data in story_triggers:
		var trigger: Dictionary = trigger_data
		if _story_trigger_matches(trigger, safe_phase, day_number, context, consumed_story_triggers, event_values):
			return trigger.duplicate(true)

	return {}


static func get_story_payload_for_trigger(trigger_data: Dictionary) -> Dictionary:
	if trigger_data.is_empty():
		return {}

	var localized_payload := _build_localized_payload(str(trigger_data.get("payload_id", trigger_data.get("id", ""))))
	if not localized_payload.is_empty():
		return localized_payload

	var payload_variant = trigger_data.get("payload", {})
	if payload_variant is Dictionary:
		var saved_payload := payload_variant as Dictionary
		localized_payload = _build_localized_payload(str(saved_payload.get("story_id", "")))
		if not localized_payload.is_empty():
			return localized_payload
		return saved_payload.duplicate(true)
	return {}


static func _build_localized_payload(payload_id: String) -> Dictionary:
	var safe_payload_id := str(payload_id).strip_edges()
	var use_tagalog := StoryLanguageManager.is_tagalog()
	match safe_payload_id:
		"day_02_station_bill", "day_2_station_bill":
			if use_tagalog:
				return Day02StationBillPayloadTagalog.build()
			return Day02StationBillPayloadEnglish.build()
		"scene_03_day7_night", "day_7_night_scene_03":
			if use_tagalog:
				return Scene03Day7NightPayloadTagalog.build()
			return Scene03Day7NightPayloadEnglish.build()
	return {}


static func consume_story_trigger(consumed_story_triggers: Dictionary, trigger_data: Dictionary) -> bool:
	if trigger_data.is_empty() or bool(trigger_data.get("repeatable", false)):
		return false

	var trigger_id := _story_trigger_id(trigger_data)
	if trigger_id.is_empty():
		return false

	consumed_story_triggers[trigger_id] = true
	return true


static func ensure_required_story_triggers(story_triggers: Array) -> bool:
	var changed := false
	for required_trigger in build_default_story_triggers():
		var required_id := str(required_trigger.get("id", ""))
		if required_id.is_empty() or _has_trigger_with_id(story_triggers, required_id):
			continue
		story_triggers.append(required_trigger.duplicate(true))
		changed = true
	return changed


static func _has_trigger_with_id(story_triggers: Array, trigger_id: String) -> bool:
	for trigger_data in story_triggers:
		if not trigger_data is Dictionary:
			continue
		if str((trigger_data as Dictionary).get("id", "")) == trigger_id:
			return true
	return false


static func _story_trigger_matches(trigger_data: Dictionary, phase: String, day_number: int, context: Dictionary, consumed_story_triggers: Dictionary, event_values: Dictionary) -> bool:
	if trigger_data.is_empty():
		return false
	if normalize_story_trigger_phase(str(trigger_data.get("phase", ""))) != phase:
		return false
	if get_story_payload_for_trigger(trigger_data).is_empty():
		return false

	var trigger_id := _story_trigger_id(trigger_data)
	if not bool(trigger_data.get("repeatable", false)) and not trigger_id.is_empty() and bool(consumed_story_triggers.get(trigger_id, false)):
		return false

	if trigger_data.has("day") and int(trigger_data.get("day", 0)) != day_number:
		return false
	if trigger_data.has("min_day") and day_number < int(trigger_data.get("min_day", day_number)):
		return false
	if trigger_data.has("max_day") and day_number > int(trigger_data.get("max_day", day_number)):
		return false

	var days_variant = trigger_data.get("days", [])
	if days_variant is Array and not (days_variant as Array).is_empty():
		var valid_day := false
		for listed_day in days_variant:
			if int(listed_day) == day_number:
				valid_day = true
				break
		if not valid_day:
			return false

	if not _trigger_matches_context_value(trigger_data.get("stage_type", null), context.get("stage_type", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("stage_types", []), context.get("stage_type", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("time_of_day", null), context.get("time_of_day", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("times", []), context.get("time_of_day", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("difficulty", null), context.get("difficulty", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("difficulties", []), context.get("difficulty", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("traffic", null), context.get("traffic", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("traffic_types", []), context.get("traffic", null)):
		return false
	if not _trigger_matches_context_value(trigger_data.get("character_id", null), context.get("character_id", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("character_ids", []), context.get("character_id", null)):
		return false
	if not StoryEventHandler.matches_required_events(event_values, trigger_data.get("required_events", [])):
		return false
	if not StoryEventHandler.matches_forbidden_events(event_values, trigger_data.get("forbidden_events", [])):
		return false
	if not StoryEventHandler.matches_event_values(event_values, trigger_data.get("required_event_values", {}), true):
		return false
	if not StoryEventHandler.matches_event_values(event_values, trigger_data.get("forbidden_event_values", {}), false):
		return false

	return true


static func _trigger_matches_context_value(expected_value, actual_value) -> bool:
	if expected_value == null:
		return true
	var expected_text := str(expected_value).strip_edges()
	if expected_text.is_empty():
		return true
	return expected_text == str(actual_value).strip_edges()


static func _trigger_matches_context_array(expected_values, actual_value) -> bool:
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


static func _story_trigger_id(trigger_data: Dictionary) -> String:
	var explicit_id := str(trigger_data.get("id", ""))
	if not explicit_id.is_empty():
		return explicit_id

	var payload := get_story_payload_for_trigger(trigger_data)
	return "%s:%s:%s" % [
		str(trigger_data.get("phase", "")),
		str(trigger_data.get("day", "")),
		str(payload.get("chapter_title", "")),
	]
