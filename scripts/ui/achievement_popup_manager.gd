extends CanvasLayer

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const UI_FRAME_TEXTURE := preload("res://assets/ui/ui_frame.png")
const POPUP_HOLD_SECONDS := 2.2
const POPUP_FADE_SECONDS := 0.28

var popup_frame: TextureRect
var heading_label: Label
var title_label: Label
var subtitle_label: Label
var popup_queue: Array[String] = []
var is_showing := false


func _ready() -> void:
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if not PlayerState.achievement_unlocked.is_connected(_on_achievement_unlocked):
		PlayerState.achievement_unlocked.connect(_on_achievement_unlocked)


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
	if safe_id.is_empty():
		return
	popup_queue.append(safe_id)
	if not is_showing:
		_show_next_popup()


func _show_next_popup() -> void:
	if popup_queue.is_empty():
		is_showing = false
		return

	var achievement_id: String = str(popup_queue.pop_front())
	var achievement_data: Dictionary = PlayerState.get_achievement_data(achievement_id)
	if achievement_data.is_empty():
		_show_next_popup()
		return

	is_showing = true
	UIAudioManager.play_press()
	title_label.text = str(achievement_data.get("title", achievement_id)).to_upper()
	subtitle_label.text = str(achievement_data.get("subtitle", ""))
	popup_frame.position = Vector2(56.0, -10.0)
	popup_frame.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var intro_tween := create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(popup_frame, "position", Vector2(0.0, 0.0), POPUP_FADE_SECONDS)
	intro_tween.tween_property(popup_frame, "modulate:a", 1.0, POPUP_FADE_SECONDS)
	await intro_tween.finished

	await get_tree().create_timer(POPUP_HOLD_SECONDS).timeout

	var outro_tween := create_tween()
	outro_tween.set_parallel(true)
	outro_tween.tween_property(popup_frame, "position", Vector2(56.0, -10.0), POPUP_FADE_SECONDS)
	outro_tween.tween_property(popup_frame, "modulate:a", 0.0, POPUP_FADE_SECONDS)
	await outro_tween.finished

	_show_next_popup()
