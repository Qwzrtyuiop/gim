extends RefCounted
class_name StoryActionRunner

const RandomRideEventService := preload("res://scripts/story/random_ride_event_service.gd")
const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")
const PlayerDebtState := preload("res://scripts/state/player_debt_state.gd")
const StoryAudioRuntime := preload("res://scripts/story/story_audio_runtime.gd")
const StoryPresentation := preload("res://scripts/story/story_presentation.gd")
const StoryInterface := preload("res://scripts/story/story_interface.gd")
const StoryActionCatalog := preload("res://scripts/story/story_action_catalog.gd")
const StoryGameFlow := preload("res://scripts/story/story_game_flow.gd")
const StoryGameEffects := preload("res://scripts/story/story_game_effects.gd")


static func run(owner, action_data: Dictionary) -> void:
	var errors := StoryActionCatalog.validate_action(action_data)
	if not errors.is_empty():
		push_warning("Story action rejected: %s" % "; ".join(errors))
		return
	var action_type := StoryActionCatalog.canonical_type(str(action_data.get("type", action_data.get("action", ""))))
	if StoryActionCatalog.is_persistent(action_type) and bool(owner.story_payload.get("replay", owner.story_payload.get("memory_replay", false))):
		return
	action_data = action_data.duplicate(true)
	action_data["type"] = action_type
	if StoryGameFlow.supports(action_type):
		StoryGameFlow.run(owner, action_data)
		return
	if StoryGameEffects.supports(action_type):
		StoryGameEffects.run(owner, action_data)
		return
	match action_type:
		"resolve_bayanihan":
			RandomRideEventService.resolve_bayanihan(PlayerState, owner.story_payload, str(action_data.get("outcome", "")))
		"show_weekly_debt_transition":
			await StoryInterface.show_weekly_debt_transition(owner)
		"hide_weekly_debt_transition":
			StoryInterface.hide_weekly_debt_transition(owner)
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
			await StoryPresentation.pause_for_seconds(owner, float(action_data.get("duration", action_data.get("time", 0.0))))
		"fade_to_black", "screen_fade_out":
			await StoryPresentation.fade_background_overlay(owner, 1.0, float(action_data.get("duration", StoryPresentation.DEFAULT_SCREEN_FADE_SECONDS)))
		"fade_from_black", "screen_fade_in":
			await StoryPresentation.fade_background_overlay(owner, 0.0, float(action_data.get("duration", StoryPresentation.DEFAULT_SCREEN_FADE_SECONDS)))
		"fade_screen":
			await StoryPresentation.fade_background_overlay(
				owner,
				clampf(float(action_data.get("alpha", action_data.get("target_alpha", owner.background_fade_overlay.color.a))), 0.0, 1.0),
				float(action_data.get("duration", StoryPresentation.DEFAULT_SCREEN_FADE_SECONDS))
			)
		"play_music", "music_play":
			await StoryAudioRuntime.play_music_action(owner, action_data)
		"stop_music", "music_stop":
			await StoryAudioRuntime.stop_music_action(owner, action_data)
		"unlock_achievement", "achievement_unlock":
			PlayerState.unlock_achievement(str(action_data.get("id", action_data.get("achievement_id", ""))))
		"set_event_value", "story_event", "event_value":
			apply_set_event_value_action(action_data)
		"set_event_values", "story_events", "event_values":
			apply_set_event_values_action(action_data)
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
			apply_character_progress_action(action_data)
		"set_character_progress", "character_progress_set":
			apply_set_character_progress_action(action_data)
		"set_character_story_lock", "character_story_lock":
			apply_character_story_lock_action(action_data)
		"set_pending_night_skip", "pending_night_skip", "skip_night_phase":
			PlayerState.set_pending_night_phase_skip(bool(action_data.get("enabled", action_data.get("value", true))))
		"clear_pending_night_skip":
			PlayerState.clear_pending_night_phase_skip()
		"play_sfx", "sfx_play", "cue_phone_sound", "phone_sound":
			StoryAudioRuntime.play_sfx_action(owner, action_data)
		"stop_sfx", "sfx_stop":
			StoryAudioRuntime.stop_sfx_action(owner)
		"set_portrait", "change_portrait":
			StoryPresentation.apply_portrait_action(owner, action_data)
		"set_character_sprite":
			StoryPresentation.apply_character_sprite_action(owner, action_data)
		"set_portraits":
			StoryPresentation.replace_portraits(owner, action_data.get("portraits", []))
		"clear_portraits":
			StoryPresentation.replace_portraits(owner, [])
		"clear_portrait":
			StoryPresentation.clear_portrait_action(owner, action_data)
		"portrait_switch", "focus_portrait":
			StoryPresentation.apply_portrait_focus_from_side(owner, str(action_data.get("side", action_data.get("focus", "none"))))
		"set_dialogue", "dialogue":
			StoryInterface.set_dialogue_content(
				owner,
				str(action_data.get("speaker", owner.speaker_label.text)),
				str(action_data.get("text", owner.body_label.text)),
				str(action_data.get("continue_hint", owner.continue_label.text if not owner.continue_label.text.is_empty() else StoryInterface.DEFAULT_CONTINUE_HINT)),
				bool(action_data.get("visible", true))
			)
			if bool(action_data.get("visible", true)) and is_instance_valid(owner.get("dialogue_playback")):
				var reveal_line: Dictionary = owner._current_line().duplicate(true)
				if action_data.has("typewriter"):
					reveal_line["typewriter"] = action_data.typewriter
				owner.dialogue_playback.start(owner.story_payload, reveal_line, str(action_data.get("speaker", owner._current_line().get("speaker", ""))))
		"background_camera", "bg_camera", "camera":
			StoryPresentation.apply_background_camera_action(owner, action_data)
		"zoom_background", "bg_zoom":
			StoryPresentation.apply_background_camera_action(owner, {
				"zoom": action_data.get("zoom", action_data.get("value", action_data.get("amount", owner.background_zoom))),
				"duration": action_data.get("duration", StoryPresentation.DEFAULT_BG_CAMERA_DURATION),
			})
		"pan_background", "bg_pan":
			StoryPresentation.apply_background_camera_action(owner, {
				"pan": action_data.get("pan", action_data.get("value", action_data.get("offset", action_data.get("focus", null)))),
				"duration": action_data.get("duration", StoryPresentation.DEFAULT_BG_CAMERA_DURATION),
			})
		"reset_background_camera", "bg_reset":
			StoryPresentation.set_background_camera(owner, 1.0, Vector2.ZERO, float(action_data.get("duration", StoryPresentation.DEFAULT_BG_CAMERA_DURATION)))
		"hide_dialogue":
			if is_instance_valid(owner.get("dialogue_playback")):
				owner.dialogue_playback.finish_now()
			owner.dialogue_panel.visible = false
		"show_dialogue":
			owner.dialogue_panel.visible = true
		"set_background":
			owner.current_background_ref = action_data.get("texture", action_data.get("background", action_data.get("path", null)))
			StoryPresentation.set_background_texture(owner, owner.current_background_ref, not bool(action_data.get("preserve_camera", false)))
			if StoryPresentation.has_background_camera_data(action_data):
				StoryPresentation.apply_background_camera_action(owner, action_data)


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


