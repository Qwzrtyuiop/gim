extends Control

signal midnight_encounter_selected(encounter_id: String, character_id: String)

# Coordinates station navigation, locked passenger offers, and ride/story entry.
const STORY_SCENE := "res://scenes/story_scene.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const PassengerPool := preload("res://scripts/ride_selection/passenger_pool.gd")
const SelectionView := preload("res://scripts/ride_selection/selection_view.gd")
const SelectionTutorial := preload("res://scripts/ride_selection/selection_tutorial.gd")
const PassengerStory := preload("res://scripts/ride_selection/passenger_story.gd")
const RideDeparture := preload("res://scripts/ride_selection/ride_departure.gd")
const StationInterface := preload("res://scripts/ride_selection/station_interface.gd")
const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const HubNightAmbience := preload("res://scripts/ui/hub_night_ambience.gd")
const StationIdleMusic := preload("res://scripts/ui/station_idle_music.gd")
const MidnightEncounters := preload("res://scripts/ride_selection/midnight_encounters.gd")
const DialogueAnchors := preload("res://scripts/ui/hub_dialogue_anchors.gd")

var pending_trip_selection: Dictionary = {}
var selected_distance := "short"
var locked_character_pools: Dictionary = {}
var displayed_characters: Array[Dictionary] = []
var terminal_offers: Array[Dictionary] = []
var focused_offer: Dictionary = {}
var passenger_pool: PassengerPool
var view: SelectionView
var tutorial: SelectionTutorial
var is_departing := false
var station: Control
var passenger_overlay: ColorRect
var terminal_view: Control
var status_label: Label
var status_header: PanelContainer
var station_back_button: Button
var station_ui: StationInterface
var confirmation: Control
var _confirmation_offer: Dictionary = {}
var _confirmation_input := InputHighlightMode.new()
var hub_dialogue: HubDialogue
var night_ambience: HubNightAmbience
var idle_music: StationIdleMusic


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/ride_selection.tscn")
	passenger_pool = PassengerPool.new(self)
	view = SelectionView.new(self)
	tutorial = SelectionTutorial.new(self)
	pending_trip_selection = PlayerState.get_pending_trip_selection()
	selected_distance = PlayerState.get_locked_pending_trip_distance()
	if selected_distance.is_empty() or _is_forced_first_day_ride():
		selected_distance = "short"
	locked_character_pools = PlayerState.get_locked_pending_trip_character_pools()
	# Older selections stored a single distance's locked offers as an array.
	var legacy: Array = pending_trip_selection.get("locked_characters", [])
	if locked_character_pools.is_empty() and not legacy.is_empty():
		locked_character_pools[selected_distance] = legacy.duplicate(true)
	if locked_character_pools.is_empty():
		locked_character_pools = passenger_pool.roll()
	elif PlayerState.are_passengers_available() and view.offers().is_empty():
		# A legacy locked pool can predate a character's current schedule. Repair
		# only a wholly unusable selection, so the player always has a way forward.
		locked_character_pools = passenger_pool.roll()
	_set_distance(selected_distance)
	station_ui = StationInterface.new(self)
	station_ui.setup()
	_create_hub_dialogue()
	night_ambience = AmbientAudioManager
	AmbientAudioManager.enter_hub(true)
	view.start_ride_select_bgm()
	idle_music = StationIdleMusic.new()
	idle_music.can_play = func() -> bool: return not is_departing
	idle_music.active_changed.connect(_on_idle_music_changed)
	add_child(idle_music)
	MidnightEncounters.prepare(PlayerState)
	_refresh_terminal()
	var story_error := PlayerState.take_pending_trip_selection_error()
	if not story_error.is_empty():
		status_label.text = story_error
	tutorial.build()
	var opening_tutorial := _is_forced_first_day_ride() and not PlayerState.has_ride_select_tutorial_shown()
	if opening_tutorial or bool(pending_trip_selection.get("passengers_open", false)) or not story_error.is_empty():
		_open_passengers()


func _input(event: InputEvent) -> void:
	if tutorial != null and tutorial.active and tutorial.is_any_press(event):
		get_viewport().set_input_as_handled()
		tutorial.advance()
	elif hub_dialogue != null and hub_dialogue.handle_input(event):
		get_viewport().set_input_as_handled()
	elif confirmation != null and confirmation.visible:
		_confirmation_input.handle_input(event)
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_cancel_passenger()
	elif passenger_overlay != null and passenger_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_passengers()


