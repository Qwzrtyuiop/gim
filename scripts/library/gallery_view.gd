extends RefCounted

# Gallery grids, memory rows, detail previews, and the expanded image overlay.

const LibraryTheme := preload("res://scripts/library/library_theme.gd")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const GALLERY_COLUMNS := 3
const GALLERY_TILE_SIZE := Vector2(330.0, 184.0)
const GALLERY_BOTTOM_SPACER_HEIGHT := 48.0
const MEMORY_ROW_SIZE := Vector2(0.0, 60.0)
const MEMORY_BOTTOM_SPACER_HEIGHT := 96.0


static func populate(owner, entries: Array[Dictionary]) -> void:
	owner.memory_bottom_spacer = null
	for child in owner.list_container.get_children():
		owner.list_container.remove_child(child)
		child.queue_free()

	owner.gallery_tab_button.disabled = owner.current_mode == owner.MODE_GALLERY
	owner.memory_tab_button.disabled = owner.current_mode == owner.MODE_MEMORY
	_apply_mode_layout(owner)
	owner.scroll_container.scroll_horizontal = 0
	owner.scroll_container.scroll_vertical = 0
	owner.empty_label.visible = entries.is_empty()
	owner.empty_label.text = "No memories unlocked yet." if owner.current_mode == owner.MODE_MEMORY else "No gallery images unlocked yet."
	if entries.is_empty():
		_clear_detail(owner)
		return

	if owner.current_mode == owner.MODE_GALLERY:
		_populate_gallery_tiles(owner, entries)
		_clear_detail(owner)
		return

	for entry in entries:
		owner.list_container.add_child(_make_memory_button(owner, entry))

	var spacer := Control.new()
	spacer.name = "MemoryBottomSpace"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.focus_mode = Control.FOCUS_NONE
	owner.list_container.add_child(spacer)
	owner.memory_bottom_spacer = spacer
	update_memory_scroll_space(owner)

	owner._select_entry(entries[0])
	var first_child: Node = owner.list_container.get_child(0)
	if first_child is Button:
		(first_child as Button).grab_focus()


static func update_memory_scroll_space(owner) -> void:
	if owner.current_mode != owner.MODE_MEMORY or not is_instance_valid(owner.memory_bottom_spacer):
		return
	var rows_height := 0.0
	for child in owner.list_container.get_children():
		if child is Control and child != owner.memory_bottom_spacer:
			rows_height += child.get_combined_minimum_size().y
	rows_height += owner.list_container.get_theme_constant("separation") * (owner.list_container.get_child_count() - 1)
	# Keep at least one row of scrolling even when only one memory is unlocked.
	owner.memory_bottom_spacer.custom_minimum_size.y = maxf(
		MEMORY_BOTTOM_SPACER_HEIGHT,
		owner.scroll_container.size.y + MEMORY_ROW_SIZE.y - rows_height
	)


static func _populate_gallery_tiles(owner, entries: Array[Dictionary]) -> void:
	var current_row: HBoxContainer
	for entry_index in range(entries.size()):
		if entry_index % GALLERY_COLUMNS == 0:
			current_row = HBoxContainer.new()
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_theme_constant_override("separation", 14)
			owner.list_container.add_child(current_row)

		var tile: Button = _make_gallery_tile(owner, entries[entry_index])
		current_row.add_child(tile)

		if entry_index == 0:
			tile.grab_focus()

	var remainder: int = entries.size() % GALLERY_COLUMNS
	if remainder == 0:
		return
	for empty_index in range(GALLERY_COLUMNS - remainder):
		var spacer := Control.new()
		spacer.custom_minimum_size = GALLERY_TILE_SIZE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0.0, GALLERY_BOTTOM_SPACER_HEIGHT)
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.list_container.add_child(bottom_spacer)


