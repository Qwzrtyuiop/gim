extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ACHIEVEMENTS_LIBRARY_SCENE := "res://scenes/achievements_library.tscn"
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const NOTEBOOK_TEXTURE := preload("res://assets/ui/frames/notebookclosed.png")
const NOTEBOOK_REGION := Rect2(224, 108, 860, 1068)
const BUTTON_TEXTURE := preload("res://assets/ui/buttons/button_generic.png")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const AudioSettingsPanel := preload("res://scripts/ui/audio_settings_panel.gd")
const SaveSlotScreen := preload("res://scripts/ui/save_slot_screen.gd")
const SaveGameContext := preload("res://scripts/save/save_game_context.gd")

var overlay: ColorRect
var menu_panel: Panel
var menu_title: Label
var return_button: TextureButton
var save_button: TextureButton
var load_button: TextureButton
var achievements_button: TextureButton
var exit_button: TextureButton
var library_panel: Panel
var library_title: Label
var library_scroll: ScrollContainer
var library_list: VBoxContainer
var library_empty_label: Label
var library_back_button: Button
var detail_overlay: ColorRect
var detail_panel: Panel
var detail_title: Label
var detail_subtitle: Label
var detail_body: Label
var detail_close_button: Button
var audio_panel_refs: Dictionary = {}
var save_screen: SaveSlotScreen
var save_preview: Image
var save_screen_mode := "save"


func _ready() -> void:
	layer = 700
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_layout_menu)
	_layout_menu()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if not request_toggle():
		return
	get_viewport().set_input_as_handled()


func request_toggle() -> bool:
	var achievement_popups := get_node_or_null("/root/AchievementPopupManager")
	if achievement_popups != null and achievement_popups.is_description_open():
		return true
	if visible:
		if save_screen.visible:
			save_screen.handle_cancel()
			return true
		if detail_overlay.visible:
			_hide_detail()
			return true
		if library_panel.visible:
			_hide_library()
			return true
		hide_pause_menu()
		return true

	if not _can_pause_current_scene():
		return false

	show_pause_menu()
	return true


func is_menu_open() -> bool:
	return visible


func show_pause_menu() -> void:
	# Capture the last unobscured frame, before the notebook overlays appear.
	save_preview = null
	var viewport_texture := get_viewport().get_texture() if DisplayServer.get_name() != "headless" else null
	if viewport_texture != null:
		var frame := viewport_texture.get_image()
		if frame != null and not frame.is_empty():
			save_preview = frame
	visible = true
	overlay.visible = true
	menu_panel.visible = true
	library_panel.visible = false
	detail_overlay.visible = false
	save_screen.hide()
	var reason := SaveGameContext.save_block_reason()
	save_button.disabled = not reason.is_empty()
	save_button.tooltip_text = reason
	get_tree().paused = true
	return_button.grab_focus()


func hide_pause_menu() -> void:
	save_screen.hide()
	save_preview = null
	detail_overlay.visible = false
	library_panel.visible = false
	menu_panel.visible = true
	overlay.visible = false
	visible = false
	get_tree().paused = false


