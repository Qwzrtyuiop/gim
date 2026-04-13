extends Control

const STORE_SCENE := "res://scenes/store.tscn"
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const GAS_ICON := preload("res://assets/ui/icons/gas_pump.svg")
const BUTTON_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_GLOW_MODULATE := Color(1.35, 1.18, 0.62, 1.0)
const LAST_ENERGY_WARNING := "Start the next day with your last energy?\nIf this trip goes bad, the run ends."

@onready var results_label: Label = $ResultsLabel
@onready var status_label: Label = $StatusLabel
@onready var rest_button: BaseButton = $BreakButtons/RestButton
@onready var store_button: BaseButton = $BreakButtons/StoreButton
@onready var ride_button: BaseButton = $BreakButtons/RideButton

var ride_confirm_dialog: ConfirmationDialog
var stats_row: HBoxContainer
var money_value_label: Label
var energy_value_label: Label
var gas_value_label: Label


func _ready() -> void:
	_create_stats_row()
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
	var is_night_stage := time_of_day == "night"

	results_label.text = "Day %d  %s\nComplete\n\nDistance: %dm\nFare: PhP %d\nBonus: PhP %d\nTotal: PhP %d" % [
		day_number,
		stage_name,
		distance,
		fare,
		bonus,
		total,
	]

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
		rest_note = "Rest: sleep, recover +1 energy, then choose a morning trip."
	elif allow_rest:
		if time_of_day == "morning":
			rest_note = "Rest: skip to night and recover +1 energy."
		elif time_of_day == "noon":
			rest_note = "Rest: skip to next day and recover +3 energy."
	elif time_of_day == "morning" or time_of_day == "noon":
		rest_note = "Rest already used for Day %d." % PlayerState.get_current_day()

	_refresh_status(rest_note)


func _rest_then_next_stage() -> void:
	if PlayerState.get_current_time_of_day() == "night":
		PlayerState.apply_night_rest_bonus()
		PlayerState.set_pending_trip_selection(STAGE_RESULTS_SCENE, PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY, false)
		get_tree().change_scene_to_file(SLEEP_TRANSITION_SCENE)
		return

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
	if not PlayerState.has_locked_pending_trip_selection():
		PlayerState.clear_pending_trip_selection()
	get_tree().change_scene_to_file(STORE_SCENE)


func _refresh_status(note := "") -> void:
	_refresh_stats_row()
	status_label.text = PlayerState.get_debt_status_text()
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


func _create_stats_row() -> void:
	stats_row = HBoxContainer.new()
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 12)
	stats_row.position = Vector2(330.0, 410.0)
	stats_row.size = Vector2(620.0, 24.0)
	add_child(stats_row)

	money_value_label = _make_stat_label()
	energy_value_label = _make_stat_label()
	gas_value_label = _make_stat_label()

	stats_row.add_child(money_value_label)
	stats_row.add_child(_make_stat_icon(ENERGY_ICON))
	stats_row.add_child(energy_value_label)
	stats_row.add_child(_make_stat_icon(GAS_ICON))
	stats_row.add_child(gas_value_label)


func _refresh_stats_row() -> void:
	if not stats_row:
		return

	money_value_label.text = "Money: PhP %d" % PlayerState.money
	energy_value_label.text = "%d/%d" % [PlayerState.energy, PlayerState.max_energy]
	gas_value_label.text = "%d/%d" % [PlayerState.gas, PlayerState.max_gas]


func _make_stat_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.27, 0.18, 0.10, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.95, 0.90, 0.78, 0.92))
	label.add_theme_constant_override("outline_size", 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_stat_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon
