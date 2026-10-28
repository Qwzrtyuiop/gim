extends RefCounted

const MapView := preload("res://scripts/map/topdown_map_view.gd")
const MapCatalog := preload("res://scripts/map/topdown_map_catalog.gd")
const WeatherState := preload("res://scripts/state/player_weather_state.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STATION := "res://scenes/ride_selection.tscn"
const STORE := "res://scenes/store.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_geometry_and_input(host)
	await _test_travel_confirmation(host)
	await _test_north_road(host)
	await _test_location_phases(host)
	await _test_home_gates(host)
	await _test_hub_departures(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: map geometry and pointer/keyboard isolation, real Escape ownership, day/night hospital and bar entry/exit, indoor/map rain, paid arrivals, three free pickup routes with stable offers, same-picker map return, zero-energy store access and home modal guards")


static func _setup(phase := "morning", day := 3) -> void:
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = day
	PlayerState.current_phase = "night" if phase == "midnight" else phase
	PlayerState.current_stage_type = "short-%s-chill" % PlayerState.current_phase
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 5
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.set_event_value("celina_first_encounter_seen", true)
	PlayerState.ensure_daily_conditions_for_current_day()
	assert(WeatherState.set_story_weather(PlayerState, "rain"))
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)
	var rider: Dictionary = PlayerState.get_character_by_id("generic_guy")
	rider["active_distance"] = "short"
	rider["stage_traffic"] = "chill"
	rider["stage_special_type"] = ""
	rider["pickup_location"] = "station"
	rider["pickup_variant"] = ""
	PlayerState.lock_pending_trip_selection({"short": [rider], "medium": [], "long": []}, "short")
	if phase == "midnight":
		PlayerState.last_stage_result = {"day": day, "time_of_day": "night"}


static func _home(host: Node, phase := "morning", day := 3) -> Variant:
	_setup(phase, day)
	var home = load(HOME).instantiate()
	host.get_tree().root.add_child(home)
	host.get_tree().current_scene = home
	await _settle(host)
	return home


static func _snapshot(include_navigation := true) -> Dictionary:
	var result := {
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"stress": PlayerState.stress,
		"hull": PlayerState.hull,
		"gas": PlayerState.gas,
		"weather": PlayerState.current_weather,
		"rests": PlayerState.rests_taken_today,
		"events": PlayerState.event_values.duplicate(true),
		"story": PlayerState.get_pending_story(),
		"pools": PlayerState.get_locked_pending_trip_character_pools(),
	}
	if include_navigation:
		result["selection"] = PlayerState.get_pending_trip_selection()
		result["saves"] = int(PlayerState.get_meta("test_save_count", 0))
	return result


static func _test_geometry_and_input(host: Node) -> void:
	_setup()
	var original := _snapshot()
	var view := MapView.new()
	host.get_tree().root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var selected: Array[String] = []
	view.location_selected.connect(func(id: String) -> void: selected.append(id))
	assert(MapCatalog.BACKGROUND.get_size() == MapCatalog.ART_SIZE)
	assert(MapCatalog.NIGHT_BACKGROUND.get_size() == MapCatalog.ART_SIZE)
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(640, 360)]:
		view.size = viewport_size
		await _settle(host)
		assert(Rect2(Vector2.ZERO, viewport_size).grow(0.01).encloses(view.image_rect))
		for id: String in MapCatalog.REGIONS:
			var region: Rect2 = MapCatalog.REGIONS[id]
			var expected := Rect2(view.image_rect.position + region.position / MapCatalog.ART_SIZE * view.image_rect.size, region.size / MapCatalog.ART_SIZE * view.image_rect.size)
			assert(view.buttons[id].get_rect().is_equal_approx(expected), "Authored map areas must track the fitted artwork at every viewport shape")
		for weather in ["rain", "heavy rain", "cloudy"]:
			view.set_weather(weather)
			assert(view.weather_effects.get_rect().is_equal_approx(view.image_rect), "Map rain cannot cover its letterboxing")
			assert(view.weather_effects.is_raining() == (weather != "cloudy"))
			assert(not view.weather_effects.indoor)
			assert(view.weather_effects.marker_texture == null, "The map needs falling rain without invented splash regions")
		view.set_night(true)
		assert(view.get_background_texture() == MapCatalog.NIGHT_BACKGROUND)
		view.set_night(false)
		assert(view.get_background_texture() == MapCatalog.BACKGROUND)
	view.size = Vector2(1280, 720)
	await _settle(host)
	var empty := view.image_rect.position + view.image_rect.size * Vector2(0.5, 0.78)
	await _move(host, empty)
	view.buttons.hospital.grab_focus()
	assert(view.active_location().is_empty(), "Automatic focus cannot become a permanent map hover")
	await _click(host, view.region_for("park").get_center())
	assert(selected == ["park"] and view.active_location() == "park")
	await _move(host, empty)
	assert(view.active_location().is_empty(), "A clicked destination stops highlighting after the pointer leaves")
	await _key(host, KEY_TAB)
	view.buttons.bar.grab_focus()
	assert(view.active_location() == "bar", "Keyboard navigation keeps a visible location focus")
	await _move(host, empty)
	assert(view.active_location().is_empty())
	for id: String in MapCatalog.REGIONS:
		if MapCatalog.is_locked(id):
			await _click(host, view.region_for(id).get_center())
	assert(selected == ["park"], "The three locked exits must never emit a travel request")
	view.set_enabled(false)
	view._on_location_pressed("bar")
	assert(selected == ["park"])
	assert(_snapshot() == original, "Map input, weather and layout are read-only")
	view.free()
	await _settle(host)


