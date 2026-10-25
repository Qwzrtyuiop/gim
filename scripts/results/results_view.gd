extends Control

# Results presentation owns no rewards, calendar changes or scene transitions.
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const StageState := preload("res://scripts/state/player_stage_state.gd")
const CREAM := Color("faefd5")
const MUTED := Color("b8ab92")
const GOLD := Color("dfba78")

var canvas: Control
var heading_label: Label
var date_label: Label
var route_label: Label
var special_label: Label
var portrait: TextureRect
var passenger_name: Label
var passenger_panel: PanelContainer
var receipt_panel: PanelContainer
var goal_panel: Panel
var receipt_rows: VBoxContainer
var total_label: Label
var goal_label: Label
var goal_progress: ProgressBar
var goal_progress_label: Label
var earnings_summary_label: Label
var debt_label: Label
var due_label: Label
var footer_note: Label
var stats_refs: Dictionary = {}
var _stats_panel: PanelContainer
var _goal_caption: Label
var _goal_divider: ColorRect
var _passenger_status: Label
var _total_caption: Label
var _buttons: HBoxContainer


func build(buttons: HBoxContainer) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Control.new()
	canvas.name = "ResultsLayout"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var caption := _label(9, GOLD, "TRIP SUMMARY")
	canvas.add_child(caption)
	_place(caption, Rect2(0, 0, 460, 16))
	heading_label = _label(24, CREAM)
	canvas.add_child(heading_label)
	date_label = _label(11, MUTED)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	canvas.add_child(date_label)
	_build_stats()
	_build_passenger()
	_build_receipt()
	_build_goal()
	_buttons = buttons
	buttons.reparent(canvas, false)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	for button: TextureButton in buttons.get_children():
		button.custom_minimum_size = Vector2(216, 78)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	footer_note = _label(9, MUTED)
	footer_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(footer_note)
	resized.connect(_layout)
	_layout()


func present(result: Dictionary, passenger: Dictionary) -> void:
	var completed := bool(result.get("completed", true))
	heading_label.text = "RIDE COMPLETE" if completed else "TRIP ENDED"
	date_label.text = "DAY %d / %s" % [int(result.get("day", PlayerState.get_current_day())), str(result.get("time_of_day", "morning")).capitalize()]
	var stage: Dictionary = StageState.parse_stage_type(PlayerState, str(result.get("stage_type", "short-morning-chill")))
	var distance := str(result.get("difficulty", stage.get("difficulty", "short")))
	var traffic := str(result.get("traffic", stage.get("traffic", "chill")))
	route_label.text = "%s trip / %s" % [distance.capitalize(), traffic.replace("-", " ").capitalize()]
	special_label.text = PlayerState.get_stage_special_display_name(str(result.get("stage_special_type", "")))
	special_label.visible = not special_label.text.is_empty()
	portrait.texture = passenger.get("texture") as Texture2D
	passenger_name.text = str(passenger.get("name", "Passenger"))
	passenger_name.tooltip_text = passenger_name.text
	_passenger_status.text = "DROPPED OFF" if completed else "TRIP INTERRUPTED"
	_total_caption.text = "TOTAL EARNED" if completed else "NO PAYOUT"
	total_label.text = "PHP %d" % int(result.get("total", 0))
	for child in receipt_rows.get_children():
		receipt_rows.remove_child(child)
		child.queue_free()
	var lines: Array = result.get("detail_lines", []) if result.get("detail_lines", []) is Array else []
	if lines.is_empty():
		lines = [
			"Distance: %dm" % int(result.get("distance", 0)),
			"Fare: PhP %d" % int(result.get("fare", 0)),
			"Bonus: PhP %d" % int(result.get("bonus", 0)),
		]
		if not completed:
			lines.append("Reason: %s" % str(result.get("failure_reason", "Trip interrupted")))
	for line in lines:
		_add_receipt_line(str(line))
	var skipped := str(result.get("bayanihan_skipped_phase", ""))
	if not skipped.is_empty():
		_add_receipt_line("Bayanihan: %s turn spent helping." % skipped.capitalize())
	update_goal(int(result.get("total", 0)), completed)


