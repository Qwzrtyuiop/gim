extends RefCounted


static func speeder_overtake_lane_order(lane_index: int) -> Array[int]:
	match lane_index:
		0:
			return []
		1:
			return [2]
		2:
			return [1]
	return [1, 2]


static func overtake_lane_order(lane_index: int) -> Array[int]:
	match lane_index:
		1:
			return [2]
		2:
			return [1]
	return []


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
	if not entity_sprite_is_valid(moving_entity):
		return false
	var moving_rect: Rect2 = collision_rect_provider.call(moving_entity["sprite"], vehicle_hitbox_inset)
	for entity in active_entities:
		if not entity_sprite_is_valid(entity):
			continue
		if same_entity_sprite(entity, moving_entity):
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
	if not entity_sprite_is_valid(speeder):
		return false
	var speeder_rect: Rect2 = collision_rect_provider.call(speeder["sprite"], vehicle_hitbox_inset)
	var speeder_speed := float(speeder.get("world_speed", speeder_fallback_speed))
	var speeder_moves_with_player := entity_moves_with_player(speeder, lane_index)
	for entity in active_entities:
		if not entity_sprite_is_valid(entity):
			continue
		if same_entity_sprite(entity, speeder) or entity.get("kind", "traffic") == "speeder":
			continue
		if int(entity["lane"]) != lane_index:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		if not rect_is_ahead(speeder_rect, entity_rect, speeder_moves_with_player):
			continue

		var entity_speed := float(entity.get("world_speed", 0.0))
		var gap := front_gap(speeder_rect, entity_rect, speeder_moves_with_player)
		var closing_speed := closing_speed_between(speeder, entity, lane_index, speeder_speed, entity_speed)
		var predicted_close_distance := closing_speed * 0.42
		var emergency_gap := maxf(speeder_safe_gap * 0.82, predicted_close_distance)
		if gap <= emergency_gap:
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
	if not entity_sprite_is_valid(vehicle):
		return false
	var vehicle_rect: Rect2 = collision_rect_provider.call(vehicle["sprite"], vehicle_hitbox_inset)
	var vehicle_speed := float(vehicle.get("world_speed", 0.0))
	var vehicle_moves_with_player := entity_moves_with_player(vehicle, lane_index)
	for entity in active_entities:
		if not entity_sprite_is_valid(entity):
			continue
		if same_entity_sprite(entity, vehicle):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		if not rect_is_ahead(vehicle_rect, entity_rect, vehicle_moves_with_player):
			continue

		var entity_speed := float(entity.get("world_speed", 0.0))
		var gap := front_gap(vehicle_rect, entity_rect, vehicle_moves_with_player)
		var closing_speed := closing_speed_between(vehicle, entity, lane_index, vehicle_speed, entity_speed)
		var predicted_close_distance := closing_speed * collision_lookahead
		if gap <= follow_gap or gap <= predicted_close_distance:
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
	if not entity_sprite_is_valid(vehicle):
		return -1.0
	var vehicle_rect: Rect2 = collision_rect_provider.call(vehicle["sprite"], vehicle_hitbox_inset)
	var vehicle_moves_with_player := entity_moves_with_player(vehicle, lane_index)
	var nearest_gap := INF
	var front_speed := -1.0
	for entity in active_entities:
		if not entity_sprite_is_valid(entity):
			continue
		if same_entity_sprite(entity, vehicle):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		if not rect_is_ahead(vehicle_rect, entity_rect, vehicle_moves_with_player):
			continue

		var gap := front_gap(vehicle_rect, entity_rect, vehicle_moves_with_player)
		if gap < nearest_gap and gap <= follow_gap:
			nearest_gap = gap
			front_speed = comparable_front_speed(vehicle, entity, lane_index)
	return front_speed


