extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleTrafficController := preload("res://scripts/game/vehicle_traffic_controller.gd")
const VehicleWheelAnimation := preload("res://scripts/game/vehicle_wheel_animation.gd")


static func collision_data(owner) -> Dictionary:
	if owner.player_hit_invincible_timer > 0.0:
		return {}

	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	for entity in TrafficIndex.in_lane(owner, owner.player_lane):
		if VehicleTrafficController.entity_collision_disabled(entity):
			continue
		if entity["lane"] != owner.player_lane:
			continue
		if bool(entity.get("low_speed_pass_hitbox_disabled", false)):
			continue

		var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if player_rect.intersects(entity_rect):
			if is_safe_low_speed_passing_contact(owner, entity):
				entity["low_speed_pass_hitbox_disabled"] = true
				continue
			if VehicleTrafficController.lane_change_fault_is_active(entity):
				VehicleTrafficController.deflect_lane_change_fault(owner, entity)
				continue
			var head_on := not bool(entity.get("is_parked", false)) and not VehicleTrafficController.entity_moves_with_player(entity, int(entity["lane"]))
			var relative_speed: float = owner.player_speed + absf(float(entity.get("world_speed", 0.0))) if head_on else absf(owner.player_speed - float(entity.get("world_speed", 0.0)))
			var relative_kmh: float = relative_speed / owner.SPEEDOMETER_REFERENCE_MAX_SPEED * owner.SPEEDOMETER_BASE_MAX_KMH
			var heavy: bool = relative_kmh >= GameTuning.HEAVY_CRASH_MIN_RELATIVE_KMH
			return {
				"detail": "Collision in the %s lane." % owner.LANE_NAMES[entity["lane"]],
				"hull_damage": GameTuning.HEAD_ON_CRASH_HULL_DAMAGE if head_on else (GameTuning.HEAVY_CRASH_HULL_DAMAGE if heavy else owner.crash_hull_damage),
				"stress_gain": GameTuning.HEAD_ON_CRASH_STRESS_GAIN if head_on else (GameTuning.HEAVY_CRASH_STRESS_GAIN if heavy else GameTuning.CRASH_STRESS_GAIN),
			}
	return {}


static func is_safe_low_speed_passing_contact(owner, entity: Dictionary) -> bool:
	var speed_kmh := clampi(
		roundi(owner.player_speed / owner.SPEEDOMETER_REFERENCE_MAX_SPEED * owner.SPEEDOMETER_BASE_MAX_KMH),
		0,
		owner.SPEEDOMETER_MAX_KMH
	)
	if speed_kmh > owner.PARKED_COLLISION_MIN_KMH:
		return false

	return bool(entity.get("is_parked", false))


static func remove_vehicles_behind_player(owner) -> void:
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var dead_entities := []
	for entity in owner.active_entities:
		var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if entity_rect.position.x + entity_rect.size.x < player_rect.position.x:
			dead_entities.append(entity)

	for entity in dead_entities:
		VehicleTrafficController.remove_entity(owner, entity)


static func update_stage_clear_entities(owner, delta: float) -> void:
	var dead_entities := []
	var viewport_width: float = owner.get_viewport_rect().size.x

	for entity in owner.active_entities:
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var world_speed: float = maxf(owner.stage_clear_min_exit_speed, absf(entity["world_speed"]))
		var screen_velocity := world_speed

		if lane_index == 0:
			screen_velocity = -world_speed

		sprite.position.x += screen_velocity * delta
		if not bool(entity.get("is_parked", false)):
			VehicleWheelAnimation.update(sprite, screen_velocity, delta)

		if lane_index == 0 and sprite.position.x < -260.0:
			dead_entities.append(entity)
		elif lane_index != 0 and sprite.position.x > viewport_width + 520.0:
			dead_entities.append(entity)

	for entity in dead_entities:
		VehicleTrafficController.remove_entity(owner, entity)
