extends Control

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
const AudioSettingsPanel := preload("res://scripts/ui/audio_settings_panel.gd")
const AchievementServiceData := preload("res://scripts/achievement_service.gd")
const StoryMemoryCatalog := preload("res://scripts/story/story_memory_catalog.gd")
const Scene01IntroPayloadEnglish := preload("res://scripts/story/payloads/intro/scene_01_intro.gd")
const Scene01IntroPayloadTagalog := preload("res://scripts/story/payloads/intro/scene_01_intro_tagalog.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GENERIC_BUTTON_TEXTURE := preload("res://assets/ui/buttons/button_generic.png")
const MAIN_MENU_BGM_PATH := "res://assets/audio/music/story/peace.mp3"
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
	if is_start_transitioning:
		return
	StoryMemoryCatalog.unlock_all(PlayerState)
	_set_debug_unlock_message("Gallery and memories unlocked")


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


func _apply_debug_button_theme(button: BaseButton) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.52, 0.95))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	button.add_theme_constant_override("outline_size", 1)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.17, 0.12, 0.96)
	normal_style.border_color = Color(0.60, 0.45, 0.26, 1.0)
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(7)
	normal_style.content_margin_left = 14.0
	normal_style.content_margin_right = 14.0
	normal_style.content_margin_top = 10.0
	normal_style.content_margin_bottom = 10.0

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.83, 0.63, 0.33, 0.98)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.35, 0.48, 0.31, 0.98)

	var disabled_style := normal_style.duplicate()
	disabled_style.bg_color = Color(0.16, 0.13, 0.11, 0.92)
	disabled_style.border_color = Color(0.34, 0.28, 0.22, 1.0)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)


