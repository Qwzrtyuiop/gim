extends Control

# Source-canvas readout below the rod; all reel input passes through it.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const FONT := preload("res://assets/fonts/game_font.tres")
const PRESSURE_WARNING := GameTuning.FISHING_LINE_PRESSURE_WARNING
const PANEL_SIZE := Vector2(1060, 214)
const INK := Color("101815")
const SURFACE := Color("1c2823")
const BRASS := Color("9c895c")
const CREAM := Color("f1dfb5")
const MUTED := Color("b3bba4")
const SUCCESS_COLOR := Color("c4e39a")
const WARNING_COLOR := Color("edb28b")
const DANGER_COLOR := Color("ee8c77")

var _title_text := "Cast your line"
var _detail_text := "Lower the hook toward a fish."
var _status_color := CREAM
var _caught := 0
var _title: Label
var _detail: Label
var _count: Label
var _line_label: Label
var _line_pressure := 0.0
var _line_engaged := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE


func _ready() -> void:
	name = "FishingStatusPanel"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label("CAUGHT", 26, Rect2(20, 26, 176, 32), MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_count = _label(str(_caught), _count_font_size(), Rect2(20, 65, 176, 72), SUCCESS_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_label("fish", 24, Rect2(20, 146, 176, 28), MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_title = _label(_title_text, 32, Rect2(244, 34, 430, 48), _status_color)
	_detail = _label(_detail_text, 28, Rect2(244, 92, 430, 64), CREAM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_line_label = _label("LINE", 20, Rect2(244, 160, 64, 24), DANGER_COLOR if _line_pressure >= PRESSURE_WARNING else MUTED)
	_line_label.visible = _line_engaged
	_label("Hold left click", 22, Rect2(730, 20, 302, 26), MUTED)
	_label("TURN RIGHT", 22, Rect2(784, 60, 248, 26), MUTED)
	_label("Lower hook", 28, Rect2(784, 86, 248, 32), CREAM)
	_label("TURN LEFT", 22, Rect2(784, 128, 248, 26), MUTED)
	_label("Reel in", 28, Rect2(784, 154, 248, 32), CREAM)


func set_status(title: String, detail: String, color: Color = CREAM) -> void:
	if title != _title_text:
		_title_text = title
		if is_instance_valid(_title):
			_title.text = title
	if detail != _detail_text:
		_detail_text = detail
		if is_instance_valid(_detail):
			_detail.text = detail
	if color != _status_color:
		_status_color = color
		if is_instance_valid(_title):
			_title.add_theme_color_override("font_color", color)


func set_caught(count: int) -> void:
	var safe_count := maxi(0, count)
	if safe_count == _caught:
		return
	_caught = safe_count
	if is_instance_valid(_count):
		_count.text = str(_caught)
		var font_size := _count_font_size()
		if _count.get_theme_font_size("font_size") != font_size:
			_count.add_theme_font_size_override("font_size", font_size)


func _count_font_size() -> int:
	return mini(60, maxi(22, floori(160.0 / float(maxi(1, str(_caught).length())))))


func set_line_pressure(value: float, engaged: bool) -> void:
	var pressure := clampf(value, 0.0, 1.0)
	if is_equal_approx(pressure, _line_pressure) and engaged == _line_engaged:
		return
	var was_warning := _line_pressure >= PRESSURE_WARNING
	_line_pressure = pressure
	_line_engaged = engaged
	if is_instance_valid(_line_label):
		_line_label.visible = engaged
		if was_warning != (pressure >= PRESSURE_WARNING):
			_line_label.add_theme_color_override("font_color", DANGER_COLOR if pressure >= PRESSURE_WARNING else MUTED)
	queue_redraw()


func _label(text: String, font_size: int, rect: Rect2, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 1)
	add_child(label)
	return label


func _draw() -> void:
	# Stepped borders and a subdued wood-toned inset match the pier's pixel art.
	draw_colored_polygon(_cut_rect(Rect2(6, 7, 1060, 214), 10), Color(0, 0, 0, 0.38))
	var outer := _cut_rect(Rect2(Vector2.ZERO, PANEL_SIZE), 10)
	draw_colored_polygon(outer, INK)
	draw_colored_polygon(_cut_rect(Rect2(4, 4, 1052, 206), 8), SURFACE)
	_stroke(outer, BRASS, 2)
	_stroke(_cut_rect(Rect2(5, 5, 1050, 204), 6), Color("455044"), 1)
	var catch_inset := _cut_rect(Rect2(20, 20, 176, 174), 6)
	draw_colored_polygon(catch_inset, Color("33392b"))
	_stroke(catch_inset, Color("665e40"), 1)
	draw_line(Vector2(30, 22), Vector2(186, 22), Color("81734c"), 1)
	for divider_x in [216.0, 700.0]:
		draw_line(Vector2(divider_x, 26), Vector2(divider_x, 188), Color("4c5543"), 2)
		draw_line(Vector2(divider_x + 3, 26), Vector2(divider_x + 3, 188), INK, 1)
	draw_line(Vector2(730, 51), Vector2(1032, 51), Color("3d493b"), 1)
	_draw_turn_arrow(Vector2(749, 91), true)
	_draw_turn_arrow(Vector2(749, 159), false)
	if _line_engaged:
		_draw_line_pressure()
	for corner in [Vector2(12, 12), Vector2(1044, 12), Vector2(12, 198), Vector2(1044, 198)]:
		draw_rect(Rect2(corner, Vector2(4, 4)), BRASS)


func _draw_line_pressure() -> void:
	var bar := Rect2(322, 167, 350, 12)
	draw_rect(bar, INK)
	var amber := Color("e4bd6e")
	var fill_color := SUCCESS_COLOR.lerp(amber, clampf(_line_pressure / PRESSURE_WARNING, 0.0, 1.0))
	if _line_pressure >= PRESSURE_WARNING:
		fill_color = amber.lerp(DANGER_COLOR, clampf((_line_pressure - PRESSURE_WARNING) / (1.0 - PRESSURE_WARNING), 0.0, 1.0))
	var fill_width := floorf((bar.size.x - 4) * _line_pressure)
	if fill_width > 0:
		draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2(fill_width, 8)), fill_color)
	draw_rect(bar, DANGER_COLOR if _line_pressure >= PRESSURE_WARNING else Color("52604d"), false, 1)


func _draw_turn_arrow(center: Vector2, clockwise: bool) -> void:
	var direction := 1.0 if clockwise else -1.0
	var points := PackedVector2Array()
	for step in range(19):
		var angle := lerpf(-2.5, 2.2, float(step) / 18.0) * direction
		points.append(center + Vector2(cos(angle), sin(angle)) * 16)
	draw_polyline(points, BRASS, 3, false)
	var tip := points[points.size() - 1]
	var tangent := (tip - points[points.size() - 2]).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	draw_colored_polygon(PackedVector2Array([tip + tangent * 3, tip - tangent * 7 + normal * 6, tip - tangent * 7 - normal * 6]), CREAM)


func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, false)


func _cut_rect(rect: Rect2, cut: float) -> PackedVector2Array:
	var at := rect.position
	var end := rect.end
	return PackedVector2Array([
		Vector2(at.x + cut, at.y), Vector2(end.x - cut, at.y),
		Vector2(end.x, at.y + cut), Vector2(end.x, end.y - cut),
		Vector2(end.x - cut, end.y), Vector2(at.x + cut, end.y),
		Vector2(at.x, end.y - cut), Vector2(at.x, at.y + cut),
	])
