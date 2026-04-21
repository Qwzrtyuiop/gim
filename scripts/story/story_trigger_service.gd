extends RefCounted
class_name StoryTriggerService

const Day02StationBillPayloadEnglish := preload("res://scripts/story/payloads/day_02_station_bill.gd")
const Day02StationBillPayloadTagalog := preload("res://scripts/story/payloads/day_02_station_bill_tagalog.gd")
const BennyClassClownPayloadEnglish := preload("res://scripts/story/payloads/benny_class_clown.gd")
const BennyClassClownPayloadTagalog := preload("res://scripts/story/payloads/benny_class_clown_tagalog.gd")
const BennyTropaNightPayloadEnglish := preload("res://scripts/story/payloads/benny_tropa_night.gd")
const BennyTropaNightPayloadTagalog := preload("res://scripts/story/payloads/benny_tropa_night_tagalog.gd")
const Scene03Day7NightPayloadEnglish := preload("res://scripts/story/payloads/scene_03_day7_night.gd")
const Scene03Day7NightPayloadTagalog := preload("res://scripts/story/payloads/scene_03_day7_night_tagalog.gd")
const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")
const NUMERIC_TRIGGER_FIELDS := [
	"energy",
	"gas",
	"gas_price",
	"money",
	"karma",
	"week",
	"character_progress",
	"days_until_collection",
	"weekly_goal",
	"remaining_debt",
]

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
			"id": "benny_class_clown",
			"phase": STORY_TRIGGER_STAGE_COMPLETE,
			"character_id": "benny",
			"min_character_progress": 2,
			"required_events": ["day_2_station_bill"],
			"forbidden_events": ["benny_class_clown_seen"],
			"payload_id": "benny_class_clown",
		},
		{
			"id": "day_7_night_scene_03",
			"phase": STORY_TRIGGER_DAY_END,
			"day": 7,
			"time_of_day": "night",
			"payload_id": "scene_03_day7_night",
		},
		{
			"id": "benny_tropa_night",
			"phase": STORY_TRIGGER_DAY_END,
			"times": ["noon"],
			"required_events": ["benny_class_clown_seen"],
			"required_event_values": {
				"benny_class_clown_drink_choice": "agree",
			},
			"forbidden_events": ["benny_tropa_seen"],
			"payload_id": "benny_tropa_night",
		},
	]


static func normalize_story_trigger_phase(phase: String) -> String:
	match phase:
		STORY_TRIGGER_DAY_END, STORY_TRIGGER_SLEEP_MIDPOINT, STORY_TRIGGER_DAY_START, STORY_TRIGGER_STAGE_COMPLETE:
			return phase
	return ""


static func find_story_trigger_for_phase(story_triggers: Array, consumed_story_triggers: Dictionary, event_values: Dictionary, phase: String, day_number: int, rng: RandomNumberGenerator = null, context: Dictionary = {}) -> Dictionary:
	var safe_phase := normalize_story_trigger_phase(str(phase))
	if safe_phase.is_empty():
		return {}

	var matching_triggers: Array[Dictionary] = []
	for trigger_data in story_triggers:
		var trigger: Dictionary = trigger_data
		if _story_trigger_matches(trigger, safe_phase, day_number, context, consumed_story_triggers, event_values):
			matching_triggers.append(trigger.duplicate(true))

	if matching_triggers.is_empty():
		return {}

	var selected_trigger: Dictionary = _select_matching_trigger(matching_triggers)
	if selected_trigger.is_empty():
		return {}

	var resolved_trigger := _resolve_trigger_payload(selected_trigger, consumed_story_triggers, rng)
	if not resolved_trigger.is_empty():
		return resolved_trigger

	return {}


static func get_story_payload_for_trigger(trigger_data: Dictionary) -> Dictionary:
	if trigger_data.is_empty():
		return {}

	var resolved_payload_variant = trigger_data.get("resolved_payload", null)
	if resolved_payload_variant is Dictionary:
		var resolved_payload := resolved_payload_variant as Dictionary
		var localized_resolved_payload := _build_localized_payload(str(resolved_payload.get("story_id", "")))
		if not localized_resolved_payload.is_empty():
			return localized_resolved_payload
		return resolved_payload.duplicate(true)

	var resolved_payload_id := str(trigger_data.get("resolved_payload_id", "")).strip_edges()
	var localized_payload := _build_localized_payload(resolved_payload_id if not resolved_payload_id.is_empty() else str(trigger_data.get("payload_id", trigger_data.get("id", ""))))
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
		"benny_class_clown":
			if use_tagalog:
				return BennyClassClownPayloadTagalog.build()
			return BennyClassClownPayloadEnglish.build()
		"benny_tropa_night":
			if use_tagalog:
				return BennyTropaNightPayloadTagalog.build()
			return BennyTropaNightPayloadEnglish.build()
		"scene_03_day7_night", "day_7_night_scene_03":
			if use_tagalog:
				return Scene03Day7NightPayloadTagalog.build()
			return Scene03Day7NightPayloadEnglish.build()
	return {}


