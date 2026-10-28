extends RefCounted

const StationView := preload("res://scripts/ui/station_view.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_hotspots(host)
	await _test_pointer_focus(host)
	await _test_intro_handoff(host)
	await _test_passenger_tutorial_input_and_exit(host)
	await _test_modal_and_resume(host)
	await _test_terminal_header(host)
	await _test_store_navigation(host)
	PlayerState.reset()
	print("PASS: separate station terminal/map/store hotspots, pointer/keyboard highlights, cost-free map open/close, shared status header, day/night resizing, tutorial gating, locked-offer save/resume and store navigation")


static func _test_intro_handoff(host: Node) -> void:
	var previous_language := StoryLanguageManager.get_language()
	for language in ["english", "tagalog"]:
		PlayerState.reset()
		StoryLanguageManager.set_language(language)
		var energy: int = PlayerState.energy
		var gas: float = PlayerState.gas
		var payload := PayloadCatalog.build("scene_01_intro", "res://scenes/day_start_scene.tscn", PlayerState.FIRST_STAGE_TYPE)
		# Resume at the final authored line, then use its normal Continue handoff.
		PlayerState.set_last_seen_story_section("scene_01_intro", payload.composition.size() - 1)
		var reader = await host._reader(payload)
		await reader._advance_story()
		await host.get_tree().scene_changed
		if host.get_tree().current_scene == null or host.get_tree().current_scene.scene_file_path != SELECTION_SCENE:
			await host.get_tree().scene_changed
		var selection = host.get_tree().current_scene
		await host.get_tree().process_frame
		assert(selection.scene_file_path == SELECTION_SCENE)
		assert(not selection.passenger_overlay.visible and not selection.terminal_view.is_visible_in_tree(), "The prologue must arrive at the station front in both languages")
		assert(selection.station_tutorial.active and not selection.tutorial.active and not selection.station.enabled)
		assert(not selection.terminal_view.enabled)
		for passenger: Button in selection.terminal_view.buttons.values():
			assert(passenger.disabled, "Tutorial input cannot start a passenger ride")
		assert(not bool(PlayerState.get_pending_trip_selection().get("passengers_open", false)))
		assert(PlayerState.get_current_day() == 1 and PlayerState.get_current_time_of_day() == "morning" and PlayerState.stage_round == 0)
		assert(PlayerState.energy == energy - 1 and PlayerState.gas == gas, "Only the existing intro entry cost applies; station navigation cannot charge again")
		var original := _snapshot()
		var pools: Dictionary = selection.locked_character_pools.duplicate(true)
		for action in ["map", "store", "passengers"]:
			selection._on_station_action(action)
		selection._open_passengers()
		selection._open_store()
		selection._open_map()
		selection._go_back()
		assert(selection.station_tutorial.active and not selection.is_departing and not selection.travel_map.visible and not selection.passenger_overlay.visible, "Station onboarding blocks background navigation")
		for index in range(selection.station_tutorial.steps.size() - 1):
			selection.station_tutorial.advance()
		assert(selection.station_tutorial.active and str(selection.station_tutorial.steps[selection.station_tutorial.step_index].get("interaction", "")) == "terminal")
		await _click(host, selection.station.image_rect.position + Vector2(0.15, 0.80) * selection.station.image_rect.size)
		for pressed in [true, false]:
			var wrong_key := InputEventKey.new()
			wrong_key.keycode = KEY_Q
			wrong_key.physical_keycode = KEY_Q
			wrong_key.pressed = pressed
			host.get_viewport().push_input(wrong_key, true)
			await host.get_tree().process_frame
		assert(selection.station_tutorial.active and not selection.passenger_overlay.visible, "The last station step requires the terminal instead of an unrelated click/key")
		await _click(host, selection.station.image_rect.position + Vector2(0.25, 0.35) * selection.station.image_rect.size)
		assert(not selection.station_tutorial.active and selection.passenger_overlay.visible and selection.tutorial.active, "Clicking the terminal starts its passenger tutorial")
		assert(bool(PlayerState.get_event_value(selection.STATION_TUTORIAL_EVENT, false)))
		assert(not PlayerState.has_ride_select_tutorial_shown(), "Passenger onboarding is only marked complete after its final step")
		assert(PlayerState.get_pending_trip_selection().passengers_open)
		assert(_snapshot() == original and selection.locked_character_pools == pools, "The station-to-terminal tutorial transition preserves resources, time and locked offers")
		host.get_tree().current_scene = null
		selection.free()
		reader.free()
	StoryLanguageManager.set_language(previous_language)


static func _test_passenger_tutorial_input_and_exit(host: Node) -> void:
	for input_mode in ["mouse", "keyboard"]:
		_setup(PlayerState.TRANSITION_CURRENT_STAGE)
		PlayerState.ride_select_tutorial_shown = false
		var selection = load(SELECTION_SCENE).instantiate()
		host.get_tree().root.add_child(selection)
		selection._open_passengers()
		await host.get_tree().process_frame
		var tutorial = selection.tutorial
		assert(tutorial.active and tutorial.step_index == 0 and not PlayerState.has_ride_select_tutorial_shown())
		var original: Array = _snapshot() + [PlayerState.stress, PlayerState.hull]
		var pools: Dictionary = selection.locked_character_pools.duplicate(true)
		var rng_state: int = selection.passenger_pool.rng.state
		var saves := int(PlayerState.get_meta("test_save_count", 0))
		await _click(host, Vector2(20, 710))
		assert(tutorial.step_index == 0 and not selection.confirmation.visible, "Inspecting a tutorial passenger requires its own hitbox")
		if input_mode == "mouse":
			await _click(host, _passenger_point(tutorial._passenger))
		else:
			await _accept(host)
		assert(tutorial.step_index == 1 and selection.terminal_view.info_panel.visible, "Inspecting a passenger opens the real offer preview without accepting it")
		for dimensions in [Vector2(1280, 720), Vector2(640, 360), Vector2(900, 900)]:
			selection.size = dimensions
			await host.get_tree().process_frame
			await host.get_tree().process_frame
			var bounds := Rect2(selection.global_position, dimensions)
			assert(bounds.grow(0.01).encloses(tutorial.text_panel.get_global_rect()), "Passenger tutorial text must fit after resizing")
			assert(bounds.grow(0.01).encloses(tutorial.highlight.get_global_rect()), "Passenger tutorial highlights must fit after resizing")
		selection.size = Vector2(1280, 720)
		await host.get_tree().process_frame
		while tutorial.step_index < tutorial.steps.size() - 1:
			await _accept(host)
		await _click(host, Vector2(20, 710))
		assert(tutorial.active and not PlayerState.has_ride_select_tutorial_shown() and not selection.confirmation.visible, "An unrelated click cannot finish passenger onboarding or accept a ride")
		assert(_snapshot() + [PlayerState.stress, PlayerState.hull] == original and selection.locked_character_pools == pools)
		assert(int(PlayerState.get_meta("test_save_count", 0)) == saves, "Explanation and preview steps must not write progress")
		if input_mode == "mouse":
			await _click(host, _passenger_point(tutorial._passenger))
		else:
			await _accept(host)
		assert(not tutorial.active and PlayerState.has_ride_select_tutorial_shown() and selection.confirmation.visible, "The final passenger click/Enter finishes onboarding and opens normal confirmation")
		assert(_snapshot() + [PlayerState.stress, PlayerState.hull] == original and selection.locked_character_pools == pools and selection.passenger_pool.rng.state == rng_state, "Completing onboarding cannot charge, advance time or reroll offers before confirmation")
		selection._cancel_passenger()
		selection.free()
		await host.get_tree().process_frame
	_setup(PlayerState.TRANSITION_CURRENT_STAGE)
	PlayerState.ride_select_tutorial_shown = false
	var exiting = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(exiting)
	exiting._open_passengers()
	var pending_tutorial = exiting.tutorial
	assert(host.get_tree().process_frame.is_connected(pending_tutorial._relayout_current_step))
	exiting.free()
	assert(not pending_tutorial.active and not host.get_tree().process_frame.is_connected(pending_tutorial._relayout_current_step), "Discarding an active tutorial must remove its deferred layout callback")
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _passenger_point(passenger: Control) -> Vector2:
	for y in range(1, 10):
		for x in range(1, 10):
			var local_point := passenger.size * Vector2(x / 10.0, y / 10.0)
			if bool(passenger.call("_has_point", local_point)):
				return passenger.get_global_transform() * local_point
	assert(false, "The tutorial passenger needs a visible clickable point")
	return Vector2.ZERO


static func _accept(host: Node) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame


static func _test_hotspots(host: Node) -> void:
	var station := StationView.new()
	host.get_tree().root.add_child(station)
	station.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	assert(StationView.DAY.get_size() == StationView.ART_SIZE)
	assert(StationView.NIGHT.get_size() == StationView.ART_SIZE)
	assert(StationView.DAY_SELECTED.get_size() == StationView.ART_SIZE)
	assert(StationView.NIGHT_SELECTED.get_size() == StationView.ART_SIZE)
	for night in [false, true]:
		station.set_night(night)
		for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
			station.size = viewport_size
			station._layout()
			var image: Rect2 = station.image_rect
			assert(image.position.x >= -0.01 and image.position.y >= -0.01)
			assert(image.end.x <= viewport_size.x + 0.01 and image.end.y <= viewport_size.y + 0.01)
			assert(_hit(station, "store", Vector2(0.02, 0.40)), "The left-edge entrance opens the store")
			assert(not _hit(station, "passengers", Vector2(0.02, 0.40)), "The store entrance must not open passengers")
			assert(not _hit(station, "map", Vector2(0.02, 0.40)), "The store entrance must not open the map")
			assert(_hit(station, "map", Vector2(0.75, 0.72)), "The foreground tricycle opens the map")
			assert(not _hit(station, "passengers", Vector2(0.75, 0.72)), "The foreground tricycle must not open passengers")
			assert(not _hit(station, "store", Vector2(0.75, 0.72)), "The foreground tricycle must not open the store")
			assert(_hit(station, "map", Vector2(0.90, 0.08)), "The upper canopy is part of the tricycle")
			assert(not _hit(station, "map", Vector2(0.75, 0.30)), "The gap below the canopy is not clickable")
			assert(_hit(station, "passengers", Vector2(0.25, 0.35)), "The terminal waiting area opens passenger selection")
			assert(not _hit(station, "map", Vector2(0.25, 0.35)) and not _hit(station, "store", Vector2(0.25, 0.35)), "Terminal clicks cannot activate the tricycle or store")
			assert(not _hit(station, "store", Vector2(0.04, 0.40)), "The pole beside the outlined entrance is not clickable")
			assert(not _hit(station, "store", Vector2(0.02, 0.12)), "The tree above the entrance is not clickable")
			assert(not _hit(station, "store", Vector2(0.47, 0.20)), "The previous upper-building hotspot is no longer active")
			for action in ["map", "passengers", "store"]:
				assert(not _hit(station, action, Vector2(0.15, 0.80)), "Empty road must not activate a hotspot")
				assert(not Geometry2D.triangulate_polygon(station.polygon_for(action)).is_empty())
				for other in ["map", "passengers", "store"]:
					if action != other:
						assert(Geometry2D.intersect_polygons(station.polygon_for(action), station.polygon_for(other)).is_empty(), "Station destinations must have disjoint hit polygons")
				if action == "passengers":
					continue
				var highlights: Array[PackedVector2Array] = station._highlight_polygons(action)
				assert(not highlights.is_empty())
				for polygon in highlights:
					assert(not Geometry2D.triangulate_polygon(polygon).is_empty())
					for point in polygon:
						assert(Rect2(Vector2.ZERO, Vector2.ONE).grow(0.0001).has_point(point), "Hover art must stay inside the image, including letterboxed layouts")
		for action in ["map", "passengers", "store"]:
			var day_polygon: PackedVector2Array = station.polygon_for(action)
			station.set_night(not night)
			assert(station.polygon_for(action) == day_polygon, "Day and night use identical selection areas")
			station.set_night(night)
	station.buttons.store.mouse_entered.emit()
	assert(station.hovered_action == "store")
	station.buttons.store.mouse_exited.emit()
	assert(station.hovered_action.is_empty())
	station.buttons.passengers.focus_entered.emit()
	assert(station.focused_action == "passengers")
	assert(station.active_action().is_empty(), "Automatic focus must not look like a pointer hover")
	station.set_enabled(false)
	assert(station.hovered_action.is_empty() and station.focused_action.is_empty())
	for button: Button in station.buttons.values():
		assert(button.disabled)
	station.set_enabled(true)
	for button: Button in station.buttons.values():
		assert(not button.disabled)
	station.free()


static func _test_pointer_focus(host: Node) -> void:
	var station := StationView.new()
	host.get_tree().root.add_child(station)
	station.size = Vector2(1280, 720)
	await host.get_tree().process_frame
	for night in [false, true]:
		station.set_night(night)
		var empty: Vector2 = station.image_rect.position + Vector2(0.15, 0.80) * station.image_rect.size
		var tricycle: Vector2 = station.image_rect.position + Vector2(0.75, 0.72) * station.image_rect.size
		var terminal: Vector2 = station.image_rect.position + Vector2(0.25, 0.35) * station.image_rect.size
		await _move(host, empty)
		station.buttons.map.grab_focus()
		assert(station.active_action().is_empty(), "A focused tricycle cannot stay highlighted while the pointer is on empty road")
		await _click(host, tricycle)
		assert(station.active_action() == "map")
		await _move(host, empty)
		assert(station.active_action().is_empty(), "Moving off a clicked tricycle must clear its highlight")
		await _click(host, terminal)
		assert(station.active_action() == "passengers", "The terminal has its own passenger hover target")
		await _move(host, empty)
		assert(station.active_action().is_empty(), "Moving off the terminal clears its custom highlight")
		await _tab(host)
		assert(station.is_keyboard_navigation() and not station.active_action().is_empty(), "Intentional keyboard navigation retains a visible focus target")
		await _move(host, empty)
		assert(not station.is_keyboard_navigation() and station.active_action().is_empty(), "Pointer input must stop displaying the old keyboard focus")
		station.set_enabled(false)
		station.set_enabled(true)
		station.buttons.map.grab_focus()
		assert(station.active_action().is_empty(), "Re-enabling the station cannot turn its restored focus into hover")
	station.free()


static func _hit(station, action: String, normalized: Vector2) -> bool:
	var point: Vector2 = station.image_rect.position + normalized * station.image_rect.size
	var button: Button = station.buttons[action]
	return bool(button.call("_has_point", point - button.position))


static func _setup(mode := "current_stage", allow_back := true) -> void:
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
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", mode, allow_back)
	var character: Dictionary = PlayerState.get_character_by_id("jessa")
	character["active_distance"] = "medium"
	character["stage_traffic"] = "traffic-jam"
	character["stage_special_type"] = PlayerState.STAGE_SPECIAL_TYPE_NONE
	character["special_stage_id"] = ""
	character["pickup_location"] = "station"
	character["pickup_variant"] = ""
	PlayerState.lock_pending_trip_selection({
		"short": [character.duplicate(true), {}, {}],
		"medium": [character.duplicate(true), {}, {}],
		"long": [character.duplicate(true), {}, {}],
	}, "medium")


static func _snapshot() -> Array:
	return [
		PlayerState.get_current_day(),
		PlayerState.get_current_time_of_day(),
		PlayerState.stage_round,
		PlayerState.money,
		PlayerState.energy,
		PlayerState.stress,
		PlayerState.hull,
		PlayerState.gas,
		PlayerState.pending_stage_energy_cost,
		PlayerState.last_rest_day,
	]


static func _test_terminal_header(host: Node) -> void:
	_setup(PlayerState.TRANSITION_REST_TO_NIGHT)
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	var header = selection.status_header
	var original: Array = _snapshot()
	var style: StyleBox = header.get_theme_stylebox("panel")
	assert(header.day_label.text == "DAY 3 / Noon")
	selection._open_passengers()
	await host.get_tree().process_frame
	assert(header == selection.status_header and header.is_visible_in_tree(), "Passengers reuse the station's status header")
	assert(header.get_theme_stylebox("panel") == style)
	assert(header.day_label.text == "DAY 3 / Night", "The header previews the selected trip phase without advancing time")
	assert(header.z_index > selection.passenger_overlay.z_index)
	var stats: Dictionary = header.stats_refs
	assert(stats.money_label.text == "Money: PhP 500")
	assert(stats.energy_label.text == "%d/%d" % [PlayerState.energy, PlayerState.max_energy])
	assert(stats.gas_label.text == PlayerState.gas_text())
	var icon_paths: Array[String] = []
	for child in stats.row.get_children():
		if child is TextureRect:
			icon_paths.append(child.texture.resource_path)
	assert(icon_paths.has("res://assets/ui/icons/energy_lightning.svg") and icon_paths.has("res://assets/ui/icons/gas_pump.svg"), "Energy and fuel keep the shared header icons")
	assert(_snapshot() == original)
	PlayerState.add_money(17)
	PlayerState.add_energy(1)
	PlayerState.add_gas(2.0)
	assert(stats.money_label.text == "Money: PhP 517")
	assert(stats.energy_label.text == "%d/%d" % [PlayerState.energy, PlayerState.max_energy])
	assert(stats.gas_label.text == PlayerState.gas_text())
	assert(header.day_label.text == "DAY 3 / Night", "Live resource refreshes preserve the trip phase preview")
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		selection.size = viewport_size
		await host.get_tree().process_frame
		assert(is_equal_approx(header.position.x + header.size.x * 0.5, viewport_size.x * 0.5))
		assert(selection.status_label.position.y >= header.position.y + header.size.y, "Actionable passenger errors must sit below the shared header")
	selection._close_passengers()
	assert(header.is_visible_in_tree() and header.day_label.text == "DAY 3 / Noon")
	selection.free()


static func _test_modal_and_resume(host: Node) -> void:
	_setup(PlayerState.TRANSITION_CURRENT_STAGE, false)
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	var original: Array = _snapshot()
	var pools: Dictionary = selection.locked_character_pools.duplicate(true)
	assert(not selection.passenger_overlay.visible and not selection.terminal_view.is_visible_in_tree())
	assert(selection.station.enabled and not selection.tutorial.active)
	selection._choose_character(0)
	assert(_snapshot() == original and not selection.is_departing, "Hidden passengers cannot start a ride")
	var tricycle_point: Vector2 = selection.station.image_rect.position + Vector2(0.75, 0.72) * selection.station.image_rect.size
	var pending := PlayerState.get_pending_trip_selection()
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	var pool_rng: int = selection.passenger_pool.rng.state
	await _click(host, tricycle_point)
	assert(selection.travel_map.visible and selection.travel_map.map_view.visible, "Clicking the foreground tricycle opens the town map")
	assert(selection.travel_map.current_location == "station" and selection.travel_map.map_view.current_location == "station", "Station travel starts at the station")
	assert(not selection.passenger_overlay.visible and not selection.station.enabled and not selection.status_header.visible)
	selection.station.action_pressed.emit("passengers")
	assert(not selection.passenger_overlay.visible, "The open map blocks station actions behind it")
	await _click(host, selection.travel_map.map_view.back_button.get_global_rect().get_center())
	assert(not selection.travel_map.visible and selection.station.enabled and selection.status_header.visible, "Closing the map returns to the station street")
	assert(not selection.passenger_overlay.visible and selection.station_back_button.visible and selection.station_back_button.text == "MAP", "The station map stays available even when the legacy return destination is restricted")
	assert(_snapshot() == original and selection.locked_character_pools == pools and PlayerState.get_pending_trip_selection() == pending, "Opening and closing the map cannot charge, advance time or replace locked offers")
	assert(selection.passenger_pool.rng.state == pool_rng and int(PlayerState.get_meta("test_save_count", 0)) == saves, "Map browsing cannot reroll passengers or save progression")
	var terminal_point: Vector2 = selection.station.image_rect.position + Vector2(0.25, 0.35) * selection.station.image_rect.size
	await _click(host, terminal_point)
	assert(selection.passenger_overlay.visible and selection.terminal_view.visible)
	assert(not selection.station.enabled)
	assert(selection.terminal_view.active_offer_id().is_empty() and selection.terminal_view.info_label.text.is_empty(), "Mouse entry cannot automatically hover the first passenger")
	assert(selection.terminal_view.buttons.size() == 1, "Repeated saved offers cannot spawn duplicate copies of the same character")
	assert(PlayerState.get_pending_trip_selection().passengers_open)
	assert(selection.terminal_view.close_button.visible and selection.terminal_view.close_button.text == "MAP", "Passenger selection keeps map travel available independently of legacy return restrictions")
	selection._set_distance("long")
	assert(selection.passenger_overlay.visible and selection.selected_distance == "long", "Saved distance selection must not close the terminal or reroll its offers")
	await _move(host, Vector2(320, 576))
	selection._handle_back_button_pressed()
	assert(not selection.passenger_overlay.visible and selection.station.enabled)
	assert(selection.station.active_action().is_empty(), "Closing passengers over empty road cannot leave the restored tricycle focus highlighted")
	assert(not bool(PlayerState.get_pending_trip_selection().get("passengers_open", false)))
	assert(_snapshot() == original and selection.locked_character_pools == pools)
	selection.station.buttons.passengers.pressed.emit()
	assert(selection.selected_distance == "long" and selection.locked_character_pools == pools)
	assert(selection.terminal_view.active_offer_id().is_empty() and selection.terminal_view.info_label.text.is_empty(), "Reopening in mouse mode cannot pin passenger details")
	Codec.save_to_path(PlayerState, "res://test_user/station_open_passengers.tres", PlayerState.SAVE_VERSION)
	selection.free()
	assert(Codec.load_from_path(PlayerState, "res://test_user/station_open_passengers.tres"))
	selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	assert(selection.passenger_overlay.visible and selection.terminal_view.visible)
	assert(selection.terminal_view.active_offer_id().is_empty(), "Restoring an open terminal must not invent a hovered passenger")
	assert(selection.selected_distance == "long" and selection.locked_character_pools == pools)
	assert(_snapshot() == original, "Restoring an open passenger screen cannot pay or advance a trip")
	selection._close_passengers()
	selection.free()


static func _click(host: Node, point: Vector2) -> void:
	await _move(host, point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame


static func _move(host: Node, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	host.get_viewport().push_input(motion, true)
	await host.get_tree().process_frame


static func _tab(host: Node) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await host.get_tree().process_frame


static func _test_store_navigation(host: Node) -> void:
	_setup(PlayerState.TRANSITION_REST_TO_NIGHT)
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	var original := _snapshot()
	var pools: Dictionary = selection.locked_character_pools.duplicate(true)
	assert(selection.station.is_night, "The station matches the selected trip's projected phase")
	var store_point: Vector2 = selection.station.image_rect.position + Vector2(0.02, 0.40) * selection.station.image_rect.size
	await _click(host, store_point)
	if host.get_tree().current_scene == null or host.get_tree().current_scene.scene_file_path != STORE_SCENE:
		await host.get_tree().scene_changed
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == STORE_SCENE)
	assert(_snapshot() == original)
	assert(PlayerState.get_locked_pending_trip_character_pools() == pools)
	assert(PlayerState.get_pending_trip_selection().transition_mode == PlayerState.TRANSITION_REST_TO_NIGHT)
	store.street.buttons.station.pressed.emit()
	await host.get_tree().scene_changed
	var returned = host.get_tree().current_scene
	assert(returned.scene_file_path == SELECTION_SCENE)
	assert(not returned.passenger_overlay.visible and returned.station.enabled)
	assert(returned.station.is_night and returned.selected_distance == "medium")
	assert(returned.locked_character_pools == pools)
	assert(PlayerState.get_pending_trip_selection().transition_mode == PlayerState.TRANSITION_REST_TO_NIGHT)
	assert(_snapshot() == original, "Walking to the store and back cannot grant rest, charge entry, or advance time")
	host.get_tree().current_scene = null
	returned.free()
	selection.free()
