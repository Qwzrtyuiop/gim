extends RefCounted

const BackgroundScroller := preload("res://scripts/game/background_scroller.gd")
const GameAudioManager := preload("res://scripts/game/game_audio_manager.gd")
const GameHud := preload("res://scripts/game/game_hud.gd")
const PlayerVehicleController := preload("res://scripts/game/player_vehicle_controller.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")


static func hide_editor_preview(owner) -> void:
	var editor_preview: CanvasItem = owner.get_node_or_null("EditorPreview") as CanvasItem
	if editor_preview:
		editor_preview.visible = false


static func create_audio_manager(owner) -> void:
	owner.audio_manager = GameAudioManager.new()
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
		owner.background_scroller.update(owner.distance)


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
		"night":
			return owner.night_filter_color
	return owner.morning_filter_color


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

	owner.noon_glow_rect.visible = owner.stage_time_of_day == "noon"
	if not owner.noon_glow_rect.visible:
		return

	owner.noon_glow_material.set_shader_parameter("glow_center", owner.noon_glow_center)
	owner.noon_glow_material.set_shader_parameter("glow_radius", owner.noon_glow_radius)
	owner.noon_glow_material.set_shader_parameter("glow_color", owner.noon_glow_color)


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
