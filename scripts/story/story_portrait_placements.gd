extends RefCounted

const CharacterSprites := preload("res://scripts/story/story_character_sprites.gd")
const LocationSpawns := preload("res://scripts/story/story_location_spawns.gd")
const PRESENTATION_FIELDS := [
	"sheet",
	"source_region",
	"flip_h",
	"flip_v",
	"visible",
]


# Entries remain authored data; the active location only changes the returned copy.
static func resolve(entry: Dictionary, background: Texture2D) -> Dictionary:
	var uses_map := entry.has("background_placements")
	if not uses_map and str(entry.get("placement", "")).strip_edges().to_lower() != "background":
		return entry
	if background == null:
		return {}
	var background_path := _normalized_path(background.resource_path)
	if background_path.is_empty():
		return {}

	var raw_placement: Variant = null
	if uses_map:
		var placements: Variant = entry.get("background_placements", {})
		if not placements is Dictionary:
			return {}
		for path in placements:
			if _normalized_path(str(path)) == background_path:
				raw_placement = placements[path]
				break
	else:
		var character_id := CharacterSprites.canonical_character_id(str(entry.get("character_id", entry.get("id", ""))))
		raw_placement = LocationSpawns.entry(background_path, character_id)

	var placement := _placement_data(raw_placement)
	if placement.is_empty():
		return {}
	var variants: Variant = placement.get("variants", {})
	if variants is Dictionary:
		var sprite := str(entry.get("sprite", "default")).strip_edges().to_lower()
		for variant in variants:
			if str(variant).strip_edges().to_lower() != sprite:
				continue
			var variant_data := _placement_data(variants[variant])
			if variant_data.is_empty():
				return {}
			_clear_replaced_source(placement, variant_data)
			placement.merge(variant_data, true)
			break

	var background_region := region(placement.get("background_region", null))
	if background_region.size == Vector2.ZERO:
		return {}
	var result := entry.duplicate(true)
	result["background_region"] = background_region
	_clear_replaced_source(result, placement)
	for field in PRESENTATION_FIELDS:
		if placement.has(field):
			result[field] = placement[field]
	# Normalize texture aliases so an older base alias cannot win on another frame.
	if placement.has("texture") or placement.has("path"):
		var texture_ref: Variant = placement.get("texture", placement.get("path", null))
		if not _is_texture_reference(texture_ref):
			return {}
		result["texture"] = texture_ref
		result.erase("path")
		result.erase("portrait")
	if result.has("sheet"):
		if not _is_texture_reference(result["sheet"]):
			return {}
		var source_region := region(result.get("source_region", background_region))
		if source_region.size == Vector2.ZERO:
			return {}
		result["source_region"] = source_region
	return result


# Invalid regions use an empty rectangle, never coordinates from a previous scene.
static func region(value: Variant) -> Rect2:
	var result := Rect2()
	if value is Rect2:
		result = value
	elif value is Array and value.size() >= 4:
		for index in range(4):
			if not (value[index] is int or value[index] is float):
				return Rect2()
		result = Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	else:
		return Rect2()
	if not result.position.is_finite() or not result.size.is_finite():
		return Rect2()
	if result.size.x <= 0.0 or result.size.y <= 0.0:
		return Rect2()
	return result


static func _placement_data(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	if value is Rect2 or value is Array:
		return {"background_region": value}
	return {}


static func _is_texture_reference(value: Variant) -> bool:
	return value is Texture2D or (value is String and not value.strip_edges().is_empty())


static func _clear_replaced_source(target: Dictionary, source_override: Dictionary) -> void:
	if source_override.has("texture"):
		target.erase("path")
		target.erase("portrait")
	elif source_override.has("path"):
		target.erase("texture")
		target.erase("portrait")
	if (source_override.has("texture") or source_override.has("path")) and not source_override.has("sheet"):
		target.erase("sheet")
		target.erase("source_region")
	elif source_override.has("sheet") and not source_override.has("source_region"):
		# A newly selected sheet defaults its crop to this location's target region.
		target.erase("source_region")


static func _normalized_path(value: String) -> String:
	return value.strip_edges().replace("\\", "/").to_lower()
