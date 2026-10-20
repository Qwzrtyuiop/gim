extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleVisuals := preload("res://scripts/game/vehicle_visuals.gd")
const VehicleWheelAnimation := preload("res://scripts/game/vehicle_wheel_animation.gd")


static func spawn(owner) -> void:
	var viewport_width: float = owner.get_viewport_rect().size.x
	for definition in GameTuning.MENU_TRAFFIC_VEHICLES:
		var lane_index := int(definition["lane"])
		var sprite := Sprite2D.new()
		sprite.texture = owner.VEHICLE_TEXTURES[definition["vehicle"]]
		var perspective := GameTuning.INCOMING_LANE_SCALE if lane_index == 0 else GameTuning.MAIN_LANE_SCALE
		sprite.scale = Vector2.ONE * float(definition["scale"]) * perspective
		sprite.flip_h = lane_index == 0
		var line_name := "TopTraceLine" if lane_index == 0 else "MainTraceLine"
		var line := owner.get_node_or_null("MenuTraceLines/%s" % line_name) as Node2D
		var guide_y: float = line.position.y if line else GameTuning.MENU_TRAFFIC_FALLBACK_LANE_Y[lane_index]
		sprite.position = Vector2(
			viewport_width * float(definition["x_ratio"]),
			VehicleGeometry.sprite_y_for_hitbox_bottom(sprite, guide_y, GameTuning.MENU_TRAFFIC_HITBOX_INSET, owner)
		)
		sprite.z_index = VehicleGeometry.z_for_lane(owner, lane_index)
		VehicleVisuals.apply_shadow(owner, sprite, GameTuning.MENU_TRAFFIC_HITBOX_INSET)
		VehicleWheelAnimation.attach(sprite, str(definition["vehicle"]))
		owner.traffic_layer.add_child(sprite)
		var speed := maxf(0.0, float(definition["speed"]))
		owner.menu_vehicles.append({
			"sprite": sprite,
			"lane": lane_index,
			"cruise_speed": speed,
			"world_speed": speed,
		})
	# Also separate initial placements if sizes or starting positions were edited.
	update(owner, 0.0)


static func update(owner, delta: float) -> void:
	var gap := maxf(0.0, GameTuning.MENU_TRAFFIC_GAP_PIXELS)
	var viewport_width: float = owner.get_viewport_rect().size.x
	for lane_index in range(2):
		var lane_vehicles: Array = []
		for vehicle in owner.menu_vehicles:
			if int(vehicle["lane"]) == lane_index:
				lane_vehicles.append(vehicle)
		# Advance the leader first and cap each follower at its new bumper position.
		# Sorting before movement prevents a fast car tunnelling past its leader.
		var moves_right := lane_index == 1
		lane_vehicles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["sprite"].position.x > b["sprite"].position.x if moves_right else a["sprite"].position.x < b["sprite"].position.x
		)
		var front_rect := Rect2()
		var has_front := false
		for vehicle in lane_vehicles:
			var sprite: Sprite2D = vehicle["sprite"]
			var before_x := sprite.position.x
			var direction := 1.0 if moves_right else -1.0
			sprite.position.x += direction * float(vehicle["cruise_speed"]) * delta
			var rect := bumper_rect(owner, sprite)
			if has_front:
				if moves_right:
					sprite.position.x -= maxf(0.0, rect.end.x + gap - front_rect.position.x)
				else:
					sprite.position.x += maxf(0.0, front_rect.end.x + gap - rect.position.x)
			vehicle["world_speed"] = maxf(0.0, (sprite.position.x - before_x) * direction / delta) if delta > 0.0 else float(vehicle["cruise_speed"])
			VehicleWheelAnimation.update(sprite, float(vehicle["world_speed"]) * direction, delta)
			front_rect = bumper_rect(owner, sprite)
			has_front = true

		# Recycle only once the whole car has left, then queue behind every car
		# in its lane. This also handles multiple cars exiting on the same frame.
		for vehicle in lane_vehicles:
			var sprite: Sprite2D = vehicle["sprite"]
			var rect := bumper_rect(owner, sprite)
			if (moves_right and rect.position.x > viewport_width) or (not moves_right and rect.end.x < 0.0):
				wrap_vehicle(owner, vehicle, lane_vehicles, viewport_width, gap)


static func bumper_rect(owner, sprite: Sprite2D) -> Rect2:
	# Full visible width keeps the artwork apart; use traffic-layer coordinates.
	var local_rect := VehicleGeometry.local_hitbox_rect(sprite, Vector4.ZERO, owner)
	return VehicleGeometry.collision_rect_for_transform(sprite, sprite.position, sprite.scale, local_rect)


static func wrap_vehicle(owner, vehicle: Dictionary, lane_vehicles: Array, viewport_width: float, gap: float) -> void:
	var sprite: Sprite2D = vehicle["sprite"]
	var moves_right := int(vehicle["lane"]) == 1
	var min_offset := maxf(0.0, GameTuning.MENU_TRAFFIC_WRAP_MIN_PIXELS)
	var max_offset := maxf(min_offset, GameTuning.MENU_TRAFFIC_WRAP_MAX_PIXELS)
	var offset: float = owner.rng.randf_range(min_offset, max_offset)
	var entry_edge := -offset if moves_right else viewport_width + offset
	for other in lane_vehicles:
		if other["sprite"] == sprite:
			continue
		var other_rect := bumper_rect(owner, other["sprite"])
		if moves_right:
			entry_edge = minf(entry_edge, other_rect.position.x - gap)
		else:
			entry_edge = maxf(entry_edge, other_rect.end.x + gap)
	var rect := bumper_rect(owner, sprite)
	sprite.position.x += entry_edge - (rect.end.x if moves_right else rect.position.x)
	vehicle["world_speed"] = vehicle["cruise_speed"]
