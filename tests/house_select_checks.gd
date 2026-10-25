extends RefCounted

const HouseView := preload("res://scripts/ui/house_view.gd")
const CATALOG_PATH := "res://scripts/ui/house_selectable_catalog.gd"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const ACTIONS := ["radio", "calendar", "rest", "ride"]
const ITEM_ACTIONS := ["radio", "calendar", "rest"]


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_shared_geometry(host)
	await _test_pointer_and_keyboard(host)
	await _test_home_interactions(host)
	PlayerState.reset()
	print("PASS: shared day/night house item masks, alpha picking and foreground hover geometry, pointer/keyboard isolation, responsive home actions, tutorial gating and speech anchors")


static func _test_shared_geometry(host: Node) -> void:
	var catalog = load(CATALOG_PATH)
	assert(catalog.ART_SIZE == Vector2(1698, 926))
	assert(HouseView.DAY.get_size() == catalog.ART_SIZE and HouseView.NIGHT.get_size() == catalog.ART_SIZE)
	assert(HouseView.REGIONS.size() == ACTIONS.size())
	var house := HouseView.new()
	host.get_tree().root.add_child(house)
	var pressed: Array[String] = []
	house.action_pressed.connect(func(action: String) -> void: pressed.append(action))
	var alpha_images: Dictionary = {}
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		house.size = viewport_size
		var day_rects: Dictionary = {}
		var day_hits: Dictionary = {}
		for night in [false, true]:
			house.set_night(night)
			await _settle(host)
			assert(Rect2(Vector2.ZERO, viewport_size).grow(0.01).encloses(house.image_rect), "The new house canvas fits the viewport with letterboxing")
			for action: String in ACTIONS:
				var button: Button = house.buttons[action]
				var region: Rect2 = HouseView.REGIONS[action]
				var expected := Rect2(house.image_rect.position + region.position * house.image_rect.size, region.size * house.image_rect.size)
				assert(button.position.is_equal_approx(expected.position) and button.size.is_equal_approx(expected.size), "One authored region controls each house item's input and display bounds")
				assert(not bool(button.call("_has_point", Vector2(-2, -2))))
				var body_point := _body_point(button)
				assert(bool(button.call("_has_point", body_point - button.global_position)), "Visible house item pixels remain clickable after resizing")
				if not night:
					day_rects[action] = button.get_rect()
					day_hits[action] = body_point - button.global_position
				else:
					assert(button.get_rect() == day_rects[action], "Day and night must use the same hit area rather than separate checks")
					assert(bool(button.call("_has_point", day_hits[action])), "A day item pixel has the identical night hit test")
				if action in ITEM_ACTIONS:
					var image: Image = button.get("alpha_image")
					assert(image != null and image.get_used_rect().has_area())
					if alpha_images.has(action):
						assert(image == alpha_images[action], "Changing phase/resolution reuses the shared alpha mask")
					else:
						alpha_images[action] = image
					var normal: Rect2 = house.sprite_rect_for(action)
					var highlighted: Rect2 = house.sprite_rect_for(action, true)
					assert(normal.is_equal_approx(expected))
					assert(highlighted.size.is_equal_approx(normal.size * 1.06))
					assert(is_equal_approx(highlighted.end.y, normal.end.y) and is_equal_approx(highlighted.get_center().x, normal.get_center().x), "A selected item grows upward around its bottom center")
			for action: String in ["radio", "rest"]:
				assert(_has_transparent_gap(house.buttons[action]), "Empty pixels inside a house item's bounds cannot activate its rectangular box")
			var empty := house.image_rect.position + house.image_rect.size * Vector2(0.45, 0.80)
			for action: String in ACTIONS:
				assert(not bool(house.buttons[action].call("_has_point", empty - house.buttons[action].global_position)), "Empty floor does not activate any house item")
	house.set_enabled(false)
	for action: String in ACTIONS:
		assert(house.buttons[action].disabled)
		house.buttons[action].pressed.emit()
	assert(pressed.is_empty(), "Disabled house items cannot emit an action through a synthetic press")
	house.set_enabled(true)
	for action: String in ACTIONS:
		assert(not house.buttons[action].disabled)
	house.free()
	await _settle(host)


