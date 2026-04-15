extends Control

const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")
const INTRO_FADE_SECONDS := 0.35
const OUTRO_FADE_SECONDS := 0.35
const DEFAULT_SCREEN_FADE_SECONDS := 0.24
const DEFAULT_MUSIC_FADE_SECONDS := 0.35
const DEFAULT_CONTINUE_HINT := "ENTER / CLICK"
const DEFAULT_BG_CAMERA_DURATION := 0.0
const DEFAULT_BG_FADE_SECONDS := 0.24
const MIN_BG_ZOOM := 0.7
const DEFAULT_BG_FIT_SCALE := 0.94

const DIALOGUE_PANEL_COLOR := Color(0.09, 0.08, 0.07, 0.92)
const DIALOGUE_PANEL_BORDER := Color(0.71, 0.58, 0.39, 0.95)
const PORTRAIT_PANEL_COLOR := Color(0.12, 0.10, 0.09, 0.82)
const PORTRAIT_PANEL_BORDER := Color(0.60, 0.48, 0.33, 0.95)
const ACTIVE_PORTRAIT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const INACTIVE_PORTRAIT_MODULATE := Color(0.56, 0.56, 0.60, 0.82)
const CHOICE_BUTTON_BG := Color(0.42, 0.27, 0.17, 0.96)
const CHOICE_BUTTON_HOVER_BG := Color(0.78, 0.59, 0.29, 0.98)
const CHOICE_BUTTON_PRESSED_BG := Color(0.28, 0.45, 0.28, 0.98)
const CHOICE_BUTTON_BORDER := Color(0.13, 0.09, 0.06, 0.98)

@onready var background: TextureRect = $Background
@onready var background_fade_overlay: ColorRect = $BackgroundFadeOverlay
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var chapter_label: Label = $ChapterLabel
@onready var debt_overlay: Panel = $DebtOverlay
@onready var debt_remaining_label: Label = $DebtOverlay/DebtRemainingLabel
@onready var debt_due_label: Label = $DebtOverlay/DebtDueLabel
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var left_portrait_frame: Panel = $LeftPortraitFrame
@onready var left_portrait: TextureRect = $LeftPortraitFrame/LeftPortrait
@onready var right_portrait_frame: Panel = $RightPortraitFrame
@onready var right_portrait: TextureRect = $RightPortraitFrame/RightPortrait
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/SpeakerLabel
@onready var body_label: Label = $DialoguePanel/BodyLabel
@onready var continue_label: Label = $DialoguePanel/ContinueLabel
@onready var choice_container: VBoxContainer = $ChoiceContainer

var story_payload: Dictionary = {}
var story_lines: Array[Dictionary] = []
var current_line_index := -1
var current_background_ref = null
var current_left_portrait_ref = null
var current_right_portrait_ref = null
var current_focus_side := "none"
var return_scene_path := FALLBACK_SCENE
var complete_scene_path := ""
var story_id := ""
var choice_buttons: Array[BaseButton] = []
var background_zoom := 1.0
var background_pan := Vector2.ZERO
var background_motion_tween: Tween
var bgm_fade_tween: Tween
var debt_overlay_tween: Tween
var is_input_locked := false


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/story_scene.tscn")
	_apply_theme()
	_load_story_payload()
	_refresh_background_transform()
	await _play_intro_fade()
	var resume_index := PlayerState.get_last_seen_story_section(story_id)
	if resume_index < 0 or resume_index >= story_lines.size():
		resume_index = 0
	await _restore_story_music_state(resume_index)
	await _show_line(resume_index)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if is_input_locked or _has_active_choices():
		return

	if event.is_action_pressed("ui_accept"):
		_advance_story()
	elif event.is_action_pressed("ui_cancel"):
		_finish_story()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_story()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_background_transform()


func _load_story_payload() -> void:
	var pending_story := PlayerState.get_pending_story()
	if pending_story.is_empty():
		story_payload = _preview_story_payload()
	else:
		story_payload = pending_story

	story_lines.clear()
	var raw_lines: Array = []
	if story_payload.has("composition"):
		raw_lines = story_payload.get("composition", [])
	elif story_payload.has("sections"):
		raw_lines = story_payload.get("sections", [])
	else:
		raw_lines = story_payload.get("lines", [])
	for line_data in raw_lines:
		if line_data is Dictionary:
			story_lines.append((line_data as Dictionary).duplicate(true))

	chapter_label.text = str(story_payload.get("chapter_title", "STORY")).to_upper()
	story_id = str(story_payload.get("story_id", chapter_label.text.to_lower().replace(" ", "_")))
	return_scene_path = str(story_payload.get("return_scene", FALLBACK_SCENE))
	if return_scene_path.is_empty():
		return_scene_path = FALLBACK_SCENE
	complete_scene_path = str(story_payload.get("next_scene", ""))
	current_background_ref = story_payload.get("background", null)
	current_left_portrait_ref = story_payload.get("left_portrait", null)
	current_right_portrait_ref = story_payload.get("right_portrait", null)


