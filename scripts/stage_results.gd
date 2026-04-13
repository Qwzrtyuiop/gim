extends Control

const STORE_SCENE := "res://scenes/store.tscn"
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const UI_FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const BUTTON_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_GLOW_MODULATE := Color(1.35, 1.18, 0.62, 1.0)
const LAST_ENERGY_WARNING := "Start the next day with your last energy?\nIf this trip goes bad, the run ends."

@onready var results_label: Label = $ResultsLabel
@onready var status_label: Label = $StatusLabel
@onready var rest_button: BaseButton = $BreakButtons/RestButton
@onready var store_button: BaseButton = $BreakButtons/StoreButton
@onready var ride_button: BaseButton = $BreakButtons/RideButton

var ride_confirm_dialog: ConfirmationDialog


func _ready() -> void:
	_connect_button_glow(rest_button)
	_connect_button_glow(store_button)
	_connect_button_glow(ride_button)
	rest_button.pressed.connect(_rest_then_next_stage)
	store_button.pressed.connect(_open_store)
	ride_button.pressed.connect(_attempt_next_stage)
	_create_dialogs()

	var result := PlayerState.get_last_stage_result()
	PlayerState.claim_last_stage_total()
	_render_results(result)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if rest_button.visible and rest_button.has_focus():
			_rest_then_next_stage()
		elif store_button.has_focus():
			_open_store()
		else:
			_attempt_next_stage()


func _render_results(result: Dictionary) -> void:
	var stage_name := String(result.get("stage_type", "stage")).to_upper()
	var day_number := int(result.get("day", PlayerState.get_current_day()))
	var time_of_day := String(result.get("time_of_day", "morning"))
	var distance := int(result.get("distance", 0))
	var fare := int(result.get("fare", 0))
	var bonus := int(result.get("bonus", 0))
	var total := int(result.get("total", 0))

	results_label.text = "Day %d  %s\nComplete\n\nDistance: %dm\nFare: PhP %d\nBonus: PhP %d\nTotal: PhP %d" % [
		day_number,
		stage_name,
		distance,
		fare,
		bonus,
		total,
	]

	var allow_rest := PlayerState.can_rest_after_stage()
	rest_button.visible = allow_rest
	if allow_rest:
		rest_button.grab_focus()
	else:
		ride_button.grab_focus()

	var rest_note := ""
	if allow_rest:
		if time_of_day == "morning":
			rest_note = "Rest: skip to night and recover +1 energy."
		elif time_of_day == "noon":
			rest_note = "Rest: skip to next day and recover +3 energy."
	elif time_of_day == "morning" or time_of_day == "noon":
		rest_note = "Rest already used for Day %d." % PlayerState.get_current_day()

	_refresh_status(rest_note)


func _rest_then_next_stage() -> void:
	if not PlayerState.can_rest_after_stage():
		return

	var transition_mode := PlayerState.TRANSITION_REST_TO_NIGHT
	if PlayerState.get_current_time_of_day() == "noon":
		transition_mode = PlayerState.TRANSITION_REST_TO_NEXT_DAY

	_begin_trip_selection(transition_mode)


func _next_stage() -> void:
	_begin_trip_selection(PlayerState.TRANSITION_RIDE)


func _begin_trip_selection(transition_mode: String) -> void:
	PlayerState.set_pending_trip_selection(STAGE_RESULTS_SCENE, transition_mode)
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _open_store() -> void:
	PlayerState.clear_pending_trip_selection()
	get_tree().change_scene_to_file(STORE_SCENE)


func _refresh_status(note := "") -> void:
	status_label.text = "Money: PhP %d     Energy: %d/%d\n%s" % [
		PlayerState.money,
		PlayerState.energy,
		PlayerState.max_energy,
		PlayerState.get_debt_status_text(),
	]
	if not note.is_empty():
		status_label.text += "\n%s" % note


func _attempt_next_stage() -> void:
	if PlayerState.get_current_time_of_day() == "night" and PlayerState.energy == 1:
		ride_confirm_dialog.popup_centered()
		return

	_next_stage()


func _create_dialogs() -> void:
	ride_confirm_dialog = ConfirmationDialog.new()
	ride_confirm_dialog.title = "Last Energy"
	ride_confirm_dialog.dialog_text = LAST_ENERGY_WARNING
	ride_confirm_dialog.get_ok_button().text = "START DAY"
	ride_confirm_dialog.get_cancel_button().text = "BACK"
	ride_confirm_dialog.confirmed.connect(_next_stage)
	add_child(ride_confirm_dialog)


func _connect_button_glow(button: BaseButton) -> void:
	button.modulate = BUTTON_NORMAL_MODULATE
	button.mouse_entered.connect(_set_button_glow.bind(button, true))
	button.mouse_exited.connect(_set_button_glow.bind(button, false))
	button.focus_entered.connect(_set_button_glow.bind(button, true))
	button.focus_exited.connect(_set_button_glow.bind(button, false))


func _set_button_glow(button: BaseButton, is_glowing: bool) -> void:
	var tween := create_tween()
	tween.tween_property(
		button,
		"modulate",
		BUTTON_GLOW_MODULATE if is_glowing else BUTTON_NORMAL_MODULATE,
		0.08
	)
