extends RefCounted
class_name PlayerStateSaveCodec

const GameSaveResource := preload("res://scripts/save/game_save_resource.gd")
const PlayerDayPhaseTracker := preload("res://scripts/state/player_day_phase_tracker.gd")
const SeededRiderRuntime := preload("res://scripts/seeded_rider_runtime.gd")
const StoryTriggerService := preload("res://scripts/story/story_trigger_service.gd")
const RandomRideEventService := preload("res://scripts/story/random_ride_event_service.gd")
const AssetPathMigration := preload("res://scripts/save/asset_path_migration.gd")


static func load_from_path(player_state, save_path: String) -> bool:
	if not FileAccess.file_exists(save_path):
		return false

	var loaded_resource := ResourceLoader.load(save_path)
	if not loaded_resource is GameSaveResource:
		return false

	var save_resource := loaded_resource as GameSaveResource
	var saved_version := int(save_resource.version)
	var save_data: Dictionary = save_resource.data.duplicate(true)
	if save_data.is_empty():
		return false

	var needs_migration_save := saved_version < 4
	var migrated_data: Dictionary = AssetPathMigration.migrate(save_data)
	if migrated_data != save_data:
		save_data = migrated_data
		needs_migration_save = true
	player_state._is_loading_save = true
	player_state._begin_state_batch()
	player_state.money = int(save_data.get("money", player_state.money))
	var saved_max_energy := int(save_data.get("max_energy", player_state.max_energy))
	var saved_energy := int(save_data.get("energy", player_state.energy))
	if saved_version < 2 and saved_max_energy <= 5:
		player_state.max_energy = maxi(1, player_state.DEFAULT_MAX_ENERGY - maxi(0, 5 - saved_max_energy) * 2)
		player_state.energy = clampi(
			roundi(float(saved_energy) / maxf(1.0, float(saved_max_energy)) * float(player_state.max_energy)),
			0,
			player_state.max_energy
		)
	else:
		player_state.max_energy = saved_max_energy
		player_state.energy = saved_energy
	var saved_max_gas := float(save_data.get("max_gas", player_state.max_gas))
	var saved_gas := float(save_data.get("gas", player_state.gas))
	if saved_version < 2 and saved_max_gas <= 10.0:
		player_state.max_gas = player_state.DEFAULT_MAX_GAS_PERCENT
		player_state.gas = clampf(saved_gas / maxf(1.0, saved_max_gas) * player_state.max_gas, 0.0, player_state.max_gas)
	else:
		player_state.max_gas = saved_max_gas
		player_state.gas = saved_gas
	player_state.gas_price = int(save_data.get("gas_price", player_state.gas_price))
	player_state.previous_gas_price = int(save_data.get("previous_gas_price", player_state.previous_gas_price))
	player_state.gas_price_delta = int(save_data.get("gas_price_delta", player_state.gas_price - player_state.previous_gas_price))
	player_state.current_weather = str(save_data.get("current_weather", player_state.current_weather))
	player_state.weather_forecasts = Dictionary(save_data.get("weather_forecasts", player_state.weather_forecasts)).duplicate(true)
	player_state.weather_phase_cache = Dictionary(save_data.get("weather_phase_cache", player_state.weather_phase_cache)).duplicate(true)
	player_state.daily_conditions_day = int(save_data.get("daily_conditions_day", 0))
	player_state.karma = int(save_data.get("karma", player_state.karma))
	player_state.current_stage_type = str(save_data.get("current_stage_type", player_state.current_stage_type))
	player_state.current_stage_special_type = player_state.normalize_stage_special_type(
		str(save_data.get("current_stage_special_type", player_state.current_stage_special_type))
	)
	player_state.current_special_stage_id = player_state.normalize_special_stage_id(
		str(save_data.get("current_special_stage_id", player_state.current_special_stage_id))
	)
	if player_state.current_stage_special_type != player_state.STAGE_SPECIAL_TYPE_SPECIAL:
		player_state.current_special_stage_id = ""
	player_state.current_day = int(save_data.get("current_day", player_state.current_day))
	var saved_current_phase: String = str(save_data.get("current_phase", "")).strip_edges().to_lower()
	if saved_current_phase.is_empty():
		saved_current_phase = PlayerDayPhaseTracker.phase_from_stage_type(player_state, player_state.current_stage_type)
	player_state.current_phase = PlayerDayPhaseTracker.normalize_phase(player_state, saved_current_phase)
	PlayerDayPhaseTracker.sync_stage_type_to_phase(player_state)
	player_state.stage_round = int(save_data.get("stage_round", player_state.stage_round))
	player_state.pending_stage_energy_cost = bool(save_data.get("pending_stage_energy_cost", player_state.pending_stage_energy_cost))
	player_state.pending_trip_selection = Dictionary(save_data.get("pending_trip_selection", {})).duplicate(true)
	player_state.pending_story = Dictionary(save_data.get("pending_story", {})).duplicate(true)
	player_state.active_event_special_stage = Dictionary(save_data.get("active_event_special_stage", {})).duplicate(true)
	player_state.pending_sleep_transition_state = Dictionary(save_data.get("pending_sleep_transition_state", {})).duplicate(true)
	player_state.pending_crash_repair = Dictionary(save_data.get("pending_crash_repair", {})).duplicate(true)
	player_state.pending_gameplay_entry_fade_duration = float(save_data.get("pending_gameplay_entry_fade_duration", player_state.pending_gameplay_entry_fade_duration))
	player_state.pending_skip_night_phase = bool(save_data.get("pending_skip_night_phase", player_state.pending_skip_night_phase))
	player_state.current_mock_character_id = str(save_data.get("current_mock_character_id", player_state.current_mock_character_id))
	player_state.seen_mock_characters = Dictionary(save_data.get("seen_mock_characters", {})).duplicate(true)
	player_state.unique_character_progress = Dictionary(save_data.get("unique_character_progress", {})).duplicate(true)
	# Older saves tracked completed rides through story progress only.
	player_state.character_completed_rides = Dictionary(save_data.get("character_completed_rides", player_state.unique_character_progress)).duplicate(true)
	player_state.locked_unique_character_stories = Dictionary(save_data.get("locked_unique_character_stories", {})).duplicate(true)
	player_state.consumed_unique_session_dialogue = Dictionary(save_data.get("consumed_unique_session_dialogue", {})).duplicate(true)
	player_state.seeded_rider_rules.clear()
	var saved_seeded_rider_rules: Array = save_data.get("seeded_rider_rules", [])
	for rule_data in saved_seeded_rider_rules:
		if rule_data is Dictionary:
			var normalized_rule := SeededRiderRuntime.normalize_rule(player_state, (rule_data as Dictionary).duplicate(true))
			if normalized_rule.is_empty():
				continue
			player_state.seeded_rider_rules.append(normalized_rule)
	player_state.consumed_seeded_rider_rules = Dictionary(save_data.get("consumed_seeded_rider_rules", {})).duplicate(true)
	player_state.last_rest_day = int(save_data.get("last_rest_day", player_state.last_rest_day))
	player_state.yosi_bought_today = int(save_data.get("yosi_bought_today", player_state.yosi_bought_today))
	player_state.yosi_bought_day = int(save_data.get("yosi_bought_day", player_state.yosi_bought_day))
	player_state.yosi_bought_total = int(save_data.get("yosi_bought_total", player_state.yosi_bought_total))
	player_state.rests_taken_today = int(save_data.get("rests_taken_today", player_state.rests_taken_today))
	player_state.rests_taken_day = int(save_data.get("rests_taken_day", player_state.rests_taken_day))
	player_state.tamad_rest_day = int(save_data.get("tamad_rest_day", player_state.tamad_rest_day))
	player_state.tamad_rest_times_today.clear()
	var saved_tamad_rest_times: Array = save_data.get("tamad_rest_times_today", [])
	for rest_time_variant in saved_tamad_rest_times:
		var normalized_rest_time: String = player_state._normalize_tamad_rest_time(str(rest_time_variant))
		if normalized_rest_time.is_empty() or player_state.tamad_rest_times_today.has(normalized_rest_time):
			continue
		player_state.tamad_rest_times_today.append(normalized_rest_time)
	player_state.rides_completed_today = int(save_data.get("rides_completed_today", player_state.rides_completed_today))
	player_state.rides_completed_day = int(save_data.get("rides_completed_day", player_state.rides_completed_day))
	player_state.non_gas_store_purchases_this_week = int(save_data.get("non_gas_store_purchases_this_week", player_state.non_gas_store_purchases_this_week))
	player_state.clean_stage_streak = int(save_data.get("clean_stage_streak", player_state.clean_stage_streak))
	player_state.current_trip_had_crash = bool(save_data.get("current_trip_had_crash", false))
	player_state.current_trip_low_energy = bool(save_data.get("current_trip_low_energy", player_state.current_trip_low_energy))
	player_state.current_trip_low_gas = bool(save_data.get("current_trip_low_gas", player_state.current_trip_low_gas))
	player_state.low_resource_trip_count = int(save_data.get("low_resource_trip_count", player_state.low_resource_trip_count))
	player_state.low_both_resource_trip_count = int(save_data.get("low_both_resource_trip_count", player_state.low_both_resource_trip_count))
	player_state.debt_goal_index = int(save_data.get("debt_goal_index", player_state.debt_goal_index))
	player_state.debt_carryover = maxi(0, int(save_data.get("debt_carryover", 0)))
	player_state.last_debt_collection = Dictionary(save_data.get("last_debt_collection", {})).duplicate(true)
	player_state.last_debt_collection_day = int(save_data.get("last_debt_collection_day", player_state.last_debt_collection_day))
	player_state.remaining_debt = int(save_data.get("remaining_debt", player_state.remaining_debt))
	player_state.run_failed = bool(save_data.get("run_failed", player_state.run_failed))
	player_state.run_fail_reason = str(save_data.get("run_fail_reason", player_state.run_fail_reason))
	player_state.last_stage_result = Dictionary(save_data.get("last_stage_result", {})).duplicate(true)
	player_state.story_triggers.clear()
	var saved_story_triggers: Array = save_data.get("story_triggers", [])
	for trigger_data in saved_story_triggers:
		if trigger_data is Dictionary:
			var normalized_trigger := StoryTriggerService.normalize_trigger(player_state, (trigger_data as Dictionary).duplicate(true))
			if normalized_trigger.is_empty():
				continue
			player_state.story_triggers.append(normalized_trigger)
	var needs_story_trigger_save := StoryTriggerService.ensure_required_story_triggers(player_state.story_triggers)
	player_state.consumed_story_triggers = Dictionary(save_data.get("consumed_story_triggers", {})).duplicate(true)
	player_state.upgrades = Dictionary(save_data.get("upgrades", {})).duplicate(true)
	player_state.achievements = Dictionary(save_data.get("achievements", {})).duplicate(true)
	player_state.last_seen_story_sections = Dictionary(save_data.get("last_seen_story_sections", {})).duplicate(true)
	player_state.last_seen_story_id = str(save_data.get("last_seen_story_id", ""))
	player_state.event_values = Dictionary(save_data.get("event_values", {})).duplicate(true)
	# Earlier builds had only one weekly goal, so successful collections kept index 0.
	if not save_data.has("debt_carryover") and player_state.last_debt_collection_day >= 8 and not player_state.run_failed and player_state.debt_goal_index == 0:
		player_state.debt_goal_index = mini(1, player_state.WEEKLY_DEBT_GOALS.size() - 1)
		needs_migration_save = true
	if RandomRideEventService.migrate_waived_earnings(player_state):
		needs_migration_save = true
	player_state.unlocked_gallery_images = Dictionary(save_data.get("unlocked_gallery_images", {})).duplicate(true)
	player_state.gallery_image_unlocks_initialized = bool(save_data.get("gallery_image_unlocks_initialized", saved_version >= 4))
	player_state.resume_scene_path = str(save_data.get("resume_scene_path", ""))
	player_state.ride_select_tutorial_shown = bool(save_data.get("ride_select_tutorial_shown", player_state.ride_select_tutorial_shown))
	player_state.store_tutorial_shown = bool(save_data.get("store_tutorial_shown", player_state.store_tutorial_shown))
	player_state.home_tutorial_shown = bool(save_data.get("home_tutorial_shown", player_state.home_tutorial_shown))
	player_state._end_state_batch(false, true)
	player_state._is_loading_save = false
	if needs_story_trigger_save or needs_migration_save:
		player_state.save_progress()
	return true


