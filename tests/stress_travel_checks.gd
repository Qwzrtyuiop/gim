extends RefCounted

const HomeMap := preload("res://scripts/home/home_map.gd")
const Catalog := preload("res://scripts/map/topdown_map_catalog.gd")
const LocationVisits := preload("res://tests/location_visit_checks.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_paid_visits(host)
	await _test_hospital_unlock(host)
	await _test_park_relief(host)
	await _test_navigation_and_closed_destinations(host)
	await _test_pickup_departures(host)
	await _test_exhausted_travel(host)
	AmbientAudioManager.stop_all()
	UIAudioManager.hover_player.stop()
	UIAudioManager.press_player.stop()
	await host.get_tree().create_timer(0.1).timeout
	PlayerState.reset()
	print("PASS: free north public destinations, paid map arrivals, Celina-gated hospital, daily Park/Church inline relief, free current-location reopening/region navigation and shared pickups, closed-building and zero-energy guards")


static func _fixture(host: Node, day := 8, phase := "night", hospital_unlocked := true) -> Dictionary:
	PlayerState.reset()
	PlayerState.current_day = day
	assert(PlayerState.max_energy == 5 and PlayerState.energy == 5)
	PlayerState.current_phase = phase
	PlayerState.current_weather = "clear"
	PlayerState.set_event_value("celina_first_encounter_seen", hospital_unlocked)
	PlayerState.set_event_value("north_road_open_announced", true)
	PlayerState.set_pending_trip_selection(HomeMap.HOME_SCENE, PlayerState.TRANSITION_CURRENT_STAGE)
	var rider: Dictionary = PlayerState.get_character_by_id("generic_guy")
	rider["active_distance"] = "short"
	rider["stage_traffic"] = "chill"
	rider["pickup_location"] = "station"
	rider["pickup_variant"] = ""
	PlayerState.lock_pending_trip_selection({"short": [rider], "medium": [], "long": []}, "short")
	var parent := Control.new()
	parent.size = Vector2(1280, 720)
	host.get_tree().root.add_child(parent)
	host.get_tree().current_scene = parent
	var world := HomeMap.new()
	parent.add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var departures: Array[String] = []
	world.destination_requested.connect(func(path: String) -> void: departures.append(path))
	world.open()
	return {"parent": parent, "world": world, "departures": departures}


static func _test_paid_visits(host: Node) -> void:
	var fixture := _fixture(host)
	var world: HomeMap = fixture.world
	await _settle(host)
	PlayerState.stress = 8
	var unchanged := _other_resources()
	for location_id in ["park", "hospital", "bar"]:
		var energy: int = PlayerState.energy
		world._visit(location_id)
		if world.hub_story_overlay.active:
			await LocationVisits.finish_overlay(host, world)
		assert(world.current_location == location_id and world.location_view.visible)
		assert(PlayerState.energy == energy - 1, "A distinct map destination costs exactly one energy")
		if location_id == "park":
			unchanged.stress -= 2
		world._show_map()
		world._visit(location_id)
		assert(PlayerState.energy == energy - 1, "Reopening the current destination cannot charge again")
		if location_id == "bar":
			world._enter_bar()
			world._exit_bar()
			assert(PlayerState.energy == energy - 1, "Entering and leaving the bar building is part of the same visit")
		world._show_map()
	world._visit("park")
	assert(PlayerState.energy == 2 and world.map_view.visible, "The daily Park limit blocks another arrival before charging")
	assert(str(world.hub_dialogue.active_line.get("text", "")).contains("tomorrow"))
	world._show_map()
	world._visit("north")
	assert(world.map_view.map_region == "north" and PlayerState.energy == 2)
	PlayerState.energy = PlayerState.max_energy
	var energy_supplied: int = PlayerState.max_energy
	var paid_visits := 0
	for location_id: String in Catalog.NORTH_REGIONS:
		if location_id == "town":
			continue
		var energy: int = PlayerState.energy
		var cost: int = world.travel_energy_cost(location_id)
		world._visit(location_id)
		if location_id == "abandoned_building":
			assert(world.map_view.visible and PlayerState.energy == energy and world.hub_dialogue.active_line.get("text") == world.ABANDONED_BUILDING_MESSAGE)
			continue
		if world.hub_story_overlay.active:
			await LocationVisits.finish_overlay(host, world)
		paid_visits += cost
		if location_id == "church":
			unchanged.stress -= 2
		assert(world.current_location == location_id and world.background.texture != null)
		assert(cost == (0 if location_id in ["pier", "school", "big_station"] else 1))
		assert(PlayerState.energy == energy - cost, "North public destinations are free; the court, construction site and church cost one energy")
		world._show_map()
		world._visit(location_id)
		assert(PlayerState.energy == energy - cost, "Current-location reopening never spends another energy point")
		world._show_map()
	assert(PlayerState.energy == energy_supplied - paid_visits)
	assert(_other_resources() == unchanged, "The two daily Park/Church arrivals relieve stress; ordinary travel preserves stress, hull, cash, fuel and the clock")
	fixture.parent.free()
	await _settle(host)


static func _test_hospital_unlock(host: Node) -> void:
	for phase in ["morning", "night"]:
		var fixture := _fixture(host, 8, phase, false)
		var world: HomeMap = fixture.world
		await _settle(host)
		var unchanged := _other_resources()
		var energy: int = PlayerState.energy
		var saves := int(PlayerState.get_meta("test_save_count", 0))
		assert(Catalog.is_locked("hospital") and world.travel_energy_cost("hospital") == 0)
		world.map_view.buttons.hospital.pressed.emit()
		world._request_visit("hospital")
		world._visit("hospital")
		assert(world.current_location == "home" and world.map_view.visible and not world.location_view.visible)
		assert(not world.travel_confirmation.visible and world._pending_destination.is_empty())
		assert(PlayerState.energy == energy and _other_resources() == unchanged and int(PlayerState.get_meta("test_save_count", 0)) == saves, "Locked hospital requests and direct visits cannot charge, save or reveal the interior")
		PlayerState.set_event_value("celina_first_encounter_seen", true)
		assert(not Catalog.is_locked("hospital") and world.travel_energy_cost("hospital") == 1, "Celina's completed first encounter unlocks the hospital immediately")
		world._request_visit("hospital")
		assert(world.travel_confirmation.visible and world._pending_destination == "hospital" and PlayerState.energy == energy)
		world._confirm_travel()
		assert(world.current_location == "hospital" and world.location_view.visible and PlayerState.energy == energy - 1)
		assert(_other_resources() == unchanged, "Unlocking hospital travel changes no other resources")
		fixture.parent.free()
		await _settle(host)


static func _test_park_relief(host: Node) -> void:
	var fixture := _fixture(host, 8, "morning")
	var world: HomeMap = fixture.world
	await _settle(host)
	PlayerState.stress = 7
	var unchanged := _other_resources()
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	world._request_visit("park")
	assert(world.travel_confirmation.visible and PlayerState.energy == 5 and _other_resources() == unchanged)
	world._cancel_travel()
	assert(PlayerState.energy == 5 and _other_resources() == unchanged and int(PlayerState.get_meta("test_save_count", 0)) == saves, "Previewing or cancelling the park cannot grant stress relief")
	world._request_visit("park")
	world._confirm_travel()
	unchanged.stress = 5
	assert(PlayerState.energy == 4 and _other_resources() == unchanged)
	assert(world.hub_story_overlay.active and PlayerState.has_visited_location_today("park"))
	await LocationVisits.finish_overlay(host, world)
	assert(PlayerState._state_batch_depth == 0 and not PlayerState._suppress_auto_save)
	saves = int(PlayerState.get_meta("test_save_count", 0))
	for _repeat in range(3):
		world._show_map()
		assert(world.travel_energy_cost("park") == 0)
		world._request_visit("park")
		assert(world.location_view.visible and not world.travel_confirmation.visible)
		assert(PlayerState.energy == 4 and _other_resources() == unchanged and int(PlayerState.get_meta("test_save_count", 0)) == saves, "Reopening the current park cannot farm relief, another scene or another save")
	world._show_map()
	world._visit("hospital")
	world._show_map()
	saves = int(PlayerState.get_meta("test_save_count", 0))
	world._visit("park")
	assert(PlayerState.energy == 3 and _other_resources() == unchanged and int(PlayerState.get_meta("test_save_count", 0)) == saves, "Returning after another destination cannot buy a second visit on the same day")
	assert(world.map_view.visible and str(world.hub_dialogue.active_line.get("text", "")).contains("tomorrow"))
	PlayerState.current_day = 9
	PlayerState.energy = 1
	world._show_map()
	PlayerState.stress = 1
	world._visit("park")
	await LocationVisits.finish_overlay(host, world)
	unchanged.stress = 0
	unchanged.day = 9
	assert(PlayerState.energy == 0 and _other_resources() == unchanged and int(PlayerState.get_event_value("park_visit_count", 0)) == 2, "Tomorrow's visit is available again and relief clamps at zero")
	fixture.parent.free()
	await _settle(host)
	fixture = _fixture(host, 8, "morning")
	world = fixture.world
	PlayerState.energy = 0
	PlayerState.stress = 7
	unchanged = _other_resources()
	saves = int(PlayerState.get_meta("test_save_count", 0))
	world._request_visit("park")
	assert(world.current_location == "home" and not world.travel_confirmation.visible)
	assert(PlayerState.energy == 0 and _other_resources() == unchanged and int(PlayerState.get_meta("test_save_count", 0)) == saves, "An unaffordable park visit cannot grant free stress relief")
	fixture.parent.free()
	await _settle(host)


static func _test_navigation_and_closed_destinations(host: Node) -> void:
	var fixture := _fixture(host, 7, "morning")
	var world: HomeMap = fixture.world
	await _settle(host)
	var energy: int = PlayerState.energy
	world._visit("north")
	assert(world.map_view.map_region == "town" and PlayerState.energy == energy)
	assert(world.hub_dialogue.active_line.get("text") == world.NORTH_ROAD_CLOSED_MESSAGE)
	world.hub_dialogue.clear()
	world._visit("bar")
	assert(world.current_location == "home" and PlayerState.energy == energy)
	assert(world.hub_dialogue.active_line.get("text") == world.BAR_CLOSED_MESSAGE)
	world.hub_dialogue.clear()
	for location_id in ["locked_east", "locked_south_east", "locked_south_west"]:
		world.map_view.buttons[location_id].pressed.emit()
		assert(world.current_location == "home" and PlayerState.energy == energy)
	PlayerState.current_day = 8
	world._visit("north")
	assert(world.map_view.map_region == "north" and PlayerState.energy == energy)
	world._visit("town")
	assert(world.map_view.map_region == "town" and PlayerState.energy == energy, "Opening north/south maps is free")
	fixture.parent.free()
	await _settle(host)


static func _test_pickup_departures(host: Node) -> void:
	for phase in ["morning", "noon", "night"]:
		for location_id in ["station", "market", "street"]:
			var fixture := _fixture(host, 8, phase)
			var world: HomeMap = fixture.world
			await _settle(host)
			var energy: int = PlayerState.energy
			var unchanged := _other_resources()
			var pools := PlayerState.get_locked_pending_trip_character_pools()
			assert(world.travel_energy_cost(location_id) == 0, "All passenger pickup areas are free in every phase")
			world._request_visit(location_id)
			assert(not world.travel_confirmation.visible and fixture.departures == [world.STATION_SCENE])
			assert(PlayerState.get_pending_pickup_location() == location_id, "Map travel selects the requested pickup area before departure")
			assert(PlayerState.energy == energy and _other_resources() == unchanged and PlayerState.get_locked_pending_trip_character_pools() == pools, "Pickup travel must retain offers, energy, stress, hull, gas, money and time")
			fixture.parent.free()
			await _settle(host)


static func _test_exhausted_travel(host: Node) -> void:
	for exit_id in ["home", "station", "market", "street"]:
		var fixture := _fixture(host)
		var world: HomeMap = fixture.world
		await _settle(host)
		PlayerState.energy = 0
		var unchanged := _other_resources()
		world._visit("hospital")
		assert(world.current_location == "home" and world.map_view.visible and not world.location_view.visible)
		assert(world.hub_dialogue.active_line.get("speaker") == "John Toda")
		assert(str(world.hub_dialogue.active_line.get("text", "")).contains("too tired"))
		assert(world.hub_dialogue.bubble.is_visible_in_tree() and world.hub_dialogue.bubble.tail_points.is_empty())
		assert(PlayerState.energy == 0 and _other_resources() == unchanged, "A blocked visit must preserve the current place and state")
		if exit_id != "home":
			world._visit(exit_id)
			assert(fixture.departures == [world.STATION_SCENE])
			assert(PlayerState.get_pending_pickup_location() == exit_id)
		else:
			world._visit("home")
			assert(not world.visible)
		assert(PlayerState.energy == 0 and _other_resources() == unchanged, "Safe hub exits remain available without energy")
		fixture.parent.free()
		await _settle(host)


static func _other_resources() -> Dictionary:
	return {
		"money": PlayerState.money,
		"stress": PlayerState.stress,
		"hull": PlayerState.hull,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
	}


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
