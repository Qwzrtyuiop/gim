extends RefCounted

const UI_FONT := preload("res://assets/fonts/game_font.tres")


static func make_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("outline_size", mini(outline_size, 2))
	return label
