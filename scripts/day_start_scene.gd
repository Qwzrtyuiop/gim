extends Control

const DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HOME_REST_FADE_SECONDS := 0.28
const CRT_LINE_SPACING := 7.0
const CRT_LINE_ALPHA := 0.16

@onready var header_label: Label = $HeaderLabel
@onready var news_panel: Panel = $NewsPanel
@onready var news_label: Label = $NewsPanel/NewsLabel
@onready var crt_lines: Control = $NewsPanel/CrtLines
@onready var status_label: Label = $StatusLabel
@onready var night_filter: ColorRect = $NightFilter
@onready var rest_button: BaseButton = $BreakButtons/RestButton
@onready var store_button: BaseButton = $BreakButtons/StoreButton
@onready var ride_button: BaseButton = $BreakButtons/RideButton
@onready var fade_overlay: ColorRect = $FadeOverlay

var stats_row_refs: Dictionary = {}
var is_transitioning := false
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_text_panel: Panel
var tutorial_text_label: Label
var tutorial_step_index := 0
var tutorial_steps: Array[Dictionary] = []
var tutorial_active := false
var tutorial_disabled_buttons: Dictionary = {}


func _ready() -> void:
	PlayerState.set_resume_scene(DAY_START_SCENE)
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	var current_time := PlayerState.get_current_time_of_day()
	var has_pending_trip_selection := not PlayerState.get_pending_trip_selection().is_empty()
	if current_time != "morning" and current_time != "noon" and current_time != "night":
		PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
		get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)
		return
	if PlayerState.get_current_day() <= 1 and not has_pending_trip_selection:
		PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
		get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)
		return

	_create_stats_row()
	PlayerState.ensure_daily_conditions_for_current_day()
	ButtonGlow.attach(self, rest_button)
	ButtonGlow.attach(self, store_button)
	ButtonGlow.attach(self, ride_button)
	rest_button.pressed.connect(_rest_then_noon)
	store_button.pressed.connect(_open_store)
	ride_button.pressed.connect(_ride_now)
	call_deferred("_build_crt_lines")
	_render_day_start()
	_build_tutorial()
	if not PlayerState.has_home_tutorial_shown():
		call_deferred("_start_tutorial")
	rest_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return
	if tutorial_active:
		if event is InputEventMouseButton and event.pressed:
			_advance_tutorial()
			return
		if _is_any_press(event):
			_advance_tutorial()
		return
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_accept"):
		if rest_button.has_focus():
			_rest_then_noon()
		elif store_button.has_focus():
			_open_store()
		else:
			_ride_now()


func _render_day_start() -> void:
	var current_time := PlayerState.get_current_time_of_day()
	_refresh_stats_row()
	night_filter.visible = current_time == "night"
	_render_daily_news()
	header_label.text = "DAY %d\n%s At Home" % [
		PlayerState.get_current_day(),
		current_time.capitalize(),
	]
	var rest_note := "Rest: stay home, recover +2 energy, and move to noon."
	if current_time == "noon":
		rest_note = "Rest: stay home, recover +2 energy, and move to night."
	if current_time == "night":
		rest_note = "Rest: sleep, recover +3 energy, then start the next day at home."
	status_label.text = "%s\n%s" % [
		PlayerState.get_debt_status_text(),
		rest_note,
	]


func _render_daily_news() -> void:
	var should_show_news: bool = PlayerState.get_current_day() >= 2
	news_panel.visible = should_show_news
	if should_show_news:
		news_label.text = PlayerState.get_daily_news_text()


func _build_crt_lines() -> void:
	if crt_lines == null:
		return
	for child in crt_lines.get_children():
		child.queue_free()

	var line_area_height: float = crt_lines.size.y
	if line_area_height <= 0.0:
		line_area_height = 150.0
	var line_count: int = ceili(line_area_height / CRT_LINE_SPACING)
	for index in range(line_count):
		var line: ColorRect = ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.color = Color(0.0, 0.0, 0.0, CRT_LINE_ALPHA)
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.offset_left = 0.0
		line.offset_right = 0.0
		line.offset_top = float(index) * CRT_LINE_SPACING
		line.offset_bottom = line.offset_top + 1.0
		crt_lines.add_child(line)


func _ride_now() -> void:
	if is_transitioning:
		return
	PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _open_store() -> void:
	if is_transitioning:
		return
	PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
	get_tree().change_scene_to_file(STORE_SCENE)


func _rest_then_noon() -> void:
	if is_transitioning:
		return
	if PlayerState.get_current_time_of_day() == "night":
		PlayerState.apply_night_rest_bonus()
		PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY, false)
		get_tree().change_scene_to_file(SLEEP_TRANSITION_SCENE)
		return

	var next_time := "noon" if PlayerState.get_current_time_of_day() == "morning" else "night"
	await _transition_home_rest(next_time)


func _create_stats_row() -> void:
	stats_row_refs = PlayerStatsRow.create({
		"font": UI_FONT,
		"font_size": 11,
		"font_color": Color(0.27, 0.18, 0.10, 1.0),
		"outline_color": Color(0.95, 0.90, 0.78, 0.92),
	})
	var stats_row := stats_row_refs["row"] as HBoxContainer
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.position = Vector2(330.0, 348.0)
	stats_row.size = Vector2(620.0, 24.0)
	add_child(stats_row)


