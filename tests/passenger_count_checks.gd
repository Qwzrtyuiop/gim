extends RefCounted

const PassengerPool := preload("res://scripts/ride_selection/passenger_pool.gd")
const SelectionView := preload("res://scripts/ride_selection/selection_view.gd")
const Availability := preload("res://scripts/story/character_availability.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STATION := "res://scenes/ride_selection.tscn"
const STORE := "res://scenes/store.tscn"

class SelectionContext extends RefCounted:
	var selected_distance := "short"
	var forced_first := false
	var locked_character_pools: Dictionary = {}

	func _transition_mode() -> String:
		return PlayerState.TRANSITION_CURRENT_STAGE

	func _is_forced_first_day_ride() -> bool:
		return forced_first

	func _display_day() -> int:
		return PlayerState.get_current_day()


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_count_range()
	_test_retained_first_appearances()
	_test_tutorial_offers()
	_test_scripted_reservations()
	_test_low_fuel()
	_test_midnight()
	await _test_sparse_lock_resume(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: variable two-to-nine unique passenger totals, sparse real terminal offers, tutorial/low-fuel safeguards, retained-only first appearances, seeded slot/traffic priority and consumption, sparse store/revisit/save locks and closed midnight pools")


static func _setup() -> void:
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = 4
	PlayerState.set_current_stage_time("morning")
	PlayerState.stage_round = 4
	PlayerState.money = 1000
	PlayerState.energy = 5
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)


static func _all_seen() -> void:
	for character: Dictionary in PlayerState.get_mock_characters():
		PlayerState.seen_mock_characters[str(character.id)] = true


static func _test_count_range() -> void:
	_setup()
	_all_seen()
	var selection := SelectionContext.new()
	var pool := PassengerPool.new(selection)
	var counts: Dictionary = {}
	var empty_distance_seen := false
	PlayerState._begin_state_batch()
	for roll_seed in range(128):
		pool.rng.seed = roll_seed
		selection.locked_character_pools = pool.roll()
		var ids := _assert_lineup(selection.locked_character_pools)
		assert(ids.size() >= 2 and ids.size() <= 9)
		var offers := SelectionView.new(selection).offers()
		assert(offers.size() == ids.size(), "Every retained passenger must be visible together across distances")
		counts[offers.size()] = true
		if offers.size() == 2:
			for distance: String in PlayerState.STAGE_DIFFICULTIES:
				empty_distance_seen = empty_distance_seen or _count(selection.locked_character_pools[distance]) == 0
	PlayerState._end_state_batch()
	assert(counts.has(2), "A fresh terminal can have exactly two visible passengers")
	assert(counts.has(9), "A fully available terminal can still fill all nine slots")
	assert(counts.size() > 2 and empty_distance_seen, "Totals vary without requiring one passenger per distance")


static func _test_retained_first_appearances() -> void:
	_setup()
	var selection := SelectionContext.new()
	var pool := PassengerPool.new(selection)
	PlayerState._begin_state_batch()
	for roll_seed in range(48):
		PlayerState.seen_mock_characters.clear()
		pool.rng.seed = roll_seed
		var pools := pool.roll()
		var ids := _assert_lineup(pools)
		assert(ids.size() >= 2 and ids.size() <= 9)
		assert(PlayerState.seen_mock_characters.size() == ids.size(), "Discarded candidates/retries cannot mark hidden passengers seen")
		for id: String in PlayerState.seen_mock_characters:
			assert(ids.has(id))
		for cards: Array in pools.values():
			for character: Dictionary in cards:
				if not character.is_empty():
					assert(character.is_first_appearance, "Only the final lock records a new passenger's first appearance")
	PlayerState._end_state_batch()


static func _test_tutorial_offers() -> void:
	_setup()
	PlayerState.current_day = 1
	PlayerState.stage_round = 0
	var selection := SelectionContext.new()
	selection.forced_first = true
	var pool := PassengerPool.new(selection)
	var counts: Dictionary = {}
	PlayerState._begin_state_batch()
	for roll_seed in range(24):
		PlayerState.seen_mock_characters.clear()
		pool.rng.seed = roll_seed
		var pools := pool.roll()
		var ids := _assert_lineup(pools)
		assert(ids.size() >= 2 and ids.size() <= 3)
		assert(_count(pools.medium) == 0 and _count(pools.long) == 0, "The first tutorial cannot lock unseen passengers outside its short route")
		assert(PlayerState.seen_mock_characters.size() == ids.size())
		for id: String in PlayerState.seen_mock_characters:
			assert(ids.has(id))
		for character: Dictionary in pools.short:
			if not character.is_empty():
				assert(character.stage_traffic == "chill" and character.stage_special_type == PlayerState.STAGE_SPECIAL_TYPE_NONE)
		counts[ids.size()] = true
	assert(counts.has(2) and counts.has(3))
	PlayerState.seen_mock_characters.clear()
	var short_rule := _seed("generic_vendor", "short", 2, "speeders")
	var hidden_rule := _seed("gardo", "long", 1, "busy")
	var seeded := pool.roll()
	assert(seeded.short[2].id == "generic_vendor" and seeded.short[2].stage_traffic == "chill")
	assert(PlayerState.consumed_seeded_rider_rules.get(short_rule, false))
	assert(not PlayerState.consumed_seeded_rider_rules.get(hidden_rule, false), "A tutorial-hidden seed must remain unconsumed")
	var retained := _assert_lineup(seeded)
	assert(retained.size() >= 2 and retained.size() <= 3)
	assert(PlayerState.seen_mock_characters.size() == retained.size())
	PlayerState._end_state_batch()


static func _test_scripted_reservations() -> void:
	_setup()
	_all_seen()
	var selection := SelectionContext.new()
	var pool := PassengerPool.new(selection)
	var assignments := [
		{"id": "benny", "distance": "medium", "slot": 2, "traffic": "traffic-jam"},
		{"id": "gardo", "distance": "long", "slot": 2, "traffic": "speeders"},
		{"id": "generic_guy", "distance": "medium", "slot": 1, "traffic": "busy"},
		{"id": "generic_vendor", "distance": "long", "slot": 0, "traffic": "normal"},
	]
	var rules: Array[String] = []
	PlayerState._begin_state_batch()
	for assignment: Dictionary in assignments:
		rules.append(_seed(assignment.id, assignment.distance, int(assignment.slot), assignment.traffic))
	var floor_seen := false
	for roll_seed in range(48):
		PlayerState.consumed_seeded_rider_rules.clear()
		pool.rng.seed = roll_seed
		var pools := pool.roll()
		var ids := _assert_lineup(pools)
		assert(ids.size() >= 4 and ids.size() <= 9, "Scripted riders raise the count floor")
		floor_seen = floor_seen or ids.size() == 4
		for assignment: Dictionary in assignments:
			var character: Dictionary = pools[assignment.distance][assignment.slot]
			assert(character.id == assignment.id and character.stage_traffic == assignment.traffic, "Random filling cannot steal a rider or replace its scripted slot/traffic")
		for rule: String in rules:
			assert(PlayerState.consumed_seeded_rider_rules.get(rule, false), "Only retained scripted placements consume their rules")
	assert(floor_seen, "A small roll keeps its seeded floor without padding every distance")
	PlayerState._end_state_batch()


static func _test_low_fuel() -> void:
	_setup()
	_all_seen()
	var selection := SelectionContext.new()
	selection.selected_distance = "long"
	var pool := PassengerPool.new(selection)
	PlayerState._begin_state_batch()
	for gas in [0.0, 1.0, 40.0]:
		PlayerState.gas = gas
		for roll_seed in range(24):
			pool.rng.seed = roll_seed
			var pools := pool.roll()
			var ids := _assert_lineup(pools)
			assert(ids.size() >= 2 and ids.size() <= 9)
			assert(_count(pools.short) > 0, "Low fuel preserves a short offer even when Long was selected")
	var medium_rule := _seed("generic_worker", "medium", 1, "chill")
	var long_rule := _seed("generic_parent_child", "long", 2, "normal")
	var three_seen := false
	for roll_seed in range(48):
		PlayerState.consumed_seeded_rider_rules.clear()
		pool.rng.seed = roll_seed
		var pools := pool.roll()
		var ids := _assert_lineup(pools)
		assert(ids.size() >= 3 and _count(pools.short) > 0, "Two non-short seeds cannot eliminate the safe short offer")
		three_seen = three_seen or ids.size() == 3
		assert(pools.medium[1].id == "generic_worker" and pools.long[2].id == "generic_parent_child")
		assert(PlayerState.consumed_seeded_rider_rules.get(medium_rule, false) and PlayerState.consumed_seeded_rider_rules.get(long_rule, false))
	assert(three_seen)
	PlayerState._end_state_batch()


static func _test_midnight() -> void:
	_setup()
	PlayerState.set_current_stage_time("night")
	_seed("hana", "medium", 0, "chill")
	PlayerState.set_last_stage_result({"day": 4, "time_of_day": "night", "completed": true})
	var selection := SelectionContext.new()
	var pool := PassengerPool.new(selection)
	pool.rng.seed = 8495
	var seen := PlayerState.seen_mock_characters.duplicate(true)
	var consumed := PlayerState.consumed_seeded_rider_rules.duplicate(true)
	var random_state: int = pool.rng.state
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	assert(pool.roll() == {"short": [], "medium": [], "long": []})
	assert(pool.rng.state == random_state and PlayerState.seen_mock_characters == seen and PlayerState.consumed_seeded_rider_rules == consumed)
	assert(int(PlayerState.get_meta("test_save_count", 0)) == saves, "Closed midnight pools cannot reroll, consume seeds or save")


static func _test_sparse_lock_resume(host: Node) -> void:
	_setup()
	_all_seen()
	var short_rider := PlayerState.get_character_by_id("generic_guy")
	short_rider.merge({"active_distance": "short", "stage_traffic": "chill", "pickup_location": "station", "pickup_variant": ""}, true)
	var long_rider := PlayerState.get_character_by_id("generic_student")
	long_rider.merge({"active_distance": "long", "stage_traffic": "speeders", "pickup_location": "station", "pickup_variant": ""}, true)
	var sparse := {"short": [{}, short_rider, {}], "medium": [{}, {}, {}], "long": [{}, {}, long_rider]}
	PlayerState.lock_pending_trip_selection(sparse, "long")
	var unused_rule := _seed("benny", "medium", 0, "busy")
	var economy := _economy()
	var station = load(STATION).instantiate()
	host.get_tree().root.add_child(station)
	await _settle(host)
	_assert_sparse(station, sparse, unused_rule)
	station._open_passengers()
	station._close_passengers()
	assert(PlayerState.get_locked_pending_trip_character_pools() == sparse)
	station._open_store()
	await host.get_tree().scene_changed
	await _settle(host)
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == STORE)
	station.free()
	store._ride()
	await host.get_tree().scene_changed
	await _settle(host)
	station = host.get_tree().current_scene
	_assert_sparse(station, sparse, unused_rule)
	assert(_economy() == economy, "Walking between hubs cannot change resources or time")
	var path := "res://test_user/sparse_passengers.tres"
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	host.get_tree().current_scene = null
	station.free()
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, path))
	station = load(STATION).instantiate()
	host.get_tree().root.add_child(station)
	await _settle(host)
	_assert_sparse(station, sparse, unused_rule)
	assert(_economy() == economy)
	station.free()


static func _assert_sparse(station, sparse: Dictionary, unused_rule: String) -> void:
	assert(station.locked_character_pools == sparse and PlayerState.get_locked_pending_trip_character_pools() == sparse, "A usable two-offer saved lineup must be reused exactly")
	assert(station.terminal_offers.size() == 2 and station.terminal_view.buttons.size() == 2)
	assert(station.terminal_view.buttons.has("generic_guy") and station.terminal_view.buttons.has("generic_student"))
	assert(station.selected_distance == "long")
	assert(not PlayerState.consumed_seeded_rider_rules.get(unused_rule, false), "Reopening cached offers must not consume a new seed")


static func _assert_lineup(pools: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	for distance: String in PlayerState.STAGE_DIFFICULTIES:
		var cards: Array = pools[distance]
		assert(cards.size() == 3, "Saved distance slot arrays retain their existing shape")
		for character: Dictionary in cards:
			if character.is_empty():
				continue
			var id := str(character.id)
			assert(not id.is_empty() and not ids.has(id), "Each visible passenger has one unique slot")
			assert(character.active_distance == distance and PlayerState.STAGE_TRAFFIC_TYPES.has(character.stage_traffic))
			assert(Availability.supports_time(PlayerState.get_character_by_id(id), PlayerState.get_current_time_of_day(), PlayerState.get_current_day()))
			ids[id] = true
	return ids


static func _count(cards: Array) -> int:
	var count := 0
	for character: Dictionary in cards:
		if not character.is_empty():
			count += 1
	return count


static func _seed(id: String, distance: String, slot: int, traffic: String) -> String:
	var character := PlayerState.get_character_by_id(id)
	assert(character.get("eligible_distances", []).has(distance), "Seed fixtures must use a live supported distance")
	assert(Availability.supports_time(character, PlayerState.get_current_time_of_day(), PlayerState.get_current_day()), "Seed fixtures must use a live supported phase")
	PlayerState.seed_rider_for_stage(id, PlayerState.get_current_day(), PlayerState.get_current_time_of_day(), distance, slot, traffic)
	var rules: Array = PlayerState.get_seeded_rider_rules()
	return str(rules.back().id)


static func _economy() -> Dictionary:
	return {"day": PlayerState.current_day, "phase": PlayerState.current_phase, "round": PlayerState.stage_round, "money": PlayerState.money, "energy": PlayerState.energy, "gas": PlayerState.gas}


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