static func _test_north_road(host: Node) -> void:
	for day in [7, 8]:
		for phase in ["morning", "night"]:
			var home = await _home(host, phase, day)
			home._open_map()
			var world = home.home_map
			var original := _snapshot()
			await _travel(host, world, "north")
			if day < 8:
				assert(world.map_view.map_region == "town")
				assert(world.hub_dialogue.active_line.get("text") == world.NORTH_ROAD_CLOSED_MESSAGE)
				assert(world.hub_dialogue.bubble.is_visible_in_tree() and world.hub_dialogue.bubble.tail_points.is_empty())
			else:
				assert(world.map_view.map_region == "north")
				assert(world.map_view.get_background_texture().resource_path.ends_with("northmapnight.png" if phase == "night" else "northmap.png"))
				assert(world.map_view.weather_effects.weather == "rain")
				assert(not world.map_view.buttons.bar.visible and world.map_view.buttons.town.visible)
				for location_id: String in ["pier", "basketball_court", "construction_site", "school", "big_station", "church", "abandoned_building"]:
					if PlayerState.energy == 0:
						# Refill the fixture to cover all seven destinations within the five-point cap.
						PlayerState.energy = PlayerState.max_energy
						original.energy += PlayerState.max_energy
						original.saves += 1
					var energy_before: int = PlayerState.energy
					await _travel(host, world, location_id)
					assert(PlayerState.energy == energy_before - 1, "Every north destination charges one energy on arrival")
					assert(world.location_view.visible and not world.map_view.visible and world.current_location == location_id)
					assert(world.background.texture is AtlasTexture)
					assert(world.background.texture.atlas == world.map_view.get_background_texture())
					var rain = world.background.get_node("StoryBackgroundWeather")
					assert(rain._effects.is_raining() and not rain._effects.indoor)
					assert(not world.entrance_button.visible and not world.store_button.visible)
					await _key(host, KEY_ESCAPE)
					assert(world.map_view.map_region == "north" and world.map_view.visible)
				await _travel(host, world, "town")
				assert(world.map_view.map_region == "town" and world.visible)
				await _travel(host, world, "north")
				await _key(host, KEY_ESCAPE)
				assert(world.map_view.map_region == "town" and world.visible and not PauseMenuManager.visible)
			if day >= 8:
				original.energy -= 7
				original.saves += 7
			assert(_snapshot() == original, "Only paid destination arrivals spend energy/save; construction speech and region navigation preserve all other state")
			host.get_tree().current_scene = null
			home.free()
			await _settle(host)


