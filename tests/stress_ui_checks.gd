extends RefCounted

const Header := preload("res://scripts/ui/hub_status_header.gd")
const Hud := preload("res://scripts/game/game_hud.gd")


class ResultsProbe extends "res://scripts/stage_results.gd":
	var continued := 0

	func _ready() -> void:
		_create_dialogs()

	func _next_stage() -> void:
		continued += 1


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	assert(PlayerState.max_energy == 5 and PlayerState.energy == 5)
	await _test_shared_stats(host)
	await _test_driving_hud(host)
	await _test_high_stress_confirmation(host)
	await _test_tutorials(host)
	AmbientAudioManager.stop_all()
	UIAudioManager.hover_player.stop()
	UIAudioManager.press_player.stop()
	await host.get_tree().create_timer(0.1).timeout
	PlayerState.reset()
	print("PASS: full-width hub status bounds/visibility, live resource values and input transparency, responsive driving HUD, maximum-stress confirmation and home/terminal/store tutorials")


static func _test_shared_stats(host: Node) -> void:
	var parent := Control.new()
	parent.size = Vector2(1280, 720)
	host.get_tree().root.add_child(parent)
	var header := Header.new()
	parent.add_child(header)
	await _settle(host)
	assert(header.stats_refs.has("energy_label") and header.stats_refs.has("stress_label"), "Energy and stress must remain separate visible resources")
	assert(header.find_children("PlayerIDCard", "", true, false).is_empty(), "Hub status must not instantiate the archived ID-card UI")
	PlayerState.stress = 10
	PlayerState.hull = 3
	PlayerState.money = 50000
	PlayerState.energy = 2
	PlayerState.gas = 42.5
	_assert_resource_values(header.stats_refs)
	PlayerState.energy = 1
	PlayerState.stress = 9
	PlayerState.hull = 2
	PlayerState.gas = 25.0
	PlayerState.money = 12345678
	_assert_resource_values(header.stats_refs)
	for viewport_size in [Vector2(1280, 720), Vector2(640, 360), Vector2(900, 900)]:
		parent.size = viewport_size
		header.layout_in(viewport_size)
		await _settle(host)
		_assert_inside(_global_rect(header), viewport_size, "Hub date header")
		_assert_header(header, viewport_size)
		header.hide()
		assert(not header.stats_refs.row.is_visible_in_tree(), "The resource row must hide with its header")
		header.show()
		parent.hide()
		assert(not header.stats_refs.row.is_visible_in_tree(), "Hidden locations must not leave resource values visible")
		parent.show()
		assert(header.stats_refs.row.is_visible_in_tree())
	PlayerState.energy = 2
	PlayerState.stress = 10
	PlayerState.hull = 3
	PlayerState.gas = 42.5
	PlayerState.money = 50000
	parent.free()
	await _settle(host)


