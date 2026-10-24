extends RefCounted

# NPC lane-change decisions, warning completion, and overtaking behavior.
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const VehicleBehaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleSpawnRules := preload("res://scripts/game/vehicle_spawn_rules.gd")
const OVERTAKE_PASS_BUFFER_X := 12.0
const TrafficEntities := preload("res://scripts/game/vehicle_traffic_entities.gd")
const TrafficSignals := preload("res://scripts/game/vehicle_traffic_signals.gd")
const LaneNavigation := preload("res://scripts/game/vehicle_lane_navigation.gd")
const TrafficSpacing := preload("res://scripts/game/vehicle_traffic_spacing.gd")


static func update_speeder_lane_change_warning(owner, delta: float) -> void:
	if owner.speeder_lane_change_warning_label:
		owner.speeder_lane_change_warning_label.visible = false

	if not owner.speeder_lane_change_warning_active:
		return

	if not is_instance_valid(owner.pending_speeder_lane_change_sprite):
		TrafficSignals.clear_speeder_lane_change_warning(owner)
		return

	var lane_to_warn: int = owner.speeder_lane_change_warning_target_lane if owner.speeder_lane_change_warning_target_lane >= 0 else owner.player_lane
	if owner.speeder_lane_change_warning_label:
		owner.speeder_lane_change_warning_label.position = Vector2(
			owner.player_x + 105.0,
			VehicleGeometry.lane_y(owner, lane_to_warn, owner.get_viewport_rect().size) - 92.0
		)
		owner.speeder_lane_change_warning_label.visible = owner.speeder_lane_change_warning_beeps_remaining >= 0

	owner.speeder_lane_change_warning_timer -= delta
	if owner.speeder_lane_change_warning_timer > 0.0:
		return

	if owner.speeder_lane_change_warning_beeps_remaining > 0:
		TrafficSignals.pulse_speeder_lane_change_warning(owner)
		owner.speeder_lane_change_warning_beeps_remaining -= 1
		owner.speeder_lane_change_warning_timer = 0.28
	else:
		complete_speeder_lane_change_warning(owner)


static func complete_speeder_lane_change_warning(owner) -> void:
	var entity := TrafficEntities.find_entity_by_sprite(owner, owner.pending_speeder_lane_change_sprite)
	if not entity.is_empty():
		var target_lane: int = owner.speeder_lane_change_warning_target_lane
		if LaneNavigation.speeder_target_lane_is_safe(owner, entity, target_lane):
			var previous_lane := int(entity.get("lane", target_lane))
			entity["lane"] = target_lane
			TrafficIndex.invalidate(owner)
			entity["target_lane"] = target_lane
			entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, target_lane, 2)
			TrafficEntities.mark_recent_lane_change(owner, entity, previous_lane)

	TrafficSignals.clear_speeder_lane_change_warning(owner)


static func update_random_lane_changes(owner, delta: float) -> void:
	var post_day_seven_traffic_ramp: bool = VehicleSpawnRules.is_post_day_seven_traffic_ramp(owner)
	if not owner.npc_random_lane_change_enabled and not post_day_seven_traffic_ramp:
		return

	for entity in owner.active_entities:
		if bool(entity.get("lane_change_warning_active", false)):
			continue
		if entity.get("kind", "traffic") != "traffic":
			continue
		if float(entity.get("world_speed", 0.0)) <= 0.0:
			continue

		var lane_index := int(entity["lane"])
		if lane_index < 0 or lane_index > 2:
			continue

		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		if float(entity["lane_change_cooldown"]) > 0.0:
			continue

		var is_busy_car := bool(entity.get("is_busy_car", false))
		if not owner.npc_random_lane_change_enabled and not is_busy_car:
			continue

		var lane_change_chance: float = owner.npc_lane_change_chance_per_second if owner.npc_random_lane_change_enabled else 0.0
		if is_busy_car:
			lane_change_chance = maxf(lane_change_chance, owner.POST_DAY_SEVEN_BUSY_CAR_LANE_CHANGE_CHANCE_PER_SECOND)
		if lane_index == 2:
			lane_change_chance *= owner.bottom_lane_lane_change_chance_x

		if owner.rng.randf() > lane_change_chance * delta:
			continue

		var target_lane := random_lane_change_target(entity, lane_index)
		if target_lane < 0:
			continue
		if LaneNavigation.target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
			start_lane_change_warning(owner, entity, target_lane)

		entity["lane_change_cooldown"] = owner.rng.randf_range(1.2, 3.5)