static func is_persistent_story_action(action_data: Dictionary) -> bool:
	return StoryActionCatalog.is_persistent(str(action_data.get("type", action_data.get("action", ""))))


static func apply_character_progress_action(action_data: Dictionary) -> void:
	var character_id := str(action_data.get("character_id", action_data.get("id", PlayerState.get_current_mock_character_id())))
	var amount := int(action_data.get("amount", action_data.get("value", 1)))
	PlayerState.increment_unique_character_progress(character_id, amount)


static func apply_set_character_progress_action(action_data: Dictionary) -> void:
	var character_id := str(action_data.get("character_id", action_data.get("id", PlayerState.get_current_mock_character_id())))
	var value := int(action_data.get("value", action_data.get("amount", 0)))
	PlayerState.set_unique_character_progress(character_id, value)


static func apply_character_story_lock_action(action_data: Dictionary) -> void:
	var character_id := str(action_data.get("character_id", action_data.get("id", PlayerState.get_current_mock_character_id())))
	PlayerState.set_unique_character_story_locked(
		character_id,
		bool(action_data.get("locked", action_data.get("value", true)))
	)


static func apply_choice_event_values(choice_data: Dictionary) -> void:
	if choice_data.has("event_values"):
		PlayerState.set_event_values(choice_data.get("event_values", {}))
	elif choice_data.has("event_id") or choice_data.has("event_value") or choice_data.has("key"):
		PlayerState.set_event_values(
			StoryEventHandler.build_single_event_values(
				str(choice_data.get("event_id", choice_data.get("key", ""))),
				choice_data.get("event_value", choice_data.get("value", 1))
			)
		)


static func apply_set_event_value_action(action_data: Dictionary) -> void:
	var event_id := str(action_data.get("id", action_data.get("event_id", action_data.get("key", ""))))
	if event_id.is_empty():
		return
	PlayerState.set_event_values(
		StoryEventHandler.build_single_event_values(
			event_id,
			action_data.get("value", action_data.get("amount", 1))
		)
	)


static func apply_set_event_values_action(action_data: Dictionary) -> void:
	var values: Variant = action_data.get("values", action_data.get("events", {}))
	if not values is Dictionary:
		return
	PlayerState.set_event_values((values as Dictionary).duplicate(true))