static func front_vehicle_collision_speed(
	vehicle: Dictionary,
	lane_index: int,
	active_entities: Array,
	follow_gap: float,
	collision_lookahead: float,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> float:
	if not entity_sprite_is_valid(vehicle):
		return -1.0
	var vehicle_rect: Rect2 = collision_rect_provider.call(vehicle["sprite"], vehicle_hitbox_inset)
	var vehicle_speed := float(vehicle.get("world_speed", 0.0))
	var vehicle_moves_with_player := entity_moves_with_player(vehicle, lane_index)
	var nearest_gap := INF
	var front_speed := -1.0
	for entity in active_entities:
		if not entity_sprite_is_valid(entity):
			continue
		if same_entity_sprite(entity, vehicle):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var entity_rect: Rect2 = collision_rect_provider.call(entity["sprite"], vehicle_hitbox_inset)
		if not rect_is_ahead(vehicle_rect, entity_rect, vehicle_moves_with_player):
			continue

		var entity_speed := float(entity.get("world_speed", 0.0))
		var gap := front_gap(vehicle_rect, entity_rect, vehicle_moves_with_player)
		var closing_speed := closing_speed_between(vehicle, entity, lane_index, vehicle_speed, entity_speed)
		var predicted_close_distance := closing_speed * collision_lookahead
		if gap < nearest_gap and (gap <= follow_gap or gap <= predicted_close_distance):
			nearest_gap = gap
			front_speed = comparable_front_speed(vehicle, entity, lane_index)
	return front_speed


static func update_npc_following(
	active_entities: Array,
	npc_follow_gap: float,
	npc_collision_lookahead: float,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> void:
	for entity in active_entities:
		if not entity_sprite_is_valid(entity):
			continue
		if not entity.has("desired_world_speed"):
			entity["desired_world_speed"] = entity["world_speed"]

	for lane_index in [0, 1, 2]:
		update_npc_following_for_direction(
			active_entities,
			lane_index,
			true,
			npc_follow_gap,
			npc_collision_lookahead,
			vehicle_hitbox_inset,
			collision_rect_provider
		)
		update_npc_following_for_direction(
			active_entities,
			lane_index,
			false,
			npc_follow_gap,
			npc_collision_lookahead,
			vehicle_hitbox_inset,
			collision_rect_provider
		)


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
		if not entity_sprite_is_valid(entity):
			continue
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
		if not entity_sprite_is_valid(entity):
			continue
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
	var boosted_speed := maxf(current_speed, max_speed) + speed_boost * 0.75
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


static func update_npc_following_for_direction(
	active_entities: Array,
	lane_index: int,
	moves_with_player: bool,
	npc_follow_gap: float,
	npc_collision_lookahead: float,
	vehicle_hitbox_inset: Vector4,
	collision_rect_provider: Callable
) -> void:
	var lane_entities: Array = []
	for entity in active_entities:
		if not entity_sprite_is_valid(entity):
			continue
		if entity.get("kind", "traffic") != "traffic":
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue
		if entity_moves_with_player(entity, lane_index) != moves_with_player:
			continue

		lane_entities.append(entity)

	if lane_entities.size() < 2:
		return

	if moves_with_player:
		lane_entities.sort_custom(_sort_entities_front_to_back)
	else:
		lane_entities.sort_custom(_sort_entities_left_front_to_back)

	for index in range(1, lane_entities.size()):
		var front_entity: Dictionary = lane_entities[index - 1]
		var rear_entity: Dictionary = lane_entities[index]
		var rear_desired_speed := float(rear_entity["desired_world_speed"])
		var front_speed := float(front_entity["world_speed"])
		var closing_speed := rear_desired_speed - front_speed
		if closing_speed <= 0.0:
			continue

		var front_rect: Rect2 = collision_rect_provider.call(front_entity["sprite"], vehicle_hitbox_inset)
		var rear_rect: Rect2 = collision_rect_provider.call(rear_entity["sprite"], vehicle_hitbox_inset)
		var gap := front_gap(rear_rect, front_rect, moves_with_player)
		var predicted_closing_distance := closing_speed * npc_collision_lookahead

		if gap <= npc_follow_gap or gap <= predicted_closing_distance:
			rear_entity["world_speed"] = front_speed


static func rect_is_ahead(source_rect: Rect2, other_rect: Rect2, source_moves_with_player: bool) -> bool:
	if source_moves_with_player:
		return other_rect.get_center().x > source_rect.get_center().x
	return other_rect.get_center().x < source_rect.get_center().x


static func front_gap(source_rect: Rect2, front_rect: Rect2, source_moves_with_player: bool) -> float:
	if source_moves_with_player:
		return front_rect.position.x - (source_rect.position.x + source_rect.size.x)
	return source_rect.position.x - (front_rect.position.x + front_rect.size.x)


static func closing_speed_between(vehicle: Dictionary, other: Dictionary, lane_index: int, vehicle_speed: float, other_speed: float) -> float:
	if entity_moves_with_player(vehicle, lane_index) == entity_moves_with_player(other, lane_index):
		return maxf(0.0, vehicle_speed - other_speed)
	return vehicle_speed + other_speed


static func comparable_front_speed(vehicle: Dictionary, other: Dictionary, lane_index: int) -> float:
	if entity_moves_with_player(vehicle, lane_index) == entity_moves_with_player(other, lane_index):
		return float(other.get("world_speed", 0.0))
	return 0.0


static func entity_moves_with_player(entity: Dictionary, lane_index: int) -> bool:
	if entity.has("moves_with_player"):
		return bool(entity["moves_with_player"])
	if lane_index == 0:
		return str(entity.get("spawn_side", "")) == "left"
	return true


static func entity_sprite_is_valid(entity: Dictionary) -> bool:
	var sprite = entity.get("sprite", null)
	return sprite != null and is_instance_valid(sprite)


static func same_entity_sprite(a: Dictionary, b: Dictionary) -> bool:
	if not entity_sprite_is_valid(a) or not entity_sprite_is_valid(b):
		return false
	return a.get("sprite") == b.get("sprite")


static func _sort_entities_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x > b["sprite"].position.x


static func _sort_entities_left_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x < b["sprite"].position.x
