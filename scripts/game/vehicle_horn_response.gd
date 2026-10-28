extends RefCounted

# Per-car patience and reactions. This runs before following/collision safety.
const Tuning := preload("res://scripts/config/game_tuning.gd")
const Entities := preload("res://scripts/game/vehicle_traffic_entities.gd")
const Geometry := preload("res://scripts/game/vehicle_geometry.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const TrafficSignals := preload("res://scripts/game/vehicle_traffic_signals.gd")


static func truck_wave(owner, origin: Vector2, radius: float) -> void:
	if owner.game_state != "playing" or not is_instance_valid(owner.player):
		return
	var viewport: Rect2 = owner.get_viewport_rect()
	var affected := false
	for entity: Dictionary in owner.active_entities:
		if not Entities.is_entity_sprite_valid(entity) or bool(entity.get("truck_horn_yielding", false)):
			continue
		var sprite: Sprite2D = entity.sprite
		var visible_bounds := sprite.get_transform() * sprite.get_rect()
		if not viewport.intersects(visible_bounds):
			continue
		var bounds := Geometry.collision_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner)
		var nearest_point := Vector2(
			clampf(origin.x, bounds.position.x, bounds.end.x),
			clampf(origin.y, bounds.position.y, bounds.end.y)
		)
		if origin.distance_squared_to(nearest_point) > radius * radius:
			continue
		_truck_yield(owner, entity)
		affected = true
	if affected:
		TrafficIndex.invalidate(owner)


static func _truck_yield(owner, entity: Dictionary) -> void:
	var sprite: Sprite2D = entity.sprite
	var pullover_lane := 0 if int(entity.get("lane", -1)) == 0 else 2
	if is_instance_valid(owner.pending_speeder_lane_change_sprite) and owner.pending_speeder_lane_change_sprite == sprite:
		TrafficSignals.clear_speeder_lane_change_warning(owner)
	Entities.cancel_entity_lane_change_warning(entity)
	Entities.clear_overtake_state(entity)
	entity.erase("lane_change_previous_lane")
	entity.erase("lane_change_fault_grace_timer")
	entity["truck_horn_yielding"] = true
	entity["horn_yielding"] = true
	# Contact is disabled only after the expanding wave reaches this car.
	entity["horn_yield_clear"] = true
	entity["is_parked"] = true
	entity["lane"] = pullover_lane
	entity["target_lane"] = pullover_lane
	entity["kind"] = "traffic"
	# Parked top-lane cars must retain a valid incoming-lane direction.
	entity["moves_with_player"] = pullover_lane != 0
	entity["world_speed"] = 0.0
	entity["desired_world_speed"] = 0.0
	entity["horn_speed_timer"] = 0.0
	entity["speeder_bob_offset"] = 0.0


static func press(owner) -> void:
	if owner.game_state != "playing" or owner.player_lane != 2 or not is_instance_valid(owner.player):
		return
	var entity := nearest_driver(owner)
	if entity.is_empty() or entity.has("horn_response"):
		return
	if not entity.has("horn_required_presses"):
		entity["horn_required_presses"] = owner.rng.randi_range(Tuning.HORN_MIN_PRESSES, Tuning.HORN_MAX_PRESSES)
	entity["horn_press_count"] = int(entity.get("horn_press_count", 0)) + 1
	entity["horn_repeat_timer"] = Tuning.HORN_REPEAT_WINDOW
	if int(entity.horn_press_count) < int(entity.horn_required_presses):
		return
	var roll: float = owner.rng.randf()
	if roll < Tuning.HORN_IGNORE_CHANCE:
		entity["horn_response"] = "ignore"
	elif roll < Tuning.HORN_IGNORE_CHANCE + Tuning.HORN_SPEED_CHANCE or not shoulder_is_clear(owner, entity):
		entity["horn_response"] = "speed"
		entity["horn_speed_timer"] = Tuning.HORN_SPEED_SECONDS
		entity["horn_target_speed"] = minf(Tuning.HORN_MAX_RESPONSE_SPEED,
			maxf(float(entity.get("max_world_speed", 0.0)), float(entity.world_speed)) + Tuning.HORN_SPEED_BOOST)
	else:
		entity["horn_response"] = "yield"
		Entities.cancel_entity_lane_change_warning(entity)
		Entities.clear_overtake_state(entity)
		entity.erase("lane_change_previous_lane")
		entity.erase("lane_change_fault_grace_timer")
		entity["horn_yielding"] = true
		entity["target_lane"] = 2
		# Stop before moving down, so the car cannot coast through a parked car.
		entity["world_speed"] = 0.0
		entity["desired_world_speed"] = 0.0


