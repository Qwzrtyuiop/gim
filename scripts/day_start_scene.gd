extends Control

const HomeInterface := preload("res://scripts/home/home_interface.gd")
const HomeTutorial := preload("res://scripts/home/home_tutorial.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const DialogueAnchors := preload("res://scripts/ui/hub_dialogue_anchors.gd")

const DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HOME_BGM_PATH := "res://assets/audio/music/story/peace.mp3"
const HOME_REST_FADE_SECONDS := 0.28

@onready var house = $House
@onready var fade_overlay: ColorRect = $FadeOverlay

var header_label: Label
var status_header: PanelContainer
var stats_row_refs: Dictionary = {}
var is_transitioning := false
var bgm_player: AudioStreamPlayer
var info_overlay: ColorRect
var info_panel: PanelContainer
var info_panel_style: StyleBoxFlat
var calendar_background: TextureRect
var calendar_content: Control
var radio_content: Control
var info_title: Label
var info_body: Label
var info_close: Button
var rest_confirm: Button
var outside_buttons: Array[TextureButton] = []
var info_action := ""
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_text_panel: Panel
var tutorial_text_label: Label
var tutorial_step_index := 0
var tutorial_steps: Array[Dictionary] = []
var tutorial_active := false
var hub_dialogue: HubDialogue


func _ready() -> void:
	PlayerState.set_resume_scene(DAY_START_SCENE)
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	if PlayerState.get_current_day() <= 1 and PlayerState.get_pending_trip_selection().is_empty():
		PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
		get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)
		return
	PlayerState.ensure_daily_conditions_for_current_day()
	if PlayerState.get_current_day() >= 2 and int(PlayerState.stage_round) > 0 and not PlayerState.has_home_tutorial_shown():
		PlayerState.mark_home_tutorial_shown()
	_create_hud()
	_create_info_overlay()
	_create_hub_dialogue()
	house.action_pressed.connect(_on_house_action)
	resized.connect(_layout_ui)
	_start_home_bgm()
	_render_day_start()
	_build_tutorial()
	_layout_ui()
	if not PlayerState.has_home_tutorial_shown():
		call_deferred("_start_tutorial")


func _input(event: InputEvent) -> void:
	if tutorial_active and _is_any_press(event):
		get_viewport().set_input_as_handled()
		_advance_tutorial()
	elif hub_dialogue != null and hub_dialogue.handle_input(event):
		get_viewport().set_input_as_handled()
	elif info_overlay != null and info_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_info()


func _on_house_action(action: String) -> void:
	if is_transitioning or tutorial_active or info_overlay.visible or _speech_is_blocking():
		return
	match action:
		"radio", "calendar":
			_show_info(action)
		"rest":
			_show_info("rest")
		"ride":
			_show_info("outside")


func _create_hud() -> void:
	HomeInterface.create_hud(self)


func _label(font_size: int) -> Label:
	return HomeInterface.label(self, font_size)


func _create_info_overlay() -> void:
	HomeInterface.create_info_overlay(self)


func _layout_ui() -> void:
	HomeInterface.layout_ui(self)


func _render_day_start() -> void:
	HomeInterface.render_day_start(self)


func _show_info(action: String) -> void:
	if _speech_is_blocking():
		return
	HomeInterface.show_info(self, action)


func _close_info() -> void:
	HomeInterface.close_info(self)


func _confirm_rest() -> void:
	if is_transitioning or not info_overlay.visible or info_action != "rest":
		return
	hub_dialogue.clear()
	_close_info()
	_rest_then_noon()


func _ride_now() -> void:
	_leave_home(RIDE_SELECTION_SCENE)


func _choose_outside_destination(scene_path: String) -> void:
	if is_transitioning or not info_overlay.visible or info_action != "outside":
		return
	hub_dialogue.clear()
	_close_info()
	_leave_home(scene_path)


func _leave_home(scene_path: String) -> void:
	if is_transitioning or _speech_is_blocking():
		return
	hub_dialogue.clear()
	is_transitioning = true
	house.set_enabled(false)
	PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.get_home_ride_transition_mode())
	get_tree().change_scene_to_file(scene_path)


func _rest_then_noon() -> void:
	if is_transitioning or _speech_is_blocking():
		return
	hub_dialogue.clear()
	if PlayerState.get_current_time_of_day() == "night":
		is_transitioning = true
		house.set_enabled(false)
		PlayerState.apply_night_rest_bonus()
		PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY, false)
		get_tree().change_scene_to_file(SLEEP_TRANSITION_SCENE)
		return
	var next_time := "noon" if PlayerState.get_current_time_of_day() == "morning" else "night"
	await _transition_home_rest(next_time)


func _transition_home_rest(next_time: String) -> void:
	hub_dialogue.clear()
	is_transitioning = true
	house.set_enabled(false)
	await _fade_overlay_to(1.0, HOME_REST_FADE_SECONDS)
	PlayerState.record_rest()
	PlayerState.add_energy(2)
	PlayerState.set_current_stage_time(next_time)
	PlayerState.clear_pending_trip_selection()
	_render_day_start()
	await _fade_overlay_to(0.0, HOME_REST_FADE_SECONDS)
	house.set_enabled(true)
	is_transitioning = false


func _fade_overlay_to(alpha_value: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", alpha_value, duration)
	await tween.finished


func _start_home_bgm() -> void:
	if bgm_player != null and is_instance_valid(bgm_player):
		return
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "HomeBGMPlayer"
	bgm_player.bus = "Master"
	bgm_player.stream = _load_looping_audio_stream(HOME_BGM_PATH)
	add_child(bgm_player)
	AudioSettingsManager.register_player(bgm_player, "music")
	bgm_player.play()


func _load_looping_audio_stream(path: String):
	var stream = load(path)
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		stream.loop = true
	return stream


func _create_hub_dialogue() -> void:
	hub_dialogue = HubDialogue.new()
	hub_dialogue.name = "HubDialogue"
	add_child(hub_dialogue)
	hub_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_dialogue.set_gate(func() -> bool:
		return not tutorial_active and not is_transitioning and not info_overlay.visible
	)
	for action: String in house.REGIONS:
		hub_dialogue.register_target(action, _home_message_target.bind(action))


func _home_message_target(action: String) -> Rect2:
	if not house.is_visible_in_tree():
		return Rect2()
	return DialogueAnchors.transform_rect(house, house.sprite_rect_for(action, house.active_action() == action))


func show_message(text: Variant, options: Dictionary = {}) -> bool:
	return hub_dialogue.say(text, options) if hub_dialogue != null else false


func show_messages(lines: Array, options: Dictionary = {}) -> bool:
	return hub_dialogue.play(lines, options) if hub_dialogue != null else false


func _speech_is_blocking() -> bool:
	return hub_dialogue != null and hub_dialogue.blocks_input()


func _build_tutorial() -> void:
	HomeTutorial.build_tutorial(self)


func _start_tutorial() -> void:
	HomeTutorial.start_tutorial(self)


func _advance_tutorial() -> void:
	HomeTutorial.advance_tutorial(self)


func _show_tutorial_step(step_index: int) -> void:
	HomeTutorial.show_tutorial_step(self, step_index)


func _is_any_press(event: InputEvent) -> bool:
	return HomeTutorial.is_any_press(self, event)