func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	add_child(overlay)

	menu_panel = Panel.new()
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -250.0
	menu_panel.offset_top = -310.0
	menu_panel.offset_right = 250.0
	menu_panel.offset_bottom = 310.0
	menu_panel.pivot_offset = Vector2(250.0, 310.0)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	overlay.add_child(menu_panel)

	var frame := TextureRect.new()
	var cover := AtlasTexture.new()
	cover.atlas = NOTEBOOK_TEXTURE
	cover.region = NOTEBOOK_REGION
	frame.texture = cover
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(frame)

	menu_title = _make_label(20, Color(0.98, 0.91, 0.72, 1.0), 2)
	menu_title.text = "PAUSED"
	menu_title.position = Vector2(125.0, 45.0)
	menu_title.size = Vector2(320.0, 30.0)
	menu_panel.add_child(menu_title)

	return_button = _make_texture_button("RETURN", Vector2(145.0, 94.0))
	return_button.pressed.connect(hide_pause_menu)

	save_button = _make_texture_button("SAVE", Vector2(145.0, 152.0))
	save_button.pressed.connect(_show_save_screen.bind("save"))
	load_button = _make_texture_button("LOAD", Vector2(145.0, 210.0))
	load_button.pressed.connect(_show_save_screen.bind("load"))
	achievements_button = _make_texture_button("ACHIEVEMENTS", Vector2(145.0, 268.0), 14)
	achievements_button.pressed.connect(_show_library)

	exit_button = _make_texture_button("EXIT", Vector2(145.0, 326.0))
	exit_button.pressed.connect(_exit_to_main_menu)

	audio_panel_refs = AudioSettingsPanel.create(
		self,
		menu_panel,
		UI_FONT,
		Vector2(125.0, 396.0),
		Vector2(320.0, 170.0),
		"AUDIO"
	)

	library_panel = Panel.new()
	library_panel.visible = false
	library_panel.anchor_left = 0.5
	library_panel.anchor_top = 0.5
	library_panel.anchor_right = 0.5
	library_panel.anchor_bottom = 0.5
	library_panel.offset_left = -430.0
	library_panel.offset_top = -220.0
	library_panel.offset_right = 430.0
	library_panel.offset_bottom = 220.0
	library_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_theme(library_panel, Color(0.10, 0.09, 0.08, 0.97))
	overlay.add_child(library_panel)

	library_title = _make_label(16, Color(0.98, 0.94, 0.80, 1.0), 2)
	library_title.text = "ACHIEVEMENTS LIBRARY"
	library_title.position = Vector2(0.0, 26.0)
	library_title.size = Vector2(860.0, 24.0)
	library_panel.add_child(library_title)

	library_scroll = ScrollContainer.new()
	library_scroll.anchor_left = 0.0
	library_scroll.anchor_top = 0.0
	library_scroll.anchor_right = 1.0
	library_scroll.anchor_bottom = 1.0
	library_scroll.offset_left = 28.0
	library_scroll.offset_top = 68.0
	library_scroll.offset_right = -28.0
	library_scroll.offset_bottom = -84.0
	library_panel.add_child(library_scroll)

	library_list = VBoxContainer.new()
	library_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_list.add_theme_constant_override("separation", 10)
	library_scroll.add_child(library_list)

	library_empty_label = _make_label(12, Color(0.95, 0.91, 0.80, 1.0), 1)
	library_empty_label.text = "No achievements unlocked yet."
	library_empty_label.anchor_right = 1.0
	library_empty_label.anchor_bottom = 1.0
	library_empty_label.offset_left = 32.0
	library_empty_label.offset_top = 110.0
	library_empty_label.offset_right = -32.0
	library_empty_label.offset_bottom = -110.0
	library_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	library_panel.add_child(library_empty_label)

	library_back_button = Button.new()
	library_back_button.text = "BACK"
	library_back_button.custom_minimum_size = Vector2(188.0, 42.0)
	library_back_button.position = Vector2(336.0, 386.0)
	_apply_flat_button_theme(library_back_button)
	library_back_button.pressed.connect(_hide_library)
	library_panel.add_child(library_back_button)

	detail_overlay = ColorRect.new()
	detail_overlay.visible = false
	detail_overlay.anchor_right = 1.0
	detail_overlay.anchor_bottom = 1.0
	detail_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	library_panel.add_child(detail_overlay)

	detail_panel = Panel.new()
	detail_panel.anchor_left = 0.5
	detail_panel.anchor_top = 0.5
	detail_panel.anchor_right = 0.5
	detail_panel.anchor_bottom = 0.5
	detail_panel.offset_left = -300.0
	detail_panel.offset_top = -150.0
	detail_panel.offset_right = 300.0
	detail_panel.offset_bottom = 150.0
	_apply_panel_theme(detail_panel, Color(0.12, 0.11, 0.09, 0.98))
	detail_overlay.add_child(detail_panel)

	detail_title = _make_label(16, Color(0.98, 0.94, 0.80, 1.0), 2)
	detail_title.position = Vector2(0.0, 26.0)
	detail_title.size = Vector2(600.0, 24.0)
	detail_panel.add_child(detail_title)

	detail_subtitle = _make_label(11, Color(0.93, 0.86, 0.70, 1.0), 1)
	detail_subtitle.position = Vector2(0.0, 58.0)
	detail_subtitle.size = Vector2(600.0, 20.0)
	detail_panel.add_child(detail_subtitle)

	detail_body = _make_label(12, Color(0.98, 0.95, 0.88, 1.0), 1)
	detail_body.position = Vector2(28.0, 96.0)
	detail_body.size = Vector2(544.0, 136.0)
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_panel.add_child(detail_body)

	detail_close_button = Button.new()
	detail_close_button.text = "CLOSE"
	detail_close_button.custom_minimum_size = Vector2(180.0, 38.0)
	detail_close_button.position = Vector2(210.0, 244.0)
	_apply_flat_button_theme(detail_close_button)
	detail_close_button.pressed.connect(_hide_detail)
	detail_panel.add_child(detail_close_button)
	save_screen = SaveSlotScreen.new()
	overlay.add_child(save_screen)
	save_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_screen.hide()
	save_screen.closed.connect(_hide_save_screen)
	save_screen.save_requested.connect(_save_requested)
	save_screen.load_requested.connect(_load_requested)
	save_screen.delete_requested.connect(_delete_requested)
	SaveSlotManager.slots_changed.connect(_refresh_save_slots)