static func random_lane_change_target(entity: Dictionary, lane_index: int) -> int:
	match lane_index:
		0:
			return -1
		1:
			return 2
		2:
			return 1
	return -1


static func update_vehicle_speeds(owner, delta: float) -> void:
	VehicleBehaviors.update_speed_targets(
		owner.active_entities,
		delta,
		owner.rng,
		owner.vehicle_speed_change_min_delay,
		owner.vehicle_speed_change_max_delay,
		owner.vehicle_speed_acceleration
	)
	TrafficSpacing.apply_bottom_lane_speed_cap(owner)


static func update_overtake_speed_boosts(owner, delta: float) -> void:
	VehicleBehaviors.update_overtake_speed_boosts(owner.active_entities, delta)
	for entity in owner.active_entities:
		var kind := str(entity.get("kind", "traffic"))
		if kind != "traffic" and kind != "speeder":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if TrafficEntities._is_overtaking_or_lane_changing(entity):
			update_overtake_completion(owner, entity)
			if kind == "traffic":
				apply_forward_collision_detection(owner, entity)
	update_top_lane_overtake_returns(owner)
	TrafficSpacing.apply_bottom_lane_speed_cap(owner)


static func update_lane_change_warnings(owner, delta: float) -> void:
	for entity in owner.active_entities:
		if not bool(entity.get("lane_change_warning_active", false)):
			continue

		entity["lane_change_warning_timer"] = float(entity.get("lane_change_warning_timer", 0.0)) - delta
		if float(entity["lane_change_warning_timer"]) > 0.0:
			continue

		var pulses_remaining := int(entity.get("lane_change_warning_pulses_remaining", 0))
		if pulses_remaining > 0:
			TrafficSignals.pulse_entity_lane_warning(owner, entity)
			entity["lane_change_warning_pulses_remaining"] = pulses_remaining - 1
			entity["lane_change_warning_timer"] = owner.NPC_LANE_CHANGE_WARNING_INTERVAL
		else:
			finish_warned_lane_change(owner, entity)


static func start_lane_change_warning(owner, entity: Dictionary, target_lane: int) -> void:
	entity["lane_change_warning_active"] = true
	entity["lane_change_warning_target_lane"] = target_lane
	entity["lane_change_previous_lane"] = int(entity.get("lane", target_lane))
	entity["lane_change_warning_pulses_remaining"] = owner.NPC_LANE_CHANGE_WARNING_PULSES
	entity["lane_change_warning_timer"] = 0.0
	var warning_label := TrafficSignals.get_entity_lane_warning_label(owner, entity)
	warning_label.visible = false


static func finish_warned_lane_change(owner, entity: Dictionary) -> void:
	var target_lane := int(entity.get("lane_change_warning_target_lane", entity["lane"]))
	var warning_label := TrafficSignals.get_entity_lane_warning_label(owner, entity)
	warning_label.visible = false
	entity["lane_change_warning_active"] = false

	if LaneNavigation.lane_change_allowed(entity, target_lane) and LaneNavigation.target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
		var previous_lane := int(entity.get("lane_change_previous_lane", entity["lane"]))
		entity["lane"] = target_lane
		TrafficIndex.invalidate(owner)
		entity["target_lane"] = target_lane
		entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, target_lane)
		TrafficEntities.mark_recent_lane_change(owner, entity, previous_lane)
		if bool(entity.get("returning_from_top_lane_overtake", false)):
			TrafficEntities.clear_top_lane_overtake_return(entity)
		if bool(entity.get("pending_overtake_speed_boost", false)):
			boost_vehicle_for_overtake(owner, entity)
	else:
		if target_lane == 0:
			TrafficEntities.clear_top_lane_overtake_return(entity)
		entity.erase("lane_change_previous_lane")
		entity.erase("returning_from_top_lane_overtake")

	entity["pending_overtake_speed_boost"] = false
	entity["lane_change_cooldown"] = owner.rng.randf_range(1.2, 3.5)


static func update_speeder_ai(owner) -> void:
	for entity in owner.active_entities:
		if entity.get("kind", "traffic") != "speeder":
			continue

		var lane_index := int(entity["lane"])
		if speeder_needs_lane_change(owner, entity, lane_index):
			var changed_lane := false
			for avoid_target_lane in VehicleBehaviors.speeder_overtake_lane_order(lane_index):
				if try_set_speeder_target_lane(owner, entity, avoid_target_lane):
					set_overtake_target(owner, entity, lane_index)
					changed_lane = true
					break
			if not changed_lane:
				slow_speeder_near_player(owner, entity)
			continue

		if lane_index != 1:
			try_set_speeder_target_lane(owner, entity, 1)


