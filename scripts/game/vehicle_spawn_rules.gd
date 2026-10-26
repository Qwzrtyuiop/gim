extends RefCounted

# Shared spawn adjustments used by traffic scheduling, vehicle creation, and AI.
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const StageProfiles := preload("res://scripts/game/stage_profiles.gd")


static func next_vehicle_speed_change_delay(owner) -> float:
	return owner.rng.randf_range(
		minf(owner.vehicle_speed_change_min_delay, owner.vehicle_speed_change_max_delay),
		maxf(owner.vehicle_speed_change_min_delay, owner.vehicle_speed_change_max_delay)
	)


static func vehicle_spawn_x(owner, size: Vector2, spawn_side: String, lane_index := -1) -> float:
	if owner.stage_traffic == "busy" and lane_index != 2:
		return BusyTrafficBehavior.spawn_x(size, spawn_side, owner.rng, owner.player_speed, owner.player_max_speed)

	return size.x + owner.rng.randf_range(owner.SPAWN_MIN_OFFSET, owner.SPAWN_MAX_OFFSET)


static func player_speed_ratio(owner) -> float:
	return clampf(owner.player_speed / maxf(1.0, owner.player_max_speed), 0.0, 1.0)


static func vehicle_speed_range_for_spawn_side(owner, min_speed: float, max_speed: float, spawn_side: String, lane_index := -1) -> Vector2:
	if owner.stage_traffic == "busy" and lane_index != 2:
		return BusyTrafficBehavior.speed_range_for_spawn_side(min_speed, max_speed, spawn_side, owner.player_speed)
	return Vector2(min_speed, max_speed)


static func shoulder_speed_range(owner) -> Vector2:
	if owner.stage_traffic == "busy":
		return Vector2(StageProfiles.DEFAULT_STAGE_PROFILE.shoulder_vehicle_min_speed, StageProfiles.DEFAULT_STAGE_PROFILE.main_vehicle_max_speed)
	return Vector2(owner.shoulder_vehicle_min_speed, maxf(owner.main_vehicle_min_speed, owner.main_vehicle_max_speed))


static func is_post_day_seven_traffic_ramp(owner) -> bool:
	return owner.use_player_state_stage_sequence and PlayerState.get_current_day() > 7


static func get_post_day_busy_car_chance(owner, lane_index: int) -> float:
	match lane_index:
		1:
			return owner.POST_DAY_SEVEN_BUSY_CAR_CHANCE_MAIN
		2:
			return owner.POST_DAY_SEVEN_BUSY_CAR_CHANCE_SHOULDER
	return 0.0