func _layout_menu() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := minf(1.0, minf(maxf(1.0, viewport_size.x - 24.0) / 500.0, maxf(1.0, viewport_size.y - 24.0) / 620.0))
	menu_panel.scale = Vector2.ONE * fit


func _show_save_screen(mode: String) -> void:
	save_screen_mode = mode
	menu_panel.hide()
	var reason := SaveGameContext.save_block_reason()
	save_screen.open(mode, SaveSlotManager.list_slots(), reason.is_empty(), reason)


func _hide_save_screen() -> void:
	save_screen.hide()
	menu_panel.show()
	(save_button if save_screen_mode == "save" else load_button).grab_focus()


func _refresh_save_slots() -> void:
	if save_screen != null and save_screen.visible:
		save_screen.refresh_slots(SaveSlotManager.list_slots())


func _save_requested(slot: int) -> void:
	var reason := SaveGameContext.save_block_reason()
	if not reason.is_empty():
		save_screen.show_status(reason, false)
		return
	var context: Dictionary = SaveGameContext.capture(null, save_preview)
	var error: Error = SaveSlotManager.save_slot(slot, context)
	if error == OK:
		save_screen.refresh_slots(SaveSlotManager.list_slots())
		save_screen.show_status("Saved to slot %d." % slot)
	else:
		save_screen.show_status("Could not save: %s" % error_string(error), false)


func _delete_requested(slot: int) -> void:
	var error: Error = SaveSlotManager.delete_slot(slot)
	save_screen.refresh_slots(SaveSlotManager.list_slots())
	save_screen.show_status("Deleted slot %02d." % slot if error == OK else "Could not delete: %s" % error_string(error), error == OK)


func _load_requested(slot: int) -> void:
	var valid := false
	for entry: Dictionary in SaveSlotManager.list_slots():
		if int(entry.slot) == slot:
			valid = bool(entry.valid)
			break
	if not valid:
		save_screen.show_status("Could not load this save.", false)
		return
	# Retire pending story checkpoints before the slot replaces PlayerState.
	SaveGameContext.prepare_scene_for_load(get_tree().current_scene)
	if not SaveSlotManager.load_slot(slot):
		save_screen.show_status("Could not load this save.", false)
		return
	var destination: String = SaveGameContext.resume_scene()
	_finish_slot_load.call_deferred(destination)


