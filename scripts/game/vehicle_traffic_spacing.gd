extends RefCounted

# Following, overlap separation, and relief for player pinning and lane-change contacts.
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const VehicleBehaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleSpawnRules := preload("res://scripts/game/vehicle_spawn_rules.gd")
const NPC_OVERLAP_SEPARATION_GAP := 8.0
const TrafficEntities := preload("res://scripts/game/vehicle_traffic_entities.gd")


static func apply_bottom_lane_speed_cap(owner) -> void:
	var cap := maxf(owner.main_vehicle_min_speed, owner.main_vehicle_max_speed)
	if str(owner.get("stage_traffic")) == "busy":
		cap = VehicleSpawnRules.shoulder_speed_range(owner).y
	if cap <= 0.0:
		return

	for entity in owner.active_entities:
		if not TrafficEntities.is_entity_sprite_valid(entity):
			continue
		if int(entity.get("lane", -1)) != 2:
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if float(entity.get("horn_speed_timer", 0.0)) > 0.0:
			continue
		if TrafficEntities.is_overtake_speed_exempt(entity):
			continue

		entity["desired_world_speed"] = minf(float(entity.get("desired_world_speed", cap)), cap)
		entity["world_speed"] = minf(float(entity.get("world_speed", cap)), cap)


static func deflect_lane_change_fault(owner, entity: Dictionary) -> void:
	TrafficEntities.cancel_entity_lane_change_warning(entity)
	TrafficEntities.clear_overtake_state(entity)

	var previous_lane := int(entity.get("lane_change_previous_lane", -1))
	if previous_lane >= 0 and previous_lane <= 2 and previous_lane != owner.player_lane:
		entity["lane"] = previous_lane
		TrafficIndex.invalidate(owner)
		entity["target_lane"] = previous_lane
		entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, previous_lane)
	else:
		entity["world_speed"] = minf(float(entity.get("world_speed", owner.player_speed)), maxf(0.0, owner.player_speed - 60.0))
		entity["desired_world_speed"] = minf(float(entity.get("desired_world_speed", owner.player_speed)), float(entity["world_speed"]))

	entity["lane_change_cooldown"] = maxf(float(entity.get("lane_change_cooldown", 0.0)), 3.0)
	entity["lane_change_fault_grace_timer"] = maxf(float(entity.get("lane_change_fault_grace_timer", 0.0)), 0.25)


static func relieve_player_pin_pressure(owner) -> void:
	if not player_is_pinned(owner):
		return

	var protected_lanes := player_protected_lanes(owner)
	for entity in owner.active_entities:
		if not TrafficEntities.is_entity_sprite_valid(entity):
			continue

		if bool(entity.get("lane_change_warning_active", false)):
			var target_lane := int(entity.get("lane_change_warning_target_lane", entity.get("lane", -1)))
			if protected_lanes.has(target_lane):
				TrafficEntities.cancel_entity_lane_change_warning(entity)
				entity["lane_change_cooldown"] = maxf(float(entity.get("lane_change_cooldown", 0.0)), 2.5)

		slow_rear_pressure_vehicle(owner, entity)


static func player_is_pinned(owner) -> bool:
	if owner.player == null or not is_instance_valid(owner.player):
		return false

	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var front_gap := nearest_player_lane_gap(owner, player_rect, true)
	var rear_gap := nearest_player_lane_gap(owner, player_rect, false)
	var front_blocked: bool = front_gap <= owner.pin_pressure_front_gap
	var rear_blocked: bool = rear_gap <= owner.pin_pressure_rear_gap
	var escape_blocked: bool = player_escape_lanes_blocked(owner, player_rect)
	return front_blocked and (rear_blocked or escape_blocked)


static func nearest_player_lane_gap(owner, player_rect: Rect2, ahead: bool) -> float:
	var nearest_gap := INF
	var player_center_x := player_rect.get_center().x
	for entity in TrafficIndex.in_lane(owner, owner.player_lane):
		if not TrafficEntities.is_entity_sprite_valid(entity):
			continue
		if TrafficEntities.entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != owner.player_lane:
			continue

		var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var entity_center_x := entity_rect.get_center().x
		if ahead and entity_center_x <= player_center_x:
			continue
		if not ahead and entity_center_x >= player_center_x:
			continue

		var gap := entity_rect.position.x - (player_rect.position.x + player_rect.size.x) if ahead else player_rect.position.x - (entity_rect.position.x + entity_rect.size.x)
		nearest_gap = minf(nearest_gap, maxf(0.0, gap))
	return nearest_gap


static func player_escape_lanes_blocked(owner, player_rect: Rect2) -> bool:
	var checked_lanes := 0
	var blocked_lanes := 0
	for lane_index in [owner.player_lane - 1, owner.player_lane + 1]:
		if lane_index < 0 or lane_index > 2:
			continue
		checked_lanes += 1
		if not player_escape_lane_is_clear(owner, lane_index, player_rect):
			blocked_lanes += 1

	return checked_lanes > 0 and blocked_lanes >= checked_lanes


static func player_escape_lane_is_clear(owner, lane_index: int, player_rect: Rect2) -> bool:
	for entity in TrafficIndex.in_lane(owner, lane_index):
		if not TrafficEntities.is_entity_sprite_valid(entity):
			continue
		if TrafficEntities.entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if absf(entity_rect.get_center().x - player_rect.get_center().x) < owner.pin_pressure_escape_lane_gap:
			return false
	return true