static func update_busy_vehicle_ai(owner, delta: float) -> void:
	if owner.stage_traffic != "busy":
		return

	for entity in owner.active_entities:
		if entity.get("kind", "traffic") != "traffic":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			apply_forward_collision_detection(owner, entity)
			continue

		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		if float(entity["lane_change_cooldown"]) > 0.0:
			apply_forward_collision_detection(owner, entity)
			continue

		var lane_index := int(entity["lane"])

		if not vehicle_needs_lane_change(owner, entity, lane_index):
			continue

		var changed_lane := false
		for target_lane in BusyTrafficBehavior.overtake_lane_order(lane_index):
			if try_warn_vehicle_lane_change(owner, entity, target_lane):
				set_overtake_target(owner, entity, lane_index)
				entity["pending_overtake_speed_boost"] = true
				changed_lane = true
				break
		if not changed_lane:
			slow_vehicle_for_front_car(owner, entity, lane_index)


static func update_vehicle_overtake_ai(owner, delta: float) -> void:
	for entity in owner.active_entities:
		if entity.get("kind", "traffic") != "traffic":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			apply_forward_collision_detection(owner, entity)
			continue
		if float(entity.get("world_speed", 0.0)) <= 0.0:
			continue

		var lane_index := int(entity["lane"])
		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		if float(entity["lane_change_cooldown"]) > 0.0:
			apply_forward_collision_detection(owner, entity)
			continue

		if lane_index == 0:
			continue
		if lane_index != 1 and lane_index != 2:
			continue
		if not vehicle_needs_lane_change(owner, entity, lane_index):
			continue

		var overtake_chance: float = owner.npc_overtake_chance_per_second
		if lane_index == 2:
			overtake_chance *= owner.bottom_lane_lane_change_chance_x

		if owner.rng.randf() > overtake_chance * delta:
			slow_vehicle_for_front_car(owner, entity, lane_index)
			continue

		var started_overtake := false
		for target_lane in VehicleBehaviors.overtake_lane_order(lane_index):
			if try_warn_overtake_lane_change(owner, entity, target_lane):
				started_overtake = true
				break
		if not started_overtake:
			slow_vehicle_for_front_car(owner, entity, lane_index)


static func vehicle_needs_lane_change(owner, vehicle: Dictionary, lane_index: int) -> bool:
	return VehicleBehaviors.vehicle_needs_lane_change(
		vehicle,
		lane_index,
		TrafficEntities.active_collision_entities(owner, vehicle, lane_index),
		owner.npc_collision_lookahead,
		owner.npc_follow_gap,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)


static func try_warn_overtake_lane_change(owner, entity: Dictionary, target_lane: int) -> bool:
	if not LaneNavigation.lane_change_allowed(entity, target_lane):
		return false
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not LaneNavigation.target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
		return false

	entity["pending_overtake_speed_boost"] = true
	set_overtake_target(owner, entity, int(entity.get("lane", target_lane)))
	set_top_lane_overtake_return(entity, target_lane)
	start_lane_change_warning(owner, entity, target_lane)
	return true


static func try_warn_vehicle_lane_change(owner, entity: Dictionary, target_lane: int) -> bool:
	if not LaneNavigation.lane_change_allowed(entity, target_lane):
		return false
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not LaneNavigation.target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
		return false

	set_top_lane_overtake_return(entity, target_lane)
	start_lane_change_warning(owner, entity, target_lane)
	return true


static func boost_vehicle_for_overtake(owner, entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) == 0 and entity.has("overtake_return_lane"):
		boost_vehicle_for_top_lane_overtake(owner, entity)
		return

	VehicleBehaviors.boost_for_overtake(entity, owner.npc_overtake_speed_boost, owner.npc_overtake_speed_boost_seconds)


static func boost_vehicle_for_top_lane_overtake(owner, entity: Dictionary) -> void:
	var current_speed := float(entity.get("world_speed", 0.0))
	var max_speed := float(entity.get("max_world_speed", current_speed))
	var boosted_speed: float = maxf(
		maxf(current_speed, max_speed) + owner.top_lane_overtake_speed_boost,
		owner.player_speed + owner.top_lane_overtake_speed_boost
	)
	entity["overtake_target_speed"] = boosted_speed
	entity["overtake_speed_timer"] = owner.top_lane_overtake_speed_boost_seconds
	entity["desired_world_speed"] = boosted_speed
	entity["world_speed"] = maxf(current_speed, boosted_speed)


