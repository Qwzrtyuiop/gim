extends RefCounted

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const UI_FRAME_TEXTURE := preload("res://assets/ui/ui_frame.png")
const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const GAS_ICON := preload("res://assets/ui/icons/gas_pump.svg")
const SPEEDOMETER_GAUGE := preload("res://scripts/speedometer_gauge.gd")

var refs: Dictionary = {}


func setup(parent: Node, gameplay_entry_fade_seconds: float, stage_type: String) -> Dictionary:
	var ui := CanvasLayer.new()
	parent.add_child(ui)
	refs["ui"] = ui

	var speedometer := SPEEDOMETER_GAUGE.new()
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
	bottom_bar.color = Color(0.06, 0.07, 0.08, 0.90)
	ui.add_child(bottom_bar)
	refs["bottom_bar"] = bottom_bar

	var help_label := _make_label(13, Color(0.95, 0.96, 0.88, 1.0), 4)
	ui.add_child(help_label)
	refs["help_label"] = help_label

	var distance_progress_bg := ColorRect.new()
	distance_progress_bg.color = Color(0.12, 0.14, 0.16, 0.92)
	ui.add_child(distance_progress_bg)
	refs["distance_progress_bg"] = distance_progress_bg

	var distance_progress_fill := ColorRect.new()
	distance_progress_fill.color = Color(0.32, 0.92, 0.66, 1.0)
	ui.add_child(distance_progress_fill)
	refs["distance_progress_fill"] = distance_progress_fill

	var distance_label := _make_label(14, Color(0.60, 0.95, 0.80, 1.0), 4)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(distance_label)
	refs["distance_label"] = distance_label

	var footer_stats_row := HBoxContainer.new()
	footer_stats_row.alignment = BoxContainer.ALIGNMENT_END
	footer_stats_row.add_theme_constant_override("separation", 14)
	ui.add_child(footer_stats_row)
	refs["footer_stats_row"] = footer_stats_row

	var footer_money_label := _make_label(14, Color(1.0, 0.97, 0.82, 1.0), 4)
	footer_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_stats_row.add_child(footer_money_label)
	refs["footer_money_label"] = footer_money_label

	footer_stats_row.add_child(_make_stat_icon(ENERGY_ICON, 22.0))
	var footer_energy_label := _make_label(15, Color(1.0, 0.97, 0.82, 1.0), 4)
	footer_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_stats_row.add_child(footer_energy_label)
	refs["footer_energy_label"] = footer_energy_label

	footer_stats_row.add_child(_make_stat_icon(GAS_ICON, 22.0))
	var footer_gas_label := _make_label(15, Color(1.0, 0.97, 0.82, 1.0), 4)
	footer_gas_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_stats_row.add_child(footer_gas_label)
	refs["footer_gas_label"] = footer_gas_label

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

	var debt_goal_label := _make_label(9, Color(0.92, 0.88, 0.74, 1.0), 3)
	debt_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debt_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debt_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(debt_goal_label)
	refs["debt_goal_label"] = debt_goal_label

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
	var fade_rect := refs.get("fade_rect") as ColorRect
	if fade_rect == null:
		return
	if gameplay_entry_fade_seconds <= 0.0:
		fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		return

	var tween := parent.create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, gameplay_entry_fade_seconds)


func layout(size: Vector2, player_x: float, player_lane: int, stage_type: String, lane_y_provider: Callable) -> void:
	var speedometer := refs.get("speedometer") as Control
	if speedometer:
		speedometer.position = Vector2(size.x - 320.0 - 6.0, size.y - 180.0)
		speedometer.size = Vector2(320.0, 150.0)

	var bottom_bar := refs.get("bottom_bar") as ColorRect
	if bottom_bar:
		bottom_bar.position = Vector2(0.0, size.y - 58.0)
		bottom_bar.size = Vector2(size.x, 58.0)

	var help_label := refs.get("help_label") as Label
	if help_label:
		help_label.text = "UP/DOWN lane    LEFT/RIGHT speed    SHIFT boost    SPACE/R action"
		help_label.position = Vector2(28.0, size.y - 45.0)
		help_label.size = Vector2(size.x * 0.34, 34.0)

	var time_label := refs.get("time_label") as Label
	if time_label:
		time_label.position = Vector2(size.x * 0.5 - 120.0, 18.0)
		time_label.size = Vector2(240.0, 32.0)

	var distance_progress_bg := refs.get("distance_progress_bg") as ColorRect
	if distance_progress_bg:
		distance_progress_bg.position = Vector2(size.x * 0.5 - 160.0, size.y - 86.0)
		distance_progress_bg.size = Vector2(320.0, 10.0)

	var distance_progress_fill := refs.get("distance_progress_fill") as ColorRect
	if distance_progress_fill:
		distance_progress_fill.position = Vector2(size.x * 0.5 - 160.0, size.y - 86.0)
		distance_progress_fill.size = Vector2.ZERO

	var distance_label := refs.get("distance_label") as Label
	if distance_label:
		distance_label.position = Vector2(size.x * 0.5 - 180.0, size.y - 70.0)
		distance_label.size = Vector2(360.0, 30.0)

	var footer_stats_row := refs.get("footer_stats_row") as HBoxContainer
	if footer_stats_row:
		footer_stats_row.position = Vector2(size.x * 0.64, size.y - 50.0)
		footer_stats_row.size = Vector2(size.x * 0.34 - 24.0, 40.0)

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

	var footer_money_label := refs.get("footer_money_label") as Label
	if footer_money_label:
		footer_money_label.text = "PhP %d" % PlayerState.money
	var footer_energy_label := refs.get("footer_energy_label") as Label
	if footer_energy_label:
		footer_energy_label.text = "%d/%d" % [PlayerState.energy, PlayerState.max_energy]
	var footer_gas_label := refs.get("footer_gas_label") as Label
	if footer_gas_label:
		footer_gas_label.text = PlayerState.gas_text()

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

	var debt_goal_label := refs.get("debt_goal_label") as Label
	if debt_goal_label:
		debt_goal_label.text = "Debt Remaining: PhP %d\n%s" % [
			PlayerState.get_total_debt_goal(),
			PlayerState.get_debt_due_text(),
		]


func _layout_stage_panel(stage_type: String) -> void:
	var top_right_info_panel := refs.get("top_right_info_panel") as TextureRect
	if top_right_info_panel == null:
		return

	top_right_info_panel.position = Vector2(18.0, 10.0)
	top_right_info_panel.size = Vector2(312.0, 128.0)

	var stage_label := refs.get("stage_label") as Label
	if stage_label:
		stage_label.text = "DAY %d\n%s" % [PlayerState.get_current_day(), stage_type.to_upper()]
		stage_label.position = Vector2(40.0, 26.0)
		stage_label.size = Vector2(268.0, 42.0)

	var weekly_goal_label := refs.get("weekly_goal_label") as Label
	if weekly_goal_label:
		weekly_goal_label.position = Vector2(40.0, 70.0)
		weekly_goal_label.size = Vector2(268.0, 22.0)

	var debt_goal_label := refs.get("debt_goal_label") as Label
	if debt_goal_label:
		debt_goal_label.position = Vector2(40.0, 92.0)
		debt_goal_label.size = Vector2(268.0, 24.0)


func _make_warning_label() -> Label:
	var label := _make_label(48, Color(1.0, 0.92, 0.2, 1.0), 7)
	label.text = "!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	return label


func _make_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _make_stat_icon(texture: Texture2D, size_value: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size_value, size_value)
	return icon
