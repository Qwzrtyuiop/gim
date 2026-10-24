extends RefCounted

# Traffic update and entity lifetime coordinator. Domain helpers own maneuver and spacing rules.
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const VehicleBehaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const VehicleSpawner := preload("res://scripts/game/vehicle_spawner.gd")
const VehicleWheelAnimation := preload("res://scripts/game/vehicle_wheel_animation.gd")
const SAME_DIRECTION_BEHIND_DESPAWN_X := -960.0
const INCOMING_BEHIND_DESPAWN_X := -260.0
const FRONT_DESPAWN_EXTRA_X := 520.0
const TrafficEntities := preload("res://scripts/game/vehicle_traffic_entities.gd")
const TrafficSignals := preload("res://scripts/game/vehicle_traffic_signals.gd")
const LaneNavigation := preload("res://scripts/game/vehicle_lane_navigation.gd")
const TrafficSpacing := preload("res://scripts/game/vehicle_traffic_spacing.gd")
const TrafficManeuvers := preload("res://scripts/game/vehicle_traffic_maneuvers.gd")


static func update_speeder_warning(owner, delta: float) -> void:
	prune_invalid_entities(owner)
	if owner.speeder_warning_label:
		owner.speeder_warning_label.visible = owner.speeder_warning_flash_timer > 0.0
		owner.speeder_warning_flash_timer = maxf(0.0, owner.speeder_warning_flash_timer - delta)

	if not owner.speeder_enabled:
		return

	if owner.speeder_warning_active:
		owner.speeder_warning_timer -= delta
		if owner.speeder_warning_timer <= 0.0:
			if owner.speeder_warning_beeps_remaining > 0:
				TrafficSignals.pulse_speeder_warning(owner)
				owner.speeder_warning_beeps_remaining -= 1
				owner.speeder_warning_timer = 0.28
			else:
				owner.speeder_warning_active = false
				if owner.speeder_warning_label:
					owner.speeder_warning_label.visible = false
				VehicleSpawner.spawn_speeder(owner)
				TrafficSignals.reset_speeder_timer(owner)
		return

	owner.speeder_spawn_timer -= delta
	if owner.speeder_spawn_timer <= 0.0:
		owner.speeder_warning_active = true
		owner.speeder_warning_beeps_remaining = 3
		owner.speeder_warning_timer = 0.0


static func update_entities(owner, delta: float) -> void:
	prune_invalid_entities(owner)
	remove_invalid_top_lane_direction_entities(owner)
	TrafficSpacing.relieve_player_pin_pressure(owner)
	LaneNavigation.update_top_lane_evasive_offsets(owner)
	for entity in owner.active_entities:
		TrafficEntities.update_lane_change_fault_grace(entity, delta)
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var world_speed: float = entity["world_speed"]
		var movement_side := BusyTrafficBehavior.LEFT_SPAWN_SIDE if TrafficEntities.entity_moves_with_player(entity, lane_index) else BusyTrafficBehavior.RIGHT_SPAWN_SIDE
		var screen_velocity := VehicleBehaviors.screen_velocity_for_spawn_side(
			lane_index,
			str(entity.get("kind", "traffic")),
			movement_side,
			world_speed,
			owner.player_speed
		)

		sprite.position.x += screen_velocity * delta
		update_speeder_bob(entity, delta)
		LaneNavigation.update_entity_lane_position(owner, entity, delta)

	TrafficSpacing.resolve_vehicle_overlaps(owner)
	for entity in owner.active_entities:
		var road_speed := 0.0 if bool(entity.get("is_parked", false)) else float(entity["world_speed"])
		var direction := 1.0 if TrafficEntities.entity_moves_with_player(entity, int(entity["lane"])) else -1.0
		VehicleWheelAnimation.update(entity["sprite"], road_speed * direction, delta)

	var dead_entities := []
	for entity in owner.active_entities:
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var left_despawn_x := SAME_DIRECTION_BEHIND_DESPAWN_X if TrafficEntities.entity_moves_with_player(entity, lane_index) else INCOMING_BEHIND_DESPAWN_X
		if sprite.position.x < left_despawn_x or sprite.position.x > owner.get_viewport_rect().size.x + FRONT_DESPAWN_EXTRA_X:
			dead_entities.append(entity)

	for entity in dead_entities:
		remove_entity(owner, entity)


static func prune_invalid_entities(owner) -> void:
	if owner.speeder_lane_change_warning_active and not is_instance_valid(owner.pending_speeder_lane_change_sprite):
		TrafficSignals.clear_speeder_lane_change_warning(owner)

	var invalid_entities: Array = []
	for entity in owner.active_entities:
		if not TrafficEntities.is_entity_sprite_valid(entity):
			invalid_entities.append(entity)
			continue

		var target_sprite = entity.get("overtake_target_sprite")
		if target_sprite != null and not is_instance_valid(target_sprite):
			TrafficEntities.finish_top_lane_overtake_or_clear(entity)

	for entity in invalid_entities:
		remove_entity(owner, entity)


