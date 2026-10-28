extends RefCounted

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const UI_FRAME_TEXTURE := preload("res://assets/ui/frames/ui_frame.png")
const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const STRESS_ICON := preload("res://assets/ui/icons/stress_brain.png")
const HULL_ICON := preload("res://assets/ui/icons/tricycle_condition.png")
const GAS_ICON := preload("res://assets/ui/icons/gas_pump.svg")
const StressShieldIndicator := preload("res://scripts/ui/stress_shield_indicator.gd")
const SPEEDOMETER_GAUGE := preload("res://scripts/speedometer_gauge.gd")

var refs: Dictionary = {}
var entry_fade_tween: Tween


func setup(parent: Node, gameplay_entry_fade_seconds: float, stage_type: String) -> Dictionary:
	var ui := CanvasLayer.new()
	parent.add_child(ui)
	refs["ui"] = ui

	var speedometer := SPEEDOMETER_GAUGE.new()
	speedometer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedometer.position = Vector2(954.0, 510.0)
	speedometer.size = Vector2(320.0, 150.0)
	ui.add_child(speedometer)
	refs["speedometer"] = speedometer

	var time_label := _make_label(16, Color(0.78, 0.92, 0.94, 1.0), 4)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(time_label)
	refs["time_label"] = time_label

	var bottom_bar := ColorRect.new()
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.color = Color(0.06, 0.07, 0.08, 0.90)
	ui.add_child(bottom_bar)
	refs["bottom_bar"] = bottom_bar

	var help_label := _make_label(10, Color(0.95, 0.96, 0.88, 1.0), 4)
	ui.add_child(help_label)
	refs["help_label"] = help_label

	var distance_progress_bg := ColorRect.new()
	distance_progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_progress_bg.color = Color(0.12, 0.14, 0.16, 0.92)
	ui.add_child(distance_progress_bg)
	refs["distance_progress_bg"] = distance_progress_bg

	var distance_progress_fill := ColorRect.new()
	distance_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_progress_fill.color = Color(0.32, 0.92, 0.66, 1.0)
	ui.add_child(distance_progress_fill)
	refs["distance_progress_fill"] = distance_progress_fill

	var distance_label := _make_label(14, Color(0.60, 0.95, 0.80, 1.0), 4)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(distance_label)
	refs["distance_label"] = distance_label

	var footer_stats_row := HBoxContainer.new()
	footer_stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_stats_row.alignment = BoxContainer.ALIGNMENT_END
	footer_stats_row.add_theme_constant_override("separation", 12)
	ui.add_child(footer_stats_row)
	refs["footer_stats_row"] = footer_stats_row
	var footer_money_label := _make_label(12, Color(1.0, 0.97, 0.82), 2)
	footer_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_stats_row.add_child(footer_money_label)
	refs["footer_money_label"] = footer_money_label
	var icons := [ENERGY_ICON, STRESS_ICON, HULL_ICON, GAS_ICON]
	var resources := ["energy", "stress", "hull", "gas"]
	for index in range(resources.size()):
		var icon := _make_stat_icon(icons[index], 22.0)
		footer_stats_row.add_child(icon)
		if resources[index] == "stress":
			icon.add_child(StressShieldIndicator.new())
		var resource_label := _make_label(12, Color(1.0, 0.97, 0.82), 2)
		resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		footer_stats_row.add_child(resource_label)
		refs["footer_%s_label" % resources[index]] = resource_label
	_refresh_footer_stats()

	var status_label := _make_label(22, Color(1.0, 0.97, 0.82, 1.0), 6)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(status_label)
	refs["status_label"] = status_label

	var top_right_info_panel := TextureRect.new()
	top_right_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right_info_panel.texture = UI_FRAME_TEXTURE
	top_right_info_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_right_info_panel.stretch_mode = TextureRect.STRETCH_SCALE
	ui.add_child(top_right_info_panel)
	refs["top_right_info_panel"] = top_right_info_panel

	var stage_label := _make_label(11, Color(0.92, 0.95, 0.88, 1.0), 4)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_label.text = "DAY %d\n%s" % [PlayerState.get_current_day(), stage_type.to_upper()]
	ui.add_child(stage_label)
	refs["stage_label"] = stage_label

	var weekly_goal_label := _make_label(12, Color(1.0, 0.95, 0.78, 1.0), 4)
	weekly_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weekly_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(weekly_goal_label)
	refs["weekly_goal_label"] = weekly_goal_label

	var speeder_warning_label := _make_warning_label()
	ui.add_child(speeder_warning_label)
	refs["speeder_warning_label"] = speeder_warning_label

	var speeder_lane_change_warning_label := _make_warning_label()
	ui.add_child(speeder_lane_change_warning_label)
	refs["speeder_lane_change_warning_label"] = speeder_lane_change_warning_label

	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0 if gameplay_entry_fade_seconds > 0.0 else 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade_rect)
	refs["fade_rect"] = fade_rect

	return refs


