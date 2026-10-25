extends RefCounted

const Encounters := preload("res://scripts/ride_selection/midnight_encounters.gd")
const SpawnCatalog := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")
const TerminalChecks := preload("res://tests/terminal_spawn_checks.gd")
const Departure := preload("res://scripts/ride_selection/ride_departure.gd")
const PassengerStory := preload("res://scripts/ride_selection/passenger_story.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SOURCE := preload("res://assets/story/backgrounds/locations/terminalspawns/gardo_midnightspawn.png")
const REGION := Rect2(214, 396, 133, 161)
const STATION := "res://scenes/ride_selection.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_roll_gates_and_cache()
	await _test_encounter_ui(host)
	PlayerState.reset()
	print("PASS: Gardo midnight completed-ride gate, persistent per-date chance/dialogue cursor, exact four-line floating speech, fifth-click event hook once, revisit/save resume and no extra rides or progression effects")


static func _setup(midnight := true, rides := 1) -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time("night")
	PlayerState.stage_round = 3
	PlayerState.money = 1000
	PlayerState.energy = 5
	PlayerState.gas = 70
	PlayerState.character_completed_rides["gardo"] = rides
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE)
	if midnight:
		PlayerState.set_last_stage_result({"day": 3, "time_of_day": "night", "completed": true, "total": 0})


static func _test_roll_gates_and_cache() -> void:
	assert(is_equal_approx(Encounters.SPAWN_CHANCE, 0.35))
	_setup(true, 0)
	PlayerState.set_unique_character_progress("gardo", 10)
	var original := _snapshot()
	Encounters.prepare(PlayerState)
	assert(not Encounters.eligible(PlayerState) and Encounters.offers(PlayerState).is_empty())
	assert(_snapshot() == original, "Relationship progress alone cannot unlock Gardo's midnight encounter")
	_setup(false, 1)
	original = _snapshot()
	Encounters.prepare(PlayerState)
	assert(not Encounters.eligible(PlayerState) and Encounters.offers(PlayerState).is_empty())
	assert(_snapshot() == original, "Ordinary night cannot roll a midnight encounter")
	_setup()
	seed(77123)
	var expected_random := randf()
	seed(77123)
	var before_saves := int(PlayerState.get_meta("test_save_count", 0))
	Encounters.prepare(PlayerState)
	assert(randf() == expected_random, "Encounter chance must not consume gameplay RNG")
	var roll: Dictionary = PlayerState.get_event_value(Encounters.ROLL_EVENT, {})
	assert(roll.day == 3 and roll.present is bool)
	assert(int(PlayerState.get_meta("test_save_count", 0)) == before_saves + 1)
	original = _snapshot()
	Encounters.prepare(PlayerState)
	assert(_snapshot() == original, "Repeated preparation cannot reroll or resave the same night")
	for present in [false, true]:
		PlayerState.set_event_value(Encounters.ROLL_EVENT, {"day": 3, "present": present})
		original = _snapshot()
		var offers := Encounters.offers(PlayerState)
		assert(offers.size() == (1 if present else 0))
		if present:
			assert(Encounters.is_available(PlayerState, offers[0]))
			assert(offers[0].kind == "encounter" and offers[0].distance == "encounter" and offers[0].presentation == "midnight")
			var copy := offers[0].duplicate(true)
			copy.day = 2
			assert(not Encounters.is_available(PlayerState, copy))
			copy = offers[0].duplicate(true)
			copy.character.id = "hana"
			assert(not Encounters.is_available(PlayerState, copy))
		Encounters.prepare(PlayerState)
		assert(_snapshot() == original, "Hit and miss lookups are pure and remain stable during the night")
		var path := "res://test_user/gardo_midnight_%s.tres" % str(present)
		Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
		PlayerState.reset()
		assert(Codec.load_from_path(PlayerState, path))
		original = _snapshot()
		Encounters.prepare(PlayerState)
		assert(Encounters.offers(PlayerState).size() == (1 if present else 0) and _snapshot() == original)
	PlayerState.current_day = 4
	PlayerState.set_last_stage_result({"day": 4, "time_of_day": "night", "completed": true, "total": 0})
	assert(Encounters.offers(PlayerState).is_empty(), "Yesterday's cached presence cannot spawn Gardo tonight")
	before_saves = int(PlayerState.get_meta("test_save_count", 0))
	Encounters.prepare(PlayerState)
	assert(PlayerState.get_event_value(Encounters.ROLL_EVENT).day == 4)
	assert(int(PlayerState.get_event_value(Encounters.ROLL_EVENT).get("dialogue_index", 0)) == 0)
	assert(not bool(PlayerState.get_event_value(Encounters.ROLL_EVENT).get("event_requested", false)))
	assert(int(PlayerState.get_meta("test_save_count", 0)) == before_saves + 1)