static func remove_invalid_top_lane_direction_entities(owner) -> void:
	var invalid_entities: Array = []
	for entity in owner.active_entities:
		if not TrafficEntities.is_entity_sprite_valid(entity):
			continue
		if entity.get("kind", "traffic") == "speeder":
			continue
		if int(entity.get("lane", -1)) != 0:
			continue
		if TrafficEntities.entity_moves_with_player(entity, 0):
			if not entity.has("overtake_return_lane"):
				invalid_entities.append(entity)

	for entity in invalid_entities:
		remove_entity(owner, entity)


static func remove_entity(owner, entity: Dictionary) -> void:
	TrafficIndex.invalidate(owner)
	var sprite = entity.get("sprite")
	var removed := false
	for index in range(owner.active_entities.size() - 1, -1, -1):
		var active_entity: Dictionary = owner.active_entities[index]
		if sprite != null and is_instance_valid(sprite):
			if TrafficEntities.is_entity_sprite_valid(active_entity) and active_entity.get("sprite") == sprite:
				owner.active_entities.remove_at(index)
				removed = true
				break
		elif not TrafficEntities.is_entity_sprite_valid(active_entity):
			owner.active_entities.remove_at(index)
			removed = true
			break

	if not removed:
		return

	clear_removed_sprite_references(owner, sprite)
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()


static func clear_removed_sprite_references(owner, sprite) -> void:
	if sprite == null:
		return
	if is_instance_valid(owner.pending_speeder_lane_change_sprite) and owner.pending_speeder_lane_change_sprite == sprite:
		TrafficSignals.clear_speeder_lane_change_warning(owner)

	for entity in owner.active_entities:
		var target_sprite = entity.get("overtake_target_sprite")
		if target_sprite == null:
			continue
		if not is_instance_valid(target_sprite):
			TrafficEntities.finish_top_lane_overtake_or_clear(entity)
			continue
		if target_sprite == sprite:
			TrafficEntities.finish_top_lane_overtake_or_clear(entity)


static func update_speeder_bob(entity: Dictionary, delta: float) -> void:
	if entity.get("kind", "traffic") != "speeder":
		return
	var sprite: Sprite2D = entity["sprite"]
	# Apply only the offset difference so oscillation never accumulates as travel.
	var previous_offset := float(entity.get("bob_x_offset", 0.0))
	var phase := fposmod(float(entity.get("bob_phase", 0.0)) + delta * TAU * GameTuning.SPEEDER_BOB_CYCLES_PER_SECOND, TAU)
	var offset := sin(phase) * GameTuning.SPEEDER_BOB_X_PIXELS
	sprite.position.x += offset - previous_offset
	entity["bob_phase"] = phase
	entity["bob_x_offset"] = offset


# Compatibility entry points used by the gameplay coordinator and other traffic systems.


static func reset_speeder_timer(owner) -> void:
	TrafficSignals.reset_speeder_timer(owner)


static func update_speeder_lane_change_warning(owner, delta: float) -> void:
	TrafficManeuvers.update_speeder_lane_change_warning(owner, delta)


static func update_lane_change_warnings(owner, delta: float) -> void:
	TrafficManeuvers.update_lane_change_warnings(owner, delta)


static func update_random_lane_changes(owner, delta: float) -> void:
	TrafficManeuvers.update_random_lane_changes(owner, delta)


static func update_vehicle_speeds(owner, delta: float) -> void:
	TrafficManeuvers.update_vehicle_speeds(owner, delta)


static func update_vehicle_overtake_ai(owner, delta: float) -> void:
	TrafficManeuvers.update_vehicle_overtake_ai(owner, delta)


static func update_busy_vehicle_ai(owner, delta: float) -> void:
	TrafficManeuvers.update_busy_vehicle_ai(owner, delta)


static func update_speeder_ai(owner) -> void:
	TrafficManeuvers.update_speeder_ai(owner)


static func update_npc_following(owner) -> void:
	TrafficSpacing.update_npc_following(owner)


static func update_overtake_speed_boosts(owner, delta: float) -> void:
	TrafficManeuvers.update_overtake_speed_boosts(owner, delta)


static func clear_oncoming_warning(owner) -> void:
	TrafficSignals.clear_oncoming_warning(owner)


static func clear_speeder_lane_change_warning(owner) -> void:
	TrafficSignals.clear_speeder_lane_change_warning(owner)


static func entity_collision_disabled(entity: Dictionary) -> bool:
	return TrafficEntities.entity_collision_disabled(entity)


static func lane_change_fault_is_active(entity: Dictionary) -> bool:
	return TrafficEntities.lane_change_fault_is_active(entity)


static func deflect_lane_change_fault(owner, entity: Dictionary) -> void:
	TrafficSpacing.deflect_lane_change_fault(owner, entity)


static func entity_moves_with_player(entity: Dictionary, lane_index: int) -> bool:
	return TrafficEntities.entity_moves_with_player(entity, lane_index)


static func update_oncoming_warning(owner, delta: float) -> bool:
	return TrafficSignals.update_oncoming_warning(owner, delta)


static func find_front_collision_entity(owner, entity: Dictionary, lane_index: int) -> Dictionary:
	return TrafficManeuvers.find_front_collision_entity(owner, entity, lane_index)
