extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const GALLERY_SCENE := "res://scenes/gallery_library.tscn"
const MODE_GALLERY := "gallery"
const MODE_MEMORY := "memory"
const GalleryView := preload("res://scripts/library/gallery_view.gd")
const LibraryTheme := preload("res://scripts/library/library_theme.gd")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const StoryMemoryCatalog := preload("res://scripts/story/story_memory_catalog.gd")

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
var memory_bottom_spacer: Control


func _ready() -> void:
	scroll_container.resized.connect(_update_memory_scroll_space)
	list_container.mouse_filter = Control.MOUSE_FILTER_PASS
	LibraryTheme.apply_panel(main_panel, Color(0.08, 0.08, 0.08, 0.92))
	LibraryTheme.apply_panel(preview_panel, Color(0.11, 0.10, 0.08, 0.94))
	for button in [gallery_tab_button, memory_tab_button, replay_button, back_button, close_image_button]:
		LibraryTheme.apply_gallery_button(button)
		ButtonGlow.attach(self, button)
	LibraryTheme.apply_panel(image_overlay_panel, Color(0.05, 0.045, 0.04, 0.98))
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
	selected_entry.clear()
	var entries: Array[Dictionary] = []
	if current_mode == MODE_MEMORY:
		entries = StoryMemoryCatalog.get_unlocked_memory_entries(PlayerState)
	else:
		entries = StoryMemoryCatalog.get_unlocked_gallery_entries(PlayerState)
	GalleryView.populate(self, entries)


func _update_memory_scroll_space() -> void:
	GalleryView.update_memory_scroll_space(self)


func _select_entry(entry: Dictionary) -> void:
	selected_entry = entry.duplicate(true)
	GalleryView.show_selected_entry(self, selected_entry)


func _show_expanded_image(entry: Dictionary) -> void:
	GalleryView.show_expanded_image(self, entry)


func _hide_expanded_image() -> void:
	GalleryView.hide_expanded_image(self)


func _replay_selected_memory() -> void:
	if selected_entry.is_empty():
		return

	var memory_id: String = str(selected_entry.get("id", ""))
	var payload: Dictionary = StoryMemoryCatalog.build_memory_payload(memory_id, GALLERY_SCENE)
	if payload.is_empty():
		return

	PlayerState.set_pending_memory_replay(payload)
	get_tree().change_scene_to_file(STORY_SCENE)


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
