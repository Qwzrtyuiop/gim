extends RefCounted

const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const STRESS_ICON := preload("res://assets/ui/icons/stress_brain.png")
const HULL_ICON := preload("res://assets/ui/icons/tricycle_condition.png")
const GAS_ICON := preload("res://assets/ui/icons/gas_pump.svg")
const StressShieldIndicator := preload("res://scripts/ui/stress_shield_indicator.gd")
const DEFAULT_FONT_COLOR := Color(0.27, 0.18, 0.10, 1.0)
const DEFAULT_OUTLINE_COLOR := Color(0.95, 0.90, 0.78, 0.92)
const DEFAULT_ICON_SIZE := Vector2(22.0, 22.0)


static func create(config: Dictionary = {}) -> Dictionary:
	var two_rows := bool(config.get("two_rows", false))
	var row: BoxContainer = VBoxContainer.new() if two_rows else HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.alignment = int(config.get("alignment", BoxContainer.ALIGNMENT_CENTER))
	row.add_theme_constant_override("separation", int(config.get("separation", 12)))

	var label_config := {
		"font": config.get("font", null),
		"font_size": int(config.get("font_size", 11)),
		"font_color": config.get("font_color", DEFAULT_FONT_COLOR),
		"outline_color": config.get("outline_color", DEFAULT_OUTLINE_COLOR),
	}
	var icon_size: Vector2 = config.get("icon_size", DEFAULT_ICON_SIZE)
	var energy_icon := _make_icon(ENERGY_ICON, icon_size)
	var stress_icon := _make_icon(STRESS_ICON, icon_size)
	stress_icon.add_child(StressShieldIndicator.new())
	var hull_icon := _make_icon(HULL_ICON, icon_size)
	var gas_icon := _make_icon(GAS_ICON, icon_size)

	var money_label := _make_label(label_config)
	if bool(config.get("spread", false)):
		money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var energy_label := _make_label(label_config)
	var stress_label := _make_label(label_config)
	var hull_label := _make_label(label_config)
	var gas_label := _make_label(label_config)

	var first_row: BoxContainer = row
	var second_row: BoxContainer = row
	if two_rows:
		row.add_theme_constant_override("separation", 2)
		first_row = HBoxContainer.new()
		second_row = HBoxContainer.new()
		for line in [first_row, second_row]:
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.alignment = row.alignment
			line.add_theme_constant_override("separation", int(config.get("separation", 12)))
			row.add_child(line)
	first_row.add_child(money_label)
	first_row.add_child(energy_icon)
	first_row.add_child(energy_label)
	second_row.add_child(stress_icon)
	second_row.add_child(stress_label)
	second_row.add_child(hull_icon)
	second_row.add_child(hull_label)
	second_row.add_child(gas_icon)
	second_row.add_child(gas_label)

	return {
		"row": row,
		"money_label": money_label,
		"energy_label": energy_label,
		"stress_label": stress_label,
		"hull_label": hull_label,
		"gas_label": gas_label,
		"energy_icon": energy_icon,
		"stress_icon": stress_icon,
		"hull_icon": hull_icon,
		"gas_icon": gas_icon,
	}


static func refresh(stats_refs: Dictionary) -> void:
	var money_label := stats_refs.get("money_label") as Label
	var energy_label := stats_refs.get("energy_label") as Label
	var stress_label := stats_refs.get("stress_label") as Label
	var hull_label := stats_refs.get("hull_label") as Label
	var gas_label := stats_refs.get("gas_label") as Label
	if money_label == null or energy_label == null or stress_label == null or hull_label == null or gas_label == null:
		return

	money_label.text = "Money: PhP %d" % PlayerState.money
	energy_label.text = "%d/%d" % [PlayerState.energy, PlayerState.max_energy]
	stress_label.text = "%d/%d" % [PlayerState.stress, PlayerState.max_stress]
	hull_label.text = "%d/%d" % [PlayerState.hull, PlayerState.max_hull]
	gas_label.text = PlayerState.gas_text()


static func _make_label(label_config: Dictionary) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var font = label_config.get("font", null)
	if font != null:
		label.add_theme_font_override("font", font)

	label.add_theme_font_size_override("font_size", int(label_config.get("font_size", 11)))
	label.add_theme_color_override("font_color", label_config.get("font_color", DEFAULT_FONT_COLOR))
	label.add_theme_color_override("font_outline_color", label_config.get("outline_color", DEFAULT_OUTLINE_COLOR))
	label.add_theme_constant_override("outline_size", 1)
	return label


static func _make_icon(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon
