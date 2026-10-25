extends RefCounted

const SelectionStory := preload("res://scripts/ride_selection/passenger_story.gd")
const Payload := preload("res://scripts/story/story_payload.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const Actions := preload("res://scripts/story/story_action_runner.gd")
const ActionCatalog := preload("res://scripts/story/story_action_catalog.gd")
const Flow := preload("res://scripts/story/story_game_flow.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"


static func run(host: Node) -> void:
	_test_eligibility_and_save()
	_test_rest_continuation()
	await _test_click_and_return(host)
	await _test_outcomes(host)
	await _test_saved_ride_handoff(host)
	PlayerState.reset()
	StoryLanguageManager.set_language("english")
	print("PASS: Jessa selection event eligibility, pre-cost launch, same-offer return, save/resume, optional ride/skip, chaining and replay isolation")


static func _setup(mode: String = PlayerState.TRANSITION_RIDE) -> Dictionary:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "noon"
	PlayerState.current_stage_type = "short-noon-chill"
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 5
	PlayerState.gas = 50.0
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.set_event_value("jessa_runaway_fare_seen", true)
	PlayerState.set_pending_trip_selection("res://scenes/stage_results.tscn", mode, true)
	var character: Dictionary = PlayerState.get_character_by_id("jessa")
	character["active_distance"] = "short"
	character["stage_traffic"] = "traffic-jam"
	character["stage_special_type"] = PlayerState.STAGE_SPECIAL_TYPE_NONE
	character["special_stage_id"] = ""
	PlayerState.lock_pending_trip_selection({
		"short": [character, {}, {}],
		"medium": [{}, {}, {}],
		"long": [{}, {}, {}],
	}, "short")
	return character


static func _test_eligibility_and_save() -> void:
	var localized: Array[Dictionary] = []
	for language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(language)
		var character := _setup()
		PlayerState.clear_event_value("jessa_runaway_fare_seen")
		assert(not SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE), "Jessa's second event requires completing her first event")
		PlayerState.set_event_value("jessa_runaway_fare_seen", false)
		assert(not SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE), "An explicitly false first-event flag does not count as completion")
		PlayerState.set_event_value("jessa_runaway_fare_seen", true)
		assert(not SelectionStory.begin({"id": "benny"}, "short", PlayerState.TRANSITION_RIDE), "Selecting another passenger must not trigger Jessa")
		PlayerState.energy = 0
		PlayerState.gas = 0.0
		PlayerState.set_current_mock_character("benny")
		var offers := PlayerState.get_pending_trip_selection()
		assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE), "Story entry happens before trip resource checks")
		var payload := PlayerState.get_pending_story()
		assert(payload.story_id == "jessa_second_encounter" and Payload.validate(payload).is_empty())
		assert(payload._passenger_selection.character.id == "jessa")
		assert(PlayerState.get_current_mock_character_id() == "jessa", "Default character actions must use the clicked passenger, not the previous rider")
		assert(payload._passenger_selection.distance == "short")
		assert(PlayerState.get_pending_trip_selection() == offers)
		assert(PlayerState.energy == 0 and PlayerState.gas == 0.0 and PlayerState.stage_round == 4)
		assert(PlayerState.get_current_day() == 3 and PlayerState.get_current_time_of_day() == "noon")
		assert(PlayerState.resume_scene_path == STORY_SCENE)
		localized.append(PayloadCatalog.build("jessa_second_encounter"))
		Codec.save_to_path(PlayerState, "res://test_user/passenger_event_%s.tres" % language, PlayerState.SAVE_VERSION)
		PlayerState.reset()
		assert(Codec.load_from_path(PlayerState, "res://test_user/passenger_event_%s.tres" % language))
		assert(PlayerState.get_pending_story() == payload and PlayerState.get_pending_trip_selection() == offers)
		assert(PlayerState.find_story_trigger_for_phase("passenger_selected", 3, {"character_id": "jessa"}).is_empty(), "The launched trigger must remain consumed after loading")
		assert(not SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE), "An active story cannot be overwritten")
	assert(_without_words(localized[0]) == _without_words(localized[1]), "New translations must preserve actions, presentation and routing")
	var character := _setup()
	PlayerState.set_event_value("jessa_second_encounter_seen", true)
	assert(not SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	PlayerState.clear_event_value("jessa_second_encounter_seen")
	PlayerState.fail_run("Fixture failure")
	assert(not SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))


