extends Control

const NEXT_STAGE_SCENE := "res://scenes/main.tscn"
const DAY_START_SCENE := "res://scenes/day_start_transition.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const EMPTY_CARD_CHANCE := 0.28
@onready var subtitle_label: Label = $Panel/Subtitle
@onready var status_label: Label = $Panel/StatusLabel
@onready var money_label: Label = $Panel/MoneyLabel
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

var pending_trip_selection: Dictionary = {}
var rng := RandomNumberGenerator.new()
var selected_distance := "short"
var displayed_characters: Array[Dictionary] = []
var stats_row_refs: Dictionary = {}


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/ride_selection.tscn")
	rng.randomize()
	pending_trip_selection = PlayerState.get_pending_trip_selection()
	selected_distance = PlayerState.get_locked_pending_trip_distance()
	if selected_distance.is_empty():
		selected_distance = "short"
	back_button.visible = _allow_back()
	_create_stats_row()

	back_button.pressed.connect(_handle_back_button_pressed)
	short_button.pressed.connect(_set_distance.bind("short"))
	medium_button.pressed.connect(_set_distance.bind("medium"))
	long_button.pressed.connect(_set_distance.bind("long"))
	card_a.gui_input.connect(_on_card_gui_input.bind(0))
	card_b.gui_input.connect(_on_card_gui_input.bind(1))
	card_c.gui_input.connect(_on_card_gui_input.bind(2))

	for label in [card_a_label, card_b_label, card_c_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for button in [back_button, short_button, medium_button, long_button]:
		ButtonGlow.attach(self, button)

	var locked_characters: Array = PlayerState.get_locked_pending_trip_characters()
	if locked_characters.is_empty():
		displayed_characters = _roll_character_cards()
		PlayerState.lock_pending_trip_selection(displayed_characters, selected_distance)
	else:
		displayed_characters.clear()
		for character_data in locked_characters:
			displayed_characters.append(character_data)

	_refresh_header()
	_refresh_action_button()
	_set_distance(selected_distance)
	if _show_store_shortcut():
		back_button.grab_focus()
	else:
		match selected_distance:
			"medium":
				medium_button.grab_focus()
			"long":
				long_button.grab_focus()
			_:
				short_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_cancel") and _allow_back():
		_go_back()


func _refresh_header() -> void:
	var display_day := PlayerState.get_transition_display_day(_transition_mode())
	_refresh_stats_row()
	money_label.text = PlayerState.get_debt_status_text(display_day)


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
	PlayerState.lock_pending_trip_selection(displayed_characters, selected_distance)
	_refresh_subtitle()
	_refresh_distance_buttons()
	_refresh_character_cards()
	if _show_store_shortcut():
		status_label.text = "Out of gas. Visit the store to refuel before Day %d begins." % _display_day()
	else:
		status_label.text = "Choose a passenger for a %s trip." % difficulty.capitalize()


func _refresh_distance_buttons() -> void:
	for button_data in [
		{"button": short_button, "id": "short"},
		{"button": medium_button, "id": "medium"},
		{"button": long_button, "id": "long"},
	]:
		var button := button_data["button"] as BaseButton
		var button_id: String = str(button_data["id"])
		var is_selected: bool = button_id == selected_distance
		button.disabled = is_selected
		ButtonGlow.set_state(self, button, is_selected)


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
				str(character["name"]).to_upper(),
				preview_stage_type,
				PlayerState.estimate_stage_earnings(preview_stage_type),
			]
			panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_available else Control.CURSOR_ARROW


func _roll_character_cards() -> Array[Dictionary]:
	for _attempt in range(24):
		var rolled_cards := _roll_character_cards_once()
		if _has_distance_coverage(rolled_cards):
			return rolled_cards

	return _build_guaranteed_coverage_cards()


func _roll_character_cards_once() -> Array[Dictionary]:
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
	var guaranteed_slot := -1
	var guaranteed_character: Dictionary = {}
	if PlayerState.gas <= 4:
		guaranteed_character = _pick_short_trip_character_from_pools(eligible_first_appearance, eligible_repeat, used_ids)
		if guaranteed_character.is_empty():
			guaranteed_character = _fallback_short_trip_character(used_ids)
		if not guaranteed_character.is_empty():
			used_ids[guaranteed_character["id"]] = true
			guaranteed_slot = rng.randi_range(0, 2)

	for _slot_index in range(3):
		if _slot_index == guaranteed_slot:
			card_results.append(_lock_character_for_selection(guaranteed_character))
			continue

		if rng.randf() < EMPTY_CARD_CHANCE:
			card_results.append({})
			continue

		var picked_character := _pick_character_from_pools(eligible_first_appearance, eligible_repeat, used_ids)

		if picked_character.is_empty():
			card_results.append({})
			continue

		used_ids[picked_character["id"]] = true
		card_results.append(_lock_character_for_selection(picked_character))

	while card_results.size() < 3:
		card_results.append({})

	return card_results


