extends Control

# The pause menu and main menu own saving/loading; this view only selects slots.
signal closed
signal save_requested(slot: int)
signal load_requested(slot: int)

const DESIGN_SIZE := Vector2(1218, 931)
const NOTEBOOK := preload("res://assets/ui/frames/notebook.png")
const NOTEBOOK_REGION := Rect2(18, 155, 1218, 931)
const FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const INK := Color("4b2d19")
const RED_INK := Color("873d2c")
const MUTED := Color("86603b")
const SLOT_COUNT := 10

var mode := "save"
var slot_buttons: Dictionary = {}
var notebook: Control
var scroll: ScrollContainer
var slot_list: VBoxContainer
var title_label: Label
var status_label: Label
var back_button: Button
var confirmation: ColorRect
var confirmation_text: Label
var confirm_button: Button
var cancel_button: Button
var preview_image: TextureRect
var preview_placeholder: Label
var preview_title: Label
var preview_kind: Label
var preview_day: Label
var preview_location: Label
var preview_time: Label
var preview_hint: Label
var _entries: Array[Dictionary] = []
var _can_save := true
var _pending_slot := 0
var _built := false
var _preview_textures: Dictionary = {}
var _selected_slot := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	_layout()
	hide()


func open(selected_mode: String, entries: Array, can_save := true, unavailable_reason := "") -> void:
	_build()
	mode = "load" if selected_mode == "load" else "save"
	_can_save = can_save
	_pending_slot = 0
	confirmation.hide()
	title_label.text = "LOAD GAME" if mode == "load" else "SAVE GAME"
	_selected_slot = 2
	if mode == "load":
		for entry in entries:
			if entry is Dictionary and bool(entry.get("valid", false)):
				_selected_slot = int(entry.slot)
				break
	refresh_slots(entries)
	_set_picker_focus(true)
	show_status(unavailable_reason if mode == "save" and not can_save else "Slot 1 autosaves at the start of each day.", can_save or mode == "load")
	show()
	_layout()
	scroll.scroll_vertical = 0
	back_button.grab_focus()


func refresh_slots(entries: Array) -> void:
	_entries.clear()
	_preview_textures.clear()
	for entry in entries:
		if entry is Dictionary:
			_entries.append(entry.duplicate(true))
	for child in slot_list.get_children():
		slot_list.remove_child(child)
		child.queue_free()
	slot_buttons.clear()
	for slot in range(1, SLOT_COUNT + 1):
		_build_slot(slot, _slot_data(slot))
	_show_slot_details(_selected_slot)


func close() -> void:
	_pending_slot = 0
	confirmation.hide()
	hide()
	closed.emit()


func handle_cancel() -> void:
	if confirmation.visible:
		_hide_confirmation()
	else:
		close()


func show_status(message: String, success := true) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", MUTED if success else RED_INK)


func _build() -> void:
	if _built:
		return
	_built = true
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.02, 0.015, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notebook = Control.new()
	notebook.name = "SaveNotebook"
	notebook.size = DESIGN_SIZE
	notebook.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(notebook)
	var paper := TextureRect.new()
	var cropped := AtlasTexture.new()
	cropped.atlas = NOTEBOOK
	cropped.region = NOTEBOOK_REGION
	paper.texture = cropped
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.size = DESIGN_SIZE
	notebook.add_child(paper)
	title_label = _label(notebook, "SAVE GAME", Rect2(76, 68, 456, 58), 42, RED_INK)
	_label(notebook, "YOUR JOURNEY / 10 SAVE SLOTS", Rect2(76, 127, 456, 30), 19, MUTED)
	scroll = ScrollContainer.new()
	scroll.name = "SlotScroll"
	scroll.position = Vector2(76, 178)
	scroll.size = Vector2(456, 593)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	notebook.add_child(scroll)
	slot_list = VBoxContainer.new()
	slot_list.name = "Slots"
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_list.add_theme_constant_override("separation", 12)
	scroll.add_child(slot_list)
	_label(notebook, "SCROLL TO VIEW ALL SLOTS", Rect2(76, 788, 456, 27), 18, MUTED)
	_label(notebook, "01 AUTOSAVE / 02-10 MANUAL", Rect2(76, 833, 456, 28), 19, MUTED)
	_build_preview()
	status_label = _label(notebook, "", Rect2(694, 696, 438, 96), 22, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back_button = _button(notebook, "CLOSE NOTEBOOK", Rect2(764, 821, 300, 52))
	back_button.pressed.connect(close)
	confirmation = ColorRect.new()
	confirmation.name = "SlotConfirmation"
	confirmation.size = DESIGN_SIZE
	confirmation.color = Color(0.12, 0.07, 0.035, 0.30)
	confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	notebook.add_child(confirmation)
	var panel := Panel.new()
	panel.position = Vector2(692, 335)
	panel.size = Vector2(444, 300)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("f3e4c8")
	panel_style.border_color = INK
	panel_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_style)
	confirmation.add_child(panel)
	confirmation_text = _label(panel, "", Rect2(24, 26, 396, 162), 28)
	confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cancel_button = _button(panel, "CANCEL", Rect2(24, 222, 182, 52))
	cancel_button.pressed.connect(_hide_confirmation)
	confirm_button = _button(panel, "SAVE", Rect2(238, 222, 182, 52))
	confirm_button.pressed.connect(_confirm_slot)
	confirmation.hide()


