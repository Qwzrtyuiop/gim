extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const GameRandom := preload("res://scripts/game/game_random.gd")
const VehicleBehaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleSpawnRules := preload("res://scripts/game/vehicle_spawn_rules.gd")
const VehicleVisuals := preload("res://scripts/game/vehicle_visuals.gd")
const VehicleWheelAnimation := preload("res://scripts/game/vehicle_wheel_animation.gd")

const SPAWN_HITBOX_CLEARANCE_X := 12.0
const PARKED_FALLBACK_HEIGHTS := {
	"parkedmoped": 74.0,
	"parkedtruck": 96.0,
}


static func spawn_traffic(owner, lane_index: int, spawn_side := BusyTrafficBehavior.RIGHT_SPAWN_SIDE) -> bool:
	if owner.stage_traffic == "busy" and lane_index == 2:
		spawn_side = BusyTrafficBehavior.RIGHT_SPAWN_SIDE
	var size: Vector2 = owner.get_viewport_rect().size
	var sprite := Sprite2D.new()
	var vehicle_key := ""
	var world_speed := 0.0
	var min_world_speed := 0.0
	var max_world_speed := 0.0
	var fallback_height := 80.0
	var is_busy_car := false
	var is_parked := false
	var moves_with_player := lane_index != 0 or spawn_side == BusyTrafficBehavior.LEFT_SPAWN_SIDE

	match lane_index:
		0:
			vehicle_key = GameRandom.choose(owner.rng, ["blue_truck", "bus", "cargotruck", "jeepney", "sedan", "truck", "van"])
			min_world_speed = minf(owner.incoming_vehicle_min_speed, owner.incoming_vehicle_max_speed)
			max_world_speed = maxf(owner.incoming_vehicle_min_speed, owner.incoming_vehicle_max_speed)
			fallback_height = 96.0
			sprite.flip_h = spawn_side == BusyTrafficBehavior.RIGHT_SPAWN_SIDE
		1:
			vehicle_key = GameRandom.choose(owner.rng, ["beetle", "gray_sedan", "jeepney", "sedan", "motorcycle", "van"])
			min_world_speed = minf(owner.main_vehicle_min_speed, owner.main_vehicle_max_speed)
			max_world_speed = maxf(owner.main_vehicle_min_speed, owner.main_vehicle_max_speed)
			fallback_height = 96.0
		2:
			var can_spawn_parked: bool = owner.stage_traffic != "busy" or spawn_side != BusyTrafficBehavior.LEFT_SPAWN_SIDE
			if can_spawn_parked and owner.rng.randf() < owner.shoulder_parked_chance:
				is_parked = true
				vehicle_key = GameRandom.choose(owner.rng, owner.PARKED_VEHICLE_KEYS)
				world_speed = 0.0
				fallback_height = float(PARKED_FALLBACK_HEIGHTS.get(vehicle_key, 96.0))
			else:
				vehicle_key = GameRandom.choose_weighted(owner.rng, {
					"beetle": 12.0,
					"vendor_tricycle": 46.0,
					"motorcycle": 46.0,
					"van": 8.0,
					"jeepney": 4.0,
					"sedan": 4.0,
				})
				var shoulder_range := VehicleSpawnRules.shoulder_speed_range(owner)
				min_world_speed = shoulder_range.x
				max_world_speed = shoulder_range.y
				fallback_height = 90.0

	if not is_parked:
		var speed_range: Vector2 = VehicleSpawnRules.vehicle_speed_range_for_spawn_side(owner, min_world_speed, max_world_speed, spawn_side, lane_index)
		min_world_speed = speed_range.x
		max_world_speed = speed_range.y
		world_speed = owner.rng.randf_range(min_world_speed, max_world_speed)

	if world_speed > 0.0 and lane_index in [1, 2]:
		is_busy_car = VehicleSpawnRules.is_post_day_seven_traffic_ramp(owner) and owner.rng.randf() < VehicleSpawnRules.get_post_day_busy_car_chance(owner, lane_index)

	sprite.texture = owner.VEHICLE_TEXTURES[vehicle_key]
	sprite.centered = true
	sprite.scale = VehicleGeometry.scale_for_vehicle_in_lane(
		owner,
		vehicle_key,
		VehicleGeometry.scale_for_height(sprite.texture, fallback_height),
		lane_index
	)
	VehicleVisuals.apply_shadow(owner, sprite, owner.VEHICLE_HITBOX_INSET)
	if not is_parked:
		VehicleVisuals.apply_headlight(owner, sprite, owner.VEHICLE_HITBOX_INSET)
		VehicleWheelAnimation.attach(sprite, vehicle_key)
	var spawn_x: float
	if not moves_with_player:
		# Keep the whole car just offscreen, regardless of its width or transparent padding.
		var visible_rect := VehicleGeometry.local_hitbox_rect(sprite, Vector4.ZERO, owner)
		spawn_x = size.x + maxf(0.0, GameTuning.ONCOMING_SPAWN_EDGE_GAP) - visible_rect.position.x * sprite.scale.x
	else:
		spawn_x = VehicleSpawnRules.vehicle_spawn_x(owner, size, spawn_side, lane_index)
	sprite.position = Vector2(
		spawn_x,
		VehicleGeometry.sprite_y_for_hitbox_bottom(
			sprite,
			VehicleGeometry.entity_lane_y(owner, lane_index, size, is_parked),
			owner.VEHICLE_HITBOX_INSET,
			owner
		)
	)
	sprite.z_index = VehicleGeometry.z_for_lane(owner, lane_index, owner.PARKED_VEHICLE_Z_OFFSET if is_parked else 0)
	if not spawn_hitbox_is_clear(owner, sprite, lane_index, spawn_side, world_speed):
		sprite.free()
		return false
	if not owner.traffic_jam_gaps.can_spawn(owner, sprite, lane_index, world_speed):
		sprite.free()
		return false

	owner.add_child(sprite)

	TrafficIndex.invalidate(owner)
	owner.active_entities.append({
		"sprite": sprite,
		"lane": lane_index,
		"target_lane": lane_index,
		"vehicle_key": vehicle_key,
		"fallback_height": fallback_height,
		"kind": "traffic",
		"spawn_side": spawn_side,
		"moves_with_player": moves_with_player,
		"desired_world_speed": world_speed,
		"world_speed": world_speed,
		"min_world_speed": min_world_speed,
		"max_world_speed": max_world_speed,
		"speed_change_timer": VehicleSpawnRules.next_vehicle_speed_change_delay(owner),
		"is_parked": is_parked,
		"is_busy_car": is_busy_car,
		"overtake_speed_timer": 0.0,
		"pending_overtake_speed_boost": false,
		"lane_change_cooldown": owner.rng.randf_range(0.6, 2.0),
		"lane_change_warning_active": false,
	})
	owner.traffic_jam_gaps.spawned(owner, owner.active_entities.back())
	return true