func _apply_debug_panel_theme(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.97)
	style.border_color = Color(0.71, 0.56, 0.31, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	panel.add_theme_stylebox_override("panel", style)


func _build_audio_panel() -> void:
	audio_panel_refs = AudioSettingsPanel.create(
		self,
		self,
		UI_FONT,
		Vector2(26.0, 84.0),
		Vector2(356.0, 222.0),
		"AUDIO SETTINGS"
	)
	var audio_panel := audio_panel_refs.get("panel") as Panel
	if audio_panel:
		audio_panel.visible = false

	audio_toggle_button = TextureButton.new()
	audio_toggle_button.z_index = 10
	audio_toggle_button.texture_normal = GENERIC_BUTTON_TEXTURE
	audio_toggle_button.texture_pressed = GENERIC_BUTTON_TEXTURE
	audio_toggle_button.texture_hover = GENERIC_BUTTON_TEXTURE
	audio_toggle_button.texture_focused = GENERIC_BUTTON_TEXTURE
	audio_toggle_button.ignore_texture_size = true
	audio_toggle_button.stretch_mode = TextureButton.STRETCH_SCALE
	audio_toggle_button.position = Vector2(26.0, 22.0)
	audio_toggle_button.size = Vector2(240.0, 48.0)
	audio_toggle_button.tooltip_text = "Toggle Audio Settings"
	add_child(audio_toggle_button)

	audio_toggle_label = Label.new()
	audio_toggle_label.anchor_right = 1.0
	audio_toggle_label.anchor_bottom = 1.0
	audio_toggle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	audio_toggle_label.text = "AUDIO"
	audio_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	audio_toggle_label.add_theme_font_override("font", UI_FONT)
	audio_toggle_label.add_theme_font_size_override("font_size", 14)
	audio_toggle_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	audio_toggle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	audio_toggle_label.add_theme_constant_override("outline_size", 1)
	audio_toggle_button.add_child(audio_toggle_label)
	ButtonGlow.attach(self, audio_toggle_button)
	audio_toggle_button.pressed.connect(_toggle_audio_panel)


func _build_language_button() -> void:
	language_toggle_button = TextureButton.new()
	language_toggle_button.z_index = 10
	language_toggle_button.texture_normal = GENERIC_BUTTON_TEXTURE
	language_toggle_button.texture_pressed = GENERIC_BUTTON_TEXTURE
	language_toggle_button.texture_hover = GENERIC_BUTTON_TEXTURE
	language_toggle_button.texture_focused = GENERIC_BUTTON_TEXTURE
	language_toggle_button.ignore_texture_size = true
	language_toggle_button.stretch_mode = TextureButton.STRETCH_SCALE
	language_toggle_button.position = Vector2(26.0, 602.0)
	language_toggle_button.size = Vector2(300.0, 48.0)
	language_toggle_button.tooltip_text = "Toggle Story Language"
	add_child(language_toggle_button)

	language_toggle_label = Label.new()
	language_toggle_label.anchor_right = 1.0
	language_toggle_label.anchor_bottom = 1.0
	language_toggle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	language_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	language_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	language_toggle_label.add_theme_font_override("font", UI_FONT)
	language_toggle_label.add_theme_font_size_override("font_size", 14)
	language_toggle_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	language_toggle_label.add_theme_color_override("font_outline_color", Color.BLACK)
	language_toggle_label.add_theme_constant_override("outline_size", 1)
	language_toggle_button.add_child(language_toggle_label)
	ButtonGlow.attach(self, language_toggle_button)
	language_toggle_button.pressed.connect(_toggle_story_language)
	_refresh_language_toggle_label()


func _toggle_audio_panel() -> void:
	var audio_panel := audio_panel_refs.get("panel") as Panel
	if audio_panel == null:
		return
	audio_panel.visible = not audio_panel.visible
	audio_toggle_label.text = "AUDIO  -" if audio_panel.visible else "AUDIO"


func _toggle_story_language() -> void:
	StoryLanguageManager.toggle_language()
	_refresh_language_toggle_label()


func _refresh_language_toggle_label() -> void:
	if language_toggle_label == null:
		return
	language_toggle_label.text = "LANG: %s" % StoryLanguageManager.get_language_label()


func _build_debug_unlock_panel() -> void:
	debug_unlock_overlay = ColorRect.new()
	debug_unlock_overlay.z_index = 40
	debug_unlock_overlay.visible = false
	debug_unlock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_unlock_overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	debug_unlock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(debug_unlock_overlay)

	debug_unlock_panel = Panel.new()
	debug_unlock_panel.custom_minimum_size = Vector2(680.0, 500.0)
	debug_unlock_panel.size = Vector2(680.0, 500.0)
	debug_unlock_panel.position = Vector2(300.0, 86.0)
	_apply_debug_panel_theme(debug_unlock_panel)
	debug_unlock_overlay.add_child(debug_unlock_panel)

	var title_label := Label.new()
	title_label.text = "DEBUG UNLOCK"
	title_label.position = Vector2(28.0, 20.0)
	title_label.size = Vector2(460.0, 36.0)
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 1)
	debug_unlock_panel.add_child(title_label)

	debug_close_button = Button.new()
	debug_close_button.text = "CLOSE"
	debug_close_button.position = Vector2(526.0, 18.0)
	debug_close_button.size = Vector2(126.0, 42.0)
	_apply_debug_button_theme(debug_close_button)
	debug_close_button.pressed.connect(_close_debug_unlock_panel)
	debug_unlock_panel.add_child(debug_close_button)
	ButtonGlow.attach(self, debug_close_button)
	UIAudioManager.attach_button(debug_close_button)

	var tabs := TabContainer.new()
	tabs.position = Vector2(24.0, 76.0)
	tabs.size = Vector2(632.0, 396.0)
	tabs.clip_contents = true
	debug_unlock_panel.add_child(tabs)

	var achievements_tab := MarginContainer.new()
	achievements_tab.name = "ACHIEVEMENTS"
	achievements_tab.add_theme_constant_override("margin_left", 10)
	achievements_tab.add_theme_constant_override("margin_top", 14)
	achievements_tab.add_theme_constant_override("margin_right", 10)
	achievements_tab.add_theme_constant_override("margin_bottom", 10)
	tabs.add_child(achievements_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	achievements_tab.add_child(scroll)

	debug_achievement_list = VBoxContainer.new()
	debug_achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_achievement_list.add_theme_constant_override("separation", 8)
	scroll.add_child(debug_achievement_list)

	var all_tab := MarginContainer.new()
	all_tab.name = "ALL"
	all_tab.add_theme_constant_override("margin_left", 10)
	all_tab.add_theme_constant_override("margin_top", 14)
	all_tab.add_theme_constant_override("margin_right", 10)
	all_tab.add_theme_constant_override("margin_bottom", 10)
	tabs.add_child(all_tab)

	var all_box := VBoxContainer.new()
	all_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_box.add_theme_constant_override("separation", 12)
	all_tab.add_child(all_box)

	var all_label := Label.new()
	all_label.text = "Unlock gallery memories only, or unlock every debug reward at once."
	all_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	all_label.add_theme_font_override("font", UI_FONT)
	all_label.add_theme_font_size_override("font_size", 10)
	all_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	all_box.add_child(all_label)

	debug_unlock_gallery_memory_button = Button.new()
	debug_unlock_gallery_memory_button.custom_minimum_size = Vector2(0.0, 56.0)
	debug_unlock_gallery_memory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_unlock_gallery_memory_button.text = "UNLOCK GALLERY + MEMORY ONLY"
	_apply_debug_button_theme(debug_unlock_gallery_memory_button)
	debug_unlock_gallery_memory_button.pressed.connect(_debug_unlock_gallery_memory_only)
	all_box.add_child(debug_unlock_gallery_memory_button)
	ButtonGlow.attach(self, debug_unlock_gallery_memory_button)
	UIAudioManager.attach_button(debug_unlock_gallery_memory_button)

	debug_unlock_memories_button = Button.new()
	debug_unlock_memories_button.custom_minimum_size = Vector2(0.0, 56.0)
	debug_unlock_memories_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_unlock_memories_button.text = "UNLOCK GALLERY + MEMORY + ACHIEVEMENTS"
	_apply_debug_button_theme(debug_unlock_memories_button)
	debug_unlock_memories_button.pressed.connect(_debug_unlock_all)
	all_box.add_child(debug_unlock_memories_button)
	ButtonGlow.attach(self, debug_unlock_memories_button)
	UIAudioManager.attach_button(debug_unlock_memories_button)

	_refresh_debug_achievement_list()


func _open_debug_unlock_panel() -> void:
	if is_start_transitioning or debug_unlock_overlay == null:
		return
	_refresh_debug_achievement_list()
	debug_unlock_overlay.visible = true
	debug_close_button.grab_focus()


func _close_debug_unlock_panel() -> void:
	if debug_unlock_overlay == null:
		return
	debug_unlock_overlay.visible = false


func _is_debug_unlock_panel_open() -> bool:
	return debug_unlock_overlay != null and debug_unlock_overlay.visible


func _refresh_debug_achievement_list() -> void:
	if debug_achievement_list == null:
		return
	for child in debug_achievement_list.get_children():
		child.queue_free()

	for achievement_id_variant in AchievementServiceData.ORDER:
		var achievement_id := str(achievement_id_variant)
		var achievement_data := PlayerState.get_achievement_data(achievement_id)
		if achievement_data.is_empty():
			continue

		var is_unlocked := bool(achievement_data.get("unlocked", false))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s / %s%s" % [
			str(achievement_data.get("title", "")).to_upper(),
			str(achievement_data.get("subtitle", "")),
			"  UNLOCKED" if is_unlocked else "",
		]
		button.disabled = is_unlocked
		_apply_debug_button_theme(button)
		if not is_unlocked:
			button.pressed.connect(_debug_unlock_achievement.bind(achievement_id))
		debug_achievement_list.add_child(button)
		ButtonGlow.attach(self, button)
		UIAudioManager.attach_button(button)


