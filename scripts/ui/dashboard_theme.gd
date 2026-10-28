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


# Bottom navigation keeps its reading order and scales as one row when needed.
static func layout_button_row(buttons: Array, viewport_size: Vector2) -> Rect2:
	var visible_buttons: Array[Button] = []
	var button_size := BUTTON_SIZE
	for candidate in buttons:
		var button := candidate as Button
		if button == null:
			continue
		button.scale = Vector2.ONE
		if button.visible:
			visible_buttons.append(button)
			button_size = button_size.max(button.get_combined_minimum_size())
	if visible_buttons.is_empty():
		return Rect2()
	var gap := 12.0
	var row_width := button_size.x * visible_buttons.size() + gap * (visible_buttons.size() - 1)
	var available := (viewport_size - Vector2(40, 32)).max(Vector2.ONE)
	var fit := minf(1.0, minf(available.x / row_width, available.y / button_size.y))
	var row_size := Vector2(row_width, button_size.y) * fit
	var origin := Vector2(20.0, maxf(0.0, viewport_size.y - 16.0 - row_size.y))
	for index in range(visible_buttons.size()):
		var button := visible_buttons[index]
		button.pivot_offset = Vector2.ZERO
		button.size = button_size
		button.scale = Vector2.ONE * fit
		button.position = origin + Vector2(index * (button_size.x + gap) * fit, 0.0)
		var previous := visible_buttons[posmod(index - 1, visible_buttons.size())]
		var next := visible_buttons[(index + 1) % visible_buttons.size()]
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_previous = button.focus_neighbor_left
		button.focus_next = button.focus_neighbor_right
	return Rect2(origin, row_size)


static func _texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
