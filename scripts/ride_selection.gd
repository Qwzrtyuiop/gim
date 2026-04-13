extends Control

const NEXT_STAGE_SCENE := "res://scenes/main.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const BUTTON_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_GLOW_MODULATE := Color(1.35, 1.18, 0.62, 1.0)
const EMPTY_CARD_CHANCE := 0.28
@onready var subtitle_label: Label = $Panel/Subtitle
@onready var status_label: Label = $Panel/StatusLabel
@onready var money_label: Label = $Panel/MoneyLabel
@onready var back_button: BaseButton = $Panel/BackButton
@onready var short_button: BaseButton = $Panel/ShortButton
@onready var medium_button: BaseButton = $Panel/MediumButton
@onready var long_button: BaseButton = $Panel/LongButton
@onready var card_a: Panel = $Panel/CardA
@onready var card_b: Panel = $Panel/CardB
@onready var card_c: Panel = $Panel/CardC
@onready var card_a_label: Label = $Panel/CardA/CardALabel
@onready var card_b_label: Label = $Panel/CardB/CardBLabel
@onready var card_c_label: Label = $Panel/CardC/CardCLabel

var pending_trip_selection: Dictionary = {}
var rng := RandomNumberGenerator.new()
var selected_distance := "short"
var displayed_characters: Array[Dictionary] = []


