extends Control

# Coordinates ride-selection setup, input, and the stage transition.
# Passenger generation, presentation, and tutorial behavior live in scripts/ride_selection/.

const NEXT_STAGE_SCENE := "res://scenes/main.tscn"
const DAY_START_SCENE := "res://scenes/day_start_transition.tscn"
const HOUSE_DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const PassengerPool := preload("res://scripts/ride_selection/passenger_pool.gd")
const SelectionView := preload("res://scripts/ride_selection/selection_view.gd")
const SelectionTutorial := preload("res://scripts/ride_selection/selection_tutorial.gd")

@onready var subtitle_label: Label = $Panel/Subtitle
@onready var status_label: Label = $Panel/StatusLabel
@onready var background: TextureRect = $Background
@onready var back_button: BaseButton = $Panel/BackButton
@onready var back_label: Label = $Panel/BackButton/BackLabel
@onready var short_button: BaseButton = $Panel/ShortButton
@onready var medium_button: BaseButton = $Panel/MediumButton
@onready var long_button: BaseButton = $Panel/LongButton
@onready var card_a: Panel = $Panel/CardA
@onready var card_b: Panel = $Panel/CardB
@onready var card_c: Panel = $Panel/CardC
@onready var card_a_label: Label = $Panel/CardA/CardALabel
@onready var card_b_label: Label = $Panel/CardB/CardBLabel
@onready var card_c_label: Label = $Panel/CardC/CardCLabel
@onready var portrait_a_panel: Panel = $Panel/CardA/PortraitA
@onready var portrait_b_panel: Panel = $Panel/CardB/PortraitB
@onready var portrait_c_panel: Panel = $Panel/CardC/PortraitC

var pending_trip_selection: Dictionary = {}
var selected_distance := "short"
var locked_character_pools: Dictionary = {}
var displayed_characters: Array[Dictionary] = []
var passenger_pool: PassengerPool
var view: SelectionView
var tutorial: SelectionTutorial


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/ride_selection.tscn")
	passenger_pool = PassengerPool.new(self)
	view = SelectionView.new(self)
	tutorial = SelectionTutorial.new(self)
	pending_trip_selection = PlayerState.get_pending_trip_selection()
	selected_distance = PlayerState.get_locked_pending_trip_distance()
	if selected_distance.is_empty():
		selected_distance = "short"
	if _is_forced_first_day_ride():
		selected_distance = "short"
	back_button.visible = _allow_back()
	view.refresh_background()
	view.create_stats_row()

	back_button.pressed.connect(_handle_back_button_pressed)
	view.create_store_button()
	short_button.pressed.connect(_set_distance.bind("short"))
	medium_button.pressed.connect(_set_distance.bind("medium"))
	long_button.pressed.connect(_set_distance.bind("long"))
	card_a.gui_input.connect(_on_card_gui_input.bind(0))
	card_b.gui_input.connect(_on_card_gui_input.bind(1))
	card_c.gui_input.connect(_on_card_gui_input.bind(2))

	view.prepare_controls()

	view.create_card_special_labels()
	view.create_portrait_images()
	view.start_ride_select_bgm()

	locked_character_pools = PlayerState.get_locked_pending_trip_character_pools()
	if locked_character_pools.is_empty():
		locked_character_pools = passenger_pool.roll()
		PlayerState.lock_pending_trip_selection(locked_character_pools, selected_distance)

	view.refresh_stats_row()
	view.refresh_action_button()
	_set_distance(selected_distance)
	if _needs_refuel():
		view.store_button.grab_focus()
	else:
		match selected_distance:
			"medium":
				medium_button.grab_focus()
			"long":
				long_button.grab_focus()
			_:
				short_button.grab_focus()

	tutorial.build()
	if not PlayerState.has_ride_select_tutorial_shown():
		tutorial.call_deferred("start")


func _input(event: InputEvent) -> void:
	if tutorial != null and tutorial.active and event is InputEventMouseButton and event.pressed:
		# Handle the click before the tutorial overlay consumes GUI input.
		get_viewport().set_input_as_handled()
		tutorial.advance()


