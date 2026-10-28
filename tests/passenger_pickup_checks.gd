extends RefCounted

const Assignment := preload("res://scripts/ride_selection/passenger_pickup_assignment.gd")
const AreaCatalog := preload("res://scripts/ride_selection/passenger_area_spawn_catalog.gd")
const TerminalCatalog := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")
const TerminalView := preload("res://scripts/ride_selection/terminal_passenger_view.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const SELECTION := "res://scenes/ride_selection.tscn"
const MAIN := "res://scenes/main.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false), "Use the isolated runner to protect real saves")
	_setup()
	_test_assignment()
	_test_preference_trends()
	await _test_rendering(host)
	await _test_selection_and_resume(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: unique stable pickup assignments, day-phase preference trends, exact authored market/street art and alpha targets, night/intro guards, global locked-pool navigation, save resume and confirmed departure costs")


static func _setup() -> void:
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "morning"
	PlayerState.current_stage_type = "short-morning-chill"
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 5
	PlayerState.gas = 80.0
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	PlayerState.rng.seed = 981422


static func _rider(id: String, area := "", variant := "") -> Dictionary:
	var character: Dictionary = PlayerState.get_character_by_id(id)
	character.merge({
		"stage_traffic": "chill",
		"stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_NONE,
		"special_stage_id": "",
	}, true)
	if not area.is_empty():
		character["pickup_location"] = area
		character["pickup_variant"] = variant
	return character


static func _resources() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"stress": PlayerState.stress,
		"hull": PlayerState.hull,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"events": PlayerState.event_values.duplicate(true),
		"rides": PlayerState.character_completed_rides.duplicate(true),
	}


static func _pure_state() -> Dictionary:
	var result := _resources()
	result["rng"] = PlayerState.rng.state
	result["saves"] = int(PlayerState.get_meta("test_save_count", 0))
	return result


static func _trip_fields(pools: Dictionary) -> Dictionary:
	var copy := pools.duplicate(true)
	for distance: String in Assignment.DISTANCES:
		for character: Dictionary in copy.get(distance, []):
			character.erase("pickup_location")
			character.erase("pickup_variant")
	return copy


static func _test_assignment() -> void:
	var pools := {
		"short": [_rider("hana", "street", "reading"), _rider("cel", "street", "back"), _rider("jessa", "street", "left")],
		"medium": [_rider("ely", "market", "default"), _rider("benny", "market", "default"), _rider("alma", "market", "invalid")],
		"long": [_rider("generic_guy", "market", "slot_0"), _rider("generic_vendor", "market", "slot_1"), _rider("hana", "station", "invalid")],
	}
	var original := _pure_state()
	var trip_fields := _trip_fields(pools)
	assert(Assignment.assign(pools, "morning", 3))
	assert(_trip_fields(pools) == trip_fields, "Assigning waiting areas cannot replace passengers or change trip fields")
	assert(pools.long[2].pickup_location == "street" and pools.long[2].pickup_variant == "reading", "Duplicate legacy IDs share one global location and pose")
	assert(pools.medium[2].pickup_location == "station", "Characters without authored local art remain at the station")
	var stable := pools.duplicate(true)
	assert(not Assignment.assign(pools, "morning", 3) and pools == stable, "Assignment must be idempotent")
	assert(not Assignment.assign(pools, "noon", 4) and pools == stable, "Saved locations and valid poses survive reopening rather than rerolling")
	for options in [{"phase": "night", "forced": false}, {"phase": "morning", "forced": true}]:
		var restricted := stable.duplicate(true)
		Assignment.assign(restricted, str(options.phase), 3, bool(options.forced))
		for distance: String in Assignment.DISTANCES:
			for character: Dictionary in restricted[distance]:
				assert(character.pickup_location == "station" and character.pickup_variant.is_empty(), "Night and the forced first ride keep every offer at the station")
	var generic_pools := {"short": [], "medium": [], "long": []}
	for index in range(TerminalCatalog.GENERIC_IDS.size()):
		var id: String = TerminalCatalog.GENERIC_IDS[index]
		var distance := "short" if index < 3 else "medium"
		generic_pools[distance].append(_rider(id, "market", "slot_0"))
	Assignment.assign(generic_pools, "noon", 3)
	var occupied: Dictionary = {}
	for distance: String in Assignment.DISTANCES:
		for character: Dictionary in generic_pools[distance]:
			if character.pickup_location == "market":
				assert(not occupied.has(character.pickup_variant), "Legacy duplicate generic positions must be repaired")
				occupied[character.pickup_variant] = true
	assert(occupied.size() == 3, "Only the three authored market generic spots may be assigned")
	assert(_pure_state() == original, "Pickup assignment cannot consume gameplay RNG, save, advance time or change resources/progress")


static func _test_preference_trends() -> void:
	var original := _pure_state()
	var counts := {"morning": {"street": 0, "market": 0}, "noon": {"street": 0, "market": 0}}
	var poses := {"hana": {}, "cel": {}, "jessa": {}}
	# Fixed dates exercise deterministic local seeds; these are broad directional
	# checks, rather than a random sample or exact-count balance contract.
	for day in range(1, 97):
		for phase: String in ["morning", "noon"]:
			var pools := {
				"short": [_rider("hana"), _rider("cel"), _rider("jessa")],
				"medium": [_rider("ely"), _rider("benny")],
				"long": [],
			}
			Assignment.assign(pools, phase, day)
			for distance: String in Assignment.DISTANCES:
				for character: Dictionary in pools[distance]:
					var area := Assignment.location(character)
					if area != "station":
						counts[phase][area] += 1
					if area == "street" and poses.has(character.id):
						assert(AreaCatalog.variant_ids("street", str(character.id)).has(character.pickup_variant))
						poses[character.id][character.pickup_variant] = true
	assert(counts.morning.street > counts.noon.street + 40, "Street riders should be substantially more frequent in the morning")
	assert(counts.noon.market > counts.morning.market + 40, "Elena and Benny should favor the market at noon")
	for id: String in poses:
		assert(poses[id].size() == 2, "Both authored poses should be reachable without duplicating a named passenger")
	assert(_pure_state() == original)


static func _offer(id: String, variant: String, slot: int) -> Dictionary:
	var character := _rider(id)
	character["pickup_variant"] = variant
	return {"character": character, "distance": "short", "slot": slot, "details": id}


static func _test_rendering(host: Node) -> void:
	var original := _pure_state()
	var view := TerminalView.new()
	host.get_tree().root.add_child(view)
	for area: String in ["market", "street"]:
		var offers: Array[Dictionary] = []
		for id: String in AreaCatalog.named_ids(area):
			var variants := AreaCatalog.variant_ids(area, id)
			for variant: String in variants:
				var art := AreaCatalog.entry(area, id, false, variant)
				assert(art.texture.get_size() == art.region.size, "Every alternate keeps its own authored scale")
				assert(Rect2(Vector2.ZERO, AreaCatalog.ART_SIZE).encloses(art.region))
				assert(AreaCatalog.entry(area, id, true, variant).is_empty())
			offers.append(_offer(id, variants.back(), offers.size()))
		for slot in range(AreaCatalog.generic_count(area)):
			offers.append(_offer(TerminalCatalog.GENERIC_IDS[slot], "slot_%d" % slot, offers.size()))
		if area == "street":
			offers.append(_offer("jessa", "left", offers.size()))
		view.set_pickup_location(area)
		view.set_offers(offers, false)
		assert(view.get_background_texture() == AreaCatalog.background(area, false))
		assert(view.buttons.size() == AreaCatalog.named_ids(area).size() + AreaCatalog.generic_count(area), "One named rider cannot render both alternate poses at once")
		for dimensions in [Vector2(1280, 720), Vector2(640, 360)]:
			view.size = dimensions
			view._layout()
			for id: String in view.buttons:
				var button = view.buttons[id]
				var variant: String = view._offers[id].character.pickup_variant
				var art := AreaCatalog.generic_entry(area, variant.trim_prefix("slot_").to_int()) if id.begins_with("generic_") else AreaCatalog.entry(area, id, false, variant)
				assert(button.source_region == art.region and button.texture == art.texture)
				var normalized: Rect2 = view.region_for(id)
				assert(button.position.is_equal_approx(view.image_rect.position + normalized.position * view.image_rect.size))
				assert(button.size.is_equal_approx(normalized.size * view.image_rect.size))
				_assert_alpha_target(button)
		view.set_weather("rain")
		assert(view.weather_effects.marker_texture == (view.MARKET_RAIN_MARKER if area == "market" else null))
		view.set_offers(offers, true)
		assert(view.get_background_texture() == AreaCatalog.background(area, true) and view.buttons.is_empty(), "Night renders the area background without day passengers or placeholder riders")
		assert(not view.object_rect_for("trashcan").has_area(), "Terminal objects cannot acquire clickboxes in another pickup area")
	view.free()
	await host.get_tree().process_frame
	assert(_pure_state() == original, "Layout, weather and sprite inspection must not change game state")


static func _assert_alpha_target(button) -> void:
	assert(not button.is_placeholder and button.alpha_image != null)
	var image: Image = button.alpha_image
	var body_found := false
	var gap_found := false
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var point: Vector2 = Vector2(x + 0.5, y + 0.5) / Vector2(image.get_size()) * button.size
			var hit := bool(button.call("_has_point", point))
			# Market silhouettes are authored translucent rather than fully opaque.
			body_found = body_found or (image.get_pixel(x, y).a >= 0.8 and hit)
			gap_found = gap_found or not hit
			if body_found and gap_found:
				return
	assert(false, "Passenger bodies must be clickable while transparent canvas/shadows are excluded: %s (body=%s, gap=%s)" % [button.name, body_found, gap_found])


static func _test_selection_and_resume(host: Node) -> void:
	_setup()
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", PlayerState.TRANSITION_CURRENT_STAGE, true)
	var pools := {
		"short": [_rider("generic_guy", "station")],
		"medium": [_rider("benny", "market", "default")],
		"long": [_rider("hana", "street", "reading")],
	}
	PlayerState.lock_pending_trip_selection(pools, "short")
	var resources := _resources()
	var visited: Dictionary = {}
	for area: String in ["station", "market", "street"]:
		PlayerState.set_pending_pickup_location(area)
		var selection = load(SELECTION).instantiate()
		host.get_tree().root.add_child(selection)
		await host.get_tree().process_frame
		selection._open_passengers()
		assert(selection.pickup_location == area and selection.passenger_overlay.visible)
		assert(selection.view.offers().size() == 3 and selection.terminal_offers.size() == 1, "Location views filter one shared global pool")
		for offer: Dictionary in selection.terminal_offers:
			var id := str(offer.character.id)
			assert(not visited.has(id), "A named or generic offer may only appear at one waiting area")
			visited[id] = true
		assert(selection.locked_character_pools == pools and PlayerState.get_locked_pending_trip_character_pools() == pools)
		assert(_resources() == resources, "Visiting another selection view cannot reroll trips or charge activity resources")
		selection._close_passengers(false)
		selection.free()
		await host.get_tree().process_frame
	assert(visited.size() == 3)
	Codec.save_to_path(PlayerState, "res://test_user/passenger_pickups.tres", PlayerState.SAVE_VERSION)
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/passenger_pickups.tres"))
	assert(PlayerState.get_pending_pickup_location() == "street" and PlayerState.get_locked_pending_trip_character_pools() == pools)
	assert(_resources() == resources, "Save/load must retain global assignments, exact variants and independent resource values")
	var selection = load(SELECTION).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	assert(selection.pickup_location == "street" and selection.terminal_view.buttons.has("hana"))
	var original := _pure_state()
	var pending: Dictionary = PlayerState.get_pending_trip_selection()
	selection._choose_offer("long", 0)
	assert(selection.confirmation.visible and not selection.is_departing)
	assert(_pure_state() == original and PlayerState.get_pending_trip_selection() == pending, "Inspecting an away-from-station passenger remains unpaid until confirmation")
	selection._cancel_passenger()
	assert(_pure_state() == original and PlayerState.get_pending_trip_selection() == pending)
	selection._choose_offer("long", 0)
	selection.confirmation.confirm_button.pressed.emit()
	selection._confirm_passenger()
	await host.get_tree().scene_changed
	var game = host.get_tree().current_scene
	game.set_process(false)
	assert(game.scene_file_path == MAIN and PlayerState.current_mock_character_id == "hana")
	assert(PlayerState.current_stage_type == "long-morning-chill")
	assert(PlayerState.energy == int(resources.energy) - 1 and PlayerState.stress == mini(PlayerState.max_stress, int(resources.stress) + Tuning.TRIP_STRESS_GAIN))
	assert(PlayerState.stage_round == int(resources.round) + 1 and PlayerState.money == resources.money)
	assert(PlayerState.pending_trip_selection.is_empty() and not PlayerState.pending_stage_energy_cost, "The real departure consumes one entry cost and clears the shared waiting pool")
	host.get_tree().current_scene = null
	game.free()
	selection.free()
	await host.get_tree().process_frame
