extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")

static func set_last_stage_result(player_state, result: Dictionary) -> void:
	player_state._begin_state_batch()
	player_state.finish_ride_stress_shield()
	player_state.last_stage_result = result.duplicate(true)
	player_state.last_stage_result["paid_out"] = false
	player_state.save_progress()
	player_state._end_state_batch()


static func get_last_stage_result(player_state) -> Dictionary:
	return player_state.last_stage_result.duplicate(true)


static func claim_last_stage_total(player_state) -> int:
	if player_state.last_stage_result.is_empty() or bool(player_state.last_stage_result.get("paid_out", false)):
		return 0
	if not str(player_state.last_stage_result.get("random_ride_event", "")).is_empty() and str(player_state.last_stage_result.get("random_ride_outcome", "")).is_empty():
		return 0

	var total: int = int(player_state.last_stage_result.get("total", 0))
	player_state._begin_state_batch()
	player_state.add_money(total)
	player_state.last_stage_result["paid_out"] = true
	player_state.save_progress()
	player_state._end_state_batch()
	return total

static func normalize_stage_special_type(player_state, stage_special_type: String) -> String:
	var safe_special_type: String = str(stage_special_type).strip_edges().to_lower()
	return safe_special_type if player_state.STAGE_SPECIAL_TYPES.has(safe_special_type) else player_state.STAGE_SPECIAL_TYPE_NONE


static func normalize_special_stage_id(_player_state, special_stage_id: String) -> String:
	return str(special_stage_id).strip_edges().to_lower()


static func set_current_stage_special_type(player_state, stage_special_type: String) -> void:
	player_state.current_stage_special_type = normalize_stage_special_type(player_state, stage_special_type)
	if player_state.current_stage_special_type != player_state.STAGE_SPECIAL_TYPE_SPECIAL:
		player_state.current_special_stage_id = ""
	player_state.save_progress()


static func get_current_stage_special_type(player_state) -> String:
	return normalize_stage_special_type(player_state, player_state.current_stage_special_type)


static func set_current_special_stage_id(player_state, special_stage_id: String) -> void:
	if get_current_stage_special_type(player_state) != player_state.STAGE_SPECIAL_TYPE_SPECIAL:
		player_state.current_special_stage_id = ""
	else:
		player_state.current_special_stage_id = normalize_special_stage_id(player_state, special_stage_id)
	player_state.save_progress()


static func get_current_special_stage_id(player_state) -> String:
	if get_current_stage_special_type(player_state) != player_state.STAGE_SPECIAL_TYPE_SPECIAL:
		return ""
	return normalize_special_stage_id(player_state, player_state.current_special_stage_id)


static func stage_special_display_name(player_state, stage_special_type: String) -> String:
	var safe_special_type: String = normalize_stage_special_type(player_state, stage_special_type)
	if safe_special_type == player_state.STAGE_SPECIAL_TYPE_URGENT:
		return "URGENT"
	if safe_special_type == player_state.STAGE_SPECIAL_TYPE_CAREFUL:
		return "CAREFUL"
	if safe_special_type == player_state.STAGE_SPECIAL_TYPE_SPECIAL:
		return "SPECIAL"
	return ""


static func stage_distance_range(player_state, difficulty: String) -> Vector2:
	var safe_difficulty: String = difficulty if player_state.STAGE_DIFFICULTIES.has(difficulty) else "short"
	return player_state.STAGE_DISTANCE_RANGES.get(safe_difficulty, player_state.STAGE_DISTANCE_RANGES["short"])


static func stage_distance_average(player_state, difficulty: String) -> float:
	var distance_range: Vector2 = stage_distance_range(player_state, difficulty)
	return (distance_range.x + distance_range.y) * 0.5


static func roll_stage_target_distance(player_state, difficulty: String) -> float:
	var distance_range: Vector2 = stage_distance_range(player_state, difficulty)
	return player_state.rng.randf_range(distance_range.x, distance_range.y)


static func random_stage_type_for_time(player_state, day_time: String, selected_difficulty: String = "", forced_traffic: String = "") -> String:
	var difficulty: String = selected_difficulty
	if difficulty == "easy":
		difficulty = "short"
	if not player_state.STAGE_DIFFICULTIES.has(difficulty):
		difficulty = player_state.STAGE_DIFFICULTIES[player_state.rng.randi_range(0, player_state.STAGE_DIFFICULTIES.size() - 1)]
	var traffic_type: String = forced_traffic if player_state.STAGE_TRAFFIC_TYPES.has(forced_traffic) else random_stage_traffic_type(player_state)
	return build_stage_type(player_state, difficulty, day_time, traffic_type)


static func parse_stage_type(player_state, type_name: String) -> Dictionary:
	var parts: PackedStringArray = type_name.split("-")
	if parts.size() < 3:
		return {
			"difficulty": "short",
			"time": "morning",
			"traffic": "chill",
		}

	var traffic_name: String = ""
	for index in range(2, parts.size()):
		if not traffic_name.is_empty():
			traffic_name += "-"
		traffic_name += parts[index]

	if parts[0] == "easy":
		parts[0] = "short"
	if not player_state.STAGE_DIFFICULTIES.has(parts[0]):
		parts[0] = "short"
	if not player_state.STAGE_TIMES.has(parts[1]):
		parts[1] = "morning"
	if not player_state.STAGE_TRAFFIC_TYPES.has(traffic_name):
		traffic_name = "chill"

	return {
		"difficulty": parts[0],
		"time": parts[1],
		"traffic": traffic_name,
	}


