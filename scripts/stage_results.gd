extends Control

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const DrivingAudio := preload("res://scripts/game/game_audio_manager.gd")

const STORE_SCENE := "res://scenes/store.tscn"
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const ResultsView := preload("res://scripts/results/results_view.gd")
const ResultPassenger := preload("res://scripts/results/result_passenger.gd")
const HIGH_STRESS_WARNING := "Start this trip with high stress?\nYour vehicle will handle worse until John recovers."

@onready var rest_button: BaseButton = $BreakButtons/RestButton
@onready var store_button: BaseButton = $BreakButtons/StoreButton
@onready var ride_button: BaseButton = $BreakButtons/RideButton

var ride_confirm_dialog: ConfirmationDialog
var results_view: ResultsView
var carried_music_players: Array[AudioStreamPlayer] = []
var is_transitioning := false


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/stage_results.tscn")
	_start_carried_result_music()
	results_view = ResultsView.new()
	results_view.name = "ResultsView"
	add_child(results_view)
	results_view.build($BreakButtons)
	ButtonGlow.attach(self, rest_button)
	ButtonGlow.attach(self, store_button)
	ButtonGlow.attach(self, ride_button)
	rest_button.pressed.connect(_go_home)
	store_button.pressed.connect(_open_store)
	ride_button.pressed.connect(_attempt_next_stage)
	_create_dialogs()

	var result: Dictionary = PlayerState.get_last_stage_result()
	PlayerState.claim_last_stage_total()
	_render_results(result)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_accept"):
		if rest_button.visible and rest_button.has_focus():
			_go_home()
		elif store_button.visible and store_button.has_focus():
			_open_store()
		elif ride_button.visible:
			_attempt_next_stage()


func _render_results(result: Dictionary) -> void:
	var time_of_day := str(result.get("time_of_day", "morning"))
	var skipped_phase := str(result.get("bayanihan_skipped_phase", ""))
	var is_night_stage := time_of_day == "night" or skipped_phase == "night"
	var has_pending_night_skip := time_of_day == "noon" and PlayerState.has_pending_night_phase_skip()
	var passenger := ResultPassenger.resolve(result, PlayerState.get_character_by_id(PlayerState.get_current_mock_character_id()))
	results_view.present(result, passenger)

	# This action only returns home. Recovery/time changes happen when the
	# player explicitly confirms Rest/Sleep from the house menu.
	rest_button.show()
	store_button.visible = not is_night_stage and not has_pending_night_skip
	ride_button.visible = not is_night_stage and not has_pending_night_skip
	rest_button.grab_focus()
	var rest_note := "Rest: go home. Choose Rest or Sleep there to recover and advance time."
	if has_pending_night_skip:
		rest_note = "Head home to meet Benny tonight."
	_refresh_status(rest_note)


func _go_home() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	PlayerState.set_pending_trip_selection(HOME_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
	get_tree().change_scene_to_file(HOME_SCENE)


func _next_stage() -> void:
	_begin_trip_selection(PlayerState.TRANSITION_CURRENT_STAGE)


func _begin_trip_selection(transition_mode: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	PlayerState.set_pending_trip_selection(STAGE_RESULTS_SCENE, transition_mode)
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _open_store() -> void:
	if is_transitioning or not store_button.visible:
		return
	is_transitioning = true
	if not PlayerState.has_locked_pending_trip_selection():
		PlayerState.set_pending_trip_selection(STAGE_RESULTS_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
	get_tree().change_scene_to_file(STORE_SCENE)


func _refresh_status(note := "") -> void:
	var result: Dictionary = PlayerState.get_last_stage_result()
	results_view.update_goal(int(result.get("total", 0)), bool(result.get("completed", true)))
	results_view.set_rest_note(note)
	rest_button.tooltip_text = note if not note.is_empty() else "Rest"


func _attempt_next_stage() -> void:
	if is_transitioning or not ride_button.visible:
		return
	if PlayerState.get_current_time_of_day() == "night" and PlayerState.stress >= GameTuning.STRESS_WARNING_THRESHOLD:
		ride_confirm_dialog.popup_centered()
		return

	_next_stage()


func _create_dialogs() -> void:
	ride_confirm_dialog = ConfirmationDialog.new()
	ride_confirm_dialog.title = "High Stress"
	ride_confirm_dialog.dialog_text = HIGH_STRESS_WARNING
	ride_confirm_dialog.get_ok_button().text = "START DAY"
	ride_confirm_dialog.get_cancel_button().text = "BACK"
	ride_confirm_dialog.confirmed.connect(_next_stage)
	add_child(ride_confirm_dialog)


func _start_carried_result_music() -> void:
	var music_state: Dictionary = PlayerState.consume_pending_result_music()
	AmbientAudioManager.enter_results(music_state)
	if not PlayerState.is_midnight():
		_play_carried_stage_music(music_state)


func _play_carried_stage_music(music_state: Dictionary) -> void:
	var path := str(music_state.get("stage_path", "")).strip_edges()
	if path.is_empty():
		return
	# The live clock may already be night after completing a noon trip. Suppress
	# its default playlist too, including carry data from saves made before this rule.
	if PlayerState.get_current_time_of_day() == "night" and DrivingAudio.is_default_stage_bgm_path(path):
		return

	var stream = _load_looping_audio_stream(path)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "StageResultsBGMPlayer"
	player.bus = "Master"
	player.stream = stream
	add_child(player)
	AudioSettingsManager.register_player(player, "music", float(music_state.get("stage_base_db", 0.0)))
	player.play(maxf(0.0, float(music_state.get("stage_position", 0.0))))
	carried_music_players.append(player)


func _load_looping_audio_stream(path: String):
	var stream = load(path)
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		stream.loop = true
	return stream