func _layout() -> void:
	if notebook == null:
		return
	var fit := maxf(0.1, minf((size.x - 32.0) / DESIGN_SIZE.x, (size.y - 24.0) / DESIGN_SIZE.y))
	notebook.scale = Vector2.ONE * fit
	notebook.position = (size - DESIGN_SIZE * fit) * 0.5


func _build_preview() -> void:
	preview_title = _label(notebook, "SLOT 02", Rect2(694, 68, 438, 58), 42, RED_INK)
	preview_kind = _label(notebook, "MANUAL SAVE", Rect2(694, 127, 438, 30), 19, MUTED)
	var frame := Panel.new()
	frame.position = Vector2(694, 178)
	frame.size = Vector2(438, 246)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.17, 0.08, 0.07)
	style.border_color = Color(0.30, 0.17, 0.08, 0.65)
	style.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", style)
	notebook.add_child(frame)
	preview_image = TextureRect.new()
	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(preview_image)
	_fill(preview_image, 5)
	preview_placeholder = _label(frame, "+", Rect2(0, 0, 438, 246), 72, MUTED)
	preview_day = _label(notebook, "", Rect2(694, 454, 438, 48), 34, INK)
	preview_location = _label(notebook, "", Rect2(694, 514, 438, 74), 28, INK)
	preview_location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_location.clip_text = true
	preview_time = _label(notebook, "", Rect2(694, 600, 438, 36), 23, MUTED)
	preview_hint = _label(notebook, "", Rect2(694, 654, 438, 30), 19, RED_INK)


func _show_slot_details(slot: int) -> void:
	if confirmation.visible or slot < 1 or slot > SLOT_COUNT:
		return
	_selected_slot = slot
	var entry := _slot_data(slot)
	var exists := bool(entry.get("exists", false))
	var valid := bool(entry.get("valid", false))
	preview_title.text = "SLOT %02d" % slot
	preview_kind.text = "DAILY AUTOSAVE" if slot == 1 else "MANUAL SAVE"
	preview_image.texture = _preview(str(entry.get("preview_path", ""))) if exists else null
	preview_image.visible = preview_image.texture != null
	preview_placeholder.visible = not preview_image.visible
	preview_placeholder.text = "NO PREVIEW" if exists else ("AUTO" if slot == 1 else "+")
	preview_placeholder.add_theme_font_size_override("font_size", 32 if exists or slot == 1 else 72)
	preview_day.text = "Day %d / %s" % [int(entry.get("day", 1)), str(entry.get("phase", "")).capitalize()] if valid else ("Save unavailable" if exists else "An unwritten page")
	preview_location.text = str(entry.get("location", "Saved game")) if valid else ("This file cannot be loaded." if exists else "Your next memory starts here.")
	preview_location.tooltip_text = preview_location.text
	preview_time.text = str(entry.get("saved_at", "")) if valid else ""
	if mode == "load":
		preview_hint.text = "CLICK SLOT TO LOAD" if valid else "NO SAVED GAME IN THIS SLOT"
	elif not _can_save:
		preview_hint.text = "SAVING UNAVAILABLE"
	elif slot == 1:
		preview_hint.text = "AUTOMATICALLY SAVED EACH NEW DAY"
	else:
		preview_hint.text = "CLICK SLOT TO OVERWRITE" if exists else "CLICK SLOT TO SAVE"
	for key: int in slot_buttons:
		_style_button(slot_buttons[key], key == slot)


