extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const GALLERY_SCENE := "res://scenes/gallery_library.tscn"
const MODE_GALLERY := "gallery"
const MODE_MEMORY := "memory"
const GALLERY_COLUMNS := 3
const GALLERY_TILE_SIZE := Vector2(330.0, 184.0)
const GALLERY_BOTTOM_SPACER_HEIGHT := 48.0
const MEMORY_ROW_SIZE := Vector2(0.0, 60.0)
const MEMORY_BOTTOM_SPACER_HEIGHT := 96.0
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const StoryMemoryCatalog := preload("res://scripts/story/story_memory_catalog.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

@onready var main_panel: Panel = $Panel
@onready var preview_panel: Panel = $Panel/PreviewPanel
@onready var gallery_tab_button: Button = $Panel/TabBar/GalleryTabButton
@onready var memory_tab_button: Button = $Panel/TabBar/MemoryTabButton
@onready var scroll_container: ScrollContainer = $Panel/ScrollContainer
@onready var list_container: VBoxContainer = $Panel/ScrollContainer/ListContainer
@onready var empty_label: Label = $Panel/EmptyLabel
@onready var preview_texture: TextureRect = $Panel/PreviewPanel/PreviewTexture
@onready var detail_title: Label = $Panel/PreviewPanel/TitleLabel
@onready var detail_subtitle: Label = $Panel/PreviewPanel/SubtitleLabel
@onready var detail_body: Label = $Panel/PreviewPanel/BodyLabel
@onready var replay_button: Button = $Panel/PreviewPanel/ReplayButton
@onready var back_button: Button = $Panel/BackButton
@onready var image_overlay: ColorRect = $ImageOverlay
@onready var image_overlay_panel: Panel = $ImageOverlay/ImagePanel
@onready var expanded_image: TextureRect = $ImageOverlay/ImagePanel/ExpandedImage
@onready var close_image_button: Button = $ImageOverlay/ImagePanel/CloseButton

var current_mode: String = MODE_GALLERY
var selected_entry: Dictionary = {}


func _ready() -> void:
	_apply_panel_theme(main_panel, Color(0.08, 0.08, 0.08, 0.92))
	_apply_panel_theme(preview_panel, Color(0.11, 0.10, 0.08, 0.94))
	_apply_button_theme(gallery_tab_button)
	_apply_button_theme(memory_tab_button)
	_apply_button_theme(replay_button)
	_apply_button_theme(back_button)
	_apply_button_theme(close_image_button)
	ButtonGlow.attach(self, gallery_tab_button)
	ButtonGlow.attach(self, memory_tab_button)
	ButtonGlow.attach(self, replay_button)
	ButtonGlow.attach(self, back_button)
	ButtonGlow.attach(self, close_image_button)
	_apply_panel_theme(image_overlay_panel, Color(0.05, 0.045, 0.04, 0.98))
	gallery_tab_button.pressed.connect(_show_gallery)
	memory_tab_button.pressed.connect(_show_memory)
	replay_button.pressed.connect(_replay_selected_memory)
	back_button.pressed.connect(_go_back)
	close_image_button.pressed.connect(_hide_expanded_image)
	image_overlay.visible = false
	_show_gallery()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if image_overlay.visible:
			_hide_expanded_image()
			return
		_go_back()


func _show_gallery() -> void:
	current_mode = MODE_GALLERY
	_populate_current_mode()


func _show_memory() -> void:
	current_mode = MODE_MEMORY
	_populate_current_mode()


func _populate_current_mode() -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()

	selected_entry.clear()
	_refresh_tab_buttons()
	_apply_mode_layout()
	scroll_container.scroll_horizontal = 0
	scroll_container.scroll_vertical = 0
	var entries: Array[Dictionary] = []
	if current_mode == MODE_MEMORY:
		entries = StoryMemoryCatalog.get_unlocked_memory_entries(PlayerState)
	else:
		entries = StoryMemoryCatalog.get_unlocked_gallery_entries(PlayerState)

	empty_label.visible = entries.is_empty()
	empty_label.text = "No memories unlocked yet." if current_mode == MODE_MEMORY else "No gallery images unlocked yet."
	if entries.is_empty():
		_clear_detail()
		return

	if current_mode == MODE_GALLERY:
		_populate_gallery_tiles(entries)
		_clear_detail()
		return

	for entry in entries:
		var button: Button = _make_memory_button(entry)
		list_container.add_child(button)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, MEMORY_BOTTOM_SPACER_HEIGHT)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_container.add_child(spacer)

	_select_entry(entries[0])
	var first_child: Node = list_container.get_child(0)
	if first_child is Button:
		(first_child as Button).grab_focus()


func _populate_gallery_tiles(entries: Array[Dictionary]) -> void:
	var current_row: HBoxContainer
	for entry_index in range(entries.size()):
		if entry_index % GALLERY_COLUMNS == 0:
			current_row = HBoxContainer.new()
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_theme_constant_override("separation", 14)
			list_container.add_child(current_row)

		var tile: Button = _make_gallery_tile(entries[entry_index])
		current_row.add_child(tile)

		if entry_index == 0:
			tile.grab_focus()

	var remainder: int = entries.size() % GALLERY_COLUMNS
	if remainder == 0:
		return
	for empty_index in range(GALLERY_COLUMNS - remainder):
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = GALLERY_TILE_SIZE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(spacer)

	var bottom_spacer: Control = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0.0, GALLERY_BOTTOM_SPACER_HEIGHT)
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_container.add_child(bottom_spacer)


