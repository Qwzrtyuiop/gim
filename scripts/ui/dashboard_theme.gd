extends RefCounted

# Shared artwork for the hub status display and its navigation controls.
const BIG_MENU := preload("res://assets/ui/buttons/dashboard/BigMenu.png")
const SMALL_BUTTON := preload("res://assets/ui/buttons/dashboard/smallButton.png")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const INK := Color("392719")
const BUTTON_SIZE := Vector2(168, 44)


static func header_style() -> StyleBoxTexture:
	var style := _texture_style(BIG_MENU)
	# Keep the writing inside the paper, clear of the tape and torn edges.
	style.content_margin_left = 52
	style.content_margin_right = 52
	style.content_margin_top = 32
	style.content_margin_bottom = 30
	return style


static func apply_button(button: Button) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := _texture_style(SMALL_BUTTON)
		style.content_margin_left = 30
		style.content_margin_right = 30
		style.content_margin_top = 13
		style.content_margin_bottom = 11
		match state:
			"hover":
				style.modulate_color = Color(1.13, 1.09, 0.98)
			"pressed":
				style.modulate_color = Color(0.82, 0.73, 0.59)
			"disabled":
				style.modulate_color = Color(0.65, 0.65, 0.65, 0.7)
		button.add_theme_stylebox_override(state, style)
	# Focus overlays the paper itself, retaining its torn silhouette.
	var focus := _texture_style(SMALL_BUTTON)
	focus.modulate_color = Color(1.25, 1.12, 0.86, 0.5)
	button.add_theme_stylebox_override("focus", focus)
	for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, INK)
	button.add_theme_color_override("font_disabled_color", Color("746858"))
	button.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	button.add_theme_constant_override("outline_size", 0)


static func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