func update_goal(total: int, completed: bool) -> void:
	PlayerStatsRow.refresh(stats_refs)
	var goal: int = PlayerState.get_current_weekly_goal()
	var available: int = maxi(0, PlayerState.money)
	goal_label.text = "PHP %d" % goal if goal > 0 else "DEBT SETTLED"
	goal_progress.value = clampf(float(available) / float(goal) * 100.0, 0, 100) if goal > 0 else 100.0
	goal_progress_label.text = "PHP %d available / %.1f%%" % [available, float(available) / float(goal) * 100.0] if goal > 0 else "No collection remaining."
	if not completed:
		earnings_summary_label.text = "No payout this trip.\nRecover and try another route."
	elif total == 0:
		earnings_summary_label.text = "No fare collected this trip."
	elif goal > 0:
		earnings_summary_label.text = "This ride earned %.1f%% of your weekly goal." % (float(total) / float(goal) * 100.0)
	else:
		earnings_summary_label.text = "You earned PHP %d.\nThe debt is paid off." % total
	debt_label.text = "DEBT REMAINING\n\nPHP %d" % PlayerState.get_total_debt_goal()
	due_label.text = PlayerState.get_debt_due_text() if goal > 0 else "All paid."


func set_rest_note(note: String) -> void:
	footer_note.text = note


func _build_stats() -> void:
	_stats_panel = PanelContainer.new()
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.03, 0.02, 0.94), 16, 10))
	canvas.add_child(_stats_panel)
	stats_refs = PlayerStatsRow.create({
		"spread": true,
		"font": FONT,
		"font_size": 11,
		"font_color": CREAM,
		"outline_color": Color("181008"),
	})
	_stats_panel.add_child(stats_refs["row"])


func _build_passenger() -> void:
	passenger_panel = _panel(Color(0.12, 0.10, 0.07, 0.97), 18)
	var content := _stack(passenger_panel, 12)
	content.add_child(_label(9, GOLD, "PASSENGER"))
	portrait = TextureRect.new()
	portrait.name = "PassengerPortrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(portrait)
	passenger_name = _label(16, CREAM)
	passenger_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passenger_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(passenger_name)
	_passenger_status = _label(9, MUTED)
	_passenger_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_passenger_status)


func _build_receipt() -> void:
	receipt_panel = _panel(Color(0.055, 0.043, 0.03, 0.98), 24)
	var content := _stack(receipt_panel, 14)
	content.add_child(_label(10, GOLD, "FARE BREAKDOWN"))
	route_label = _label(11, CREAM)
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(route_label)
	special_label = _label(9, GOLD)
	content.add_child(special_label)
	content.add_child(_divider())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	receipt_rows = VBoxContainer.new()
	receipt_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	receipt_rows.add_theme_constant_override("separation", 14)
	scroll.add_child(receipt_rows)
	content.add_child(_divider())
	_total_caption = _label(9, MUTED)
	content.add_child(_total_caption)
	total_label = _label(28, GOLD)
	content.add_child(total_label)


