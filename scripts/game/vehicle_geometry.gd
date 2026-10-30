extends RefCounted

const VEHICLE_REFERENCE_PATHS := {
	"player_tricycle": "EditorPreview/VehicleScaleReferences/PlayerTricycleReference",
	"beetle": "EditorPreview/VehicleScaleReferences/BeetleReference",
	"blue_truck": "EditorPreview/VehicleScaleReferences/BlueTruckReference",
	"bus": "EditorPreview/VehicleScaleReferences/BusReference",
	"cargotruck": "EditorPreview/VehicleScaleReferences/CargoTruckReference",
	"gray_sedan": "EditorPreview/VehicleScaleReferences/GraySedanReference",
	"jeepney": "EditorPreview/VehicleScaleReferences/JeepneyReference",
	"motorcycle": "EditorPreview/VehicleScaleReferences/MotorcycleReference",
	"parkedmoped": "EditorPreview/VehicleScaleReferences/ParkedMopedReference",
	"parkedtruck": "EditorPreview/VehicleScaleReferences/ParkedTruckReference",
	"sedan": "EditorPreview/VehicleScaleReferences/SedanReference",
	"truck": "EditorPreview/VehicleScaleReferences/TruckReference",
	"van": "EditorPreview/VehicleScaleReferences/VanReference",
	"vendor_tricycle": "EditorPreview/VehicleScaleReferences/VendorTricycleReference",
}


static func collision_rect(sprite: Sprite2D, inset: Vector4, owner) -> Rect2:
	# Cache by geometry inputs, not merely frame: overlap resolution can move a
	# vehicle several times in the same frame, and lane changes alter its scale.
	var cache: Dictionary = sprite.get_meta(&"collision_rect_cache", {})
	var signature: Array = [sprite.texture, sprite.texture.get_size(), sprite.flip_h, sprite.flip_v, sprite.global_position, sprite.scale]
	var entry: Dictionary = cache.get(inset, {})
	if entry.get("signature", []) == signature:
		return entry.rect
	var local_rect: Rect2 = local_hitbox_rect(sprite, inset, owner)
	var rect := collision_rect_for_transform(sprite, sprite.global_position, sprite.scale, local_rect)
	cache[inset] = {"signature": signature, "rect": rect}
	sprite.set_meta(&"collision_rect_cache", cache)
	return rect


static func collision_rect_for_transform(_sprite: Sprite2D, global_position: Vector2, scale: Vector2, local_rect: Rect2) -> Rect2:
	var scaled_position := Vector2(
		local_rect.position.x * scale.x,
		local_rect.position.y * scale.y
	)
	var scaled_size := Vector2(
		local_rect.size.x * absf(scale.x),
		local_rect.size.y * absf(scale.y)
	)
	return Rect2(global_position + scaled_position, scaled_size)


static func sprite_y_for_hitbox_bottom(sprite: Sprite2D, guide_y: float, inset: Vector4, owner) -> float:
	var local_rect: Rect2 = local_hitbox_rect(sprite, inset, owner)
	return sprite_y_for_hitbox_bottom_with_scale(local_rect, guide_y, sprite.scale)


static func sprite_y_for_hitbox_bottom_with_scale(local_rect: Rect2, guide_y: float, scale: Vector2) -> float:
	var local_bottom := local_rect.position.y + local_rect.size.y
	return guide_y - local_bottom * scale.y


static func local_hitbox_rect(sprite: Sprite2D, inset: Vector4, owner) -> Rect2:
	var texture_size := sprite.texture.get_size()
	var visible_rect: Rect2 = visible_texture_rect(sprite.texture, owner)

	var left := visible_rect.position.x + visible_rect.size.x * inset.x
	var top := visible_rect.position.y + visible_rect.size.y * inset.y
	var right := visible_rect.position.x + visible_rect.size.x * (1.0 - inset.z)
	var bottom := visible_rect.position.y + visible_rect.size.y * (1.0 - inset.w)

	if sprite.flip_h:
		var mirrored_left := texture_size.x - right
		right = texture_size.x - left
		left = mirrored_left

	if sprite.flip_v:
		var mirrored_top := texture_size.y - bottom
		bottom = texture_size.y - top
		top = mirrored_top

	return Rect2(
		Vector2(left, top) - texture_size * 0.5,
		Vector2(maxf(1.0, right - left), maxf(1.0, bottom - top))
	)


static func visible_texture_rect(texture: Texture2D, owner) -> Rect2:
	# Runtime textures and resource duplicates may have the same (or empty)
	# path while using different transparent bounds.
	var cache_key := texture.get_instance_id()
	if owner.texture_hitbox_cache.has(cache_key):
		return owner.texture_hitbox_cache[cache_key]

	var image := texture.get_image()
	if image == null or image.is_empty():
		var fallback_rect := Rect2(Vector2.ZERO, texture.get_size())
		owner.texture_hitbox_cache[cache_key] = fallback_rect
		return fallback_rect

	var used_rect_i := image.get_used_rect()
	var used_rect := Rect2(Vector2(used_rect_i.position), Vector2(used_rect_i.size))
	if used_rect.size.x <= 0.0 or used_rect.size.y <= 0.0:
		used_rect = Rect2(Vector2.ZERO, texture.get_size())

	owner.texture_hitbox_cache[cache_key] = used_rect
	return used_rect


static func scale_for_height(texture: Texture2D, target_height: float) -> Vector2:
	var scale_value := target_height / texture.get_height()
	return Vector2(scale_value, scale_value)


static func reference_scale_for_vehicle(owner, vehicle_key: String, fallback: Vector2) -> Vector2:
	var path: String = VEHICLE_REFERENCE_PATHS.get(vehicle_key, "")
	if path.is_empty():
		return fallback

	var scale_reference: Node2D = owner.get_node_or_null(path) as Node2D
	if scale_reference == null:
		return fallback

	var viewport_height_ratio: float = owner.get_viewport_rect().size.y / 720.0
	return scale_reference.scale * viewport_height_ratio


static func scale_for_vehicle_in_lane(owner, vehicle_key: String, fallback: Vector2, lane_index: int) -> Vector2:
	return reference_scale_for_vehicle(owner, vehicle_key, fallback) * perspective_scale_for_lane(owner, lane_index)


static func perspective_scale_for_lane(owner, lane_index: int) -> float:
	match lane_index:
		0:
			return owner.incoming_lane_scale
		1:
			return owner.main_lane_scale
		2:
			return owner.shoulder_lane_scale
	return 1.0


static func lane_y(owner, lane_index: int, size: Vector2) -> float:
	var guide_names := ["IncomingSnapLine", "MainSnapLine", "ShoulderSnapLine"]
	var guide: Node2D = owner.get_node_or_null("EditorPreview/LaneSnapLines/%s" % guide_names[lane_index]) as Node2D
	if guide:
		return guide.position.y * size.y / 720.0

	var fallback_lane_positions := [0.585, 0.675, 0.805]
	return size.y * fallback_lane_positions[lane_index]


static func entity_lane_y(owner, lane_index: int, size: Vector2, is_parked := false) -> float:
	var lane_position: float = lane_y(owner, lane_index, size)
	if is_parked and lane_index == 2:
		lane_position += owner.PARKED_VEHICLE_Y_OFFSET
	return lane_position


static func z_for_lane(owner, lane_index: int, offset := 0) -> int:
	return owner.ROAD_ACTOR_Z_BASE + lane_index * owner.ROAD_ACTOR_Z_STEP + offset