static func _make_gallery_tile(owner, entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = GALLERY_TILE_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.tooltip_text = str(entry.get("title", ""))
	LibraryTheme.apply_image_button(button)

	var texture_rect := TextureRect.new()
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	texture_rect.offset_left = 8.0
	texture_rect.offset_top = 8.0
	texture_rect.offset_right = -8.0
	texture_rect.offset_bottom = -8.0
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.texture = _load_texture(str(entry.get("image", "")))
	button.add_child(texture_rect)
	button.pressed.connect(owner._show_expanded_image.bind(entry))
	ButtonGlow.attach(owner, button)
	return button


static func _make_memory_button(owner, entry: Dictionary) -> Button:
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_force_pass_scroll_events = true
	button.custom_minimum_size = MEMORY_ROW_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.text = str(entry.get("title", "")).to_upper()
	button.tooltip_text = str(entry.get("title", ""))
	button.set_meta("memory_id", str(entry.get("id", "")))
	LibraryTheme.apply_gallery_button(button)

	button.pressed.connect(owner._select_entry.bind(entry))
	ButtonGlow.attach(owner, button)
	return button


static func show_selected_entry(owner, entry: Dictionary) -> void:
	owner.detail_title.text = str(entry.get("title", "")).to_upper()
	owner.detail_subtitle.text = str(entry.get("subtitle", ""))
	owner.detail_body.text = "Replay this unlocked story event without changing progress." if owner.current_mode == owner.MODE_MEMORY else "Unlocked gallery image."
	owner.detail_body.visible = owner.current_mode == owner.MODE_GALLERY
	owner.replay_button.visible = owner.current_mode == owner.MODE_MEMORY
	owner.replay_button.disabled = owner.current_mode != owner.MODE_MEMORY

	var image_path: String = str(entry.get("image", entry.get("preview_image", "")))
	var texture: Texture2D = _load_texture(image_path)
	owner.preview_texture.texture = texture
	owner.preview_texture.visible = texture != null
	if owner.current_mode == owner.MODE_MEMORY:
		var selected_id: String = str(entry.get("id", ""))
		for child in owner.list_container.get_children():
			if child is Button:
				var row_button: Button = child as Button
				row_button.button_pressed = str(row_button.get_meta("memory_id", "")) == selected_id


static func show_expanded_image(owner, entry: Dictionary) -> void:
	var texture: Texture2D = _load_texture(str(entry.get("image", "")))
	if texture == null:
		return
	owner.expanded_image.texture = texture
	owner.image_overlay.visible = true
	owner.close_image_button.grab_focus()


static func hide_expanded_image(owner) -> void:
	owner.image_overlay.visible = false
	owner.expanded_image.texture = null


static func _clear_detail(owner) -> void:
	owner.preview_texture.texture = null
	owner.preview_texture.visible = false
	owner.detail_title.text = ""
	owner.detail_subtitle.text = ""
	owner.detail_body.text = ""
	owner.detail_body.visible = false
	owner.replay_button.visible = owner.current_mode == owner.MODE_MEMORY
	owner.replay_button.disabled = true


static func _apply_mode_layout(owner) -> void:
	owner.scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS if owner.current_mode == owner.MODE_MEMORY else ScrollContainer.SCROLL_MODE_AUTO
	owner.preview_panel.visible = owner.current_mode == owner.MODE_MEMORY
	owner.scroll_container.offset_left = 28.0
	owner.scroll_container.offset_top = 94.0
	owner.scroll_container.offset_right = -780.0 if owner.current_mode == owner.MODE_MEMORY else -28.0
	owner.scroll_container.offset_bottom = -86.0
	owner.preview_panel.offset_left = 448.0
	owner.preview_panel.offset_top = 94.0
	owner.preview_panel.offset_right = -28.0
	owner.preview_panel.offset_bottom = -86.0
	owner.empty_label.offset_left = 48.0
	owner.empty_label.offset_top = 150.0
	owner.empty_label.offset_right = -800.0 if owner.current_mode == owner.MODE_MEMORY else -48.0
	owner.empty_label.offset_bottom = -120.0


static func _load_texture(path: String) -> Texture2D:
	var safe_path: String = path.strip_edges()
	if safe_path.is_empty():
		return null
	return load(safe_path) as Texture2D