func _refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return
	PlayerStatsRow.refresh(stats_row_refs)


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

	tutorial_steps.append({
		"text": "This is home. The header shows the current day and time of day.",
		"targets": [header_label],
	})
	if news_panel.visible:
		tutorial_steps.append({
			"text": "Today's news shows gas price changes and the weather forecast for today and tomorrow.",
			"targets": [news_panel],
		})
	var stats_row := stats_row_refs.get("row") as Control
	var stats_targets := [stats_row] if stats_row != null else [status_label]
	tutorial_steps.append({
		"text": "Money, energy, and gas are shown here. Check these before choosing what to do next.",
		"targets": stats_targets,
	})
	tutorial_steps.append({
		"text": "Debt status and rest notes appear here. Rest changes the time and restores energy.",
		"targets": [status_label],
	})
	tutorial_steps.append({
		"text": "REST recovers energy and moves time forward. At night, it sleeps until the next day.",
		"targets": [rest_button],
	})
	tutorial_steps.append({
		"text": "STORE lets you buy upgrades, energy, and gas before choosing a passenger.",
		"targets": [store_button],
	})
	tutorial_steps.append({
		"text": "RIDE opens passenger selection for the current trip.",
		"targets": [ride_button],
	})


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
	tutorial_text_label.text = "%s\n\nPress any key to continue" % str(step.get("text", ""))
	tutorial_text_label.visible = true
	_layout_tutorial_for_targets(step.get("targets", []))


func _layout_tutorial_for_targets(targets: Array) -> void:
	var rect := _union_global_rect(targets)
	var label_size := Vector2(620.0, 88.0)
	if tutorial_text_label != null:
		var text_len := tutorial_text_label.text.length()
		if text_len > 180:
			label_size.y = 170.0
		elif text_len > 120:
			label_size.y = 140.0
	if rect.size == Vector2.ZERO:
		tutorial_highlight.visible = false
		tutorial_text_panel.size = label_size
		tutorial_text_panel.global_position = Vector2(
			(get_viewport_rect().size.x - label_size.x) * 0.5,
			120.0
		)
		return

	var padding := 14.0
	rect.position -= Vector2(padding, padding)
	rect.size += Vector2(padding * 2.0, padding * 2.0)
	tutorial_highlight.visible = true
	tutorial_highlight.global_position = rect.position
	tutorial_highlight.size = rect.size

	var label_pos := rect.position + Vector2((rect.size.x - label_size.x) * 0.5, rect.size.y + 16.0)
	if label_pos.y + label_size.y > get_viewport_rect().size.y - 12.0:
		label_pos.y = rect.position.y - label_size.y - 16.0
	label_pos.y = maxf(label_pos.y, 12.0)
	label_pos.x = clampf(label_pos.x, 20.0, get_viewport_rect().size.x - label_size.x - 20.0)
	tutorial_text_panel.size = label_size
	tutorial_text_panel.global_position = label_pos


func _union_global_rect(targets: Array) -> Rect2:
	var has_rect := false
	var rect := Rect2()
	for target in targets:
		var control := target as Control
		if control == null or not control.visible:
			continue
		var target_rect := control.get_global_rect()
		if not has_rect:
			rect = target_rect
			has_rect = true
		else:
			rect = rect.merge(target_rect)
	return rect


func _set_tutorial_active(is_active: bool) -> void:
	tutorial_active = is_active
	if tutorial_overlay != null:
		tutorial_overlay.visible = is_active
		if is_active:
			tutorial_overlay.grab_focus()
	if tutorial_text_panel != null:
		tutorial_text_panel.visible = is_active
	if tutorial_text_label != null:
		tutorial_text_label.visible = is_active

	var buttons := [rest_button, store_button, ride_button]
	if is_active:
		tutorial_disabled_buttons.clear()
		for button in buttons:
			if button == null:
				continue
			tutorial_disabled_buttons[button] = button.disabled
			button.disabled = true
	else:
		for button_variant in tutorial_disabled_buttons.keys():
			var button := button_variant as BaseButton
			if button == null:
				continue
			button.disabled = bool(tutorial_disabled_buttons.get(button, false))
		tutorial_disabled_buttons.clear()


func _end_tutorial() -> void:
	_set_tutorial_active(false)


func _make_tutorial_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _transition_home_rest(next_time: String) -> void:
	is_transitioning = true
	_set_buttons_disabled(true)
	await _fade_overlay_to(1.0, HOME_REST_FADE_SECONDS)
	PlayerState.record_rest()
	PlayerState.add_energy(2)
	PlayerState.set_current_stage_time(next_time)
	_render_day_start()
	await _fade_overlay_to(0.0, HOME_REST_FADE_SECONDS)
	_set_buttons_disabled(false)
	is_transitioning = false


func _set_buttons_disabled(is_disabled: bool) -> void:
	rest_button.disabled = is_disabled
	store_button.disabled = is_disabled
	ride_button.disabled = is_disabled


func _fade_overlay_to(alpha_value: float, duration: float) -> void:
	if fade_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", alpha_value, duration)
	await tween.finished
