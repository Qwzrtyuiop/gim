extends RefCounted

const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const GAS_ICON := preload("res://assets/ui/icons/gas_pump.svg")
const DEFAULT_FONT_COLOR := Color(0.27, 0.18, 0.10, 1.0)
const DEFAULT_OUTLINE_COLOR := Color(0.95, 0.90, 0.78, 0.92)
const DEFAULT_ICON_SIZE := Vector2(22.0, 22.0)


static func create(config: Dictionary = {}) -> Dictionary:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = int(config.get("alignment", BoxContainer.ALIGNMENT_CENTER))
	row.add_theme_constant_override("separation", int(config.get("separation", 12)))

	var label_config := {
		"font": config.get("font", null),
		"font_size": int(config.get("font_size", 11)),
		"font_color": config.get("font_color", DEFAULT_FONT_COLOR),
		"outline_color": config.get("outline_color", DEFAULT_OUTLINE_COLOR),
	}
	var icon_size: Vector2 = config.get("icon_size", DEFAULT_ICON_SIZE)

	var money_label := _make_label(label_config)
	if bool(config.get("spread", false)):
		money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var energy_label := _make_label(label_config)
	var gas_label := _make_label(label_config)

	row.add_child(money_label)
	row.add_child(_make_icon(ENERGY_ICON, icon_size))
	row.add_child(energy_label)
	row.add_child(_make_icon(GAS_ICON, icon_size))
	row.add_child(gas_label)

	return {
		"row": row,
		"money_label": money_label,
		"energy_label": energy_label,
		"gas_label": gas_label,
	}


static func refresh(stats_refs: Dictionary) -> void:
	var money_label := stats_refs.get("money_label") as Label
	var energy_label := stats_refs.get("energy_label") as Label
	var gas_label := stats_refs.get("gas_label") as Label
	if money_label == null or energy_label == null or gas_label == null:
		return

	money_label.text = "Money: PhP %d" % PlayerState.money
	energy_label.text = "%d/%d" % [PlayerState.energy, PlayerState.max_energy]
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
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon
