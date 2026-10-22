extends Control

const DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HOME_BGM_PATH := "res://assets/audio/music/story/peace.mp3"
const HOME_REST_FADE_SECONDS := 0.28

@onready var house = $House
@onready var fade_overlay: ColorRect = $FadeOverlay

var header_label: Label
var stats_row_refs: Dictionary = {}
var is_transitioning := false
var bgm_player: AudioStreamPlayer
var info_overlay: ColorRect
var info_panel: PanelContainer
var info_title: Label
var info_body: Label
var info_close: Button
var info_action := ""
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_text_panel: Panel
var tutorial_text_label: Label
var tutorial_step_index := 0
var tutorial_steps: Array[Dictionary] = []
var tutorial_active := false


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
	elif info_overlay != null and info_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_info()


func _on_house_action(action: String) -> void:
	if is_transitioning or tutorial_active or info_overlay.visible:
		return
	match action:
		"radio", "calendar":
			_show_info(action)
		"rest":
			_rest_then_noon()
		"ride":
			_ride_now()


func _create_hud() -> void:
	header_label = _label(16)
	header_label.name = "DayAndTime"
	add_child(header_label)
	stats_row_refs = PlayerStatsRow.create({
		"font": UI_FONT, "font_size": 11,
		"font_color": Color(0.98, 0.94, 0.82),
		"outline_color": Color(0.08, 0.06, 0.04),
	})
	add_child(stats_row_refs["row"])


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _create_info_overlay() -> void:
	info_overlay = ColorRect.new()
	info_overlay.name = "HouseInfoOverlay"
	info_overlay.color = Color(0, 0, 0, 0.55)
	info_overlay.z_index = 50
	info_overlay.hide()
	add_child(info_overlay)
	info_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			_close_info()
	)
	info_panel = PanelContainer.new()
	info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.085, 0.065, 0.97)
	style.border_color = Color(0.78, 0.61, 0.34)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	info_panel.add_theme_stylebox_override("panel", style)
	info_overlay.add_child(info_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	info_panel.add_child(content)
	info_title = _label(20)
	content.add_child(info_title)
	info_body = _label(14)
	info_body.custom_minimum_size.x = 600
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_body.add_theme_constant_override("line_spacing", 12)
	content.add_child(info_body)
	info_close = Button.new()
	info_close.text = "CLOSE"
	info_close.custom_minimum_size.y = 46
	info_close.add_theme_font_override("font", UI_FONT)
	info_close.add_theme_font_size_override("font_size", 14)
	info_close.pressed.connect(_close_info)
	content.add_child(info_close)


func _layout_ui() -> void:
	if header_label == null:
		return
	header_label.position = Vector2(20, 16)
	header_label.size = Vector2(size.x - 40, 32)
	var stats: Control = stats_row_refs["row"]
	stats.position = Vector2(20, 52)
	stats.size = Vector2(size.x - 40, 28)
	info_body.custom_minimum_size.x = minf(700, size.x - 48) - 48
	info_panel.size = Vector2(minf(700, size.x - 48), minf(420, size.y - 64))
	info_panel.position = (size - info_panel.size) * 0.5
	if tutorial_active:
		_show_tutorial_step(tutorial_step_index)


func _render_day_start() -> void:
	var current_time := PlayerState.get_current_time_of_day()
	house.set_night(current_time == "night")
	PlayerStatsRow.refresh(stats_row_refs)
	header_label.text = "DAY %d / %s" % [PlayerState.get_current_day(), current_time.capitalize()]
	var rest_note := "Rest: recover +2 energy and move to noon."
	if current_time == "noon":
		rest_note = "Rest: recover +2 energy and move to night."
	elif current_time == "night":
		rest_note = "Sleep: recover +3 energy and start the next day at home."
	house.buttons["rest"].tooltip_text = rest_note


func _show_info(action: String) -> void:
	info_action = action
	if action == "radio":
		info_title.text = "RADIO / DAILY NEWS"
		info_body.text = PlayerState.get_daily_news_text()
	else:
		info_title.text = "CALENDAR"
		info_body.text = "WEEKLY GOAL: PhP %d\n\nDebt remaining: PhP %d\n\n%s" % [PlayerState.get_current_weekly_goal(), PlayerState.get_total_debt_goal(), PlayerState.get_debt_due_text()]
	house.set_enabled(false)
	info_overlay.show()
	_layout_ui()
	info_close.grab_focus()


func _close_info() -> void:
	info_overlay.hide()
	info_close.release_focus()
	house.set_enabled(not is_transitioning and not tutorial_active)


func _ride_now() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	house.set_enabled(false)
	PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.get_home_ride_transition_mode())
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _rest_then_noon() -> void:
	if is_transitioning:
		return
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