static func _test_rest_continuation() -> void:
	var mode: String = PlayerState.TRANSITION_REST_TO_NIGHT
	var character := _setup(mode)
	PlayerState.energy = 2
	var offers := PlayerState.get_pending_trip_selection()
	assert(SelectionStory.begin(character, "short", mode))
	var payload := PlayerState.get_pending_story()
	var ride_payload := payload.duplicate(true)
	assert(SelectionStory.complete(payload, SELECTION_SCENE) == SELECTION_SCENE)
	assert(PlayerState.get_pending_trip_selection() == offers, "A return must preserve rest mode and its locked offers")
	assert(PlayerState.pending_trip_selection.transition_mode == mode)
	assert(PlayerState.get_current_time_of_day() == "noon" and PlayerState.energy == 2)
	assert(PlayerState.stage_round == 4 and PlayerState.last_rest_day == 0, "The event itself does not grant the planned rest")
	# The departure branch of the same selection pays and recovers normally.
	ride_payload["_selection_outcome"] = "ride"
	var expected_energy: int = 2 + PlayerState.get_transition_energy_bonus(mode) - 1
	assert(SelectionStory.complete(ride_payload, SELECTION_SCENE) == "res://scenes/main.tscn")
	assert(PlayerState.energy == expected_energy and PlayerState.last_rest_day == 3)
	assert(PlayerState.get_current_time_of_day() == "night" and PlayerState.stage_round == 5)
	assert(SelectionStory.complete(ride_payload, SELECTION_SCENE) == "res://scenes/main.tscn")
	assert(PlayerState.energy == expected_energy and PlayerState.stage_round == 5, "Rest recovery and the ride charge apply once")


static func _test_click_and_return(host: Node) -> void:
	_setup()
	PlayerState.energy = 0
	PlayerState.gas = 0.0
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	selection._open_passengers()
	var offers := PlayerState.get_pending_trip_selection()
	await _click_passenger(host, selection, "jessa")
	assert(selection.confirmation.visible and PlayerState.pending_story.is_empty(), "Jessa's story must wait for passenger confirmation")
	assert(PlayerState.get_pending_trip_selection() == offers and PlayerState.energy == 0 and PlayerState.gas == 0.0)
	selection.confirmation.cancel_button.pressed.emit()
	assert(not selection.confirmation.visible and PlayerState.consumed_story_triggers.get("jessa_second_encounter", false) == false, "Cancelling cannot consume the event")
	await _click_passenger(host, selection, "jessa")
	selection.confirmation.confirm_button.pressed.emit()
	if host.get_tree().current_scene == null or host.get_tree().current_scene.scene_file_path != STORY_SCENE:
		await host.get_tree().scene_changed
	var reader = host.get_tree().current_scene
	await host.get_tree().create_timer(1.1).timeout
	assert(reader.scene_file_path == STORY_SCENE and reader.story_id == "jessa_second_encounter")
	assert(PlayerState.energy == 0 and PlayerState.gas == 0.0 and PlayerState.stage_round == 4)
	# Reload a real checkpoint, then complete the event through the real reader.
	host.get_tree().current_scene = null
	reader.free()
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	reader = await host._reader(PlayerState.get_pending_story())
	await reader._advance_story()
	assert(PlayerState.has_event_value("jessa_second_encounter_seen"))
	await reader._finish_story()
	await host.get_tree().scene_changed
	var returned = host.get_tree().current_scene
	assert(returned.scene_file_path == SELECTION_SCENE)
	assert(returned.passenger_overlay.visible and returned.terminal_view.visible, "Passenger stories return to the open passenger screen")
	assert(PlayerState.pending_story.is_empty() and PlayerState.resume_scene_path == SELECTION_SCENE)
	assert(PlayerState.get_pending_trip_selection() == offers and returned.locked_character_pools == offers.locked_character_pools)
	assert(PlayerState.get_current_day() == 3 and PlayerState.get_current_time_of_day() == "noon")
	assert(PlayerState.energy == 0 and PlayerState.gas == 0.0 and PlayerState.money == 500 and PlayerState.stage_round == 4)
	await _click_passenger(host, returned, "jessa")
	assert(returned.confirmation.visible and PlayerState.pending_story.is_empty())
	returned.confirmation.confirm_button.pressed.emit()
	assert(PlayerState.pending_story.is_empty(), "Second selection uses ordinary ride checks rather than repeating the event")
	assert(returned.status_label.text.contains("energy"))
	host.get_tree().current_scene = null
	returned.free()
	reader.free()
	selection.free()


