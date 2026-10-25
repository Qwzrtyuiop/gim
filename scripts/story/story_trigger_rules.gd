extends RefCounted

# Saved trigger rule definitions, canonical time fields, and built-in rule migrations.
# Runtime matching and payload selection live in StoryTriggerService.

const STORY_TRIGGER_DAY_END := "day_end"
const STORY_TRIGGER_SLEEP_MIDPOINT := "sleep_midpoint"
const STORY_TRIGGER_DAY_START := "day_start"
const STORY_TRIGGER_STAGE_COMPLETE := "stage_complete"
const STORY_TRIGGER_PASSENGER_SELECTED := "passenger_selected"


static func normalize_trigger(player_state, trigger_data: Dictionary) -> Dictionary:
	if trigger_data.is_empty():
		return {}

	var normalized_trigger: Dictionary = trigger_data.duplicate(true)
	var normalized_phase := normalize_story_trigger_phase(str(normalized_trigger.get("phase", "")))
	if normalized_phase.is_empty():
		return {}
	normalized_trigger["phase"] = normalized_phase

	_normalize_trigger_time_field(player_state, normalized_trigger, "time_of_day", ["phase_of_day"])
	_normalize_trigger_time_field(player_state, normalized_trigger, "current_time_of_day", ["current_phase"])
	_normalize_trigger_time_array(player_state, normalized_trigger, "times", ["phases"])
	_normalize_trigger_time_array(player_state, normalized_trigger, "current_times", ["current_phases"])
	return normalized_trigger


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
			"id": "elena_old_acquaintance",
			"phase": STORY_TRIGGER_STAGE_COMPLETE,
			"character_id": "ely",
			"min_character_progress": 2,
			"required_events": ["day_2_station_bill"],
			"forbidden_events": ["elena_old_acquaintance_seen"],
			"payload_id": "elena_old_acquaintance",
		},
		{
			"id": "jessa_runaway_fare",
			"phase": STORY_TRIGGER_STAGE_COMPLETE,
			"character_id": "jessa",
			"times": ["morning", "noon"],
			"min_character_progress": 1,
			# Her first completed ride can happen before the Day 2 event.
			"bypass_character_story_gate": true,
			"forbidden_events": ["jessa_runaway_fare_seen"],
			"payload_id": "jessa_runaway_fare",
		},
		{
			"id": "jessa_second_encounter",
			"phase": STORY_TRIGGER_PASSENGER_SELECTED,
			"character_id": "jessa",
			"bypass_character_story_gate": true,
			"required_events": ["jessa_runaway_fare_seen"],
			"required_event_values": {
				"jessa_runaway_fare_seen": true,
			},
			"forbidden_events": ["jessa_second_encounter_seen"],
			"payload_id": "jessa_second_encounter",
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
			# Completing the noon trip has already advanced the clock to night.
			"times": ["noon", "night"],
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
		STORY_TRIGGER_DAY_END, STORY_TRIGGER_SLEEP_MIDPOINT, STORY_TRIGGER_DAY_START, STORY_TRIGGER_STAGE_COMPLETE, STORY_TRIGGER_PASSENGER_SELECTED:
			return phase
	return ""


static func ensure_required_story_triggers(story_triggers: Array) -> bool:
	var changed := false
	# The unrestricted built-in rule shipped before Jessa's daytime introduction.
	# Match its full saved shape so authored/custom schedules are left intact.
	var previous_jessa_rule := {
		"id": "jessa_runaway_fare",
		"phase": STORY_TRIGGER_STAGE_COMPLETE,
		"character_id": "jessa",
		"min_character_progress": 1,
		"bypass_character_story_gate": true,
		"forbidden_events": ["jessa_runaway_fare_seen"],
		"payload_id": "jessa_runaway_fare",
	}
	# Saves retain their trigger dictionaries. Upgrade old built-in rules
	# without replacing custom rules or resetting consumed/seen event state.
	for trigger_data in story_triggers:
		if not trigger_data is Dictionary:
			continue
		if (
			str(trigger_data.get("id", "")) == "benny_tropa_night"
			and str(trigger_data.get("phase", "")) == STORY_TRIGGER_DAY_END
			and str(trigger_data.get("payload_id", "")) == "benny_tropa_night"
			and trigger_data.get("times", []) == ["noon"]
		):
			trigger_data["times"] = ["noon", "night"]
			changed = true
		if (
			str(trigger_data.get("id", "")) == "jessa_runaway_fare"
			and str(trigger_data.get("phase", "")) == STORY_TRIGGER_STAGE_COMPLETE
			and str(trigger_data.get("payload_id", "")) == "jessa_runaway_fare"
			and str(trigger_data.get("character_id", "")) == "jessa"
			and int(trigger_data.get("min_character_progress", -1)) == 2
			and trigger_data.get("required_events", []) == ["day_2_station_bill"]
		):
			trigger_data["min_character_progress"] = 1
			trigger_data["bypass_character_story_gate"] = true
			trigger_data.erase("required_events")
			changed = true
		if trigger_data == previous_jessa_rule:
			trigger_data["times"] = ["morning", "noon"]
			changed = true
	for required_trigger in build_default_story_triggers():
		var required_id := str(required_trigger.get("id", ""))
		if required_id.is_empty() or _has_trigger_with_id(story_triggers, required_id):
			continue
		story_triggers.append(required_trigger.duplicate(true))
		changed = true
	return changed


static func _normalize_trigger_time_field(player_state, trigger_data: Dictionary, canonical_key: String, alias_keys: Array[String]) -> void:
	var raw_value = trigger_data.get(canonical_key, null)
	for alias_key in alias_keys:
		if raw_value == null and trigger_data.has(alias_key):
			raw_value = trigger_data.get(alias_key)
		trigger_data.erase(alias_key)

	if raw_value == null:
		return

	var normalized_value := _normalize_time_value(player_state, raw_value)
	if normalized_value.is_empty():
		trigger_data.erase(canonical_key)
		return

	trigger_data[canonical_key] = normalized_value


static func _normalize_trigger_time_array(player_state, trigger_data: Dictionary, canonical_key: String, alias_keys: Array[String]) -> void:
	var raw_values: Array = []
	var canonical_values = trigger_data.get(canonical_key, [])
	if canonical_values is Array:
		raw_values.append_array(canonical_values)
	for alias_key in alias_keys:
		var alias_values = trigger_data.get(alias_key, [])
		if alias_values is Array:
			raw_values.append_array(alias_values)
		trigger_data.erase(alias_key)
	if raw_values.is_empty():
		return

	var normalized_values: Array[String] = []
	for raw_value in raw_values:
		var normalized_value := _normalize_time_value(player_state, raw_value)
		if normalized_value.is_empty() or normalized_values.has(normalized_value):
			continue
		normalized_values.append(normalized_value)

	if normalized_values.is_empty():
		trigger_data.erase(canonical_key)
		return

	trigger_data[canonical_key] = normalized_values


static func _normalize_time_value(player_state, time_value) -> String:
	var safe_time := str(time_value).strip_edges().to_lower()
	return safe_time if player_state.STAGE_TIMES.has(safe_time) else ""


static func _has_trigger_with_id(story_triggers: Array, trigger_id: String) -> bool:
	for trigger_data in story_triggers:
		if not trigger_data is Dictionary:
			continue
		if str((trigger_data as Dictionary).get("id", "")) == trigger_id:
			return true
	return false