static func _test_encounter_ui(host: Node) -> void:
	_setup()
	PlayerState.set_event_value(Encounters.ROLL_EVENT, {"day": 3, "present": true})
	var presentation := SpawnCatalog.midnight_entry("gardo")
	var atlas: AtlasTexture = presentation.texture
	assert(presentation.region == REGION and atlas.atlas == SOURCE and atlas.region == REGION)
	assert(atlas.get_size() == REGION.size)
	assert(atlas.get_image().get_data() == SOURCE.get_image().get_region(Rect2i(REGION)).get_data())
	assert(SpawnCatalog.entry("gardo", true).region == Rect2(355, 353, 171, 222), "The normal night passenger sprite must remain unchanged")
	assert(SpawnCatalog.midnight_entry("missing").is_empty())
	var station = load(STATION).instantiate()
	host.get_tree().root.add_child(station)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	station._open_passengers()
	assert(station.terminal_offers.size() == 1 and station.terminal_view.buttons.size() == 1)
	var offer: Dictionary = station.terminal_offers[0]
	assert(offer.kind == "encounter" and offer.encounter_id == Encounters.GARDO_ID)
	var button = station.terminal_view.buttons.gardo
	assert(not button.is_placeholder and button.source_region == REGION and TerminalChecks._has_opaque_target(button))
	var normal: Rect2 = station.terminal_view.sprite_rect_for("gardo")
	var hover: Rect2 = station.terminal_view.sprite_rect_for("gardo", true)
	assert(hover.size.is_equal_approx(normal.size * 1.06) and is_equal_approx(hover.end.y, normal.end.y))
	button.mouse_entered.emit()
	var card = station.terminal_view.info_panel
	assert(card.visible and card.badge_label.text == "ENCOUNTER")
	assert(not card.fare_label.is_visible_in_tree() and not card.fuel_label.is_visible_in_tree() and not card.risk_label.is_visible_in_tree())
	assert(not card.traffic_label.is_visible_in_tree())
	assert(card.route_label.text.contains("Midnight") or card.route_label.text.to_lower().contains("sitting alone"))
	var selected: Array[Array] = []
	station.midnight_encounter_selected.connect(func(encounter_id: String, character_id: String) -> void: selected.append([encounter_id, character_id]))
	var stale := offer.duplicate(true)
	stale.day = 2
	var original := _snapshot()
	assert(Encounters.interact(PlayerState, stale).is_empty() and _snapshot() == original, "A stale offer cannot advance dialogue or request an event")
	var lines := ["Go away.", "Leave me alone.", "Is there something wrong with you? Go away!", "..."]
	assert(Encounters.GARDO_LINES == lines)
	for index in range(lines.size()):
		button = station.terminal_view.buttons.gardo
		var before := _snapshot()
		button.pressed.emit()
		assert(not station.confirmation.visible and not station.is_departing)
		assert(station.hub_dialogue.is_active() and station.hub_dialogue.bubble.visible)
		assert(str(station.hub_dialogue.active_line.text) == lines[index])
		assert(station.hub_dialogue.active_line.character_id == "gardo" and not bool(station.hub_dialogue.active_line.typewriter))
		assert(station.hub_dialogue.bubble.body_label.text == lines[index])
		assert(selected.is_empty(), "The first four clicks only show Gardo's lines")
		_assert_dialogue_save(before, index + 1, false)
		before = _snapshot()
		if index < lines.size() - 1:
			station.hub_dialogue.clear()
			assert(_snapshot() == before, "Dismissing a balloon cannot advance the click sequence")
		if index == 1:
			station._close_passengers()
			station._open_passengers()
			assert(int(PlayerState.get_event_value(Encounters.ROLL_EVENT).dialogue_index) == 2)
			Codec.save_to_path(PlayerState, "res://test_user/gardo_dialogue_resume.tres", PlayerState.SAVE_VERSION)
			station.free()
			PlayerState.reset()
			assert(Codec.load_from_path(PlayerState, "res://test_user/gardo_dialogue_resume.tres"))
			station = load(STATION).instantiate()
			host.get_tree().root.add_child(station)
			await host.get_tree().process_frame
			station._open_passengers()
			station.midnight_encounter_selected.connect(func(encounter_id: String, character_id: String) -> void: selected.append([encounter_id, character_id]))
	button = station.terminal_view.buttons.gardo
	var before_event := _snapshot()
	button.pressed.emit()
	assert(selected == [[Encounters.GARDO_ID, "gardo"]])
	assert(not station.hub_dialogue.is_active() and not station.confirmation.visible and not station.is_departing)
	_assert_dialogue_save(before_event, 4, true)
	original = _snapshot()
	button.pressed.emit()
	assert(selected.size() == 1 and _snapshot() == original, "Sixth and later clicks cannot repeat the event request or save")
	assert(not PlayerState.are_passengers_available())
	assert(station.passenger_pool.roll() == {"short": [], "medium": [], "long": []})
	assert(Departure.start(offer.character, "short", PlayerState.TRANSITION_CURRENT_STAGE).scene.is_empty())
	assert(not PassengerStory.begin(offer.character, "short", PlayerState.TRANSITION_CURRENT_STAGE))
	station._depart_with_offer(offer)
	assert(not station.is_departing and _snapshot() == original)
	station._close_passengers()
	station._open_passengers()
	assert(station.terminal_offers.size() == 1 and station.terminal_view.buttons.has("gardo"))
	station.terminal_view.buttons.gardo.pressed.emit()
	assert(selected.size() == 1 and bool(PlayerState.get_event_value(Encounters.ROLL_EVENT).event_requested))
	station.free()
	# A cached miss remains an empty terminal on actual scene visits.
	PlayerState.set_event_value(Encounters.ROLL_EVENT, {"day": 3, "present": false})
	station = load(STATION).instantiate()
	host.get_tree().root.add_child(station)
	await host.get_tree().process_frame
	station._open_passengers()
	assert(station.terminal_offers.is_empty() and station.terminal_view.buttons.is_empty())
	station.free()


static func _assert_dialogue_save(before: Dictionary, index: int, event_requested: bool) -> void:
	var after := _snapshot()
	assert(int(after.saves) == int(before.saves) + 1, "Each valid progress click must persist exactly once")
	var roll: Dictionary = after.events[Encounters.ROLL_EVENT]
	assert(int(roll.dialogue_index) == index and bool(roll.get("event_requested", false)) == event_requested)
	after.events[Encounters.ROLL_EVENT] = before.events[Encounters.ROLL_EVENT].duplicate(true)
	after.saves = before.saves
	assert(after == before, "Only the encounter cursor/request changes; resources, time, seen state, story/ride state and other events remain intact")


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"progress": PlayerState.unique_character_progress.duplicate(true),
		"rides": PlayerState.character_completed_rides.duplicate(true),
		"events": PlayerState.event_values.duplicate(true),
		"seen": PlayerState.seen_mock_characters.duplicate(true),
		"consumed": PlayerState.consumed_story_triggers.duplicate(true),
		"story": PlayerState.get_pending_story(),
		"pending": PlayerState.get_pending_trip_selection(),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}
