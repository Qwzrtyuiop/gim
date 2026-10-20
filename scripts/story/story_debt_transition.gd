extends Panel

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GOLD := Color(1.0, 0.76, 0.32)
var old_amount: Label
var new_amount: Label
var arrow: DebtArrow
var hint: Label


class DebtArrow extends Control:
	var progress := 0.0

	func set_progress(value: float) -> void:
		progress = value
		queue_redraw()

	func _draw() -> void:
		var start := Vector2(8.0, size.y * 0.5)
		var tip := Vector2(size.x - 8.0, start.y)
		draw_line(start, start.lerp(tip, progress), Color(1.0, 0.76, 0.32), 4.0, true)
		if progress >= 0.95:
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -10), tip + Vector2(-14, 10)]), Color(1.0, 0.76, 0.32))


func setup(report: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -440
	offset_right = 440
	offset_top = -130
	offset_bottom = 130
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.065, 0.05, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 28
	stack.offset_right = -28
	stack.offset_top = 24
	stack.offset_bottom = -20
	stack.add_theme_constant_override("separation", 18)
	stack.add_child(_label("WEEKLY DEBT", 18, GOLD))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.y = 64
	stack.add_child(row)
	old_amount = _label("PhP %d" % int(report.get("previous_goal", 2500)), 24, Color(0.78, 0.76, 0.71))
	old_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(old_amount)
	arrow = DebtArrow.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.custom_minimum_size = Vector2(90, 64)
	row.add_child(arrow)
	new_amount = _label("PhP %d" % int(report.get("next_goal", 5000)), 24, GOLD)
	new_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(new_amount)
	var carryover := int(report.get("carryover", 0))
	var next_base := int(report.get("next_goal", 0)) - carryover
	var explanation := "Next week: PhP %d + PhP %d unpaid" % [next_base, carryover] if carryover > 0 else "First payment settled. Next week: PhP %d" % next_base
	stack.add_child(_label(explanation, 12, Color.WHITE))
	stack.add_child(_label("Paid this week: PhP %d" % int(report.get("paid", 0)), 11, Color(0.78, 0.76, 0.71)))
	hint = _label("ENTER / CLICK", 10, Color(0.78, 0.76, 0.71))
	stack.add_child(hint)
	old_amount.modulate.a = 0.0
	new_amount.modulate.a = 0.0
	hint.modulate.a = 0.0


func play() -> void:
	var tween := create_tween()
	tween.tween_property(old_amount, "modulate:a", 1.0, 0.35)
	tween.tween_interval(0.3)
	tween.tween_method(arrow.set_progress, 0.0, 1.0, 0.45)
	tween.tween_property(new_amount, "modulate:a", 1.0, 0.6)
	tween.tween_property(hint, "modulate:a", 1.0, 0.2)
	await tween.finished


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
