extends Control

const PortraitOutline := preload("res://scripts/story/story_portrait_outline.gd")
const CharacterSprites := preload("res://scripts/story/story_character_sprites.gd")

# Character cutouts, bottom-aligned to dialogue or positioned on the background.
var entries: Array[Dictionary] = []
var images: Dictionary = {}
var dialogue_panel: Control
var background: TextureRect
var resolve_texture: Callable


func setup(panel: Control, resolver: Callable, scene_background: TextureRect = null) -> void:
	dialogue_panel = panel
	background = scene_background
	resolve_texture = resolver
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_panel.resized.connect(layout_portraits)
	dialogue_panel.item_rect_changed.connect(layout_portraits)
	if is_instance_valid(background):
		background.item_rect_changed.connect(layout_portraits)
	resized.connect(layout_portraits)


func replace_portraits(raw_entries: Array) -> void:
	clear_portraits()
	for entry in raw_entries:
		if entry is Dictionary:
			set_portrait(entry)


func set_portrait(data: Dictionary) -> void:
	var id := str(data.get("id", "")).strip_edges()
	if id.is_empty():
		push_warning("Story portrait needs an id.")
		return
	var index := _entry_index(id)
	var entry: Dictionary = entries[index].duplicate(true) if index >= 0 else {"id": id}
	entry.merge(data, true)
	entry["id"] = id
	# Both aliases can replace a previously assigned texture.
	if data.has("path"):
		entry["texture"] = data["path"]
	elif data.has("portrait"):
		entry["texture"] = data["portrait"]
	entry.erase("path")
	entry.erase("portrait")
	var explicit_texture := data.has("texture") or data.has("path") or data.has("portrait")
	var previous_character := CharacterSprites.canonical_character_id(str(entries[index].get("character_id", id))) if index >= 0 else ""
	var next_character := CharacterSprites.canonical_character_id(str(entry.get("character_id", id)))
	var update_sprite := data.has("sprite") or previous_character != next_character or not entry.has("texture")
	if not explicit_texture and update_sprite and (entry.has("character_id") or entry.has("sprite")):
		var character_id := CharacterSprites.canonical_character_id(str(entry.get("character_id", id)))
		var sprite := str(entry.get("sprite", "default")).strip_edges().to_lower()
		if previous_character != next_character and not data.has("sprite"):
			sprite = "default"
		var path := CharacterSprites.texture_path(character_id, sprite)
		if path.is_empty():
			push_warning("Unknown character sprite '%s' for portrait '%s'." % [sprite, id])
			return
		entry["character_id"] = character_id
		entry["sprite"] = sprite
		entry["texture"] = path
	var texture_ref = entry.get("texture", null)
	var texture: Texture2D = resolve_texture.call(texture_ref)
	if texture == null:
		push_warning("Story portrait '%s' has no valid texture." % id)
		return
	if index >= 0:
		entries[index] = entry
	else:
		entries.append(entry)
	var rect: TextureRect = images.get(id)
	if rect == null:
		rect = TextureRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(rect)
		images[id] = rect
	rect.texture = texture
	rect.flip_h = bool(entry.get("flip_h", false))
	rect.flip_v = bool(entry.get("flip_v", false))
	rect.visible = bool(entry.get("visible", true))
	# Scene cutouts keep their original shading; portrait outlines distort atlas UVs.
	if entry.has("background_region"):
		rect.material = null
	else:
		PortraitOutline.apply_to(rect)
	layout_portraits()


func remove_portrait(id: String) -> void:
	var index := _entry_index(id)
	if index < 0:
		return
	entries.remove_at(index)
	var rect: TextureRect = images[id]
	remove_child(rect)
	rect.queue_free()
	images.erase(id)
	layout_portraits()


func clear_portraits() -> void:
	for rect in images.values():
		remove_child(rect)
		rect.queue_free()
	images.clear()
	entries.clear()


func layout_portraits() -> void:
	if not is_instance_valid(dialogue_panel):
		return
	var panel_rect := dialogue_panel.get_rect()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var rect: TextureRect = images[str(entry["id"])]
		if _layout_background_portrait(rect, entry.get("background_region", null)):
			continue
		var offset := _offset(entry.get("offset", Vector2.ZERO))
		var bottom := panel_rect.position.y - float(entry.get("gap", 0.0)) + offset.y
		var height := clampf(float(entry.get("height", 320.0)), 1.0, maxf(1.0, bottom))
		var texture_size := rect.texture.get_size()
		var width := height * texture_size.x / maxf(1.0, texture_size.y)
		if width > panel_rect.size.x:
			height *= panel_rect.size.x / width
			width = panel_rect.size.x
		var x_ratio := 0.17
		match str(entry.get("position", "")):
			"left":
				x_ratio = 0.17
			"center":
				x_ratio = 0.5
			"right":
				x_ratio = 0.83
		x_ratio = clampf(float(entry.get("x", x_ratio)), 0.0, 1.0)
		var center := panel_rect.position.x + panel_rect.size.x * x_ratio + offset.x
		center = clampf(center, panel_rect.position.x + width * 0.5, panel_rect.end.x - width * 0.5)
		rect.size = Vector2(width, height)
		rect.position = Vector2(center - width * 0.5, bottom - height)


func _layout_background_portrait(rect: TextureRect, region_data: Variant) -> bool:
	if not region_data is Array or region_data.size() < 4 or not is_instance_valid(background) or background.texture == null:
		return false
	var texture_size := background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var region := Rect2(float(region_data[0]), float(region_data[1]), float(region_data[2]), float(region_data[3]))
	var drawn_rect := Rect2(Vector2.ZERO, background.size)
	if background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		drawn_rect.size = texture_size * minf(background.size.x / texture_size.x, background.size.y / texture_size.y)
		drawn_rect.position = (background.size - drawn_rect.size) * 0.5
	var image_scale := drawn_rect.size / texture_size
	var image_rect := Rect2(drawn_rect.position + region.position * image_scale, region.size * image_scale)
	var local_transform := get_global_transform_with_canvas().affine_inverse() * background.get_global_transform_with_canvas()
	var local_rect: Rect2 = local_transform * image_rect
	rect.position = local_rect.position
	rect.size = local_rect.size
	return true


func _entry_index(id: String) -> int:
	for index in range(entries.size()):
		if str(entries[index]["id"]) == id:
			return index
	return -1


func _offset(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
