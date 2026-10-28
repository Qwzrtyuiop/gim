extends RefCounted

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Context := preload("res://scripts/save/save_game_context.gd")
const Catalog := preload("res://scripts/story/story_payload_catalog.gd")
const Church := preload("res://scripts/home/church_prayer_encounter.gd")
const Park := preload("res://scripts/home/park_visit_encounter.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STORY := "res://scenes/story_scene.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_daily_ledger()
	await _test_cancel_failure_and_reopening(host)
	await _test_ordered_scenes_and_perk(host)
	await _test_random_scene_slot_resume(host)
	await _test_memory_isolation(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: independent daily Park/Church claims, cancelled/exhausted/reopened visits, persisted counters and older-save defaults, ordered first five and random later scenes, fifth-prayer Makadiyos and future relief, actual inline slot resume and memory isolation")


static func _test_daily_ledger() -> void:
	PlayerState.reset()
	PlayerState.current_day = 8
	var resources := _resources()
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	assert(not PlayerState.has_visited_location_today("park") and not PlayerState.has_visited_location_today("church"))
	assert(PlayerState.record_location_visit("park") == 1)
	assert(PlayerState.record_location_visit("church") == 1)
	assert(PlayerState.has_visited_location_today("park") and PlayerState.has_visited_location_today("church"))
	assert(int(PlayerState.get_meta("test_save_count", 0)) == saves + 2, "Each complete daily claim saves once")
	assert(_resources() == resources, "The ledger cannot charge energy or alter resources itself")
	var events := PlayerState.get_event_values()
	saves = int(PlayerState.get_meta("test_save_count", 0))
	for location in ["park", "church", "hospital", ""]:
		assert(PlayerState.record_location_visit(location) == 0)
	assert(PlayerState.get_event_values() == events and int(PlayerState.get_meta("test_save_count", 0)) == saves)
	PlayerState.current_phase = "night"
	PlayerState.set_event_value("night_phase_consumed_day", 8)
	assert(PlayerState.is_midnight() and PlayerState.has_visited_location_today("church"), "Midnight is part of the same visit day")
	var saved := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	PlayerState.reset()
	assert(Codec.load_snapshot(PlayerState, saved))
	assert(PlayerState.has_visited_location_today("park") and PlayerState.has_visited_location_today("church"))
	assert(int(PlayerState.get_event_value("church_visit_count", 0)) == 1 and int(PlayerState.get_event_value("park_visit_count", 0)) == 1)
	PlayerState.current_day = 9
	assert(not PlayerState.has_visited_location_today("park"))
	assert(PlayerState.record_location_visit("park") == 2 and PlayerState.record_location_visit("church") == 2)
	PlayerState.current_day = 10
	PlayerState.set_event_value("park_visit_count", -100)
	assert(PlayerState.record_location_visit("park") == 1, "Invalid negative hidden counts recover without producing a negative scene index")
	PlayerState.set_pending_memory_replay({"story_id": "visit_memory_fixture", "replay": true})
	events = PlayerState.get_event_values()
	saves = int(PlayerState.get_meta("test_save_count", 0))
	assert(PlayerState.record_location_visit("church") == 0)
	assert(PlayerState.get_event_values() == events and int(PlayerState.get_meta("test_save_count", 0)) == saves)
	PlayerState.clear_pending_memory_replay()
	var legacy := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	legacy.version = 4
	legacy.data.event_values.erase("daily_location_visit_days")
	legacy.data.event_values.erase("park_visit_count")
	legacy.data.event_values["church_visit_count"] = 4
	assert(Codec.load_snapshot(PlayerState, legacy))
	assert(not PlayerState.has_visited_location_today("church") and not PlayerState.has_visited_location_today("park"))
	assert(Church.record_visit() == "church_prayer_visit_5", "Older saves retain their existing prayer count without an invented daily claim")
	assert(Park.record_visit() == "park_visit_1")
	PlayerState.reset()
	assert(PlayerState.get_event_value("daily_location_visit_days", {}).is_empty())
	assert(int(PlayerState.get_event_value("church_visit_count", 0)) == 0 and int(PlayerState.get_event_value("park_visit_count", 0)) == 0)


static func _home(host: Node):
	PlayerState.reset()
	PlayerState.clear_story_triggers()
	PlayerState.current_day = 8
	PlayerState.current_phase = "morning"
	PlayerState.current_stage_type = "short-morning-chill"
	PlayerState.current_weather = "clear"
	PlayerState.daily_conditions_day = 8
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.set_event_value("north_road_open_announced", true)
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)
	var home = load(HOME).instantiate()
	host.get_tree().root.add_child(home)
	host.get_tree().current_scene = home
	await _settle(host)
	home._open_map()
	await _settle(host)
	return home


static func _test_cancel_failure_and_reopening(host: Node) -> void:
	var home = await _home(host)
	var world = home.home_map
	PlayerState.stress = 1
	var resources := _resources()
	var events := PlayerState.get_event_values()
	world._request_visit("park")
	assert(world.travel_confirmation.visible)
	world._cancel_travel()
	assert(_resources() == resources and PlayerState.get_event_values() == events)
	PlayerState.energy = 0
	world._request_visit("park")
	assert(not world.hub_story_overlay.active and not PlayerState.has_visited_location_today("park"))
	assert(int(PlayerState.get_event_value("park_visit_count", 0)) == 0 and PlayerState.stress == 1)
	PlayerState.energy = 1
	world._request_visit("park")
	world._confirm_travel()
	assert(world.hub_story_overlay.active and PlayerState.energy == 0 and PlayerState.stress == 0, "Actual paid relief clamps at zero")
	await finish_overlay(host, world)
	resources = _resources()
	events = PlayerState.get_event_values()
	world._show_map()
	world._visit("park")
	assert(not world.hub_story_overlay.active and _resources() == resources and PlayerState.get_event_values() == events, "Reopening the same park cannot consume another visit or start another scene")
	world._show_map()
	world.map_view.set_map_region("north")
	world._visit("school")
	world._show_map()
	world.map_view.set_map_region("town")
	world._request_visit("park")
	assert(world.map_view.visible and not world.travel_confirmation.visible and not world.hub_story_overlay.active)
	assert(str(world.hub_dialogue.active_line.get("text", "")).contains("tomorrow"))
	assert(_resources() == resources and PlayerState.get_event_values() == events, "Returning from another destination is blocked for the same day before any energy or relief")
	await _discard(host, home)


static func _test_ordered_scenes_and_perk(host: Node) -> void:
	var home = await _home(host)
	var world = home.home_map
	for visit in range(1, 7):
		PlayerState.current_day = 7 + visit
		PlayerState.daily_conditions_day = PlayerState.current_day
		PlayerState.energy = PlayerState.max_energy
		PlayerState.stress = 10
		world._show_map()
		world.map_view.set_map_region("north")
		world._visit("church")
		assert(world.hub_story_overlay.active)
		var story_id: String = PlayerState.get_pending_story().get("story_id", "")
		if visit <= 5:
			assert(story_id == "church_prayer_visit_%d" % visit)
		else:
			assert(story_id.begins_with("church_prayer_short_") and int(story_id.get_slice("_", 3)) in range(1, 6))
		assert(PlayerState.stress == (7 if visit == 6 else 8), "Makadiyos changes subsequent church relief from two to three")
		await finish_overlay(host, world)
		assert(PlayerState.has_achievement("makadiyos") == (visit >= 5), "Makadiyos unlocks on the fifth completed prayer")
		assert(PlayerState.energy == PlayerState.max_energy - 1 and PlayerState.current_day == 7 + visit and PlayerState.current_phase == "morning")
		assert(world.church_audio.active and world.church_audio.ambience_player.playing)
		world._show_map()
		world.map_view.set_map_region("town")
		world._visit("park")
		assert(world.hub_story_overlay.active)
		story_id = PlayerState.get_pending_story().get("story_id", "")
		if visit <= 5:
			assert(story_id == "park_visit_%d" % visit)
		else:
			assert(story_id.begins_with("park_short_") and int(story_id.get_slice("_", 2)) in range(1, 6))
		await finish_overlay(host, world)
		assert(PlayerState.energy == PlayerState.max_energy - 2)
		assert(int(PlayerState.get_event_value("church_visit_count", 0)) == visit and int(PlayerState.get_event_value("park_visit_count", 0)) == visit)
	assert(PlayerState.max_energy == 5 and PlayerState.max_stress == 10, "Makadiyos changes its church perk without granting capacity bonuses")
	await _discard(host, home)


static func _test_random_scene_slot_resume(host: Node) -> void:
	await _test_saved_visit(host, "park")
	await _test_saved_visit(host, "church")


static func _test_saved_visit(host: Node, location_id: String) -> void:
	var home = await _home(host)
	var world = home.home_map
	var count_event := "%s_visit_count" % location_id
	PlayerState.set_event_value(count_event, 5)
	PlayerState.stress = 7
	if location_id == "church":
		world.map_view.set_map_region("north")
	world._visit(location_id)
	await _ready_reader(host, world.hub_story_overlay.reader)
	var selected_id: String = PlayerState.get_pending_story().get("story_id", "")
	assert(selected_id.begins_with("park_short_" if location_id == "park" else "church_prayer_short_"))
	var resources := _resources()
	var visits: Dictionary = PlayerState.get_event_value("daily_location_visit_days", {}).duplicate(true)
	assert(SaveSlotManager.save_slot(9, Context.capture(home)) == OK)
	Context.prepare_scene_for_load(home)
	await _discard(host, home)
	assert(SaveSlotManager.load_slot(9))
	assert(PlayerState.get_pending_story().get("story_id", "") == selected_id and int(PlayerState.get_event_value(count_event, 0)) == 6)
	var destinations: Array[String] = []
	var reader = load(STORY).instantiate()
	reader.inline_complete_callback = func(path: String) -> void: destinations.append(path)
	host.get_tree().root.add_child(reader)
	host.get_tree().current_scene = reader
	await _ready_reader(host, reader)
	await _finish_reader(host, reader, destinations)
	assert(destinations == [HOME])
	await _discard(host, reader)
	home = load(HOME).instantiate()
	host.get_tree().root.add_child(home)
	host.get_tree().current_scene = home
	await _settle(host)
	world = home.home_map
	assert(world.visible and world.location_view.visible and world.current_location == location_id)
	assert(not world.hub_story_overlay.active and PlayerState.get_pending_story().is_empty())
	assert(_resources() == resources and PlayerState.get_event_value("daily_location_visit_days", {}) == visits, "Completing and restoring a saved random visit cannot reroll, charge energy, relieve stress or count twice")
	assert(int(PlayerState.get_event_value(count_event, 0)) == 6)
	await _discard(host, home)


static func _test_memory_isolation(host: Node) -> void:
	PlayerState.reset()
	var payload := Catalog.build("church_prayer_visit_5")
	payload["replay"] = true
	PlayerState.set_pending_memory_replay(payload)
	var events := PlayerState.get_event_values()
	var resources := _resources()
	var destinations: Array[String] = []
	var reader = load(STORY).instantiate()
	reader.inline_complete_callback = func(path: String) -> void: destinations.append(path)
	host.get_tree().root.add_child(reader)
	host.get_tree().current_scene = reader
	await _ready_reader(host, reader)
	await _finish_reader(host, reader, destinations)
	assert(not PlayerState.has_achievement("makadiyos") and PlayerState.get_event_values() == events and _resources() == resources, "Replaying the fifth prayer cannot unlock its achievement or alter visits/resources")
	await _discard(host, reader)


static func finish_overlay(host: Node, world) -> void:
	for _frame in range(400):
		if not world.hub_story_overlay.active:
			await _settle(host)
			return
		var reader = world.hub_story_overlay.reader
		if is_instance_valid(reader) and not reader.is_input_locked and not reader.is_finishing_story:
			reader._advance_story()
		await host.get_tree().create_timer(0.01).timeout
	assert(false, "A short non-choice location story must finish and restore map controls")


static func _ready_reader(host: Node, reader) -> void:
	for _frame in range(120):
		if reader.current_line_index >= 0 and not reader.is_input_locked:
			return
		await host.get_tree().create_timer(0.01).timeout
	assert(false, "The location reader must finish its intro")


static func _finish_reader(host: Node, reader, destinations: Array[String]) -> void:
	for _frame in range(400):
		if not destinations.is_empty():
			return
		if not reader.is_input_locked and not reader.is_finishing_story:
			reader._advance_story()
		await host.get_tree().create_timer(0.01).timeout
	assert(false, "A saved or replayed location reader must finish")


static func _resources() -> Dictionary:
	return {
		"energy": PlayerState.energy,
		"stress": PlayerState.stress,
		"hull": PlayerState.hull,
		"gas": PlayerState.gas,
		"money": PlayerState.money,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
	}


static func _discard(host: Node, scene: Node) -> void:
	host.get_tree().current_scene = null
	scene.free()
	await _settle(host)
	assert(PlayerState._state_batch_depth == 0 and not PlayerState._suppress_auto_save)


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