static func set_overtake_target(owner, entity: Dictionary, lane_index: int) -> void:
	var target: Dictionary = find_front_collision_entity(owner, entity, lane_index)
	if target.is_empty():
		entity.erase("overtake_target_sprite")
		return
	entity["overtake_target_sprite"] = target["sprite"]


static func set_top_lane_overtake_return(entity: Dictionary, target_lane: int) -> void:
	if target_lane != 0:
		return

	var current_lane := int(entity.get("lane", -1))
	if current_lane != 1:
		return
	if not TrafficEntities.entity_moves_with_player(entity, current_lane):
		return

	entity["overtake_return_lane"] = current_lane
	entity["top_lane_overtake_return_ready"] = false


static func find_front_collision_entity(owner, entity: Dictionary, lane_index: int) -> Dictionary:
	var vehicle_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var vehicle_speed := float(entity.get("world_speed", 0.0))
	var vehicle_moves_with_player := TrafficEntities.entity_moves_with_player(entity, lane_index)
	var nearest_gap := INF
	var nearest_entity: Dictionary = {}
	for other_entity in TrafficIndex.in_lane(owner, lane_index):
		if not TrafficEntities.is_entity_sprite_valid(other_entity):
			continue
		if TrafficEntities.entity_collision_disabled(other_entity):
			continue
		if TrafficEntities.same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != lane_index:
			continue

		var other_rect: Rect2 = VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if not VehicleBehaviors.rect_is_ahead(vehicle_rect, other_rect, vehicle_moves_with_player):
			continue

		var other_speed := float(other_entity.get("world_speed", 0.0))
		var gap := VehicleBehaviors.front_gap(vehicle_rect, other_rect, vehicle_moves_with_player)
		var closing_speed := VehicleBehaviors.closing_speed_between(entity, other_entity, lane_index, vehicle_speed, other_speed)
		var predicted_close_distance: float = closing_speed * owner.npc_collision_lookahead
		if gap < nearest_gap and (gap <= owner.npc_follow_gap or gap <= predicted_close_distance):
			nearest_gap = gap
			nearest_entity = other_entity
	return nearest_entity


static func update_overtake_completion(owner, entity: Dictionary) -> void:
	if not entity.has("overtake_target_sprite"):
		return
	if not TrafficEntities.is_entity_sprite_valid(entity):
		TrafficEntities.clear_overtake_state(entity)
		return

	var target_sprite = entity.get("overtake_target_sprite")
	if target_sprite == null or not is_instance_valid(target_sprite):
		TrafficEntities.finish_top_lane_overtake_or_clear(entity)
		return
	if not target_sprite is Sprite2D:
		TrafficEntities.finish_top_lane_overtake_or_clear(entity)
		return

	var target_sprite_node: Sprite2D = target_sprite
	var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var target_rect: Rect2 = VehicleGeometry.collision_rect(target_sprite_node, owner.VEHICLE_HITBOX_INSET, owner)
	var entity_rear_x := entity_rect.position.x
	var target_front_x := target_rect.position.x + target_rect.size.x
	if entity_rear_x > target_front_x + OVERTAKE_PASS_BUFFER_X:
		TrafficEntities.finish_top_lane_overtake_or_clear(entity)


