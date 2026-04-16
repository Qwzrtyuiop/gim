extends RefCounted

const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")


static func apply_shadow(owner, sprite: Sprite2D, inset: Vector4) -> void:
	var shadow := sprite.get_node_or_null("Shadow") as Polygon2D
	if shadow == null:
		shadow = Polygon2D.new()
		shadow.name = "Shadow"
		shadow.z_index = -1
		shadow.color = Color(0.0, 0.0, 0.0, 0.34)
		sprite.add_child(shadow)

	var local_rect: Rect2 = VehicleGeometry.local_hitbox_rect(sprite, inset, owner)
	var shadow_width := local_rect.size.x * 0.92
	var shadow_height := maxf(20.0, local_rect.size.y * 0.20)
	var center_x := local_rect.position.x + local_rect.size.x * 0.5
	var center_y := local_rect.position.y + local_rect.size.y - shadow_height * 0.28
	var half_width := shadow_width * 0.5
	var half_height := shadow_height * 0.5

	shadow.polygon = PackedVector2Array([
		Vector2(center_x - half_width, center_y),
		Vector2(center_x - half_width * 0.72, center_y - half_height),
		Vector2(center_x, center_y - half_height * 0.86),
		Vector2(center_x + half_width * 0.72, center_y - half_height),
		Vector2(center_x + half_width, center_y),
		Vector2(center_x + half_width * 0.72, center_y + half_height),
		Vector2(center_x, center_y + half_height * 0.86),
		Vector2(center_x - half_width * 0.72, center_y + half_height),
	])


static func apply_headlight(owner, sprite: Sprite2D, inset: Vector4) -> void:
	var cone_node := sprite.get_node_or_null("HeadlightCone")
	var cone: Sprite2D
	if cone_node != null and is_instance_valid(cone_node) and cone_node is Sprite2D:
		cone = cone_node
	if cone == null:
		cone = Sprite2D.new()
		cone.name = "HeadlightCone"
		cone.texture = owner.headlight_cone_texture
		cone.centered = false
		cone.z_as_relative = false
		cone.z_index = owner.HEADLIGHT_Z_INDEX
		var headlight_material := CanvasItemMaterial.new()
		headlight_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		cone.material = headlight_material
		sprite.add_child(cone)

	if owner.headlight_cone_texture == null:
		return

	var alpha: float = _current_headlight_alpha(owner)
	cone.visible = owner.stage_time_of_day == "night" and alpha > 0.0 and owner.game_state != "CRASH" and owner.game_state != "TIME OUT" and owner.game_state != "GAME OVER"
	if not cone.visible:
		return

	var local_rect: Rect2 = VehicleGeometry.local_hitbox_rect(sprite, inset, owner)
	var cone_width: float = maxf(74.0, local_rect.size.x * owner.headlight_cone_length_x)
	var cone_height: float = maxf(26.0, local_rect.size.y * owner.headlight_cone_height_x)
	var scale_x: float = cone_width / owner.headlight_cone_texture.get_width()
	var scale_y: float = cone_height / owner.headlight_cone_texture.get_height()
	var front_x: float = local_rect.position.x + local_rect.size.x if not sprite.flip_h else local_rect.position.x
	var cone_y: float = local_rect.position.y + local_rect.size.y * 0.46 - cone_height * 0.5

	cone.modulate = Color(1.0, 0.96, 0.82, alpha)
	cone.position = Vector2(front_x, cone_y)
	cone.scale = Vector2(scale_x if not sprite.flip_h else -scale_x, scale_y)


static func _current_headlight_alpha(owner) -> float:
	match owner.stage_time_of_day:
		"noon":
			return owner.noon_headlight_alpha
		"night":
			return owner.night_headlight_alpha
	return owner.morning_headlight_alpha
