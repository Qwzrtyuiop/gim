extends RefCounted

const BackgroundScroller := preload("res://scripts/game/background_scroller.gd")
const GameAudioManager := preload("res://scripts/game/game_audio_manager.gd")
const GameHud := preload("res://scripts/game/game_hud.gd")
const PlayerVehicleController := preload("res://scripts/game/player_vehicle_controller.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")


static func pick_stage_background(owner) -> Texture2D:
	var pool_tag: String = background_pool_tag(owner)
	var background_pool: Array = owner.STAGE_BACKGROUND_POOLS.get(pool_tag, owner.STAGE_BACKGROUND_POOLS.get(owner.DEFAULT_BACKGROUND_POOL_TAG, []))
	if background_pool.is_empty():
		return null
	return background_pool[owner.rng.randi_range(0, background_pool.size() - 1)] as Texture2D


static func background_pool_tag(owner) -> String:
	return str(owner.BACKGROUND_POOL_TAGS_BY_TYPE.get(owner.background_type, owner.DEFAULT_BACKGROUND_POOL_TAG))


static func hide_editor_preview(owner) -> void:
	var editor_preview: CanvasItem = owner.get_node_or_null("EditorPreview") as CanvasItem
	if editor_preview:
		editor_preview.visible = false


static func create_audio_manager(owner) -> void:
	owner.audio_manager = GameAudioManager.new()
	owner.add_child(owner.audio_manager)
	owner.audio_manager.setup(owner)


static func create_background(owner, background_texture: Texture2D) -> void:
	owner.background_scroller = BackgroundScroller.new()
	owner.background_scroller.setup(owner, background_texture)


static func create_time_filter(owner) -> void:
	owner.time_filter_rect = ColorRect.new()
	owner.time_filter_rect.z_index = owner.TIME_FILTER_Z_INDEX
	owner.time_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.time_filter_rect.color = current_time_filter_color(owner)
	owner.add_child(owner.time_filter_rect)


static func create_weather_effects(owner, rain_texture: Texture2D, drop_texture: Texture2D, floor_drop_texture: Texture2D) -> void:
	owner.weather_filter_rect = ColorRect.new()
	owner.weather_filter_rect.z_index = owner.TIME_FILTER_Z_INDEX + 2
	owner.weather_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.weather_filter_rect.color = current_weather_filter_color(owner)
	owner.add_child(owner.weather_filter_rect)

	owner.rain_lines_rect = TextureRect.new()
	owner.rain_lines_rect.z_index = owner.TIME_FILTER_Z_INDEX + 5
	owner.rain_lines_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.rain_lines_rect.texture = rain_texture
	owner.rain_lines_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner.rain_lines_rect.stretch_mode = TextureRect.STRETCH_TILE
	owner.add_child(owner.rain_lines_rect)

	owner.rain_drops_rect = TextureRect.new()
	owner.rain_drops_rect.z_index = owner.TIME_FILTER_Z_INDEX + 6
	owner.rain_drops_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.rain_drops_rect.texture = drop_texture
	owner.rain_drops_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner.rain_drops_rect.stretch_mode = TextureRect.STRETCH_TILE
	owner.add_child(owner.rain_drops_rect)

	owner.rain_floor_drop_texture = floor_drop_texture
	owner.rain_floor_drops_rect = Control.new()
	owner.rain_floor_drops_rect.z_index = owner.TIME_FILTER_Z_INDEX + 3
	owner.rain_floor_drops_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(owner.rain_floor_drops_rect)
	update_weather_effects(owner, 0.0)


static func create_noon_glow(owner, shader_code: String) -> void:
	owner.noon_glow_rect = ColorRect.new()
	owner.noon_glow_rect.z_index = owner.TIME_FILTER_Z_INDEX + 4
	owner.noon_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.noon_glow_rect.color = Color.WHITE

	var shader := Shader.new()
	shader.code = shader_code
	owner.noon_glow_material = ShaderMaterial.new()
	owner.noon_glow_material.shader = shader
	owner.noon_glow_rect.material = owner.noon_glow_material
	owner.add_child(owner.noon_glow_rect)
	update_noon_glow(owner)


static func create_night_visibility_mask(owner, shader_code: String) -> void:
	owner.night_visibility_rect = ColorRect.new()
	owner.night_visibility_rect.z_index = owner.NIGHT_MASK_Z_INDEX
	owner.night_visibility_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.night_visibility_rect.color = Color.WHITE

	var shader := Shader.new()
	shader.code = shader_code
	owner.night_visibility_material = ShaderMaterial.new()
	owner.night_visibility_material.shader = shader
	owner.night_visibility_rect.material = owner.night_visibility_material
	owner.add_child(owner.night_visibility_rect)
	update_night_visibility_mask(owner)