func _restore_story_music_state(resume_index: int) -> void:
	var last_music_action: Dictionary = {}
	var should_stop_music := false

	var payload_music_action := _build_payload_music_action()
	if not payload_music_action.is_empty():
		last_music_action = payload_music_action

	var capped_index := clampi(resume_index, 0, story_lines.size())
	for line_index in range(capped_index):
		var line_data: Dictionary = story_lines[line_index]
		var raw_actions: Array = line_data.get("actions", line_data.get("triggers", []))
		for action_data_variant in raw_actions:
			if not action_data_variant is Dictionary:
				continue
			var action_data: Dictionary = (action_data_variant as Dictionary).duplicate(true)
			var action_type := str(action_data.get("type", action_data.get("action", ""))).to_lower()
			match action_type:
				"play_music", "music_play":
					last_music_action = action_data
					should_stop_music = false
				"stop_music", "music_stop":
					last_music_action.clear()
					should_stop_music = true

	if should_stop_music:
		bgm_player.stop()
		return

	if not last_music_action.is_empty():
		var restore_action := last_music_action.duplicate(true)
		restore_action["fade_in"] = 0.0
		restore_action["fade_out"] = 0.0
		restore_action["restart"] = true
		await _play_music_action(restore_action)


func _build_payload_music_action() -> Dictionary:
	var payload_bgm = story_payload.get("bgm", story_payload.get("music", null))
	if payload_bgm == null:
		return {}
	if payload_bgm is Dictionary:
		return (payload_bgm as Dictionary).duplicate(true)

	var path := str(payload_bgm).strip_edges()
	if path.is_empty():
		return {}
	return {
		"type": "play_music",
		"path": path,
		"loop": bool(story_payload.get("music_loop", story_payload.get("bgm_loop", true))),
		"fade_in": float(story_payload.get("music_fade_in", story_payload.get("bgm_fade_in", DEFAULT_MUSIC_FADE_SECONDS))),
		"volume_db": float(story_payload.get("music_volume_db", story_payload.get("bgm_volume_db", 0.0))),
	}


func _show_line(index: int) -> void:
	if story_lines.is_empty() or index < 0 or index >= story_lines.size():
		_finish_story()
		return

	is_input_locked = true
	current_line_index = index
	PlayerState.set_last_seen_story_section(story_id, index)
	var line := story_lines[index]
	continue_label.visible = false
	await _pause_for_seconds(float(line.get("pause_before", 0.0)))
	await _apply_line_visuals(line)
	_apply_line_text(line)
	await _run_line_actions(line)
	_render_choices(line)
	await _pause_for_seconds(float(line.get("pause_after", 0.0)))
	is_input_locked = false


func _apply_line_visuals(line: Dictionary) -> void:
	var background_changed := false
	var next_background_ref = current_background_ref
	if line.has("background"):
		next_background_ref = line.get("background", null)
		background_changed = next_background_ref != current_background_ref
	if line.has("left_portrait"):
		current_left_portrait_ref = line.get("left_portrait", null)
	if line.has("right_portrait"):
		current_right_portrait_ref = line.get("right_portrait", null)

	var background_fade_duration := float(line.get("background_fade", line.get("bg_fade", 0.0)))
	if line.has("background") and background_fade_duration > 0.0:
		await _transition_background_with_fade(next_background_ref, background_changed, line, background_fade_duration)
	else:
		if line.has("background"):
			current_background_ref = next_background_ref
			_set_background_texture(current_background_ref, background_changed)
		_apply_line_background_camera(line)
	if line.has("show_debt_overlay"):
		await _show_debt_overlay(line.get("show_debt_overlay", {}))
	if line.has("hide_debt_overlay"):
		await _hide_debt_overlay(line.get("hide_debt_overlay", {}))
	_set_portrait(left_portrait_frame, left_portrait, current_left_portrait_ref)
	_set_portrait(right_portrait_frame, right_portrait, current_right_portrait_ref)
	_apply_portrait_focus_from_side(str(line.get("focus", line.get("speaker_side", "none"))))


func _apply_line_text(line: Dictionary) -> void:
	var speaker := str(line.get("speaker", ""))
	var body_text := str(line.get("text", ""))
	var continue_text := str(line.get("continue_hint", DEFAULT_CONTINUE_HINT))
	_set_dialogue_content(speaker, body_text, continue_text, true)


func _run_line_actions(line: Dictionary) -> void:
	var raw_actions: Array = line.get("actions", line.get("triggers", []))
	for action_data_variant in raw_actions:
		if action_data_variant is Dictionary:
			await _run_story_action((action_data_variant as Dictionary).duplicate(true))


