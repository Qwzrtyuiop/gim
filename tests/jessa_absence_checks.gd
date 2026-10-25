extends RefCounted

const Catalog := preload("res://scripts/story/story_catalog.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const Economy := preload("res://scripts/game/game_economy_manager.gd")
const FareEvent := preload("res://scripts/story/jessa_fare_event.gd")
const PassengerPool := preload("res://scripts/ride_selection/passenger_pool.gd")
const Seeded := preload("res://scripts/seeded_rider_runtime.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"

class SelectionContext extends RefCounted:
	var mode := "current_stage"

	func _transition_mode() -> String:
		return mode


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	var previous_language := StoryLanguageManager.get_language()
	for language in ["english", "tagalog"]:
		for daytime in ["morning", "noon"]:
			for branch in [0, 1]:
				await _test_authored_completion(host, language, daytime, branch)
	_test_history_compatibility()
	await _test_locked_offers_and_resume(host)
	await _test_replay_isolation(host)
	PlayerState.reset()
	StoryLanguageManager.set_language(previous_language)
	print("PASS: Jessa first-event same-day absence in both languages/branches, later-night return, projected and seeded availability, saved locks/history and replay isolation")


static func _prepare_first_ride(daytime: String) -> Dictionary:
	PlayerState.reset()
	PlayerState.money = 500
	PlayerState.current_day = 3
	PlayerState.stage_round = 4
	# This Day 3 fixture has already resolved the higher-priority station bill.
	PlayerState.set_event_value("day_2_station_bill", true)
	PlayerState.set_current_mock_character("jessa")
	PlayerState.set_current_stage_time(daytime)
	var stage := "short-%s-normal" % daytime
	Economy.store_stage_result(stage, "short", daytime, "normal", "", "", 200, 200, 1, 0, 0, 10, 2, 0)
	var payload := Economy.stage_complete_story_payload(stage, "short", daytime, "normal")
	assert(payload.story_id == "jessa_runaway_fare")
	assert(PlayerState.event_values[FareEvent.EARNINGS_KEY].day == 3)
	assert(not bool(PlayerState.event_values.get("jessa_runaway_fare_seen", false)))
	assert(int(Catalog.get_character_by_id(PlayerState, "jessa").get("unavailable_day", 0)) == 0, "Preparing a fare cannot complete Jessa's story")
	return payload


static func _test_authored_completion(host: Node, language: String, daytime: String, branch: int) -> void:
	StoryLanguageManager.set_language(language)
	var payload := _prepare_first_ride(daytime)
	var history: Dictionary = PlayerState.event_values[FareEvent.EARNINGS_KEY].duplicate(true)
	var reader = await host._reader(payload)
	await reader._show_line(16)
	await reader._choose_branch(reader.story_lines[16].choices[branch])
	assert(not bool(PlayerState.event_values.get("jessa_runaway_fare_seen", false)))
	var ending := 24 if branch == 0 else 30
	await reader._show_line(ending)
	assert(bool(PlayerState.event_values.get("jessa_runaway_fare_seen", false)))
	assert(PlayerState.event_values[FareEvent.EARNINGS_KEY] == history)
	assert(PlayerState.money == 500 and PlayerState.last_stage_result.total == 0)
	if language == "english" and daytime == "noon" and branch == 1:
		Codec.save_to_path(PlayerState, "res://test_user/jessa_absence_checkpoint.tres", PlayerState.SAVE_VERSION)
		reader.free()
		PlayerState.reset()
		assert(Codec.load_from_path(PlayerState, "res://test_user/jessa_absence_checkpoint.tres"))
		reader = await host._reader(PlayerState.get_pending_story())
		assert(reader.current_line_index == ending)
		FareEvent.prepare(PlayerState, reader.story_payload)
		assert(PlayerState.event_values[FareEvent.EARNINGS_KEY] == history, "Checkpoint reload cannot move the historical encounter date or forfeit fare twice")
		assert(PlayerState.money == 500 and PlayerState.last_stage_result.total == 0)
	reader.free()
	_assert_day_and_seeded_availability()


static func _assert_day_and_seeded_availability() -> void:
	var selection := SelectionContext.new()
	var pool := PassengerPool.new(selection)
	var used_ids: Dictionary = {}
	for character: Dictionary in PlayerState.get_mock_characters():
		if character.id != "jessa":
			used_ids[character.id] = true
	PlayerState.set_current_stage_time("night")
	var jessa := Catalog.get_character_by_id(PlayerState, "jessa")
	assert(jessa.eligible_times == ["night"] and int(jessa.unavailable_day) == 3)
	assert(pool._pick_character_for_distance("short", used_ids, {"jessa": true}, true).is_empty(), "Jessa cannot return on the first encounter's night")
	assert(not Seeded.supports_character_time(PlayerState, jessa, "night", 3))
	assert(Seeded.supports_character_time(PlayerState, jessa, "night", 4), "Projected future-day eligibility cannot depend only on the live day")
	Seeded.add_rule(PlayerState, {"id": "jessa_absence_seed", "character_id": "jessa", "distance": "short", "min_day": 3, "repeatable": true})
	var blocked_setup := PlayerState.get_seeded_rider_pool_setup({"day": 3, "time_of_day": "night"})
	assert(not _has_seeded_jessa(blocked_setup) and blocked_setup.rule_ids.is_empty(), "Blocked same-day seeds cannot consume their rule")
	var next_setup := PlayerState.get_seeded_rider_pool_setup({"day": 4, "time_of_day": "night"})
	assert(_has_seeded_jessa(next_setup) and next_setup.rule_ids.has("jessa_absence_seed"))
	selection.mode = PlayerState.TRANSITION_RIDE
	assert(not pool._supports_time_in_selection(jessa), "The next day's morning still follows Jessa's later-night schedule")
	PlayerState.current_day = 4
	PlayerState.set_current_stage_time("noon")
	assert(pool._supports_time_in_selection(Catalog.get_character_by_id(PlayerState, "jessa")), "The next day's projected night restores her normal schedule")
	selection.mode = PlayerState.TRANSITION_CURRENT_STAGE
	PlayerState.set_current_stage_time("night")
	assert(pool._pick_character_for_distance("short", used_ids, {"jessa": true}, true).get("id", "") == "jessa")
	PlayerState.set_current_stage_time("morning")
	assert(not pool._supports_time_in_selection(Catalog.get_character_by_id(PlayerState, "jessa")))


static func _has_seeded_jessa(setup: Dictionary) -> bool:
	for assignments: Array in setup.distance_slots.values():
		for assignment: Dictionary in assignments:
			if assignment.character.id == "jessa":
				return true
	return false


static func _test_history_compatibility() -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time("night")
	PlayerState.set_event_value("jessa_runaway_fare_seen", true)
	for history in [null, {}, "legacy", {"day": 0}, {"day": -1}, {"day": "unknown"}, {"day": []}]:
		if history == null:
			PlayerState.clear_event_value(FareEvent.EARNINGS_KEY)
		else:
			PlayerState.set_event_value(FareEvent.EARNINGS_KEY, history)
		var jessa := Catalog.get_character_by_id(PlayerState, "jessa")
		assert(int(jessa.get("unavailable_day", 0)) == 0, "Unknown old history must not invent a new absence date")
		assert(Seeded.supports_character_time(PlayerState, jessa, "night", 3))
	PlayerState.set_event_value(FareEvent.EARNINGS_KEY, {"day": 3})
	PlayerState.set_event_value("jessa_runaway_fare_seen", false)
	var incomplete := Catalog.get_character_by_id(PlayerState, "jessa")
	assert(incomplete.eligible_times == ["morning", "noon"] and int(incomplete.get("unavailable_day", 0)) == 0)
	assert(Seeded.supports_character_time(PlayerState, incomplete, "morning", 3))


static func _test_locked_offers_and_resume(host: Node) -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.stage_round = 4
	PlayerState.set_current_stage_time("night")
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE)
	# A saved offer may predate this rule. Keep another usable rider so filtering
	# must preserve the pool rather than repair an entirely unusable old selection.
	var jessa := PlayerState.get_character_by_id("jessa")
	var generic := PlayerState.get_character_by_id("generic_guy")
	for character: Dictionary in [jessa, generic]:
		character["stage_traffic"] = "chill"
		character["active_distance"] = "short"
		character["stage_special_type"] = PlayerState.STAGE_SPECIAL_TYPE_NONE
	PlayerState.lock_pending_trip_selection({"short": [jessa, generic, {}], "medium": [], "long": []}, "short")
	PlayerState.set_event_value("jessa_runaway_fare_seen", true)
	PlayerState.set_event_value(FareEvent.EARNINGS_KEY, {"day": 3, "total": 220})
	var pools := PlayerState.get_locked_pending_trip_character_pools()
	var resources := [PlayerState.money, PlayerState.energy, PlayerState.gas, PlayerState.current_day, PlayerState.current_phase, PlayerState.stage_round]
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	selection._open_passengers()
	assert(not selection.terminal_view.buttons.has("jessa") and selection.terminal_view.buttons.has("generic_guy"))
	assert(selection.locked_character_pools == pools)
	selection._close_passengers()
	selection._open_passengers()
	Codec.save_to_path(PlayerState, "res://test_user/jessa_absence_terminal.tres", PlayerState.SAVE_VERSION)
	selection.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/jessa_absence_terminal.tres"))
	selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	assert(selection.passenger_overlay.visible and not selection.terminal_view.buttons.has("jessa"))
	assert(selection.locked_character_pools == pools)
	assert([PlayerState.money, PlayerState.energy, PlayerState.gas, PlayerState.current_day, PlayerState.current_phase, PlayerState.stage_round] == resources)
	assert(PlayerState.event_values[FareEvent.EARNINGS_KEY].day == 3)
	PlayerState.current_day = 4
	selection._refresh_terminal()
	assert(selection.terminal_view.buttons.has("jessa"), "A saved offer can return on a later night without rerolling or changing its distance")
	assert(selection.locked_character_pools == pools)
	selection.free()


static func _test_replay_isolation(host: Node) -> void:
	PlayerState.reset()
	PlayerState.current_day = 9
	PlayerState.set_current_stage_time("night")
	PlayerState.set_event_value("jessa_runaway_fare_seen", true)
	PlayerState.set_event_value(FareEvent.EARNINGS_KEY, {"day": 3, "total": 220})
	var history: Dictionary = PlayerState.event_values[FareEvent.EARNINGS_KEY].duplicate(true)
	var live := {"story_id": "jessa_absence_live", "composition": [{"text": "Live progress"}]}
	PlayerState.set_pending_story(live)
	var payload := PayloadCatalog.build("jessa_runaway_fare")
	payload["replay"] = true
	PlayerState.set_pending_memory_replay(payload)
	var reader = load("res://scenes/story_scene.tscn").instantiate()
	host.get_tree().root.add_child(reader)
	await host.get_tree().create_timer(1.1).timeout
	await reader._show_line(24)
	await reader._show_line(30)
	assert(PlayerState.event_values[FareEvent.EARNINGS_KEY] == history)
	assert(PlayerState.get_pending_story() == live)
	assert(Seeded.supports_character_time(PlayerState, Catalog.get_character_by_id(PlayerState, "jessa"), "night", 9), "Replaying the first story cannot create a new same-day absence")
	reader.free()