static func consume_story_trigger(consumed_story_triggers: Dictionary, trigger_data: Dictionary) -> bool:
	if trigger_data.is_empty():
		return false

	var consumed_any := false
	var resolved_payload_story_id := _resolved_payload_story_id(trigger_data)
	if not resolved_payload_story_id.is_empty() and bool(trigger_data.get("consume_resolved_payload_once", true)):
		var payload_trigger_id := _resolved_payload_trigger_id(resolved_payload_story_id)
		if not payload_trigger_id.is_empty():
			consumed_story_triggers[payload_trigger_id] = true
			consumed_any = true

	if bool(trigger_data.get("repeatable", false)):
		return consumed_any

	var trigger_id := _story_trigger_id(trigger_data)
	if trigger_id.is_empty():
		return consumed_any

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
	if not _trigger_has_available_payload(trigger_data, consumed_story_triggers):
		return false

	var trigger_id := _story_trigger_id(trigger_data)
	if not bool(trigger_data.get("repeatable", false)) and not trigger_id.is_empty() and bool(consumed_story_triggers.get(trigger_id, false)):
		return false
	if _is_character_story_trigger(trigger_data) and not _character_story_gate_satisfied(trigger_data, event_values):
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

	if not _trigger_matches_numeric_condition(trigger_data, "week", context.get("week", null)):
		return false
	var weeks_variant = trigger_data.get("weeks", [])
	if weeks_variant is Array and not (weeks_variant as Array).is_empty():
		if not _trigger_matches_context_array(weeks_variant, context.get("week", null)):
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
	if not _trigger_matches_context_value(trigger_data.get("story_stage_id", null), context.get("story_stage_id", null)):
		return false
	if not _trigger_matches_context_array(trigger_data.get("story_stage_ids", []), context.get("story_stage_id", null)):
		return false
	for numeric_field_variant in NUMERIC_TRIGGER_FIELDS:
		var numeric_field := str(numeric_field_variant)
		if numeric_field == "week":
			continue
		if not _trigger_matches_numeric_condition(trigger_data, numeric_field, context.get(numeric_field, null)):
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


static func _select_matching_trigger(matching_triggers: Array[Dictionary]) -> Dictionary:
	if matching_triggers.is_empty():
		return {}

	var first_match: Dictionary = matching_triggers[0]
	if not _is_character_story_trigger(first_match):
		return first_match

	var selected_trigger: Dictionary = first_match
	var selected_order: float = _character_story_trigger_order(first_match)
	for trigger_data in matching_triggers:
		if not _is_character_story_trigger(trigger_data):
			continue
		var trigger_order: float = _character_story_trigger_order(trigger_data)
		if trigger_order < selected_order:
			selected_trigger = trigger_data
			selected_order = trigger_order
	return selected_trigger


static func _is_character_story_trigger(trigger_data: Dictionary) -> bool:
	if bool(trigger_data.get("character_story", false)):
		return true
	if trigger_data.has("character_id"):
		return not str(trigger_data.get("character_id", "")).strip_edges().is_empty()
	var character_ids_variant = trigger_data.get("character_ids", [])
	return character_ids_variant is Array and not (character_ids_variant as Array).is_empty()


static func _character_story_gate_satisfied(trigger_data: Dictionary, event_values: Dictionary) -> bool:
	if bool(trigger_data.get("bypass_character_story_gate", false)):
		return true
	return StoryEventHandler.has_event_value(event_values, "day_2_station_bill")


static func _character_story_trigger_order(trigger_data: Dictionary) -> float:
	if trigger_data.has("story_order"):
		return float(trigger_data.get("story_order", 0))
	if trigger_data.has("character_story_order"):
		return float(trigger_data.get("character_story_order", 0))
	if trigger_data.has("character_progress"):
		return float(trigger_data.get("character_progress", 0))
	if trigger_data.has("min_character_progress"):
		return float(trigger_data.get("min_character_progress", 0))
	return 1000000.0


