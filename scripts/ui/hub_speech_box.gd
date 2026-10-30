extends Control

# A local speech balloon. The owning hub decides content, timing and input rules.
signal advanced
signal dismissed

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const BACKGROUND := Color(0.055, 0.043, 0.030, 0.98)
const CREAM := Color("faefd5")
const MUTED := Color("b8ab92")
const GOLD := Color("dfba78")
const PADDING := 16.0
const GAP := 14.0

var panel: PanelContainer
var speaker_label: Label
var body_label: Label
var hint_label: Label
var close_button: Button
var tail_points := PackedVector2Array()
var _header: HBoxContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _options: Dictionary = {}
var _built := false


func _ready() -> void:
	_build()


func set_line(speaker: String, text: String, options: Dictionary = {}) -> void:
	_build()
	_options = options.duplicate(true)
	speaker_label.text = speaker
	speaker_label.tooltip_text = speaker
	speaker_label.visible = not speaker.is_empty()
	body_label.text = text
	body_label.visible_characters = -1
	body_label.add_theme_font_size_override("font_size", int(_number(options.get("font_size", 12), 12, 10, 18)))
	hint_label.text = str(options.get("hint", "Click to continue"))
	hint_label.visible = not hint_label.text.is_empty()
	close_button.visible = bool(options.get("closable", true))
	_header.visible = speaker_label.visible or close_button.visible
	_scroll.scroll_vertical = 0
	tail_points.clear()
	queue_redraw()


func layout_near(target_rect: Rect2, safe_rect: Rect2, preferred_side := "auto") -> void:
	_build()
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		panel.hide()
		tail_points.clear()
		queue_redraw()
		return
	panel.show()
	var width := minf(safe_rect.size.x, _number(_options.get("width", 380), 380, 260, 520))
	var text_width := maxf(1, width - PADDING * 2 - 14)
	var font_size := body_label.get_theme_font_size("font_size")
	var measured := FONT.get_multiline_string_size(body_label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size)
	var line_count := maxi(1, ceili(measured.y / FONT.get_height(font_size)))
	var body_height := measured.y + maxf(0, line_count - 1) * body_label.get_theme_constant("line_spacing")
	var header_height := 28.0 if _header.visible else 0.0
	var hint_height := 10.0 if hint_label.visible else 0.0
	var fixed_height := PADDING * 2 + header_height + hint_height
	if _header.visible:
		fixed_height += 8
	if hint_label.visible:
		fixed_height += 8
	var max_height := minf(250, safe_rect.size.y)
	var visible_body_height := minf(maxf(font_size + 4, body_height), maxf(1, max_height - fixed_height))
	_scroll.custom_minimum_size = Vector2(0, visible_body_height)
	var desired_size := Vector2(width, minf(max_height, fixed_height + visible_body_height))
	# A very small safe area can be narrower than the font and close button.
	# Scaling the panel also preserves its internal container minimum sizes.
	panel.scale = Vector2.ONE
	panel.size = desired_size
	var minimum := panel.get_combined_minimum_size()
	var actual_size := Vector2(maxf(desired_size.x, minimum.x), maxf(desired_size.y, minimum.y))
	panel.size = actual_size
	var fit := minf(1, minf(safe_rect.size.x / maxf(1, actual_size.x), safe_rect.size.y / maxf(1, actual_size.y)))
	panel.scale = Vector2.ONE * fit
	var balloon_size := actual_size * fit
	var balloon_position := safe_rect.position + Vector2((safe_rect.size.x - balloon_size.x) * 0.5, safe_rect.size.y - balloon_size.y)
	var has_target := target_rect.size.x > 0 and target_rect.size.y > 0
	if has_target:
		balloon_position = _position_for(target_rect, balloon_size, safe_rect, preferred_side)
	balloon_position.x = clampf(balloon_position.x, safe_rect.position.x, safe_rect.end.x - balloon_size.x)
	balloon_position.y = clampf(balloon_position.y, safe_rect.position.y, safe_rect.end.y - balloon_size.y)
	panel.position = balloon_position.round()
	_build_tail(target_rect, Rect2(panel.position, balloon_size), safe_rect, has_target)
	queue_redraw()


