extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const UI_FRAME_TEXTURE := preload("res://assets/ui/ui_frame.png")
const POPUP_HOLD_SECONDS := 2.2
const POPUP_FADE_SECONDS := 0.28

var popup_frame: TextureRect
var heading_label: Label
var title_label: Label
var subtitle_label: Label
var popup_tween: Tween
var detail_overlay: ColorRect
var detail_title: Label
var detail_subtitle: Label
var detail_body: Label
var detail_queue: Array[String] = []
var active_detail_id := ""
var was_paused := false
var previous_focus: WeakRef
var detail_ready_at := 0
var dismissal_pending := false


func _ready() -> void:
	layer = 800
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_detail_ui()
	_build_ui()
	if not PlayerState.achievement_unlocked.is_connected(_on_achievement_unlocked):
		PlayerState.achievement_unlocked.connect(_on_achievement_unlocked)


func is_description_open() -> bool:
	return not active_detail_id.is_empty()


func _input(event: InputEvent) -> void:
	if not is_description_open():
		return
	# Consume the entire input before returning control to the underlying scene.
	get_viewport().set_input_as_handled()
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.double_click
	if (clicked or event.is_action_pressed("ui_accept")) and not event.is_echo() and Time.get_ticks_msec() >= detail_ready_at and not dismissal_pending:
		dismissal_pending = true
		_dismiss_description.call_deferred()


func _build_detail_ui() -> void:
	detail_overlay = ColorRect.new()
	detail_overlay.name = "AchievementDescription"
	detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_overlay.color = Color(0, 0, 0, 0.72)
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_overlay.hide()
	add_child(detail_overlay)
	var panel := Panel.new()
	detail_overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.09, 0.98)
	style.border_color = Color(0.71, 0.56, 0.31)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var heading := _make_detail_label(panel, "ACHIEVEMENT UNLOCKED", 11, Vector2(28, 26), Vector2(724, 22))
	heading.modulate = Color(1, 0.8, 0.5)
	detail_title = _make_detail_label(panel, "", 22, Vector2(28, 65), Vector2(724, 30))
	detail_subtitle = _make_detail_label(panel, "", 12, Vector2(28, 110), Vector2(724, 22))
	detail_body = _make_detail_label(panel, "", 12, Vector2(36, 158), Vector2(708, 220))
	detail_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_make_detail_label(panel, "CLICK / ENTER TO CONTINUE", 11, Vector2(28, 396), Vector2(724, 24))


func _make_detail_label(parent: Control, text: String, font_size: int, position_value: Vector2, size_value: Vector2) -> Label:
	var label := _make_label(font_size, Color(0.98, 0.95, 0.88), 0)
	label.text = text
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _show_next_description() -> void:
	if detail_queue.is_empty():
		active_detail_id = ""
		detail_overlay.hide()
		if popup_tween != null:
			popup_tween.kill()
		popup_frame.modulate.a = 0.0
		get_tree().paused = was_paused
		if previous_focus != null:
			var control = previous_focus.get_ref()
			if is_instance_valid(control) and control.is_visible_in_tree():
				control.grab_focus()
		previous_focus = null
		return
	active_detail_id = detail_queue.pop_front()
	var data := PlayerState.get_achievement_data(active_detail_id)
	detail_title.text = str(data.get("title", active_detail_id)).to_upper()
	detail_subtitle.text = str(data.get("subtitle", ""))
	detail_body.text = str(data.get("description", ""))
	detail_ready_at = Time.get_ticks_msec() + 250
	detail_overlay.show()
	_show_popup(active_detail_id)


func _dismiss_description() -> void:
	dismissal_pending = false
	_show_next_description()


func _build_ui() -> void:
	popup_frame = TextureRect.new()
	popup_frame.name = "AchievementPopup"
	popup_frame.texture = UI_FRAME_TEXTURE
	popup_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_frame.stretch_mode = TextureRect.STRETCH_SCALE
	popup_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_frame.anchor_left = 1.0
	popup_frame.anchor_top = 0.0
	popup_frame.anchor_right = 1.0
	popup_frame.anchor_bottom = 0.0
	popup_frame.offset_left = -360.0
	popup_frame.offset_top = 24.0
	popup_frame.offset_right = -24.0
	popup_frame.offset_bottom = 144.0
	popup_frame.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(popup_frame)

	heading_label = _make_label(10, Color(0.43, 0.24, 0.10, 1.0), 1)
	heading_label.text = "ACHIEVEMENT UNLOCKED"
	heading_label.position = Vector2(44.0, 22.0)
	heading_label.size = Vector2(240.0, 18.0)
	popup_frame.add_child(heading_label)

	title_label = _make_label(18, Color(0.24, 0.13, 0.07, 1.0), 1)
	title_label.position = Vector2(42.0, 44.0)
	title_label.size = Vector2(270.0, 26.0)
	popup_frame.add_child(title_label)

	subtitle_label = _make_label(11, Color(0.38, 0.23, 0.11, 1.0), 1)
	subtitle_label.position = Vector2(44.0, 78.0)
	subtitle_label.size = Vector2(250.0, 24.0)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_frame.add_child(subtitle_label)


func _make_label(font_size: int, font_color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.98, 0.93, 0.78, 0.92))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _on_achievement_unlocked(achievement_id: String) -> void:
	var safe_id := str(achievement_id).strip_edges().to_lower()
	if safe_id.is_empty() or PlayerState.get_achievement_data(safe_id).is_empty():
		return
	if safe_id == active_detail_id or detail_queue.has(safe_id):
		return
	detail_queue.append(safe_id)
	if not is_description_open():
		was_paused = get_tree().paused
		var focused := get_viewport().gui_get_focus_owner()
		previous_focus = weakref(focused) if focused != null else null
		if focused != null:
			focused.release_focus()
		get_tree().paused = true
		_show_next_description()


func _show_popup(achievement_id: String) -> void:
	if popup_tween != null:
		popup_tween.kill()
	var achievement_data: Dictionary = PlayerState.get_achievement_data(achievement_id)
	UIAudioManager.play_press()
	title_label.text = str(achievement_data.get("title", achievement_id)).to_upper()
	subtitle_label.text = str(achievement_data.get("subtitle", ""))
	popup_frame.position = Vector2(56.0, -10.0)
	popup_frame.modulate = Color(1.0, 1.0, 1.0, 0.0)

	popup_tween = create_tween()
	popup_tween.tween_property(popup_frame, "position", Vector2(0.0, 0.0), POPUP_FADE_SECONDS)
	popup_tween.parallel().tween_property(popup_frame, "modulate:a", 1.0, POPUP_FADE_SECONDS)
	popup_tween.tween_interval(POPUP_HOLD_SECONDS)
	popup_tween.tween_property(popup_frame, "position", Vector2(56.0, -10.0), POPUP_FADE_SECONDS)
	popup_tween.parallel().tween_property(popup_frame, "modulate:a", 0.0, POPUP_FADE_SECONDS)