static func spawn_speeder(owner) -> void:
	var size: Vector2 = owner.get_viewport_rect().size
	var lane_index := 1
	var vehicle_key: String = GameRandom.choose(owner.rng, ["sedan", "gray_sedan"])
	var min_world_speed := minf(owner.speeder_vehicle_min_speed, owner.speeder_vehicle_max_speed)
	var max_world_speed := maxf(owner.speeder_vehicle_min_speed, owner.speeder_vehicle_max_speed)
	var world_speed: float = owner.rng.randf_range(min_world_speed, max_world_speed)
	var sprite := Sprite2D.new()
	sprite.texture = owner.VEHICLE_TEXTURES[vehicle_key]
	sprite.centered = true
	sprite.scale = VehicleGeometry.scale_for_vehicle_in_lane(
		owner,
		vehicle_key,
		VehicleGeometry.scale_for_height(sprite.texture, 92.0),
		lane_index
	)
	VehicleVisuals.apply_shadow(owner, sprite, owner.VEHICLE_HITBOX_INSET)
	VehicleVisuals.apply_headlight(owner, sprite, owner.VEHICLE_HITBOX_INSET)
	VehicleWheelAnimation.attach(sprite, vehicle_key)
	sprite.position = Vector2(
		-220.0,
		VehicleGeometry.sprite_y_for_hitbox_bottom(
			sprite,
			VehicleGeometry.lane_y(owner, lane_index, size),
			owner.VEHICLE_HITBOX_INSET,
			owner
		)
	)
	sprite.z_index = VehicleGeometry.z_for_lane(owner, lane_index, 2)
	owner.add_child(sprite)

	TrafficIndex.invalidate(owner)
	owner.active_entities.append({
		"sprite": sprite,
		"lane": lane_index,
		"target_lane": lane_index,
		"vehicle_key": vehicle_key,
		"fallback_height": 92.0,
		"kind": "speeder",
		"moves_with_player": true,
		"desired_world_speed": world_speed,
		"world_speed": world_speed,
		"min_world_speed": min_world_speed,
		"max_world_speed": max_world_speed,
		"speed_change_timer": VehicleSpawnRules.next_vehicle_speed_change_delay(owner),
		"lane_change_cooldown": 0.0,
	})


