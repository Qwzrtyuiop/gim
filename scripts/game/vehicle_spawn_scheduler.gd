extends RefCounted

const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const VehicleSpawner := preload("res://scripts/game/vehicle_spawner.gd")


static func update_spawns(owner, delta: float) -> void:
	var progress: float = clampf(owner.distance / maxf(1.0, owner.target_distance), 0.0, 1.0)
	for lane_index in range(3):
		owner.spawn_timers[lane_index] -= delta
		if owner.spawn_timers[lane_index] <= 0.0:
			var spawn_side: String = vehicle_spawn_side(owner, lane_index)
			if lane_has_spawn_room(owner, lane_index, spawn_side) and VehicleSpawner.spawn_traffic(owner, lane_index, spawn_side):
				owner.spawn_timers[lane_index] = next_spawn_delay(owner, lane_index, progress)
			else:
				owner.spawn_timers[lane_index] = blocked_spawn_retry_delay(owner)


static func next_spawn_delay(owner, lane_index: int, progress: float) -> float:
	var delay_range: Vector2 = spawn_delay_range_for_lane(owner, lane_index)
	var speed_spawn_x: float = lerpf(1.0, owner.FAST_SPEED_SPAWN_DELAY_X, player_speed_ratio(owner))
	var min_delay: float = maxf(0.05, (delay_range.x - progress * owner.spawn_delay_progress_reduction) * speed_spawn_x)
	var max_delay: float = maxf(min_delay, (delay_range.y - progress * owner.spawn_delay_progress_reduction) * speed_spawn_x)
	return owner.rng.randf_range(min_delay, max_delay)


static func blocked_spawn_retry_delay(owner) -> float:
	var speed_spawn_x: float = lerpf(1.0, owner.FAST_SPEED_SPAWN_DELAY_X, player_speed_ratio(owner))
	return owner.rng.randf_range(owner.BLOCKED_SPAWN_RETRY_MIN_DELAY, owner.BLOCKED_SPAWN_RETRY_MAX_DELAY) * speed_spawn_x


static func spawn_delay_range_for_lane(owner, lane_index: int) -> Vector2:
	var delay_range := Vector2(1.0, 2.0)
	match lane_index:
		0:
			delay_range = Vector2(owner.incoming_spawn_min_delay, owner.incoming_spawn_max_delay)
		1:
			delay_range = Vector2(owner.main_spawn_min_delay, owner.main_spawn_max_delay)
		2:
			delay_range = Vector2(owner.shoulder_spawn_min_delay, owner.shoulder_spawn_max_delay)

	if is_post_day_seven_traffic_ramp(owner):
		delay_range *= owner.POST_DAY_SEVEN_SPAWN_DELAY_X

	return delay_range


static func vehicle_spawn_side(owner, lane_index: int) -> String:
	if lane_index == 0:
		return BusyTrafficBehavior.RIGHT_SPAWN_SIDE
	if owner.stage_traffic == "busy":
		return BusyTrafficBehavior.spawn_side(owner.rng, owner.player_speed, owner.player_max_speed)
	return BusyTrafficBehavior.RIGHT_SPAWN_SIDE


static func lane_has_spawn_room(owner, lane_index: int, spawn_side := BusyTrafficBehavior.RIGHT_SPAWN_SIDE) -> bool:
	if owner.stage_traffic == "busy":
		return BusyTrafficBehavior.lane_has_spawn_room(
			owner.active_entities,
			lane_index,
			owner.get_viewport_rect().size,
			spawn_side,
			owner.player_speed,
			owner.player_max_speed
		)

	var right_edge: float = owner.get_viewport_rect().size.x - owner.SPAWN_ROOM_EDGE_BUFFER + owner.FAST_SPAWN_ROOM_EXTRA * player_speed_ratio(owner)
	for entity in owner.active_entities:
		if not entity.has("sprite") or entity["sprite"] == null or not is_instance_valid(entity["sprite"]):
			continue
		if entity["lane"] == lane_index and entity["sprite"].position.x > right_edge:
			return false
	return true


static func next_vehicle_speed_change_delay(owner) -> float:
	return owner.rng.randf_range(
		minf(owner.vehicle_speed_change_min_delay, owner.vehicle_speed_change_max_delay),
		maxf(owner.vehicle_speed_change_min_delay, owner.vehicle_speed_change_max_delay)
	)


static func vehicle_spawn_x(owner, size: Vector2, spawn_side: String) -> float:
	if owner.stage_traffic == "busy":
		return BusyTrafficBehavior.spawn_x(size, spawn_side, owner.rng, owner.player_speed, owner.player_max_speed)

	return size.x + owner.rng.randf_range(owner.SPAWN_MIN_OFFSET, owner.SPAWN_MAX_OFFSET)


static func player_speed_ratio(owner) -> float:
	return clampf(owner.player_speed / maxf(1.0, owner.player_max_speed), 0.0, 1.0)


static func vehicle_speed_range_for_spawn_side(owner, min_speed: float, max_speed: float, spawn_side: String) -> Vector2:
	if owner.stage_traffic == "busy":
		return BusyTrafficBehavior.speed_range_for_spawn_side(min_speed, max_speed, spawn_side, owner.player_speed)
	return Vector2(min_speed, max_speed)


static func is_post_day_seven_traffic_ramp(owner) -> bool:
	return owner.use_player_state_stage_sequence and PlayerState.get_current_day() > 7


static func get_post_day_busy_car_chance(owner, lane_index: int) -> float:
	match lane_index:
		1:
			return owner.POST_DAY_SEVEN_BUSY_CAR_CHANCE_MAIN
		2:
			return owner.POST_DAY_SEVEN_BUSY_CAR_CHANCE_SHOULDER
	return 0.0
