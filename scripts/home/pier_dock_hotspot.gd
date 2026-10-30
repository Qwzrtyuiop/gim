extends Button

const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const ART_SIZE := Vector2(1670, 941)
# Hand-traced from pierselect.png; both lighting variants share these areas.
const DOCK := [
	Vector2(349, 369), Vector2(365, 360), Vector2(365, 344),
	Vector2(376, 338), Vector2(384, 343), Vector2(385, 351),
	Vector2(395, 351), Vector2(400, 347), Vector2(400, 332),
	Vector2(405, 326), Vector2(441, 326), Vector2(448, 330),
	Vector2(449, 344), Vector2(454, 344), Vector2(455, 314),
	Vector2(496, 314), Vector2(499, 344), Vector2(529, 344),
	Vector2(504, 375), Vector2(350, 373),
]
const SHOP := [
	Vector2(986, 614), Vector2(1124, 484), Vector2(1277, 517),
	Vector2(1337, 565), Vector2(1337, 571), Vector2(1295, 581),
	Vector2(1298, 762), Vector2(1167, 809), Vector2(1155, 809),
	Vector2(1104, 789), Vector2(1094, 793), Vector2(1017, 765),
	Vector2(1019, 628),
]

var selection_id := "dock"
var _highlight_mode := InputHighlightMode.new()


func _ready() -> void:
	name = "PierFishingShop" if selection_id == "shop" else "PierFishingDock"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Fishing shop" if selection_id == "shop" else "Fish from the dock"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for changed: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		changed.connect(queue_redraw)
	visibility_changed.connect(_clear_highlight)
	hide()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and not disabled and _highlight_mode.handle_input(event):
		queue_redraw()


func _has_point(point: Vector2) -> bool:
	return not disabled and size.x > 0.0 and size.y > 0.0 and Geometry2D.is_point_in_polygon(point / size * ART_SIZE, _source_polygon())


func _source_polygon() -> PackedVector2Array:
	return PackedVector2Array(SHOP if selection_id == "shop" else DOCK)


func _draw() -> void:
	if disabled or not (has_focus() if _highlight_mode.keyboard_active else is_hovered()):
		return
	var polygon := PackedVector2Array()
	for point: Vector2 in _source_polygon():
		polygon.append(point / ART_SIZE * size)
	draw_colored_polygon(polygon, Color(1.0, 0.9, 0.3, 0.08))
	polygon.append(polygon[0])
	draw_polyline(polygon, Color("ffe28a"), 2.0, false)


func _clear_highlight() -> void:
	if not is_visible_in_tree():
		release_focus()
		_highlight_mode.reset()
	queue_redraw()
