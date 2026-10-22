extends RefCounted

# Shared home/results structure. Containers keep longer text above the actions.
static func build(owner: Control, header: Label, stats: Control, primary: Control, secondary: Array, buttons: HBoxContainer) -> void:
	owner.get_node("Panel").hide()
	var shell := PanelContainer.new()
	shell.name = "MenuLayout"
	owner.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var resize_shell := func() -> void:
		var side := maxf(20.0, (owner.size.x - 1080.0) * 0.5)
		shell.offset_left = side
		shell.offset_right = -side
		shell.offset_top = 20
		shell.offset_bottom = -20
	resize_shell.call()
	owner.resized.connect(resize_shell)
	shell.add_theme_stylebox_override("panel", _style(Color(0.94, 0.89, 0.78, 0.82), 24))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 16)
	scroll.add_child(stack)
	_move(header, stack)
	header.custom_minimum_size.y = 58
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _style(Color(0.35, 0.24, 0.13, 0.09), 10))
	stack.add_child(stats_panel)
	_move(stats, stats_panel)
	stats.custom_minimum_size.y = 24
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.custom_minimum_size.y = 220
	columns.add_theme_constant_override("separation", 20)
	stack.add_child(columns)
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_stylebox_override("panel", _style(Color(0.35, 0.24, 0.13, 0.06), 16))
	columns.add_child(left)
	_move(primary, left)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _style(Color(0.35, 0.24, 0.13, 0.06), 16))
	columns.add_child(right)
	var right_stack := VBoxContainer.new()
	right_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	right_stack.add_theme_constant_override("separation", 24)
	right.add_child(right_stack)
	for control in secondary:
		_move(control, right_stack)
		if control is Label:
			control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_move(buttons, stack)
	buttons.custom_minimum_size.y = 116
	buttons.add_theme_constant_override("separation", 16)
	for button in buttons.get_children():
		button.custom_minimum_size = Vector2(0, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if button is TextureButton:
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED


static func _move(control: Control, parent: Node) -> void:
	control.reparent(parent, false)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.size = Vector2.ZERO
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func _style(color: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.43, 0.31, 0.18, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
