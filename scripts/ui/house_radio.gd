extends Control

signal closed

const DESIGN_SIZE := Vector2(960, 540)
const TEXTURE := preload("res://assets/ui/frames/Radio.png")
const FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const ImageOutline := preload("res://scripts/story/story_portrait_outline.gd")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const CREAM := Color("f5dfac")
const AMBER := Color("efb65e")
const MUTED := Color("c7ab7c")

var day_label: Label
var price_label: Label
var change_label: Label
var today_label: Label
var tomorrow_label: Label
var close_button: Button


func _ready() -> void:
	size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := TextureRect.new()
	background.texture = TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = DESIGN_SIZE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	ImageOutline.apply_to(background)
	_label("TODAY'S NEWS", Rect2(82, 218, 400, 34), 30, AMBER)
	day_label = _label("", Rect2(540, 223, 338, 26), 20, MUTED)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rule(Rect2(82, 261, 796, 1))
	_rule(Rect2(478, 285, 1, 130))
	_label("GAS PRICE", Rect2(94, 284, 360, 26), 21, MUTED)
	price_label = _label("", Rect2(94, 313, 360, 50), 42, CREAM)
	_label("CHANGE SINCE YESTERDAY", Rect2(94, 373, 360, 22), 17, MUTED)
	change_label = _label("", Rect2(94, 397, 360, 30), 23, AMBER)
	_label("WEATHER FORECAST", Rect2(512, 284, 350, 26), 21, AMBER)
	_label("TODAY", Rect2(512, 329, 140, 26), 18, MUTED)
	today_label = _label("", Rect2(656, 325, 206, 34), 29, CREAM)
	_label("TOMORROW", Rect2(512, 382, 140, 26), 18, MUTED)
	tomorrow_label = _label("", Rect2(656, 378, 206, 34), 29, CREAM)
	close_button = Button.new()
	close_button.text = "TURN OFF"
	close_button.position = Vector2(385, 444)
	close_button.size = Vector2(190, 34)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("302419") if state == "normal" else Color("594128")
		style.border_color = MUTED if state == "normal" else AMBER
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		close_button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		close_button.add_theme_color_override(state, CREAM)
	close_button.pressed.connect(func() -> void: closed.emit())
	add_child(close_button)
	ButtonGlow.attach(self, close_button)
	refresh()


func _label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("281c10"))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	return label


func _rule(rect: Rect2) -> void:
	var line := ColorRect.new()
	line.position = rect.position
	line.size = rect.size
	line.color = Color(0.78, 0.63, 0.38, 0.4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)


func refresh() -> void:
	day_label.text = "DAY %d / %s" % [PlayerState.get_current_day(), PlayerState.get_current_time_of_day().to_upper()]
	price_label.text = PlayerState.get_gas_price_text()
	change_label.text = "%s  (%s)" % [PlayerState.get_gas_price_change_text(), PlayerState.get_gas_price_yesterday_percent_text()]
	today_label.text = PlayerState.weather_text(PlayerState.get_today_weather_forecast())
	tomorrow_label.text = PlayerState.weather_text(PlayerState.get_tomorrow_weather_forecast())
