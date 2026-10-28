extends RefCounted

# Lane eligibility, predictive clearance, and lane-dependent vehicle geometry.
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const VehicleBehaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const TrafficEntities := preload("res://scripts/game/vehicle_traffic_entities.gd")
const TrafficJamGaps := preload("res://scripts/game/traffic_jam_gaps.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")


static func update_top_lane_evasive_offsets(owner) -> void:
	for entity in owner.active_entities:
		if not TrafficEntities.is_entity_sprite_valid(entity):
			continue
		if not top_lane_evasion_candidate(entity):
			entity.erase("top_lane_evasive_offset_active")
			continue

		if top_lane_incoming_collision_is_inevitable(owner, entity):
			entity["top_lane_evasive_offset_active"] = true
		else:
			entity.erase("top_lane_evasive_offset_active")


static func top_lane_evasion_candidate(entity: Dictionary) -> bool:
	var kind := str(entity.get("kind", "traffic"))
	return (
		(kind == "traffic" or kind == "speeder")
		and int(entity.get("lane", -1)) == 0
		and TrafficEntities.entity_moves_with_player(entity, 0)
		and (entity.has("overtake_return_lane") or kind == "speeder")
	)


static func top_lane_incoming_collision_is_inevitable(owner, entity: Dictionary) -> bool:
	var lookahead: float = maxf(owner.npc_collision_lookahead, owner.player_lane_change_prediction_seconds) + 0.45
	var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var entity_future_rect: Rect2 = entity_rect
	entity_future_rect.position.x += predicted_screen_velocity(owner, entity, 0) * lookahead
	var entity_swept_rect: Rect2 = padded_rect(
		entity_rect.merge(entity_future_rect),
		owner.npc_lane_change_planning_padding_x,
		owner.npc_lane_change_planning_padding_y
	)

	for other_entity in TrafficIndex.in_lane(owner, 0):
		if not TrafficEntities.is_entity_sprite_valid(other_entity):
			continue
		if TrafficEntities.same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != 0:
			continue
		if TrafficEntities.entity_moves_with_player(other_entity, 0):
			continue

		var other_rect: Rect2 = VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var other_future_rect: Rect2 = other_rect
		other_future_rect.position.x += predicted_screen_velocity(owner, other_entity, 0) * lookahead
		var other_swept_rect: Rect2 = padded_rect(
			other_rect.merge(other_future_rect),
			owner.npc_lane_change_planning_padding_x,
			owner.npc_lane_change_planning_padding_y
		)
		if entity_swept_rect.intersects(other_swept_rect):
			return true
	return false


static func lane_is_safe_for_entity(owner, moving_entity: Dictionary, target_lane: int, safe_gap: float) -> bool:
	if target_lane in [1, 2] and TrafficJamGaps.reserved_gap_intersects(owner, projected_entity_collision_rect(owner, moving_entity, target_lane)):
		return false
	return (
		VehicleBehaviors.is_lane_safe(
			moving_entity,
			target_lane,
			safe_gap,
			TrafficEntities.active_collision_entities(owner, moving_entity, target_lane),
			owner.VEHICLE_HITBOX_INSET,
			Callable(VehicleGeometry, "collision_rect").bind(owner)
		)
		and target_lane_hitboxes_clear(owner, moving_entity, target_lane)
	)


static func target_lane_is_safe_for_entity(owner, moving_entity: Dictionary, target_lane: int, safe_gap: float) -> bool:
	return (
		lane_is_safe_for_entity(owner, moving_entity, target_lane, safe_gap)
		and top_lane_overtake_is_safe(owner, moving_entity, target_lane)
		and player_lane_is_safe_for_entity(owner, moving_entity, target_lane)
	)


static func target_lane_hitboxes_clear(owner, entity: Dictionary, target_lane: int) -> bool:
	var moving_rect := padded_rect(
		projected_entity_collision_rect(owner, entity, target_lane),
		owner.npc_lane_change_planning_padding_x,
		owner.npc_lane_change_planning_padding_y
	)
	for other_entity in TrafficIndex.in_lane(owner, target_lane):
		if not TrafficEntities.is_entity_sprite_valid(other_entity):
			continue
		if TrafficEntities.entity_collision_disabled(other_entity):
			continue
		if TrafficEntities.same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != target_lane:
			continue

		var other_rect: Rect2 = padded_rect(
			VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner),
			owner.npc_lane_change_planning_padding_x,
			owner.npc_lane_change_planning_padding_y
		)
		if moving_rect.intersects(other_rect):
			return false
	return true