func _debug_unlock_achievement(achievement_id: String) -> void:
	var achievement_data := PlayerState.get_achievement_data(achievement_id)
	if achievement_data.is_empty():
		return
	PlayerState.unlock_achievement(achievement_id)
	_refresh_debug_achievement_list()
	_set_debug_unlock_message("Achievement unlocked: %s" % str(achievement_data.get("title", achievement_id)).to_upper())


func _debug_unlock_gallery_memory_only() -> void:
	StoryMemoryCatalog.unlock_gallery_and_memories_only(PlayerState)
	_set_debug_unlock_message("Gallery and memories unlocked")


func _set_debug_unlock_message(message: String) -> void:
	debug_unlock_message_text = message
	debug_unlock_message_time = 1.8
	hint_label.text = debug_unlock_message_text


func _build_intro_story_payload(next_scene: String, stage_descriptor: String) -> Dictionary:
	if StoryLanguageManager.is_tagalog():
		return Scene01IntroPayloadTagalog.build(next_scene, stage_descriptor)
	return Scene01IntroPayloadEnglish.build(next_scene, stage_descriptor)


func _start_main_menu_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "MainMenuBGMPlayer"
	bgm_player.stream = load(MAIN_MENU_BGM_PATH)
	bgm_player.autoplay = false
	bgm_player.bus = &"Master"
	add_child(bgm_player)
	AudioSettingsManager.register_player(bgm_player, "music")
	bgm_player.play()


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
