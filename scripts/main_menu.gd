extends Control

const MainMenuDebug := preload("res://scripts/menu/main_menu_debug.gd")
const MainMenuSettings := preload("res://scripts/menu/main_menu_settings.gd")

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const MenuTrafficController := preload("res://scripts/game/menu_traffic_controller.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const DAY_START_SCENE := "res://scenes/day_start_transition.tscn"
const HOUSE_DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const ACHIEVEMENTS_LIBRARY_SCENE := "res://scenes/achievements_library.tscn"
const GALLERY_LIBRARY_SCENE := "res://scenes/gallery_library.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const REPAIR_SCENE := "res://scenes/repair_transition.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const Scene01IntroPayloadEnglish := preload("res://scripts/story/payloads/intro/scene_01_intro.gd")
const Scene01IntroPayloadTagalog := preload("res://scripts/story/payloads/intro/scene_01_intro_tagalog.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const VEHICLE_TEXTURES := {
	"blue_truck": preload("res://assets/vehicles/blue_truck.png"),
	"gray_sedan": preload("res://assets/vehicles/gray_sedan.png"),
	"jeepney": preload("res://assets/vehicles/jeepney.png"),
	"sedan": preload("res://assets/vehicles/sedan.png"),
	"truck": preload("res://assets/vehicles/truck.png"),
}
const ROAD_ACTOR_Z_BASE := 10
const ROAD_ACTOR_Z_STEP := 10
const RESET_HOLD_SECONDS := 1.4
const LAST_ENERGY_WARNING := "Start the day with critically low energy?\nYour vehicle will handle worse until John recovers."
const START_FADE_SECONDS := 0.35

@onready var start_button: BaseButton = $Menu/StartButton
@onready var quit_button: BaseButton = $Menu/QuitButton
@onready var gallery_button: BaseButton = $Menu/GalleryButton
@onready var gallery_label: Label = $Menu/GalleryButton/GalleryLabel
@onready var achievements_button: BaseButton = $AchievementsButton
@onready var achievements_label: Label = $AchievementsButton/AchievementsLabel
@onready var background: TextureRect = $Background
@onready var traffic_layer: Node2D = $TrafficLayer
@onready var menu_trace_lines: Node2D = $MenuTraceLines
@onready var hint_label: Label = $Hint
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var debug_unlock_all_button: BaseButton = $DebugUnlockAllButton
@onready var debug_unlock_all_label: Label = $DebugUnlockAllButton/DebugUnlockAllLabel

var rng := RandomNumberGenerator.new()
var menu_vehicles: Array = []
var texture_hitbox_cache := {}
var reset_hold_time := 0.0
var reset_message_time := 0.0
var debug_unlock_message_time := 0.0
var debug_unlock_message_text := ""
var blocked_start_message_time := 0.0
var reset_hold_completed := false
var start_confirm_dialog: ConfirmationDialog
var is_start_transitioning := false
var audio_panel_refs: Dictionary = {}
var audio_toggle_button: TextureButton
var audio_toggle_label: Label
var language_toggle_button: TextureButton
var language_toggle_label: Label
var bgm_player: AudioStreamPlayer
var debug_unlock_overlay: ColorRect
var debug_unlock_panel: Panel
var debug_achievement_list: VBoxContainer
var debug_close_button: Button
var debug_unlock_gallery_memory_button: Button
var debug_unlock_memories_button: Button


func _ready() -> void:
	rng.randomize()
	start_button.grab_focus()
	gallery_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	achievements_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_unlock_all_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.pressed.connect(_start_game)
	quit_button.pressed.connect(_quit_game)
	gallery_button.pressed.connect(_open_gallery_library)
	achievements_button.pressed.connect(_open_achievements_library)
	debug_unlock_all_button.pressed.connect(_open_debug_unlock_panel)
	_apply_button_font(start_button)
	_apply_button_font(quit_button)
	_apply_button_font(gallery_button)
	_apply_button_font(achievements_button)
	_apply_button_font(debug_unlock_all_button)
	ButtonGlow.attach(self, start_button)
	ButtonGlow.attach(self, quit_button)
	ButtonGlow.attach(self, gallery_button)
	ButtonGlow.attach(self, achievements_button)
	ButtonGlow.attach(self, debug_unlock_all_button)
	debug_unlock_all_button.visible = OS.is_debug_build()
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_trace_lines.visible = false
	_build_audio_panel()
	_build_language_button()
	_build_debug_unlock_panel()
	_create_dialogs()
	MenuTrafficController.spawn(self)
	_start_main_menu_bgm()
	hint_label.text = _default_hint_text()


func _process(delta: float) -> void:
	_update_reset_progress(delta)
	MenuTrafficController.update(self, delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_debug_unlock_panel_open():
		if event.is_action_pressed("ui_cancel"):
			_close_debug_unlock_panel()
		return

	if event.is_action_pressed("ui_accept"):
		if gallery_button.has_focus():
			_open_gallery_library()
		elif achievements_button.has_focus():
			_open_achievements_library()
		elif quit_button.has_focus():
			_quit_game()
		else:
			_start_game()
	elif event.is_action_pressed("ui_cancel"):
		_quit_game()


func _start_game() -> void:
	if is_start_transitioning:
		return
	if PlayerState.is_run_failed():
		_fade_to_scene(GAME_OVER_SCENE)
		return

	if PlayerState.has_save_data():
		_continue_saved_game()
		return

	PlayerState.begin_stage_sequence()
	if PlayerState.energy <= GameTuning.CRITICAL_ENERGY_WARNING_THRESHOLD:
		start_confirm_dialog.popup_centered()
		return

	_confirm_start_game()


func _confirm_start_game() -> void:
	if not PlayerState.get_stage_start_error().is_empty():
		blocked_start_message_time = 1.8
		hint_label.text = "%s Hold R to reset progress" % PlayerState.get_stage_start_error()
		return

	is_start_transitioning = true
	start_button.disabled = true
	quit_button.disabled = true
	gallery_button.disabled = true
	achievements_button.disabled = true
	debug_unlock_all_button.disabled = true
	audio_toggle_button.disabled = true
	language_toggle_button.disabled = true
	PlayerState.set_pending_story(_build_intro_story_payload(
		HOUSE_DAY_START_SCENE,
		PlayerState.get_current_stage_type()
	))
	_fade_to_intro_story()


func _continue_saved_game() -> void:
	is_start_transitioning = true
	start_button.disabled = true
	quit_button.disabled = true
	gallery_button.disabled = true
	achievements_button.disabled = true
	debug_unlock_all_button.disabled = true
	audio_toggle_button.disabled = true
	language_toggle_button.disabled = true
	_fade_to_scene(_saved_resume_scene())


func _quit_game() -> void:
	if is_start_transitioning:
		return
	get_tree().quit()


func _open_achievements_library() -> void:
	if is_start_transitioning:
		return
	get_tree().change_scene_to_file(ACHIEVEMENTS_LIBRARY_SCENE)


func _open_gallery_library() -> void:
	if is_start_transitioning:
		return
	get_tree().change_scene_to_file(GALLERY_LIBRARY_SCENE)


func _debug_unlock_all() -> void:
	MainMenuDebug.debug_unlock_all(self)


func _create_dialogs() -> void:
	start_confirm_dialog = ConfirmationDialog.new()
	start_confirm_dialog.title = "Low Energy"
	start_confirm_dialog.dialog_text = LAST_ENERGY_WARNING
	start_confirm_dialog.get_ok_button().text = "START"
	start_confirm_dialog.get_cancel_button().text = "BACK"
	start_confirm_dialog.confirmed.connect(_confirm_start_game)
	add_child(start_confirm_dialog)


func _apply_button_font(button: BaseButton) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)


func _build_audio_panel() -> void:
	MainMenuSettings.build_audio_panel(self)


func _build_language_button() -> void:
	MainMenuSettings.build_language_button(self)


func _toggle_audio_panel() -> void:
	MainMenuSettings.toggle_audio_panel(self)


func _toggle_story_language() -> void:
	MainMenuSettings.toggle_story_language(self)


func _refresh_language_toggle_label() -> void:
	MainMenuSettings.refresh_language_toggle_label(self)


func _build_debug_unlock_panel() -> void:
	MainMenuDebug.build_debug_unlock_panel(self)


func _open_debug_unlock_panel() -> void:
	MainMenuDebug.open_debug_unlock_panel(self)


func _close_debug_unlock_panel() -> void:
	MainMenuDebug.close_debug_unlock_panel(self)


func _is_debug_unlock_panel_open() -> bool:
	return MainMenuDebug.is_debug_unlock_panel_open(self)


func _debug_unlock_achievement(achievement_id: String) -> void:
	MainMenuDebug.debug_unlock_achievement(self, achievement_id)


func _debug_unlock_gallery_memory_only() -> void:
	MainMenuDebug.debug_unlock_gallery_memory_only(self)


func _set_debug_unlock_message(message: String) -> void:
	MainMenuDebug.set_debug_unlock_message(self, message)


func _build_intro_story_payload(next_scene: String, stage_descriptor: String) -> Dictionary:
	if StoryLanguageManager.is_tagalog():
		return Scene01IntroPayloadTagalog.build(next_scene, stage_descriptor)
	return Scene01IntroPayloadEnglish.build(next_scene, stage_descriptor)


func _start_main_menu_bgm() -> void:
	MainMenuSettings.start_main_menu_bgm(self)


func _fade_to_intro_story() -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, START_FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file(STORY_SCENE)


func _fade_to_scene(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, START_FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


func _saved_resume_scene() -> String:
	if not PlayerState.active_event_special_stage.is_empty():
		return GAME_SCENE
	var saved_scene := PlayerState.get_resume_scene()
	match saved_scene:
		GAME_SCENE, STORY_SCENE, DAY_START_SCENE, HOUSE_DAY_START_SCENE, RIDE_SELECTION_SCENE, STORE_SCENE, STAGE_RESULTS_SCENE, SLEEP_TRANSITION_SCENE, GAME_OVER_SCENE, REPAIR_SCENE:
			return saved_scene

	if PlayerState.is_run_failed():
		return GAME_OVER_SCENE

	if not PlayerState.get_pending_story().is_empty():
		return STORY_SCENE
	if not PlayerState.get_pending_crash_repair().is_empty():
		return SLEEP_TRANSITION_SCENE if bool(PlayerState.get_pending_crash_repair().get("transition_started", false)) else REPAIR_SCENE
	if not PlayerState.get_pending_sleep_transition_state().is_empty():
		return SLEEP_TRANSITION_SCENE
	if not PlayerState.get_pending_trip_selection().is_empty():
		return RIDE_SELECTION_SCENE
	return GAME_SCENE


func _update_reset_progress(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		if reset_hold_completed:
			return
		reset_hold_time += delta
		var percent := clampf(reset_hold_time / RESET_HOLD_SECONDS, 0.0, 1.0)
		hint_label.text = "HOLD R reset progress  %d%%" % roundi(percent * 100.0)
		if reset_hold_time >= RESET_HOLD_SECONDS:
			PlayerState.reset()
			reset_hold_time = 0.0
			reset_message_time = 1.8
			reset_hold_completed = true
	else:
		reset_hold_time = 0.0
		reset_hold_completed = false
		if reset_message_time > 0.0:
			reset_message_time -= delta
			hint_label.text = "Progress reset"
		elif debug_unlock_message_time > 0.0:
			debug_unlock_message_time -= delta
			hint_label.text = debug_unlock_message_text
		elif blocked_start_message_time > 0.0:
			blocked_start_message_time -= delta
			hint_label.text = _default_hint_text() if PlayerState.is_run_failed() else "No energy left. Hold R to reset progress"
		else:
			hint_label.text = _default_hint_text()


func _default_hint_text() -> String:
	if PlayerState.is_run_failed():
		return "%s" % PlayerState.get_run_fail_reason()
	return "ENTER select     ESC quit     HOLD R reset progress"
