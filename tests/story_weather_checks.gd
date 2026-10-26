extends RefCounted

const BackgroundWeather := preload("res://scripts/story/story_background_weather.gd")
const Effects := preload("res://scripts/ui/hub_weather_effects.gd")
const LOCATIONS := "res://assets/story/backgrounds/locations/"
const BINDINGS := {
	"bar.png": "barrain_indoor.png",
	"barnight.png": "barnightrain.png",
	"hospitalday.png": "hospitalrain_indoor.png",
	"hospitalnight.png": "hospitalrain_indoor.png",
	"inhouse.png": "houserain_indoor.png",
	"inhouse_night.png": "houserain_indoor.png",
	"park.png": "parkrain.png",
	"parknight.png": "parkrain.png",
	"market.png": "marketrain.png",
	"marketnight.png": "marketrain.png",
}
const INDOOR_PIXELS := {
	"barrain_indoor.png": Vector2(1400.5, 400.5),
	"hospitalrain_indoor.png": Vector2(30.5, 200.5),
	"houserain_indoor.png": Vector2(450.5, 350.5),
}


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	await _test_bindings(host)
	await _test_camera_geometry(host)
	await _test_transitions_and_clock(host)
	PlayerState.reset()
	print("PASS: all story/map rain mask bindings, bright indoor markers, transparent padding, fit/zoom/pan alignment, tint/indoor/outdoor transitions, paused clock and read-only presentation")


static func _background(host: Node) -> TextureRect:
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.size = Vector2(1280, 720)
	host.add_child(background)
	return background


static func _test_bindings(host: Node) -> void:
	var background := _background(host)
	PlayerState.current_weather = "rain"
	var original := _snapshot()
	for filename: String in BINDINGS:
		background.texture = load(LOCATIONS + filename) as Texture2D
		BackgroundWeather.apply(background)
		await host.get_tree().process_frame
		var layer: BackgroundWeather = background.get_node("StoryBackgroundWeather")
		var effects: Effects = layer._effects
		var marker: Texture2D = load(LOCATIONS + str(BINDINGS[filename])) as Texture2D
		assert(layer.visible and effects.marker_texture == marker, filename)
		assert(marker.get_size() == background.texture.get_size(), "Rain masks must retain their background's native canvas")
		assert(effects.shader_material.get_shader_parameter("marker_mask") == marker)
		assert(effects.shader_material.get_shader_parameter("logical_size") == marker.get_size())
		var indoor := INDOOR_PIXELS.has(BINDINGS[filename])
		assert(effects.indoor == indoor and bool(effects.shader_material.get_shader_parameter("indoor")) == indoor)
		assert(effects.strict_marker_colors and bool(effects.shader_material.get_shader_parameter("strict_marker_colors")))
		assert(effects.weather == "rain" and effects.effect_rect.visible)
		assert(background.self_modulate.is_equal_approx(Effects.RAIN_TINT))
		assert(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and effects.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		if indoor:
			var marked_pixel: Vector2 = INDOOR_PIXELS[BINDINGS[filename]]
			assert(effects.contains_marked_uv(marked_pixel / marker.get_size()), "Both lime marker colors must admit indoor rain")
			assert(not effects.contains_marked_uv(Vector2(0.5, 0.9)), "Indoor rain cannot leak into unmarked floor/wall pixels")
		assert(not effects.contains_marked_uv(Vector2(-0.01, 0.5)))
		assert(not effects.contains_marked_uv(Vector2(1.0, 0.5)))
		assert(not effects.contains_marked_uv(Vector2(0.5, 1.0)))
		assert(_snapshot() == original, "Applying and rendering rain must not roll weather, save or change progression")
	background.free()


static func _test_camera_geometry(host: Node) -> void:
	var background := _background(host)
	background.texture = load(LOCATIONS + "hospitalday.png") as Texture2D
	PlayerState.current_weather = "heavy rain"
	BackgroundWeather.apply(background)
	var layer: BackgroundWeather = background.get_node("StoryBackgroundWeather")
	for viewport in [Vector2(1280, 720), Vector2(900, 900), Vector2(640, 360)]:
		background.size = viewport
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var art_size := background.texture.get_size()
		var fit := minf(viewport.x / art_size.x, viewport.y / art_size.y)
		var expected := Rect2((viewport - art_size * fit) * 0.5, art_size * fit)
		assert(layer._effects.get_rect().is_equal_approx(expected), "Rain must follow the fitted background rather than the letterbox")
		assert(layer._effects.effect_rect.get_rect().is_equal_approx(Rect2(Vector2.ZERO, expected.size)))
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.position = Vector2(-200, -90)
	background.size = Vector2(1760, 1080)
	background.scale = Vector2(1.1, 0.9)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	assert(layer._effects.get_rect().is_equal_approx(Rect2(Vector2.ZERO, background.size)))
	var expected_canvas: Rect2 = background.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, background.size)
	var rain_canvas: Rect2 = layer._effects.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, layer._effects.size)
	assert(rain_canvas.is_equal_approx(expected_canvas), "Camera zoom/pan/scale must move rain and openings together")
	background.free()