func begin_gameplay_entry_fade(parent: Node, gameplay_entry_fade_seconds: float) -> void:
	cancel_gameplay_entry_fade()
	var fade_rect := refs.get("fade_rect") as ColorRect
	if fade_rect == null:
		return
	if gameplay_entry_fade_seconds <= 0.0:
		fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		return

	entry_fade_tween = parent.create_tween()
	entry_fade_tween.tween_property(fade_rect, "color:a", 0.0, gameplay_entry_fade_seconds)


func cancel_gameplay_entry_fade() -> void:
	if entry_fade_tween != null and entry_fade_tween.is_valid():
		entry_fade_tween.kill()
	entry_fade_tween = null


func layout(size: Vector2, player_x: float, player_lane: int, stage_type: String, lane_y_provider: Callable) -> void:
	var compact := size.x < 800.0
	var gauge_scale := 0.75 if compact else 1.0
	var gauge_left := size.x - 12.0 - 320.0 * gauge_scale
	var speedometer := refs.get("speedometer") as Control
	if speedometer:
		speedometer.scale = Vector2.ONE * gauge_scale
		speedometer.size = Vector2(320.0, 150.0)
		# Tuck the dial's base behind the footer, which draws above the gauge.
		speedometer.position = Vector2(gauge_left, size.y - 36.0 - 150.0 * gauge_scale)

	var bottom_bar := refs.get("bottom_bar") as ColorRect
	if bottom_bar:
		bottom_bar.position = Vector2(0.0, size.y - 58.0)
		bottom_bar.size = Vector2(size.x, 58.0)

	var footer_stats_row := refs.get("footer_stats_row") as HBoxContainer
	if footer_stats_row:
		footer_stats_row.add_theme_constant_override("separation", 8 if compact else 12)
		for child: Control in footer_stats_row.get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", 9 if compact else 12)
			elif child is TextureRect:
				child.custom_minimum_size = Vector2.ONE * (18.0 if compact else 22.0)
		footer_stats_row.position = Vector2(16.0, size.y - 52.0)
		footer_stats_row.size = Vector2(size.x - 32.0, 24.0)

	var help_label := refs.get("help_label") as Label
	if help_label:
		help_label.text = "ARROWS/WASD drive   SHIFT boost   Q horn"
		help_label.add_theme_font_size_override("font_size", 8 if compact else 9)
		help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		help_label.position = Vector2(16.0, size.y - 24.0)
		help_label.size = Vector2(size.x - 32.0, 18.0)

	var time_label := refs.get("time_label") as Label
	if time_label:
		time_label.position = Vector2(minf(size.x - 252.0, maxf(342.0, size.x * 0.5 - 120.0)), 18.0)
		time_label.size = Vector2(240.0, 32.0)

	# Keep the trip readout centered unless a narrow viewport brings the gauge
	# into that space; then center it in the clear area to the gauge's left.
	var distance_width := minf(360.0, maxf(200.0, gauge_left - 40.0))
	var distance_center := minf(size.x * 0.5, gauge_left - 16.0 - distance_width * 0.5)
	var progress_width := minf(320.0, distance_width)
	var progress_left := distance_center - progress_width * 0.5
	var distance_progress_bg := refs.get("distance_progress_bg") as ColorRect
	if distance_progress_bg:
		distance_progress_bg.position = Vector2(progress_left, size.y - 94.0)
		distance_progress_bg.size = Vector2(progress_width, 8.0)

	var distance_progress_fill := refs.get("distance_progress_fill") as ColorRect
	if distance_progress_fill:
		distance_progress_fill.position = Vector2(progress_left, size.y - 94.0)
		distance_progress_fill.size = Vector2.ZERO

	var distance_label := refs.get("distance_label") as Label
	if distance_label:
		distance_label.add_theme_font_size_override("font_size", 10 if compact else 12)
		distance_label.position = Vector2(distance_center - distance_width * 0.5, size.y - 82.0)
		distance_label.size = Vector2(distance_width, 22.0)

	var status_label := refs.get("status_label") as Label
	if status_label:
		status_label.position = Vector2(0.0, size.y * 0.37)
		status_label.size = Vector2(size.x, 120.0)

	_layout_stage_panel(stage_type)

	var speeder_warning_label := refs.get("speeder_warning_label") as Label
	if speeder_warning_label:
		speeder_warning_label.position = Vector2(player_x + 105.0, float(lane_y_provider.call(1, size)) - 92.0)
		speeder_warning_label.size = Vector2(90.0, 90.0)

	var speeder_lane_change_warning_label := refs.get("speeder_lane_change_warning_label") as Label
	if speeder_lane_change_warning_label:
		speeder_lane_change_warning_label.position = Vector2(player_x + 105.0, float(lane_y_provider.call(max(player_lane, 1), size)) - 92.0)
		speeder_lane_change_warning_label.size = Vector2(90.0, 90.0)

	var fade_rect := refs.get("fade_rect") as ColorRect
	if fade_rect:
		fade_rect.position = Vector2.ZERO
		fade_rect.size = size


func update(
	game_state: String,
	end_message: String,
	speed_kmh: int,
	speedometer_max_kmh: int,
	distance: float,
	target_distance: float,
	time_left: float,
	stage_type: String
) -> void:
	var speedometer = refs.get("speedometer")
	if speedometer:
		var speed_ratio := float(speed_kmh) / float(speedometer_max_kmh)
		speedometer.set_values(speed_kmh, speed_ratio, floori(distance), floori(target_distance), time_left)

	var status_label := refs.get("status_label") as Label
	if status_label:
		status_label.text = "" if game_state == "playing" else "%s\n%s" % [game_state, end_message]
	_refresh_footer_stats()

	var time_label := refs.get("time_label") as Label
	if time_label:
		time_label.text = "TIME  %04.1f SEC" % time_left

	var distance_progress_fill := refs.get("distance_progress_fill") as ColorRect
	var distance_progress_bg := refs.get("distance_progress_bg") as ColorRect
	if distance_progress_fill and distance_progress_bg:
		var distance_ratio := clampf(distance / maxf(1.0, target_distance), 0.0, 1.0)
		distance_progress_fill.position = distance_progress_bg.position
		distance_progress_fill.size = Vector2(distance_progress_bg.size.x * distance_ratio, distance_progress_bg.size.y)

	var distance_label := refs.get("distance_label") as Label
	if distance_label:
		distance_label.text = "DISTANCE  %04dM / %04dM" % [floori(distance), floori(target_distance)]

	var stage_label := refs.get("stage_label") as Label
	if stage_label:
		stage_label.text = "DAY %d\n%s" % [PlayerState.get_current_day(), stage_type.to_upper()]

	var weekly_goal_label := refs.get("weekly_goal_label") as Label
	if weekly_goal_label:
		weekly_goal_label.text = "WEEKLY GOAL: PhP %d" % PlayerState.get_current_weekly_goal()


func _refresh_footer_stats() -> void:
	refs.footer_money_label.text = "PhP %d" % PlayerState.money
	refs.footer_energy_label.text = "%d/%d" % [PlayerState.energy, PlayerState.max_energy]
	refs.footer_stress_label.text = "%d/%d" % [PlayerState.stress, PlayerState.max_stress]
	refs.footer_hull_label.text = "%d/%d" % [PlayerState.hull, PlayerState.max_hull]
	refs.footer_gas_label.text = PlayerState.gas_text()


func _layout_stage_panel(stage_type: String) -> void:
	var top_right_info_panel := refs.get("top_right_info_panel") as TextureRect
	if top_right_info_panel == null:
		return

	top_right_info_panel.position = Vector2(18.0, 10.0)
	top_right_info_panel.size = Vector2(312.0, 104.0)

	var stage_label := refs.get("stage_label") as Label
	if stage_label:
		stage_label.text = "DAY %d\n%s" % [PlayerState.get_current_day(), stage_type.to_upper()]
		stage_label.position = Vector2(40.0, 26.0)
		stage_label.size = Vector2(268.0, 42.0)

	var weekly_goal_label := refs.get("weekly_goal_label") as Label
	if weekly_goal_label:
		weekly_goal_label.position = Vector2(40.0, 70.0)
		weekly_goal_label.size = Vector2(268.0, 22.0)


func _make_warning_label() -> Label:
	var label := _make_label(48, Color(1.0, 0.92, 0.2, 1.0), 7)
	label.text = "!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	return label


func _make_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func get_ui_root() -> CanvasLayer:
	return refs.get("ui") as CanvasLayer


func _make_stat_icon(texture: Texture2D, size_value: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * size_value
	return icon