func _render_choices(line: Dictionary) -> void:
	_clear_choice_buttons()
	var raw_choices: Array = line.get("choices", [])
	if raw_choices.is_empty():
		choice_container.visible = false
		continue_label.visible = true
		return

	continue_label.visible = false
	choice_container.visible = true

	for choice_data_variant in raw_choices:
		if not choice_data_variant is Dictionary:
			continue

		var choice_data: Dictionary = (choice_data_variant as Dictionary).duplicate(true)
		var button := Button.new()
		button.custom_minimum_size = Vector2(420.0, 54.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(choice_data.get("text", "CONTINUE"))
		var is_disabled := bool(choice_data.get("disabled", not bool(choice_data.get("enabled", true))))
		button.disabled = is_disabled
		button.focus_mode = Control.FOCUS_NONE if is_disabled else Control.FOCUS_ALL
		_apply_choice_button_theme(button)
		if not is_disabled:
			button.pressed.connect(_choose_branch.bind(choice_data))
		choice_container.add_child(button)
		choice_buttons.append(button)
		if not is_disabled:
			ButtonGlow.attach(self, button)

	for button in choice_buttons:
		if is_instance_valid(button) and not button.disabled:
			button.grab_focus()
			break


func _run_choice_actions(choice_data: Dictionary) -> void:
	if choice_data.has("event_values"):
		PlayerState.set_event_values(choice_data.get("event_values", {}))
	elif choice_data.has("event_id") or choice_data.has("event_value") or choice_data.has("key"):
		PlayerState.set_event_values(
			StoryEventHandler.build_single_event_values(
				str(choice_data.get("event_id", choice_data.get("key", ""))),
				choice_data.get("event_value", choice_data.get("value", 1))
			)
		)

	var raw_actions: Array = choice_data.get("actions", choice_data.get("effects", []))
	for action_data_variant in raw_actions:
		if action_data_variant is Dictionary:
			await _run_story_action((action_data_variant as Dictionary).duplicate(true))


func _build_choice_response_line(choice_data: Dictionary, explicit_next_scene: String, next_index: int) -> Dictionary:
	var response_line: Dictionary = {}
	var response_variant = choice_data.get("response", null)
	if response_variant is Dictionary:
		response_line = (response_variant as Dictionary).duplicate(true)
	else:
		var response_keys := {
			"speaker": "response_speaker",
			"text": "response_text",
			"continue_hint": "response_continue_hint",
			"background": "response_background",
			"focus": "response_focus",
			"left_portrait": "response_left_portrait",
			"right_portrait": "response_right_portrait",
			"background_fade": "response_background_fade",
			"pause_before": "response_pause_before",
			"pause_after": "response_pause_after",
			"camera": "response_camera",
			"choices": "response_choices",
		}
		for response_key in response_keys:
			var choice_key: String = response_keys[response_key]
			if choice_data.has(choice_key):
				response_line[response_key] = choice_data.get(choice_key)

		var response_actions: Array = choice_data.get("response_actions", [])
		if not response_actions.is_empty():
			response_line["actions"] = response_actions.duplicate(true)

	if response_line.is_empty():
		return {}

	if not response_line.has("next_scene") and not explicit_next_scene.is_empty():
		response_line["next_scene"] = explicit_next_scene
	elif not response_line.has("next_index"):
		response_line["next_index"] = next_index

	return response_line


func _advance_story() -> void:
	if _has_active_choices():
		return

	var line := _current_line()
	if line.is_empty():
		_finish_story()
		return

	var explicit_next_scene := str(line.get("next_scene", ""))
	if not explicit_next_scene.is_empty():
		complete_scene_path = explicit_next_scene
		_finish_story()
		return

	var next_index := current_line_index + 1
	if line.has("next_index"):
		next_index = int(line.get("next_index", next_index))

	_show_line(next_index)


func _choose_branch(choice_data: Dictionary) -> void:
	await _run_choice_actions(choice_data)
	var explicit_next_scene := str(choice_data.get("next_scene", ""))
	var next_index := int(choice_data.get("next_index", current_line_index + 1))
	var response_line := _build_choice_response_line(choice_data, explicit_next_scene, next_index)
	if not response_line.is_empty():
		story_lines.insert(current_line_index + 1, response_line)
		_show_line(current_line_index + 1)
		return

	if not explicit_next_scene.is_empty():
		complete_scene_path = explicit_next_scene
		_finish_story()
		return

	_show_line(next_index)


func _finish_story() -> void:
	var target_scene := complete_scene_path
	if target_scene.is_empty():
		target_scene = return_scene_path
	if target_scene.is_empty():
		target_scene = FALLBACK_SCENE

	if bool(story_payload.get("prepare_stage_start", false)):
		var stage_descriptor := str(story_payload.get("stage_descriptor", ""))
		if not PlayerState.prepare_stage_start(stage_descriptor):
			target_scene = return_scene_path if not return_scene_path.is_empty() else FALLBACK_SCENE

	await _play_outro_fade()
	PlayerState.clear_pending_story()
	get_tree().change_scene_to_file(target_scene)


func _apply_portrait_focus_from_side(focus_side: String) -> void:
	current_focus_side = str(focus_side).to_lower()
	var left_visible := left_portrait_frame.visible
	var right_visible := right_portrait_frame.visible

	if current_focus_side.is_empty() or current_focus_side == "none":
		if left_visible and not right_visible:
			current_focus_side = "left"
		elif right_visible and not left_visible:
			current_focus_side = "right"

	if left_visible:
		left_portrait_frame.modulate = ACTIVE_PORTRAIT_MODULATE if current_focus_side == "left" else INACTIVE_PORTRAIT_MODULATE
	if right_visible:
		right_portrait_frame.modulate = ACTIVE_PORTRAIT_MODULATE if current_focus_side == "right" else INACTIVE_PORTRAIT_MODULATE


func _set_portrait(frame: Panel, portrait_rect: TextureRect, texture_ref) -> void:
	var portrait_texture := _resolve_texture(texture_ref)
	frame.visible = portrait_texture != null
	portrait_rect.texture = portrait_texture
	if frame.visible:
		frame.modulate = INACTIVE_PORTRAIT_MODULATE


func _set_background_texture(texture_ref, reset_camera := false) -> void:
	var resolved_texture := _resolve_texture(texture_ref)
	background.texture = resolved_texture
	background.visible = resolved_texture != null
	if reset_camera:
		background_zoom = 1.0
		background_pan = Vector2.ZERO
	_refresh_background_transform()


func _resolve_texture(texture_ref) -> Texture2D:
	if texture_ref is Texture2D:
		return texture_ref as Texture2D

	var texture_path := str(texture_ref)
	if texture_path.is_empty():
		return null
	if not ResourceLoader.exists(texture_path):
		return null

	var resource := load(texture_path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _resolve_audio_stream(stream_ref) -> AudioStream:
	if stream_ref is AudioStream:
		return stream_ref as AudioStream

	var stream_path := str(stream_ref)
	if stream_path.is_empty():
		return null
	if not ResourceLoader.exists(stream_path):
		return null

	var resource := load(stream_path)
	if resource is AudioStream:
		return resource as AudioStream
	return null


func _has_active_choices() -> bool:
	return choice_container.visible and not choice_buttons.is_empty()


func _clear_choice_buttons() -> void:
	for button in choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	choice_buttons.clear()


func _current_line() -> Dictionary:
	if current_line_index < 0 or current_line_index >= story_lines.size():
		return {}
	return story_lines[current_line_index]


func _preview_story_payload() -> Dictionary:
	return {
		"chapter_title": "Story Scene",
		"return_scene": FALLBACK_SCENE,
		"composition": [
			{
				"speaker": "Narrator",
				"text": "This scene is ready to handle dialogue sequences.",
				"actions": [
					{
						"type": "portrait_switch",
						"side": "none",
					}
				],
			},
			{
				"speaker": "System",
				"text": "Each section can now fire actions for music, portrait swaps, focus changes, and dialogue updates.",
				"choices": [
					{
						"text": "Continue",
						"next_index": 2,
					}
				],
			},
			{
				"speaker": "System",
				"text": "Use either lines, sections, or composition arrays. actions and triggers are both supported.",
			},
		],
	}


func _apply_theme() -> void:
	clip_contents = true
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 0.0
	background.anchor_bottom = 0.0
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = 0.0
	background.offset_bottom = 0.0
	background.position = Vector2.ZERO
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_theme(chapter_label, 12, Color(0.96, 0.92, 0.78, 1.0), Color.BLACK, 2)
	_apply_label_theme(debt_remaining_label, 11, Color(0.96, 0.92, 0.78, 1.0), Color.BLACK, 2)
	_apply_label_theme(debt_due_label, 10, Color(0.88, 0.84, 0.74, 1.0), Color.BLACK, 1)
	_apply_label_theme(speaker_label, 16, Color(0.96, 0.84, 0.56, 1.0), Color.BLACK, 2)
	_apply_label_theme(body_label, 13, Color(0.98, 0.96, 0.90, 1.0), Color.BLACK, 2)
	_apply_label_theme(continue_label, 10, Color(0.88, 0.84, 0.74, 1.0), Color.BLACK, 1)
	left_portrait_frame.visible = false
	right_portrait_frame.visible = false
	dialogue_panel.visible = false
	debt_overlay.visible = false
	debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	speaker_label.visible = false
	body_label.text = ""
	continue_label.visible = false
	choice_container.visible = false

	debt_overlay.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.10, 0.09, 0.86), DIALOGUE_PANEL_BORDER, 10))
	dialogue_panel.add_theme_stylebox_override("panel", _make_panel_style(DIALOGUE_PANEL_COLOR, DIALOGUE_PANEL_BORDER, 10))
	left_portrait_frame.add_theme_stylebox_override("panel", _make_panel_style(PORTRAIT_PANEL_COLOR, PORTRAIT_PANEL_BORDER, 10))
	right_portrait_frame.add_theme_stylebox_override("panel", _make_panel_style(PORTRAIT_PANEL_COLOR, PORTRAIT_PANEL_BORDER, 10))
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	background_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	bgm_player.autoplay = false
	bgm_player.bus = &"Master"
	sfx_player.autoplay = false
	sfx_player.bus = &"Master"
	AudioSettingsManager.register_player(bgm_player, "music")
	AudioSettingsManager.register_player(sfx_player, "sfx")


