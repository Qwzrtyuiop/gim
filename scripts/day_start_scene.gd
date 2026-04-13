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

@onready var header_label: Label = $HeaderLabel
@onready var status_label: Label = $StatusLabel
@onready var night_filter: ColorRect = $NightFilter
@onready var rest_button: BaseButton = $BreakButtons/RestButton
@onready var store_button: BaseButton = $BreakButtons/StoreButton
@onready var ride_button: BaseButton = $BreakButtons/RideButton
@onready var fade_overlay: ColorRect = $FadeOverlay

var stats_row_refs: Dictionary = {}
var is_transitioning := false


func _ready() -> void:
	PlayerState.set_resume_scene(DAY_START_SCENE)
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	var current_time := PlayerState.get_current_time_of_day()
	if PlayerState.get_current_day() <= 1 or (current_time != "morning" and current_time != "noon" and current_time != "night"):
		PlayerState.set_pending_trip_selection(DAY_START_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
		get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)
		return

	_create_stats_row()
	ButtonGlow.attach(self, rest_button)
	ButtonGlow.attach(self, store_button)
	ButtonGlow.attach(self, ride_button)
	rest_button.pressed.connect(_rest_then_noon)
	store_button.pressed.connect(_open_store)
	ride_button.pressed.connect(_ride_now)
	_render_day_start()
	rest_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
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
	header_label.text = "DAY %d\n%s At Home" % [
		PlayerState.get_current_day(),
		current_time.capitalize(),
	]
	var rest_note := "Rest: stay home, recover +1 energy, and move to noon."
	if current_time == "noon":
		rest_note = "Rest: stay home, recover +1 energy, and move to night."
	if current_time == "night":
		rest_note = "Rest: sleep, recover +1 energy, then start the next day at home."
	status_label.text = "%s\n%s" % [
		PlayerState.get_debt_status_text(),
		rest_note,
	]


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


func _transition_home_rest(next_time: String) -> void:
	is_transitioning = true
	_set_buttons_disabled(true)
	await _fade_overlay_to(1.0, HOME_REST_FADE_SECONDS)
	PlayerState.add_energy(1)
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