func _build_tutorial() -> void:
	tutorial_steps.clear()
	tutorial_step_index = 0

	tutorial_overlay = Control.new()
	tutorial_overlay.anchor_right = 1.0
	tutorial_overlay.anchor_bottom = 1.0
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.focus_mode = Control.FOCUS_ALL
	tutorial_overlay.z_index = 200
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)

	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.add_child(backdrop)

	tutorial_highlight = Panel.new()
	tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_highlight.z_index = 1
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	highlight_style.border_color = Color(0.98, 0.92, 0.68, 0.95)
	highlight_style.set_border_width_all(3)
	highlight_style.set_corner_radius_all(8)
	tutorial_highlight.add_theme_stylebox_override("panel", highlight_style)
	tutorial_overlay.add_child(tutorial_highlight)

	tutorial_text_panel = Panel.new()
	tutorial_text_panel.z_index = 2
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.06, 0.92)
	panel_style.border_color = Color(0.82, 0.66, 0.40, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	tutorial_text_panel.add_theme_stylebox_override("panel", panel_style)
	tutorial_overlay.add_child(tutorial_text_panel)

	tutorial_text_label = _make_tutorial_label()
	tutorial_text_label.anchor_right = 1.0
	tutorial_text_label.anchor_bottom = 1.0
	tutorial_text_label.offset_left = 12.0
	tutorial_text_label.offset_top = 10.0
	tutorial_text_label.offset_right = -12.0
	tutorial_text_label.offset_bottom = -10.0
	tutorial_text_panel.add_child(tutorial_text_label)

	tutorial_steps = [
		{"text": "This is home. Hover over objects to see what you can use.", "targets": [header_label]},
		{"text": "Click the radio for today's news, gas prices and weather forecast.", "targets": [house.buttons["radio"]]},
		{"text": "Click the calendar to check your weekly goal, remaining debt and due date.", "targets": [house.buttons["calendar"]]},
		{"text": "Click the curtained sleeping area to rest. Hover over it to see the energy recovery and time change.", "targets": [house.buttons["rest"]]},
		{"text": "Click the bottom-right exit to leave the house.", "targets": [house.buttons["ride"]]},
	]


func _start_tutorial() -> void:
	if tutorial_overlay == null or tutorial_steps.is_empty():
		return
	if PlayerState.has_home_tutorial_shown():
		return
	PlayerState.mark_home_tutorial_shown()
	_set_tutorial_active(true)
	_show_tutorial_step(0)


func _advance_tutorial() -> void:
	if not tutorial_active:
		return
	var next_index := tutorial_step_index + 1
	if next_index >= tutorial_steps.size():
		_end_tutorial()
		return
	_show_tutorial_step(next_index)


func _show_tutorial_step(step_index: int) -> void:
	tutorial_step_index = clampi(step_index, 0, tutorial_steps.size() - 1)
	var step: Dictionary = tutorial_steps[tutorial_step_index]
	tutorial_text_label.text = "%s\n\nClick or press any key to continue" % str(step.get("text", ""))
	tutorial_text_label.visible = true
	_layout_tutorial_for_targets(step.get("targets", []))


func _layout_tutorial_for_targets(targets: Array) -> void:
	TutorialOverlayHelper.layout_for_targets(self, tutorial_highlight, tutorial_text_panel, tutorial_text_label, targets)


func _union_global_rect(targets: Array) -> Rect2:
	return TutorialOverlayHelper.union_global_rect(targets)


func _set_tutorial_active(is_active: bool) -> void:
	tutorial_active = is_active
	TutorialOverlayHelper.set_overlay_visible(is_active, tutorial_overlay, tutorial_text_panel, tutorial_text_label)
	house.set_enabled(not is_active)


func _end_tutorial() -> void:
	_set_tutorial_active(false)


func _make_tutorial_label() -> Label:
	return TutorialOverlayHelper.make_label(UI_FONT)


func _is_any_press(event: InputEvent) -> bool:
	return TutorialOverlayHelper.is_any_press(event)
