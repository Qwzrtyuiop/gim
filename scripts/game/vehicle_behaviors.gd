extends RefCounted


static func speeder_overtake_lane_order(lane_index: int) -> Array[int]:
	match lane_index:
		0:
			return [1, 2]
		1:
			return [0, 2]
		2:
			return [0, 1]
	return [0, 1, 2]


static func overtake_lane_order(lane_index: int) -> Array[int]:
	match lane_index:
		1:
			return [2, 0]
		2:
			return [1, 0]
	return [1, 2]


static func speeder_lane_change_safe_gap(target_lane: int, safe_gap: float, avoid_lookahead: float) -> float:
	if target_lane == 0:
		return maxf(safe_gap, avoid_lookahead)
	return safe_gap


static func is_lane_safe(
	moving_entity: Dictionary,
	target_lane: int,
	safe_gap: float,
	active_entities: Array,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> bool:
	var moving_rect: Rect2 = collision_rect_provider.call(moving_entity["sprite"], vehicle_hitbox_inset)
	for entity in active_entities:
		if entity == moving_entity:
			continue
		if int(entity["lane"]) != target_lane:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		if absf(entity_rect.get_center().x - moving_rect.get_center().x) < safe_gap:
			return false
	return true


static func speeder_needs_lane_change(
	speeder: Dictionary,
	lane_index: int,
	active_entities: Array,
	speeder_fallback_speed: float,
	speeder_safe_gap: float,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> bool:
	var speeder_rect: Rect2 = collision_rect_provider.call(speeder["sprite"], vehicle_hitbox_inset)
	var speeder_speed := float(speeder.get("world_speed", speeder_fallback_speed))
	for entity in active_entities:
		if entity == speeder or entity.get("kind", "traffic") == "speeder":
			continue
		if int(entity["lane"]) != lane_index:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		var entity_speed := float(entity.get("world_speed", 0.0))
		var gap := entity_rect.position.x - (speeder_rect.position.x + speeder_rect.size.x)
		var closing_speed := maxf(0.0, speeder_speed - entity_speed)
		var predicted_close_distance := closing_speed * 0.42
		var emergency_gap := maxf(speeder_safe_gap * 0.82, predicted_close_distance)
		if gap > 0.0 and gap <= emergency_gap:
			return true
	return false


static func vehicle_needs_lane_change(
	vehicle: Dictionary,
	lane_index: int,
	active_entities: Array,
	collision_lookahead: float,
	follow_gap: float,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> bool:
	var vehicle_rect: Rect2 = collision_rect_provider.call(vehicle["sprite"], vehicle_hitbox_inset)
	var vehicle_speed := float(vehicle.get("world_speed", 0.0))
	for entity in active_entities:
		if entity == vehicle:
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		var entity_speed := float(entity.get("world_speed", 0.0))
		var gap := entity_rect.position.x - (vehicle_rect.position.x + vehicle_rect.size.x)
		var closing_speed := maxf(0.0, vehicle_speed - entity_speed)
		var predicted_close_distance := closing_speed * collision_lookahead
		if gap > 0.0 and (gap <= follow_gap or gap <= predicted_close_distance):
			return true
	return false


static func front_vehicle_speed(
	vehicle: Dictionary,
	lane_index: int,
	active_entities: Array,
	follow_gap: float,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> float:
	var vehicle_rect: Rect2 = collision_rect_provider.call(vehicle["sprite"], vehicle_hitbox_inset)
	var nearest_gap := INF
	var front_speed := -1.0
	for entity in active_entities:
		if entity == vehicle:
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		var gap := entity_rect.position.x - (vehicle_rect.position.x + vehicle_rect.size.x)
		if gap > 0.0 and gap < nearest_gap and gap <= follow_gap:
			nearest_gap = gap
			front_speed = float(entity.get("world_speed", 0.0))
	return front_speed


static func update_npc_following(
	active_entities: Array,
	npc_follow_gap: float,
	npc_collision_lookahead: float,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> void:
	for entity in active_entities:
		if not entity.has("desired_world_speed"):
			entity["desired_world_speed"] = entity["world_speed"]

	for lane_index in [1, 2]:
		var lane_entities := []
		for entity in active_entities:
			if entity.get("kind", "traffic") == "traffic" and entity["lane"] == lane_index:
				lane_entities.append(entity)

		lane_entities.sort_custom(_sort_entities_front_to_back)

		for index in range(1, lane_entities.size()):
			var front_entity = lane_entities[index - 1]
			var rear_entity = lane_entities[index]
			var rear_desired_speed: float = rear_entity["desired_world_speed"]
			var front_speed: float = front_entity["world_speed"]
			var closing_speed := rear_desired_speed - front_speed
			if closing_speed <= 0.0:
				continue

			var front_rect: Rect2 = collision_rect_provider.call(front_entity["sprite"], vehicle_hitbox_inset)
			var rear_rect: Rect2 = collision_rect_provider.call(rear_entity["sprite"], vehicle_hitbox_inset)
			var gap := front_rect.position.x - (rear_rect.position.x + rear_rect.size.x)
			var predicted_closing_distance := closing_speed * npc_collision_lookahead

			if gap <= npc_follow_gap or gap <= predicted_closing_distance:
				rear_entity["world_speed"] = front_speed


static func update_speed_targets(
	active_entities: Array,
	delta: float,
	rng: RandomNumberGenerator,
	speed_change_min_delay: float,
	speed_change_max_delay: float,
	speed_acceleration: float
) -> void:
	var min_delay := minf(speed_change_min_delay, speed_change_max_delay)
	var max_delay := maxf(speed_change_min_delay, speed_change_max_delay)
	for entity in active_entities:
		if bool(entity.get("is_parked", false)):
			entity["world_speed"] = 0.0
			entity["desired_world_speed"] = 0.0
			continue

		var min_speed := float(entity.get("min_world_speed", entity.get("world_speed", 0.0)))
		var max_speed := float(entity.get("max_world_speed", maxf(min_speed, float(entity.get("world_speed", 0.0)))))
		if max_speed < min_speed:
			var swap_speed := min_speed
			min_speed = max_speed
			max_speed = swap_speed

		var timer := float(entity.get("speed_change_timer", 0.0)) - delta
		if timer <= 0.0:
			entity["desired_world_speed"] = rng.randf_range(min_speed, max_speed)
			timer = rng.randf_range(min_delay, max_delay)
		entity["speed_change_timer"] = timer

		var desired_speed := clampf(float(entity.get("desired_world_speed", min_speed)), min_speed, max_speed)
		entity["desired_world_speed"] = desired_speed
		entity["world_speed"] = move_toward(
			float(entity.get("world_speed", desired_speed)),
			desired_speed,
			speed_acceleration * delta
		)


static func update_overtake_speed_boosts(active_entities: Array, delta: float) -> void:
	for entity in active_entities:
		var boost_timer := float(entity.get("overtake_speed_timer", 0.0))
		if boost_timer <= 0.0:
			continue

		boost_timer = maxf(0.0, boost_timer - delta)
		entity["overtake_speed_timer"] = boost_timer
		var boosted_speed := float(entity.get("overtake_target_speed", entity.get("world_speed", 0.0)))
		entity["desired_world_speed"] = maxf(float(entity.get("desired_world_speed", 0.0)), boosted_speed)
		entity["world_speed"] = maxf(float(entity.get("world_speed", 0.0)), boosted_speed)


static func boost_for_overtake(entity: Dictionary, speed_boost: float, boost_seconds: float) -> void:
	var current_speed := float(entity.get("world_speed", 0.0))
	var max_speed := float(entity.get("max_world_speed", current_speed))
	var boosted_speed := maxf(current_speed + speed_boost, max_speed + speed_boost * 0.5)
	entity["overtake_target_speed"] = boosted_speed
	entity["overtake_speed_timer"] = boost_seconds
	entity["desired_world_speed"] = boosted_speed
	entity["world_speed"] = maxf(current_speed, boosted_speed)


static func screen_velocity(lane_index: int, kind: String, world_speed: float, player_speed: float) -> float:
	return screen_velocity_for_spawn_side(lane_index, kind, "", world_speed, player_speed)


static func screen_velocity_for_spawn_side(lane_index: int, kind: String, spawn_side: String, world_speed: float, player_speed: float) -> float:
	if spawn_side == "left":
		return world_speed - player_speed
	if lane_index == 0 and kind != "speeder":
		return -(player_speed + world_speed)
	return world_speed - player_speed


static func _sort_entities_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x > b["sprite"].position.x