func _unhandled_input(event: InputEvent) -> void:
	if (tutorial != null and tutorial.active) or (confirmation != null and confirmation.visible) or _speech_is_blocking():
		return
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_cancel") and _allow_back():
		_go_back()


func _set_distance(difficulty: String) -> void:
	# Save the last selected distance without filtering terminal spawns.
	selected_distance = "short" if _is_forced_first_day_ride() else difficulty
	if not PlayerState.STAGE_DIFFICULTIES.has(selected_distance):
		selected_distance = "short"
	displayed_characters = passenger_pool.for_distance(selected_distance)
	PlayerState.lock_pending_trip_selection(locked_character_pools, selected_distance)


func _refresh_terminal() -> void:
	terminal_offers = view.offers()
	view.refresh_terminal()
	var weather := PlayerState.get_current_weather()
	idle_music.set_weather(weather)
	station.set_weather(weather)
	terminal_view.set_weather(weather)
	night_ambience.refresh()


func _on_idle_music_changed(_active: bool) -> void:
	view.refresh_bgm()


func _focus_offer(distance: String, slot: int) -> void:
	# Hover/focus must never save, reroll, or select a ride.
	for offer in terminal_offers:
		if offer.distance == distance and int(offer.slot) == slot:
			focused_offer = offer.duplicate(true)
			return


func _choose_character(card_index: int) -> void:
	_choose_offer(selected_distance, card_index)


func _choose_offer(distance: String, slot: int) -> void:
	if is_departing or tutorial.active or not passenger_overlay.visible or confirmation.visible or _speech_is_blocking():
		return
	for offer in terminal_offers:
		if offer.distance == distance and int(offer.slot) == slot:
			if str(offer.get("kind", "")) == "encounter":
				_interact_midnight_encounter(offer)
				return
			_confirmation_offer = offer.duplicate(true)
			_confirmation_offer["day"] = PlayerState.get_current_day()
			_confirmation_offer["phase"] = PlayerState.get_current_time_of_day()
			_confirmation_offer["round"] = PlayerState.stage_round
			_confirmation_input.keyboard_active = terminal_view.is_keyboard_navigation()
			terminal_view.set_enabled(false)
			confirmation.present(offer.summary)
			return


func _interact_midnight_encounter(offer: Dictionary) -> void:
	if not MidnightEncounters.is_available(PlayerState, offer):
		_refresh_terminal()
		return
	var interaction := MidnightEncounters.interact(PlayerState, offer)
	if interaction.is_empty():
		return
	if bool(interaction.get("start_event", false)):
		hub_dialogue.clear()
		# The future authored event starts here, after the four floating lines.
		midnight_encounter_selected.emit(str(offer.encounter_id), str(offer.character.id))
		return
	show_message(str(interaction.text), {
		"target": "gardo",
		"character_id": "gardo",
		"typewriter": false,
	})


func _cancel_passenger() -> void:
	if not confirmation.visible:
		return
	var character: Dictionary = _confirmation_offer.get("character", {})
	_confirmation_offer.clear()
	confirmation.dismiss()
	_restore_passenger_controls(str(character.get("id", "")))


func _confirm_passenger() -> void:
	if is_departing or tutorial.active or not confirmation.visible or _confirmation_offer.is_empty():
		return
	var request := _confirmation_offer.duplicate(true)
	var unchanged_time := (
		int(request.day) == PlayerState.get_current_day()
		and str(request.phase) == PlayerState.get_current_time_of_day()
		and int(request.round) == int(PlayerState.stage_round)
	)
	var selected: Dictionary = {}
	for offer in view.offers():
		if offer.distance == request.distance and int(offer.slot) == int(request.slot) and offer.character == request.character:
			selected = offer
			break
	_confirmation_offer.clear()
	confirmation.dismiss()
	if not unchanged_time or selected.is_empty():
		_restore_passenger_controls("")
		_refresh_terminal()
		status_label.text = "This passenger is no longer available. Please choose again."
		return
	_depart_with_offer(selected)


func _restore_passenger_controls(character_id: String) -> void:
	if not passenger_overlay.visible:
		return
	terminal_view.set_enabled(true)
	terminal_view.set_keyboard_navigation(_confirmation_input.keyboard_active)
	if terminal_view.buttons.has(character_id):
		terminal_view.buttons[character_id].grab_focus()
	else:
		terminal_view.focus_first_offer()