static func spawn_hitbox_is_clear(owner, sprite: Sprite2D, lane_index: int, spawn_side: String, world_speed: float) -> bool:
	var spawn_rect: Rect2 = VehicleGeometry.collision_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner)
	var padded_spawn_rect := Rect2(
		spawn_rect.position - Vector2(SPAWN_HITBOX_CLEARANCE_X, 0.0),
		spawn_rect.size + Vector2(SPAWN_HITBOX_CLEARANCE_X * 2.0, 0.0)
	)
	if not spawn_is_clear_of_player(owner, padded_spawn_rect, lane_index, spawn_side, world_speed):
		return false

	for entity in owner.active_entities:
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var other_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if padded_spawn_rect.intersects(other_rect):
			return false
	return true


static func spawn_is_clear_of_player(owner, spawn_rect: Rect2, lane_index: int, spawn_side: String, world_speed: float) -> bool:
	if owner.player == null or not is_instance_valid(owner.player):
		return true
	if absi(lane_index - owner.player_lane) > 1:
		return true

	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	if lane_index == 0 and spawn_side == BusyTrafficBehavior.RIGHT_SPAWN_SIDE:
		# Oncoming cars have an advance warning and spawn just outside the screen.
		# A lane-change prediction rejects them at high closing speeds even when
		# the spawn is clear. Check actual overlap here; keep prediction for other traffic.
		return not spawn_rect.intersects(player_rect)

	var future_rect := spawn_rect
	var movement_side := BusyTrafficBehavior.LEFT_SPAWN_SIDE if lane_index != 0 or spawn_side == BusyTrafficBehavior.LEFT_SPAWN_SIDE else BusyTrafficBehavior.RIGHT_SPAWN_SIDE
	var screen_velocity: float = VehicleBehaviors.screen_velocity_for_spawn_side(
		lane_index,
		"traffic",
		movement_side,
		world_speed,
		owner.player_speed
	)
	future_rect.position.x += screen_velocity * owner.player_lane_change_prediction_seconds
	var swept_spawn_rect := spawn_rect.merge(future_rect)
	var player_safety_rect := Rect2(
		player_rect.position - Vector2(owner.player_lane_change_back_padding, owner.player_lane_change_side_padding),
		player_rect.size + Vector2(
			owner.player_lane_change_back_padding + owner.player_lane_change_front_padding,
			owner.player_lane_change_side_padding * 2.0
		)
	)
	if lane_index == owner.player_lane:
		return not swept_spawn_rect.intersects(player_safety_rect)
	return not (swept_spawn_rect.position.x <= player_safety_rect.position.x + player_safety_rect.size.x and player_safety_rect.position.x <= swept_spawn_rect.position.x + swept_spawn_rect.size.x)
