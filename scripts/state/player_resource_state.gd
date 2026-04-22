extends RefCounted
class_name PlayerResourceState


static func stage_start_error(player_state, _stage_descriptor := "", projected_energy := -1) -> String:
	if player_state.pending_stage_energy_cost:
		return ""

	var effective_energy: int = player_state.energy if projected_energy < 0 else int(projected_energy)
	if effective_energy <= 0:
		return "Not enough energy to start this trip."

	if player_state.gas <= 0.0:
		return "Not enough gas for this trip."

	return ""


static func stage_start_error_after_transition(player_state, stage_descriptor := "", transition_mode: String = "") -> String:
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
