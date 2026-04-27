extends RefCounted

const AchievementService := preload("res://scripts/achievement_service.gd")


static func distance_gas_cost(player_state, distance_units: float) -> float:
	return maxf(0.0, distance_units) / 1000.0 * player_state.GAS_DRAIN_PERCENT_PER_1000_UNITS * player_state.get_distance_gas_consumption_multiplier()


static func estimate_stage_gas_usage(player_state, stage_type: String) -> float:
	var parts: Dictionary = player_state._parse_stage_type(stage_type)
	var difficulty_key: String = str(parts.get("difficulty", "short"))
	return distance_gas_cost(player_state, player_state.get_stage_distance_average(difficulty_key))


static func distance_gas_consumption_multiplier(player_state) -> float:
	return maxf(0.45, 1.0 - player_state.get_fuel_efficiency_level() * player_state.FUEL_EFFICIENCY_GAS_REDUCTION_PER_LEVEL)


static func boost_gas_consumption_multiplier(player_state) -> float:
	return maxf(0.60, 1.0 - player_state.get_fuel_efficiency_level() * player_state.FUEL_EFFICIENCY_BOOST_REDUCTION_PER_LEVEL)


static func add_gas(player_state, amount: float) -> void:
	player_state.gas += amount


static func spend_gas(player_state, amount: float, save_immediately: bool = true) -> bool:
	if amount < 0.0 or player_state.gas + 0.001 < amount:
		return false

	set_gas_with_save_mode(player_state, player_state.gas - amount, save_immediately)
	return true


static func drain_gas(player_state, amount: float, save_immediately: bool = true) -> float:
	var consumed_amount: float = minf(maxf(0.0, amount), player_state.gas)
	if consumed_amount <= 0.0:
		return 0.0

	set_gas_with_save_mode(player_state, player_state.gas - consumed_amount, save_immediately)
	return consumed_amount


static func set_gas_with_save_mode(player_state, value: float, save_immediately: bool) -> void:
	if save_immediately:
		player_state.gas = value
		return

	var was_suppressing_auto_save: bool = player_state._suppress_auto_save
	player_state._suppress_auto_save = true
	player_state.gas = value
	player_state._suppress_auto_save = was_suppressing_auto_save
	player_state._mark_deferred_save()


static func gas_text(player_state) -> String:
	return "%.1f%%" % player_state.gas


static func gas_capacity_text(player_state) -> String:
	return "%.1f%%" % player_state.max_gas


static func stage_start_error(player_state, _stage_descriptor: String = "", projected_energy: int = -1) -> String:
	if player_state.pending_stage_energy_cost:
		return ""

	var effective_energy: int = player_state.energy if projected_energy < 0 else int(projected_energy)
	if effective_energy <= 0:
		return "Not enough energy to start this trip."

	if player_state.gas <= 0.0:
		return "Not enough gas for this trip."

	return ""


static func stage_start_error_after_transition(player_state, stage_descriptor: String = "", transition_mode: String = "") -> String:
	if player_state.pending_stage_energy_cost:
		return ""

	var projected_energy: int = player_state.energy
	var transition_bonus: int = player_state.get_transition_energy_bonus(transition_mode)
	if transition_bonus > 0:
		projected_energy = mini(player_state.max_energy, player_state.energy + transition_bonus)
	return stage_start_error(player_state, stage_descriptor, projected_energy)


static func gas_ratio(player_state) -> float:
	return clampf(player_state.gas / maxf(1.0, player_state.max_gas), 0.0, 1.0)


static func is_low_gas(player_state) -> bool:
	return player_state.gas <= player_state.LOW_GAS_PERCENT_THRESHOLD


static func boost_gas_is_available(player_state) -> bool:
	return player_state.gas > 0.05


