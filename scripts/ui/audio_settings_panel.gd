extends RefCounted

const CATEGORY_ROWS := [
	{"id": "master", "label": "MASTER"},
	{"id": "music", "label": "MUSIC"},
	{"id": "sfx", "label": "SFX"},
	{"id": "ui", "label": "UI"},
]


static func create(host: Node, parent: Control, font: Font, position_value: Vector2, size_value: Vector2, title_text := "AUDIO") -> Dictionary:
	var refs := {
		"panel": Panel.new(),
		"sliders": {},
		"value_labels": {},
	}
	var panel := refs["panel"] as Panel
	panel.position = position_value
	panel.size = size_value
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	parent.add_child(panel)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0.0, 14.0)
	title.size = Vector2(size_value.x, 22.0)
	_apply_label_theme(title, font, 13, Color(0.97, 0.93, 0.80, 1.0), 2)
	panel.add_child(title)

	var rows := VBoxContainer.new()
	rows.position = Vector2(18.0, 46.0)
	rows.size = Vector2(size_value.x - 36.0, size_value.y - 60.0)
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)

	for row_data in CATEGORY_ROWS:
		var category_id := str(row_data["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		rows.add_child(row)

		var label := Label.new()
		label.custom_minimum_size = Vector2(70.0, 24.0)
		label.text = str(row_data["label"])
		_apply_label_theme(label, font, 11, Color(0.96, 0.93, 0.84, 1.0), 1, HORIZONTAL_ALIGNMENT_LEFT)
		row.add_child(label)

		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = roundf(AudioSettingsManager.get_category_volume(category_id) * 100.0)
		row.add_child(slider)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(52.0, 24.0)
		value_label.text = "%d%%" % roundi(slider.value)
		_apply_label_theme(value_label, font, 10, Color(0.92, 0.88, 0.76, 1.0), 1)
		row.add_child(value_label)

		slider.value_changed.connect(func(value: float) -> void:
			AudioSettingsManager.set_category_volume(category_id, value / 100.0)
			value_label.text = "%d%%" % roundi(value)
		)

		refs["sliders"][category_id] = slider
		refs["value_labels"][category_id] = value_label

	var sync_callable := func(category: String, value: float) -> void:
		if host == null or not is_instance_valid(host):
			return
		if not refs["sliders"].has(category):
			return
		var category_slider_variant = refs["sliders"].get(category, null)
		var category_value_label_variant = refs["value_labels"].get(category, null)
		if category_slider_variant != null and is_instance_valid(category_slider_variant):
			var category_slider := category_slider_variant as Range
			category_slider.set_value_no_signal(roundf(value * 100.0))
		if category_value_label_variant != null and is_instance_valid(category_value_label_variant):
			var category_value_label := category_value_label_variant as Label
			category_value_label.text = "%d%%" % roundi(value * 100.0)
	if not AudioSettingsManager.category_volume_changed.is_connected(sync_callable):
		AudioSettingsManager.category_volume_changed.connect(sync_callable)
	host.tree_exiting.connect(func() -> void:
		if AudioSettingsManager.category_volume_changed.is_connected(sync_callable):
			AudioSettingsManager.category_volume_changed.disconnect(sync_callable)
	, CONNECT_ONE_SHOT)

	return refs


static func _apply_label_theme(label: Label, font: Font, font_size: int, font_color: Color, outline_size: int, horizontal_alignment := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	label.horizontal_alignment = horizontal_alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", outline_size)


static func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.92)
	style.border_color = Color(0.68, 0.52, 0.28, 0.98)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	return style
