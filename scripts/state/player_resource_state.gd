extends RefCounted

const SpecialStages := preload("res://scripts/config/special_stages.gd")

const GameTuning := preload("res://scripts/config/game_tuning.gd")

const AchievementService := preload("res://scripts/achievement_service.gd")
const StressShield := preload("res://scripts/state/player_stress_shield_state.gd")
const CHARACTER_RELIEF_EVENT := "daily_character_stress_relief"
const CHARACTER_RELIEF_LOCATIONS := ["hospital", "bar", "park"]


static func set_story_resource(player_state, resource: String, value) -> bool:
	# Narrative controls use a fixed list rather than arbitrary state properties.
	match resource:
		"money":
			player_state.money = int(value)
		"stress":
			player_state.stress = int(value)
		"hull":
			player_state.hull = int(value)
		"energy":
			player_state.energy = int(value)
		"gas":
			player_state.gas = float(value)
		"karma":
			player_state.karma = int(value)
		_:
			return false
	return true


static func distance_gas_cost(player_state, distance_units: float) -> float:
	return maxf(0.0, distance_units) / 1000.0 * player_state.GAS_DRAIN_PERCENT_PER_1000_UNITS * player_state.get_distance_gas_consumption_multiplier()


static func estimate_stage_gas_usage(player_state, stage_type: String) -> float:
	var parts: Dictionary = player_state._parse_stage_type(stage_type)
	var difficulty_key: String = str(parts.get("difficulty", "short"))
	return distance_gas_cost(player_state, player_state.get_stage_distance_average(difficulty_key))


static func distance_gas_consumption_multiplier(player_state) -> float:
	return maxf(GameTuning.MIN_DISTANCE_FUEL_MULTIPLIER, 1.0 - player_state.get_fuel_efficiency_level() * player_state.FUEL_EFFICIENCY_GAS_REDUCTION_PER_LEVEL)


static func boost_gas_consumption_multiplier(player_state) -> float:
	return maxf(GameTuning.MIN_BOOST_FUEL_MULTIPLIER, 1.0 - player_state.get_fuel_efficiency_level() * player_state.FUEL_EFFICIENCY_BOOST_REDUCTION_PER_LEVEL)


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


static func stage_uses_gas(player_state, special_stage_id: String = "") -> bool:
	var stage_id := special_stage_id
	if stage_id.is_empty() and not bool(player_state.active_event_special_stage.get("completed", false)):
		stage_id = str(player_state.active_event_special_stage.get("id", ""))
	# Read current tuning so already-saved Alma deliveries gain this rule too.
	return SpecialStages.uses_gas(stage_id)


static func stage_start_error(player_state, _stage_descriptor: String = "", _projected_energy: int = -1, special_stage_id: String = "") -> String:
	if player_state.hull <= 0:
		return "The tricycle needs repairs before another trip."
	if not player_state.pending_stage_stress_applied and (player_state.energy if _projected_energy < 0 else _projected_energy) < GameTuning.TRIP_ENERGY_COST:
		return "Not enough energy to start this trip."
	if stage_uses_gas(player_state, special_stage_id) and player_state.gas <= 0.0:
		return "Not enough gas for this trip."
	return ""


static func stage_start_error_after_transition(player_state, stage_descriptor: String = "", transition_mode: String = "") -> String:
	var safe_mode: String = player_state.normalize_transition_mode(transition_mode)
	var projected_energy: int = player_state.max_energy if safe_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY else mini(player_state.max_energy, player_state.energy + player_state.get_transition_energy_bonus(safe_mode))
	return stage_start_error(player_state, stage_descriptor, projected_energy)


static func gas_ratio(player_state) -> float:
	return clampf(player_state.gas / maxf(1.0, player_state.max_gas), 0.0, 1.0)


static func is_low_gas(player_state) -> bool:
	return player_state.gas <= player_state.LOW_GAS_PERCENT_THRESHOLD


static func boost_gas_is_available(player_state) -> bool:
	return not stage_uses_gas(player_state) or player_state.gas > GameTuning.MIN_BOOST_GAS_PERCENT


static func stress_vehicle_modifiers(player_state) -> Dictionary:
	var stress_ratio := clampf(float(player_state.stress) / float(maxi(1, player_state.max_stress)), 0.0, 1.0)
	var modifiers: Dictionary = {}
	for key in GameTuning.STRESS_MODIFIER_DELTAS:
		modifiers[key] = 1.0 + stress_ratio * float(GameTuning.STRESS_MODIFIER_DELTAS[key])
	return modifiers


# Compatibility for callers in old authored payloads.
static func energy_vehicle_modifiers(player_state) -> Dictionary:
	return stress_vehicle_modifiers(player_state)


static func apply_night_rest_bonus(player_state) -> int:
	player_state.record_rest()
	player_state.energy = player_state.max_energy
	return relieve_stress(player_state, GameTuning.NIGHT_SLEEP_STRESS_RELIEF)


static func prepare_stage_start(player_state, stage_descriptor: String = "") -> bool:
	if player_state.hull <= 0:
		return false
	if player_state.pending_stage_stress_applied:
		return true
	if not stage_start_error(player_state, stage_descriptor).is_empty():
		return false
	player_state._begin_state_batch()
	spend_energy(player_state, GameTuning.TRIP_ENERGY_COST)
	StressShield.begin_ride(player_state)
	add_stress(player_state, GameTuning.TRIP_STRESS_GAIN)
	player_state.current_trip_had_crash = false
	player_state.current_trip_high_stress = player_state.stress >= AchievementService.HIGH_STRESS_THRESHOLD
	player_state.current_trip_low_gas = is_low_gas(player_state)
	player_state.pending_stage_stress_applied = true
	player_state.save_progress()
	player_state._end_state_batch()
	return true


