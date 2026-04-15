extends Control

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SPEED_COLOR := Color(0.98, 0.86, 0.32, 1.0)
const LABEL_COLOR := Color(0.95, 0.96, 0.88, 1.0)
const DISTANCE_LABEL_COLOR := Color(0.72, 0.92, 0.88, 1.0)
const DISTANCE_VALUE_COLOR := Color(0.60, 0.95, 0.80, 1.0)
const TIME_LABEL_COLOR := Color(0.78, 0.92, 0.94, 1.0)
const PANEL_BORDER_COLOR := Color(0.46, 0.38, 0.22, 0.92)
const PANEL_BG_COLOR := Color(0.04, 0.05, 0.06, 0.94)
const PANEL_INNER_COLOR := Color(0.10, 0.12, 0.14, 0.94)
const BAR_BG_COLOR := Color(0.12, 0.14, 0.16, 0.92)
const BAR_FILL_COLOR := Color(0.32, 0.92, 0.66, 1.0)

var speed_kmh := 0
var speed_ratio := 0.0
var distance_m := 0
var target_distance_m := 1000
var time_left_s := 45.0


func _ready() -> void:
	custom_minimum_size = Vector2(420.0, 190.0)


func set_values(new_speed_kmh: int, new_speed_ratio: float, new_distance_m: int, new_target_distance_m: int, new_time_left_s: float) -> void:
	speed_kmh = new_speed_kmh
	speed_ratio = clampf(new_speed_ratio, 0.0, 1.0)
	distance_m = new_distance_m
	target_distance_m = new_target_distance_m
	time_left_s = new_time_left_s
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	if outer.size.x <= 0.0 or outer.size.y <= 0.0:
		return

	draw_rect(outer, PANEL_BG_COLOR, true)
	draw_rect(outer, PANEL_BORDER_COLOR, false, 2.0)

	var inner := outer.grow(-6.0)
	draw_rect(inner, PANEL_INNER_COLOR, true)

	var padding := 10.0
	var gap := 16.0
	var left_width := inner.size.x * 0.40
	var left_rect := Rect2(inner.position + Vector2(padding, padding), Vector2(left_width - padding, inner.size.y - padding * 2.0))
	var right_rect := Rect2(
		Vector2(inner.position.x + left_width + gap, inner.position.y + padding),
		Vector2(inner.size.x - left_width - gap - padding, inner.size.y - padding * 2.0)
	)
	draw_line(
		Vector2(right_rect.position.x - gap * 0.5, inner.position.y + 10.0),
		Vector2(right_rect.position.x - gap * 0.5, inner.position.y + inner.size.y - 10.0),
		Color(0.0, 0.0, 0.0, 0.45),
		1.0
	)

	var center := left_rect.position + Vector2(left_rect.size.x * 0.5, left_rect.size.y * 0.50)
	var radius := minf(left_rect.size.x, left_rect.size.y) * 0.34
	var start_angle := deg_to_rad(210.0)
	var end_angle := deg_to_rad(510.0)

	draw_arc(center, radius + 6.0, start_angle, end_angle, 44, Color(0.0, 0.0, 0.0, 0.6), 14.0)
	_draw_speed_segments(center, radius, start_angle, end_angle)
	_draw_ticks(center, radius, start_angle, end_angle)
	_draw_needle(center, radius, start_angle, end_angle)

	draw_circle(center, 6.0, Color(0.70, 0.64, 0.48, 1.0))
	draw_circle(center, 3.0, Color(0.04, 0.05, 0.06, 1.0))

	_draw_text("SPEED", left_rect.position + Vector2(0.0, 4.0), 10, LABEL_COLOR, left_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var speed_plate_size := Vector2(left_rect.size.x * 0.62, 24.0)
	var speed_plate_pos := Vector2(
		center.x - speed_plate_size.x * 0.5,
		center.y + radius * 0.52
	)
	draw_rect(Rect2(speed_plate_pos, speed_plate_size), Color(0.02, 0.03, 0.04, 0.85), true)
	draw_rect(Rect2(speed_plate_pos, speed_plate_size), Color(0.0, 0.0, 0.0, 0.65), false, 1.0)
	_draw_text("%03d" % speed_kmh, speed_plate_pos + Vector2(0.0, 2.0), 18, SPEED_COLOR, speed_plate_size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("KM/H", left_rect.position + Vector2(0.0, left_rect.size.y - 20.0), 9, LABEL_COLOR, left_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	var distance_label_y := right_rect.position.y + 2.0
	_draw_text("DISTANCE", Vector2(right_rect.position.x, distance_label_y), 8, DISTANCE_LABEL_COLOR, right_rect.size.x, HORIZONTAL_ALIGNMENT_LEFT)

	var bar_rect := Rect2(right_rect.position + Vector2(0.0, 20.0), Vector2(right_rect.size.x, 14.0))
	draw_rect(bar_rect, BAR_BG_COLOR, true)
	draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.65), false, 1.0)
	var distance_ratio := 0.0
	if target_distance_m > 0:
		distance_ratio = clampf(float(distance_m) / float(target_distance_m), 0.0, 1.0)
	var fill_rect := Rect2(bar_rect.position, Vector2(bar_rect.size.x * distance_ratio, bar_rect.size.y))
	draw_rect(fill_rect, BAR_FILL_COLOR, true)

	_draw_text("%04dM / %04dM" % [distance_m, target_distance_m], right_rect.position + Vector2(0.0, 42.0), 11, DISTANCE_VALUE_COLOR, right_rect.size.x, HORIZONTAL_ALIGNMENT_LEFT)

	var time_label_y := right_rect.position.y + 72.0
	_draw_text("TIME LEFT", Vector2(right_rect.position.x, time_label_y), 8, TIME_LABEL_COLOR, right_rect.size.x, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_text("%04.1f" % time_left_s, right_rect.position + Vector2(0.0, time_label_y + 18.0), 17, LABEL_COLOR, right_rect.size.x, HORIZONTAL_ALIGNMENT_LEFT)


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