static func _click_passenger(host: Node, selection, character_id: String) -> void:
	var button: Button = selection.terminal_view.buttons[character_id]
	var local_point := Vector2.ZERO
	var found := false
	for y in range(1, 10):
		for x in range(1, 10):
			var candidate := button.size * Vector2(x, y) / 10.0
			if bool(button.call("_has_point", candidate)):
				local_point = candidate
				found = true
				break
		if found:
			break
	assert(found, "The passenger must have a clickable body")
	var point: Vector2 = button.global_position + local_point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	host.get_viewport().push_input(motion, true)
	await host.get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame


static func _test_outcomes(host: Node) -> void:
	assert(ActionCatalog.validate_action({"type": "selection_outcome", "outcome": "invalid"}).size() > 0)
	assert(Actions.is_persistent_story_action({"type": "selection_outcome"}))
	var character := _setup()
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	var reader = await host._reader(PlayerState.get_pending_story())
	await reader._run_story_action({"type": "selection_outcome", "outcome": "ride"})
	await reader._run_story_action({"type": "queue_story", "id": "malasakit"})
	var queued := Flow.queued_story(reader, SELECTION_SCENE)
	assert(queued._passenger_selection == reader.story_payload._passenger_selection)
	assert(queued._selection_outcome == "ride", "A chained scene must preserve the selected passenger and departure outcome")
	var payload: Dictionary = reader.story_payload
	assert(SelectionStory.complete(payload, SELECTION_SCENE) == "res://scenes/main.tscn")
	assert(PlayerState.current_mock_character_id == "jessa" and PlayerState.current_stage_type == "short-night-traffic-jam")
	assert(PlayerState.energy == 4 and PlayerState.gas == 50.0 and PlayerState.stage_round == 5)
	assert(PlayerState.pending_stage_energy_cost and PlayerState.pending_trip_selection.is_empty())
	assert(SelectionStory.complete(payload, SELECTION_SCENE) == "res://scenes/main.tscn")
	assert(PlayerState.energy == 4 and PlayerState.stage_round == 5, "Completing the same handoff twice cannot charge or advance twice")
	reader.free()

	character = _setup()
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	reader = await host._reader(PlayerState.get_pending_story())
	await reader._run_story_action({"type": "selection_outcome", "outcome": "skip"})
	assert(PlayerState.get_current_day() == 3 and PlayerState.get_current_time_of_day() == "night")
	assert(PlayerState.energy == 5 and PlayerState.stage_round == 4)
	assert(SelectionStory.complete(reader.story_payload, Flow.destination(reader, SELECTION_SCENE)) == SELECTION_SCENE)
	assert(PlayerState.pending_trip_selection.transition_mode == PlayerState.TRANSITION_CURRENT_STAGE)
	assert(PlayerState.get_locked_pending_trip_character_pools().is_empty(), "Skipping time discards offers from the old phase")
	# A ride after a clock skip uses the reached phase, without skipping again.
	await reader._run_story_action({"type": "selection_outcome", "outcome": "ride"})
	reader.story_payload.erase("_selection_completed_scene")
	assert(SelectionStory.complete(reader.story_payload, SELECTION_SCENE) == "res://scenes/main.tscn")
	assert(PlayerState.get_current_time_of_day() == "night" and PlayerState.get_current_day() == 3)
	assert(PlayerState.energy == 4 and PlayerState.stage_round == 5)
	reader.free()

	character = _setup()
	PlayerState.energy = 0
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	reader = await host._reader(PlayerState.get_pending_story())
	await reader._run_story_action({"type": "selection_outcome", "outcome": "ride"})
	assert(SelectionStory.complete(reader.story_payload, SELECTION_SCENE) == SELECTION_SCENE)
	assert(PlayerState.energy == 0 and PlayerState.stage_round == 4 and PlayerState.get_current_time_of_day() == "noon")
	reader.free()

	character = _setup()
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	payload = PlayerState.get_pending_story()
	payload["replay"] = true
	payload["_selection_outcome"] = "ride"
	PlayerState.set_pending_memory_replay(payload)
	reader = load(STORY_SCENE).instantiate()
	host.get_tree().root.add_child(reader)
	await host.get_tree().create_timer(1.1).timeout
	await Actions.run(reader, {"type": "selection_outcome", "outcome": "skip"})
	Flow.run(reader, {"type": "selection_outcome", "outcome": "ride"})
	assert(SelectionStory.complete(reader.story_payload, SELECTION_SCENE) == SELECTION_SCENE)
	assert(PlayerState.energy == 5 and PlayerState.stage_round == 4 and PlayerState.get_current_time_of_day() == "noon")
	reader.free()
	PlayerState.clear_pending_memory_replay()


