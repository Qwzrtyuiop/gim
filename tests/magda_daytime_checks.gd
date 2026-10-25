extends RefCounted

const Catalog := preload("res://scripts/story/story_catalog.gd")
const Availability := preload("res://scripts/story/character_availability.gd")
const PassengerPool := preload("res://scripts/ride_selection/passenger_pool.gd")
const SelectionView := preload("res://scripts/ride_selection/selection_view.gd")
const Seeded := preload("res://scripts/seeded_rider_runtime.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SpawnCatalog := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")
const TerminalView := preload("res://scripts/ride_selection/terminal_passenger_view.gd")
const TerminalChecks := preload("res://tests/terminal_spawn_checks.gd")
const DAY_SOURCE := preload("res://assets/story/backgrounds/locations/terminalspawns/magda_dayspawn.png")
const DAY_REGION := Rect2(41, 277, 139, 345)
const NAMED_DAY_IDS := ["ely", "gardo", "ito", "cel", "hana", "benny", "jessa", "alma"]

class SelectionContext extends RefCounted:
	var mode := "current_stage"
	var selected_distance := "medium"
	var locked_character_pools: Dictionary = {}

	func _transition_mode() -> String:
		return mode

	func _is_forced_first_day_ride() -> bool:
		return false

	func _display_day() -> int:
		return PlayerState.get_transition_display_day(mode)


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_live_availability()
	await _test_save_and_cached_offers(host)
	await _test_day_sprite(host)
	PlayerState.reset()
	print("PASS: Magda daytime unlock from progress or completed rides, locked legacy saves/reset, random/seeded/cached live availability, exact alternate atlas crop, preserved night art and nine-offer placement/hover")


static func _setup(progress := 0, rides := 0, locked := false) -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time("morning")
	PlayerState.stage_round = 3
	PlayerState.money = 1000
	PlayerState.energy = 5
	PlayerState.gas = 70
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	PlayerState.set_unique_character_progress("faye", progress)
	PlayerState.character_completed_rides["faye"] = rides
	PlayerState.set_unique_character_story_locked("faye", locked)
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE)


static func _test_live_availability() -> void:
	for state in [[0, 0, false, false], [1, 0, false, false], [0, 1, false, false], [1, 1, false, false], [2, 0, false, true], [0, 2, true, true], [5, 0, false, true], [0, 5, true, true]]:
		_setup(int(state[0]), int(state[1]), bool(state[2]))
		var unlocked := bool(state[3])
		var selection := SelectionContext.new()
		var pool := PassengerPool.new(selection)
		var used_ids: Dictionary = {}
		for character: Dictionary in PlayerState.get_mock_characters():
			if character.id != "faye":
				used_ids[character.id] = true
		PlayerState.seeded_rider_rules.clear()
		Seeded.add_rule(PlayerState, {"id": "magda_daytime_fixture", "character_id": "faye", "distance": "medium", "min_day": 3, "repeatable": true})
		for phase in ["morning", "noon", "night"]:
			PlayerState.set_current_stage_time(phase)
			var faye := Catalog.get_character_by_id(PlayerState, "faye")
			var expected: bool = unlocked or phase == "night"
			assert(Availability.supports_time(faye, phase, 3) == expected)
			assert(faye.eligible_times.has("night"), "Magda always retains her original night schedule")
			assert((pool._pick_character_for_distance("medium", used_ids, {"faye": true}, true).get("id", "") == "faye") == expected)
			var setup := PlayerState.get_seeded_rider_pool_setup({"day": 3, "time_of_day": phase})
			assert(setup.rule_ids.has("magda_daytime_fixture") == expected)
			assert(_has_seeded_faye(setup) == expected)
			assert(not PlayerState.consumed_seeded_rider_rules.has("magda_daytime_fixture"), "Eligibility checks cannot consume a seed")
		# Unlocking the schedule does not bypass the ordinary first-appearance roll.
		PlayerState.set_current_stage_time("morning")
		assert(pool._pick_character_for_distance("medium", used_ids, {"faye": false}, false).is_empty())
	_setup(2)
	var copy := Catalog.get_character_by_id(PlayerState, "faye")
	copy.eligible_times.clear()
	assert(Catalog.get_character_by_id(PlayerState, "faye").eligible_times.has("morning"), "A caller cannot mutate live catalog defaults")
	PlayerState.reset()
	assert(Catalog.get_character_by_id(PlayerState, "faye").eligible_times == ["night"])


static func _has_seeded_faye(setup: Dictionary) -> bool:
	for assignments: Array in setup.distance_slots.values():
		for assignment: Dictionary in assignments:
			if assignment.character.id == "faye":
				return true
	return false


