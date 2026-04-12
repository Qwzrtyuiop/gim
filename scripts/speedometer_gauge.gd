extends Control

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var speed_kmh := 0
var speed_ratio := 0.0
var distance_m := 0
var target_distance_m := 1000
var time_left_s := 45.0


func _ready() -> void:
	custom_minimum_size = Vector2(310.0, 190.0)


func set_values(new_speed_kmh: int, new_speed_ratio: float, new_distance_m: int, new_target_distance_m: int, new_time_left_s: float) -> void:
	speed_kmh = new_speed_kmh
	speed_ratio = clampf(new_speed_ratio, 0.0, 1.0)
	distance_m = new_distance_m
	target_distance_m = new_target_distance_m
	time_left_s = new_time_left_s
	queue_redraw()


func _draw() -> void:
	var center := Vector2(106.0, 112.0)
	var radius := 76.0
	var start_angle := deg_to_rad(210.0)
	var end_angle := deg_to_rad(510.0)

	draw_arc(center, radius, start_angle, end_angle, 48, Color(0.0, 0.0, 0.0, 0.64), 16.0)
	_draw_speed_segments(center, radius, start_angle, end_angle)
	_draw_ticks(center, radius, start_angle, end_angle)
	_draw_needle(center, radius, start_angle, end_angle)

	draw_circle(center, 8.0, Color(0.95, 0.92, 0.72, 1.0))
	draw_circle(center, 4.0, Color(0.08, 0.08, 0.09, 1.0))

	_draw_text("SPEED", Vector2(22.0, 18.0), 13, Color(0.95, 0.96, 0.88, 1.0))
	_draw_text("%03d" % speed_kmh, Vector2(196.0, 52.0), 24, Color(0.98, 0.86, 0.32, 1.0))
	_draw_text("KM/H", Vector2(203.0, 88.0), 12, Color(0.95, 0.96, 0.88, 1.0))

	_draw_text("TIME", Vector2(196.0, 124.0), 10, Color(0.78, 0.92, 0.94, 1.0))
	_draw_text("%04.1f" % time_left_s, Vector2(196.0, 143.0), 13, Color(0.95, 0.96, 0.88, 1.0))
	_draw_text("DIST %04d/%04d" % [distance_m, target_distance_m], Vector2(22.0, 164.0), 10, Color(0.95, 0.96, 0.88, 1.0))


func _draw_speed_segments(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	var segment_count := 12
	for index in range(segment_count):
		var segment_start := lerpf(start_angle, end_angle, float(index) / segment_count)
		var segment_end := lerpf(start_angle, end_angle, float(index + 1) / segment_count) - deg_to_rad(2.2)
		var color := Color(0.26, 0.88, 0.30, 1.0)
		if index >= 6:
			color = Color(0.94, 0.82, 0.22, 1.0)
		if index >= 9:
			color = Color(0.82, 0.20, 0.18, 1.0)

		var alpha := 0.28
		if float(index + 1) / segment_count <= speed_ratio:
			alpha = 1.0
		draw_arc(center, radius, segment_start, segment_end, 6, Color(color.r, color.g, color.b, alpha), 12.0)


func _draw_ticks(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	for index in range(0, 11):
		var t := float(index) / 10.0
		var angle := lerpf(start_angle, end_angle, t)
		var inner := center + Vector2(cos(angle), sin(angle)) * (radius - 18.0)
		var outer := center + Vector2(cos(angle), sin(angle)) * (radius - 5.0)
		draw_line(inner, outer, Color(0.94, 0.94, 0.84, 0.92), 3.0)


func _draw_needle(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	var angle := lerpf(start_angle, end_angle, speed_ratio)
	var tip := center + Vector2(cos(angle), sin(angle)) * (radius - 22.0)
	var tail := center - Vector2(cos(angle), sin(angle)) * 16.0
	draw_line(tail, tip, Color(0.96, 0.18, 0.15, 1.0), 5.0)
	draw_line(tail, tip, Color(1.0, 0.95, 0.70, 0.72), 2.0)


func _draw_text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(UI_FONT, position + Vector2(1.0, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position + Vector2(-1.0, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position + Vector2(0.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position + Vector2(0.0, -1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(UI_FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