static func _test_driving_hud(host: Node) -> void:
	PlayerState.energy = 2
	PlayerState.stress = 10
	PlayerState.hull = 3
	PlayerState.gas = 42.5
	PlayerState.money = 50000
	var parent := Control.new()
	host.get_tree().root.add_child(parent)
	var hud := Hud.new()
	var refs := hud.setup(parent, 0.0, "short-morning-chill")
	assert(refs.has("footer_stress_label") and refs.has("footer_hull_label"))
	assert(refs.has("footer_energy_label"), "Driving must show the restored daily energy budget")
	assert(not refs.has("player_id_card"), "Driving must retain its compact resource HUD instead of the hub ID card")
	hud.update("playing", "", 45, 120, 10.0, 525.0, 40.0, "short-morning-chill")
	assert(refs.footer_energy_label.text == "2/5")
	assert(refs.footer_stress_label.text == "10/10")
	assert(refs.footer_hull_label.text == "3/10")
	assert(refs.footer_gas_label.text == PlayerState.gas_text())
	assert(refs.footer_money_label.text == "PhP 50000")
	var row: HBoxContainer = refs.footer_stats_row
	assert(row.visible, "Driving resource values must remain visible")
	var hull_icon := row.get_child(refs.footer_hull_label.get_index() - 1) as TextureRect
	assert(hull_icon != null and hull_icon.texture.resource_path == "res://assets/ui/icons/tricycle_condition.png", "Driving must show the tricycle-condition icon beside hull")
	for resource in ["money", "energy", "stress", "hull", "gas"]:
		assert(refs["footer_%s_label" % resource].get_parent() == row, "Driving references must use the compact footer labels")
	assert(refs.ui.get_children().find(row) < refs.ui.get_children().find(refs.fade_rect), "Scene fades must cover the driving HUD")
	assert(refs.ui.get_children().find(refs.speedometer) < refs.ui.get_children().find(refs.bottom_bar), "The lowered gauge base must draw behind the resource footer")
	assert(refs.ui.get_children().find(refs.speedometer) < refs.ui.get_children().find(row), "Resource values must draw above the lowered gauge base")
	for viewport_size in [Vector2(1280, 720), Vector2(640, 360), Vector2(900, 900)]:
		parent.size = viewport_size
		hud.layout(viewport_size, 280.0, 1, "short-morning-chill", func(_lane: int, dimensions: Vector2) -> float: return dimensions.y * 0.675)
		hud.update("playing", "", 45, 120, 10.0, 525.0, 40.0, "short-morning-chill")
		await _settle(host)
		for key in ["footer_stats_row", "help_label", "bottom_bar", "speedometer", "distance_label", "distance_progress_bg", "time_label"]:
			_assert_inside(_global_rect(refs[key]), viewport_size, key)
		assert(is_equal_approx(refs.bottom_bar.size.x, viewport_size.x), "The compact driving footer must span the full viewport")
		for child: Control in row.get_children():
			_assert_contains(_global_rect(row), _global_rect(child), "Driving resource cell")
			assert(child.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		for key in ["help_label", "distance_label", "distance_progress_bg"]:
			assert(not _global_rect(row).intersects(_global_rect(refs[key])), "Driving resources must stay clear of " + key)
		assert(not _global_rect(refs.help_label).intersects(_global_rect(refs.speedometer)), "The control hint must stay clear of the speedometer")
		assert(not _global_rect(refs.distance_label).intersects(_global_rect(refs.speedometer)), "Distance text must stay clear of the speedometer")
		_assert_contains(_global_rect(refs.bottom_bar), _global_rect(row), "Driving resource footer")
		_assert_contains(_global_rect(refs.bottom_bar), _global_rect(refs.help_label), "Driving control hint")
	PlayerState.energy = 1
	PlayerState.stress = 9
	PlayerState.hull = 2
	PlayerState.gas = 25.0
	PlayerState.money = 1234
	hud.update("playing", "", 45, 120, 10.0, 525.0, 40.0, "short-morning-chill")
	assert(refs.footer_energy_label.text == "1/5" and refs.footer_stress_label.text == "9/10")
	assert(refs.footer_hull_label.text == "2/10" and refs.footer_gas_label.text == PlayerState.gas_text())
	assert(refs.footer_money_label.text == "PhP 1234", "Driving HUD updates must refresh all five resources")
	parent.free()
	await _settle(host)


static func _test_high_stress_confirmation(host: Node) -> void:
	PlayerState.current_phase = "night"
	PlayerState.stress = 10
	var probe := ResultsProbe.new()
	var buttons := HBoxContainer.new()
	buttons.name = "BreakButtons"
	for name in ["RestButton", "StoreButton", "RideButton"]:
		var button := Button.new()
		button.name = name
		buttons.add_child(button)
	probe.add_child(buttons)
	host.get_tree().root.add_child(probe)
	await _settle(host)
	probe._attempt_next_stage()
	assert(probe.ride_confirm_dialog.visible and probe.ride_confirm_dialog.title == "High Stress")
	probe.ride_confirm_dialog.confirmed.emit()
	assert(probe.continued == 1 and PlayerState.stress == 10, "Maximum stress may warn but must still allow continuing")
	probe.free()
	await _settle(host)


static func _test_tutorials(host: Node) -> void:
	for path in ["res://scenes/day_start_scene.tscn", "res://scenes/ride_selection.tscn", "res://scenes/store.tscn"]:
		PlayerState.reset()
		PlayerState.current_day = 2
		PlayerState.current_phase = "morning"
		PlayerState.stage_round = 3
		PlayerState.home_tutorial_shown = true
		PlayerState.ride_select_tutorial_shown = true
		PlayerState.store_tutorial_shown = true
		var screen = load(path).instantiate()
		host.get_tree().root.add_child(screen)
		await _settle(host)
		var steps: Array = screen.tutorial.steps if path.ends_with("ride_selection.tscn") else screen.tutorial_steps
		var copy := ""
		for step: Dictionary in steps:
			assert(str(step.get("text", "")).length() <= 160, "Tutorial steps should explain one short idea: " + path)
			copy += str(step.get("text", "")).to_lower() + " "
		if path.ends_with("day_start_scene.tscn"):
			assert(copy.contains("radio") and copy.contains("calendar") and copy.contains("rest") and copy.contains("map"), "Home onboarding should teach its room objects and navigation")
			assert(not copy.contains("activity budget") and not copy.contains("crashes"), "Home should not repeat the station's meter lessons")
			await _test_home_modals(host, screen)
		elif path.ends_with("store.tscn"):
			assert(copy.contains("repair") and copy.contains("upgrades") and copy.contains("gas") and copy.contains("food"), "Store onboarding should explain the counters' practical uses")
			assert(not copy.contains("activity budget") and not copy.contains("high stress") and not copy.contains("crashes"), "Store should not repeat the station's meter and driving lessons")
		else:
			assert(copy.contains("distance") and copy.contains("traffic") and copy.contains("fare") and copy.contains("risk"), "Terminal onboarding should explain passenger trip information")
			assert(copy.contains("fuel") or copy.contains("gas"), "Terminal onboarding should explain the trip's estimated fuel")
			assert(not copy.contains("activity budget") and not copy.contains("high stress") and not copy.contains("crashes"), "Terminal should not repeat the station's resource lessons")
			_assert_station_tutorial(screen)
		screen.free()
		AmbientAudioManager.stop_all()
		await _settle(host)


static func _assert_station_tutorial(screen) -> void:
	var steps: Array = screen.station_tutorial.steps
	assert(not steps.is_empty(), "The station introduction needs its own resource and hotspot steps")
	for resource in ["energy", "stress", "hull", "gas"]:
		var label: Label = screen.status_header.stats_refs[resource + "_label"]
		var found := false
		for step: Dictionary in steps:
			assert(str(step.get("text", "")).length() <= 160, "Station resource lessons must stay short")
			var targets: Array = step.get("targets", [])
			if not targets.has(label):
				continue
			found = true
			for other in ["energy", "stress", "hull", "gas"]:
				if other != resource:
					assert(not targets.has(screen.status_header.stats_refs[other + "_label"]), "Each station resource needs its own highlighted step")
		assert(found, "The station must highlight the " + resource + " value individually")
	var last: Dictionary = steps.back()
	assert(last.get("interaction", "") == "terminal" and last.get("targets", []).has(screen.station.buttons.passengers), "The station introduction must end by asking for the terminal click")


static func _test_home_modals(host: Node, home) -> void:
	var surfaces := {
		"calendar": home.calendar_content,
		"radio": home.radio_content,
		"rest": home.rest_content,
	}
	for viewport_size in [Vector2(1280, 720), Vector2(640, 360), Vector2(900, 900)]:
		home.size = viewport_size
		for action: String in surfaces:
			home._show_info(action)
			await _settle(host)
			var surface: Control = surfaces[action]
			assert(home.info_overlay.is_visible_in_tree() and surface.is_visible_in_tree(), "Home " + action + " must open its modal")
			_assert_contains(_global_rect(home.info_overlay), _global_rect(home.status_header), "Home modal dimmer")
			assert(_effective_z(home.info_overlay) > _effective_z(home.status_header), "Home modal dimming must cover the hub status bar")
			assert(_effective_z(surface) > _effective_z(home.status_header), "Home " + action + " must render above the hub status bar")
			home._close_info()
			assert(not home.info_overlay.visible, "Home modal must close normally")


static func _effective_z(item: CanvasItem) -> int:
	var result := item.z_index
	var ancestor := item.get_parent()
	if not item.z_as_relative:
		return result
	while ancestor != null:
		var canvas_ancestor := ancestor as CanvasItem
		if canvas_ancestor != null:
			result += canvas_ancestor.z_index
			if not canvas_ancestor.z_as_relative:
				break
		ancestor = ancestor.get_parent()
	return result


static func _assert_inside(rect: Rect2, viewport_size: Vector2, label: String) -> void:
	assert(rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0, "%s must stay within %s: %s" % [label, viewport_size, rect])


static func _assert_header(header: Header, viewport_size: Vector2) -> void:
	var bounds := _global_rect(header)
	_assert_inside(bounds, viewport_size, "Hub status bar")
	assert(bounds.position.is_zero_approx() and bounds.size.is_equal_approx(Vector2(viewport_size.x, Header.BAR_HEIGHT)), "The hub status bar must span the top edge at every viewport size")
	assert(header.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The status bar must not intercept scene clicks")
	var background := header.get_theme_stylebox("panel") as StyleBoxFlat
	assert(background != null and background.bg_color.r < 0.15 and background.bg_color.g < 0.15 and background.bg_color.b < 0.15, "The hub status bar must use a dark flat backdrop")
	_assert_contains(bounds, _global_rect(header.day_label), "Day indicator")
	assert(is_equal_approx(_global_rect(header.day_label).get_center().x, viewport_size.x * 0.5), "The day stays centered within the single-line status bar")
	_assert_text_fits(header.day_label, "Day indicator")
	var brain_found := false
	var hull_icon_found := false
	for child: Control in header.find_children("*", "Control", true, false):
		assert(child.mouse_filter == Control.MOUSE_FILTER_IGNORE, "All status-bar controls must leave scene input available")
		_assert_contains(bounds, _global_rect(child), "Status-bar control")
		if child is TextureRect and child.texture != null and child.texture.resource_path.ends_with("stress_brain.png"):
			brain_found = true
		if child is TextureRect and child.texture != null and child.texture.resource_path.ends_with("tricycle_condition.png"):
			hull_icon_found = true
	assert(brain_found, "The shared resource display must retain the stress icon")
	assert(hull_icon_found, "The shared resource display must show the tricycle-condition icon")
	for resource in ["money", "energy", "stress", "hull", "gas"]:
		var label: Label = header.stats_refs["%s_label" % resource]
		_assert_contains(bounds, _global_rect(label), resource + " value")
		assert(is_equal_approx(_global_rect(label).get_center().y, _global_rect(header.day_label).get_center().y), "All top-bar values must share one line")
		_assert_text_fits(label, resource + " value")
	_assert_resource_values(header.stats_refs)


static func _assert_resource_values(stats_refs: Dictionary) -> void:
	var expected := {
		"money": "Money: PhP %d" % PlayerState.money,
		"energy": "%d/%d" % [PlayerState.energy, PlayerState.max_energy],
		"stress": "%d/%d" % [PlayerState.stress, PlayerState.max_stress],
		"hull": "%d/%d" % [PlayerState.hull, PlayerState.max_hull],
		"gas": PlayerState.gas_text(),
	}
	for resource: String in expected:
		var label: Label = stats_refs["%s_label" % resource]
		assert(label.text == expected[resource], "Resource signals must update the " + resource + " value")


static func _global_rect(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


static func _assert_contains(outer: Rect2, inner: Rect2, label: String) -> void:
	assert(outer.grow(0.5).encloses(inner), "%s must fit its authored area: %s outside %s" % [label, inner, outer])


static func _assert_text_fits(label: Label, description: String) -> void:
	var minimum := label.get_minimum_size()
	assert(minimum.x <= label.size.x + 0.5 and minimum.y <= label.size.y + 0.5, "%s must fit without clipping: minimum %s, actual %s" % [description, minimum, label.size])


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
