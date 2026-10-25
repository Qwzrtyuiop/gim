extends RefCounted

const StreetView := preload("res://scripts/ui/store_street_view.gd")
const Migration := preload("res://scripts/save/asset_path_migration.gd")
const SOURCE_RECTS := {
	"tricycle": Rect2(203, 352, 653, 470),
	"food": Rect2(1089, 409, 448, 236),
	"home": Rect2(1, 353, 89, 495),
	"station": Rect2(1592, 410, 103, 453),
}


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_shared_rectangles(host)
	await _test_store_actions(host)
	_test_archived_sources()
	PlayerState.reset()
	print("PASS: store day/night shared rectangles and transparent interiors, responsive hover/focus isolation, real shop actions/purchases/tutorial gating and archived-image save paths")


static func _test_shared_rectangles(host: Node) -> void:
	assert(StreetView.BACKGROUND.get_size() == StreetView.ART_SIZE)
	assert(StreetView.NIGHT.get_size() == StreetView.ART_SIZE)
	assert(StreetView.SELECTED.get_size() == StreetView.ART_SIZE)
	var street := StreetView.new()
	host.get_tree().root.add_child(street)
	var pressed: Array[String] = []
	street.action_pressed.connect(func(action: String) -> void: pressed.append(action))
	var selected := StreetView.SELECTED.get_image()
	for viewport in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		street.size = viewport
		# Fit the logical test composition into the runner's real viewport so
		# widescreen clicks still enter the engine's actual input surface.
		var surface: Vector2 = host.get_viewport().get_visible_rect().size
		street.scale = Vector2.ONE * minf(1, minf(surface.x / viewport.x, surface.y / viewport.y))
		await _settle(host)
		var day_rects: Dictionary = {}
		for night in [false, true]:
			street.set_night(night)
			await _settle(host)
			assert(Rect2(Vector2.ZERO, viewport).grow(0.01).encloses(street.image_rect))
			for action: String in SOURCE_RECTS:
				var region: Rect2 = StreetView.REGIONS[action]
				var source := Rect2(region.position * StreetView.ART_SIZE, region.size * StreetView.ART_SIZE)
				assert(source.is_equal_approx(SOURCE_RECTS[action]))
				var button: Button = street.buttons[action]
				var expected := Rect2(street.image_rect.position + region.position * street.image_rect.size, region.size * street.image_rect.size)
				assert(button.get_rect().is_equal_approx(expected))
				if not night:
					day_rects[action] = button.get_rect()
				else:
					assert(button.get_rect() == day_rects[action], "Changing phase must not change rectangular hit areas")
				# The selector's borders are painted, but their transparent interiors
				# still represent the user's full rectangles, not alpha-only input.
				var center := Vector2i(SOURCE_RECTS[action].get_center())
				assert(selected.get_pixelv(center).a < 0.1)
				await _click(host, button.get_global_rect().get_center())
				assert(pressed.back() == action, "Expected %s at %s in %s; last=%s" % [action, button.get_global_rect().get_center(), viewport, pressed.back()])
				assert(street.active_action() == action)
				await _move(host, street.get_global_transform_with_canvas() * (street.image_rect.position + street.image_rect.size * Vector2(0.57, 0.95)))
				assert(street.active_action().is_empty(), "Clicked rectangles cannot keep a focus highlight after the pointer leaves")
	street.buttons.tricycle.grab_focus()
	assert(street.active_action().is_empty())
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	host.get_viewport().push_input(tab, true)
	await _settle(host)
	street.buttons.food.grab_focus()
	assert(street.active_action() == "food")
	await _move(host, Vector2(20, 20))
	assert(street.active_action().is_empty())
	street.set_enabled(false)
	var count := pressed.size()
	for button: Button in street.buttons.values():
		button.pressed.emit()
	assert(pressed.size() == count and street.active_action().is_empty())
	street.free()


static func _test_store_actions(host: Node) -> void:
	for phase in ["morning", "night"]:
		PlayerState.reset()
		PlayerState.current_day = 3
		PlayerState.current_phase = phase
		PlayerState.current_stage_type = "short-%s-chill" % phase
		PlayerState.stage_round = 3
		PlayerState.money = 5000
		PlayerState.gas = 30.0
		PlayerState.store_tutorial_shown = true
		var store = load("res://scenes/store.tscn").instantiate()
		host.get_tree().root.add_child(store)
		await _settle(host)
		assert(store.street.is_night == (phase == "night"), "The real store follows the live clock's lighting")
		var original := _snapshot()
		for category in ["tricycle", "food"]:
			await _click(host, store.street.buttons[category].get_global_rect().get_center())
			assert(store.shop_overlay.visible and store.active_category == category and not store.street.enabled)
			assert(store.owner_portrait.texture != null and store.hub_dialogue.is_active())
			store._close_shop()
			assert(not store.shop_overlay.visible and store.street.enabled)
			assert(_snapshot() == original, "Walking into and closing either store consumes no resources, time or saves")
		store.StoreTutorial.set_tutorial_active(store, true)
		store.street.buttons.tricycle.pressed.emit()
		assert(not store.shop_overlay.visible)
		store.StoreTutorial.end_tutorial(store)
		await _click(host, store.street.buttons.tricycle.get_global_rect().get_center())
		for index in range(store.StoreItemCatalog.ITEMS.size()):
			var item: Dictionary = store.StoreItemCatalog.ITEMS[index]
			if item.type != "gas":
				continue
			var price: int = store._item_cost(item)
			store.store_buy_buttons[index].pressed.emit()
			assert(PlayerState.money == original.money - price)
			assert(PlayerState.gas == 30.0 + float(item.gas))
			assert(PlayerState.current_day == original.day and PlayerState.current_phase == phase)
			assert(store.hub_dialogue.is_active())
			break
		store.free()


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"gas": PlayerState.gas,
		"energy": PlayerState.energy,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"pending": PlayerState.get_pending_trip_selection(),
		"story": PlayerState.get_pending_story(),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}


static func _test_archived_sources() -> void:
	var destination := "res://assets/story/backgrounds/locations/check/unused/garagespotlight.png"
	for old in [
		"res://assets/bg/garagespotlight.png",
		"res://assets/story/backgrounds/garagespotlight.png",
		"res://assets/story/backgrounds/locations/garagespotlight.png",
	]:
		assert(Migration.migrate(old) == destination and ResourceLoader.exists(destination))
		assert(Migration.migrate(Migration.migrate(old)) == destination)
	for name in ["station_day.png", "station_day_select.png", "stationnewnight.png", "stationnight_select.png", "stationselect.png", "garagespotlight.png", "house selectables.png"]:
		assert(ResourceLoader.exists("res://assets/story/backgrounds/locations/check/unused/" + name))
		assert(not FileAccess.file_exists("res://assets/story/backgrounds/locations/" + name))
	assert(not FileAccess.file_exists("res://assets/story/backgrounds/house selectables.png"))


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _move(host: Node, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	host.get_viewport().push_input(event, true)
	await _settle(host)


static func _click(host: Node, point: Vector2) -> void:
	await _move(host, point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await _settle(host)
