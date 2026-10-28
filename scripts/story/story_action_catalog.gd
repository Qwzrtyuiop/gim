extends RefCounted

# Supported story commands and persistence metadata. Validators never mutate state.
const GameEffects := preload("res://scripts/story/story_game_effects.gd")
const StoryTime := preload("res://scripts/state/player_story_time_state.gd")
const CharacterSprites := preload("res://scripts/story/story_character_sprites.gd")
const ACTIONS := {
	"resolve_bayanihan": true,
	"show_weekly_debt_transition": false,
	"hide_weekly_debt_transition": false,
	"collect_first_week_interest": true,
	"repay_malasakit_fare": true,
	"resolve_random_ride_fare": true,
	"start_special_stage": true,
	"pause": false,
	"fade_to_black": false,
	"fade_from_black": false,
	"fade_screen": false,
	"play_music": false,
	"stop_music": false,
	"unlock_achievement": true,
	"set_event_value": true,
	"set_event_values": true,
	"clear_event_value": true,
	"clear_event_values": true,
	"add_story_trigger": true,
	"add_seeded_rider_rule": true,
	"add_money": true,
	"spend_money": true,
	"spend_all_money": true,
	"collect_debt": true,
	"add_energy": true,
	"add_max_energy": true,
	"add_karma": true,
	"add_character_progress": true,
	"set_character_progress": true,
	"set_character_story_lock": true,
	"set_pending_night_skip": true,
	"clear_pending_night_skip": true,
	"play_sfx": false,
	"stop_sfx": false,
	"set_portrait": false,
	"set_character_sprite": false,
	"set_portraits": false,
	"clear_portraits": false,
	"clear_portrait": false,
	"portrait_switch": false,
	"set_dialogue": false,
	"background_camera": false,
	"zoom_background": false,
	"pan_background": false,
	"reset_background_camera": false,
	"hide_dialogue": false,
	"show_dialogue": false,
	"set_background": false,
	"advance_time": true,
	"skip_days": true,
	"skip_phases": true,
	"queue_story": true,
	"return_to": true,
	"selection_outcome": true,
	"end_run": true,
	"set_resource": true,
	"change_resource": true,
	"add_gas": true,
	"spend_gas": true,
	"restore_energy": true,
	"add_stress": true,
	"relieve_stress": true,
	"damage_hull": true,
	"repair_hull": true,
	"set_upgrade_level": true,
	"add_upgrade_level": true,
	"increment_event_value": true,
	"pay_debt": true,
	"forgive_debt": true,
	"set_weather": true,
}

const ALIASES := {
	"wait": "pause",
	"screen_fade_out": "fade_to_black",
	"screen_fade_in": "fade_from_black",
	"music_play": "play_music",
	"music_stop": "stop_music",
	"achievement_unlock": "unlock_achievement",
	"story_event": "set_event_value",
	"event_value": "set_event_value",
	"story_events": "set_event_values",
	"event_values": "set_event_values",
	"erase_event_value": "clear_event_value",
	"erase_event_values": "clear_event_values",
	"insert_story_trigger": "add_story_trigger",
	"queue_story_trigger": "add_story_trigger",
	"insert_seeded_rider": "add_seeded_rider_rule",
	"seed_rider": "add_seeded_rider_rule",
	"gain_money": "add_money",
	"pay_money": "spend_money",
	"take_all_money": "spend_all_money",
	"pay_debt_goal": "collect_debt",
	"gain_energy": "add_energy",
	"gain_max_energy": "add_max_energy",
	"change_karma": "add_karma",
	"increase_character_progress": "add_character_progress",
	"character_progress": "add_character_progress",
	"character_progress_set": "set_character_progress",
	"character_story_lock": "set_character_story_lock",
	"pending_night_skip": "set_pending_night_skip",
	"skip_night_phase": "set_pending_night_skip",
	"sfx_play": "play_sfx",
	"cue_phone_sound": "play_sfx",
	"phone_sound": "play_sfx",
	"sfx_stop": "stop_sfx",
	"change_portrait": "set_portrait",
	"focus_portrait": "portrait_switch",
	"dialogue": "set_dialogue",
	"bg_camera": "background_camera",
	"camera": "background_camera",
	"bg_zoom": "zoom_background",
	"bg_pan": "pan_background",
	"bg_reset": "reset_background_camera",
}

const DESTINATIONS := {
	"home": "res://scenes/day_start_scene.tscn",
	"store": "res://scenes/store.tscn",
	"ride_selection": "res://scenes/ride_selection.tscn",
	"main_menu": "res://scenes/main_menu.tscn",
}


static func canonical_type(action_type: String) -> String:
	var normalized := action_type.strip_edges().to_lower()
	return str(ALIASES.get(normalized, normalized))


static func is_known(action_type: String) -> bool:
	return ACTIONS.has(canonical_type(action_type))


static func is_persistent(action_type: String) -> bool:
	return bool(ACTIONS.get(canonical_type(action_type), false))


static func validate_action(action: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var type := canonical_type(str(action.get("type", action.get("action", ""))))
	if not is_known(type):
		errors.append("Unknown story action '%s'" % type)
		return errors
	if GameEffects.supports(type):
		var canonical := action.duplicate(true)
		canonical["type"] = type
		return GameEffects.validate(canonical)
	match type:
		"set_character_sprite":
			_require_text(action, "character_id", errors)
			_require_text(action, "sprite", errors)
			if not CharacterSprites.is_valid(str(action.get("character_id", "")), str(action.get("sprite", ""))):
				errors.append("Unknown character sprite")
		"advance_time":
			if action.has("days") == action.has("phases"):
				errors.append("advance_time needs exactly one of days or phases")
			else:
				_validate_count(action.get("days", action.get("phases")), 365 if action.has("days") else 1095, errors)
		"skip_days", "skip_phases":
			_validate_count(action.get("amount", 1), 365 if type == "skip_days" else 1095, errors)
		"queue_story":
			_require_text(action, "id", errors)
		"return_to":
			if not DESTINATIONS.has(str(action.get("destination", ""))):
				errors.append("Destination must be home, store, ride_selection, or main_menu")
		"selection_outcome":
			if str(action.get("outcome", "")) not in ["return", "ride", "skip"]:
				errors.append("selection_outcome must be return, ride, or skip")
		"end_run":
			_require_text(action, "reason", errors)
	if type in ["advance_time", "skip_days", "skip_phases"]:
		var options := action.duplicate(true)
		if type != "advance_time":
			options["days" if type == "skip_days" else "phases"] = action.get("amount", 1)
		var error := StoryTime.validation_error(options)
		if not error.is_empty() and error not in errors:
			errors.append(error)
	return errors


static func _require_text(action: Dictionary, key: String, errors: PackedStringArray) -> void:
	if not action.get(key) is String or str(action.get(key, "")).strip_edges().is_empty():
		errors.append("%s needs a nonempty string" % key)


static func _validate_count(value, maximum: int, errors: PackedStringArray) -> void:
	if not _is_number(value) or float(value) < 1.0 or float(value) > maximum or float(value) != floorf(float(value)):
		errors.append("Time amount must be a whole number from 1 to %d" % maximum)


static func _is_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))
