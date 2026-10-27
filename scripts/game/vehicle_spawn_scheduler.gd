extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const VehicleTrafficSignals := preload("res://scripts/game/vehicle_traffic_signals.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const VehicleSpawner := preload("res://scripts/game/vehicle_spawner.gd")
const VehicleSpawnRules := preload("res://scripts/game/vehicle_spawn_rules.gd")


static func update_spawns(owner, delta: float) -> void:
	if owner.game_state != "playing":
		VehicleTrafficSignals.clear_oncoming_warning(owner)
		return
	update_top_lane_pressure(owner, delta)
	var progress: float = clampf(owner.distance / maxf(1.0, owner.target_distance), 0.0, 1.0)
	for lane_index in range(3):
		var clock_rate := top_lane_spawn_rate(owner) if lane_index == 0 else 1.0
		owner.spawn_timers[lane_index] -= delta * clock_rate
		if owner.spawn_timers[lane_index] <= 0.0:
			var spawn_side: String = vehicle_spawn_side(owner, lane_index)
			if lane_index == 0 and GameTuning.ONCOMING_WARNING_ENABLED:
				if owner.oncoming_warning_elapsed >= 0.0:
					if not VehicleTrafficSignals.update_oncoming_warning(owner, delta):
						continue
				elif lane_has_spawn_room(owner, lane_index, spawn_side):
					owner.oncoming_warning_elapsed = 0.0
					VehicleTrafficSignals.update_oncoming_warning(owner, 0.0)
					continue
			var spawned := false
			if lane_has_spawn_room(owner, lane_index, spawn_side):
				spawned = VehicleSpawner.spawn_incoming_group(owner) if lane_index == 0 else VehicleSpawner.spawn_traffic(owner, lane_index, spawn_side)
			if spawned:
				owner.spawn_timers[lane_index] = next_spawn_delay(owner, lane_index, progress)
			else:
				owner.spawn_timers[lane_index] = blocked_spawn_retry_delay(owner)


static func update_top_lane_pressure(owner, delta: float) -> void:
	if owner.game_state != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	if owner.is_inside_tree() and owner.get_tree().paused:
		return
	var change := delta / GameTuning.TOP_LANE_PRESSURE_FILL_SECONDS if owner.player_lane == 0 else -delta / GameTuning.TOP_LANE_PRESSURE_DECAY_SECONDS
	owner.top_lane_pressure = clampf(owner.top_lane_pressure + change, 0.0, 1.0)


static func top_lane_spawn_rate(owner) -> float:
	return lerpf(1.0, GameTuning.TOP_LANE_PRESSURE_MAX_SPAWN_RATE, clampf(owner.top_lane_pressure, 0.0, 1.0))


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
	if lane_index == 0 or lane_index == 2:
		return BusyTrafficBehavior.RIGHT_SPAWN_SIDE
	if owner.stage_traffic == "busy":
		return BusyTrafficBehavior.spawn_side(owner.rng, owner.player_speed, owner.player_max_speed)
	return BusyTrafficBehavior.RIGHT_SPAWN_SIDE


static func lane_has_spawn_room(owner, lane_index: int, spawn_side := BusyTrafficBehavior.RIGHT_SPAWN_SIDE) -> bool:
	if owner.stage_traffic == "busy" and lane_index != 2:
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
	return VehicleSpawnRules.next_vehicle_speed_change_delay(owner)


static func vehicle_spawn_x(owner, size: Vector2, spawn_side: String) -> float:
	return VehicleSpawnRules.vehicle_spawn_x(owner, size, spawn_side)


static func player_speed_ratio(owner) -> float:
	return VehicleSpawnRules.player_speed_ratio(owner)


static func vehicle_speed_range_for_spawn_side(owner, min_speed: float, max_speed: float, spawn_side: String) -> Vector2:
	return VehicleSpawnRules.vehicle_speed_range_for_spawn_side(owner, min_speed, max_speed, spawn_side)


static func is_post_day_seven_traffic_ramp(owner) -> bool:
	return VehicleSpawnRules.is_post_day_seven_traffic_ramp(owner)


static func get_post_day_busy_car_chance(owner, lane_index: int) -> float:
	return VehicleSpawnRules.get_post_day_busy_car_chance(owner, lane_index)