static func _test_location_phases(host: Node) -> void:
	for phase in ["morning", "noon", "night", "midnight"]:
		var home = await _home(host, phase)
		PlayerState.stress = 5
		var original := _snapshot()
		var rain_playback: Variant = AmbientAudioManager.rain_player.get_stream_playback()
		await _click(host, home.map_button.get_global_rect().get_center())
		var world = home.home_map
		assert(world.visible and world.map_view.visible and not home.house.enabled)
		assert(world.map_view.is_night == (phase in ["night", "midnight"]))
		assert(world.map_view.weather_effects.weather == "rain")
		await _travel(host, world, "hospital")
		assert(world.location_view.visible and not world.map_view.visible)
		assert(world.background.texture.resource_path.ends_with("hospitalnight.png" if phase in ["night", "midnight"] else "hospitalday.png"))
		var hospital_rain = world.background.get_node("StoryBackgroundWeather")
		assert(hospital_rain._effects.indoor and hospital_rain._effects.is_raining())
		await _key(host, KEY_ESCAPE)
		assert(world.map_view.visible and not PauseMenuManager.visible, "Escape from a location belongs to the map before pause")
		await _travel(host, world, "park")
		assert(world.background.texture.resource_path.ends_with("parknight.png" if phase in ["night", "midnight"] else "park.png"))
		await _key(host, KEY_ESCAPE)
		var location_before_bar: String = world.current_location
		var before_bar := _snapshot()
		await _travel(host, world, "bar")
		if phase in ["morning", "noon"]:
			assert(world.map_view.visible and not world.location_view.visible and not world.inside_bar, "Daytime bar clicks stay on the map")
			assert(world.current_location == location_before_bar and world.map_view.current_location == location_before_bar)
			assert(world.background.texture == null, "A closed bar cannot load or show the destination view")
			assert(world.hub_dialogue.active_line.get("text") == "It's closed. I should try again later.")
			assert(world.hub_dialogue.active_line.get("speaker") == "John Toda" and world.hub_dialogue.bubble.is_visible_in_tree())
			assert(world.hub_dialogue.bubble.tail_points.is_empty(), "John's closed-bar response has no textbox pointer")
			assert(_snapshot() == before_bar, "Closed-bar map clicks cannot change progress, offers, resources, time or saves")
		else:
			assert(world.background.texture.resource_path.ends_with("barnight.png") and world.entrance_button.visible)
			for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(640, 360)]:
				home.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				home.size = viewport_size
				await _settle(host)
				var art_size: Vector2 = world.background.texture.get_size()
				var fit := minf(viewport_size.x / art_size.x, viewport_size.y / art_size.y)
				var expected := Rect2((viewport_size - art_size * fit) * 0.5 + world.BAR_ENTRANCE.position * fit, world.BAR_ENTRANCE.size * fit)
				assert(world.entrance_button.get_rect().is_equal_approx(expected), "The building entrance follows the background letterboxing")
			home.size = Vector2(1280, 720)
			await _settle(host)
			await _click(host, world.entrance_button.get_global_rect().get_center())
			assert(world.inside_bar and world.background.texture.resource_path.ends_with("/bar.png"))
			assert(not world.entrance_button.visible and world.exit_button.visible)
			var indoor_rain = world.background.get_node("StoryBackgroundWeather")
			assert(indoor_rain._effects.indoor and indoor_rain._effects.marker_texture.resource_path.ends_with("barrain_indoor.png"))
			await _key(host, KEY_ESCAPE)
			assert(not world.inside_bar and world.background.texture.resource_path.ends_with("barnight.png"))
			assert(not PauseMenuManager.visible, "The first indoor Escape exits the building without also opening pause")
			await _key(host, KEY_ESCAPE)
		assert(world.map_view.visible and not PauseMenuManager.visible)
		await _key(host, KEY_ESCAPE)
		assert(not world.visible and home.house.enabled and home.map_button.visible and home.status_header.visible)
		assert(not PauseMenuManager.visible, "Closing the map must consume the Escape that closed it")
		assert(AmbientAudioManager.rain_player.get_stream_playback() == rain_playback, "Map and preview travel cannot restart the shared rain loop")
		var paid_arrivals := 3 if phase in ["night", "midnight"] else 2
		original.energy -= paid_arrivals
		original.stress -= 2
		original.saves += paid_arrivals
		assert(_snapshot() == original, "Hospital/Park/open Bar cost one energy each and Park relieves two stress; building entry, closure speech and free hubs preserve remaining state")
		host.get_tree().current_scene = null
		home.free()
		await _settle(host)


