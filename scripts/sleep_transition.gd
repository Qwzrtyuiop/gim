extends Control

const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const HOUSE_DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const SLEEP_MESSAGE_SECONDS := 1.0
const LABEL_FADE_SECONDS := 0.45
const DAY_CARD_HOLD_SECONDS := 0.7
const DEBT_LINE_DELAY_SECONDS := 0.3
const DEBT_LINE_FADE_SECONDS := 0.35
const DAY_CHANGE_SOUND := preload("res://assets/audio/sfx/story/ding.mp3")
const DEBT_REVEAL_SOUND := preload("res://assets/audio/music/story/drum.mp3")
const RESUME_AFTER_DAY_END_STORY := "after_day_end_story"
const RESUME_AFTER_SLEEP_MIDPOINT_STORY := "after_sleep_midpoint_story"
const RESUME_AFTER_DAY_START_STORY := "after_day_start_story"

@onready var message_label: Label = $MessageLabel
@onready var day_label: Label = $DayLabel
@onready var debt_label: Label = $DebtLabel
@onready var collector_label: Label = $CollectorLabel

var day_change_player: AudioStreamPlayer
var debt_reveal_player: AudioStreamPlayer


func _ready() -> void:
	day_change_player = AudioStreamPlayer.new()
	day_change_player.name = "DayChangeSFX"
	var sound := DAY_CHANGE_SOUND.duplicate() as AudioStreamMP3
	sound.loop = false
	day_change_player.stream = sound
	add_child(day_change_player)
	AudioSettingsManager.register_player(day_change_player, "sfx")
	debt_reveal_player = AudioStreamPlayer.new()
	debt_reveal_player.name = "DebtRevealSFX"
	var drum := DEBT_REVEAL_SOUND.duplicate() as AudioStreamMP3
	drum.loop = false
	debt_reveal_player.stream = drum
	add_child(debt_reveal_player)
	AudioSettingsManager.register_player(debt_reveal_player, "sfx")
	PlayerState.set_resume_scene("res://scenes/sleep_transition.tscn")
	message_label.text = "SLEEPING..."
	var repair := PlayerState.get_pending_crash_repair()
	if not repair.is_empty():
		var days := int(repair["days"])
		message_label.text = "REPAIRING...\n%d %s" % [days, "DAY" if days == 1 else "DAYS"]
	message_label.visible = true
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	day_label.visible = false
	day_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	debt_label.hide()
	collector_label.hide()
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
	if _launch_story_trigger(PlayerState.STORY_TRIGGER_SLEEP_MIDPOINT, _target_day_number(), RESUME_AFTER_SLEEP_MIDPOINT_STORY):
		return
	await _run_after_sleep_midpoint_story()


func _run_after_sleep_midpoint_story() -> void:
	var target_day := _target_day_number()
	# Commit this date's collection before displaying the remaining balance.
	if not PlayerState.get_pending_crash_repair().is_empty():
		PlayerState.prepare_crash_repair_day()
	else:
		PlayerState.prepare_day_start(target_day)
	await _show_day_card(target_day)
	if not PlayerState.get_pending_crash_repair().is_empty() and PlayerState.is_run_failed():
		PlayerState.finish_crash_repair()
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	if _launch_story_trigger(PlayerState.STORY_TRIGGER_DAY_START, target_day, RESUME_AFTER_DAY_START_STORY):
		return
	_finish_transition()


func _show_sleep_message() -> void:
	message_label.visible = true
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	await get_tree().create_timer(SLEEP_MESSAGE_SECONDS).timeout
	await _fade_label(message_label, 0.0, LABEL_FADE_SECONDS)
	message_label.visible = false


func _show_day_card(target_day: int) -> void:
	day_label.text = "DAY %d" % target_day
	debt_label.text = "PhP %d remaining debt" % PlayerState.get_total_debt_goal()
	var days_left := PlayerState.get_days_until_debt_collection(target_day)
	collector_label.text = "Collection in %d %s" % [days_left, "Day" if days_left == 1 else "Days"]
	day_label.visible = true
	day_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	debt_label.modulate.a = 0.0
	collector_label.modulate.a = 0.0
	debt_label.show()
	collector_label.show()
	day_change_player.play()
	await _fade_label(day_label, 1.0, LABEL_FADE_SECONDS)
	await get_tree().create_timer(DEBT_LINE_DELAY_SECONDS).timeout
	debt_reveal_player.play()
	await _fade_label(debt_label, 1.0, DEBT_LINE_FADE_SECONDS)
	await get_tree().create_timer(DEBT_LINE_DELAY_SECONDS).timeout
	await _fade_label(collector_label, 1.0, DEBT_LINE_FADE_SECONDS)
	await get_tree().create_timer(DAY_CARD_HOLD_SECONDS).timeout
	var fade := create_tween().set_parallel(true)
	for label: Label in [day_label, debt_label, collector_label]:
		fade.tween_property(label, "modulate:a", 0.0, LABEL_FADE_SECONDS)
	await fade.finished
	day_label.visible = false
	debt_label.hide()
	collector_label.hide()


func _target_day_number() -> int:
	var repair := PlayerState.get_pending_crash_repair()
	if not repair.is_empty():
		return int(repair["target_day"])
	if _transition_mode() == PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY and PlayerState.get_current_time_of_day() == "morning":
		return PlayerState.get_current_day()
	return PlayerState.get_transition_display_day(_transition_mode())


func _finish_transition() -> void:
	PlayerState.clear_pending_sleep_transition_state()
	if _transition_mode() == PlayerState.TRANSITION_REST_TO_NIGHT:
		get_tree().change_scene_to_file(HOUSE_DAY_START_SCENE)
		return
	if _transition_mode() == PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY:
		if not PlayerState.get_pending_crash_repair().is_empty():
			PlayerState.prepare_crash_repair_day()
			PlayerState.finish_crash_repair()
			get_tree().change_scene_to_file(GAME_OVER_SCENE if PlayerState.is_run_failed() else HOUSE_DAY_START_SCENE)
			return
		if PlayerState.get_current_time_of_day() != "morning":
			PlayerState.prepare_day_start(_target_day_number())
		if PlayerState.is_run_failed():
			get_tree().change_scene_to_file(GAME_OVER_SCENE)
			return
		PlayerState.clear_pending_trip_selection()
		get_tree().change_scene_to_file(HOUSE_DAY_START_SCENE)
		return
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _launch_story_trigger(phase: String, day_number: int, resume_step: String) -> bool:
	var current_time_of_day := PlayerState.get_current_time_of_day()
	var context := {
		"time_of_day": current_time_of_day,
		"phase_of_day": current_time_of_day,
		"current_time_of_day": current_time_of_day,
		"current_phase": current_time_of_day,
		"current_stage_type": PlayerState.get_current_stage_type(),
	}
	var trigger_data := PlayerState.find_story_trigger_for_phase(phase, day_number, context)
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