func _finish_slot_load(destination: String) -> void:
	var old_scene := get_tree().current_scene
	var previous_mode: int = old_scene.process_mode if old_scene != null else Node.PROCESS_MODE_INHERIT
	if old_scene != null:
		old_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var error := get_tree().change_scene_to_file(destination)
	if error != OK:
		if is_instance_valid(old_scene):
			old_scene.process_mode = previous_mode
		show_pause_menu()
		_show_save_screen("load")
		save_screen.show_status("Could not open the saved location.", false)
		return
	# Keep the discarded reader/ride paused until Godot frees it and installs
	# the loaded scene. Pending old waits must not run against loaded progress.
	await get_tree().scene_changed
	hide_pause_menu()


func _make_texture_button(text: String, position_value: Vector2, font_size := 16) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = BUTTON_TEXTURE
	button.texture_pressed = BUTTON_TEXTURE
	button.texture_hover = BUTTON_TEXTURE
	button.texture_focused = BUTTON_TEXTURE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.position = position_value
	button.size = Vector2(280.0, 50.0)
	menu_panel.add_child(button)

	var label := _make_label(font_size, Color(0.96, 0.92, 0.78, 1.0), 1)
	label.text = text
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	ButtonGlow.attach(self, button)
	return button


func _make_label(font_size: int, font_color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _apply_panel_theme(panel: Panel, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.68, 0.52, 0.28, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)


func _apply_flat_button_theme(button: Button) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.17, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.17, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.17, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	button.add_theme_constant_override("outline_size", 1)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.42, 0.27, 0.16, 0.95)
	normal_style.border_color = Color(0.16, 0.09, 0.05, 1.0)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(7)
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.82, 0.63, 0.33, 0.98)
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.37, 0.52, 0.31, 0.98)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)


func _show_library() -> void:
	menu_panel.visible = false
	library_panel.visible = true
	detail_overlay.visible = false
	_populate_library()
	library_back_button.grab_focus()


func _hide_library() -> void:
	detail_overlay.visible = false
	library_panel.visible = false
	menu_panel.visible = true
	return_button.grab_focus()


func _populate_library() -> void:
	for child in library_list.get_children():
		child.queue_free()

	var unlocked_ids := PlayerState.get_unlocked_achievement_ids()
	library_empty_label.visible = unlocked_ids.is_empty()
	if unlocked_ids.is_empty():
		return

	for achievement_id in unlocked_ids:
		var achievement_data := PlayerState.get_achievement_data(achievement_id)
		if achievement_data.is_empty():
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 70.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s / %s" % [
			str(achievement_data.get("title", "")).to_upper(),
			str(achievement_data.get("subtitle", "")),
		]
		_apply_flat_button_theme(button)
		button.pressed.connect(_show_achievement_detail.bind(achievement_data))
		library_list.add_child(button)
		ButtonGlow.attach(self, button)


func _show_achievement_detail(achievement_data: Dictionary) -> void:
	detail_title.text = str(achievement_data.get("title", "")).to_upper()
	detail_subtitle.text = str(achievement_data.get("subtitle", ""))
	detail_body.text = str(achievement_data.get("description", ""))
	detail_overlay.visible = true
	detail_close_button.grab_focus()


func _hide_detail() -> void:
	detail_overlay.visible = false
	library_back_button.grab_focus()


func _exit_to_main_menu() -> void:
	hide_pause_menu()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _can_pause_current_scene() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	# A blocking hub conversation owns Escape until it is dismissed. Ordinary
	# ambient bubbles leave the existing pause behavior available.
	var dialogue := current_scene.get_node_or_null("HubDialogue")
	if dialogue != null and dialogue.has_method("blocks_input") and dialogue.blocks_input():
		return false
	var scene_file := str(current_scene.scene_file_path)
	if scene_file.is_empty():
		return false
	return scene_file != MAIN_MENU_SCENE and scene_file != ACHIEVEMENTS_LIBRARY_SCENE
