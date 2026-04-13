extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const FADE_SECONDS := 0.45
const LINE_FADE_SECONDS := 0.35
const LINE_HOLD_SECONDS := 0.3
const HOLD_SECONDS := 0.7
const GAMEPLAY_ENTRY_FADE_SECONDS := 0.55

@onready var day_label: Label = $DayLabel
@onready var debt_label: Label = $DebtLabel
@onready var collector_label: Label = $CollectorLabel
@onready var fade_overlay: ColorRect = $FadeOverlay


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/day_start_transition.tscn")
	day_label.text = "DAY %d" % PlayerState.get_current_day()
	debt_label.text = "PhP %d remaining debt" % PlayerState.get_total_debt_goal()
	var days_left := PlayerState.get_days_until_debt_collection()
	var day_suffix := "day" if days_left == 1 else "days"
	collector_label.text = "Collector in %d %s" % [days_left, day_suffix]
	day_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	debt_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	collector_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_begin_transition()


func _begin_transition() -> void:
	await _fade_node(fade_overlay, "color:a", 0.0, FADE_SECONDS)
	await _fade_node(day_label, "modulate:a", 1.0, FADE_SECONDS)
	await get_tree().create_timer(LINE_HOLD_SECONDS).timeout
	await _fade_node(debt_label, "modulate:a", 1.0, LINE_FADE_SECONDS)
	await get_tree().create_timer(LINE_HOLD_SECONDS).timeout
	await _fade_node(collector_label, "modulate:a", 1.0, LINE_FADE_SECONDS)
	await get_tree().create_timer(HOLD_SECONDS).timeout
	await _fade_node(collector_label, "modulate:a", 0.0, LINE_FADE_SECONDS)
	await _fade_node(debt_label, "modulate:a", 0.0, LINE_FADE_SECONDS)
	await _fade_node(day_label, "modulate:a", 0.0, FADE_SECONDS)
	await _fade_node(fade_overlay, "color:a", 1.0, FADE_SECONDS)

	if not PlayerState.get_stage_start_error().is_empty():
		get_tree().change_scene_to_file(FALLBACK_SCENE)
		return

	PlayerState.set_pending_gameplay_entry_fade(GAMEPLAY_ENTRY_FADE_SECONDS)
	get_tree().change_scene_to_file(GAME_SCENE)


func _fade_node(node: CanvasItem, property_path: String, target_value: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, property_path, target_value, duration)
	await tween.finished