static func _test_home_gates(host: Node) -> void:
	var home = await _home(host)
	for action in ["calendar", "radio", "rest"]:
		home._show_info(action)
		home.map_button.pressed.emit()
		assert(not home.home_map.visible, "Map cannot open behind a home modal")
		home._close_info()
	home.HomeTutorial.set_tutorial_active(home, true)
	home.map_button.pressed.emit()
	assert(not home.home_map.visible and home.tutorial_active)
	home.HomeTutorial.end_tutorial(home)
	assert(home.show_message("Wait here.", {"blocking": true, "typewriter": false}))
	await _settle(host)
	home.map_button.pressed.emit()
	assert(not home.home_map.visible, "Blocking dialogue owns input before the map")
	home.hub_dialogue.clear()
	home.is_transitioning = true
	home.map_button.pressed.emit()
	assert(not home.home_map.visible)
	home.is_transitioning = false
	host.get_tree().current_scene = null
	home.free()
	await _settle(host)


static func _test_hub_departures(host: Node) -> void:
	for pickup in ["station", "market", "street"]:
		var home = await _home(host)
		var original := _snapshot(false)
		home._open_map()
		var old_home: WeakRef = weakref(home)
		assert(home.home_map.travel_energy_cost(pickup) == 0)
		await _click(host, home.home_map.map_view.region_for(pickup).get_center())
		var screen = await _await_departure(host, STATION, old_home)
		assert(screen.pickup_location == pickup and PlayerState.get_pending_pickup_location() == pickup)
		assert(_snapshot(false) == original, "All three pickup areas preserve resources, phase and the same assigned offer pool")
		if pickup != "station":
			assert(screen.passenger_overlay.visible and screen.terminal_view.pickup_location == pickup, "Market and Street open their passenger screen directly")
			screen._close_passengers()
			await _settle(host)
			assert(screen.travel_map.visible and screen.travel_map.map_view.visible and screen.travel_map.current_location == pickup)
			await _key(host, KEY_ESCAPE)
			assert(not screen.travel_map.visible and screen.passenger_overlay.visible and not PauseMenuManager.visible, "Map Escape returns to the current pickup screen and consumes its input")
			assert(_snapshot(false) == original)
			screen._close_passengers()
			await _settle(host)
			var old_pickup: WeakRef = weakref(screen)
			await _click(host, screen.travel_map.map_view.region_for("station").get_center())
			screen = await _await_departure(host, STATION, old_pickup)
			assert(screen.pickup_location == "station" and PlayerState.get_pending_pickup_location() == "station", "Station navigation must reset the old pickup area")
			assert(_snapshot(false) == original, "Returning from another pickup area cannot reroll or charge the locked offers")
		host.get_tree().current_scene = null
		screen.free()
		await _settle(host)
	# The market's passenger screen remains a free route to the store at zero energy.
	var home = await _home(host)
	PlayerState.energy = 0
	var original := _snapshot(false)
	home._open_map()
	var old_home: WeakRef = weakref(home)
	await _click(host, home.home_map.map_view.region_for("market").get_center())
	var market = await _await_departure(host, STATION, old_home)
	assert(market.pickup_location == "market" and market.terminal_view.store_button.visible)
	var old_market: WeakRef = weakref(market)
	await _click(host, market.terminal_view.store_button.get_global_rect().get_center())
	var store = await _await_departure(host, STORE, old_market)
	assert(_snapshot(false) == original, "Reaching Store through the market pickup is free even without energy")
	var old_store: WeakRef = weakref(store)
	store._ride()
	var station = await _await_departure(host, STATION, old_store)
	assert(station.pickup_location == "station" and PlayerState.get_pending_pickup_location() == "station")
	assert(_snapshot(false) == original, "Store's station exit returns to Station without charging a ride or retaining Market")
	host.get_tree().current_scene = null
	station.free()
	await _settle(host)