static func top_lane_overtake_is_safe(owner, entity: Dictionary, target_lane: int) -> bool:
	if target_lane != 0:
		return true
	if not TrafficEntities.is_entity_sprite_valid(entity):
		return false
	if not TrafficEntities.entity_moves_with_player(entity, int(entity.get("lane", target_lane))):
		return false

	var lookahead: float = maxf(owner.npc_collision_lookahead, owner.player_lane_change_prediction_seconds) + 0.75
	var entity_rect := projected_entity_collision_rect(owner, entity, target_lane)
	var entity_future_rect := entity_rect
	entity_future_rect.position.x += predicted_screen_velocity(owner, entity, target_lane) * lookahead
	var entity_swept_rect := padded_rect(
		entity_rect.merge(entity_future_rect),
		owner.npc_lane_change_planning_padding_x,
		owner.npc_lane_change_planning_padding_y
	)

	for other_entity in TrafficIndex.in_lane(owner, 0):
		if not TrafficEntities.is_entity_sprite_valid(other_entity):
			continue
		if TrafficEntities.same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != 0:
			continue
		if TrafficEntities.entity_moves_with_player(other_entity, 0):
			continue

		var other_rect: Rect2 = VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var other_future_rect := other_rect
		other_future_rect.position.x += predicted_screen_velocity(owner, other_entity, 0) * lookahead
		var other_swept_rect := padded_rect(
			other_rect.merge(other_future_rect),
			owner.npc_lane_change_planning_padding_x,
			owner.npc_lane_change_planning_padding_y
		)
		if entity_swept_rect.intersects(other_swept_rect):
			return false
	return true


static func player_lane_is_safe_for_entity(owner, entity: Dictionary, target_lane: int) -> bool:
	if owner.player == null or not is_instance_valid(owner.player):
		return true
	if not TrafficEntities.is_entity_sprite_valid(entity):
		return false

	var entity_swept_rect := predicted_entity_swept_rect(owner, entity, target_lane)
	var player_safety_rect := player_lane_change_safety_rect(owner)
	if target_lane == owner.player_lane:
		return not entity_swept_rect.intersects(player_safety_rect)

	if absi(target_lane - owner.player_lane) == 1:
		return not rect_x_ranges_overlap(entity_swept_rect, player_safety_rect)

	return true


static func predicted_entity_swept_rect(owner, entity: Dictionary, target_lane: int) -> Rect2:
	var current_rect := projected_entity_collision_rect(owner, entity, target_lane)
	var future_rect := current_rect
	future_rect.position.x += predicted_screen_velocity(owner, entity, target_lane) * owner.player_lane_change_prediction_seconds
	return current_rect.merge(future_rect)


static func predicted_screen_velocity(owner, entity: Dictionary, target_lane: int) -> float:
	var movement_side := BusyTrafficBehavior.LEFT_SPAWN_SIDE if TrafficEntities.entity_moves_with_player(entity, target_lane) else BusyTrafficBehavior.RIGHT_SPAWN_SIDE
	return VehicleBehaviors.screen_velocity_for_spawn_side(
		target_lane,
		str(entity.get("kind", "traffic")),
		movement_side,
		float(entity.get("world_speed", 0.0)),
		owner.player_speed
	)


static func player_lane_change_safety_rect(owner) -> Rect2:
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	return Rect2(
		player_rect.position - Vector2(owner.player_lane_change_back_padding, owner.player_lane_change_side_padding),
		player_rect.size + Vector2(
			owner.player_lane_change_back_padding + owner.player_lane_change_front_padding,
			owner.player_lane_change_side_padding * 2.0
		)
	)


static func padded_rect(rect: Rect2, padding_x: float, padding_y: float) -> Rect2:
	return Rect2(
		rect.position - Vector2(padding_x, padding_y),
		rect.size + Vector2(padding_x * 2.0, padding_y * 2.0)
	)


static func rect_x_ranges_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x <= b.position.x + b.size.x and b.position.x <= a.position.x + a.size.x


static func speeder_lane_change_safe_gap(owner, target_lane: int) -> float:
	return VehicleBehaviors.speeder_lane_change_safe_gap(target_lane, owner.speeder_safe_gap, owner.speeder_avoid_lookahead)


static func speeder_target_lane_is_safe(owner, entity: Dictionary, target_lane: int) -> bool:
	return (
		speeder_lane_is_safe_for_entity(owner, entity, target_lane)
		and speeder_has_player_lane_change_clearance(owner, entity, target_lane)
	)


static func speeder_lane_is_safe_for_entity(owner, entity: Dictionary, target_lane: int) -> bool:
	if not lane_is_safe_for_entity(owner, entity, target_lane, speeder_lane_change_safe_gap(owner, target_lane)):
		return false
	if not top_lane_overtake_is_safe(owner, entity, target_lane):
		return false

	var current_lane := int(entity.get("lane", target_lane))
	if target_lane == owner.player_lane:
		return player_lane_is_safe_for_entity(owner, entity, target_lane)
	if current_lane == owner.player_lane:
		return true
	return player_lane_is_safe_for_entity(owner, entity, target_lane)


static func lane_change_allowed(entity: Dictionary, target_lane: int) -> bool:
	var current_lane := int(entity.get("lane", target_lane))
	if entity.get("kind", "traffic") == "speeder":
		return current_lane >= 0 and current_lane <= 2 and target_lane >= 0 and target_lane <= 2
	if current_lane == 0:
		return (
			TrafficEntities.entity_moves_with_player(entity, current_lane)
			and target_lane == int(entity.get("overtake_return_lane", -1))
		)
	if target_lane == 0:
		return current_lane == 1 and TrafficEntities.entity_moves_with_player(entity, current_lane)
	return current_lane >= 1 and current_lane <= 2 and target_lane >= 1 and target_lane <= 2