static func create_ui(owner, gameplay_entry_fade_seconds: float) -> void:
	owner.game_hud = GameHud.new()
	var hud_refs: Dictionary = owner.game_hud.setup(owner, gameplay_entry_fade_seconds, owner.stage_type)
	owner.speedometer = hud_refs.get("speedometer") as Control
	owner.time_label = hud_refs.get("time_label") as Label
	owner.bottom_bar = hud_refs.get("bottom_bar") as ColorRect
	owner.help_label = hud_refs.get("help_label") as Label
	owner.distance_progress_bg = hud_refs.get("distance_progress_bg") as ColorRect
	owner.distance_progress_fill = hud_refs.get("distance_progress_fill") as ColorRect
	owner.distance_label = hud_refs.get("distance_label") as Label
	owner.footer_stats_row = hud_refs.get("footer_stats_row") as HBoxContainer
	owner.footer_money_label = hud_refs.get("footer_money_label") as Label
	owner.footer_energy_label = hud_refs.get("footer_energy_label") as Label
	owner.footer_gas_label = hud_refs.get("footer_gas_label") as Label
	owner.status_label = hud_refs.get("status_label") as Label
	owner.top_right_info_panel = hud_refs.get("top_right_info_panel") as TextureRect
	owner.stage_label = hud_refs.get("stage_label") as Label
	owner.weekly_goal_label = hud_refs.get("weekly_goal_label") as Label
	owner.debt_goal_label = hud_refs.get("debt_goal_label") as Label
	owner.speeder_warning_label = hud_refs.get("speeder_warning_label") as Label
	owner.speeder_lane_change_warning_label = hud_refs.get("speeder_lane_change_warning_label") as Label
	owner.fade_rect = hud_refs.get("fade_rect") as ColorRect


static func begin_gameplay_entry_fade(owner) -> void:
	if owner.game_hud == null:
		return
	owner.game_hud.begin_gameplay_entry_fade(owner, owner.gameplay_entry_fade_seconds)


static func layout_scene(owner) -> void:
	if owner.background_scroller == null or not owner.background_scroller.is_ready() or owner.player == null:
		return

	var size: Vector2 = owner.get_viewport_rect().size
	owner.background_scroller.layout(size)

	PlayerVehicleController.layout_player(owner, size)

	if owner.game_hud:
		owner.game_hud.layout(
			size,
			owner.player_x,
			owner.player_lane,
			owner.stage_type,
			func(lane_index: int, layout_size: Vector2) -> float:
				return VehicleGeometry.lane_y(owner, lane_index, layout_size)
		)

	if owner.time_filter_rect:
		owner.time_filter_rect.position = Vector2.ZERO
		owner.time_filter_rect.size = size
		owner.time_filter_rect.color = current_time_filter_color(owner)

	if owner.weather_filter_rect:
		owner.weather_filter_rect.position = Vector2.ZERO
		owner.weather_filter_rect.size = size
		owner.weather_filter_rect.color = current_weather_filter_color(owner)

	if owner.rain_lines_rect:
		owner.rain_lines_rect.size = size * 2.0

	if owner.rain_drops_rect:
		owner.rain_drops_rect.position = Vector2.ZERO
		owner.rain_drops_rect.size = size

	if owner.rain_floor_drops_rect:
		owner.rain_floor_drops_rect.position = Vector2(0.0, size.y * 0.5)
		owner.rain_floor_drops_rect.size = Vector2(size.x, size.y * 0.5)

	if owner.noon_glow_rect:
		owner.noon_glow_rect.position = Vector2.ZERO
		owner.noon_glow_rect.size = size
		update_noon_glow(owner)

	if owner.night_visibility_rect:
		owner.night_visibility_rect.position = Vector2.ZERO
		owner.night_visibility_rect.size = size
		update_night_visibility_mask(owner)


static func update_background(owner) -> void:
	if owner.background_scroller:
		owner.background_scroller.update(owner.distance * owner.VISUAL_DISTANCE_SCALE)