static func nearest_driver(owner) -> Dictionary:
	var player_rect := Geometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var nearest: Dictionary = {}
	var nearest_gap := INF
	for entity: Dictionary in owner.active_entities:
		if not eligible_driver(owner, entity):
			continue
		var rect := Geometry.collision_rect(entity.sprite, owner.VEHICLE_HITBOX_INSET, owner)
		if rect.get_center().x <= player_rect.get_center().x:
			continue
		var gap := maxf(0.0, rect.position.x - player_rect.end.x)
		if gap <= Tuning.HORN_RANGE and gap < nearest_gap:
			nearest = entity
			nearest_gap = gap
	return nearest


static func eligible_driver(owner, entity: Dictionary) -> bool:
	if not Entities.is_entity_sprite_valid(entity):
		return false
	if str(entity.get("kind", "traffic")) != "traffic" or int(entity.get("lane", -1)) != 2:
		return false
	if bool(entity.get("is_parked", false)) or bool(entity.get("horn_yielding", false)) or not Entities.entity_moves_with_player(entity, 2):
		return false
	if int(entity.get("target_lane", 2)) != 2 or Entities._is_overtaking_or_lane_changing(entity) or entity.has("overtake_target_sprite"):
		return false
	var guide := Geometry.entity_lane_y(owner, 2, owner.get_viewport_rect().size, false)
	var rect := Geometry.collision_rect(entity.sprite, owner.VEHICLE_HITBOX_INSET, owner)
	return absf(rect.end.y - guide) <= Tuning.HORN_YIELD_CLEAR_DISTANCE


static func shoulder_is_clear(owner, entity: Dictionary) -> bool:
	var rect := Geometry.collision_rect(entity.sprite, owner.VEHICLE_HITBOX_INSET, owner)
	# Include the full swept region, including cars already excluded from traffic.
	var destination := rect
	destination.position.y += owner.PARKED_VEHICLE_Y_OFFSET
	var swept := rect.merge(destination).grow(Tuning.HORN_PULL_OVER_GAP)
	for other: Dictionary in owner.active_entities:
		if not Entities.is_entity_sprite_valid(other) or Entities.same_entity_sprite(entity, other):
			continue
		if not bool(other.get("is_parked", false)) and not bool(other.get("horn_yielding", false)):
			continue
		if swept.intersects(Geometry.collision_rect(other.sprite, owner.VEHICLE_HITBOX_INSET, owner)):
			return false
	return true


static func update(owner, delta: float) -> void:
	for entity: Dictionary in owner.active_entities:
		if entity.has("horn_repeat_timer"):
			entity["horn_repeat_timer"] = maxf(0.0, float(entity.horn_repeat_timer) - delta)
			if float(entity.horn_repeat_timer) <= 0.0:
				entity["horn_press_count"] = 0
		if float(entity.get("horn_speed_timer", 0.0)) > 0.0:
			entity["horn_speed_timer"] = maxf(0.0, float(entity.horn_speed_timer) - delta)


static func update_speeds(owner, delta: float) -> void:
	for entity: Dictionary in owner.active_entities:
		if bool(entity.get("horn_yielding", false)):
			entity["world_speed"] = 0.0
			entity["desired_world_speed"] = 0.0
		elif float(entity.get("horn_speed_timer", 0.0)) > 0.0:
			var target := float(entity.get("horn_target_speed", entity.world_speed))
			entity["desired_world_speed"] = target
			entity["world_speed"] = move_toward(float(entity.world_speed), target, owner.vehicle_speed_acceleration * delta)


static func update_yield_clearance(owner, entity: Dictionary) -> void:
	if not bool(entity.get("horn_yielding", false)) or bool(entity.get("horn_yield_clear", false)):
		return
	var guide := Geometry.entity_lane_y(owner, 2, owner.get_viewport_rect().size, true)
	var rect := Geometry.collision_rect(entity.sprite, owner.VEHICLE_HITBOX_INSET, owner)
	if absf(rect.end.y - guide) <= Tuning.HORN_YIELD_CLEAR_DISTANCE:
		entity["horn_yield_clear"] = true
		entity["is_parked"] = true
