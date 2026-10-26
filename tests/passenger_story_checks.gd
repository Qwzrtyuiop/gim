extends RefCounted

const SelectionStory := preload("res://scripts/ride_selection/passenger_story.gd")
const Payload := preload("res://scripts/story/story_payload.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const Actions := preload("res://scripts/story/story_action_runner.gd")
const ActionCatalog := preload("res://scripts/story/story_action_catalog.gd")
const Flow := preload("res://scripts/story/story_game_flow.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Availability := preload("res://scripts/story/character_availability.gd")
const PassengerPool := preload("res://scripts/ride_selection/passenger_pool.gd")
const SelectionView := preload("res://scripts/ride_selection/selection_view.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const CHOICE_EVENT := "jessa_second_encounter_choice"
const SEEN_EVENT := "jessa_second_encounter_seen"
const NAME_EVENT := "jessa_name_revealed"
const ABSENCE_EVENT := "jessa_second_encounter_absence"

class SelectionContext extends RefCounted:
	var mode := "ride"
	var selected_distance := "short"
	var locked_character_pools: Dictionary = {}

	func _transition_mode() -> String:
		return mode

	func _display_day() -> int:
		return PlayerState.get_transition_display_day(mode)

	func _is_forced_first_day_ride() -> bool:
		return false


static func run(host: Node) -> void:
	_test_eligibility_and_save()
	_test_rest_continuation()
	await _test_click_and_return(host)
	await _test_authored_branches(host)
	await _test_name_checkpoints(host)
	await _test_legacy_completion(host)
	await _test_authored_replay(host)
	_test_absence_guards()
	await _test_phase_absence(host)
	await _test_all_jessa_lock_repair(host)
	await _test_outcomes(host)
	await _test_saved_ride_handoff(host)
	PlayerState.reset()
	StoryLanguageManager.set_language("english")
	print("PASS: Jessa bilingual police/warning branches, warning-only name/checkpoints, legacy completion, live-phase absence across random/seeded/cached offers and reloads, unchanged resources/time, optional ride/skip, chaining and replay isolation")


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
	PlayerState.store_tutorial_shown = true
	PlayerState.set_event_value("jessa_runaway_fare_seen", true)
	PlayerState.set_pending_trip_selection("res://scenes/stage_results.tscn", mode, true)
	var character: Dictionary = PlayerState.get_character_by_id("jessa")
	character["active_distance"] = "short"
	character["stage_traffic"] = "traffic-jam"
	character["stage_special_type"] = PlayerState.STAGE_SPECIAL_TYPE_NONE
	character["special_stage_id"] = ""
	var generic := PlayerState.get_character_by_id("generic_guy")
	generic.merge({"active_distance": "short", "stage_traffic": "chill", "stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_NONE, "special_stage_id": ""}, true)
	PlayerState.lock_pending_trip_selection({
		"short": [character, {}, generic],
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
		assert(payload.composition.size() > 2 and payload.composition[0].next_index == 2, "New dialogue must bypass the preserved legacy completion section")
		assert(payload.composition[1].speaker == "Jessa" and payload.composition[1].text == "...")
		assert(_line_sets(payload.composition[1], SEEN_EVENT, true) and payload.composition[1].next_index == payload.composition.size())
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
	StoryLanguageManager.set_language("english")
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
	await _walk_to(host, reader, _completion_line(reader.story_payload, "police"), "police")
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
	assert(not returned.terminal_view.buttons.has("jessa") and returned.terminal_view.buttons.has("generic_guy"), "Jessa leaves for the current phase while other waiting passengers stay")
	assert(not SelectionStory.begin(PlayerState.get_character_by_id("jessa"), "short", PlayerState.TRANSITION_RIDE), "Her completed encounter cannot repeat")
	await _click_passenger(host, returned, "generic_guy")
	assert(returned.confirmation.visible and PlayerState.pending_story.is_empty())
	returned.confirmation.confirm_button.pressed.emit()
	assert(PlayerState.pending_story.is_empty(), "Other passengers retain ordinary ride entry checks")
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
	await _walk_to(host, reader, _completion_line(reader.story_payload, "police"), "police")
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


static func _test_authored_branches(host: Node) -> void:
	for language in ["english", "tagalog"]:
		for outcome in ["police", "warning"]:
			StoryLanguageManager.set_language(language)
			var character := _setup()
			PlayerState.energy = 0
			PlayerState.gas = 0
			PlayerState.set_pending_passengers_open(true)
			var offers := PlayerState.get_pending_trip_selection()
			var economy := _economy()
			assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
			var reader = await _authored_reader(host, PlayerState.get_pending_story())
			var payload: Dictionary = reader.story_payload
			var decision := _decision_line(payload)
			var reveal := _reveal_line(payload)
			assert(decision > 1 and reveal > decision)
			assert(_completion_line(payload, "police") != _completion_line(payload, "warning"), "Each branch owns its reached completion")
			await _walk_to(host, reader, decision, outcome)
			assert(reader.choice_buttons.size() == 2 and reader.choice_container.visible)
			assert(not PlayerState.get_event_value(SEEN_EVENT, false) and not PlayerState.get_event_value(NAME_EVENT, false))
			assert(PlayerState.get_character_display_name("jessa") == "???")
			await _walk_to(host, reader, _completion_line(payload, outcome), outcome)
			assert(PlayerState.get_event_value(CHOICE_EVENT) == outcome)
			assert(PlayerState.get_event_value(SEEN_EVENT, false))
			assert(bool(PlayerState.get_event_value(NAME_EVENT, false)) == (outcome == "warning"))
			assert(PlayerState.get_character_display_name("jessa") == ("Jessa" if outcome == "warning" else "???"))
			assert(_economy() == economy and PlayerState.get_pending_trip_selection() == offers)
			await _finish_to_selection(host, reader, offers, economy)
	StoryLanguageManager.set_language("english")


static func _test_name_checkpoints(host: Node) -> void:
	for language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(language)
		var character := _setup()
		PlayerState.set_pending_passengers_open(true)
		var offers := PlayerState.get_pending_trip_selection()
		var economy := _economy()
		assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
		var reader = await _authored_reader(host, PlayerState.get_pending_story())
		var reveal := _reveal_line(reader.story_payload)
		await _walk_to(host, reader, reveal - 1, "warning")
		assert(PlayerState.get_event_value(CHOICE_EVENT) == "warning")
		assert(not PlayerState.get_event_value(NAME_EVENT, false) and not PlayerState.get_event_value(SEEN_EVENT, false), "Neither selecting Warning nor preceding dialogue reveals her name")
		reader = await _reload(host, reader, "jessa_before_name_" + language)
		assert(reader.current_line_index == reveal - 1 and PlayerState.get_character_display_name("jessa") == "???")
		await _walk_to(host, reader, reveal, "warning")
		assert(PlayerState.get_event_value(NAME_EVENT, false) and not PlayerState.get_event_value(SEEN_EVENT, false))
		assert(PlayerState.get_character_display_name("jessa") == "Jessa")
		assert(reader.speaker_label.text == "???", "Her introduction retains the pre-reveal authored label until she has spoken her name")
		if language == "english":
			assert(reader.body_label.text == "Jessa. Just Jessa.")
		reader = await _reload(host, reader, "jessa_after_name_" + language)
		assert(reader.current_line_index == reveal and reader.speaker_label.text == "???")
		assert(PlayerState.get_event_value(NAME_EVENT, false) and not PlayerState.get_event_value(SEEN_EVENT, false), "Resuming the name line cannot prematurely complete the event")
		assert(PlayerState.get_event_value(CHOICE_EVENT) == "warning")
		assert(_economy() == economy and PlayerState.get_pending_trip_selection() == offers)
		var next_jessa := reveal + 1
		while next_jessa < reader.story_lines.size() and str(reader.story_lines[next_jessa].get("speaker", "")) != "Jessa":
			next_jessa += 1
		assert(next_jessa < reader.story_lines.size())
		await _walk_to(host, reader, next_jessa, "warning")
		assert(reader.speaker_label.text == "JESSA", "Following dialogue uses her revealed name")
		await _walk_to(host, reader, _completion_line(reader.story_payload, "warning"), "warning")
		assert(PlayerState.get_event_value(SEEN_EVENT, false))
		reader = await _reload(host, reader, "jessa_completed_" + language)
		assert(PlayerState.get_event_value(SEEN_EVENT, false) and PlayerState.get_event_value(NAME_EVENT, false))
		await _finish_to_selection(host, reader, offers, economy)
	StoryLanguageManager.set_language("english")


static func _test_legacy_completion(host: Node) -> void:
	for language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(language)
		var character := _setup()
		assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
		PlayerState.set_last_seen_story_section("jessa_second_encounter", 1)
		var economy := _economy()
		var reader = await _authored_reader(host, PlayerState.get_pending_story())
		assert(reader.current_line_index == 1 and reader.body_label.text == "...")
		assert(PlayerState.get_event_value(SEEN_EVENT, false) and not PlayerState.get_event_value(NAME_EVENT, false))
		assert(not PlayerState.has_event_value(CHOICE_EVENT) and _economy() == economy, "An old section-one save completes its original scaffold without inventing a branch or a name")
		reader.free()
	StoryLanguageManager.set_language("english")


static func _test_authored_replay(host: Node) -> void:
	for language in ["english", "tagalog"]:
		for outcome in ["police", "warning"]:
			StoryLanguageManager.set_language(language)
			_setup()
			var live := Payload.normalize({"story_id": "passenger_live_fixture", "composition": [{"text": "Live progress"}]})
			PlayerState.set_pending_story(live)
			PlayerState.set_resume_scene(STORY_SCENE)
			var economy := _economy()
			var events := PlayerState.get_event_values()
			var replay := PayloadCatalog.build("jessa_second_encounter")
			replay["replay"] = true
			var reader = await _authored_reader(host, replay)
			assert(reader._is_replay_mode())
			await _walk_to(host, reader, _completion_line(replay, outcome), outcome)
			assert(PlayerState.get_event_values() == events and PlayerState.pending_story == live)
			assert(_economy() == economy and PlayerState.get_character_display_name("jessa") == "???", "Memory choices and introductions cannot persist branch/name/completion flags")
			reader.free()
			assert(PlayerState.pending_memory_replay.is_empty() and PlayerState.pending_story == live)
	StoryLanguageManager.set_language("english")


static func _test_absence_guards() -> void:
	var character := _setup()
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	var unfinished := PlayerState.get_pending_story()
	assert(SelectionStory.complete(unfinished, SELECTION_SCENE) == SELECTION_SCENE)
	assert(not PlayerState.has_event_value(ABSENCE_EVENT), "Leaving an unfinished encounter cannot start Jessa's absence")
	var replay := PlayerState.get_pending_story()
	replay["replay"] = true
	PlayerState.set_event_value(SEEN_EVENT, true)
	assert(SelectionStory.complete(replay, SELECTION_SCENE) == SELECTION_SCENE)
	assert(not PlayerState.has_event_value(ABSENCE_EVENT), "Replaying a previously completed encounter cannot start an absence")


static func _test_phase_absence(host: Node) -> void:
	var character := _setup()
	PlayerState.set_pending_passengers_open(true)
	var pools := PlayerState.get_locked_pending_trip_character_pools()
	var economy := _economy()
	assert(PlayerState.get_current_time_of_day() == "noon" and PlayerState.get_next_stage_time(PlayerState.TRANSITION_RIDE) == "night")
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	var completed := PlayerState.get_pending_story()
	PlayerState.set_event_value(SEEN_EVENT, true)
	assert(SelectionStory.complete(completed, SELECTION_SCENE) == SELECTION_SCENE)
	PlayerState.clear_pending_story()
	var absence := {"day": 3, "phase": "noon"}
	assert(PlayerState.get_event_value(ABSENCE_EVENT) == absence, "Absence uses live Noon, not the selected ride's projected Night")
	var current := PlayerState.get_character_by_id("jessa")
	assert(current.get("unavailable_now", false) and not Availability.supports_time(current, "night", 3))
	var context := SelectionContext.new()
	context.locked_character_pools = pools
	var visible := SelectionView.new(context).offers()
	assert(visible.size() == 1 and visible[0].character.id == "generic_guy")
	PlayerState.seed_rider_for_stage("jessa", 3, "night", "short", 0, "chill", true)
	var rules: Array = PlayerState.get_seeded_rider_rules()
	var seed_id := str(rules.back().id)
	assert(not PlayerState.get_seeded_rider_pool_setup({"day": 3, "time_of_day": "night"}).rule_ids.has(seed_id), "The same live-phase absence blocks scripted riders too")
	var fresh := PassengerPool.new(context).roll()
	for cards: Array in fresh.values():
		for rider: Dictionary in cards:
			assert(rider.is_empty() or rider.id != "jessa", "Fresh random offers cannot bring her back in the same live phase")
	assert(not PlayerState.consumed_seeded_rider_rules.get(seed_id, false))
	assert(PlayerState.get_locked_pending_trip_character_pools() == pools and _economy() == economy)
	var station = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(station)
	await host.get_tree().process_frame
	_assert_phase_absence(station, pools, absence)
	station._open_store()
	await host.get_tree().scene_changed
	await host.get_tree().process_frame
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == "res://scenes/store.tscn")
	station.free()
	store._ride()
	await host.get_tree().scene_changed
	await host.get_tree().process_frame
	station = host.get_tree().current_scene
	_assert_phase_absence(station, pools, absence)
	var path := "res://test_user/jessa_phase_absence.tres"
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	host.get_tree().current_scene = null
	station.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, path))
	station = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(station)
	await host.get_tree().process_frame
	_assert_phase_absence(station, pools, absence)
	assert(_economy() == economy and not PlayerState.consumed_seeded_rider_rules.get(seed_id, false))
	station.free()
	PlayerState.set_current_stage_time("night")
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE)
	context.mode = PlayerState.TRANSITION_CURRENT_STAGE
	current = PlayerState.get_character_by_id("jessa")
	assert(not current.get("unavailable_now", false) and Availability.supports_time(current, "night", 3), "The next live phase restores her normal night schedule")
	assert(SelectionView.new(context).offers().size() == 2)
	assert(PlayerState.get_seeded_rider_pool_setup({"day": 3, "time_of_day": "night"}).rule_ids.has(seed_id))
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	assert(SelectionStory.complete(completed, SELECTION_SCENE) == SELECTION_SCENE)
	assert(PlayerState.get_event_value(ABSENCE_EVENT) == absence and int(PlayerState.get_meta("test_save_count", 0)) == saves, "Repeating a completed handoff cannot renew the absence timestamp")
	PlayerState.prepare_day_start(4)
	PlayerState.set_current_stage_time("noon")
	assert(not PlayerState.get_character_by_id("jessa").get("unavailable_now", false), "The same phase on another date cannot inherit yesterday's absence")


static func _test_all_jessa_lock_repair(host: Node) -> void:
	var character := _setup()
	assert(SelectionStory.begin(character, "short", PlayerState.TRANSITION_RIDE))
	var payload := PlayerState.get_pending_story()
	PlayerState.set_event_value(SEEN_EVENT, true)
	assert(SelectionStory.complete(payload, SELECTION_SCENE) == SELECTION_SCENE)
	PlayerState.clear_pending_story()
	var only_jessa := {"short": [character, {}, {}], "medium": [{}, {}, {}], "long": [{}, {}, {}]}
	PlayerState.lock_pending_trip_selection(only_jessa, "short")
	var economy := _economy()
	var station = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(station)
	await host.get_tree().process_frame
	assert(station.terminal_offers.size() >= 2 and not station.terminal_view.buttons.has("jessa"), "An unusable old all-Jessa lock repairs to eligible passengers without reviving her")
	assert(PlayerState.get_locked_pending_trip_character_pools() != only_jessa and _economy() == economy)
	assert(PlayerState.get_event_value(ABSENCE_EVENT) == {"day": 3, "phase": "noon"})
	station.free()


static func _assert_phase_absence(station, pools: Dictionary, absence: Dictionary) -> void:
	assert(station.locked_character_pools == pools and PlayerState.get_locked_pending_trip_character_pools() == pools, "Filtering Jessa cannot alter the remaining locked lineup")
	assert(station.terminal_offers.size() == 1 and station.terminal_view.buttons.has("generic_guy") and not station.terminal_view.buttons.has("jessa"))
	assert(PlayerState.get_event_value(ABSENCE_EVENT) == absence, "Hub visits and reloads cannot renew the absence timestamp")


static func _authored_reader(host: Node, payload: Dictionary):
	# The real passenger-click test retains normal presentation timing. Branch
	# and checkpoint checks need the authored routing rather than repeated fades.
	var fast_payload := payload.duplicate(true)
	fast_payload["music_fade_in"] = 0.0
	fast_payload["music_fade_out"] = 0.0
	if bool(fast_payload.get("replay", false)):
		PlayerState.set_pending_memory_replay(fast_payload)
	else:
		PlayerState.set_pending_story(fast_payload)
	var reader = load(STORY_SCENE).instantiate()
	host.get_tree().root.add_child(reader)
	var deadline := Time.get_ticks_msec() + 5000
	while reader.current_line_index < 0 or reader.is_input_locked:
		assert(Time.get_ticks_msec() < deadline, "The isolated authored reader must become ready")
		await host.get_tree().create_timer(0.01).timeout
	return reader


static func _walk_to(host: Node, reader, target: int, outcome: String) -> void:
	for _step in range(reader.story_lines.size() + 2):
		if reader.current_line_index == target:
			return
		var line: Dictionary = reader._current_line()
		if not Array(line.get("choices", [])).is_empty():
			await reader._choose_branch(_choice(line, outcome))
		else:
			await reader._advance_story()
		for _frame in range(180):
			if not reader.is_input_locked:
				break
			await host.get_tree().process_frame
		assert(not reader.is_input_locked and not reader.is_finishing_story, "The selected route must reach its authored endpoint before scene completion")
	assert(false, "The authored route did not reach its expected section")


static func _decision_line(payload: Dictionary) -> int:
	for index in range(payload.composition.size()):
		var line: Dictionary = payload.composition[index]
		if not Array(line.get("choices", [])).is_empty():
			return index
	assert(false, "Jessa's encounter must contain its police/warning decision")
	return -1


static func _choice(line: Dictionary, outcome: String) -> Dictionary:
	for choice: Dictionary in line.get("choices", []):
		if _line_sets(choice, CHOICE_EVENT, outcome):
			return choice
	assert(false, "The requested authored branch must record its stable choice value")
	return {}


static func _completion_line(payload: Dictionary, outcome: String) -> int:
	var decision := _decision_line(payload)
	var index := int(_choice(payload.composition[decision], outcome).next_index)
	for _step in range(payload.composition.size()):
		assert(index > 1 and index < payload.composition.size(), "New branches cannot fall through the old scaffold completion")
		var line: Dictionary = payload.composition[index]
		if _line_sets(line, SEEN_EVENT, true):
			assert(int(line.get("next_index", -1)) == payload.composition.size(), "Each branch's final authored line ends the story")
			return index
		index = int(line.get("next_index", index + 1))
	assert(false, "Both authored branches must complete the encounter")
	return -1


static func _reveal_line(payload: Dictionary) -> int:
	var reveal := -1
	for index in range(payload.composition.size()):
		if _line_sets(payload.composition[index], NAME_EVENT, true):
			assert(reveal == -1, "Only the spoken introduction may reveal Jessa's name")
			reveal = index
	assert(reveal > 1)
	return reveal


static func _line_sets(line: Dictionary, event_id: String, value: Variant) -> bool:
	for action: Dictionary in line.get("actions", []):
		if action.get("type") == "set_event_value" and action.get("id") == event_id and action.get("value") == value:
			return true
	return false


static func _reload(host: Node, reader, name: String):
	var index: int = reader.current_line_index
	var text: String = reader.body_label.text
	var speaker: String = reader.speaker_label.text
	var pending := PlayerState.get_pending_story()
	assert(int(pending._checkpoint.line_index) == index)
	var path := "res://test_user/%s.tres" % name
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	reader.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, path))
	var resumed = await _authored_reader(host, PlayerState.get_pending_story())
	assert(resumed.current_line_index == index and resumed.body_label.text == text and resumed.speaker_label.text == speaker, "Reload restores the reached authored line and speaker")
	return resumed


static func _finish_to_selection(host: Node, reader, offers: Dictionary, economy: Dictionary) -> void:
	await reader._advance_story()
	await host.get_tree().scene_changed
	await host.get_tree().process_frame
	var returned = host.get_tree().current_scene
	assert(returned.scene_file_path == SELECTION_SCENE and returned.passenger_overlay.visible)
	assert(PlayerState.pending_story.is_empty() and PlayerState.get_pending_trip_selection() == offers)
	assert(returned.locked_character_pools == offers.locked_character_pools and _economy() == economy, "Both branches return to the same offers without a ride cost, recovery or time change")
	assert(not returned.terminal_view.buttons.has("jessa") and returned.terminal_view.buttons.has("generic_guy"))
	assert(PlayerState.get_event_value(ABSENCE_EVENT) == {"day": economy.day, "phase": economy.phase}, "Either completed branch records the conversation's live phase")
	host.get_tree().current_scene = null
	returned.free()
	reader.free()


static func _economy() -> Dictionary:
	return {"money": PlayerState.money, "energy": PlayerState.energy, "gas": PlayerState.gas, "day": PlayerState.current_day, "phase": PlayerState.current_phase, "round": PlayerState.stage_round, "rests": PlayerState.rests_taken_today, "progress": PlayerState.get_unique_character_progress("jessa"), "rides": PlayerState.character_completed_rides.duplicate(true)}


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
