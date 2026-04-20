extends RefCounted

const GameEconomyManager := preload("res://scripts/game/game_economy_manager.gd")
const StageProfiles := preload("res://scripts/game/stage_profiles.gd")


static func apply_stage_profile(owner) -> void:
	if not owner.use_stage_profile:
		return

	var parts: Dictionary = parse_stage_type(owner.stage_type)
	owner.stage_difficulty = parts["difficulty"]
	owner.stage_time_of_day = parts["time"]
	owner.stage_traffic = parts["traffic"]

	var profile: Dictionary = StageProfiles.DEFAULT_STAGE_PROFILE.duplicate()
	profile.merge(StageProfiles.DIFFICULTY_PROFILES.get(owner.stage_difficulty, {}), true)
	profile.merge(StageProfiles.TIME_PROFILES.get(owner.stage_time_of_day, {}), true)
	profile.merge(StageProfiles.TRAFFIC_PROFILES.get(owner.stage_traffic, {}), true)
	profile.merge(StageProfiles.BACKGROUND_PROFILES.get(owner.background_type, {}), true)

	for setting_name in profile.keys():
		owner.set(setting_name, profile[setting_name])

	apply_hidden_special_modifiers(owner)
	apply_target_distance_roll(owner)


static func parse_stage_type(type_name: String) -> Dictionary:
	var parts := type_name.split("-")
	if parts.size() < 3:
		return {
			"difficulty": "short",
			"time": "morning",
			"traffic": "chill",
		}

	var traffic_name := ""
	for index in range(2, parts.size()):
		if not traffic_name.is_empty():
			traffic_name += "-"
		traffic_name += parts[index]

	if parts[0] == "easy":
		parts[0] = "short"
	if not StageProfiles.DIFFICULTY_PROFILES.has(parts[0]):
		parts[0] = "short"
	if not StageProfiles.TIME_PROFILES.has(parts[1]):
		parts[1] = "morning"
	if not StageProfiles.TRAFFIC_PROFILES.has(traffic_name):
		traffic_name = "chill"

	return {
		"difficulty": parts[0],
		"time": parts[1],
		"traffic": traffic_name,
	}


static func apply_target_distance_roll(owner) -> void:
	if owner.rolled_target_distance <= 0.0 or owner.rolled_target_stage_type != owner.stage_type:
		owner.rolled_target_distance = PlayerState.roll_stage_target_distance(owner.stage_difficulty)
		owner.rolled_target_stage_type = owner.stage_type
	owner.target_distance = owner.rolled_target_distance


static func apply_weather_modifiers(owner) -> void:
	match owner.stage_weather:
		"rain":
			owner.player_brake_deceleration *= 0.85
			owner.player_brake_x *= 0.85
			owner.player_coast_deceleration *= 0.86
		"heavy rain":
			owner.player_brake_deceleration *= 0.72
			owner.player_brake_x *= 0.75
			owner.player_coast_deceleration *= 0.72


static func apply_player_upgrades(owner) -> void:
	var modifiers: Dictionary = GameEconomyManager.player_upgrade_modifiers()
	owner.player_acceleration_x *= float(modifiers["player_acceleration_x"])
	owner.player_max_speed *= float(modifiers["player_max_speed"])
	owner.player_brake_x *= float(modifiers["player_brake_x"])
	owner.player_lane_lerp_x *= float(modifiers["player_lane_lerp_x"])

	var energy_modifiers: Dictionary = PlayerState.get_energy_vehicle_modifiers()
	owner.player_acceleration_x *= float(energy_modifiers["player_acceleration_x"])
	owner.player_max_speed *= float(energy_modifiers["player_max_speed"])
	owner.player_brake_x *= float(energy_modifiers["player_brake_x"])
	owner.player_lane_lerp_x *= float(energy_modifiers["player_lane_lerp_x"])
	owner.player_coast_x *= float(energy_modifiers["player_coast_x"])
	owner.player_wiggle_intensity_x *= float(energy_modifiers["player_wiggle_intensity_x"])


static func apply_character_modifiers(owner) -> void:
	var story_state: Dictionary = PlayerState.get_current_mock_character_story_state({
		"stage_type": owner.stage_type,
		"difficulty": owner.stage_difficulty,
		"time_of_day": owner.stage_time_of_day,
		"traffic": owner.stage_traffic,
	})
	if story_state.is_empty():
		return

	var modifiers: Dictionary = story_state.get("modifiers", {})
	if modifiers.is_empty():
		return

	_apply_numeric_owner_modifier(owner, modifiers, "fare_php_per_meter")
	_apply_numeric_owner_modifier(owner, modifiers, "time_limit")
	_apply_numeric_owner_modifier(owner, modifiers, "time_bonus_php_per_second")
	_apply_numeric_owner_modifier(owner, modifiers, "overtime_fare_penalty_php_per_second")
	_apply_numeric_owner_modifier(owner, modifiers, "player_max_speed")
	_apply_numeric_owner_modifier(owner, modifiers, "player_acceleration_x")
	_apply_numeric_owner_modifier(owner, modifiers, "player_brake_x")
	_apply_numeric_owner_modifier(owner, modifiers, "player_lane_lerp_x")
	_apply_numeric_owner_modifier(owner, modifiers, "player_coast_x")


