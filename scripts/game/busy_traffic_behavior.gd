extends RefCounted

const LEFT_SPAWN_SIDE := "left"
const RIGHT_SPAWN_SIDE := "right"
const BACK_SPAWN_CHANCE_AT_SLOW_SPEED := 0.72
const BACK_SPAWN_CHANCE_AT_FAST_SPEED := 0.25
const BACK_CAR_MIN_SPEED_ADVANTAGE := 90.0
const BACK_CAR_MAX_SPEED_ADVANTAGE := 240.0
const BACK_SPAWN_MIN_OFFSET := 180.0
const BACK_SPAWN_MAX_OFFSET := 420.0
const FRONT_SPAWN_MIN_OFFSET := 90.0
const FRONT_SPAWN_MAX_OFFSET := 360.0
const FAST_SPAWN_ROOM_EXTRA := 260.0


static func player_x(viewport_size: Vector2) -> float:
	return viewport_size.x * 0.5


static func spawn_side(rng: RandomNumberGenerator, player_speed: float, player_max_speed: float) -> String:
	var speed_ratio := clampf(player_speed / maxf(1.0, player_max_speed), 0.0, 1.0)
	var back_spawn_chance := lerpf(BACK_SPAWN_CHANCE_AT_SLOW_SPEED, BACK_SPAWN_CHANCE_AT_FAST_SPEED, speed_ratio)
	if rng.randf() < back_spawn_chance:
		return LEFT_SPAWN_SIDE
	return RIGHT_SPAWN_SIDE


static func spawn_x(viewport_size: Vector2, side: String, rng: RandomNumberGenerator, player_speed: float, player_max_speed: float) -> float:
	if side == LEFT_SPAWN_SIDE:
		return -rng.randf_range(BACK_SPAWN_MIN_OFFSET, BACK_SPAWN_MAX_OFFSET)

	return viewport_size.x + rng.randf_range(FRONT_SPAWN_MIN_OFFSET, FRONT_SPAWN_MAX_OFFSET)


static func lane_has_spawn_room(active_entities: Array, lane_index: int, viewport_size: Vector2, side: String, player_speed: float, player_max_speed: float) -> bool:
	var speed_ratio := clampf(player_speed / maxf(1.0, player_max_speed), 0.0, 1.0)
	var offscreen_buffer := 40.0
	var extra_room := FAST_SPAWN_ROOM_EXTRA * speed_ratio
	var left_edge := -offscreen_buffer - extra_room
	var right_edge := viewport_size.x + offscreen_buffer + extra_room
	for entity in active_entities:
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var sprite: Sprite2D = entity.get("sprite")
		if sprite == null:
			continue

		if side == LEFT_SPAWN_SIDE and sprite.position.x < left_edge:
			return false
		if side == RIGHT_SPAWN_SIDE and sprite.position.x > right_edge:
			return false
	return true


static func is_left_car(entity: Dictionary) -> bool:
	return str(entity.get("spawn_side", "")) == LEFT_SPAWN_SIDE


static func speed_range_for_spawn_side(min_speed: float, max_speed: float, side: String, player_speed: float) -> Vector2:
	if side != LEFT_SPAWN_SIDE:
		return Vector2(min_speed, max_speed)

	var boosted_min := maxf(min_speed, player_speed + BACK_CAR_MIN_SPEED_ADVANTAGE)
	var boosted_max := maxf(max_speed, boosted_min + BACK_CAR_MAX_SPEED_ADVANTAGE)
	return Vector2(boosted_min, boosted_max)


static func overtake_lane_order(lane_index: int) -> Array[int]:
	match lane_index:
		0:
			return []
		1:
			return [2]
		2:
			return [1]
	return [1, 2]
