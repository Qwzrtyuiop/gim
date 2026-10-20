extends RefCounted
class_name StoryActionRunner

const RandomRideEventService := preload("res://scripts/story/random_ride_event_service.gd")
const PlayerDebtState := preload("res://scripts/state/player_debt_state.gd")


static func run(owner, action_data: Dictionary) -> void:
	var action_type := str(action_data.get("type", action_data.get("action", ""))).to_lower()
	match action_type:
		"show_weekly_debt_transition":
			await owner._show_weekly_debt_transition()
		"hide_weekly_debt_transition":
			owner._hide_weekly_debt_transition()
		"collect_first_week_interest":
			PlayerDebtState.collect_first_week_interest(PlayerState, int(action_data.get("amount", 500)))
		"repay_malasakit_fare":
			RandomRideEventService.repay_malasakit_fare(PlayerState, owner.story_payload)
		"resolve_random_ride_fare":
			RandomRideEventService.resolve_fare(PlayerState, owner.story_payload, str(action_data.get("outcome", "")))
		"start_special_stage":
			# Queue the handoff; the rest of the event still plays normally.
			owner.story_payload["queued_special_stage_id"] = str(action_data.get("id", action_data.get("special_stage_id", "")))
			PlayerState.set_pending_story(owner.story_payload)
		"pause", "wait":
			await owner._pause_for_seconds(float(action_data.get("duration", action_data.get("time", 0.0))))
		"fade_to_black", "screen_fade_out":
			await owner._fade_background_overlay(1.0, float(action_data.get("duration", owner.DEFAULT_SCREEN_FADE_SECONDS)))
		"fade_from_black", "screen_fade_in":
			await owner._fade_background_overlay(0.0, float(action_data.get("duration", owner.DEFAULT_SCREEN_FADE_SECONDS)))
		"fade_screen":
			await owner._fade_background_overlay(
				clampf(float(action_data.get("alpha", action_data.get("target_alpha", owner.background_fade_overlay.color.a))), 0.0, 1.0),
				float(action_data.get("duration", owner.DEFAULT_SCREEN_FADE_SECONDS))
			)
		"play_music", "music_play":
			await owner._play_music_action(action_data)
		"stop_music", "music_stop":
			await owner._stop_music_action(action_data)
		"unlock_achievement", "achievement_unlock":
			PlayerState.unlock_achievement(str(action_data.get("id", action_data.get("achievement_id", ""))))
		"set_event_value", "story_event", "event_value":
			owner._apply_set_event_value_action(action_data)
		"set_event_values", "story_events", "event_values":
			owner._apply_set_event_values_action(action_data)
		"clear_event_value", "erase_event_value":
			PlayerState.clear_event_value(str(action_data.get("id", action_data.get("event_id", action_data.get("key", "")))))
		"clear_event_values", "erase_event_values":
			PlayerState.clear_event_values()
		"add_story_trigger", "insert_story_trigger", "queue_story_trigger":
			_add_story_trigger_from_action(action_data)
		"add_seeded_rider_rule", "insert_seeded_rider", "seed_rider":
			_add_seeded_rider_from_action(action_data)
		"add_money", "gain_money":
			PlayerState.add_money(int(action_data.get("amount", 0)))
		"spend_money", "pay_money":
			PlayerState.spend_money(int(action_data.get("amount", 0)))
			PlayerState.save_progress()
		"spend_all_money", "take_all_money":
			PlayerState.spend_money(maxi(0, int(PlayerState.money)))
			PlayerState.save_progress()
		"collect_debt", "pay_debt_goal":
			var collection_day: int = int(action_data.get("day", action_data.get("day_number", PlayerState.get_current_day())))
			PlayerState._resolve_debt_collection_for_day(collection_day)
		"add_energy", "gain_energy":
			PlayerState.add_energy(int(action_data.get("amount", 0)))
		"add_max_energy", "gain_max_energy":
			PlayerState.add_max_energy(int(action_data.get("amount", 0)))
		"add_karma", "change_karma":
			PlayerState.add_karma(int(action_data.get("amount", 0)))
		"add_character_progress", "increase_character_progress", "character_progress":
			owner._apply_character_progress_action(action_data)
		"set_character_progress", "character_progress_set":
			owner._apply_set_character_progress_action(action_data)
		"set_character_story_lock", "character_story_lock":
			owner._apply_character_story_lock_action(action_data)
		"set_pending_night_skip", "pending_night_skip", "skip_night_phase":
			PlayerState.set_pending_night_phase_skip(bool(action_data.get("enabled", action_data.get("value", true))))
		"clear_pending_night_skip":
			PlayerState.clear_pending_night_phase_skip()
		"play_sfx", "sfx_play", "cue_phone_sound", "phone_sound":
			owner._play_sfx_action(action_data)
		"stop_sfx", "sfx_stop":
			owner.sfx_player.stop()
		"set_portrait", "change_portrait":
			owner._apply_portrait_action(action_data)
		"set_portraits":
			owner._replace_portraits(action_data.get("portraits", []))
		"clear_portraits":
			owner._replace_portraits([])
		"clear_portrait":
			owner._clear_portrait_action(action_data)
		"portrait_switch", "focus_portrait":
			owner._apply_portrait_focus_from_side(str(action_data.get("side", action_data.get("focus", "none"))))
		"set_dialogue", "dialogue":
			owner._set_dialogue_content(
				str(action_data.get("speaker", owner.speaker_label.text)),
				str(action_data.get("text", owner.body_label.text)),
				str(action_data.get("continue_hint", owner.continue_label.text if not owner.continue_label.text.is_empty() else owner.DEFAULT_CONTINUE_HINT)),
				bool(action_data.get("visible", true))
			)
		"background_camera", "bg_camera", "camera":
			owner._apply_background_camera_action(action_data)
		"zoom_background", "bg_zoom":
			owner._apply_background_camera_action({
				"zoom": action_data.get("zoom", action_data.get("value", action_data.get("amount", owner.background_zoom))),
				"duration": action_data.get("duration", owner.DEFAULT_BG_CAMERA_DURATION),
			})
		"pan_background", "bg_pan":
			owner._apply_background_camera_action({
				"pan": action_data.get("pan", action_data.get("value", action_data.get("offset", action_data.get("focus", null)))),
				"duration": action_data.get("duration", owner.DEFAULT_BG_CAMERA_DURATION),
			})
		"reset_background_camera", "bg_reset":
			owner._set_background_camera(1.0, Vector2.ZERO, float(action_data.get("duration", owner.DEFAULT_BG_CAMERA_DURATION)))
		"hide_dialogue":
			owner.dialogue_panel.visible = false
		"show_dialogue":
			owner.dialogue_panel.visible = true
		"set_background":
			owner.current_background_ref = action_data.get("texture", action_data.get("background", action_data.get("path", null)))
			owner._set_background_texture(owner.current_background_ref, not bool(action_data.get("preserve_camera", false)))
			if owner._has_background_camera_data(action_data):
				owner._apply_background_camera_action(action_data)


static func _add_story_trigger_from_action(action_data: Dictionary) -> void:
	var trigger_data: Dictionary = _extract_payload_dictionary(action_data, ["trigger", "trigger_data", "data"])
	if trigger_data.is_empty():
		trigger_data = action_data.duplicate(true)
		_strip_action_keys(trigger_data)
	PlayerState.add_story_trigger(trigger_data)


static func _add_seeded_rider_from_action(action_data: Dictionary) -> void:
	var rule_data: Dictionary = _extract_payload_dictionary(action_data, ["rule", "rider_rule", "seed", "data"])
	if rule_data.is_empty():
		rule_data = action_data.duplicate(true)
		_strip_action_keys(rule_data)
	PlayerState.add_seeded_rider_rule(rule_data)


static func _extract_payload_dictionary(action_data: Dictionary, keys: Array[String]) -> Dictionary:
	for key in keys:
		var value = action_data.get(key, null)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


static func _strip_action_keys(data: Dictionary) -> void:
	data.erase("type")
	data.erase("action")