static func energy_vehicle_modifiers(player_state) -> Dictionary:
	var high_energy_level: int = maxi(0, player_state.energy - 7)
	if high_energy_level > 0:
		return {
			"player_acceleration_x": 1.0 + high_energy_level * 0.05,
			"player_max_speed": 1.0 + high_energy_level * 0.035,
			"player_brake_x": 1.0 + high_energy_level * 0.04,
			"player_lane_lerp_x": 1.0 + high_energy_level * 0.04,
			"player_coast_x": 1.0,
			"player_wiggle_intensity_x": 0.92,
		}

	var fatigue_level: int = maxi(0, 6 - player_state.energy)
	var fatigue_ratio: float = float(fatigue_level) / 6.0
	return {
		"player_acceleration_x": 1.0 - fatigue_ratio * 0.45,
		"player_max_speed": 1.0 - fatigue_ratio * 0.30,
		"player_brake_x": 1.0 - fatigue_ratio * 0.35,
		"player_lane_lerp_x": 1.0 - fatigue_ratio * 0.40,
		"player_coast_x": 1.0 + fatigue_ratio * 0.35,
		"player_wiggle_intensity_x": 1.0 + fatigue_ratio * 0.45,
	}


static func apply_night_rest_bonus(player_state) -> int:
	var applied_bonus: int = mini(player_state.NIGHT_SLEEP_ENERGY_BONUS, player_state.max_energy - player_state.energy)
	player_state.record_rest()
	if applied_bonus > 0:
		add_energy(player_state, applied_bonus)
	return applied_bonus


static func prepare_stage_start(player_state, stage_descriptor: String = "") -> bool:
	if player_state.pending_stage_energy_cost:
		return true

	if not stage_start_error(player_state, stage_descriptor).is_empty():
		return false

	spend_energy(player_state, 1)
	player_state.current_trip_low_energy = player_state.energy <= AchievementService.LOW_ENERGY_THRESHOLD
	player_state.current_trip_low_gas = is_low_gas(player_state)
	player_state.pending_stage_energy_cost = true
	player_state.save_progress()
	return true


static func prepare_stage_start_after_transition(player_state, stage_descriptor: String = "", transition_mode: String = "") -> bool:
	if player_state.pending_stage_energy_cost:
		return true

	if not stage_start_error_after_transition(player_state, stage_descriptor, transition_mode).is_empty():
		return false

	apply_transition_energy_bonus(player_state, transition_mode)
	return prepare_stage_start(player_state, stage_descriptor)


static func confirm_stage_started(player_state) -> void:
	player_state.pending_stage_energy_cost = false
	player_state.save_progress()


static func apply_transition_energy_bonus(player_state, transition_mode: String = "") -> int:
	var safe_transition_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	var applied_bonus: int = mini(player_state.get_transition_energy_bonus(safe_transition_mode), player_state.max_energy - player_state.energy)
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NIGHT or safe_transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY or safe_transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		player_state.record_rest(1, player_state.get_current_time_of_day())
	if applied_bonus > 0:
		add_energy(player_state, applied_bonus)
	return applied_bonus


static func add_money(player_state, amount: int) -> void:
	player_state.money += amount


static func spend_money(player_state, amount: int) -> bool:
	if amount < 0 or player_state.money < amount:
		return false

	player_state.money -= amount
	return true


static func add_energy(player_state, amount: int) -> void:
	player_state.energy += amount


static func add_max_energy(player_state, amount: int) -> void:
	var safe_amount: int = int(amount)
	if safe_amount == 0:
		return
	player_state.max_energy = maxi(1, player_state.max_energy + safe_amount)
	player_state.energy = mini(player_state.energy, player_state.max_energy)
	player_state.save_progress()


static func spend_energy(player_state, amount: int) -> bool:
	if amount < 0 or player_state.energy < amount:
		return false

	player_state.energy -= amount
	return true


static func add_karma(player_state, amount: int) -> void:
	player_state.karma += amount


static func reset_resource_state(player_state) -> void:
	player_state.money = 0
	player_state.max_energy = player_state.DEFAULT_MAX_ENERGY
	player_state.energy = player_state.DEFAULT_STARTING_ENERGY
	player_state.max_gas = player_state.DEFAULT_MAX_GAS_PERCENT
	player_state.gas = player_state.DEFAULT_STARTING_GAS_PERCENT
	player_state.karma = 0