static func _await_departure(host: Node, destination: String, previous: WeakRef) -> Variant:
	if previous.get_ref() != null or host.get_tree().current_scene == null:
		await host.get_tree().scene_changed
	await _settle(host)
	var screen = host.get_tree().current_scene
	assert(screen != null and screen.scene_file_path == destination and previous.get_ref() == null, "A real map departure replaces its previous screen")
	return screen


static func _test_travel_confirmation(host: Node) -> void:
	var home = await _home(host, "night", 8)
	home._open_map()
	var world = home.home_map
	var original := _snapshot()
	await _move(host, world.map_view.region_for("hospital").get_center())
	assert(world.map_view.energy_cursor.visible and world.map_view.energy_cursor_label.text == "-1", "Paid map destinations must show the energy cursor badge")
	await _click(host, world.map_view.region_for("hospital").get_center())
	var dialog = world.travel_confirmation
	assert(dialog.visible and not world.map_view.enabled and world.current_location == "home")
	assert(not world.map_view.energy_cursor.visible and dialog.cancel_button.has_focus())
	assert(dialog.heading_label.text == "Go to Hospital?" and dialog.cost_label.text == "This will cost 1 energy.")
	assert(_snapshot() == original, "Opening a travel confirmation cannot spend energy or save")
	world.map_view.buttons.park.pressed.emit()
	assert(world._pending_destination == "hospital", "Background requests cannot replace a pending trip")
	await _click(host, dialog.cancel_button.get_global_rect().get_center())
	assert(not dialog.visible and world.map_view.visible and world.map_view.enabled and _snapshot() == original)
	await _click(host, world.map_view.region_for("hospital").get_center())
	await _key(host, KEY_ESCAPE)
	assert(not dialog.visible and world.visible and world.map_view.visible and not PauseMenuManager.visible)
	assert(_snapshot() == original, "Escape must cancel travel without closing the map or spending energy")
	await _click(host, world.map_view.region_for("hospital").get_center())
	for dimensions in [Vector2(1280, 720), Vector2(640, 360), Vector2(900, 900)]:
		home.size = dimensions
		await _settle(host)
		var rendered: Rect2 = dialog.panel.get_global_transform() * Rect2(Vector2.ZERO, dialog.panel.size)
		assert(Rect2(Vector2.ZERO, dimensions).grow(0.01).encloses(rendered), "The travel confirmation must fit its viewport")
	home.size = Vector2(1280, 720)
	await _settle(host)
	await _click(host, dialog.confirm_button.get_global_rect().get_center())
	dialog._confirm()
	world._confirm_travel()
	assert(not dialog.visible and world.current_location == "hospital" and world.location_view.visible)
	original.energy -= 1
	original.saves += 1
	assert(_snapshot() == original, "Confirmed travel must charge and save exactly once while preserving other state")
	world._show_map()
	for location_id in ["hospital", "home", "station", "market", "street", "north", "locked_east"]:
		await _move(host, world.map_view.region_for(location_id).get_center())
		assert(not world.map_view.energy_cursor.visible, "Current/free/locked destinations must not show an energy cost")
	PlayerState.current_phase = "morning"
	await _move(host, world.map_view.region_for("bar").get_center())
	assert(not world.map_view.energy_cursor.visible, "The closed daytime bar must not advertise an energy charge")
	PlayerState.energy = 0
	await _click(host, world.map_view.region_for("park").get_center())
	assert(not dialog.visible and world.current_location == "hospital" and PlayerState.energy == 0)
	assert(str(world.hub_dialogue.active_line.get("text", "")).contains("too tired"))
	host.get_tree().current_scene = null
	home.free()
	await _settle(host)


static func _travel(host: Node, world, location_id: String) -> void:
	await _click(host, world.map_view.region_for(location_id).get_center())
	if world.travel_confirmation.visible:
		await _click(host, world.travel_confirmation.confirm_button.get_global_rect().get_center())


static func _click(host: Node, point: Vector2) -> void:
	await _move(host, point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await _settle(host)


static func _move(host: Node, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	host.get_viewport().push_input(event, true)
	await _settle(host)


static func _key(host: Node, key: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await _settle(host)


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
