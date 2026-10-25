extends RefCounted

const SpawnCatalog := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")
const TerminalView := preload("res://scripts/ride_selection/terminal_passenger_view.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SELECTION_SCENE := "res://scenes/ride_selection.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_catalog()
	await _test_generic_lineups(host)
	await _test_hover_input_modes(host)
	await _test_all_offers(host)
	await _test_schedules(host)
	await _test_legacy_lock_repair(host)
	PlayerState.reset()
	print("PASS: terminal character/generic crops, all-distance spawns, vacant generic slots and overflow, alpha picking, stable placements, hover isolation, projected schedules, legacy lock repair and blocked ride clicks")


static func _test_catalog() -> void:
	assert(SpawnCatalog.SPRITES.size() == 10)
	assert(SpawnCatalog.SPRITES.cel.resource_path.ends_with("celiasprite.png"))
	assert(SpawnCatalog.SPRITES.ely.resource_path.ends_with("elenasprite.png"))
	assert(SpawnCatalog.SPRITES.faye.resource_path.ends_with("magdasprite.png"))
	assert(SpawnCatalog.SPRITES.ito.resource_path.ends_with("isidrosprite.png"))
	var day_ids := ["faye", "ely", "gardo", "ito", "cel", "hana", "benny", "jessa", "alma"]
	var night_ids := ["dante", "gardo", "cel", "hana", "jessa", "alma", "faye"]
	for night in [false, true]:
		var ids: Array = night_ids if night else day_ids
		var previous_x := -1.0
		for character_id: String in ids:
			var entry: Dictionary = SpawnCatalog.entry(character_id, night)
			assert(not entry.is_empty())
			var region: Rect2 = entry.region
			var texture: Texture2D = entry.texture
			assert(region.position.x > previous_x, "Characters must retain the left-to-right order on the authored layout")
			previous_x = region.position.x
			assert(Rect2(Vector2.ZERO, SpawnCatalog.ART_SIZE).encloses(region))
			assert(texture.get_size() == region.size, "Segmented sprites retain their original size and canvas offset")
			assert(texture.get_image().get_used_rect().has_area())
		for character_id: String in SpawnCatalog.SPRITES:
			assert(SpawnCatalog.entry(character_id, night).is_empty() == (not ids.has(character_id)))
	assert(SpawnCatalog.entry("generic_worker", false).is_empty())
	assert(SpawnCatalog.entry("missing_character", true).is_empty())
	var copy: Dictionary = SpawnCatalog.entry("cel", false)
	copy.region = Rect2()
	assert(SpawnCatalog.entry("cel", false).region.has_area(), "A presentation lookup cannot modify the shared placements")
	assert(SpawnCatalog.GENERIC_ENTRIES.size() == 8 and SpawnCatalog.GENERIC_IDS.size() == 6)
	var previous_generic_x := -1.0
	for slot in range(SpawnCatalog.GENERIC_ENTRIES.size()):
		var generic: Dictionary = SpawnCatalog.generic_entry(slot)
		var region: Rect2 = generic.region
		var texture: Texture2D = generic.texture
		assert(region.position.x > previous_generic_x)
		previous_generic_x = region.position.x
		assert(Rect2(Vector2.ZERO, SpawnCatalog.ART_SIZE).encloses(region))
		assert(texture.get_size() == region.size and texture.get_image().get_used_rect().has_area())
		generic.region = Rect2()
		assert(SpawnCatalog.generic_entry(slot).region.has_area(), "Generic presentation lookups cannot modify shared slots")
	assert(SpawnCatalog.generic_entry(-1).is_empty() and SpawnCatalog.generic_entry(8).is_empty())
	for character_id: String in SpawnCatalog.GENERIC_IDS:
		assert(bool(PlayerState.get_character_by_id(character_id).get("is_generic", false)), "Generic art must preserve the existing six passenger IDs")


static func _offer(character_id: String, slot: int) -> Dictionary:
	return {
		"character": {"id": character_id},
		"distance": "short",
		"slot": slot,
		"details": character_id,
	}


static func _test_generic_lineups(host: Node) -> void:
	var view := TerminalView.new()
	host.get_tree().root.add_child(view)
	view.size = Vector2(1280, 720)
	for night in [false, true]:
		var offers: Array[Dictionary] = [_offer("gardo", 0), _offer("cel", 1)]
		if night:
			offers.append(_offer("dante", 2))
		for character_id: String in SpawnCatalog.GENERIC_IDS:
			offers.append(_offer(character_id, offers.size()))
		view.set_offers(offers, night)
		assert(view.buttons.size() == offers.size())
		var original_positions: Dictionary = {}
		for character_id: String in view.buttons:
			var button = view.buttons[character_id]
			original_positions[character_id] = button.source_region
			assert(not button.is_placeholder and button.texture != null and button.alpha_image != null)
			assert(_has_opaque_target(button), "Every named or generic passenger needs an opaque clickable body")
			if not SpawnCatalog.GENERIC_IDS.has(character_id):
				assert(button.source_region == SpawnCatalog.entry(character_id, night).region, "Generic assignment cannot move named characters")
		for character_id: String in SpawnCatalog.GENERIC_IDS:
			var generic = view.buttons[character_id]
			assert(generic.source_region != SpawnCatalog.generic_entry(SpawnCatalog.GENERIC_SLOT_BY_CHARACTER.gardo).region)
			assert(generic.source_region != SpawnCatalog.generic_entry(SpawnCatalog.GENERIC_SLOT_BY_CHARACTER.cel).region)
			for other_id: String in view.buttons:
				if other_id != character_id:
					assert(not _opaque_overlap(generic, view.buttons[other_id]), "Generic bodies cannot cover another waiting passenger")
		for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
			view.size = viewport_size
			view._layout()
			for character_id: String in SpawnCatalog.GENERIC_IDS:
				var button = view.buttons[character_id]
				var region: Rect2 = view.region_for(character_id)
				assert(button.position.is_equal_approx(view.image_rect.position + region.position * view.image_rect.size))
				assert(button.size.is_equal_approx(region.size * view.image_rect.size))
				var normal: Rect2 = view.sprite_rect_for(character_id)
				var hovered: Rect2 = view.sprite_rect_for(character_id, true)
				assert(hovered.size.is_equal_approx(normal.size * 1.06))
				assert(is_equal_approx(hovered.end.y, normal.end.y) and is_equal_approx(hovered.get_center().x, normal.get_center().x))
		var reordered := offers.duplicate(true)
		reordered.reverse()
		view.set_offers(reordered, night)
		for character_id: String in view.buttons:
			assert(view.buttons[character_id].source_region == original_positions[character_id], "Generic positions remain stable when offer iteration order changes")
	# Eight named day positions can all be occupied while a ninth offer is generic.
	var full: Array[Dictionary] = []
	for character_id in ["ely", "gardo", "ito", "cel", "hana", "benny", "jessa", "alma", "generic_guy"]:
		full.append(_offer(character_id, full.size()))
	view.size = Vector2(1280, 720)
	view.set_offers(full, false)
	assert(view.buttons.size() == 9, "A full terminal must retain the ninth offered passenger")
	var overflow = view.buttons.generic_guy
	assert(not overflow.is_placeholder and overflow.texture != null and _has_opaque_target(overflow))
	assert(Rect2(Vector2.ZERO, SpawnCatalog.ART_SIZE).encloses(overflow.source_region))
	for character_id: String in view.buttons:
		if character_id != "generic_guy":
			assert(not _opaque_overlap(overflow, view.buttons[character_id]), "Overflow cannot overlap any named passenger")
	view.set_offers([_offer("missing_character", 0)], false)
	var fallback = view.buttons.missing_character
	assert(fallback.is_placeholder and fallback.texture == null, "Missing future art retains the empty-box fallback")
	assert(view.sprite_rect_for("missing_character") == view.sprite_rect_for("missing_character", true))
	assert(bool(fallback.call("_has_point", fallback.size * 0.5)))
	view.free()
	await host.get_tree().process_frame


static func _has_opaque_target(button) -> bool:
	for y in range(1, 10):
		for x in range(1, 10):
			if bool(button.call("_has_point", button.size * Vector2(x, y) / 10.0)):
				return true
	return false


static func _opaque_overlap(left, right) -> bool:
	var overlap: Rect2 = left.source_region.intersection(right.source_region)
	if not overlap.has_area():
		return false
	for y in range(ceili(overlap.position.y), floori(overlap.end.y)):
		for x in range(ceili(overlap.position.x), floori(overlap.end.x)):
			var point := Vector2(x + 0.5, y + 0.5)
			var left_pixel := Vector2i((point - left.source_region.position) / left.source_region.size * Vector2(left.alpha_image.get_size()))
			var right_pixel := Vector2i((point - right.source_region.position) / right.source_region.size * Vector2(right.alpha_image.get_size()))
			if left.alpha_image.get_pixelv(left_pixel).a >= 0.7 and right.alpha_image.get_pixelv(right_pixel).a >= 0.7:
				return true
	return false


static func _base(phase := "morning", mode := "current_stage") -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = phase
	PlayerState.current_stage_type = "short-%s-chill" % phase
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 0
	PlayerState.gas = 50.0
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn", mode, true)


static func _test_hover_input_modes(host: Node) -> void:
	var view := TerminalView.new()
	host.get_tree().root.add_child(view)
	view.size = Vector2(1280, 720)
	var empty := Vector2(500, 570)
	for night in [false, true]:
		view.set_offers([_offer("gardo", 0), _offer("cel", 1)], night)
		await _move(host, empty)
		view.focus_first_offer()
		assert(view.active_offer_id().is_empty() and view.info_label.text.is_empty(), "Automatic passenger focus must not pin hover art or details")
		await _move(host, _body_point(view.buttons.gardo))
		assert(view.active_offer_id() == "gardo" and not view.info_label.text.is_empty())
		await _click(host, view.buttons.gardo)
		await _move(host, empty)
		assert(view.active_offer_id().is_empty() and view.info_label.text.is_empty(), "Moving off a clicked passenger must clear both enlargement and trip details")
		for _attempt in range(6):
			await _tab(host)
			if not view.active_offer_id().is_empty():
				break
		assert(view.is_keyboard_navigation() and not view.active_offer_id().is_empty(), "Keyboard navigation must still display a passenger's details")
		await _move(host, empty)
		assert(not view.is_keyboard_navigation() and view.active_offer_id().is_empty() and view.info_label.text.is_empty(), "An old keyboard focus cannot remain a mouse hover")
		view.set_enabled(false)
		view.set_enabled(true)
		view.focus_first_offer()
		assert(view.active_offer_id().is_empty(), "Re-enabling passengers cannot restore an automatic hover")
	view.free()
	await host.get_tree().process_frame


static func _lock(ids: Array) -> void:
	var pools := {"short": [], "medium": [], "long": []}
	var distances := ["short", "medium", "long"]
	for index in range(ids.size()):
		var distance: String = distances[floori(index / 3.0)]
		var character: Dictionary = PlayerState.get_character_by_id(str(ids[index]))
		character["active_distance"] = distance
		character["stage_traffic"] = "chill"
		character["stage_special_type"] = PlayerState.STAGE_SPECIAL_TYPE_NONE
		character["special_stage_id"] = ""
		pools[distance].append(character)
	PlayerState.lock_pending_trip_selection(pools, "short")


static func _economy() -> Array:
	return [PlayerState.current_day, PlayerState.current_phase, PlayerState.stage_round, PlayerState.money, PlayerState.energy, PlayerState.gas]


static func _test_all_offers(host: Node) -> void:
	_base()
	_lock(["alma", "generic_guy", "jessa", "cel", "generic_worker", "hana", "gardo", "benny", "ito"])
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	await host.get_tree().process_frame
	selection._open_passengers()
	var terminal = selection.terminal_view
	await _move(host, Vector2(500, 570))
	assert(terminal.buttons.size() == 9, "All locked distances appear together instead of only three cards")
	assert(terminal.buttons.has("alma") and terminal.buttons.has("cel") and terminal.buttons.has("gardo"))
	var pending: Dictionary = PlayerState.get_pending_trip_selection()
	var economy := _economy()
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	var button: Button = terminal.buttons.gardo
	button.mouse_entered.emit()
	assert(terminal.info_label.text.to_lower().contains("long"))
	assert(PlayerState.get_pending_trip_selection() == pending and _economy() == economy)
	assert(int(PlayerState.get_meta("test_save_count", 0)) == saves, "Hovering is read-only and cannot autosave")
	button.mouse_exited.emit()
	await _tab(host)
	button.grab_focus()
	assert(terminal.info_label.text.to_lower().contains("long"), "Keyboard focus exposes the same trip details")
	await _move(host, Vector2(500, 570))
	assert(terminal.active_offer_id().is_empty() and terminal.info_label.text.is_empty())
	for character_id in ["generic_guy", "generic_worker"]:
		var generic = terminal.buttons[character_id]
		assert(not generic.is_placeholder and generic.texture != null, "Generic offers use the new authored sprites")
		assert(_has_opaque_target(generic))
	var celina = terminal.buttons.cel
	assert(not celina.is_placeholder and celina.texture != null)
	assert(not bool(celina.call("_has_point", Vector2.ONE)), "Transparent sprite corners must not intercept another passenger")
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		selection.size = viewport_size
		await host.get_tree().process_frame
		terminal._layout()
		var image: Rect2 = terminal.image_rect
		assert(image.position.x >= -0.01 and image.position.y >= -0.01)
		assert(image.end.x <= viewport_size.x + 0.01 and image.end.y <= viewport_size.y + 0.01)
		for character_id: String in terminal.buttons:
			var region: Rect2 = terminal.region_for(character_id)
			var passenger: Button = terminal.buttons[character_id]
			assert(passenger.position.is_equal_approx(image.position + region.position * image.size))
			assert(passenger.size.is_equal_approx(region.size * image.size))
			assert(not bool(passenger.call("_has_point", Vector2(-10, -10))))
		_test_hover_geometry(terminal)
	selection.size = Vector2(1280, 720)
	await host.get_tree().process_frame
	# A long-distance passenger starts that passenger's locked offer, even while
	# the previously saved distance is short. Zero energy keeps this test in place.
	await _click(host, terminal.buttons.gardo)
	assert(selection.confirmation.visible and selection.selected_distance == "short", "Clicking a passenger previews their trip before changing the saved distance")
	assert(_economy() == economy and PlayerState.pending_story.is_empty())
	selection.confirmation.confirm_button.pressed.emit()
	assert(not selection.is_departing and selection.selected_distance == "long")
	assert(selection.status_label.text.to_lower().contains("energy"))
	assert(_economy() == economy and PlayerState.pending_story.is_empty())
	await _move(host, Vector2(500, 570))
	assert(terminal.active_offer_id().is_empty() and terminal.info_label.text.is_empty(), "A blocked ride click cannot make its passenger permanently hovered")
	await _click(host, terminal.buttons.generic_guy)
	assert(selection.confirmation.visible and selection.selected_distance == "long")
	selection.confirmation.confirm_button.pressed.emit()
	assert(selection.selected_distance == "short" and not selection.is_departing)
	assert(_economy() == economy)
	selection._close_passengers()
	assert(not terminal.is_visible_in_tree() and terminal.info_label.text.is_empty())
	terminal.buttons.gardo.pressed.emit()
	assert(selection.selected_distance == "short" and _economy() == economy, "Closed passengers cannot be selected through stale callbacks")
	selection.free()


static func _test_hover_geometry(terminal) -> void:
	var benny = terminal.buttons.benny
	var normal: Rect2 = terminal.sprite_rect_for("benny")
	var neighbor: Rect2 = terminal.sprite_rect_for("cel")
	assert(normal.position.is_equal_approx(benny.position) and normal.size.is_equal_approx(benny.size))
	var source_region: Rect2 = benny.source_region
	var source_texture: Texture2D = benny.texture
	var source_pixels: PackedByteArray = source_texture.get_image().get_data()
	var alpha_pixels: PackedByteArray = benny.alpha_image.get_data()
	var samples := [Vector2(0.1, 0.1), Vector2(0.5, 0.1), Vector2(0.5, 0.5), Vector2(0.5, 0.95), Vector2(0.9, 0.9)]
	var original_hits: Array[bool] = []
	for point: Vector2 in samples:
		original_hits.append(bool(benny.call("_has_point", point * normal.size)))
	benny.mouse_entered.emit()
	var hovered: Rect2 = terminal.sprite_rect_for("benny", true)
	assert(hovered.size.is_equal_approx(normal.size * 1.06), "Hover enlarges one Benny sprite by six percent")
	assert(is_equal_approx(hovered.end.y, normal.end.y), "Enlargement keeps his feet on the authored ground line")
	assert(is_equal_approx(hovered.get_center().x, normal.get_center().x), "Enlargement stays centered over his original stance")
	assert(hovered.position.y < normal.position.y and hovered.position.x < normal.position.x)
	assert(benny.position.is_equal_approx(normal.position) and benny.size.is_equal_approx(normal.size), "Hover art cannot enlarge or move the alpha hit target")
	assert(benny.source_region == source_region and benny.texture == source_texture)
	assert(source_texture.get_image().get_data() == source_pixels and benny.alpha_image.get_data() == alpha_pixels, "Highlighting cannot modify source sprites or alpha masks")
	for index in range(samples.size()):
		assert(bool(benny.call("_has_point", samples[index] * normal.size)) == original_hits[index])
	var normal_neighbor: Rect2 = terminal.sprite_rect_for("cel")
	assert(normal_neighbor.position.is_equal_approx(neighbor.position) and normal_neighbor.size.is_equal_approx(neighbor.size), "Hovering Benny does not shift another passenger")
	benny.mouse_exited.emit()
	var unhovered: Rect2 = terminal.sprite_rect_for("benny")
	assert(unhovered.position.is_equal_approx(normal.position) and unhovered.size.is_equal_approx(normal.size))
	var generic: Rect2 = terminal.sprite_rect_for("generic_guy")
	terminal.buttons.generic_guy.mouse_entered.emit()
	var highlighted_generic: Rect2 = terminal.sprite_rect_for("generic_guy", true)
	assert(highlighted_generic.size.is_equal_approx(generic.size * 1.06), "Generic sprite hover uses the same single-image enlargement")
	assert(is_equal_approx(highlighted_generic.end.y, generic.end.y) and is_equal_approx(highlighted_generic.get_center().x, generic.get_center().x))
	terminal.buttons.generic_guy.mouse_exited.emit()
	assert(not terminal.sprite_rect_for("missing_character", true).has_area())


static func _test_schedules(host: Node) -> void:
	var ids := ["alma", "hana", "benny", "cel", "dante", "ely", "faye", "ito", "jessa"]
	for completed in [false, true]:
		for phase in ["morning", "noon", "night"]:
			_base(phase)
			PlayerState.set_event_value("jessa_runaway_fare_seen", completed)
			_lock(ids)
			var locked: Dictionary = PlayerState.get_locked_pending_trip_character_pools()
			var selection = load(SELECTION_SCENE).instantiate()
			host.get_tree().root.add_child(selection)
			selection._open_passengers()
			var expected: Array = []
			match phase:
				"morning":
					expected = ["alma", "hana", "benny", "cel", "ely", "ito"]
				"noon":
					expected = ["benny", "cel", "ely", "ito"]
				"night":
					expected = ["alma", "hana", "cel", "dante", "faye"]
			if (phase == "night") == completed:
				expected.append("jessa")
			var actual: Array = selection.terminal_view.buttons.keys()
			expected.sort()
			actual.sort()
			assert(actual == expected, "Existing locked offers must respect live day/night availability and Jessa's first encounter")
			assert(selection.terminal_view.is_night == (phase == "night"))
			assert(selection.locked_character_pools == locked, "A partially usable saved selection must not reroll")
			selection.free()
	_base("noon", PlayerState.TRANSITION_RIDE)
	_lock(ids)
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	selection._open_passengers()
	assert(selection.terminal_view.is_night and selection.terminal_view.buttons.has("dante"))
	assert(not selection.terminal_view.buttons.has("benny") and not selection.terminal_view.buttons.has("jessa"), "The terminal uses the upcoming ride phase rather than the current noon clock")
	PlayerState.set_event_value("jessa_runaway_fare_seen", true)
	selection._refresh_terminal()
	assert(selection.terminal_view.buttons.has("jessa"))
	selection.free()


static func _test_legacy_lock_repair(host: Node) -> void:
	_base("night")
	_lock(["jessa"])
	var economy := _economy()
	var selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	selection._open_passengers()
	assert(not selection.terminal_offers.is_empty(), "An old locked pool containing only an unavailable passenger must not leave the terminal empty")
	assert(not selection.terminal_view.buttons.has("jessa"), "The repair cannot bypass Jessa's first-encounter daytime schedule")
	assert(_economy() == economy, "Repairing a stale selection cannot charge or advance a ride")
	var repaired: Dictionary = selection.locked_character_pools.duplicate(true)
	selection._close_passengers()
	selection._open_passengers()
	assert(selection.locked_character_pools == repaired)
	Codec.save_to_path(PlayerState, "res://test_user/repaired_terminal_selection.tres", PlayerState.SAVE_VERSION)
	selection.free()
	assert(Codec.load_from_path(PlayerState, "res://test_user/repaired_terminal_selection.tres"))
	selection = load(SELECTION_SCENE).instantiate()
	host.get_tree().root.add_child(selection)
	assert(selection.passenger_overlay.visible and selection.locked_character_pools == repaired)
	assert(_economy() == economy)
	selection._open_store()
	await host.get_tree().scene_changed
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == "res://scenes/store.tscn")
	assert(PlayerState.get_locked_pending_trip_character_pools() == repaired and _economy() == economy)
	store.street.buttons.station.pressed.emit()
	await host.get_tree().scene_changed
	var returned = host.get_tree().current_scene
	returned._open_passengers()
	assert(returned.locked_character_pools == repaired and not returned.terminal_view.buttons.has("jessa"))
	assert(_economy() == economy, "A repaired pool stays locked through store navigation, reopening and save/load")
	host.get_tree().current_scene = null
	returned.free()
	selection.free()


static func _body_point(button: Button) -> Vector2:
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
	assert(found, "The visible passenger must have a clickable body")
	return button.global_position + local_point


static func _click(host: Node, button: Button) -> void:
	var point := _body_point(button)
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
