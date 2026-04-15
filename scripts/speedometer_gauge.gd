extends Control

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SPEED_COLOR := Color(0.98, 0.86, 0.32, 1.0)
const LABEL_COLOR := Color(0.95, 0.96, 0.88, 1.0)
const DIAL_BG_COLOR := Color(0.03, 0.04, 0.05, 0.92)
const DIAL_BG_RING_COLOR := Color(0.16, 0.18, 0.20, 0.88)

var speed_kmh := 0
var speed_ratio := 0.0
var distance_m := 0
var target_distance_m := 1000
var time_left_s := 45.0


func _ready() -> void:
	custom_minimum_size = Vector2(340.0, 200.0)


func set_values(new_speed_kmh: int, new_speed_ratio: float, new_distance_m: int, new_target_distance_m: int, new_time_left_s: float) -> void:
	speed_kmh = new_speed_kmh
	speed_ratio = clampf(new_speed_ratio, 0.0, 1.0)
	distance_m = new_distance_m
	target_distance_m = new_target_distance_m
	time_left_s = new_time_left_s
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	var dial_rect := bounds.grow(-6.0)
	var center := dial_rect.position + Vector2(dial_rect.size.x * 0.5, dial_rect.size.y * 0.54)
	var radius := minf(dial_rect.size.x, dial_rect.size.y) * 0.40
	var start_angle := deg_to_rad(210.0)
	var end_angle := deg_to_rad(510.0)

	draw_circle(center + Vector2(0.0, 8.0), radius + 26.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(center, radius + 24.0, DIAL_BG_COLOR)
	draw_arc(center, radius + 24.0, 0.0, TAU, 64, DIAL_BG_RING_COLOR, 3.0)
	draw_arc(center, radius + 6.0, start_angle, end_angle, 44, Color(0.0, 0.0, 0.0, 0.6), 14.0)
	_draw_speed_segments(center, radius, start_angle, end_angle)
	_draw_ticks(center, radius, start_angle, end_angle)
	_draw_needle(center, radius, start_angle, end_angle)

	draw_circle(center, 6.0, Color(0.70, 0.64, 0.48, 1.0))
	draw_circle(center, 3.0, Color(0.04, 0.05, 0.06, 1.0))

	_draw_text("SPEED", Vector2(dial_rect.position.x, dial_rect.position.y + 6.0), 10, LABEL_COLOR, dial_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("%03d" % speed_kmh, Vector2(dial_rect.position.x, center.y + radius * 0.60), 22, SPEED_COLOR, dial_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("KM/H", Vector2(dial_rect.position.x, dial_rect.position.y + dial_rect.size.y - 18.0), 10, LABEL_COLOR, dial_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_speed_segments(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	var segment_count := 12
	for index in range(segment_count):
		var segment_start := lerpf(start_angle, end_angle, float(index) / segment_count)
		var segment_end := lerpf(start_angle, end_angle, float(index + 1) / segment_count) - deg_to_rad(2.2)
		var color := Color(0.18, 0.62, 0.38, 1.0)
		if index >= 6:
			color = Color(0.72, 0.54, 0.18, 1.0)
		if index >= 9:
			color = Color(0.68, 0.20, 0.16, 1.0)

		var alpha := 0.18
		if float(index + 1) / segment_count <= speed_ratio:
			alpha = 0.92
		draw_arc(center, radius, segment_start, segment_end, 6, Color(color.r, color.g, color.b, alpha), 10.0)


func _draw_ticks(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	for index in range(0, 11):
		var t := float(index) / 10.0
		var angle := lerpf(start_angle, end_angle, t)
		var inner := center + Vector2(cos(angle), sin(angle)) * (radius - 14.0)
		var outer := center + Vector2(cos(angle), sin(angle)) * (radius - 4.0)
		draw_line(inner, outer, Color(0.84, 0.84, 0.80, 0.55), 2.0)


func _draw_needle(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	var angle := lerpf(start_angle, end_angle, speed_ratio)
	var tip := center + Vector2(cos(angle), sin(angle)) * (radius - 14.0)
	var tail := center - Vector2(cos(angle), sin(angle)) * 12.0
	draw_line(tail, tip, Color(0.90, 0.26, 0.18, 1.0), 4.0)
	draw_line(tail, tip, Color(1.0, 0.92, 0.62, 0.5), 2.0)


func _draw_text(text: String, position: Vector2, font_size: int, color: Color, width: float = -1.0, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(UI_FONT, position + Vector2(1.0, 0.0), text, alignment, width, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position + Vector2(-1.0, 0.0), text, alignment, width, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position + Vector2(0.0, 1.0), text, alignment, width, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position + Vector2(0.0, -1.0), text, alignment, width, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position, text, alignment, width, font_size, color)
