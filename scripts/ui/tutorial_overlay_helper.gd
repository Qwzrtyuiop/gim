extends RefCounted


static func make_label(font: Font, font_size := 12) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	return label


static func layout_for_targets(owner: Control, highlight: Panel, text_panel: Panel, text_label: Label, targets: Array, require_visible := true) -> void:
	var rect := union_global_rect(targets, require_visible)
	var label_size := Vector2(620.0, 88.0)
	if text_label != null:
		var text_len := text_label.text.length()
		if text_len > 180:
			label_size.y = 170.0
		elif text_len > 120:
			label_size.y = 140.0

	if rect.size == Vector2.ZERO:
		if highlight != null:
			highlight.visible = false
		if text_panel != null:
			text_panel.size = label_size
			text_panel.global_position = Vector2(
				(owner.get_viewport_rect().size.x - label_size.x) * 0.5,
				120.0
			)
		return

	var padding := 14.0
	rect.position -= Vector2(padding, padding)
	rect.size += Vector2(padding * 2.0, padding * 2.0)
	if highlight != null:
		highlight.visible = true
		highlight.global_position = rect.position
		highlight.size = rect.size

	var label_pos := rect.position + Vector2((rect.size.x - label_size.x) * 0.5, rect.size.y + 16.0)
	if label_pos.y + label_size.y > owner.get_viewport_rect().size.y - 12.0:
		label_pos.y = rect.position.y - label_size.y - 16.0
	label_pos.y = maxf(label_pos.y, 12.0)
	label_pos.x = clampf(label_pos.x, 20.0, owner.get_viewport_rect().size.x - label_size.x - 20.0)
	if text_panel != null:
		text_panel.size = label_size
		text_panel.global_position = label_pos


static func union_global_rect(targets: Array, require_visible := true) -> Rect2:
	var has_rect := false
	var rect := Rect2()
	for target in targets:
		var control := target as Control
		if control == null:
			continue
		if require_visible and not control.visible:
			continue
		var target_rect := control.get_global_rect()
		if not has_rect:
			rect = target_rect
			has_rect = true
		else:
			rect = rect.merge(target_rect)
	return rect


static func set_overlay_visible(is_active: bool, overlay: Control, text_panel: Panel, text_label: Label) -> void:
	if overlay != null:
		overlay.visible = is_active
		if is_active:
			overlay.grab_focus()
	if text_panel != null:
		text_panel.visible = is_active
	if text_label != null:
		text_label.visible = is_active


static func set_buttons_disabled(is_active: bool, buttons: Array, disabled_state: Dictionary) -> void:
	if is_active:
		disabled_state.clear()
		for button_variant in buttons:
			var button := button_variant as BaseButton
			if button == null:
				continue
			disabled_state[button] = button.disabled
			button.disabled = true
		return

	for button_variant in disabled_state.keys():
		var button := button_variant as BaseButton
		if button == null:
			continue
		button.disabled = bool(disabled_state.get(button, false))
	disabled_state.clear()


static func set_mouse_filter(is_active: bool, controls: Array, filter_state: Dictionary, active_filter: Control.MouseFilter) -> void:
	if is_active:
		filter_state.clear()
		for control_variant in controls:
			var control := control_variant as Control
			if control == null:
				continue
			filter_state[control] = control.mouse_filter
			control.mouse_filter = active_filter
		return

	for control_variant in filter_state.keys():
		var control := control_variant as Control
		if control == null:
			continue
		control.mouse_filter = int(filter_state.get(control, control.mouse_filter))
	filter_state.clear()


static func is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false