static func prepare_stage_start_after_transition(player_state, stage_descriptor: String = "", transition_mode: String = "") -> bool:
	if player_state.hull <= 0:
		return false
	if player_state.pending_stage_stress_applied:
		return true
	if not stage_start_error_after_transition(player_state, stage_descriptor, transition_mode).is_empty():
		return false
	player_state._begin_state_batch()
	apply_transition_stress_relief(player_state, transition_mode)
	var prepared: bool = prepare_stage_start(player_state, stage_descriptor)
	player_state._end_state_batch()
	return prepared


static func confirm_stage_started(player_state) -> void:
	player_state.pending_stage_stress_applied = false
	player_state.save_progress()


static func apply_transition_stress_relief(player_state, transition_mode: String = "") -> int:
	var safe_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	if safe_mode in [player_state.TRANSITION_REST_TO_NIGHT, player_state.TRANSITION_REST_TO_NEXT_DAY, player_state.TRANSITION_SLEEP_TO_NEXT_DAY]:
		player_state.record_rest(1, player_state.get_current_time_of_day())
	var relief: int = player_state.get_transition_stress_relief(safe_mode)
	if safe_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		player_state.energy = player_state.max_energy
	else:
		add_energy(player_state, player_state.get_transition_energy_bonus(safe_mode))
	return relieve_stress(player_state, relief)


static func apply_transition_energy_bonus(player_state, transition_mode: String = "") -> int:
	return apply_transition_stress_relief(player_state, transition_mode)


static func add_money(player_state, amount: int) -> void:
	player_state.money += amount


static func spend_money(player_state, amount: int) -> bool:
	if amount < 0 or player_state.money < amount:
		return false

	player_state.money -= amount
	return true


static func add_stress(player_state, amount: int) -> int:
	if amount > 0 and not bool(player_state.active_event_special_stage.get("completed", false)):
		var stage_id := str(player_state.active_event_special_stage.get("id", ""))
		if not SpecialStages.gains_stress(stage_id):
			return 0
	var before: int = player_state.stress
	player_state._begin_state_batch()
	var absorbed := StressShield.absorb(player_state, amount)
	player_state.stress += amount - absorbed
	player_state._end_state_batch()
	return player_state.stress - before


static func relieve_stress(player_state, amount: int) -> int:
	var before: int = player_state.stress
	if amount > 0:
		player_state.stress -= amount
	return before - player_state.stress


static func relieve_character_interaction(player_state, location_id: String, character_id: String) -> int:
	var location := location_id.strip_edges().to_lower()
	if not CHARACTER_RELIEF_LOCATIONS.has(location) or character_id.strip_edges().is_empty() or player_state.stress <= 0:
		return 0
	var stored: Variant = player_state.get_event_value(CHARACTER_RELIEF_EVENT, {})
	var record: Dictionary = stored.duplicate(true) if stored is Dictionary else {}
	var current_day: int = player_state.get_current_day()
	var recorded_day: Variant = record.get(location, 0)
	if recorded_day is int and recorded_day == current_day:
		return 0
	player_state._begin_state_batch()
	var amount := int(GameTuning.CHARACTER_INTERACTION_STRESS_RELIEF_BY_LOCATION.get(location, GameTuning.CHARACTER_INTERACTION_STRESS_RELIEF))
	var relieved := relieve_stress(player_state, amount)
	if relieved > 0:
		record[location] = current_day
		player_state.set_event_value(CHARACTER_RELIEF_EVENT, record)
	player_state._end_state_batch()
	return relieved


static func damage_hull(player_state, amount: int) -> int:
	var before: int = player_state.hull
	if amount > 0:
		player_state._begin_state_batch()
		var protection := 0
		if str(player_state.active_event_special_stage.get("id", "")) == "alma_special_delivery" and not bool(player_state.active_event_special_stage.get("completed", false)):
			protection = mini(amount, maxi(0, int(player_state.active_event_special_stage.get("crash_protection_remaining", 0))))
			player_state.active_event_special_stage["crash_protection_remaining"] = int(player_state.active_event_special_stage.get("crash_protection_remaining", 0)) - protection
			if protection > 0:
				player_state.save_progress()
		player_state.hull -= amount - protection
		player_state._end_state_batch()
	return before - player_state.hull


static func repair_hull(player_state, amount: int) -> int:
	var before: int = player_state.hull
	if amount > 0:
		player_state.hull += amount
	return player_state.hull - before


static func add_energy(player_state, amount: int) -> void:
	var bounded_amount := clampi(amount, -player_state.max_energy, player_state.max_energy)
	player_state.energy += bounded_amount


static func add_max_energy(player_state, amount: int) -> void:
	# Capacity comes from earned achievements rather than repeatable story rewards.
	player_state.max_energy = AchievementService.energy_capacity(player_state.achievements)
	player_state.energy = mini(player_state.energy, player_state.max_energy)


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
	player_state.max_stress = GameTuning.DEFAULT_MAX_STRESS
	player_state.stress = GameTuning.DEFAULT_STARTING_STRESS
	player_state.max_hull = GameTuning.DEFAULT_MAX_HULL
	player_state.hull = GameTuning.DEFAULT_STARTING_HULL
	player_state.max_gas = player_state.DEFAULT_MAX_GAS_PERCENT
	player_state.gas = player_state.DEFAULT_STARTING_GAS_PERCENT
	player_state.karma = 0
