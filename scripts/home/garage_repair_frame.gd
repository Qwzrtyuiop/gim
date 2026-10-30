extends Control

# A pixel-edged workshop panel. The wrench art remains the focal point.
const INK := Color("111715")
const STEEL := Color("252d2a")
const BRASS := Color("a59062")
const TEXT := Color("f1dfb5")
const SECONDARY_TEXT := Color("bdc8b8")
const SUCCESS_TEXT := Color("c4e39a")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	# Stepped corners and square hardware match the game's pixel artwork.
	draw_colored_polygon(_cut_rect(Rect2(Vector2(6, 7), size), 10), Color(0, 0, 0, 0.5))
	var outer := _cut_rect(Rect2(Vector2.ZERO, size), 10)
	draw_colored_polygon(outer, INK)
	draw_colored_polygon(_cut_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), 7), STEEL)
	_stroke(outer, BRASS, 2)
	_stroke(_cut_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), 7), Color("4f5a4b"), 1)

	# Warm lamp-lit header above a recessed, darker work surface.
	draw_colored_polygon(_cut_rect(Rect2(9, 9, size.x - 18, 119), 5), Color("34372d"))
	draw_line(Vector2(24, 129), Vector2(size.x - 24, 129), Color("746747"), 2)
	var recess := Rect2(28, 138, size.x - 56, 149)
	draw_rect(recess, Color("151e1b"))
	draw_rect(recess, Color("485348"), false, 2)
	draw_line(recess.position + Vector2(2, 2), Vector2(recess.end.x - 2, recess.position.y + 2), Color("0c1310"), 2)
	for row in range(145, 283, 8):
		draw_line(Vector2(32, row), Vector2(size.x - 32, row), Color(0.37, 0.42, 0.35, 0.06), 1)

	# Small brass marks frame the readout without competing with its text.
	for edge_x in [30.0, size.x - 62.0]:
		draw_rect(Rect2(edge_x, 311, 32, 3), Color("827148"))
	draw_line(Vector2(28, 337), Vector2(size.x - 28, 337), Color("404a3e"), 1)
	for bolt_at in [Vector2(14, 14), Vector2(size.x - 22, 14), Vector2(14, size.y - 22), size - Vector2(22, 22)]:
		draw_rect(Rect2(bolt_at + Vector2.ONE, Vector2(9, 9)), INK)
		draw_rect(Rect2(bolt_at, Vector2(8, 8)), Color("818777"))
		draw_line(bolt_at + Vector2(2, 4), bolt_at + Vector2(6, 4), Color("303b32"), 2)


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
