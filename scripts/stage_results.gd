extends Control

const NEXT_STAGE_SCENE := "res://scenes/main.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const UI_FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const BUTTON_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_GLOW_MODULATE := Color(1.35, 1.18, 0.62, 1.0)

@onready var results_label: Label = $ResultsLabel
@onready var status_label: Label = $StatusLabel
@onready var rest_button: BaseButton = $BreakButtons/RestButton
@onready var store_button: BaseButton = $BreakButtons/StoreButton
@onready var ride_button: BaseButton = $BreakButtons/RideButton


func _ready() -> void:
	_connect_button_glow(rest_button)
	_connect_button_glow(store_button)
	_connect_button_glow(ride_button)
	ride_button.grab_focus()
	rest_button.pressed.connect(_rest_then_next_stage)
	store_button.pressed.connect(_open_store)
	ride_button.pressed.connect(_next_stage)

	var result := PlayerState.get_last_stage_result()
	PlayerState.claim_last_stage_total()
	_render_results(result)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_next_stage()


func _render_results(result: Dictionary) -> void:
	var stage_name := String(result.get("stage_type", "stage")).to_upper()
	var distance := int(result.get("distance", 0))
	var fare := int(result.get("fare", 0))
	var bonus := int(result.get("bonus", 0))
	var total := int(result.get("total", 0))

	results_label.text = "%s\nComplete\n\nDistance: %dm\nFare: PhP %d\nBonus: PhP %d\nTotal: PhP %d" % [
		stage_name,
		distance,
		fare,
		bonus,
		total,
	]
	status_label.text = "Money: PhP %d     Energy: %d/%d" % [
		PlayerState.money,
		PlayerState.energy,
		PlayerState.max_energy,
	]


func _rest_then_next_stage() -> void:
	PlayerState.add_energy(1)
	_next_stage()


func _next_stage() -> void:
	PlayerState.advance_to_random_stage()
	get_tree().change_scene_to_file(NEXT_STAGE_SCENE)


func _open_store() -> void:
	get_tree().change_scene_to_file(STORE_SCENE)


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
