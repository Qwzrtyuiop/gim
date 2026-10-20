extends Control

const PortraitOutline := preload("res://scripts/story/story_portrait_outline.gd")

# Character cutouts, bottom-aligned to the dialogue panel.
var entries: Array[Dictionary] = []
var images: Dictionary = {}
var dialogue_panel: Control
var resolve_texture: Callable


func setup(panel: Control, resolver: Callable) -> void:
	dialogue_panel = panel
	resolve_texture = resolver
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_panel.resized.connect(layout_portraits)
	dialogue_panel.item_rect_changed.connect(layout_portraits)
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
