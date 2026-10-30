extends Control

const GameTuning := preload("res://scripts/config/game_tuning.gd")

const HomeInterface := preload("res://scripts/home/home_interface.gd")
const HomeTutorial := preload("res://scripts/home/home_tutorial.gd")
const HomeMap := preload("res://scripts/home/home_map.gd")
const HospitalEncounter := preload("res://scripts/home/hospital_encounter.gd")
const BennyEvening := preload("res://scripts/home/benny_evening_encounter.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const HubNightAmbience := preload("res://scripts/ui/hub_night_ambience.gd")
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const DialogueAnchors := preload("res://scripts/ui/hub_dialogue_anchors.gd")

const DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
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
var night_ambience: HubNightAmbience
var info_overlay: ColorRect
var calendar_background: TextureRect
var calendar_content: Control
var radio_content: Control
var rest_content: Control
var rest_confirm: Button
var info_action := ""
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_text_panel: Panel
var tutorial_text_label: Label
var tutorial_step_index := 0
var tutorial_steps: Array[Dictionary] = []
var tutorial_active := false
var hub_dialogue: HubDialogue
var map_button: Button
var home_map: HomeMap


func _ready() -> void:
	var returning_to_hospital := HospitalEncounter.has_pending_return()
	var returning_to_hub_story := HomeMap.has_hub_story_return()
	PlayerState.set_resume_scene(DAY_START_SCENE)
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	if not returning_to_hospital and not returning_to_hub_story and _try_start_benny_evening():
		return
	if not returning_to_hospital and not returning_to_hub_story and PlayerState.get_current_day() <= 1 and PlayerState.get_pending_trip_selection().is_empty():
		PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
		get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)
		return
	PlayerState.ensure_daily_conditions_for_current_day()
	if PlayerState.get_current_day() >= 2 and int(PlayerState.stage_round) > 0 and not PlayerState.has_home_tutorial_shown():
		PlayerState.mark_home_tutorial_shown()
	_create_hud()
	_create_info_overlay()
	_create_map()
	_create_hub_dialogue()
	night_ambience = AmbientAudioManager
	AmbientAudioManager.enter_hub(false, true)
	house.action_pressed.connect(_on_house_action)
	resized.connect(_layout_ui)
	_start_home_bgm()
	_render_day_start()
	_build_tutorial()
	_layout_ui()
	if returning_to_hub_story:
		_open_map()
		home_map.restore_hub_story_return()
	elif returning_to_hospital:
		_open_map()
		home_map.restore_hospital_after_story()
		HospitalEncounter.complete_return()
	elif not PlayerState.has_home_tutorial_shown():
		call_deferred("_start_tutorial")


func _input(event: InputEvent) -> void:
	if PauseMenuManager.handle_input(event):
		return
	if home_map != null and home_map.visible:
		return
	if tutorial_active and _is_any_press(event):
		get_viewport().set_input_as_handled()
		_advance_tutorial()
	elif hub_dialogue != null and hub_dialogue.handle_input(event):
		get_viewport().set_input_as_handled()


func _on_house_action(action: String) -> void:
	if is_transitioning or tutorial_active or info_overlay.visible or home_map.visible or _speech_is_blocking():
		return
	match action:
		"radio", "calendar":
			_show_info(action)
		"rest":
			_show_info("rest")
		"garage":
			_open_map("garage")


func _create_hud() -> void:
	HomeInterface.create_hud(self)


func _create_map() -> void:
	home_map = HomeMap.new()
	add_child(home_map)
	home_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_map.closed.connect(_close_map)
	home_map.destination_requested.connect(_leave_home)
	home_map.bar_music_changed.connect(_refresh_home_bgm)


func _open_map(initial_location: String = "") -> void:
	if is_transitioning or tutorial_active or info_overlay.visible or home_map.visible or _speech_is_blocking():
		return
	hub_dialogue.clear()
	house.set_enabled(false)
	map_button.hide()
	status_header.hide()
	home_map.open("home", initial_location)
	_refresh_home_bgm()


func _close_map() -> void:
	if _try_start_benny_evening():
		return
	house.set_enabled(not is_transitioning and not tutorial_active)
	map_button.show()
	status_header.show()
	map_button.grab_focus()
	_refresh_home_bgm()


func _create_info_overlay() -> void:
	HomeInterface.create_info_overlay(self)


func _layout_ui() -> void:
	HomeInterface.layout_ui(self)


func _render_day_start() -> void:
	HomeInterface.render_day_start(self)
	house.set_weather(PlayerState.get_current_weather())
	night_ambience.refresh()
	_refresh_home_bgm()


func _show_info(action: String) -> void:
	if _speech_is_blocking() or action not in ["calendar", "radio", "rest"]:
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
	PlayerState.add_energy(GameTuning.REST_ENERGY_RESTORE)
	PlayerState.relieve_stress(GameTuning.REST_STRESS_RELIEF)
	PlayerState.set_current_stage_time(next_time)
	PlayerState.clear_pending_trip_selection()
	if _try_start_benny_evening():
		return
	_render_day_start()
	await _fade_overlay_to(0.0, HOME_REST_FADE_SECONDS)
	house.set_enabled(true)
	is_transitioning = false


func _try_start_benny_evening() -> bool:
	if not BennyEvening.queue(PlayerState):
		return false
	is_transitioning = true
	get_tree().change_scene_to_file(STORY_SCENE)
	return true


func _fade_overlay_to(alpha_value: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", alpha_value, duration)
	await tween.finished


func _start_home_bgm() -> void:
	if bgm_player != null and is_instance_valid(bgm_player):
		return
	bgm_player = HubMusicManager.player
	_refresh_home_bgm()


func _refresh_home_bgm() -> void:
	if not is_instance_valid(bgm_player):
		return
	var indoors := home_map == null or not home_map.visible
	var bar_active: bool = home_map != null and home_map.bar_audio != null and home_map.bar_audio.active
	bgm_player = HubMusicManager.request_track(
		HubMusicManager.background_path(indoors),
		RainAudioProfile.music_duck_db(PlayerState.get_current_weather()),
		PlayerState.is_midnight() or bar_active,
	)


func _create_hub_dialogue() -> void:
	hub_dialogue = HubDialogue.new()
	hub_dialogue.name = "HubDialogue"
	add_child(hub_dialogue)
	hub_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_dialogue.set_gate(func() -> bool:
		return not tutorial_active and not is_transitioning and not info_overlay.visible and not home_map.visible
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
