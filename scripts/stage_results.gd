extends Control

const STORE_SCENE := "res://scenes/store.tscn"
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const LAST_ENERGY_WARNING := "Start the next day with critically low energy?\nYour vehicle will handle worse until John recovers."

@onready var results_label: Label = $ResultsLabel
@onready var status_label: Label = $StatusLabel
@onready var rest_button: BaseButton = $BreakButtons/RestButton
@onready var store_button: BaseButton = $BreakButtons/StoreButton
@onready var ride_button: BaseButton = $BreakButtons/RideButton

var ride_confirm_dialog: ConfirmationDialog
var stats_row_refs: Dictionary = {}
var earnings_summary_label: Label
var carried_music_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/stage_results.tscn")
	_start_carried_result_music()
	_create_earnings_summary_label()
	_create_stats_row()
	ButtonGlow.attach(self, rest_button)
	ButtonGlow.attach(self, store_button)
	ButtonGlow.attach(self, ride_button)
	rest_button.pressed.connect(_rest_then_next_stage)
	store_button.pressed.connect(_open_store)
	ride_button.pressed.connect(_attempt_next_stage)
	_create_dialogs()

	var result := PlayerState.get_last_stage_result()
	PlayerState.claim_last_stage_total()
	_render_results(result)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_accept"):
		if rest_button.visible and rest_button.has_focus():
			_rest_then_next_stage()
		elif store_button.has_focus():
			_open_store()
		else:
			_attempt_next_stage()


func _render_results(result: Dictionary) -> void:
	var stage_name := str(result.get("stage_type", "stage")).to_upper()
	var day_number := int(result.get("day", PlayerState.get_current_day()))
	var time_of_day := str(result.get("time_of_day", "morning"))
	var distance := int(result.get("distance", 0))
	var fare := int(result.get("fare", 0))
	var bonus := int(result.get("bonus", 0))
	var total := int(result.get("total", 0))
	var is_night_stage := time_of_day == "night"

	results_label.text = "Day %d  %s\nComplete\n\nDistance: %dm\nFare: PhP %d\nBonus: PhP %d\nTotal: PhP %d" % [
		day_number,
		stage_name,
		distance,
		fare,
		bonus,
		total,
	]
	_render_earnings_summary(total)

	var allow_rest := is_night_stage or PlayerState.can_rest_after_stage()
	rest_button.visible = allow_rest
	store_button.visible = not is_night_stage
	ride_button.visible = not is_night_stage
	if allow_rest:
		rest_button.grab_focus()
	elif store_button.visible:
		store_button.grab_focus()
	else:
		ride_button.grab_focus()

	var rest_note := ""
	if is_night_stage:
		rest_note = "Rest: sleep, recover +3 energy, then choose a morning trip."
	elif allow_rest:
		if time_of_day == "morning":
			rest_note = "Rest: recover +2 energy, then return home for night."
		elif time_of_day == "noon":
			rest_note = "Rest: sleep, recover +5 energy, then choose a morning trip."
	elif time_of_day == "morning" or time_of_day == "noon":
		rest_note = "Rest already used for Day %d." % PlayerState.get_current_day()

	_refresh_status(rest_note)


func _rest_then_next_stage() -> void:
	var current_time := PlayerState.get_current_time_of_day()
	if current_time == "night":
		PlayerState.apply_night_rest_bonus()
		_begin_sleep_transition(PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY)
		return

	if not PlayerState.can_rest_after_stage():
		return

	if current_time == "noon":
		PlayerState.apply_transition_energy_bonus(PlayerState.TRANSITION_REST_TO_NEXT_DAY)
		_begin_sleep_transition(PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY)
		return

	PlayerState.apply_transition_energy_bonus(PlayerState.TRANSITION_REST_TO_NIGHT)
	PlayerState.set_current_stage_time("night")
	_begin_sleep_transition(PlayerState.TRANSITION_REST_TO_NIGHT)


func _next_stage() -> void:
	_begin_trip_selection(PlayerState.TRANSITION_RIDE)


func _begin_trip_selection(transition_mode: String) -> void:
	PlayerState.set_pending_trip_selection(STAGE_RESULTS_SCENE, transition_mode)
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _begin_sleep_transition(transition_mode: String) -> void:
	PlayerState.set_pending_trip_selection(STAGE_RESULTS_SCENE, transition_mode, false)
	get_tree().change_scene_to_file(SLEEP_TRANSITION_SCENE)