func _has_distance_coverage(card_results: Array[Dictionary]) -> bool:
	for difficulty in PlayerState.STAGE_DIFFICULTIES:
		var has_match := false
		for character in card_results:
			if character.is_empty():
				continue
			if _character_supports_distance(character, str(difficulty)):
				has_match = true
				break
		if not has_match:
			return false
	return true


func _build_guaranteed_coverage_cards() -> Array[Dictionary]:
	var card_results: Array[Dictionary] = []
	var used_ids: Dictionary = {}
	for difficulty_variant in PlayerState.STAGE_DIFFICULTIES:
		var difficulty := str(difficulty_variant)
		var candidate := _pick_character_for_distance(difficulty, used_ids)
		if candidate.is_empty():
			continue
		used_ids[candidate["id"]] = true
		card_results.append(_lock_character_for_selection(candidate))

	while card_results.size() < 3:
		var filler := _pick_character_for_distance(selected_distance, used_ids)
		if filler.is_empty():
			break
		used_ids[filler["id"]] = true
		card_results.append(_lock_character_for_selection(filler))

	while card_results.size() < 3:
		card_results.append({})

	return card_results


func _pick_character_from_pools(eligible_first_appearance: Array[Dictionary], eligible_repeat: Array[Dictionary], used_ids: Dictionary) -> Dictionary:
	while not eligible_first_appearance.is_empty():
		var first_candidate: Dictionary = eligible_first_appearance.pop_front()
		if not used_ids.has(first_candidate["id"]):
			return first_candidate

	while not eligible_repeat.is_empty():
		var repeat_candidate: Dictionary = eligible_repeat.pop_front()
		if not used_ids.has(repeat_candidate["id"]):
			return repeat_candidate

	return {}


func _pick_short_trip_character_from_pools(eligible_first_appearance: Array[Dictionary], eligible_repeat: Array[Dictionary], used_ids: Dictionary) -> Dictionary:
	for index in range(eligible_first_appearance.size()):
		var first_candidate: Dictionary = eligible_first_appearance[index]
		if used_ids.has(first_candidate["id"]):
			continue
		if _supports_short_trip(first_candidate, true):
			eligible_first_appearance.remove_at(index)
			return first_candidate

	for index in range(eligible_repeat.size()):
		var repeat_candidate: Dictionary = eligible_repeat[index]
		if used_ids.has(repeat_candidate["id"]):
			continue
		if _supports_short_trip(repeat_candidate, false):
			eligible_repeat.remove_at(index)
			return repeat_candidate

	return {}


func _fallback_short_trip_character(used_ids: Dictionary) -> Dictionary:
	var fallback_candidates: Array[Dictionary] = []
	for character_data in PlayerState.get_mock_characters():
		var character: Dictionary = character_data
		if used_ids.has(character["id"]):
			continue

		var is_seen := PlayerState.has_seen_mock_character(str(character["id"]))
		if _supports_short_trip(character, not is_seen):
			fallback_candidates.append(character)

	if fallback_candidates.is_empty():
		return {}

	fallback_candidates.shuffle()
	return fallback_candidates[0]


func _pick_character_for_distance(distance: String, used_ids: Dictionary) -> Dictionary:
	var seen_candidates: Array[Dictionary] = []
	var unseen_candidates: Array[Dictionary] = []
	for character_data in PlayerState.get_mock_characters():
		var character: Dictionary = character_data
		var character_id := str(character.get("id", ""))
		if used_ids.has(character_id):
			continue
		var is_seen := PlayerState.has_seen_mock_character(character_id)
		if not _supports_distance_in_selection(character, distance, not is_seen):
			continue
		if is_seen:
			seen_candidates.append(character)
		else:
			unseen_candidates.append(character)

	if not seen_candidates.is_empty():
		seen_candidates.shuffle()
		return seen_candidates[0]
	if not unseen_candidates.is_empty():
		unseen_candidates.shuffle()
		return unseen_candidates[0]
	return {}


func _supports_short_trip(character: Dictionary, is_first_appearance: bool) -> bool:
	return _supports_distance_in_selection(character, "short", is_first_appearance)


func _supports_distance_in_selection(character: Dictionary, distance: String, is_first_appearance: bool) -> bool:
	if is_first_appearance:
		return str(character.get("first_distance", "")) == distance

	var eligible_distances: Array = character.get("eligible_distances", [])
	return eligible_distances.has(distance)


func _character_supports_distance(character: Dictionary, distance: String) -> bool:
	return _supports_distance_in_selection(character, distance, bool(character.get("is_first_appearance", false)))