static func player_protected_lanes(owner) -> Array:
	var protected_lanes: Array = [owner.player_lane]
	for lane_index in [owner.player_lane - 1, owner.player_lane + 1]:
		if lane_index >= 0 and lane_index <= 2:
			protected_lanes.append(lane_index)
	return protected_lanes


static func slow_rear_pressure_vehicle(owner, entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) != owner.player_lane:
		return
	if TrafficEntities.entity_collision_disabled(entity):
		return

	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	if entity_rect.get_center().x >= player_rect.get_center().x:
		return

	var rear_gap := player_rect.position.x - (entity_rect.position.x + entity_rect.size.x)
	if rear_gap > owner.pin_pressure_rear_gap:
		return

	var pressure_speed := maxf(0.0, owner.player_speed - 60.0)
	TrafficEntities.limit_entity_speed(entity, pressure_speed)


static func update_npc_following(owner) -> void:
	VehicleBehaviors.update_npc_following(
		TrafficEntities.active_collision_entities(owner),
		owner.npc_follow_gap,
		owner.npc_collision_lookahead,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)


static func resolve_vehicle_overlaps(owner) -> void:
	for lane_index in range(3):
		resolve_direction_overlaps(owner, lane_index, true)
		resolve_direction_overlaps(owner, lane_index, false)
		resolve_opposing_direction_overlaps(owner, lane_index)


static func resolve_direction_overlaps(owner, lane_index: int, moves_with_player: bool) -> void:
	var lane_entities: Array = []
	for entity in TrafficIndex.in_lane(owner, lane_index):
		var kind := str(entity.get("kind", "traffic"))
		if kind != "traffic" and kind != "speeder":
			continue
		if TrafficEntities.entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue
		if TrafficEntities.entity_moves_with_player(entity, lane_index) != moves_with_player:
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
		if TrafficEntities.bottom_lane_traffic_can_pass_parked(rear_entity, front_entity) or TrafficEntities.bottom_lane_traffic_can_pass_parked(front_entity, rear_entity):
			continue

		var front_rect: Rect2 = VehicleGeometry.collision_rect(front_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var rear_rect: Rect2 = VehicleGeometry.collision_rect(rear_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var separation_gap := NPC_OVERLAP_SEPARATION_GAP
		if rear_entity.get("kind", "traffic") == "speeder":
			# Use visible bumper edges for following clearance. The inset contact
			# hitboxes remain unchanged for collisions with the player's tricycle.
			var bumper_inset := Vector4(0.0, owner.VEHICLE_HITBOX_INSET.y, 0.0, owner.VEHICLE_HITBOX_INSET.w)
			front_rect = VehicleGeometry.collision_rect(front_entity["sprite"], bumper_inset, owner)
			rear_rect = VehicleGeometry.collision_rect(rear_entity["sprite"], bumper_inset, owner)
			separation_gap = maxf(0.0, GameTuning.SPEEDER_FRONT_CLEARANCE_PIXELS)

		if moves_with_player:
			var rear_right: float = rear_rect.position.x + rear_rect.size.x
			var desired_rear_right: float = front_rect.position.x - separation_gap
			if rear_right > desired_rear_right:
				rear_entity["sprite"].position.x += desired_rear_right - rear_right
				TrafficEntities.limit_entity_speed(rear_entity, float(front_entity.get("world_speed", 0.0)))
		else:
			var front_right: float = front_rect.position.x + front_rect.size.x
			var desired_rear_left: float = front_right + separation_gap
			if rear_rect.position.x < desired_rear_left:
				rear_entity["sprite"].position.x += desired_rear_left - rear_rect.position.x
				TrafficEntities.limit_entity_speed(rear_entity, float(front_entity.get("world_speed", 0.0)))


static func resolve_opposing_direction_overlaps(owner, lane_index: int) -> void:
	var right_movers: Array = []
	var left_movers: Array = []
	for entity in TrafficIndex.in_lane(owner, lane_index):
		var kind := str(entity.get("kind", "traffic"))
		if kind != "traffic" and kind != "speeder":
			continue
		if TrafficEntities.entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		if TrafficEntities.entity_moves_with_player(entity, lane_index):
			right_movers.append(entity)
		else:
			left_movers.append(entity)

	if right_movers.is_empty() or left_movers.is_empty():
		return

	for right_mover in right_movers:
		for left_mover in left_movers:
			var right_mover_rect: Rect2 = VehicleGeometry.collision_rect(right_mover["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
			var left_mover_rect: Rect2 = VehicleGeometry.collision_rect(left_mover["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
			if not right_mover_rect.intersects(left_mover_rect):
				continue

			var left_entity: Dictionary = right_mover
			var left_rect: Rect2 = right_mover_rect
			var right_entity: Dictionary = left_mover
			var right_rect: Rect2 = left_mover_rect
			if left_mover_rect.get_center().x < right_mover_rect.get_center().x:
				left_entity = left_mover
				left_rect = left_mover_rect
				right_entity = right_mover
				right_rect = right_mover_rect

			var overlap_amount: float = (left_rect.position.x + left_rect.size.x) - right_rect.position.x + NPC_OVERLAP_SEPARATION_GAP
			if overlap_amount <= 0.0:
				continue

			var half_shift: float = overlap_amount * 0.5
			left_entity["sprite"].position.x -= half_shift
			right_entity["sprite"].position.x += half_shift


static func _sort_entities_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x > b["sprite"].position.x


static func _sort_entities_left_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x < b["sprite"].position.x
