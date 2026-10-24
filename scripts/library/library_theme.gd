extends RefCounted

# Shared library styling, with each screen's existing colors and spacing.

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")


static func apply_gallery_button(button: BaseButton) -> void:
	_apply_button(button, Color(0.22, 0.15, 0.11, 0.94), 12.0)
	button.add_theme_color_override("font_disabled_color", Color(0.92, 0.72, 0.36, 1.0))
	var disabled_style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
	disabled_style.bg_color = Color(0.34, 0.25, 0.15, 0.98)
	button.add_theme_stylebox_override("disabled", disabled_style)


static func apply_achievement_button(button: BaseButton) -> void:
	_apply_button(button, Color(0.25, 0.17, 0.12, 0.94), 14.0)


static func _apply_button(button: BaseButton, bg_color: Color, vertical_margin: float) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	button.add_theme_constant_override("outline_size", 1)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.border_color = Color(0.60, 0.45, 0.26, 1.0)
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 18.0
	normal_style.content_margin_right = 18.0
	normal_style.content_margin_top = vertical_margin
	normal_style.content_margin_bottom = vertical_margin

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(0.83, 0.63, 0.33, 0.98)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = Color(0.35, 0.48, 0.31, 0.98)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)


static func apply_image_button(button: BaseButton) -> void:
	var normal_style := StyleBoxFlat.new()
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


static func apply_panel(panel: Panel, bg_color: Color, corner_radius: int = 10) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.71, 0.56, 0.31, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