func _lock_character_for_selection(picked_character: Dictionary) -> Dictionary:
	var was_seen_before_roll := PlayerState.has_seen_mock_character(str(picked_character["id"]))
	PlayerState.mark_mock_character_seen(str(picked_character["id"]))
	var locked_character: Dictionary = picked_character.duplicate(true)
	locked_character["stage_traffic"] = PlayerState.get_random_stage_traffic_type()
	locked_character["is_first_appearance"] = not was_seen_before_roll
	return locked_character


func _on_card_gui_input(event: InputEvent, card_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_character(card_index)


func _is_character_available(character: Dictionary) -> bool:
	if character.is_empty():
		return false

	if bool(character.get("is_first_appearance", false)):
		return selected_distance == str(character.get("first_distance", ""))

	var eligible_distances: Array = character.get("eligible_distances", [])
	return eligible_distances.has(selected_distance)


func _preview_distance_for_character(character: Dictionary) -> String:
	var preview_distance := selected_distance
	if bool(character.get("is_first_appearance", false)):
		preview_distance = str(character.get("first_distance", selected_distance))
	elif not _is_character_available(character):
		var eligible_distances: Array = character.get("eligible_distances", [])
		if not eligible_distances.is_empty():
			preview_distance = str(eligible_distances[0])

	return preview_distance


func _preview_stage_type(character: Dictionary) -> String:
	return PlayerState.build_stage_type(
		_preview_distance_for_character(character),
		PlayerState.get_next_stage_time(_transition_mode()),
		str(character.get("stage_traffic", "chill"))
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
	var applied_bonus := PlayerState.apply_transition_energy_bonus(transition_mode)

	if not PlayerState.prepare_stage_start(selected_distance):
		if applied_bonus > 0:
			PlayerState.add_energy(-applied_bonus)
		var start_error := PlayerState.get_stage_start_error(selected_distance)
		if _show_store_shortcut() and start_error == "Not enough gas for this trip.":
			status_label.text = "Not enough gas for this trip. Visit the store to refuel."
		else:
			status_label.text = start_error
		return

	PlayerState.set_current_mock_character(str(character.get("id", "")))
	var should_show_day_start_transition := PlayerState.will_advance_day(transition_mode)
	PlayerState.advance_to_next_stage(
		transition_mode,
		selected_distance,
		str(character.get("stage_traffic", ""))
	)
	PlayerState.clear_pending_trip_selection()
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(FALLBACK_SCENE)
		return
	get_tree().change_scene_to_file(DAY_START_SCENE if should_show_day_start_transition else NEXT_STAGE_SCENE)


func _go_back() -> void:
	if not _allow_back():
		return

	var return_scene := str(pending_trip_selection.get("return_scene", FALLBACK_SCENE))
	get_tree().change_scene_to_file(return_scene if not return_scene.is_empty() else FALLBACK_SCENE)


func _handle_back_button_pressed() -> void:
	if _show_store_shortcut():
		get_tree().change_scene_to_file(STORE_SCENE)
		return
	_go_back()


func _transition_mode() -> String:
	var transition_mode := str(pending_trip_selection.get("transition_mode", ""))
	if transition_mode.is_empty():
		if bool(pending_trip_selection.get("skip_to_night", false)):
			return PlayerState.TRANSITION_REST_TO_NIGHT
		return PlayerState.TRANSITION_RIDE
	return PlayerState.normalize_transition_mode(transition_mode)


func _allow_back() -> bool:
	return bool(pending_trip_selection.get("allow_back", true))


func _display_day() -> int:
	return PlayerState.get_transition_display_day(_transition_mode())


func _can_open_store_from_selection() -> bool:
	return _display_day() >= 2 and PlayerState.gas <= 0


func _show_store_shortcut() -> bool:
	return not _allow_back() and _can_open_store_from_selection()


func _refresh_action_button() -> void:
	back_button.visible = _allow_back() or _show_store_shortcut()
	back_label.text = "STORE" if _show_store_shortcut() else "BACK"


func _create_stats_row() -> void:
	stats_row_refs = PlayerStatsRow.create({
		"font": UI_FONT,
		"font_size": 10,
		"font_color": Color(0.30, 0.19, 0.10, 1.0),
		"outline_color": Color(0.98, 0.94, 0.83, 0.86),
	})
	var stats_row := stats_row_refs["row"] as HBoxContainer
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.layout_mode = 1
	stats_row.offset_left = 90.0
	stats_row.offset_top = 118.0
	stats_row.offset_right = 1064.0
	stats_row.offset_bottom = 144.0
	$Panel.add_child(stats_row)


func _refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return

	PlayerStatsRow.refresh(stats_row_refs)
