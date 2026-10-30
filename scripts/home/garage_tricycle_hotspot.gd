extends Button

# Trace the tricycle's yellow outline in garageselect.png, shared by both phases.
const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const ART_SIZE := Vector2(1672, 941)
const OUTLINE := [
	Vector2(722, 254), Vector2(882, 279), Vector2(941, 296),
	Vector2(965, 361), Vector2(1002, 452), Vector2(996, 531),
	Vector2(989, 581), Vector2(1017, 628), Vector2(1015, 742),
	Vector2(995, 735), Vector2(976, 758), Vector2(955, 770),
	Vector2(918, 762), Vector2(900, 751), Vector2(878, 701),
	Vector2(857, 685), Vector2(830, 689), Vector2(820, 709),
	Vector2(779, 721), Vector2(712, 726), Vector2(671, 717),
	Vector2(666, 745), Vector2(658, 742), Vector2(653, 719),
	Vector2(591, 735), Vector2(515, 712), Vector2(507, 731),
	Vector2(490, 749), Vector2(466, 756), Vector2(445, 750),
	Vector2(429, 731), Vector2(410, 669), Vector2(397, 668),
	Vector2(400, 620), Vector2(396, 554), Vector2(423, 537),
	Vector2(412, 526), Vector2(458, 353), Vector2(543, 333),
	Vector2(624, 272),
]

var _highlight_mode := InputHighlightMode.new()


func _ready() -> void:
	name = "GarageTricycle"
	z_index = 1
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	if disabled or size.x <= 0.0 or size.y <= 0.0:
		return false
	return Geometry2D.is_point_in_polygon(point / size * ART_SIZE, PackedVector2Array(OUTLINE))


func _draw() -> void:
	if disabled or not (has_focus() if _highlight_mode.keyboard_active else is_hovered()):
		return
	var polygon := PackedVector2Array()
	for point: Vector2 in OUTLINE:
		polygon.append(point / ART_SIZE * size)
	draw_colored_polygon(polygon, Color(1.0, 0.9, 0.3, 0.07))
	polygon.append(polygon[0])
	draw_polyline(polygon, Color("ffe66a"), maxf(1.0, size.y / ART_SIZE.y * 2.5), true)


func _clear_highlight() -> void:
	if not is_visible_in_tree():
		release_focus()
		_highlight_mode.reset()
	queue_redraw()
