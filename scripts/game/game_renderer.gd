extends RefCounted


static func draw(_canvas: CanvasItem, _distance: float) -> void:
	pass


static func draw_dashed_lane_line(canvas: CanvasItem, y: float, width: float, distance: float) -> void:
	var dash_w := 54.0
	var gap_w := 36.0
	var phase := fmod(distance * 3.2, dash_w + gap_w)
	var x := -dash_w - phase
	while x < width + dash_w:
		canvas.draw_rect(Rect2(x, y - 3.0, dash_w, 6.0), Color(1.0, 1.0, 1.0, 0.68))
		x += dash_w + gap_w