static func save_to_path(player_state, save_path: String, save_version: int) -> void:
	if player_state._is_loading_save:
		return

	var save_resource := GameSaveResource.new()
	save_resource.version = save_version
	save_resource.data = {
		"money": player_state.money,
		"max_energy": player_state.max_energy,
		"energy": player_state.energy,
		"max_gas": player_state.max_gas,
		"gas": player_state.gas,
		"gas_price": player_state.gas_price,
		"gas_price_delta": player_state.gas_price_delta,
		"previous_gas_price": player_state.previous_gas_price,
		"current_weather": player_state.current_weather,
		"weather_forecasts": player_state.weather_forecasts.duplicate(true),
		"weather_phase_cache": player_state.weather_phase_cache.duplicate(true),
		"daily_conditions_day": player_state.daily_conditions_day,
		"karma": player_state.karma,
		"current_stage_type": player_state.current_stage_type,
		"current_stage_special_type": player_state.current_stage_special_type,
		"current_special_stage_id": player_state.current_special_stage_id,
		"current_day": player_state.current_day,
		"current_phase": player_state.current_phase,
		"stage_round": player_state.stage_round,
		"pending_stage_energy_cost": player_state.pending_stage_energy_cost,
		"pending_trip_selection": player_state.pending_trip_selection.duplicate(true),
		"pending_story": player_state.pending_story.duplicate(true),
		"active_event_special_stage": player_state.active_event_special_stage.duplicate(true),
		"pending_sleep_transition_state": player_state.pending_sleep_transition_state.duplicate(true),
		"pending_crash_repair": player_state.pending_crash_repair.duplicate(true),
		"pending_gameplay_entry_fade_duration": player_state.pending_gameplay_entry_fade_duration,
		"pending_skip_night_phase": player_state.pending_skip_night_phase,
		"current_mock_character_id": player_state.current_mock_character_id,
		"seen_mock_characters": player_state.seen_mock_characters.duplicate(true),
		"unique_character_progress": player_state.unique_character_progress.duplicate(true),
		"character_completed_rides": player_state.character_completed_rides.duplicate(true),
		"locked_unique_character_stories": player_state.locked_unique_character_stories.duplicate(true),
		"consumed_unique_session_dialogue": player_state.consumed_unique_session_dialogue.duplicate(true),
		"seeded_rider_rules": player_state.seeded_rider_rules.duplicate(true),
		"consumed_seeded_rider_rules": player_state.consumed_seeded_rider_rules.duplicate(true),
		"last_rest_day": player_state.last_rest_day,
		"yosi_bought_today": player_state.yosi_bought_today,
		"yosi_bought_day": player_state.yosi_bought_day,
		"yosi_bought_total": player_state.yosi_bought_total,
		"rests_taken_today": player_state.rests_taken_today,
		"rests_taken_day": player_state.rests_taken_day,
		"tamad_rest_day": player_state.tamad_rest_day,
		"tamad_rest_times_today": player_state.tamad_rest_times_today.duplicate(),
		"rides_completed_today": player_state.rides_completed_today,
		"rides_completed_day": player_state.rides_completed_day,
		"non_gas_store_purchases_this_week": player_state.non_gas_store_purchases_this_week,
		"clean_stage_streak": player_state.clean_stage_streak,
		"current_trip_had_crash": player_state.current_trip_had_crash,
		"current_trip_low_energy": player_state.current_trip_low_energy,
		"current_trip_low_gas": player_state.current_trip_low_gas,
		"low_resource_trip_count": player_state.low_resource_trip_count,
		"low_both_resource_trip_count": player_state.low_both_resource_trip_count,
		"debt_goal_index": player_state.debt_goal_index,
		"debt_carryover": player_state.debt_carryover,
		"last_debt_collection": player_state.last_debt_collection.duplicate(true),
		"last_debt_collection_day": player_state.last_debt_collection_day,
		"remaining_debt": player_state.remaining_debt,
		"run_failed": player_state.run_failed,
		"run_fail_reason": player_state.run_fail_reason,
		"last_stage_result": player_state.last_stage_result.duplicate(true),
		"story_triggers": player_state.story_triggers.duplicate(true),
		"consumed_story_triggers": player_state.consumed_story_triggers.duplicate(true),
		"upgrades": player_state.upgrades.duplicate(true),
		"achievements": player_state.achievements.duplicate(true),
		"last_seen_story_sections": player_state.last_seen_story_sections.duplicate(true),
		"last_seen_story_id": player_state.last_seen_story_id,
		"event_values": player_state.event_values.duplicate(true),
		"unlocked_gallery_images": player_state.unlocked_gallery_images.duplicate(true),
		"gallery_image_unlocks_initialized": player_state.gallery_image_unlocks_initialized,
		"resume_scene_path": player_state.resume_scene_path,
		"ride_select_tutorial_shown": player_state.ride_select_tutorial_shown,
		"store_tutorial_shown": player_state.store_tutorial_shown,
		"home_tutorial_shown": player_state.home_tutorial_shown,
	}
	ResourceSaver.save(save_resource, save_path)