func _open_store() -> void:
	if not PlayerState.has_locked_pending_trip_selection():
		PlayerState.clear_pending_trip_selection()
	get_tree().change_scene_to_file(STORE_SCENE)


func _refresh_status(note := "") -> void:
	_refresh_stats_row()
	status_label.text = PlayerState.get_debt_status_text()
	if not note.is_empty():
		status_label.text += "\n%s" % note


func _render_earnings_summary(total: int) -> void:
	if earnings_summary_label == null:
		return

	var weekly_goal := PlayerState.get_current_weekly_goal()
	if weekly_goal <= 0:
		earnings_summary_label.text = "You just earned PhP %d.\nWeekly goal already paid." % total
		return

	var goal_percent := float(total) / float(weekly_goal) * 100.0
	earnings_summary_label.text = "You just earned PhP %d.\nThat's %.1f%% of your weekly goal." % [
		total,
		goal_percent,
	]


func _attempt_next_stage() -> void:
	if PlayerState.get_current_time_of_day() == "night" and PlayerState.energy <= 2:
		ride_confirm_dialog.popup_centered()
		return

	_next_stage()


func _create_dialogs() -> void:
	ride_confirm_dialog = ConfirmationDialog.new()
	ride_confirm_dialog.title = "Low Energy"
	ride_confirm_dialog.dialog_text = LAST_ENERGY_WARNING
	ride_confirm_dialog.get_ok_button().text = "START DAY"
	ride_confirm_dialog.get_cancel_button().text = "BACK"
	ride_confirm_dialog.confirmed.connect(_next_stage)
	add_child(ride_confirm_dialog)


func _create_earnings_summary_label() -> void:
	earnings_summary_label = Label.new()
	earnings_summary_label.set_anchors_preset(Control.PRESET_CENTER)
	earnings_summary_label.offset_left = -430.0
	earnings_summary_label.offset_top = -46.0
	earnings_summary_label.offset_right = 430.0
	earnings_summary_label.offset_bottom = 18.0
	earnings_summary_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	earnings_summary_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	earnings_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	earnings_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	earnings_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	earnings_summary_label.add_theme_font_override("font", UI_FONT)
	earnings_summary_label.add_theme_font_size_override("font_size", 13)
	earnings_summary_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08, 1.0))
	earnings_summary_label.add_theme_color_override("font_outline_color", Color(0.95, 0.90, 0.78, 0.92))
	earnings_summary_label.add_theme_constant_override("outline_size", 1)
	add_child(earnings_summary_label)


func _create_stats_row() -> void:
	stats_row_refs = PlayerStatsRow.create({
		"font": UI_FONT,
		"font_size": 11,
		"font_color": Color(0.27, 0.18, 0.10, 1.0),
		"outline_color": Color(0.95, 0.90, 0.78, 0.92),
	})
	var stats_row := stats_row_refs["row"] as HBoxContainer
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.position = Vector2(330.0, 410.0)
	stats_row.size = Vector2(620.0, 24.0)
	add_child(stats_row)


func _refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return

	PlayerStatsRow.refresh(stats_row_refs)


func _start_carried_result_music() -> void:
	var music_state := PlayerState.consume_pending_result_music()
	if music_state.is_empty():
		return

	_play_carried_music(music_state, "stage", "StageResultsBGMPlayer")
	_play_carried_music(music_state, "rain", "StageResultsRainLoopPlayer")


func _play_carried_music(music_state: Dictionary, prefix: String, player_name: String) -> void:
	var path := str(music_state.get("%s_path" % prefix, "")).strip_edges()
	if path.is_empty():
		return

	var stream = _load_looping_audio_stream(path)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = "Master"
	player.stream = stream
	add_child(player)
	AudioSettingsManager.register_player(player, "music", float(music_state.get("%s_base_db" % prefix, 0.0)))
	player.play(maxf(0.0, float(music_state.get("%s_position" % prefix, 0.0))))
	carried_music_players.append(player)


func _load_looping_audio_stream(path: String):
	var stream = load(path)
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		stream.loop = true
	return stream