func _depart_with_offer(offer: Dictionary) -> void:
	if str(offer.get("kind", "")) == "encounter":
		return
	if not PlayerState.are_passengers_available():
		is_departing = false
		_refresh_terminal()
		_restore_passenger_controls("")
		return
	hub_dialogue.clear()
	var character: Dictionary = Dictionary(offer.character).duplicate(true)
	_set_distance(str(offer.distance))
	is_departing = true
	var transition_mode := _transition_mode()
	if PassengerStory.begin(character, selected_distance, transition_mode, _is_forced_first_day_ride()):
		get_tree().change_scene_to_file(STORY_SCENE)
		return
	if _is_forced_first_day_ride():
		character["stage_traffic"] = "chill"
	var departure := RideDeparture.start(character, selected_distance, transition_mode, str(pending_trip_selection.get("return_scene", "")))
	if str(departure.get("scene", "")).is_empty():
		is_departing = false
		status_label.text = str(departure.get("error", ""))
		if status_label.text == "Not enough gas for this trip.":
			status_label.text = "Not enough gas for this trip. Visit the store to refuel."
		_restore_passenger_controls(str(character.get("id", "")))
		return
	get_tree().change_scene_to_file(str(departure.scene))


func _go_back() -> void:
	if is_departing or confirmation.visible or not _allow_back() or _speech_is_blocking():
		return
	hub_dialogue.clear()
	is_departing = true
	station.set_enabled(false)
	var return_scene := str(pending_trip_selection.get("return_scene", FALLBACK_SCENE))
	get_tree().change_scene_to_file(return_scene if not return_scene.is_empty() else FALLBACK_SCENE)


func _open_store() -> void:
	if is_departing or tutorial.active or confirmation.visible or _speech_is_blocking():
		return
	_close_passengers()
	hub_dialogue.clear()
	is_departing = true
	station.set_enabled(false)
	get_tree().change_scene_to_file(STORE_SCENE)


func _handle_back_button_pressed() -> void:
	if passenger_overlay.visible:
		_close_passengers()
	else:
		_go_back()


func _on_station_action(action: String) -> void:
	if is_departing or passenger_overlay.visible or tutorial.active or _speech_is_blocking():
		return
	match action:
		"passengers":
			_open_passengers()
		"store":
			_open_store()


func _open_passengers() -> void:
	if _speech_is_blocking():
		return
	hub_dialogue.clear()
	station_ui.show_passengers()


func _close_passengers() -> void:
	if confirmation.visible or _speech_is_blocking():
		return
	hub_dialogue.clear()
	station_ui.hide_passengers()


func _transition_mode() -> String:
	if not PlayerState.are_passengers_available():
		return PlayerState.TRANSITION_CURRENT_STAGE
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


func _create_hub_dialogue() -> void:
	hub_dialogue = HubDialogue.new()
	hub_dialogue.name = "HubDialogue"
	add_child(hub_dialogue)
	hub_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_dialogue.set_gate(func() -> bool:
		return not is_departing and not tutorial.active and not confirmation.visible
	)
	hub_dialogue.register_target("tricycle", _station_message_target.bind("passengers"))
	hub_dialogue.register_target("store", _station_message_target.bind("store"))
	for character: Dictionary in PlayerState.get_mock_characters():
		var character_id := str(character.get("id", ""))
		if not character_id.is_empty():
			hub_dialogue.register_target(character_id, _passenger_message_target.bind(character_id))
			hub_dialogue.register_target("passenger:" + character_id, _passenger_message_target.bind(character_id))


func _station_message_target(action: String) -> Rect2:
	if passenger_overlay.visible:
		return Rect2()
	return DialogueAnchors.control_rect(station.buttons.get(action) as Control)


func _passenger_message_target(character_id: String) -> Rect2:
	return DialogueAnchors.terminal_character(self, character_id)


func show_message(text: Variant, options: Dictionary = {}) -> bool:
	return hub_dialogue.say(text, options) if hub_dialogue != null else false


func show_messages(lines: Array, options: Dictionary = {}) -> bool:
	return hub_dialogue.play(lines, options) if hub_dialogue != null else false


func _speech_is_blocking() -> bool:
	return hub_dialogue != null and hub_dialogue.blocks_input()