static func _test_pointer_and_keyboard(host: Node) -> void:
	var house := HouseView.new()
	host.get_tree().root.add_child(house)
	house.size = Vector2(1280, 720)
	for night in [false, true]:
		house.set_night(night)
		await _settle(host)
		var empty := house.image_rect.position + house.image_rect.size * Vector2(0.45, 0.80)
		await _move(host, empty)
		house.buttons.radio.grab_focus()
		assert(house.active_action().is_empty(), "Programmatic focus cannot pin an item highlight while the pointer is on the floor")
		await _move(host, _body_point(house.buttons.radio))
		assert(house.active_action() == "radio")
		await _click(host, _body_point(house.buttons.radio))
		await _move(host, empty)
		assert(house.active_action().is_empty(), "A clicked item stops enlarging when the pointer leaves it")
		await _tab(host)
		house.buttons.calendar.grab_focus()
		assert(house.active_action() == "calendar", "Intentional keyboard navigation still highlights the focused item")
		await _move(host, empty)
		assert(house.active_action().is_empty(), "Mouse movement clears the old keyboard focus highlight")
		house.set_enabled(false)
		assert(house.active_action().is_empty() and house.hovered_action.is_empty() and house.focused_action.is_empty())
		house.set_enabled(true)
		house.buttons.radio.grab_focus()
		assert(house.active_action().is_empty(), "Restoring controls cannot restore a stale item hover")
	house.free()
	await _settle(host)


static func _setup_home() -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "morning"
	PlayerState.current_stage_type = "short-morning-chill"
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 5
	PlayerState.gas = 50.0
	PlayerState.home_tutorial_shown = true
	PlayerState.set_pending_trip_selection(HOME_SCENE, PlayerState.TRANSITION_CURRENT_STAGE, true)


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"rests": PlayerState.rests_taken_today,
		"story": PlayerState.get_pending_story(),
		"selection": PlayerState.get_pending_trip_selection(),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}


static func _test_home_interactions(host: Node) -> void:
	_setup_home()
	var home = load(HOME_SCENE).instantiate()
	host.get_tree().root.add_child(home)
	await _settle(host)
	var original := _snapshot()
	for night in [false, true]:
		home.house.set_night(night)
		await _settle(host)
		for action: String in ACTIONS:
			await _click(host, _body_point(home.house.buttons[action]))
			assert(home.info_overlay.visible and not home.house.enabled, "Selecting an item opens its existing modal and gates the room")
			assert(home.info_action == ("outside" if action == "ride" else action))
			if action == "calendar":
				assert(home.calendar_content.visible and not home.radio_content.visible)
			elif action == "radio":
				assert(home.radio_content.visible and not home.calendar_content.visible)
			elif action == "rest":
				assert(home.rest_confirm.visible)
			else:
				assert(home.outside_buttons[0].visible and home.outside_buttons[1].visible)
			home._close_info()
			await _settle(host)
			assert(not home.info_overlay.visible and home.house.enabled)
			assert(_snapshot() == original, "Browsing home items cannot spend resources, rest, move the clock or create a story")
	home.HomeTutorial.set_tutorial_active(home, true)
	await _click(host, _body_point(home.house.buttons.calendar))
	assert(home.tutorial_active and not home.info_overlay.visible and not home.house.enabled, "Tutorial input cannot activate the newly segmented item underneath")
	home.HomeTutorial.end_tutorial(home)
	assert(home.show_message("Check the calendar", {"target": "calendar", "speaker": "John", "typewriter": false}))
	await _settle(host)
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(1920, 1080)]:
		home.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		home.size = viewport_size
		await _settle(host)
		var region: Rect2 = HouseView.REGIONS.calendar
		var target := Rect2(home.house.image_rect.position + region.position * home.house.image_rect.size, region.size * home.house.image_rect.size)
		assert(home.hub_dialogue.bubble.visible)
		assert(home.hub_dialogue._target_rect.is_equal_approx(target), "Local speech uses the same updated selection geometry after resizing")
		assert(Rect2(Vector2.ZERO, viewport_size).grow(0.5).encloses(home.hub_dialogue.bubble.panel.get_global_rect()))
	home.hub_dialogue.clear()
	home.free()
	await _settle(host)


static func _body_point(button: Button) -> Vector2:
	var image := button.get("alpha_image") as Image
	if image != null:
		# Choose an opaque center-area source pixel instead of assuming a box's
		# center is painted (curtains and radio antennas have transparent gaps).
		for y_fraction in [0.5, 0.65, 0.35, 0.8, 0.2]:
			for x_fraction in [0.5, 0.65, 0.35, 0.8, 0.2]:
				var pixel := Vector2i(Vector2(image.get_size()) * Vector2(x_fraction, y_fraction))
				if image.get_pixelv(pixel).a >= 0.7:
					var local := (Vector2(pixel) + Vector2(0.5, 0.5)) / Vector2(image.get_size()) * button.size
					return button.global_position + local
	var fallback := button.size * Vector2(0.75, 0.7)
	assert(bool(button.call("_has_point", fallback)), "Each selectable has a painted or polygonal interaction point")
	return button.global_position + fallback


static func _has_transparent_gap(button: Button) -> bool:
	var image := button.get("alpha_image") as Image
	if image == null:
		return false
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a > 0.01:
				continue
			var local := (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(image.get_size()) * button.size
			if not bool(button.call("_has_point", local)):
				return true
	return false


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


static func _tab(host: Node) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await _settle(host)


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