func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.name = "SpeechPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 8)
	panel.add_child(_content)
	_header = HBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.alignment = BoxContainer.ALIGNMENT_END
	_header.add_theme_constant_override("separation", 12)
	_content.add_child(_header)
	speaker_label = _label(11, GOLD)
	speaker_label.name = "SpeechSpeaker"
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speaker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header.add_child(speaker_label)
	close_button = Button.new()
	close_button.name = "CloseSpeech"
	close_button.text = "X"
	close_button.tooltip_text = "Dismiss message"
	close_button.custom_minimum_size = Vector2(28, 28)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 10)
	close_button.add_theme_color_override("font_color", MUTED)
	close_button.add_theme_color_override("font_hover_color", CREAM)
	close_button.add_theme_color_override("font_pressed_color", GOLD)
	for state in ["normal", "hover", "pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close_button.pressed.connect(func() -> void: dismissed.emit())
	_header.add_child(close_button)
	_scroll = ScrollContainer.new()
	_scroll.name = "SpeechScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.gui_input.connect(_on_panel_input)
	_content.add_child(_scroll)
	body_label = _label(12, CREAM)
	body_label.name = "SpeechText"
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	body_label.add_theme_constant_override("line_spacing", 6)
	_scroll.add_child(body_label)
	hint_label = _label(9, MUTED)
	hint_label.name = "SpeechHint"
	hint_label.text = "Click to continue"
	_content.add_child(hint_label)


func _position_for(target: Rect2, balloon_size: Vector2, safe_rect: Rect2, preferred_side: String) -> Vector2:
	var sides: Array[String] = ["above", "right", "left", "below"]
	if preferred_side in sides:
		sides.erase(preferred_side)
		sides.push_front(preferred_side)
	var best_position := Vector2.ZERO
	var best_score := INF
	for side in sides:
		var candidate := Rect2(Vector2.ZERO, balloon_size)
		match side:
			"above":
				candidate.position = Vector2(target.get_center().x - balloon_size.x * 0.5, target.position.y - GAP - balloon_size.y)
			"below":
				candidate.position = Vector2(target.get_center().x - balloon_size.x * 0.5, target.end.y + GAP)
			"left":
				candidate.position = Vector2(target.position.x - GAP - balloon_size.x, target.get_center().y - balloon_size.y * 0.5)
			"right":
				candidate.position = Vector2(target.end.x + GAP, target.get_center().y - balloon_size.y * 0.5)
		if safe_rect.encloses(candidate):
			return candidate.position
		var outside := candidate.get_area() - candidate.intersection(safe_rect).get_area()
		var score := outside + candidate.intersection(target).get_area()
		if score < best_score:
			best_score = score
			best_position = candidate.position
	return best_position


func _build_tail(target: Rect2, balloon: Rect2, safe_rect: Rect2, has_target: bool) -> void:
	tail_points.clear()
	if not bool(_options.get("show_tail", true)) or not has_target or balloon.has_point(target.get_center()):
		return
	var toward := target.get_center()
	var base := balloon.get_center()
	var along := Vector2(8, 0)
	if toward.y >= balloon.end.y:
		base = Vector2(clampf(toward.x, balloon.position.x + 18, balloon.end.x - 18), balloon.end.y - 1)
	elif toward.y <= balloon.position.y:
		base = Vector2(clampf(toward.x, balloon.position.x + 18, balloon.end.x - 18), balloon.position.y + 1)
	elif toward.x >= balloon.end.x:
		base = Vector2(balloon.end.x - 1, clampf(toward.y, balloon.position.y + 18, balloon.end.y - 18))
		along = Vector2(0, 8)
	else:
		base = Vector2(balloon.position.x + 1, clampf(toward.y, balloon.position.y + 18, balloon.end.y - 18))
		along = Vector2(0, 8)
	var tip := base + (toward - base).limit_length(24)
	tip.x = clampf(tip.x, safe_rect.position.x, safe_rect.end.x)
	tip.y = clampf(tip.y, safe_rect.position.y, safe_rect.end.y)
	tail_points = PackedVector2Array([base - along, tip, base + along])


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		advanced.emit()


func _draw() -> void:
	if tail_points.size() == 3:
		draw_colored_polygon(tail_points, BACKGROUND)
		draw_polyline(tail_points, GOLD, 1.0, false)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)