func _ready() -> void:
	rng.randomize()
	pending_trip_selection = PlayerState.get_pending_trip_selection()
	_refresh_header()
	_refresh_subtitle()

	back_button.pressed.connect(_go_back)
	short_button.pressed.connect(_set_distance.bind("short"))
	medium_button.pressed.connect(_set_distance.bind("medium"))
	long_button.pressed.connect(_set_distance.bind("long"))
	card_a.gui_input.connect(_on_card_gui_input.bind(0))
	card_b.gui_input.connect(_on_card_gui_input.bind(1))
	card_c.gui_input.connect(_on_card_gui_input.bind(2))

	for label in [card_a_label, card_b_label, card_c_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for button in [back_button, short_button, medium_button, long_button]:
		_connect_button_glow(button)

	displayed_characters = _roll_character_cards()
	short_button.grab_focus()
	_set_distance("short")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _refresh_header() -> void:
	money_label.text = "Money: PhP %d     Energy: %d/%d\n%s" % [
		PlayerState.money,
		PlayerState.energy,
		PlayerState.max_energy,
		PlayerState.get_debt_status_text(),
	]


func _refresh_subtitle() -> void:
	var transition_mode := _transition_mode()
	var energy_bonus := PlayerState.get_transition_energy_bonus(transition_mode)
	var next_time := PlayerState.get_next_stage_time(transition_mode).capitalize()
	var bonus_text := " Recovery: +%d energy." % energy_bonus if energy_bonus > 0 else ""
	subtitle_label.text = "Choose a %s route for the next %s trip.%s" % [
		selected_distance.capitalize(),
		next_time,
		bonus_text,
	]


func _set_distance(difficulty: String) -> void:
	selected_distance = difficulty
	_refresh_subtitle()
	_refresh_distance_buttons()
	_refresh_character_cards()
	status_label.text = "Choose a passenger for a %s trip." % difficulty.capitalize()


func _refresh_distance_buttons() -> void:
	for button_data in [
		{"button": short_button, "id": "short"},
		{"button": medium_button, "id": "medium"},
		{"button": long_button, "id": "long"},
	]:
		var button := button_data["button"] as BaseButton
		var button_id: String = String(button_data["id"])
		var is_selected: bool = button_id == selected_distance
		button.disabled = is_selected
		button.modulate = BUTTON_GLOW_MODULATE if is_selected else BUTTON_NORMAL_MODULATE


func _refresh_character_cards() -> void:
	var card_nodes := [
		{"panel": card_a, "label": card_a_label},
		{"panel": card_b, "label": card_b_label},
		{"panel": card_c, "label": card_c_label},
	]

	for index in range(card_nodes.size()):
		var character: Dictionary = displayed_characters[index]
		var panel := card_nodes[index]["panel"] as Panel
		var label := card_nodes[index]["label"] as Label
		if character.is_empty():
			panel.modulate = Color(0.92, 0.92, 0.92, 0.52)
			label.text = "EMPTY SLOT\nNo one available yet."
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			var is_available := _is_character_available(character)
			var preview_stage_type: String = _preview_stage_type(character)
			panel.modulate = Color.WHITE if is_available else Color(0.74, 0.74, 0.74, 0.78)
			label.text = "%s\nStage Information:\n%s\nEstimated Earnings:\nPhP %d" % [
				String(character["name"]).to_upper(),
				preview_stage_type,
				PlayerState.estimate_stage_earnings(preview_stage_type),
			]
			panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_available else Control.CURSOR_ARROW


func _roll_character_cards() -> Array[Dictionary]:
	var eligible_first_appearance: Array[Dictionary] = []
	var eligible_repeat: Array[Dictionary] = []
	for character_data in PlayerState.get_mock_characters():
		var character: Dictionary = character_data
		var is_seen := PlayerState.has_seen_mock_character(character["id"])
		if not is_seen:
			if rng.randf() <= float(character["first_appearance_chance"]):
				eligible_first_appearance.append(character)
		else:
			eligible_repeat.append(character)

	eligible_first_appearance.shuffle()
	eligible_repeat.shuffle()

	var card_results: Array[Dictionary] = []
	var used_ids: Dictionary = {}
	for _slot_index in range(3):
		if rng.randf() < EMPTY_CARD_CHANCE:
			card_results.append({})
			continue

		var picked_character: Dictionary = {}
		if not eligible_first_appearance.is_empty():
			picked_character = eligible_first_appearance.pop_front()
		else:
			while not eligible_repeat.is_empty():
				var candidate: Dictionary = eligible_repeat.pop_front()
				if not used_ids.has(candidate["id"]):
					picked_character = candidate
					break

		if picked_character.is_empty():
			card_results.append({})
			continue

		used_ids[picked_character["id"]] = true
		var was_seen_before_roll := PlayerState.has_seen_mock_character(String(picked_character["id"]))
		PlayerState.mark_mock_character_seen(String(picked_character["id"]))
		var locked_character: Dictionary = picked_character.duplicate(true)
		locked_character["stage_traffic"] = PlayerState.get_random_stage_traffic_type()
		locked_character["is_first_appearance"] = not was_seen_before_roll
		card_results.append(locked_character)

	while card_results.size() < 3:
		card_results.append({})

	return card_results


func _on_card_gui_input(event: InputEvent, card_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_character(card_index)


func _is_character_available(character: Dictionary) -> bool:
	if character.is_empty():
		return false

	if bool(character.get("is_first_appearance", false)):
		return selected_distance == String(character.get("first_distance", ""))

	var eligible_distances: Array = character.get("eligible_distances", [])
	return eligible_distances.has(selected_distance)


func _preview_distance_for_character(character: Dictionary) -> String:
	var preview_distance := selected_distance
	if bool(character.get("is_first_appearance", false)):
		preview_distance = String(character.get("first_distance", selected_distance))
	elif not _is_character_available(character):
		var eligible_distances: Array = character.get("eligible_distances", [])
		if not eligible_distances.is_empty():
			preview_distance = String(eligible_distances[0])

	return preview_distance


func _preview_stage_type(character: Dictionary) -> String:
	return PlayerState.build_stage_type(
		_preview_distance_for_character(character),
		PlayerState.get_next_stage_time(_transition_mode()),
		String(character.get("stage_traffic", "chill"))
	)


func _choose_character(card_index: int) -> void:
	if card_index < 0 or card_index >= displayed_characters.size():
		return

	var character: Dictionary = displayed_characters[card_index]
	if character.is_empty():
		status_label.text = "That slot is empty."
		return
	if not _is_character_available(character):
		status_label.text = "%s is unavailable for %s trips." % [character["name"], selected_distance]
		return

	var transition_mode := _transition_mode()
	var energy_bonus := PlayerState.get_transition_energy_bonus(transition_mode)
	var applied_bonus: int = mini(energy_bonus, PlayerState.max_energy - PlayerState.energy)
	if applied_bonus > 0:
		PlayerState.add_energy(applied_bonus)

	if not PlayerState.prepare_stage_start():
		if applied_bonus > 0:
			PlayerState.add_energy(-applied_bonus)
		status_label.text = "Not enough energy to start this trip."
		return

	PlayerState.set_current_mock_character(String(character.get("id", "")))
	PlayerState.advance_to_next_stage(
		transition_mode,
		selected_distance,
		String(character.get("stage_traffic", ""))
	)
	PlayerState.clear_pending_trip_selection()
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(FALLBACK_SCENE)
		return
	get_tree().change_scene_to_file(NEXT_STAGE_SCENE)


func _go_back() -> void:
	var return_scene := String(pending_trip_selection.get("return_scene", FALLBACK_SCENE))
	PlayerState.clear_pending_trip_selection()
	get_tree().change_scene_to_file(return_scene if not return_scene.is_empty() else FALLBACK_SCENE)


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


func _transition_mode() -> String:
	var transition_mode := String(pending_trip_selection.get("transition_mode", ""))
	if transition_mode.is_empty():
		if bool(pending_trip_selection.get("skip_to_night", false)):
			return PlayerState.TRANSITION_REST_TO_NIGHT
		return PlayerState.TRANSITION_RIDE
	return PlayerState.normalize_transition_mode(transition_mode)