static func _trigger_matches_numeric_condition(trigger_data: Dictionary, field_name: String, actual_value) -> bool:
	var exact_key := field_name
	var min_key := "min_%s" % field_name
	var max_key := "max_%s" % field_name
	if not trigger_data.has(exact_key) and not trigger_data.has(min_key) and not trigger_data.has(max_key):
		return true
	if actual_value == null:
		return false

	var actual_number := float(actual_value)
	if trigger_data.has(exact_key):
		var expected_number := float(trigger_data.get(exact_key, actual_number))
		if not is_equal_approx(actual_number, expected_number):
			return false
	if trigger_data.has(min_key) and actual_number < float(trigger_data.get(min_key, actual_number)):
		return false
	if trigger_data.has(max_key) and actual_number > float(trigger_data.get(max_key, actual_number)):
		return false
	return true


static func _trigger_has_available_payload(trigger_data: Dictionary, consumed_story_triggers: Dictionary) -> bool:
	if _trigger_uses_random_payloads(trigger_data):
		return not _available_random_payload_entries(trigger_data, consumed_story_triggers).is_empty()
	return not get_story_payload_for_trigger(trigger_data).is_empty()


static func _resolve_trigger_payload(trigger_data: Dictionary, consumed_story_triggers: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if trigger_data.is_empty():
		return {}

	var resolved_trigger := trigger_data.duplicate(true)
	if not _trigger_uses_random_payloads(trigger_data):
		return resolved_trigger

	var available_payload_entries := _available_random_payload_entries(trigger_data, consumed_story_triggers)
	if available_payload_entries.is_empty():
		return {}

	var picker := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	var selected_index := picker.randi_range(0, available_payload_entries.size() - 1)
	var selected_entry: Dictionary = available_payload_entries[selected_index]
	var resolved_payload_id := str(selected_entry.get("payload_id", "")).strip_edges()
	if not resolved_payload_id.is_empty():
		resolved_trigger["resolved_payload_id"] = resolved_payload_id
	var resolved_payload_variant = selected_entry.get("payload", null)
	if resolved_payload_variant is Dictionary:
		resolved_trigger["resolved_payload"] = (resolved_payload_variant as Dictionary).duplicate(true)
	return resolved_trigger


static func _trigger_uses_random_payloads(trigger_data: Dictionary) -> bool:
	var payload_ids_variant = trigger_data.get("random_payload_ids", [])
	if payload_ids_variant is Array and not (payload_ids_variant as Array).is_empty():
		return true
	var payloads_variant = trigger_data.get("random_payloads", [])
	return payloads_variant is Array and not (payloads_variant as Array).is_empty()


static func _available_random_payload_entries(trigger_data: Dictionary, consumed_story_triggers: Dictionary) -> Array[Dictionary]:
	var available_payload_entries: Array[Dictionary] = []
	var payload_ids_variant = trigger_data.get("random_payload_ids", [])
	if payload_ids_variant is Array:
		for payload_id_variant in payload_ids_variant:
			var payload_id := str(payload_id_variant).strip_edges()
			if payload_id.is_empty():
				continue
			if bool(trigger_data.get("consume_resolved_payload_once", true)) and bool(consumed_story_triggers.get(_resolved_payload_trigger_id(payload_id), false)):
				continue
			if _build_localized_payload(payload_id).is_empty():
				continue
			available_payload_entries.append({
				"payload_id": payload_id,
			})

	var payloads_variant = trigger_data.get("random_payloads", [])
	if payloads_variant is Array:
		for payload_variant in payloads_variant:
			if not payload_variant is Dictionary:
				continue
			var payload: Dictionary = (payload_variant as Dictionary).duplicate(true)
			var story_id := str(payload.get("story_id", "")).strip_edges()
			if story_id.is_empty():
				continue
			if bool(trigger_data.get("consume_resolved_payload_once", true)) and bool(consumed_story_triggers.get(_resolved_payload_trigger_id(story_id), false)):
				continue
			available_payload_entries.append({
				"payload": payload,
			})

	return available_payload_entries


static func _resolved_payload_story_id(trigger_data: Dictionary) -> String:
	var resolved_payload_id := str(trigger_data.get("resolved_payload_id", "")).strip_edges()
	if not resolved_payload_id.is_empty():
		return resolved_payload_id
	var resolved_payload_variant = trigger_data.get("resolved_payload", null)
	if resolved_payload_variant is Dictionary:
		return str((resolved_payload_variant as Dictionary).get("story_id", "")).strip_edges()
	return ""


static func _resolved_payload_trigger_id(payload_id: String) -> String:
	var safe_payload_id := str(payload_id).strip_edges()
	if safe_payload_id.is_empty():
		return ""
	return "__story_payload__:%s" % safe_payload_id


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