func _build_slot(slot: int, entry: Dictionary) -> void:
	var exists := bool(entry.get("exists", false))
	var valid := bool(entry.get("valid", exists))
	var button := Button.new()
	button.name = "Slot%d" % slot
	button.custom_minimum_size = Vector2(0, 136)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = (mode == "save" and (slot == 1 or not _can_save)) or (mode == "load" and not valid)
	_style_button(button)
	slot_list.add_child(button)
	slot_buttons[slot] = button
	var title := "SLOT %02d" % slot
	if slot == 1:
		title += " / AUTOSAVE"
	var preview: Texture2D = _preview(str(entry.get("preview_path", ""))) if exists else null
	if exists:
		var image := TextureRect.new()
		image.texture = preview
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		image.position = Vector2(14, 20)
		image.size = Vector2(132, 96)
		image.clip_contents = true
		_row_label(button, title, 12, 25, 19, RED_INK)
		if valid:
			_row_label(button, "Day %d / %s" % [int(entry.get("day", 1)), str(entry.get("phase", "morning")).capitalize()], 43, 31, 25, INK)
			_row_label(button, str(entry.get("location", "")), 77, 25, 21, MUTED)
			_row_label(button, str(entry.get("saved_at", "")), 106, 23, 18, MUTED)
		else:
			_row_label(button, "Save unavailable", 48, 32, 24, INK)
			_row_label(button, "Click to replace" if mode == "save" and slot != 1 else "Cannot load this file", 93, 27, 20, MUTED)
	else:
		_label(button, "+" if slot != 1 else "AUTO", Rect2(14, 22, 132, 90), 58 if slot != 1 else 26, MUTED)
		_row_label(button, title, 14, 27, 19, RED_INK)
		_row_label(button, "Empty slot", 49, 35, 28, INK)
		_row_label(button, "A new place in your story" if slot != 1 else "Saved when a new day begins", 94, 27, 19, MUTED)
	button.pressed.connect(_select_slot.bind(slot))
	button.mouse_entered.connect(_show_slot_details.bind(slot))
	button.focus_entered.connect(func() -> void:
		scroll.ensure_control_visible(button)
		_show_slot_details(slot)
	)
	UIAudioManager.attach_button(button)


func _select_slot(slot: int) -> void:
	if confirmation.visible:
		return
	_show_slot_details(slot)
	var entry := _slot_data(slot)
	if mode == "save" and (slot == 1 or not _can_save):
		return
	if mode == "load" and not bool(entry.get("valid", false)):
		return
	if mode == "save" and not bool(entry.get("exists", false)):
		save_requested.emit(slot)
		return
	_pending_slot = slot
	confirmation_text.text = "Load Slot %02d?\nUnsaved progress will be lost." % slot if mode == "load" else "Overwrite Slot %02d?\nThis will replace the previous save." % slot
	confirm_button.text = "LOAD" if mode == "load" else "OVERWRITE"
	confirmation.show()
	_set_picker_focus(false)
	cancel_button.grab_focus()


func _confirm_slot() -> void:
	var slot := _pending_slot
	_pending_slot = 0
	confirmation.hide()
	_set_picker_focus(true)
	if slot < 1 or slot > SLOT_COUNT:
		return
	if mode == "load":
		load_requested.emit(slot)
	else:
		save_requested.emit(slot)


func _hide_confirmation() -> void:
	confirmation.hide()
	_set_picker_focus(true)
	var button: Button = slot_buttons.get(_pending_slot)
	_pending_slot = 0
	if button != null and not button.disabled:
		button.grab_focus()
	else:
		back_button.grab_focus()


func _set_picker_focus(enabled: bool) -> void:
	back_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button: Button in slot_buttons.values():
		button.focus_mode = Control.FOCUS_ALL if enabled and not button.disabled else Control.FOCUS_NONE


func _slot_data(slot: int) -> Dictionary:
	for entry: Dictionary in _entries:
		if int(entry.get("slot", 0)) == slot:
			return entry
	return {"slot": slot, "exists": false, "valid": false}


func _preview(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _preview_textures.has(path):
		return _preview_textures[path]
	var texture: Texture2D
	if path.begins_with("res://") and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_preview_textures[path] = texture
	return texture


func _row_label(parent: Control, text: String, top: float, height: float, font_size: int, color: Color) -> Label:
	var label := _label(parent, text, Rect2(164, top, 0, height), font_size, color)
	label.anchor_right = 1.0
	label.offset_right = -14
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _label(parent: Control, text: String, rect: Rect2, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 25)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	_style_button(button)
	parent.add_child(button)
	UIAudioManager.attach_button(button)
	return button


func _style_button(button: Button, selected := false) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var active: bool = selected or state in ["hover", "pressed", "focus"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.30, 0.17, 0.08, 0.12 if active else 0.035)
		style.border_color = RED_INK if active else Color(0.30, 0.17, 0.08, 0.35)
		style.set_border_width_all(2 if active else 1)
		if selected:
			style.border_width_left = 5
		button.add_theme_stylebox_override(state, style)


func _fill(control: Control, margin: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = -margin
	control.offset_bottom = -margin