static func _test_saved_ride_handoff(host: Node) -> void:
	var character := _setup()
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	var reader = await host._reader(PlayerState.get_pending_story())
	await reader._run_story_action({"type": "selection_outcome", "outcome": "ride"})
	await reader._advance_story()
	await reader._finish_story()
	await host.get_tree().scene_changed
	var game = host.get_tree().current_scene
	game.set_process(false)
	assert(game.scene_file_path == "res://scenes/main.tscn")
	assert(PlayerState.pending_story.is_empty() and PlayerState.pending_trip_selection.is_empty())
	assert(PlayerState.resume_scene_path == "res://scenes/main.tscn")
	assert(PlayerState.energy == 4 and PlayerState.stage_round == 5)
	assert(PlayerState.current_mock_character_id == "jessa" and PlayerState.get_current_time_of_day() == "night")
	assert(not PlayerState.pending_stage_energy_cost, "Gameplay confirms the single prepared departure on entry")
	host.get_tree().current_scene = null
	game.free()
	reader.free()
	# Read the snapshot saved by the real handoff, without writing a new one.
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	PlayerState._begin_state_batch()
	PlayerState.energy = 1
	PlayerState.stage_round = 99
	PlayerState.pending_story = {"story_id": "unsaved_fixture"}
	PlayerState._end_state_batch(false, true)
	assert(PlayerState.get_meta("test_save_count", 0) == saves)
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	assert(PlayerState.pending_story.is_empty() and PlayerState.pending_trip_selection.is_empty())
	assert(PlayerState.energy == 4 and PlayerState.stage_round == 5 and not PlayerState.pending_stage_energy_cost)
	assert(PlayerState.resume_scene_path == "res://scenes/main.tscn")
	var resumed_game = load(PlayerState.resume_scene_path).instantiate()
	host.get_tree().root.add_child(resumed_game)
	resumed_game.set_process(false)
	assert(PlayerState.energy == 4 and PlayerState.stage_round == 5, "Continuing the saved ride cannot repeat departure costs or clock advancement")
	assert(PlayerState.pending_story.is_empty() and PlayerState.current_mock_character_id == "jessa")
	resumed_game.free()


static func _without_words(value):
	if value is Dictionary:
		var normalized: Dictionary = value.duplicate(true)
		for key in ["text", "chapter_title"]:
			normalized.erase(key)
		for key in normalized:
			normalized[key] = _without_words(normalized[key])
		return normalized
	if value is Array:
		var normalized: Array = []
		for item in value:
			normalized.append(_without_words(item))
		return normalized
	return value