func _make_gallery_tile(entry: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = GALLERY_TILE_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.tooltip_text = str(entry.get("title", ""))
	_apply_image_button_theme(button)

	var texture_rect: TextureRect = TextureRect.new()
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
	button.pressed.connect(_show_expanded_image.bind(entry))
	ButtonGlow.attach(self, button)
	return button


func _make_memory_button(entry: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = MEMORY_ROW_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.text = str(entry.get("title", "")).to_upper()
	button.tooltip_text = str(entry.get("title", ""))
	button.set_meta("memory_id", str(entry.get("id", "")))
	_apply_button_theme(button)

	button.pressed.connect(_select_entry.bind(entry))
	ButtonGlow.attach(self, button)
	return button


func _select_entry(entry: Dictionary) -> void:
	selected_entry = entry.duplicate(true)
	detail_title.text = str(selected_entry.get("title", "")).to_upper()
	detail_subtitle.text = str(selected_entry.get("subtitle", ""))
	detail_body.text = _detail_body_text(selected_entry)
	detail_body.visible = current_mode == MODE_GALLERY
	replay_button.visible = current_mode == MODE_MEMORY
	replay_button.disabled = current_mode != MODE_MEMORY

	var image_path: String = str(selected_entry.get("image", selected_entry.get("preview_image", "")))
	var texture = _load_texture(image_path)
	preview_texture.texture = texture
	preview_texture.visible = texture != null
	if current_mode == MODE_MEMORY:
		_refresh_memory_button_selection()


func _refresh_memory_button_selection() -> void:
	var selected_id: String = str(selected_entry.get("id", ""))
	for child in list_container.get_children():
		if child is Button:
			var row_button: Button = child as Button
			row_button.button_pressed = str(row_button.get_meta("memory_id", "")) == selected_id


func _show_expanded_image(entry: Dictionary) -> void:
	var texture = _load_texture(str(entry.get("image", "")))
	if texture == null:
		return
	expanded_image.texture = texture
	image_overlay.visible = true
	close_image_button.grab_focus()


func _hide_expanded_image() -> void:
	image_overlay.visible = false
	expanded_image.texture = null


func _detail_body_text(entry: Dictionary) -> String:
	if current_mode == MODE_MEMORY:
		return "Replay this unlocked story event without changing progress."
	return "Unlocked gallery image."


func _clear_detail() -> void:
	preview_texture.texture = null
	preview_texture.visible = false
	detail_title.text = ""
	detail_subtitle.text = ""
	detail_body.text = ""
	detail_body.visible = false
	replay_button.visible = current_mode == MODE_MEMORY
	replay_button.disabled = true


func _replay_selected_memory() -> void:
	if selected_entry.is_empty():
		return

	var memory_id: String = str(selected_entry.get("id", ""))
	var payload: Dictionary = StoryMemoryCatalog.build_memory_payload(memory_id, GALLERY_SCENE)
	if payload.is_empty():
		return

	PlayerState.set_pending_story(payload, false)
	get_tree().change_scene_to_file(STORY_SCENE)


func _refresh_tab_buttons() -> void:
	gallery_tab_button.disabled = current_mode == MODE_GALLERY
	memory_tab_button.disabled = current_mode == MODE_MEMORY


func _apply_mode_layout() -> void:
	if current_mode == MODE_GALLERY:
		preview_panel.visible = false
		scroll_container.offset_left = 28.0
		scroll_container.offset_top = 94.0
		scroll_container.offset_right = -28.0
		scroll_container.offset_bottom = -86.0
		preview_panel.offset_left = 448.0
		preview_panel.offset_top = 94.0
		preview_panel.offset_right = -28.0
		preview_panel.offset_bottom = -86.0
		empty_label.offset_left = 48.0
		empty_label.offset_top = 150.0
		empty_label.offset_right = -48.0
		empty_label.offset_bottom = -120.0
		return

	preview_panel.visible = true
	scroll_container.offset_left = 28.0
	scroll_container.offset_top = 94.0
	scroll_container.offset_right = -780.0
	scroll_container.offset_bottom = -86.0
	preview_panel.offset_left = 448.0
	preview_panel.offset_top = 94.0
	preview_panel.offset_right = -28.0
	preview_panel.offset_bottom = -86.0
	empty_label.offset_left = 48.0
	empty_label.offset_top = 150.0
	empty_label.offset_right = -800.0
	empty_label.offset_bottom = -120.0


func _load_texture(path: String):
	var safe_path: String = str(path).strip_edges()
	if safe_path.is_empty():
		return null
	var resource: Resource = load(safe_path)
	if resource is Texture2D:
		return resource
	return null


func _apply_button_theme(button: BaseButton) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.92, 0.72, 0.36, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	button.add_theme_constant_override("outline_size", 1)

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.22, 0.15, 0.11, 0.94)
	normal_style.border_color = Color(0.60, 0.45, 0.26, 1.0)
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 18.0
	normal_style.content_margin_right = 18.0
	normal_style.content_margin_top = 12.0
	normal_style.content_margin_bottom = 12.0

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(0.83, 0.63, 0.33, 0.98)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = Color(0.35, 0.48, 0.31, 0.98)

	var disabled_style: StyleBoxFlat = normal_style.duplicate()
	disabled_style.bg_color = Color(0.34, 0.25, 0.15, 0.98)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)


func _apply_image_button_theme(button: BaseButton) -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.07, 0.06, 0.96)
	normal_style.border_color = Color(0.64, 0.48, 0.26, 1.0)
	normal_style.set_border_width_all(4)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 8.0
	normal_style.content_margin_right = 8.0
	normal_style.content_margin_top = 8.0
	normal_style.content_margin_bottom = 8.0

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.border_color = Color(0.95, 0.72, 0.34, 1.0)
	hover_style.bg_color = Color(0.14, 0.10, 0.07, 0.98)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.border_color = Color(0.52, 0.70, 0.36, 1.0)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)


func _apply_panel_theme(panel: Panel, bg_color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.71, 0.56, 0.31, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