static func apply_hidden_special_modifiers(owner) -> void:
	owner.special_mode_hidden_modifiers.clear()

	match owner.stage_traffic:
		"traffic-jam":
			owner.special_mode_hidden_modifiers = {
				"jam_density_x": owner.rng.randf_range(0.88, 1.16),
				"jam_lock_x": owner.rng.randf_range(0.90, 1.14),
				"shoulder_clutter_x": owner.rng.randf_range(0.94, 1.10),
			}
			owner.main_spawn_min_delay *= owner.special_mode_hidden_modifiers["jam_density_x"]
			owner.main_spawn_max_delay *= owner.special_mode_hidden_modifiers["jam_density_x"]
			owner.npc_follow_gap *= owner.special_mode_hidden_modifiers["jam_lock_x"]
			owner.shoulder_parked_chance = clampf(
				owner.shoulder_parked_chance * owner.special_mode_hidden_modifiers["shoulder_clutter_x"],
				0.0,
				1.0
			)
		"busy":
			owner.special_mode_hidden_modifiers = {
				"busy_density_x": owner.rng.randf_range(0.82, 1.10),
				"busy_speed_x": owner.rng.randf_range(1.0, 1.18),
				"lane_weave_x": owner.rng.randf_range(0.88, 1.35),
				"close_call_x": owner.rng.randf_range(0.92, 1.20),
			}
			owner.incoming_spawn_min_delay *= owner.special_mode_hidden_modifiers["busy_density_x"]
			owner.incoming_spawn_max_delay *= owner.special_mode_hidden_modifiers["busy_density_x"]
			owner.main_spawn_min_delay *= owner.special_mode_hidden_modifiers["busy_density_x"]
			owner.main_spawn_max_delay *= owner.special_mode_hidden_modifiers["busy_density_x"]
			owner.shoulder_spawn_min_delay *= owner.special_mode_hidden_modifiers["busy_density_x"]
			owner.shoulder_spawn_max_delay *= owner.special_mode_hidden_modifiers["busy_density_x"]
			owner.incoming_vehicle_min_speed *= owner.special_mode_hidden_modifiers["busy_speed_x"]
			owner.incoming_vehicle_max_speed *= owner.special_mode_hidden_modifiers["busy_speed_x"]
			owner.main_vehicle_min_speed *= owner.special_mode_hidden_modifiers["busy_speed_x"]
			owner.main_vehicle_max_speed *= owner.special_mode_hidden_modifiers["busy_speed_x"]
			owner.shoulder_vehicle_min_speed *= owner.special_mode_hidden_modifiers["busy_speed_x"]
			owner.shoulder_vehicle_max_speed *= owner.special_mode_hidden_modifiers["busy_speed_x"]
			owner.npc_lane_change_chance_per_second *= owner.special_mode_hidden_modifiers["lane_weave_x"]
			owner.npc_collision_lookahead *= owner.special_mode_hidden_modifiers["close_call_x"]
		"speeders":
			owner.special_mode_hidden_modifiers = {
				"speeder_rate_x": owner.rng.randf_range(0.84, 1.12),
				"speeder_speed_x": owner.rng.randf_range(0.92, 1.14),
				"speeder_hunt_x": owner.rng.randf_range(0.88, 1.22),
			}
			owner.speeder_spawn_min_delay *= owner.special_mode_hidden_modifiers["speeder_rate_x"]
			owner.speeder_spawn_max_delay *= owner.special_mode_hidden_modifiers["speeder_rate_x"]
			owner.speeder_vehicle_min_speed *= owner.special_mode_hidden_modifiers["speeder_speed_x"]
			owner.speeder_vehicle_max_speed *= owner.special_mode_hidden_modifiers["speeder_speed_x"]
			owner.speeder_avoid_lookahead *= owner.special_mode_hidden_modifiers["speeder_hunt_x"]
			owner.main_spawn_min_delay *= owner.rng.randf_range(0.92, 1.10)
			owner.main_spawn_max_delay *= owner.rng.randf_range(0.92, 1.10)


static func _apply_numeric_owner_modifier(owner, modifiers: Dictionary, property_name: String) -> void:
	if not _owner_has_property(owner, property_name):
		return

	var resolved_value := float(owner.get(property_name))
	if modifiers.has(property_name):
		resolved_value = float(modifiers[property_name])
	if modifiers.has("%s_multiplier" % property_name):
		resolved_value *= float(modifiers["%s_multiplier" % property_name])
	if modifiers.has("%s_delta" % property_name):
		resolved_value += float(modifiers["%s_delta" % property_name])
	if modifiers.has("%s_min" % property_name):
		resolved_value = maxf(resolved_value, float(modifiers["%s_min" % property_name]))

	var cap_key := "%s_cap" % property_name
	if modifiers.has(cap_key):
		resolved_value = minf(resolved_value, float(modifiers[cap_key]))
	elif property_name == "player_max_speed" and modifiers.has("player_max_speed_limit"):
		resolved_value = minf(resolved_value, float(modifiers["player_max_speed_limit"]))

	owner.set(property_name, resolved_value)


static func _owner_has_property(owner, property_name: String) -> bool:
	for property_data in owner.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			return true
	return false
