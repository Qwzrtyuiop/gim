extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const FADE_SECONDS := 0.45
const HOLD_SECONDS := 0.7

@onready var day_label: Label = $DayLabel
@onready var fade_overlay: ColorRect = $FadeOverlay


func _ready() -> void:
	day_label.text = "DAY %d" % PlayerState.get_current_day()
	day_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_begin_transition()


func _begin_transition() -> void:
	await _fade_node(fade_overlay, "color:a", 0.0, FADE_SECONDS)
	await _fade_node(day_label, "modulate:a", 1.0, FADE_SECONDS)
	await get_tree().create_timer(HOLD_SECONDS).timeout
	await _fade_node(day_label, "modulate:a", 0.0, FADE_SECONDS)
	await _fade_node(fade_overlay, "color:a", 1.0, FADE_SECONDS)

	if not PlayerState.get_stage_start_error().is_empty():
		get_tree().change_scene_to_file(FALLBACK_SCENE)
		return

	get_tree().change_scene_to_file(GAME_SCENE)


func _fade_node(node: CanvasItem, property_path: String, target_value: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, property_path, target_value, duration)
	await tween.finished