static func random_stage_traffic_type(player_state) -> String:
	return str(player_state.STAGE_TRAFFIC_TYPES[player_state.rng.randi_range(0, player_state.STAGE_TRAFFIC_TYPES.size() - 1)])


static func build_stage_type(player_state, difficulty: String, day_time: String, traffic_type: String) -> String:
	var safe_difficulty: String = difficulty
	if safe_difficulty == "easy":
		safe_difficulty = "short"
	if not player_state.STAGE_DIFFICULTIES.has(safe_difficulty):
		safe_difficulty = "short"

	var safe_time: String = day_time if player_state.STAGE_TIMES.has(day_time) else "morning"
	var safe_traffic: String = traffic_type if player_state.STAGE_TRAFFIC_TYPES.has(traffic_type) else "chill"
	return "%s-%s-%s" % [safe_difficulty, safe_time, safe_traffic]


static func stage_earnings_multiplier(player_state, day_time: String, traffic_type: String) -> float:
	var time_multiplier: float = float(player_state.TIME_EARNINGS_MULTIPLIERS.get(day_time, 1.0))
	var traffic_multiplier: float = float(player_state.TRAFFIC_EARNINGS_MULTIPLIERS.get(traffic_type, 1.0))
	return time_multiplier * traffic_multiplier


static func apply_stage_earnings_modifiers(player_state, fare: int, bonus: int, day_time: String, traffic_type: String) -> Dictionary:
	var multiplier: float = stage_earnings_multiplier(player_state, day_time, traffic_type)
	return {
		"fare": roundi(fare * multiplier * fare_buff_multiplier(player_state)),
		"bonus": roundi(bonus * multiplier),
		"multiplier": multiplier,
	}


static func fare_buff_multiplier(player_state) -> float:
	return 1.0 + GameTuning.MALASAKIT_FARE_BONUS if player_state.has_achievement("malasakit") else 1.0


static func estimate_stage_earnings(player_state, stage_type: String, character_id: String = "") -> int:
	var parts: Dictionary = parse_stage_type(player_state, stage_type)
	var difficulty_key: String = str(parts.get("difficulty", "short"))
	var difficulty_profile: Dictionary = player_state.ESTIMATED_STAGE_PROFILES[difficulty_key].duplicate(true) if player_state.ESTIMATED_STAGE_PROFILES.has(difficulty_key) else player_state.ESTIMATED_STAGE_PROFILES["short"].duplicate(true)
	var modifier_context: Dictionary = {
		"stage_type": stage_type,
		"difficulty": difficulty_key,
		"time_of_day": str(parts.get("time", "morning")),
		"traffic": str(parts.get("traffic", "chill")),
	}
	var effective_character_id: String = str(character_id).strip_edges().to_lower()
	if effective_character_id.is_empty():
		effective_character_id = player_state.current_mock_character_id
	_apply_estimated_stage_profile_modifiers(
		difficulty_profile,
		player_state.get_character_stage_modifiers(effective_character_id, modifier_context)
	)
	var estimated_distance: float = stage_distance_average(player_state, difficulty_key)
	var base_fare: float = estimated_distance * float(difficulty_profile["fare_php_per_meter"])
	var estimated_bonus_seconds: float = float(difficulty_profile["time_limit"]) * player_state.ESTIMATED_BONUS_TIME_RATIO
	var base_bonus: float = estimated_bonus_seconds * float(difficulty_profile["time_bonus_php_per_second"])
	var multiplier: float = stage_earnings_multiplier(player_state, str(parts["time"]), str(parts["traffic"]))
	var fare_total: float = base_fare * multiplier * fare_buff_multiplier(player_state)
	var bonus_total: float = base_bonus * multiplier
	return roundi(fare_total + bonus_total)


static func _apply_estimated_stage_profile_modifiers(profile: Dictionary, modifiers: Dictionary) -> void:
	if profile.is_empty() or modifiers.is_empty():
		return
	_apply_numeric_profile_modifier(profile, modifiers, "fare_php_per_meter")
	_apply_numeric_profile_modifier(profile, modifiers, "time_limit")
	_apply_numeric_profile_modifier(profile, modifiers, "time_bonus_php_per_second")


static func _apply_numeric_profile_modifier(profile: Dictionary, modifiers: Dictionary, key: String) -> void:
	if not profile.has(key):
		return

	var resolved_value: float = float(profile.get(key, 0.0))
	if modifiers.has(key):
		resolved_value = float(modifiers[key])
	if modifiers.has("%s_multiplier" % key):
		resolved_value *= float(modifiers["%s_multiplier" % key])
	if modifiers.has("%s_delta" % key):
		resolved_value += float(modifiers["%s_delta" % key])
	if modifiers.has("%s_min" % key):
		resolved_value = maxf(resolved_value, float(modifiers["%s_min" % key]))
	if modifiers.has("%s_cap" % key):
		resolved_value = minf(resolved_value, float(modifiers["%s_cap" % key]))
	profile[key] = resolved_value
