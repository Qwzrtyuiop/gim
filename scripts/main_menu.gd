extends Control

const MainMenuDebug := preload("res://scripts/menu/main_menu_debug.gd")
const MainMenuSettings := preload("res://scripts/menu/main_menu_settings.gd")

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const MenuTrafficController := preload("res://scripts/game/menu_traffic_controller.gd")

const STORY_SCENE := "res://scenes/story_scene.tscn"
const HOUSE_DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const ACHIEVEMENTS_LIBRARY_SCENE := "res://scenes/achievements_library.tscn"
const GALLERY_LIBRARY_SCENE := "res://scenes/gallery_library.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const SaveSlotScreen := preload("res://scripts/ui/save_slot_screen.gd")
const SaveGameContext := preload("res://scripts/save/save_game_context.gd")
const LOAD_BUTTON_TEXTURE := preload("res://assets/ui/buttons/button_generic.png")
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
const HIGH_STRESS_WARNING := "Start the day with high stress?\nYour vehicle will handle worse until John recovers."
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
var load_button: TextureButton
var save_slot_screen: SaveSlotScreen
var _load_disabled_controls: Dictionary = {}


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
	_build_save_slot_screen()
	_create_dialogs()
	MenuTrafficController.spawn(self)
	_start_main_menu_bgm()
	hint_label.text = _default_hint_text()


func _process(delta: float) -> void:
	_update_reset_progress(delta)
	MenuTrafficController.update(self, delta)


func _unhandled_input(event: InputEvent) -> void:
	if save_slot_screen != null and save_slot_screen.visible:
		if event.is_action_pressed("ui_cancel"):
			save_slot_screen.handle_cancel()
			get_viewport().set_input_as_handled()
		return
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
		elif load_button.has_focus():
			_open_load_slots()
		else:
			_start_game()
	elif event.is_action_pressed("ui_cancel"):
		_quit_game()


func _start_game() -> void:
	if is_start_transitioning:
		return

	PlayerState.reset()
	PlayerState.begin_stage_sequence()
	if PlayerState.stress >= GameTuning.STRESS_WARNING_THRESHOLD:
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
	load_button.disabled = true
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


func _build_save_slot_screen() -> void:
	load_button = TextureButton.new()
	load_button.name = "LoadButton"
	load_button.z_index = 10
	load_button.texture_normal = LOAD_BUTTON_TEXTURE
	load_button.texture_hover = LOAD_BUTTON_TEXTURE
	load_button.texture_pressed = LOAD_BUTTON_TEXTURE
	load_button.texture_focused = LOAD_BUTTON_TEXTURE
	load_button.ignore_texture_size = true
	load_button.stretch_mode = TextureButton.STRETCH_SCALE
	load_button.anchor_top = 1.0
	load_button.anchor_bottom = 1.0
	load_button.offset_left = 38
	load_button.offset_right = 286
	load_button.offset_top = -170
	load_button.offset_bottom = -128
	load_button.tooltip_text = "Load a saved game"
	load_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(load_button)
	var label := Label.new()
	label.text = "LOAD GAME"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	load_button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ButtonGlow.attach(self, load_button)
	load_button.pressed.connect(_open_load_slots)
	save_slot_screen = SaveSlotScreen.new()
	save_slot_screen.name = "LoadSlots"
	save_slot_screen.z_index = 150
	add_child(save_slot_screen)
	save_slot_screen.closed.connect(_close_load_slots)
	save_slot_screen.load_requested.connect(_load_slot)
	save_slot_screen.delete_requested.connect(_delete_slot)
	SaveSlotManager.slots_changed.connect(_refresh_load_availability)
	_refresh_load_availability()


func _open_load_slots() -> void:
	if is_start_transitioning or save_slot_screen.visible:
		return
	_close_debug_unlock_panel()
	var audio_panel := audio_panel_refs.get("panel") as Panel
	if audio_panel != null:
		audio_panel.hide()
	_load_disabled_controls.clear()
	for button: BaseButton in _menu_controls():
		_load_disabled_controls[button] = button.disabled
		button.disabled = true
	save_slot_screen.open("load", SaveSlotManager.list_slots(), false)


func _close_load_slots() -> void:
	for button in _load_disabled_controls:
		if is_instance_valid(button):
			button.disabled = bool(_load_disabled_controls[button])
	_load_disabled_controls.clear()
	_refresh_load_availability()
	if not is_start_transitioning:
		start_button.grab_focus()


func _load_slot(slot: int) -> void:
	if is_start_transitioning:
		return
	if not SaveSlotManager.load_slot(slot):
		save_slot_screen.refresh_slots(SaveSlotManager.list_slots())
		save_slot_screen.show_status("Couldn't load this save. Choose another slot.", false)
		return
	save_slot_screen.close()
	is_start_transitioning = true
	for button: BaseButton in _menu_controls():
		button.disabled = true
	_fade_to_scene(SaveGameContext.resume_scene())


func _delete_slot(slot: int) -> void:
	if is_start_transitioning:
		return
	var error: Error = SaveSlotManager.delete_slot(slot)
	save_slot_screen.refresh_slots(SaveSlotManager.list_slots())
	save_slot_screen.show_status("Deleted slot %02d." % slot if error == OK else "Could not delete: %s" % error_string(error), error == OK)


func _refresh_load_availability() -> void:
	if load_button != null and (save_slot_screen == null or not save_slot_screen.visible):
		var has_save_file := false
		for entry: Dictionary in SaveSlotManager.list_slots():
			if bool(entry.get("exists", false)):
				has_save_file = true
				break
		load_button.disabled = is_start_transitioning or not has_save_file


func _menu_controls() -> Array[BaseButton]:
	return [start_button, quit_button, gallery_button, achievements_button, debug_unlock_all_button, audio_toggle_button, language_toggle_button, load_button]


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
	start_confirm_dialog.title = "High Stress"
	start_confirm_dialog.dialog_text = HIGH_STRESS_WARNING
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


func _update_reset_progress(delta: float) -> void:
	if is_start_transitioning or (save_slot_screen != null and save_slot_screen.visible):
		reset_hold_time = 0.0
		reset_hold_completed = true
		return
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
			hint_label.text = _default_hint_text() if PlayerState.is_run_failed() else "%s" % PlayerState.get_stage_start_error()
		else:
			hint_label.text = _default_hint_text()


func _default_hint_text() -> String:
	if PlayerState.is_run_failed():
		return "%s" % PlayerState.get_run_fail_reason()
	return "ENTER select     ESC quit     HOLD R reset progress"