static func update_top_lane_overtake_returns(owner) -> void:
	for entity in owner.active_entities:
		if not TrafficEntities.is_entity_sprite_valid(entity):
			continue
		if entity.get("kind", "traffic") != "traffic":
			continue
		if int(entity.get("lane", -1)) != 0:
			continue
		if not bool(entity.get("top_lane_overtake_return_ready", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			maintain_top_lane_overtake_boost(owner, entity)
			continue

		var return_lane := int(entity.get("overtake_return_lane", 1))
		if return_lane < 1 or return_lane > 2:
			TrafficEntities.clear_top_lane_overtake_return(entity)
			continue
		if not LaneNavigation.lane_change_allowed(entity, return_lane):
			maintain_top_lane_overtake_boost(owner, entity)
			continue
		if not LaneNavigation.target_lane_is_safe_for_entity(owner, entity, return_lane, owner.speeder_safe_gap):
			maintain_top_lane_overtake_boost(owner, entity)
			continue

		entity["returning_from_top_lane_overtake"] = true
		maintain_top_lane_overtake_boost(owner, entity)
		start_lane_change_warning(owner, entity, return_lane)


static func maintain_top_lane_overtake_boost(owner, entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) != 0:
		return
	if not entity.has("overtake_return_lane"):
		return

	var target_speed: float = maxf(
		float(entity.get("overtake_target_speed", 0.0)),
		owner.player_speed + owner.top_lane_overtake_speed_boost
	)
	entity["overtake_target_speed"] = target_speed
	entity["overtake_speed_timer"] = maxf(
		float(entity.get("overtake_speed_timer", 0.0)),
		owner.top_lane_overtake_speed_boost_seconds * 0.5
	)
	entity["desired_world_speed"] = maxf(float(entity.get("desired_world_speed", 0.0)), target_speed)
	entity["world_speed"] = maxf(float(entity.get("world_speed", 0.0)), target_speed)


static func apply_forward_collision_detection(owner, entity: Dictionary) -> void:
	if float(entity.get("world_speed", 0.0)) <= 0.0:
		return
	if bool(entity.get("top_lane_evasive_offset_active", false)):
		maintain_top_lane_evasive_speed(owner, entity)
		return
	slow_vehicle_for_front_car(owner, entity, int(entity.get("lane", -1)))


static func maintain_top_lane_evasive_speed(owner, entity: Dictionary) -> void:
	if entity.get("kind", "traffic") == "traffic" and entity.has("overtake_return_lane"):
		maintain_top_lane_overtake_boost(owner, entity)


static func slow_vehicle_for_front_car(owner, entity: Dictionary, lane_index: int) -> void:
	var front_speed := VehicleBehaviors.front_vehicle_collision_speed(
		entity,
		lane_index,
		TrafficEntities.active_collision_entities(owner, entity, lane_index),
		owner.npc_follow_gap,
		owner.npc_collision_lookahead,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)
	if front_speed >= 0.0:
		TrafficEntities.limit_entity_speed(entity, front_speed)


static func speeder_needs_lane_change(owner, speeder: Dictionary, lane_index: int) -> bool:
	return VehicleBehaviors.speeder_needs_lane_change(
		speeder,
		lane_index,
		TrafficEntities.active_collision_entities(owner, speeder, lane_index),
		owner.speeder_vehicle_max_speed,
		owner.speeder_safe_gap,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)


static func try_set_speeder_target_lane(owner, entity: Dictionary, target_lane: int) -> bool:
	if not LaneNavigation.lane_change_allowed(entity, target_lane):
		return false
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if speeder_lane_change_warning_belongs_to_other(owner, entity):
		return false
	if not LaneNavigation.speeder_target_lane_is_safe(owner, entity, target_lane):
		return false

	if target_lane == owner.player_lane:
		TrafficSignals.start_speeder_lane_change_warning(owner, entity["sprite"], target_lane)
		return true

	var previous_lane := int(entity.get("lane", target_lane))
	entity["lane"] = target_lane
	TrafficIndex.invalidate(owner)
	entity["target_lane"] = target_lane
	entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, target_lane, 2)
	TrafficEntities.mark_recent_lane_change(owner, entity, previous_lane)
	return true


static func speeder_lane_change_warning_belongs_to_other(owner, entity: Dictionary) -> bool:
	if not owner.speeder_lane_change_warning_active:
		return false
	if not is_instance_valid(owner.pending_speeder_lane_change_sprite):
		TrafficSignals.clear_speeder_lane_change_warning(owner)
		return false
	if not TrafficEntities.is_entity_sprite_valid(entity):
		return false
	return owner.pending_speeder_lane_change_sprite != entity["sprite"]


static func slow_speeder_near_player(owner, entity: Dictionary) -> void:
	if owner.player == null or not is_instance_valid(owner.player):
		return
	if int(entity.get("lane", -1)) != owner.player_lane:
		return

	var speeder_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var speeder_is_behind_player := speeder_rect.get_center().x < player_rect.get_center().x
	var center_gap := absf(speeder_rect.get_center().x - player_rect.get_center().x)
	if speeder_is_behind_player and center_gap < owner.SPEEDER_PLAYER_LANE_CHANGE_BUFFER:
		TrafficEntities.limit_entity_speed(entity, owner.player_speed)
