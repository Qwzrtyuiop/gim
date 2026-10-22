extends Control

signal closed

const DESIGN_SIZE := Vector2(376, 668)
const INK := Color("4b2d19")
const RED_INK := Color("873d2c")
const FADED_INK := Color("86603b")
const FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")

var day_label: Label
var phase_label: Label
var week_label: Label
var goal_label: Label
var debt_label: Label
var due_label: Label
var countdown_label: Label
var day_numbers: Array[Label] = []
var close_button: Button
var current_slot := 0


func _ready() -> void:
	size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label("CALENDAR", Rect2(32, 102, 312, 22), 18, FADED_INK)
	day_label = _label("", Rect2(32, 125, 312, 68), 56, RED_INK)
	phase_label = _label("", Rect2(32, 193, 312, 27), 23)
	week_label = _label("", Rect2(32, 233, 312, 22), 18, FADED_INK)
	var interval: int = maxi(1, PlayerState.DEBT_COLLECTION_INTERVAL_DAYS)
	var cell_width := 304.0 / interval
	for index in range(interval):
		day_numbers.append(_label("", Rect2(36 + index * cell_width, 263, cell_width, 34), 22))
	_label("WEEKLY GOAL", Rect2(36, 325, 304, 22), 18, FADED_INK)
	goal_label = _label("", Rect2(36, 349, 304, 42), 34)
	_label("DEBT REMAINING", Rect2(36, 411, 304, 22), 18, FADED_INK)
	debt_label = _label("", Rect2(36, 435, 304, 36), 28)
	due_label = _label("", Rect2(38, 500, 300, 26), 23, RED_INK)
	countdown_label = _label("", Rect2(38, 528, 300, 22), 18, RED_INK)
	close_button = Button.new()
	close_button.text = "PUT AWAY"
	close_button.position = Vector2(93, 580)
	close_button.size = Vector2(190, 38)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.30, 0.17, 0.08, 0.13 if state != "normal" else 0.0)
		style.border_color = INK
		style.set_border_width_all(2)
		close_button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		close_button.add_theme_color_override(state, INK)
	close_button.pressed.connect(func() -> void: closed.emit())
	add_child(close_button)
	ButtonGlow.attach(self, close_button)
	refresh()


func _label(text: String, rect: Rect2, font_size: int, color := INK) -> Label:
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
	add_child(label)
	return label


func refresh() -> void:
	var day: int = PlayerState.get_current_day()
	var interval: int = maxi(1, PlayerState.DEBT_COLLECTION_INTERVAL_DAYS)
	current_slot = (day - 1) % interval
	day_label.text = "DAY %d" % day
	phase_label.text = PlayerState.get_current_time_of_day().capitalize()
	week_label.text = "WEEK %d" % PlayerState.get_week_number()
	for index in range(day_numbers.size()):
		day_numbers[index].text = str(day - current_slot + index)
		day_numbers[index].add_theme_color_override("font_color", RED_INK if index == current_slot else FADED_INK)
	goal_label.text = "PhP %s" % _money(PlayerState.get_current_weekly_goal())
	debt_label.text = "PhP %s" % _money(PlayerState.get_total_debt_goal())
	var days_left: int = PlayerState.get_days_until_debt_collection()
	due_label.text = "COLLECTION / DAY %d" % (day + days_left)
	countdown_label.text = "%d %s remaining" % [days_left, "day" if days_left == 1 else "days"]
	if PlayerState.get_total_debt_goal() <= 0:
		due_label.text = "PAID IN FULL"
		countdown_label.text = "No debt remaining"
	queue_redraw()


func _money(amount: int) -> String:
	var digits := str(amount)
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result


func _draw() -> void:
	for y in [313.0, 401.0, 482.0]:
		draw_line(Vector2(36, y), Vector2(340, y), Color(0.40, 0.25, 0.12, 0.45), 1.0)
	var cell_width := 304.0 / maxi(1, day_numbers.size())
	for index in range(day_numbers.size()):
		var cell := Rect2(38 + index * cell_width, 263, cell_width - 4, 34)
		if index == current_slot:
			draw_rect(cell, Color(0.53, 0.24, 0.17, 0.10))
			draw_rect(cell, RED_INK, false, 2.0)
		elif index < current_slot:
			draw_line(cell.position + Vector2(7, 27), cell.end - Vector2(7, 27), FADED_INK, 1.0)
	draw_rect(Rect2(36, 496, 304, 60), RED_INK, false, 2.0)