static func update_weather_effects(owner, delta: float) -> void:
	if owner.weather_filter_rect:
		owner.weather_filter_rect.color = current_weather_filter_color(owner)

	var is_raining: bool = owner.stage_weather == "rain" or owner.stage_weather == "heavy rain"
	if is_raining:
		owner.weather_effect_time += delta
	if owner.rain_lines_rect:
		owner.rain_lines_rect.visible = is_raining
		if is_raining:
			var viewport_size: Vector2 = owner.get_viewport_rect().size
			var wrapped_x: float = -fmod(absf(owner.weather_effect_time * owner.rain_scroll_x), maxf(1.0, viewport_size.x))
			var wrapped_y: float = -viewport_size.y + fmod(absf(owner.weather_effect_time * owner.rain_scroll_y), maxf(1.0, viewport_size.y))
			owner.rain_lines_rect.position = Vector2(wrapped_x, wrapped_y)
			var line_alpha: float = owner.rain_lines_alpha
			if owner.stage_weather == "heavy rain":
				line_alpha = owner.heavy_rain_lines_alpha
			owner.rain_lines_rect.modulate = Color(1.0, 1.0, 1.0, line_alpha)

	if owner.rain_drops_rect:
		owner.rain_drops_rect.visible = is_raining
		if is_raining:
			var drops_alpha: float = owner.rain_drops_alpha
			if owner.stage_weather == "heavy rain":
				drops_alpha *= 1.45
			owner.rain_drops_rect.modulate = Color(1.0, 1.0, 1.0, clampf(drops_alpha, 0.0, 1.0))

	if owner.rain_floor_drops_rect:
		owner.rain_floor_drops_rect.visible = is_raining
		if is_raining:
			update_floor_drops(owner, delta)
		else:
			clear_floor_drops(owner)


static func update_floor_drops(owner, delta: float) -> void:
	if owner.rain_floor_drops_rect.size.x <= 0.0 or owner.rain_floor_drops_rect.size.y <= 0.0:
		return

	owner.rain_floor_drop_spawn_timer -= delta
	if owner.rain_floor_drop_spawn_timer <= 0.0 and owner.rain_floor_drops_rect.get_child_count() < owner.rain_floor_drop_max_active:
		spawn_floor_drop(owner)
		owner.rain_floor_drop_spawn_timer = owner.rng.randf_range(owner.rain_floor_drop_min_delay, owner.rain_floor_drop_max_delay)

	var floor_alpha: float = owner.rain_floor_drops_alpha
	if owner.stage_weather == "heavy rain":
		floor_alpha *= 1.35

	for index in range(owner.rain_floor_drops_rect.get_child_count() - 1, -1, -1):
		var drop: TextureRect = owner.rain_floor_drops_rect.get_child(index) as TextureRect
		if drop == null:
			continue
		var age: float = float(drop.get_meta("age", 0.0)) + delta
		var lifetime: float = maxf(0.001, float(drop.get_meta("lifetime", owner.rain_floor_drop_lifetime)))
		var ratio: float = clampf(age / lifetime, 0.0, 1.0)
		var visual_distance: float = owner.distance * owner.VISUAL_DISTANCE_SCALE
		var spawn_distance: float = float(drop.get_meta("spawn_distance", visual_distance))
		var spawn_x: float = float(drop.get_meta("spawn_x", drop.position.x))
		var road_x: float = spawn_x - (visual_distance - spawn_distance) * 16.0
		drop.set_meta("age", age)
		drop.position.x = road_x
		drop.scale = Vector2.ONE * lerpf(0.45, owner.rain_floor_drop_max_scale, ratio)
		drop.modulate = Color(1.0, 1.0, 1.0, floor_alpha * (1.0 - ratio))
		if ratio >= 1.0 or road_x < -64.0:
			drop.queue_free()


static func spawn_floor_drop(owner) -> void:
	if owner.rain_floor_drop_texture == null or owner.rain_floor_drops_rect == null:
		return

	var drop: TextureRect = TextureRect.new()
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.texture = owner.rain_floor_drop_texture
	drop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drop.size = Vector2(32.0, 16.0)
	drop.pivot_offset = drop.size * 0.5
	var layer_size: Vector2 = owner.rain_floor_drops_rect.size
	var viewport_size: Vector2 = owner.get_viewport_rect().size
	var lane_index: int = owner.rng.randi_range(0, 2)
	var lane_local_y: float = VehicleGeometry.lane_y(owner, lane_index, viewport_size) - viewport_size.y * 0.5
	var local_y: float = clampf(lane_local_y + owner.rng.randf_range(-18.0, 18.0), 10.0, maxf(10.0, layer_size.y - 10.0))
	var spawn_x: float = owner.rng.randf_range(24.0, maxf(24.0, layer_size.x - 24.0))
	drop.position = Vector2(spawn_x, local_y) - drop.pivot_offset
	drop.set_meta("age", 0.0)
	drop.set_meta("lifetime", owner.rain_floor_drop_lifetime * owner.rng.randf_range(0.82, 1.22))
	drop.set_meta("spawn_distance", owner.distance * owner.VISUAL_DISTANCE_SCALE)
	drop.set_meta("spawn_x", drop.position.x)
	owner.rain_floor_drops_rect.add_child(drop)


