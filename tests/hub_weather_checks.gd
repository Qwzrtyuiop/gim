extends RefCounted

const Effects := preload("res://scripts/ui/hub_weather_effects.gd")
const WeatherState := preload("res://scripts/state/player_weather_state.gd")
const VIEWS := {
	"house": preload("res://scripts/ui/house_view.gd"),
	"station": preload("res://scripts/ui/station_view.gd"),
	"store": preload("res://scripts/ui/store_street_view.gd"),
	"terminal": preload("res://scripts/ride_selection/terminal_passenger_view.gd"),
}
const MARKERS := {
	"house": {"texture": preload("res://assets/story/backgrounds/locations/houserain.png"), "size": Vector2(1698, 926)},
	"station": {"texture": preload("res://assets/story/backgrounds/locations/stationrain.png"), "size": Vector2(1672, 941)},
	"store": {"texture": preload("res://assets/story/backgrounds/locations/storerain.png"), "size": Vector2(1698, 926)},
	"terminal": {"texture": preload("res://assets/story/backgrounds/locations/terminalrain.png"), "size": Vector2(1672, 941)},
}
const HOME := "res://scenes/day_start_scene.tscn"
const STORE := "res://scenes/store.tscn"
const STATION := "res://scenes/ride_selection.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_masks_and_clock(host)
	await _test_view_layouts(host)
	await _test_live_hub_weather(host)
	PlayerState.reset()
	print("PASS: hub rain marker alpha/bounds, indoor/outdoor shader masks, rain/heavy background tint, paused/hidden/clear clock, shared letterboxed geometry and live cached weather across all four views")


static func _test_masks_and_clock(host: Node) -> void:
	var image := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(174.0 / 255.0, 1.0, 0.0, 0.0))
	image.set_pixel(0, 0, Color(174.0 / 255.0, 1.0, 0.0, 1.0))
	image.set_pixel(1, 0, Color.RED)
	var marker := ImageTexture.create_from_image(image)
	var effects := Effects.new()
	effects.configure(marker, true)
	host.get_tree().root.add_child(effects)
	effects.set_art_rect(Rect2(30, 40, 640, 360))
	await host.get_tree().process_frame
	assert(effects.contains_marked_uv(Vector2(1.0 / 6.0, 0.5)))
	assert(not effects.contains_marked_uv(Vector2(0.5, 0.5)), "Opaque non-yellow art cannot become a splash/window region")
	assert(not effects.contains_marked_uv(Vector2(5.0 / 6.0, 0.5)), "Hidden yellow RGB with zero alpha must not become a rain region")
	for uv in [Vector2(-0.01, 0.5), Vector2(1, 0.5), Vector2(0.5, -0.01), Vector2(0.5, 1)]:
		assert(not effects.contains_marked_uv(uv))
	assert(effects.position == Vector2(30, 40) and effects.size == Vector2(640, 360))
	assert(effects.effect_rect.get_rect() == Rect2(Vector2.ZERO, effects.size))
	assert(effects.mouse_filter == Control.MOUSE_FILTER_IGNORE and effects.effect_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(effects.material == effects.shader_material)
	assert(effects.shader_material.get_shader_parameter("marker_mask") == marker)
	assert(bool(effects.shader_material.get_shader_parameter("indoor")))
	assert(effects.shader_material.get_shader_parameter("logical_size") == marker.get_size())
	effects.set_weather("rain")
	assert(effects.is_raining() and effects.effect_rect.visible)
	var rain_strength := float(effects.shader_material.get_shader_parameter("rain_strength"))
	var rain_tint: Color = effects.background_tint()
	assert(rain_strength > 0.0 and rain_tint.r < 1.0 and rain_tint.g < 1.0 and rain_tint.b < 1.0)
	var elapsed: float = effects.elapsed
	effects._process(0.125)
	assert(is_equal_approx(effects.elapsed, elapsed + 0.125))
	assert(is_equal_approx(float(effects.shader_material.get_shader_parameter("elapsed")), effects.elapsed))
	host.get_tree().paused = true
	elapsed = effects.elapsed
	effects._process(0.125)
	assert(is_equal_approx(effects.elapsed, elapsed))
	host.get_tree().paused = false
	effects.hide()
	effects._process(0.125)
	assert(is_equal_approx(effects.elapsed, elapsed))
	effects.show()
	effects.set_weather("heavy rain")
	assert(float(effects.shader_material.get_shader_parameter("rain_strength")) > rain_strength)
	var heavy_tint: Color = effects.background_tint()
	assert(heavy_tint.r < rain_tint.r and heavy_tint.g < rain_tint.g and heavy_tint.b < rain_tint.b)
	for weather in ["clear", "cloudy"]:
		effects.set_weather(weather)
		assert(not effects.is_raining() and not effects.effect_rect.visible and effects.background_tint() == Color.WHITE)
		assert(is_zero_approx(effects.elapsed))
		effects._process(0.125)
		assert(is_zero_approx(effects.elapsed))
	# Reconfiguration must discard the previous image's cached marked pixels.
	image.set_pixel(0, 0, Color.TRANSPARENT)
	image.set_pixel(2, 0, Color(174.0 / 255.0, 1.0, 0.0, 1.0))
	effects.configure(ImageTexture.create_from_image(image), false)
	assert(not effects.contains_marked_uv(Vector2(1.0 / 6.0, 0.5)) and effects.contains_marked_uv(Vector2(5.0 / 6.0, 0.5)))
	assert(not bool(effects.shader_material.get_shader_parameter("indoor")))
	for name: String in MARKERS:
		var texture: Texture2D = MARKERS[name].texture
		assert(texture.get_size() == MARKERS[name].size)
		effects.configure(texture, name == "house")
		var pixels := _source_test_pixels(texture.get_image())
		assert(effects.contains_marked_uv(pixels[0]))
		assert(not effects.contains_marked_uv(pixels[1]))
	effects.free()


static func _source_test_pixels(image: Image) -> Array[Vector2]:
	if image.is_compressed():
		image.decompress()
	var marked := Vector2(-1, -1)
	var transparent := Vector2(-1, -1)
	var image_size := Vector2(image.get_size())
	for y in range(0, image.get_height(), maxi(1, ceili(image.get_height() / 64.0))):
		for x in range(0, image.get_width(), maxi(1, ceili(image.get_width() / 64.0))):
			var pixel := image.get_pixel(x, y)
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / image_size
			if marked.x < 0 and pixel.a > 0.99 and absf(pixel.r - 174.0 / 255.0) < 0.01 and pixel.g > 0.99 and pixel.b < 0.01:
				marked = uv
			if transparent.x < 0 and pixel.a < 0.01:
				transparent = uv
			if marked.x >= 0 and transparent.x >= 0:
				return [marked, transparent]
	assert(false, "Rain sources must contain both marked and transparent regions")
	return []


static func _test_view_layouts(host: Node) -> void:
	for name: String in VIEWS:
		var view = VIEWS[name].new()
		host.get_tree().root.add_child(view)
		for viewport in [Vector2(1280, 720), Vector2(900, 900), Vector2(640, 360)]:
			view.size = viewport
			await host.get_tree().process_frame
			view.set_weather("clear")
			var geometry := _geometry(view)
			var image_rect: Rect2 = view.image_rect
			var effects: Effects = view.weather_effects
			assert(effects.get_rect().is_equal_approx(image_rect))
			assert(effects.effect_rect.get_rect().is_equal_approx(Rect2(Vector2.ZERO, image_rect.size)))
			assert(effects.marker_texture == MARKERS[name].texture and effects.indoor == (name == "house"))
			for weather in ["rain", "heavy rain", "cloudy"]:
				view.set_weather(weather)
				assert(_geometry(view) == geometry and view.image_rect == image_rect, "Weather cannot move or resize interaction areas")
				assert(view.modulate == Color.WHITE and view.self_modulate == Color.WHITE, "Weather tint belongs to the background, not sprites or controls")
		view.free()


static func _setup() -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time("noon")
	PlayerState.stage_round = 3
	PlayerState.money = 1000
	PlayerState.energy = 4
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	assert(WeatherState.set_story_weather(PlayerState, "rain"))
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)