static func projected_entity_collision_rect(owner, entity: Dictionary, lane_index: int) -> Rect2:
	var sprite: Sprite2D = entity["sprite"]
	var target_scale := target_scale_for_entity(owner, entity, lane_index)
	var local_rect: Rect2 = VehicleGeometry.local_hitbox_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner)
	var target_y := VehicleGeometry.sprite_y_for_hitbox_bottom_with_scale(
		local_rect,
		VehicleGeometry.entity_lane_y(owner, lane_index, owner.get_viewport_rect().size, bool(entity.get("is_parked", false))),
		target_scale
	)
	var projected_global_position := sprite.global_position + Vector2(0.0, target_y - sprite.position.y)
	return VehicleGeometry.collision_rect_for_transform(sprite, projected_global_position, target_scale, local_rect)


static func speeder_has_player_lane_change_clearance(owner, entity: Dictionary, target_lane: int) -> bool:
	if owner.player == null or not is_instance_valid(owner.player):
		return true

	if target_lane != owner.player_lane:
		return true

	var speeder_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var center_gap := absf(speeder_rect.get_center().x - player_rect.get_center().x)
	return center_gap >= owner.SPEEDER_PLAYER_LANE_CHANGE_BUFFER


static func update_entity_lane_position(owner, entity: Dictionary, delta: float) -> void:
	var target_lane := int(entity.get("target_lane", entity["lane"]))
	var sprite: Sprite2D = entity["sprite"]
	if bool(entity.get("is_parked", false)) or bool(entity.get("horn_yielding", false)):
		sprite.z_index = VehicleGeometry.z_for_lane(owner, target_lane, owner.PARKED_VEHICLE_Z_OFFSET)
	elif bool(entity.get("top_lane_evasive_offset_active", false)):
		sprite.z_index = VehicleGeometry.z_for_lane(owner, 0, int(owner.ROAD_ACTOR_Z_STEP * 0.5))
	else:
		var z_offset := 2 if entity.get("kind", "traffic") == "speeder" else 0
		sprite.z_index = VehicleGeometry.z_for_lane(owner, target_lane, z_offset)
	var target_y: float = VehicleGeometry.sprite_y_for_hitbox_bottom(
		sprite,
		target_guide_y_for_entity(owner, entity, target_lane),
		owner.VEHICLE_HITBOX_INSET,
		owner
	)
	var lerp_speed: float = owner.speeder_lane_change_lerp_speed if entity.get("kind", "traffic") == "speeder" else owner.npc_lane_change_lerp_speed
	sprite.position.y = lerpf(sprite.position.y, target_y, minf(1.0, delta * lerp_speed))
	sprite.scale = sprite.scale.lerp(target_scale_for_entity(owner, entity, target_lane), minf(1.0, delta * lerp_speed))


static func target_guide_y_for_entity(owner, entity: Dictionary, target_lane: int) -> float:
	var size: Vector2 = owner.get_viewport_rect().size
	if bool(entity.get("truck_horn_yielding", false)) and target_lane == 0:
		return VehicleGeometry.entity_lane_y(owner, 0, size, false) - Tuning.ALMA_TRUCK_HORN_TOP_OFFSET * size.y / 720.0
	if bool(entity.get("horn_yielding", false)) and target_lane == 2:
		return VehicleGeometry.entity_lane_y(owner, 2, size, true)
	if bool(entity.get("top_lane_evasive_offset_active", false)) and int(entity.get("lane", -1)) == 0 and target_lane == 0:
		var top_lane_y: float = VehicleGeometry.entity_lane_y(owner, 0, size, false)
		var middle_lane_y: float = VehicleGeometry.entity_lane_y(owner, 1, size, false)
		return lerpf(top_lane_y, middle_lane_y, 0.5)

	return VehicleGeometry.entity_lane_y(owner, target_lane, size, bool(entity.get("is_parked", false)))


static func target_scale_for_entity(owner, entity: Dictionary, lane_index: int) -> Vector2:
	var sprite: Sprite2D = entity["sprite"]
	var vehicle_key := str(entity.get("vehicle_key", ""))
	var fallback_height := float(entity.get("fallback_height", 92.0))
	var lane_scale: Vector2 = VehicleGeometry.scale_for_vehicle_in_lane(
		owner,
		vehicle_key,
		VehicleGeometry.scale_for_height(sprite.texture, fallback_height),
		lane_index
	)
	if bool(entity.get("top_lane_evasive_offset_active", false)) and int(entity.get("lane", -1)) == 0 and lane_index == 0:
		var middle_scale: Vector2 = VehicleGeometry.scale_for_vehicle_in_lane(
			owner,
			vehicle_key,
			VehicleGeometry.scale_for_height(sprite.texture, fallback_height),
			1
		)
		return lane_scale.lerp(middle_scale, 0.5)
	return lane_scale