static func clear_floor_drops(owner) -> void:
	for child in owner.rain_floor_drops_rect.get_children():
		child.queue_free()
	owner.rain_floor_drop_spawn_timer = 0.0


static func update_ui(owner, speed_kmh: int, speedometer_max_kmh: int) -> void:
	if owner.game_hud == null:
		return
	owner.game_hud.update(
		owner.game_state,
		owner.end_message,
		speed_kmh,
		speedometer_max_kmh,
		owner.distance,
		owner.target_distance,
		owner.time_left,
		owner.stage_type
	)


static func current_time_filter_color(owner) -> Color:
	match owner.stage_time_of_day:
		"noon":
			if _weather_blocks_noon_light(owner):
				return owner.morning_filter_color
			return owner.noon_filter_color
		"night":
			return owner.night_filter_color
	return owner.morning_filter_color


static func current_weather_filter_color(owner) -> Color:
	match owner.stage_weather:
		"cloudy":
			return owner.cloudy_filter_color
		"rain":
			return owner.rain_filter_color
		"heavy rain":
			return owner.heavy_rain_filter_color
	return Color(0.0, 0.0, 0.0, 0.0)


static func current_headlight_alpha(owner) -> float:
	match owner.stage_time_of_day:
		"noon":
			return owner.noon_headlight_alpha
		"night":
			return owner.night_headlight_alpha
	return owner.morning_headlight_alpha


static func make_headlight_cone_texture() -> Texture2D:
	var width := 256
	var height := 96
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var warm_color := Color(1.0, 0.95, 0.78, 0.0)

	for y in range(height):
		for x in range(width):
			var x_ratio := float(x) / float(width - 1)
			var center_y := (height - 1) * 0.5
			var half_height := lerpf(3.0, height * 0.46, x_ratio)
			var y_offset := absf(float(y) - center_y) / maxf(1.0, half_height)
			if y_offset > 1.0:
				continue

			var longitudinal_falloff := pow(1.0 - x_ratio, 1.35)
			var lateral_falloff := pow(1.0 - y_offset, 1.8)
			var core_glow := exp(-pow((x_ratio - 0.18) / 0.24, 2.0)) * 0.42
			var alpha := clampf(longitudinal_falloff * lateral_falloff + core_glow * lateral_falloff, 0.0, 1.0)
			image.set_pixel(x, y, Color(warm_color.r, warm_color.g, warm_color.b, alpha))

	return ImageTexture.create_from_image(image)


static func update_noon_glow(owner) -> void:
	if owner.noon_glow_rect == null or owner.noon_glow_material == null:
		return

	owner.noon_glow_rect.visible = owner.stage_time_of_day == "noon" and not _weather_blocks_noon_light(owner)
	if not owner.noon_glow_rect.visible:
		return

	owner.noon_glow_material.set_shader_parameter("glow_center", owner.noon_glow_center)
	owner.noon_glow_material.set_shader_parameter("glow_radius", owner.noon_glow_radius)
	owner.noon_glow_material.set_shader_parameter("glow_color", owner.noon_glow_color)


static func _weather_blocks_noon_light(owner) -> bool:
	return owner.stage_weather == "cloudy" or owner.stage_weather == "rain" or owner.stage_weather == "heavy rain"


static func update_night_visibility_mask(owner) -> void:
	if owner.night_visibility_rect == null or owner.night_visibility_material == null or owner.player == null:
		return

	var is_night: bool = owner.stage_time_of_day == "night"
	owner.night_visibility_rect.visible = is_night
	if not is_night:
		return

	var viewport_size: Vector2 = owner.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var focus_position: Vector2 = owner.player.global_position + owner.night_visibility_focus_offset
	var focus_center := Vector2(
		clampf(focus_position.x / viewport_size.x, 0.0, 1.0),
		clampf(focus_position.y / viewport_size.y, 0.0, 1.0)
	)
	owner.night_visibility_material.set_shader_parameter("focus_center", focus_center)
	owner.night_visibility_material.set_shader_parameter("outer_radius", owner.night_visibility_outer_radius)
	owner.night_visibility_material.set_shader_parameter("inner_ratio", owner.night_visibility_inner_ratio)
	owner.night_visibility_material.set_shader_parameter("shade_color", owner.night_visibility_shade_color)