func _apply_label_theme(label: Label, font_size: int, font_color: Color, outline_color: Color, outline_size: int) -> void:
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)


func _apply_choice_button_theme(button: Button) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.16, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.16, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.56, 0.50, 0.9))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_stylebox_override("normal", _make_panel_style(CHOICE_BUTTON_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("hover", _make_panel_style(CHOICE_BUTTON_HOVER_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("pressed", _make_panel_style(CHOICE_BUTTON_PRESSED_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("focus", _make_panel_style(CHOICE_BUTTON_HOVER_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.18, 0.13, 0.10, 0.9), Color(0.10, 0.08, 0.06, 0.9), 7))


func _make_panel_style(bg_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _play_intro_fade() -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, INTRO_FADE_SECONDS)
	await tween.finished


func _play_outro_fade() -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, OUTRO_FADE_SECONDS)
	await tween.finished


func _run_story_action(action_data: Dictionary) -> void:
	var action_type := str(action_data.get("type", action_data.get("action", ""))).to_lower()
	match action_type:
		"pause", "wait":
			await _pause_for_seconds(float(action_data.get("duration", action_data.get("time", 0.0))))
		"fade_to_black", "screen_fade_out":
			await _fade_background_overlay(1.0, float(action_data.get("duration", DEFAULT_SCREEN_FADE_SECONDS)))
		"fade_from_black", "screen_fade_in":
			await _fade_background_overlay(0.0, float(action_data.get("duration", DEFAULT_SCREEN_FADE_SECONDS)))
		"fade_screen":
			await _fade_background_overlay(
				clampf(float(action_data.get("alpha", action_data.get("target_alpha", background_fade_overlay.color.a))), 0.0, 1.0),
				float(action_data.get("duration", DEFAULT_SCREEN_FADE_SECONDS))
			)
		"play_music", "music_play":
			await _play_music_action(action_data)
		"stop_music", "music_stop":
			await _stop_music_action(action_data)
		"unlock_achievement", "achievement_unlock":
			PlayerState.unlock_achievement(str(action_data.get("id", action_data.get("achievement_id", ""))))
		"set_event_value", "story_event", "event_value":
			_apply_set_event_value_action(action_data)
		"set_event_values", "story_events", "event_values":
			_apply_set_event_values_action(action_data)
		"clear_event_value", "erase_event_value":
			PlayerState.clear_event_value(str(action_data.get("id", action_data.get("event_id", action_data.get("key", "")))))
		"clear_event_values", "erase_event_values":
			PlayerState.clear_event_values()
		"add_money", "gain_money":
			PlayerState.add_money(int(action_data.get("amount", 0)))
		"add_karma", "change_karma":
			PlayerState.add_karma(int(action_data.get("amount", 0)))
		"add_character_progress", "increase_character_progress", "character_progress":
			_apply_character_progress_action(action_data)
		"play_sfx", "sfx_play", "cue_phone_sound", "phone_sound":
			_play_sfx_action(action_data)
		"stop_sfx", "sfx_stop":
			sfx_player.stop()
		"set_portrait", "change_portrait":
			_apply_portrait_action(action_data)
		"clear_portrait":
			_clear_portrait_action(action_data)
		"portrait_switch", "focus_portrait":
			_apply_portrait_focus_from_side(str(action_data.get("side", action_data.get("focus", "none"))))
		"set_dialogue", "dialogue":
			_set_dialogue_content(
				str(action_data.get("speaker", speaker_label.text)),
				str(action_data.get("text", body_label.text)),
				str(action_data.get("continue_hint", continue_label.text if not continue_label.text.is_empty() else DEFAULT_CONTINUE_HINT)),
				bool(action_data.get("visible", true))
			)
		"background_camera", "bg_camera", "camera":
			_apply_background_camera_action(action_data)
		"zoom_background", "bg_zoom":
			_apply_background_camera_action({
				"zoom": action_data.get("zoom", action_data.get("value", action_data.get("amount", background_zoom))),
				"duration": action_data.get("duration", DEFAULT_BG_CAMERA_DURATION),
			})
		"pan_background", "bg_pan":
			_apply_background_camera_action({
				"pan": action_data.get("pan", action_data.get("value", action_data.get("offset", action_data.get("focus", null)))),
				"duration": action_data.get("duration", DEFAULT_BG_CAMERA_DURATION),
			})
		"reset_background_camera", "bg_reset":
			_set_background_camera(1.0, Vector2.ZERO, float(action_data.get("duration", DEFAULT_BG_CAMERA_DURATION)))
		"hide_dialogue":
			dialogue_panel.visible = false
		"show_dialogue":
			dialogue_panel.visible = true
		"set_background":
			current_background_ref = action_data.get("texture", action_data.get("background", action_data.get("path", null)))
			_set_background_texture(current_background_ref, not bool(action_data.get("preserve_camera", false)))
			if _has_background_camera_data(action_data):
				_apply_background_camera_action(action_data)


func _play_music_action(action_data: Dictionary) -> void:
	var stream_ref = action_data.get("stream", action_data.get("path", action_data.get("music", null)))
	var stream := _resolve_audio_stream(stream_ref)
	if stream == null:
		return

	var loop_enabled := bool(action_data.get("loop", action_data.get("loops", true)))
	var fade_in_duration := float(action_data.get("fade_in", action_data.get("fade", DEFAULT_MUSIC_FADE_SECONDS)))
	var fade_out_duration := float(action_data.get("fade_out", action_data.get("out_fade", fade_in_duration)))
	var target_volume_db := float(action_data.get("volume_db", 0.0))
	var effective_target_volume_db := AudioSettingsManager.resolve_effective_volume_db("music", target_volume_db)
	var restart := bool(action_data.get("restart", true))
	var configured_stream = _configure_audio_stream_loop(stream, loop_enabled)
	var current_music_ref := str(bgm_player.get_meta("music_ref", ""))
	var next_music_ref := _music_ref_key(stream_ref, configured_stream)
	var current_loop_enabled := bool(bgm_player.get_meta("loop_enabled", true))
	var should_swap_stream := current_music_ref != next_music_ref or current_loop_enabled != loop_enabled or bgm_player.stream == null
	var should_restart := restart or should_swap_stream or not bgm_player.playing

	if bgm_player.playing and should_swap_stream and fade_out_duration > 0.0:
		await _fade_audio_player_volume(bgm_player, fade_out_duration, bgm_player.volume_db, AudioSettingsManager.SILENCE_DB)
		bgm_player.stop()

	bgm_player.stream = configured_stream
	bgm_player.set_meta("music_ref", next_music_ref)
	bgm_player.set_meta("loop_enabled", loop_enabled)
	AudioSettingsManager.set_player_base_db(bgm_player, target_volume_db)
	if should_restart:
		bgm_player.volume_db = AudioSettingsManager.SILENCE_DB if fade_in_duration > 0.0 else effective_target_volume_db
		bgm_player.play()
	if fade_in_duration > 0.0:
		await _fade_audio_player_volume(bgm_player, fade_in_duration, bgm_player.volume_db, effective_target_volume_db)
	else:
		AudioSettingsManager.apply_player_volume(bgm_player)


func _stop_music_action(action_data: Dictionary) -> void:
	if not bgm_player.playing:
		return

	var fade_out_duration := float(action_data.get("fade_out", action_data.get("fade", DEFAULT_MUSIC_FADE_SECONDS)))
	if fade_out_duration > 0.0:
		await _fade_audio_player_volume(bgm_player, fade_out_duration, bgm_player.volume_db, AudioSettingsManager.SILENCE_DB)
	bgm_player.stop()


func _play_sfx_action(action_data: Dictionary) -> void:
	var stream_ref = action_data.get("stream", action_data.get("path", action_data.get("sfx", null)))
	var stream := _resolve_audio_stream(stream_ref)
	if stream != null:
		sfx_player.stream = stream
		AudioSettingsManager.set_player_base_db(sfx_player, float(action_data.get("volume_db", 0.0)))
		sfx_player.play()
		return

	if bool(action_data.get("fallback_beep", true)):
		DisplayServer.beep()


func _apply_character_progress_action(action_data: Dictionary) -> void:
	var character_id := str(action_data.get("character_id", action_data.get("id", PlayerState.get_current_mock_character_id())))
	var amount := int(action_data.get("amount", action_data.get("value", 1)))
	PlayerState.increment_unique_character_progress(character_id, amount)


func _apply_set_event_value_action(action_data: Dictionary) -> void:
	var event_id := str(action_data.get("id", action_data.get("event_id", action_data.get("key", ""))))
	if event_id.is_empty():
		return
	PlayerState.set_event_values(
		StoryEventHandler.build_single_event_values(
			event_id,
			action_data.get("value", action_data.get("amount", 1))
		)
	)


func _apply_set_event_values_action(action_data: Dictionary) -> void:
	var values := action_data.get("values", action_data.get("events", {}))
	if not values is Dictionary:
		return
	PlayerState.set_event_values((values as Dictionary).duplicate(true))


func _configure_audio_stream_loop(stream: AudioStream, loop_enabled: bool) -> AudioStream:
	if stream == null:
		return null

	var configured_stream := stream.duplicate(true)
	if configured_stream == null:
		configured_stream = stream

	if configured_stream != null:
		var property_names: Dictionary = {}
		for property_info in configured_stream.get_property_list():
			property_names[str(property_info.get("name", ""))] = true
		for property_name in ["loop", "loop_enabled"]:
			if property_names.has(property_name):
				configured_stream.set(property_name, loop_enabled)
				break

	return configured_stream


func _music_ref_key(stream_ref, stream: AudioStream) -> String:
	if stream_ref is String:
		return str(stream_ref)
	if stream != null and not str(stream.resource_path).is_empty():
		return str(stream.resource_path)
	return str(stream_ref)


func _fade_audio_player_volume(player: AudioStreamPlayer, duration: float, from_db: float, to_db: float) -> void:
	if player == null:
		return
	if bgm_fade_tween:
		bgm_fade_tween.kill()
	player.volume_db = from_db
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(player, "volume_db", to_db, duration)
	await bgm_fade_tween.finished
	bgm_fade_tween = null


func _show_debt_overlay(overlay_data) -> void:
	var config: Dictionary = {}
	if overlay_data is Dictionary:
		config = (overlay_data as Dictionary).duplicate(true)
	var display_day := int(config.get("day", PlayerState.get_current_day()))
	debt_remaining_label.text = str(config.get(
		"remaining_text",
		"Debt Remaining: PhP %d" % PlayerState.get_total_debt_goal()
	))
	debt_due_label.text = str(config.get(
		"due_text",
		PlayerState.get_debt_due_text(display_day)
	))
	var fade_duration := float(config.get("fade_in", config.get("duration", 0.24)))
	if debt_overlay_tween:
		debt_overlay_tween.kill()
	debt_overlay.visible = true
	debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if fade_duration <= 0.0:
		debt_overlay.modulate = Color.WHITE
		return
	debt_overlay_tween = create_tween()
	debt_overlay_tween.tween_property(debt_overlay, "modulate:a", 1.0, fade_duration)
	await debt_overlay_tween.finished
	debt_overlay_tween = null


func _hide_debt_overlay(overlay_data) -> void:
	var fade_duration := 0.2
	if overlay_data is Dictionary:
		fade_duration = float((overlay_data as Dictionary).get("fade_out", (overlay_data as Dictionary).get("duration", fade_duration)))
	elif overlay_data != null:
		fade_duration = float(overlay_data)
	if not debt_overlay.visible:
		return
	if debt_overlay_tween:
		debt_overlay_tween.kill()
	if fade_duration <= 0.0:
		debt_overlay.visible = false
		debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return
	debt_overlay_tween = create_tween()
	debt_overlay_tween.tween_property(debt_overlay, "modulate:a", 0.0, fade_duration)
	await debt_overlay_tween.finished
	debt_overlay.visible = false
	debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	debt_overlay_tween = null


func _apply_portrait_action(action_data: Dictionary) -> void:
	var side := str(action_data.get("side", "left")).to_lower()
	var texture_ref = action_data.get("texture", action_data.get("portrait", action_data.get("path", null)))
	match side:
		"right":
			current_right_portrait_ref = texture_ref
		_:
			current_left_portrait_ref = texture_ref
	_refresh_portrait_state()


func _clear_portrait_action(action_data: Dictionary) -> void:
	var side := str(action_data.get("side", "left")).to_lower()
	match side:
		"right":
			current_right_portrait_ref = null
		_:
			current_left_portrait_ref = null
	_refresh_portrait_state()


func _refresh_portrait_state() -> void:
	_set_portrait(left_portrait_frame, left_portrait, current_left_portrait_ref)
	_set_portrait(right_portrait_frame, right_portrait, current_right_portrait_ref)
	_apply_portrait_focus_from_side(current_focus_side)


func _set_dialogue_content(speaker: String, body_text: String, continue_text: String, is_visible: bool) -> void:
	dialogue_panel.visible = is_visible
	speaker_label.visible = not speaker.is_empty()
	speaker_label.text = speaker.to_upper()
	body_label.text = body_text
	continue_label.text = continue_text if not continue_text.is_empty() else DEFAULT_CONTINUE_HINT


func _apply_line_background_camera(line: Dictionary) -> void:
	if not _has_background_camera_data(line):
		return
	_apply_background_camera_action(line)


func _transition_background_with_fade(next_background_ref, background_changed: bool, line: Dictionary, duration: float) -> void:
	var fade_duration := maxf(0.0, duration)
	if fade_duration <= 0.0:
		current_background_ref = next_background_ref
		_set_background_texture(current_background_ref, background_changed)
		_apply_line_background_camera(line)
		return

	var half_duration := fade_duration * 0.5
	await _fade_background_overlay(1.0, half_duration)
	current_background_ref = next_background_ref
	_set_background_texture(current_background_ref, background_changed)
	_apply_line_background_camera(line)
	await _fade_background_overlay(0.0, half_duration)


func _has_background_camera_data(data: Dictionary) -> bool:
	return data.has("camera") or data.has("zoom") or data.has("bg_zoom") or data.has("pan") or data.has("bg_pan") or data.has("focus")


func _apply_background_camera_action(action_data: Dictionary) -> void:
	var camera_data: Variant = action_data.get("camera", action_data)
	var zoom := background_zoom
	var pan := background_pan
	var duration := float(action_data.get("duration", DEFAULT_BG_CAMERA_DURATION))

	if camera_data is Dictionary:
		var camera_dict := camera_data as Dictionary
		if camera_dict.has("zoom"):
			zoom = maxf(MIN_BG_ZOOM, float(camera_dict.get("zoom", background_zoom)))
		elif camera_dict.has("bg_zoom"):
			zoom = maxf(MIN_BG_ZOOM, float(camera_dict.get("bg_zoom", background_zoom)))

		if camera_dict.has("pan"):
			pan = _parse_background_pan(camera_dict.get("pan", background_pan))
		elif camera_dict.has("bg_pan"):
			pan = _parse_background_pan(camera_dict.get("bg_pan", background_pan))
		elif camera_dict.has("focus"):
			pan = _parse_background_pan(camera_dict.get("focus", background_pan))

		if camera_dict.has("duration"):
			duration = float(camera_dict.get("duration", duration))
	else:
		pan = _parse_background_pan(camera_data)

	_set_background_camera(zoom, pan, duration)


func _set_background_camera(zoom: float, pan: Vector2, duration := DEFAULT_BG_CAMERA_DURATION) -> void:
	background_zoom = maxf(MIN_BG_ZOOM, zoom)
	background_pan = Vector2(
		clampf(pan.x, -1.0, 1.0),
		clampf(pan.y, -1.0, 1.0)
	)
	_refresh_background_transform(duration)


func _parse_background_pan(pan_data) -> Vector2:
	if pan_data is Vector2:
		return pan_data as Vector2
	if pan_data is Array:
		var pan_array := pan_data as Array
		if pan_array.size() >= 2:
			return Vector2(float(pan_array[0]), float(pan_array[1]))
	if pan_data is Dictionary:
		var pan_dict := pan_data as Dictionary
		return Vector2(
			float(pan_dict.get("x", 0.0)),
			float(pan_dict.get("y", 0.0))
		)

	var pan_preset := str(pan_data).to_lower().strip_edges()
	match pan_preset:
		"left":
			return Vector2(-1.0, 0.0)
		"right":
			return Vector2(1.0, 0.0)
		"top", "up":
			return Vector2(0.0, -1.0)
		"bottom", "down":
			return Vector2(0.0, 1.0)
		"top_left", "left_top":
			return Vector2(-1.0, -1.0)
		"top_right", "right_top":
			return Vector2(1.0, -1.0)
		"bottom_left", "left_bottom":
			return Vector2(-1.0, 1.0)
		"bottom_right", "right_bottom":
			return Vector2(1.0, 1.0)
		"center", "middle", "":
			return Vector2.ZERO
	return background_pan


func _refresh_background_transform(duration := 0.0) -> void:
	if background == null or not is_instance_valid(background):
		return

	if background_motion_tween != null:
		background_motion_tween.kill()
		background_motion_tween = null

	if background.texture == null:
		background.visible = false
		return

	background.visible = true
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size

	var texture_size := background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		background.position = Vector2.ZERO
		background.size = viewport_size
		return

	var fit_scale := minf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	var target_size := texture_size * fit_scale * DEFAULT_BG_FIT_SCALE * background_zoom
	var should_use_centered_fit := target_size.x <= viewport_size.x and target_size.y <= viewport_size.y

	if should_use_centered_fit:
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if duration <= 0.0:
			background.position = Vector2.ZERO
			background.size = viewport_size
			return

		background_motion_tween = create_tween()
		background_motion_tween.set_parallel(true)
		background_motion_tween.tween_property(background, "position", Vector2.ZERO, duration)
		background_motion_tween.tween_property(background, "size", viewport_size, duration)
		return

	background.stretch_mode = TextureRect.STRETCH_SCALE
	var target_position := Vector2.ZERO
	var x_space := viewport_size.x - target_size.x
	var y_space := viewport_size.y - target_size.y

	if target_size.x <= viewport_size.x:
		target_position.x = x_space * 0.5
	else:
		target_position.x = -(target_size.x - viewport_size.x) * ((background_pan.x + 1.0) * 0.5)

	if target_size.y <= viewport_size.y:
		target_position.y = y_space * 0.5
	else:
		target_position.y = -(target_size.y - viewport_size.y) * ((background_pan.y + 1.0) * 0.5)

	if duration <= 0.0:
		background.position = target_position
		background.size = target_size
		return

	background_motion_tween = create_tween()
	background_motion_tween.set_parallel(true)
	background_motion_tween.tween_property(background, "position", target_position, duration)
	background_motion_tween.tween_property(background, "size", target_size, duration)


func _pause_for_seconds(duration: float) -> void:
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout


func _fade_background_overlay(target_alpha: float, duration: float) -> void:
	if duration <= 0.0:
		background_fade_overlay.color.a = target_alpha
		return

	var tween := create_tween()
	tween.tween_property(background_fade_overlay, "color:a", target_alpha, duration)
	await tween.finished


func _fade_screen_overlay(target_alpha: float, duration: float) -> void:
	if duration <= 0.0:
		fade_overlay.color.a = target_alpha
		return

	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", target_alpha, duration)
	await tween.finished