func _build_goal() -> void:
	goal_panel = Panel.new()
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_panel.add_theme_stylebox_override("panel", _style(Color(0.075, 0.065, 0.045, 0.97), 0, 0))
	canvas.add_child(goal_panel)
	_goal_caption = _label(10, GOLD, "WEEKLY GOAL")
	goal_panel.add_child(_goal_caption)
	goal_label = _label(20, CREAM)
	goal_panel.add_child(goal_label)
	goal_progress = ProgressBar.new()
	goal_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_progress.show_percentage = false
	goal_progress.add_theme_stylebox_override("background", _style(Color("30291d"), 0, 0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(3)
	goal_progress.add_theme_stylebox_override("fill", fill)
	goal_panel.add_child(goal_progress)
	goal_progress_label = _label(10, MUTED)
	goal_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(goal_progress_label)
	earnings_summary_label = _label(11, CREAM)
	earnings_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(earnings_summary_label)
	_goal_divider = ColorRect.new()
	_goal_divider.color = Color(0.65, 0.54, 0.37, 0.4)
	_goal_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_panel.add_child(_goal_divider)
	debt_label = _label(11, MUTED)
	goal_panel.add_child(debt_label)
	due_label = _label(10, GOLD)
	due_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(due_label)


func _add_receipt_line(text: String) -> void:
	# Keep authored event explanations and warning amounts intact. Only the total
	# moves into its own prominent field instead of being repeated in the receipt.
	var colon := text.find(":")
	if colon > 0 and text.left(colon).strip_edges().to_lower() == "total":
		return
	if colon < 0:
		var note := _label(10, MUTED, text)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		receipt_rows.add_child(note)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	receipt_rows.add_child(row)
	var caption := _label(11, MUTED, text.left(colon))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(caption)
	var value := _label(11, CREAM, text.substr(colon + 1).strip_edges())
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value)


func _layout() -> void:
	if canvas == null:
		return
	var compact := size.x / maxf(size.y, 1.0) < 1.4
	canvas.size = Vector2(840, 800) if compact else Vector2(1160, 660)
	var fit := minf((size.x - 48) / canvas.size.x, (size.y - 40) / canvas.size.y)
	fit = clampf(fit, 0.1, 1.5)
	canvas.scale = Vector2.ONE * fit
	canvas.position = ((size - canvas.size * fit) * 0.5).round()
	var width := canvas.size.x
	_place(heading_label, Rect2(0, 24, width, 36))
	_place(date_label, Rect2(width - 250, 0, 250, 16))
	_place(_stats_panel, Rect2(0, 76, width, 48))
	if compact:
		_place(passenger_panel, Rect2(0, 140, 240, 360))
		_place(receipt_panel, Rect2(256, 140, 584, 360))
		_place(goal_panel, Rect2(0, 516, 840, 156))
		_place(_buttons, Rect2(0, 688, width, 78))
		_place(footer_note, Rect2(0, 776, width, 24))
		_place(_goal_caption, Rect2(20, 18, 260, 16))
		_place(goal_label, Rect2(20, 44, 270, 26))
		_place(goal_progress, Rect2(20, 84, 264, 10))
		_place(goal_progress_label, Rect2(20, 108, 270, 32))
		_place(earnings_summary_label, Rect2(316, 24, 228, 112))
		_place(_goal_divider, Rect2(570, 20, 1, 116))
		_place(debt_label, Rect2(594, 24, 226, 60))
		_place(due_label, Rect2(594, 108, 226, 32))
	else:
		_place(passenger_panel, Rect2(0, 140, 280, 380))
		_place(receipt_panel, Rect2(296, 140, 520, 380))
		_place(goal_panel, Rect2(832, 140, 328, 380))
		_place(_buttons, Rect2(0, 540, width, 78))
		_place(footer_note, Rect2(0, 632, width, 28))
		_place(_goal_caption, Rect2(24, 24, 280, 16))
		_place(goal_label, Rect2(24, 56, 280, 26))
		_place(goal_progress, Rect2(24, 106, 280, 10))
		_place(goal_progress_label, Rect2(24, 132, 280, 38))
		_place(earnings_summary_label, Rect2(24, 190, 280, 66))
		_place(_goal_divider, Rect2(24, 268, 280, 1))
		_place(debt_label, Rect2(24, 292, 280, 48))
		_place(due_label, Rect2(24, 348, 280, 20))


func _panel(color: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, padding, padding))
	canvas.add_child(panel)
	return panel


func _stack(parent: Control, separation: int) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", separation)
	parent.add_child(content)
	return content


func _style(color: Color, horizontal_padding: int, vertical_padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("8e7652")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = vertical_padding
	style.content_margin_bottom = vertical_padding
	return style


func _divider() -> HSeparator:
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(0.65, 0.54, 0.37, 0.4)
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator


func _label(font_size: int, color: Color, text := "") -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 6)
	label.text = text
	return label


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
