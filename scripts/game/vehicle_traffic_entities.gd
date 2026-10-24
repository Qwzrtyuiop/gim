extends RefCounted

# Shared traffic identity, collision eligibility, and maneuver state.
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")


static func finish_top_lane_overtake_or_clear(entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) == 0 and entity.has("overtake_return_lane"):
		entity["pending_overtake_speed_boost"] = false
		entity.erase("overtake_target_sprite")
		entity["top_lane_overtake_return_ready"] = true
	else:
		clear_overtake_state(entity)


static func clear_overtake_state(entity: Dictionary) -> void:
	entity["pending_overtake_speed_boost"] = false
	entity["overtake_speed_timer"] = 0.0
	entity.erase("overtake_target_speed")
	entity.erase("overtake_target_sprite")
	clear_top_lane_overtake_return(entity)


static func clear_top_lane_overtake_return(entity: Dictionary) -> void:
	entity.erase("overtake_return_lane")
	entity.erase("top_lane_overtake_return_ready")
	entity.erase("returning_from_top_lane_overtake")
	entity.erase("top_lane_evasive_offset_active")


static func mark_recent_lane_change(owner, entity: Dictionary, previous_lane: int) -> void:
	entity["lane_change_previous_lane"] = previous_lane
	entity["lane_change_fault_grace_timer"] = owner.npc_lane_change_fault_grace_seconds


static func update_lane_change_fault_grace(entity: Dictionary, delta: float) -> void:
	if not entity.has("lane_change_fault_grace_timer"):
		return

	var grace_timer := maxf(0.0, float(entity.get("lane_change_fault_grace_timer", 0.0)) - delta)
	entity["lane_change_fault_grace_timer"] = grace_timer
	if grace_timer <= 0.0:
		entity.erase("lane_change_fault_grace_timer")
		entity.erase("lane_change_previous_lane")


static func _is_overtaking_or_lane_changing(entity: Dictionary) -> bool:
	return (
		bool(entity.get("lane_change_warning_active", false))
		or bool(entity.get("pending_overtake_speed_boost", false))
		or float(entity.get("overtake_speed_timer", 0.0)) > 0.0
	)


static func is_overtake_speed_exempt(entity: Dictionary) -> bool:
	return (
		entity.get("kind", "traffic") == "speeder"
		or bool(entity.get("pending_overtake_speed_boost", false))
		or float(entity.get("overtake_speed_timer", 0.0)) > 0.0
		or entity.has("overtake_target_sprite")
	)


static func find_entity_by_sprite(owner, sprite) -> Dictionary:
	if sprite == null or not is_instance_valid(sprite):
		return {}

	for entity in owner.active_entities:
		if is_entity_sprite_valid(entity) and entity.get("sprite") == sprite:
			return entity
	return {}


static func is_entity_sprite_valid(entity: Dictionary) -> bool:
	return entity.has("sprite") and entity["sprite"] != null and is_instance_valid(entity["sprite"])


static func same_entity_sprite(a: Dictionary, b: Dictionary) -> bool:
	if not is_entity_sprite_valid(a) or not is_entity_sprite_valid(b):
		return false
	return a.get("sprite") == b.get("sprite")


static func entity_collision_disabled(entity: Dictionary) -> bool:
	return bool(entity.get("top_lane_evasive_offset_active", false))


static func bottom_lane_traffic_can_pass_parked(moving_entity: Dictionary, parked_entity: Dictionary) -> bool:
	return (
		str(moving_entity.get("kind", "traffic")) == "traffic"
		and not bool(moving_entity.get("is_parked", false))
		and int(moving_entity.get("lane", -1)) == 2
		and bool(parked_entity.get("is_parked", false))
		and int(parked_entity.get("lane", -1)) == 2
	)


static func active_collision_entities(owner, include_entity: Dictionary = {}, lane_index: int = -1) -> Array:
	var entities: Array = []
	var candidates: Array = owner.active_entities if lane_index < 0 else TrafficIndex.in_lane(owner, lane_index)
	for entity in candidates:
		if not is_entity_sprite_valid(entity):
			continue
		if not include_entity.is_empty() and same_entity_sprite(entity, include_entity):
			entities.append(entity)
			continue
		if not include_entity.is_empty() and bottom_lane_traffic_can_pass_parked(include_entity, entity):
			continue
		if entity_collision_disabled(entity):
			continue
		entities.append(entity)
	return entities


static func lane_change_fault_is_active(entity: Dictionary) -> bool:
	return (
		bool(entity.get("lane_change_warning_active", false))
		or float(entity.get("lane_change_fault_grace_timer", 0.0)) > 0.0
	)


static func cancel_entity_lane_change_warning(entity: Dictionary) -> void:
	entity["lane_change_warning_active"] = false
	entity["lane_change_warning_pulses_remaining"] = 0
	entity["lane_change_warning_timer"] = 0.0
	entity["pending_overtake_speed_boost"] = false

	if not is_entity_sprite_valid(entity):
		return

	var warning_label := entity["sprite"].get_node_or_null("LaneChangeWarning") as Label
	if warning_label:
		warning_label.visible = false


static func limit_entity_speed(entity: Dictionary, speed: float) -> void:
	entity["world_speed"] = minf(float(entity.get("world_speed", speed)), speed)
	entity["desired_world_speed"] = minf(float(entity.get("desired_world_speed", speed)), speed)


static func entity_moves_with_player(entity: Dictionary, lane_index: int) -> bool:
	if entity.has("moves_with_player"):
		return bool(entity["moves_with_player"])
	if lane_index == 0:
		return BusyTrafficBehavior.is_left_car(entity)
	return true
