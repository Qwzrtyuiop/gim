extends Control

const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const SLEEP_MESSAGE_SECONDS := 1.0
const LABEL_FADE_SECONDS := 0.45
const DAY_CARD_HOLD_SECONDS := 0.7
const RESUME_AFTER_DAY_END_STORY := "after_day_end_story"
const RESUME_AFTER_SLEEP_MIDPOINT_STORY := "after_sleep_midpoint_story"
const RESUME_AFTER_DAY_START_STORY := "after_day_start_story"

@onready var message_label: Label = $MessageLabel
@onready var day_label: Label = $DayLabel


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/sleep_transition.tscn")
	message_label.text = "SLEEPING..."
	message_label.visible = true
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	day_label.visible = false
	day_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_begin_transition()


func _begin_transition() -> void:
	if PlayerState.get_pending_trip_selection().is_empty():
		PlayerState.clear_pending_sleep_transition_state()
		get_tree().change_scene_to_file(FALLBACK_SCENE)
		return

	var resume_step := PlayerState.get_sleep_transition_resume_step()
	PlayerState.clear_pending_sleep_transition_state()

	match resume_step:
		RESUME_AFTER_DAY_END_STORY:
			await _run_after_day_end_story()
		RESUME_AFTER_SLEEP_MIDPOINT_STORY:
			message_label.visible = false
			await _run_after_sleep_midpoint_story()
		RESUME_AFTER_DAY_START_STORY:
			message_label.visible = false
			_finish_transition()
		_:
			await _run_full_sequence()


func _transition_mode() -> String:
	var pending_trip_selection := PlayerState.get_pending_trip_selection()
	return PlayerState.normalize_transition_mode(str(pending_trip_selection.get("transition_mode", PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY)))


func _run_full_sequence() -> void:
	if _transition_mode() == PlayerState.TRANSITION_REST_TO_NIGHT:
		await _show_sleep_message()
		_finish_transition()
		return

	if _launch_story_trigger(PlayerState.STORY_TRIGGER_DAY_END, PlayerState.get_current_day(), RESUME_AFTER_DAY_END_STORY):
		return
	await _run_after_day_end_story()


func _run_after_day_end_story() -> void:
	await _show_sleep_message()
	if _launch_story_trigger(PlayerState.STORY_TRIGGER_SLEEP_MIDPOINT, _next_day_number(), RESUME_AFTER_SLEEP_MIDPOINT_STORY):
		return
	await _run_after_sleep_midpoint_story()


func _run_after_sleep_midpoint_story() -> void:
	await _show_day_card()
	if _launch_story_trigger(PlayerState.STORY_TRIGGER_DAY_START, _next_day_number(), RESUME_AFTER_DAY_START_STORY):
		return
	_finish_transition()


func _show_sleep_message() -> void:
	message_label.visible = true
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	await get_tree().create_timer(SLEEP_MESSAGE_SECONDS).timeout
	await _fade_label(message_label, 0.0, LABEL_FADE_SECONDS)
	message_label.visible = false


func _show_day_card() -> void:
	day_label.text = "DAY %d" % _next_day_number()
	day_label.visible = true
	day_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	await _fade_label(day_label, 1.0, LABEL_FADE_SECONDS)
	await get_tree().create_timer(DAY_CARD_HOLD_SECONDS).timeout
	await _fade_label(day_label, 0.0, LABEL_FADE_SECONDS)
	day_label.visible = false


func _next_day_number() -> int:
	return PlayerState.get_transition_display_day(_transition_mode())


func _finish_transition() -> void:
	PlayerState.clear_pending_sleep_transition_state()
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _launch_story_trigger(phase: String, day_number: int, resume_step: String) -> bool:
	var trigger_data := PlayerState.find_story_trigger_for_phase(phase, day_number)
	if trigger_data.is_empty():
		return false

	var story_payload := PlayerState.get_story_payload_for_trigger(trigger_data)
	if story_payload.is_empty():
		return false

	story_payload["return_scene"] = SLEEP_TRANSITION_SCENE
	story_payload["next_scene"] = SLEEP_TRANSITION_SCENE
	PlayerState.set_pending_story(story_payload)
	PlayerState.consume_story_trigger(trigger_data)
	PlayerState.set_sleep_transition_resume_step(resume_step)
	get_tree().change_scene_to_file(STORY_SCENE)
	return true


func _fade_label(label: CanvasItem, alpha_value: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", alpha_value, duration)
	await tween.finished