func _unhandled_input(event: InputEvent) -> void:
	if tutorial != null and tutorial.active:
		if tutorial.is_any_press(event):
			tutorial.advance()
		return
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_cancel") and _allow_back():
		_go_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and view != null:
		view.layout_card_special_labels()


func _set_distance(difficulty: String) -> void:
	selected_distance = "short" if _is_forced_first_day_ride() else difficulty
	displayed_characters = passenger_pool.for_distance(selected_distance)
	PlayerState.lock_pending_trip_selection(locked_character_pools, selected_distance)
	view.refresh_subtitle()
	view.refresh_distance_buttons()
	view.refresh_character_cards()
	if _needs_refuel():
		status_label.text = "Not enough gas. Visit the store to refuel before Day %d begins." % _display_day()
	else:
		status_label.text = "Choose a passenger for a %s trip." % difficulty.capitalize()


func _on_card_gui_input(event: InputEvent, card_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_character(card_index)


func _choose_character(card_index: int) -> void:
	if card_index < 0 or card_index >= displayed_characters.size():
		return

	var character: Dictionary = displayed_characters[card_index]
	if character.is_empty():
		status_label.text = "That slot is empty."
		return

	var transition_mode := _transition_mode()
	var stage_distance := "short" if _is_forced_first_day_ride() else selected_distance
	var stage_traffic := "chill" if _is_forced_first_day_ride() else str(character.get("stage_traffic", ""))

	if not PlayerState.prepare_stage_start_after_transition(stage_distance, transition_mode):
		var start_error := PlayerState.get_stage_start_error_after_transition(stage_distance, transition_mode)
		if start_error == "Not enough gas for this trip.":
			status_label.text = "Not enough gas for this trip. Visit the store to refuel."
		else:
			status_label.text = start_error
		return

	PlayerState.set_current_mock_character(str(character.get("id", "")))
	PlayerState.set_current_stage_special_type(str(character.get("stage_special_type", "")))
	PlayerState.set_current_special_stage_id(str(character.get("special_stage_id", "")))
	var should_show_day_start_transition := PlayerState.will_advance_day(transition_mode) and PlayerState.get_transition_display_day(transition_mode) <= 1
	PlayerState.advance_to_next_stage(
		transition_mode,
		stage_distance,
		stage_traffic
	)
	PlayerState.clear_pending_trip_selection()
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	var target_scene := DAY_START_SCENE if should_show_day_start_transition else NEXT_STAGE_SCENE
	if str(pending_trip_selection.get("return_scene", "")) == HOUSE_DAY_START_SCENE:
		target_scene = NEXT_STAGE_SCENE
	get_tree().change_scene_to_file(target_scene)


func _go_back() -> void:
	if not _allow_back():
		return

	var return_scene := str(pending_trip_selection.get("return_scene", FALLBACK_SCENE))
	get_tree().change_scene_to_file(return_scene if not return_scene.is_empty() else FALLBACK_SCENE)


func _open_store() -> void:
	get_tree().change_scene_to_file(STORE_SCENE)


func _handle_back_button_pressed() -> void:
	_go_back()


func _transition_mode() -> String:
	var transition_mode := str(pending_trip_selection.get("transition_mode", ""))
	if transition_mode.is_empty():
		if bool(pending_trip_selection.get("skip_to_night", false)):
			return PlayerState.TRANSITION_REST_TO_NIGHT
		return PlayerState.TRANSITION_RIDE
	return PlayerState.normalize_transition_mode(transition_mode)


func _is_forced_first_day_ride() -> bool:
	return (
		PlayerState.get_current_day() == 1
		and PlayerState.get_current_time_of_day() == "morning"
		and int(PlayerState.stage_round) <= 0
		and _transition_mode() == PlayerState.TRANSITION_CURRENT_STAGE
	)


func _allow_back() -> bool:
	return bool(pending_trip_selection.get("allow_back", true))


func _display_day() -> int:
	return PlayerState.get_transition_display_day(_transition_mode())


func _needs_refuel() -> bool:
	return PlayerState.gas <= 0.0
