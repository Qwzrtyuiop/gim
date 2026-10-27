extends RefCounted

# Notebook widgets share immutable styles; hovering never allocates new styles.
const FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const INK := Color("4b2d19")
const RED_INK := Color("873d2c")
const MUTED := Color("86603b")

static var _normal_style: StyleBoxFlat
static var _active_style: StyleBoxFlat
static var _selected_style: StyleBoxFlat


static func label(parent: Control, text: String, rect: Rect2, font_size: int, color := INK) -> Label:
	var widget := Label.new()
	widget.text = text
	widget.position = rect.position
	widget.size = rect.size
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	widget.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	widget.add_theme_font_override("font", FONT)
	widget.add_theme_font_size_override("font_size", font_size)
	widget.add_theme_color_override("font_color", color)
	parent.add_child(widget)
	return widget


static func row_label(parent: Control, text: String, top: float, height: float, font_size: int, color: Color) -> Label:
	var widget := label(parent, text, Rect2(164, top, 0, height), font_size, color)
	widget.anchor_right = 1.0
	widget.offset_right = -14
	widget.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	widget.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return widget


static func button(parent: Control, text: String, rect: Rect2) -> Button:
	var widget := Button.new()
	widget.text = text
	widget.position = rect.position
	widget.size = rect.size
	widget.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	widget.add_theme_font_override("font", FONT)
	widget.add_theme_font_size_override("font_size", 25)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		widget.add_theme_color_override(state, INK)
	style_button(widget)
	parent.add_child(widget)
	UIAudioManager.attach_button(widget)
	return widget


static func style_button(widget: Button, selected := false) -> void:
	if _normal_style == null:
		_normal_style = _make_style(false, false)
		_active_style = _make_style(true, false)
		_selected_style = _make_style(true, true)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var active: bool = state in ["hover", "pressed", "focus"]
		widget.add_theme_stylebox_override(state, _selected_style if selected else (_active_style if active else _normal_style))


static func fill(control: Control, margin: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = -margin
	control.offset_bottom = -margin


static func _make_style(active: bool, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.17, 0.08, 0.12 if active else 0.035)
	style.border_color = RED_INK if active else Color(0.30, 0.17, 0.08, 0.35)
	style.set_border_width_all(2 if active else 1)
	if selected:
		style.border_width_left = 5
	return style
