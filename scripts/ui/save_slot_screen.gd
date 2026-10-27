extends Control

# The pause menu and main menu own save operations; this view selects slots.
signal closed
signal save_requested(slot: int)
signal load_requested(slot: int)
signal delete_requested(slot: int)

const DESIGN_SIZE := Vector2(1218, 931)
const NOTEBOOK := preload("res://assets/ui/frames/notebook.png")
const NOTEBOOK_REGION := Rect2(18, 155, 1218, 931)
const NotebookTheme := preload("res://scripts/ui/save_notebook_theme.gd")
const SlotCard := preload("res://scripts/ui/save_slot_card.gd")
const FONT := NotebookTheme.FONT
const INK := NotebookTheme.INK
const RED_INK := NotebookTheme.RED_INK
const MUTED := NotebookTheme.MUTED
const SLOT_COUNT := 10

var mode := "save"
var slot_buttons: Dictionary = {}
var notebook: Control
var scroll: ScrollContainer
var slot_list: VBoxContainer
var title_label: Label
var status_label: Label
var back_button: Button
var delete_button: Button
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
var _pending_action := ""
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
	_pending_action = ""
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
	_pending_action = ""
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
	status_label = _label(notebook, "", Rect2(694, 696, 438, 52), 22, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_button = _button(notebook, "DELETE SAVE", Rect2(764, 758, 300, 52))
	delete_button.name = "DeleteSave"
	delete_button.disabled = true
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		delete_button.add_theme_color_override(state, RED_INK)
	delete_button.pressed.connect(_request_delete)
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
	delete_button.disabled = not exists
	delete_button.focus_mode = Control.FOCUS_ALL if exists else Control.FOCUS_NONE
	var selected_button: Button = slot_buttons.get(slot)
	if selected_button != null:
		delete_button.focus_neighbor_left = delete_button.get_path_to(selected_button)
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
	var preview: Texture2D = _preview(str(entry.get("preview_path", ""))) if exists else null
	var button := SlotCard.build(slot, entry, mode, _can_save, preview)
	slot_list.add_child(button)
	slot_buttons[slot] = button
	button.focus_neighbor_right = button.get_path_to(delete_button)
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
	_pending_action = mode
	confirmation_text.text = "Load Slot %02d?\nUnsaved progress will be lost." % slot if mode == "load" else "Overwrite Slot %02d?\nThis will replace the previous save." % slot
	confirm_button.text = "LOAD" if mode == "load" else "OVERWRITE"
	confirmation.show()
	_set_picker_focus(false)
	cancel_button.grab_focus()


func _request_delete() -> void:
	if confirmation.visible or not visible or not bool(_slot_data(_selected_slot).get("exists", false)):
		return
	_pending_slot = _selected_slot
	_pending_action = "delete"
	confirmation_text.text = "Delete Slot %02d?\nThis cannot be undone." % _pending_slot
	confirm_button.text = "DELETE"
	confirmation.show()
	_set_picker_focus(false)
	cancel_button.grab_focus()


func _confirm_slot() -> void:
	var slot := _pending_slot
	var action := _pending_action
	_pending_slot = 0
	_pending_action = ""
	confirmation.hide()
	_set_picker_focus(true)
	if slot < 1 or slot > SLOT_COUNT:
		return
	if action == "delete":
		delete_requested.emit(slot)
		back_button.grab_focus()
	elif action == "load":
		load_requested.emit(slot)
	elif action == "save":
		save_requested.emit(slot)


func _hide_confirmation() -> void:
	var deleting := _pending_action == "delete"
	confirmation.hide()
	var button: Button = delete_button if deleting else slot_buttons.get(_pending_slot)
	_pending_slot = 0
	_pending_action = ""
	_show_slot_details(_selected_slot)
	_set_picker_focus(true)
	if button != null and not button.disabled:
		button.grab_focus()
	else:
		back_button.grab_focus()


func _set_picker_focus(enabled: bool) -> void:
	back_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	delete_button.focus_mode = Control.FOCUS_ALL if enabled and not delete_button.disabled else Control.FOCUS_NONE
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


func _label(parent: Control, text: String, rect: Rect2, font_size: int, color := INK) -> Label:
	return NotebookTheme.label(parent, text, rect, font_size, color)


func _button(parent: Control, text: String, rect: Rect2) -> Button:
	return NotebookTheme.button(parent, text, rect)


func _style_button(button: Button, selected := false) -> void:
	NotebookTheme.style_button(button, selected)


func _fill(control: Control, margin: float) -> void:
	NotebookTheme.fill(control, margin)
