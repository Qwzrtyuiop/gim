extends RefCounted

const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleTrafficController := preload("res://scripts/game/vehicle_traffic_controller.gd")


static func collision_detail(owner) -> String:
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	for entity in owner.active_entities:
		if VehicleTrafficController.entity_collision_disabled(entity):
			continue
		if entity["lane"] != owner.player_lane:
			continue
		if bool(entity.get("parked_hitbox_disabled", false)):
			continue

		var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if player_rect.intersects(entity_rect):
			if is_safe_low_speed_parked_contact(owner, entity):
				entity["parked_hitbox_disabled"] = true
				continue
			if VehicleTrafficController.lane_change_fault_is_active(entity):
				VehicleTrafficController.deflect_lane_change_fault(owner, entity)
				continue
			return "Collision in the %s lane. Space/R to retry." % owner.LANE_NAMES[entity["lane"]]
	return ""


static func is_safe_low_speed_parked_contact(owner, entity: Dictionary) -> bool:
	var speed_kmh := clampi(
		roundi(owner.player_speed / owner.SPEEDOMETER_REFERENCE_MAX_SPEED * owner.SPEEDOMETER_BASE_MAX_KMH),
		0,
		owner.SPEEDOMETER_MAX_KMH
	)
	return bool(entity.get("is_parked", false)) and speed_kmh <= owner.PARKED_COLLISION_MIN_KMH


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

		if lane_index == 0 and sprite.position.x < -260.0:
			dead_entities.append(entity)
		elif lane_index != 0 and sprite.position.x > viewport_width + 520.0:
			dead_entities.append(entity)

	for entity in dead_entities:
		VehicleTrafficController.remove_entity(owner, entity)