static func _test_save_and_cached_offers(host: Node) -> void:
	for state in [[2, 0, false], [0, 2, true]]:
		_setup(int(state[0]), int(state[1]), bool(state[2]))
		var stale := PlayerState.get_character_by_id("faye")
		stale["eligible_times"] = ["night"]
		stale["stage_traffic"] = "chill"
		var generic := PlayerState.get_character_by_id("generic_guy")
		generic["stage_traffic"] = "chill"
		var pools := {"short": [generic], "medium": [stale], "long": []}
		PlayerState.lock_pending_trip_selection(pools, "medium")
		var path := "res://test_user/magda_daytime_%d.tres" % int(state[1])
		Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
		PlayerState.reset()
		assert(Codec.load_from_path(PlayerState, path))
		assert(PlayerState.get_unique_character_progress("faye") == int(state[0]))
		assert(int(PlayerState.character_completed_rides.get("faye", 0)) == int(state[1]))
		var context := SelectionContext.new()
		context.locked_character_pools = PlayerState.get_locked_pending_trip_character_pools()
		var view := SelectionView.new(context)
		assert(_has_offer(view.offers(), "faye"), "Saved night-only metadata is revalidated against Magda's live unlocked schedule")
		var station = load("res://scenes/ride_selection.tscn").instantiate()
		host.get_tree().root.add_child(station)
		await host.get_tree().process_frame
		station._open_passengers()
		assert(station.terminal_view.buttons.has("faye") and not station.terminal_view.buttons.faye.is_placeholder)
		assert(station.locked_character_pools == pools, "An eligible saved selection must be preserved rather than rerolled")
		station.free()
		var unlocked_copy := PlayerState.get_character_by_id("faye")
		_setup()
		context.locked_character_pools = {"short": [generic], "medium": [unlocked_copy], "long": []}
		assert(not _has_offer(view.offers(), "faye") and _has_offer(view.offers(), "generic_guy"), "Stale daytime offers cannot survive resetting Magda's progress and rides")


static func _has_offer(offers: Array[Dictionary], id: String) -> bool:
	for offer: Dictionary in offers:
		if offer.character.id == id:
			return true
	return false


static func _test_day_sprite(host: Node) -> void:
	_setup(2)
	var day := SpawnCatalog.entry("faye", false)
	var night := SpawnCatalog.entry("faye", true)
	assert(day.region == DAY_REGION and day.texture is AtlasTexture)
	var atlas: AtlasTexture = day.texture
	assert(atlas.atlas == DAY_SOURCE and atlas.region == DAY_REGION and atlas.get_size() == DAY_REGION.size)
	var expected := DAY_SOURCE.get_image().get_region(Rect2i(DAY_REGION))
	assert(atlas.get_image().get_data() == expected.get_data(), "The alternate sprite preserves the supplied crop's full RGBA pixels")
	assert(night.region == Rect2(1546, 307, 114, 335) and night.texture.resource_path.ends_with("terminal/night/faye.png"))
	assert(not SpawnCatalog.GENERIC_SLOT_BY_CHARACTER.has("faye"), "The new left-edge pose cannot reserve another character's generic slot")
	var view := TerminalView.new()
	host.get_tree().root.add_child(view)
	view.size = Vector2(1280, 720)
	for omitted in NAMED_DAY_IDS:
		var offers: Array[Dictionary] = [_offer("faye", 0)]
		for id in NAMED_DAY_IDS:
			if id != omitted:
				offers.append(_offer(id, offers.size()))
		offers.append(_offer("generic_guy", offers.size()))
		view.set_offers(offers, false)
		assert(view.buttons.size() == 9)
		var faye = view.buttons.faye
		var generic = view.buttons.generic_guy
		assert(not faye.is_placeholder and faye.source_region == DAY_REGION and faye.alpha_image.get_size() == Vector2i(139, 345))
		assert(TerminalChecks._has_opaque_target(faye) and not generic.is_placeholder)
		assert(generic.spawn_slot == int(SpawnCatalog.GENERIC_SLOT_BY_CHARACTER[omitted]))
		for other: String in view.buttons:
			if other != "faye":
				assert(not TerminalChecks._opaque_overlap(faye, view.buttons[other]))
			if other != "generic_guy":
				assert(not TerminalChecks._opaque_overlap(generic, view.buttons[other]), "All nine offers must fit without covering a waiting body")
		for viewport in [Vector2(1280, 720), Vector2(900, 900)]:
			view.size = viewport
			view._layout()
			var normal: Rect2 = view.sprite_rect_for("faye")
			var hover: Rect2 = view.sprite_rect_for("faye", true)
			assert(hover.size.is_equal_approx(normal.size * 1.06))
			assert(is_equal_approx(hover.end.y, normal.end.y) and is_equal_approx(hover.get_center().x, normal.get_center().x))
	view.set_offers([_offer("faye", 0)], true)
	assert(view.buttons.faye.source_region == night.region and view.buttons.faye.texture == night.texture)
	view.free()
	await host.get_tree().process_frame


static func _offer(id: String, slot: int) -> Dictionary:
	return {"character": {"id": id}, "distance": "medium", "slot": slot, "details": id}