static func _test_live_hub_weather(host: Node) -> void:
	for path in [HOME, STORE, STATION]:
		_setup()
		if path == STATION:
			PlayerState.weather_phase_cache[WeatherState.weather_phase_key(3, "night")] = "clear"
			PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_REST_TO_NIGHT)
		var screen = load(path).instantiate()
		host.get_tree().root.add_child(screen)
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var views: Array = [screen.house] if path == HOME else ([screen.street] if path == STORE else [screen.station, screen.terminal_view])
		for view in views:
			assert(view.weather_effects.weather == "rain")
		if path == STATION:
			assert(PlayerState.get_next_stage_time(screen._transition_mode()) == "night")
			assert(screen.terminal_view.weather_effects.weather != PlayerState.get_stage_weather("night"), "Hub rain follows the live clock rather than the projected trip")
			var terminal_rain: Effects = screen.terminal_view.weather_effects
			var elapsed: float = terminal_rain.elapsed
			terminal_rain._process(0.125)
			assert(terminal_rain.elapsed == elapsed)
			screen._open_passengers()
			terminal_rain._process(0.125)
			assert(terminal_rain.elapsed > elapsed)
			screen._close_passengers()
		for weather in ["heavy rain", "clear"]:
			assert(WeatherState.set_story_weather(PlayerState, weather))
			var original := _snapshot()
			if path == HOME:
				screen._render_day_start()
			elif path == STORE:
				screen._refresh_header()
			else:
				screen._refresh_terminal()
			for view in views:
				assert(view.weather_effects.weather == weather and view.weather_effects.is_raining() == (weather == "heavy rain"))
			assert(_snapshot() == original, "Rendering cached weather must not reroll forecasts or change progression/resources")
		screen.free()


static func _geometry(view) -> Dictionary:
	var geometry: Dictionary = {}
	for key in view.buttons:
		var button: Control = view.buttons[key]
		geometry[key] = button.get_rect()
	return geometry


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"weather": PlayerState.current_weather,
		"cache": PlayerState.weather_phase_cache.duplicate(true),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}
