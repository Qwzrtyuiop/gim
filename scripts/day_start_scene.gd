extends Control

const DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const ImageOutline := preload("res://scripts/story/story_portrait_outline.gd")
const HouseCalendar := preload("res://scripts/ui/house_calendar.gd")
const HouseRadio := preload("res://scripts/ui/house_radio.gd")
const RIDE_BUTTON_TEXTURE := preload("res://assets/ui/buttons/hub/ride.png")
const STORE_BUTTON_TEXTURE := preload("res://assets/ui/buttons/hub/store.png")
const CALENDAR_TEXTURE := preload("res://assets/ui/frames/calendar.png")
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
			_show_info("rest")
		"ride":
			_show_info("outside")


func _create_hud() -> void:
	status_header = HubStatusHeader.new()
	add_child(status_header)
	header_label = status_header.day_label
	stats_row_refs = status_header.stats_refs


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
	calendar_background = TextureRect.new()
	calendar_background.name = "CalendarBackground"
	calendar_background.texture = CALENDAR_TEXTURE
	calendar_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	calendar_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	calendar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calendar_background.rotation_degrees = 90
	calendar_background.hide()
	info_overlay.add_child(calendar_background)
	ImageOutline.apply_to(calendar_background)
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
	info_panel_style = style
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
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)
	info_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(info_close)
	rest_confirm = Button.new()
	rest_confirm.name = "ConfirmRest"
	rest_confirm.custom_minimum_size.y = 46
	rest_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest_confirm.add_theme_font_override("font", UI_FONT)
	rest_confirm.add_theme_font_size_override("font_size", 14)
	rest_confirm.pressed.connect(_confirm_rest)
	rest_confirm.hide()
	actions.add_child(rest_confirm)
	for destination in [["Ride", RIDE_SELECTION_SCENE, RIDE_BUTTON_TEXTURE], ["Shop", STORE_SCENE, STORE_BUTTON_TEXTURE]]:
		var button := TextureButton.new()
		button.tooltip_text = destination[0]
		button.texture_normal = destination[2]
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size.y = 150
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_outside_destination.bind(destination[1]))
		button.hide()
		actions.add_child(button)
		ButtonGlow.attach(self, button)
		outside_buttons.append(button)
	calendar_content = HouseCalendar.new()
	calendar_content.hide()
	info_overlay.add_child(calendar_content)
	calendar_content.closed.connect(_close_info)
	radio_content = HouseRadio.new()
	radio_content.hide()
	info_overlay.add_child(radio_content)
	radio_content.closed.connect(_close_info)


func _layout_ui() -> void:
	if header_label == null:
		return
	status_header.layout_in(size)
	var content_origin := Vector2(0, HubStatusHeader.CONTENT_TOP)
	var content_size := size - content_origin - Vector2(0, 16)
	if info_action == "calendar":
		var aspect := float(CALENDAR_TEXTURE.get_height()) / CALENDAR_TEXTURE.get_width()
		var height := minf(content_size.y, (size.x - 48) / aspect)
		var calendar_size := Vector2(height * aspect, height)
		calendar_background.size = Vector2(calendar_size.y, calendar_size.x)
		calendar_background.position = content_origin + (content_size - calendar_size) * 0.5 + Vector2(calendar_size.x, 0)
		calendar_content.position = content_origin + (content_size - calendar_size) * 0.5
		calendar_content.scale = calendar_size / HouseCalendar.DESIGN_SIZE
	elif info_action == "radio":
		var radio_scale := minf(1.15, minf((size.x - 48) / HouseRadio.DESIGN_SIZE.x, content_size.y / HouseRadio.DESIGN_SIZE.y))
		radio_content.scale = Vector2.ONE * radio_scale
		radio_content.position = content_origin + (content_size - HouseRadio.DESIGN_SIZE * radio_scale) * 0.5
	else:
		info_panel.add_theme_stylebox_override("panel", info_panel_style)
		info_body.custom_minimum_size.x = minf(700, size.x - 48) - 48
		info_panel.size = Vector2(minf(700, size.x - 48), minf(380 if info_action == "outside" else 420, content_size.y))
	info_panel.position = content_origin + (content_size - info_panel.size) * 0.5
	if tutorial_active:
		_show_tutorial_step(tutorial_step_index)


func _render_day_start() -> void:
	var current_time := PlayerState.get_current_time_of_day()
	house.set_night(current_time == "night")
	status_header.refresh()
	var rest_note := "Rest: recover +2 energy and move to noon."
	if current_time == "noon":
		rest_note = "Rest: recover +2 energy and move to night."
	elif current_time == "night":
		rest_note = "Sleep: recover +3 energy and start the next day at home."
	house.buttons["rest"].tooltip_text = rest_note


func _show_info(action: String) -> void:
	info_action = action
	calendar_background.visible = action == "calendar"
	calendar_content.visible = action == "calendar"
	radio_content.visible = action == "radio"
	info_panel.visible = action not in ["calendar", "radio"]
	info_close.visible = action != "outside"
	for button in outside_buttons:
		button.visible = action == "outside"
	rest_confirm.visible = action == "rest"
	info_close.text = "NO" if action == "rest" else "CLOSE"
	if action == "outside":
		info_title.text = "GO OUTSIDE"
		info_body.text = "Where would you like to go?\n\nPress Esc or click outside to stay home."
	elif action == "rest":
		var phase := PlayerState.get_current_time_of_day()
		info_title.text = "SLEEP UNTIL MORNING?" if phase == "night" else "REST NOW?"
		rest_confirm.text = "YES, SLEEP" if phase == "night" else "YES, REST"
		if phase == "night":
			info_body.text = "Recover up to 3 energy and advance to Day %d, morning." % (PlayerState.get_current_day() + 1)
		else:
			info_body.text = "Recover up to 2 energy and advance to %s." % ("noon" if phase == "morning" else "night")
	elif action == "radio":
		radio_content.refresh()
	elif action == "calendar":
		calendar_content.refresh()
	house.set_enabled(false)
	info_overlay.show()
	_layout_ui()
	if action == "calendar":
		calendar_content.close_button.grab_focus()
	elif action == "radio":
		radio_content.close_button.grab_focus()
	elif action == "outside":
		outside_buttons[0].grab_focus()
	else:
		info_close.grab_focus()


func _close_info() -> void:
	info_overlay.hide()
	calendar_content.close_button.release_focus()
	radio_content.close_button.release_focus()
	info_close.release_focus()
	rest_confirm.release_focus()
	for button in outside_buttons:
		button.release_focus()
	info_action = ""
	house.set_enabled(not is_transitioning and not tutorial_active)


func _confirm_rest() -> void:
	if is_transitioning or not info_overlay.visible or info_action != "rest":
		return
	_close_info()
	_rest_then_noon()


func _ride_now() -> void:
	_leave_home(RIDE_SELECTION_SCENE)


func _choose_outside_destination(scene_path: String) -> void:
	if is_transitioning or not info_overlay.visible or info_action != "outside":
		return
	_close_info()
	_leave_home(scene_path)


func _leave_home(scene_path: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	house.set_enabled(false)
	PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.get_home_ride_transition_mode())
	get_tree().change_scene_to_file(scene_path)


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
		{"text": "Click the bottom-right exit, then choose Ride or Shop.", "targets": [house.buttons["ride"]]},
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