static func _test_transitions_and_clock(host: Node) -> void:
	var background := _background(host)
	var base_tint := Color(0.9, 0.8, 0.7, 0.85)
	background.self_modulate = base_tint
	background.texture = load(LOCATIONS + "bar.png") as Texture2D
	PlayerState.current_weather = "heavy rain"
	BackgroundWeather.apply(background)
	var layer: BackgroundWeather = background.get_node("StoryBackgroundWeather")
	var effects: Effects = layer._effects
	var original := _snapshot()
	assert(effects.indoor and background.self_modulate.is_equal_approx(base_tint * Effects.HEAVY_RAIN_TINT))
	var elapsed: float = effects.elapsed
	effects._process(0.125)
	assert(is_equal_approx(effects.elapsed, elapsed + 0.125))
	host.get_tree().paused = true
	elapsed = effects.elapsed
	effects._process(0.125)
	assert(is_equal_approx(effects.elapsed, elapsed))
	host.get_tree().paused = false
	background.hide()
	effects._process(0.125)
	assert(is_equal_approx(effects.elapsed, elapsed))
	background.show()
	background.texture = load(LOCATIONS + "barnight.png") as Texture2D
	BackgroundWeather.apply(background)
	assert(background.get_node("StoryBackgroundWeather") == layer, "Location changes must reuse one weather layer")
	assert(not effects.indoor and not bool(effects.shader_material.get_shader_parameter("indoor")))
	assert(is_equal_approx(effects.elapsed, elapsed), "Switching indoor/outdoor masks must not reset ongoing rain")
	background.texture = load(LOCATIONS + "hospitalnight.png") as Texture2D
	BackgroundWeather.apply(background)
	assert(effects.indoor and bool(effects.shader_material.get_shader_parameter("indoor")))
	assert(_snapshot() == original)
	for weather in ["rain", "clear", "cloudy", "heavy rain"]:
		PlayerState.current_weather = weather
		var snapshot := _snapshot()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		assert(effects.weather == weather)
		assert(background.self_modulate.is_equal_approx(base_tint * effects.background_tint()))
		assert(_snapshot() == snapshot)
	background.texture = load(LOCATIONS + "city.png") as Texture2D
	BackgroundWeather.apply(background)
	assert(not layer.visible and not effects.is_raining() and not effects.effect_rect.visible)
	assert(background.self_modulate.is_equal_approx(base_tint), "Unmarked scenes must not retain a prior rainy tint")
	background.texture = null
	BackgroundWeather.apply(background)
	assert(not layer.visible and background.self_modulate.is_equal_approx(base_tint))
	background.texture = load(LOCATIONS + "bar.png") as Texture2D
	BackgroundWeather.apply(background)
	assert(layer.visible and effects.indoor and effects.is_raining())
	background.free()


static func _snapshot() -> Dictionary:
	return {
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"weather": PlayerState.current_weather,
		"cache": PlayerState.weather_phase_cache.duplicate(true),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}
