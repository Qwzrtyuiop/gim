extends Control

const NEXT_STAGE_SCENE := "res://scenes/main.tscn"
const UI_FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const BUTTON_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const BUTTON_GLOW_MODULATE := Color(1.35, 1.18, 0.62, 1.0)
const TIER_FILLED_COLOR := Color(0.98, 0.82, 0.24, 1.0)
const TIER_EMPTY_COLOR := Color(0.16, 0.15, 0.13, 0.92)
const TIER_BORDER_COLOR := Color(0.0, 0.0, 0.0, 0.92)

const STORE_ITEMS := [
	{
		"id": "engine_tune",
		"name": "Engine Tune",
		"description": "+8% acceleration, +4% top speed per level",
		"cost": 120,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "brake_kit",
		"name": "Brake Kit",
		"description": "+10% braking per level",
		"cost": 90,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "tire_grip",
		"name": "Tire Grip",
		"description": "+8% lane switching per level",
		"cost": 100,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "energy_snack",
		"name": "Energy Snack",
		"description": "Restore 1 energy",
		"cost": 50,
		"type": "energy",
		"energy": 1,
	},
	{
		"id": "full_meal",
		"name": "Full Meal",
		"description": "Restore 3 energy",
		"cost": 120,
		"type": "energy",
		"energy": 3,
	},
]

@onready var money_label: Label = $MoneyLabel
@onready var status_label: Label = $StatusLabel
@onready var item_list: VBoxContainer = $ItemList
@onready var ride_button: BaseButton = $RideButton


func _ready() -> void:
	ride_button.pressed.connect(_ride)
	_connect_button_glow(ride_button)
	_build_items()
	_refresh_header()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and ride_button.has_focus():
		_ride()


func _build_items() -> void:
	for item in STORE_ITEMS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 74.0)
		row.add_theme_constant_override("separation", 14)
		item_list.add_child(row)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.label_settings = _make_label_settings(22, Color(0.98, 0.95, 0.78, 1.0))
		label.text = _item_text(item)
		row.add_child(label)

		var tier_container := _make_tier_bars(item)
		row.add_child(tier_container)

		var button := Button.new()
		button.custom_minimum_size = Vector2(145.0, 48.0)
		button.text = "BUY"
		_apply_button_font(button)
		button.pressed.connect(_buy_item.bind(item, label, tier_container, button))
		row.add_child(button)

		_refresh_buy_button(item, button)


func _item_text(item: Dictionary) -> String:
	var text := "%s  PhP %d\n%s" % [item["name"], item["cost"], item["description"]]
	if item["type"] == "upgrade":
		text += "  Lv %d/%d" % [
			PlayerState.get_upgrade_level(item["id"]),
			item["max_level"],
		]
	return text


func _buy_item(item: Dictionary, label: Label, tier_container: HBoxContainer, button: Button) -> void:
	if item["type"] == "upgrade":
		var current_level := PlayerState.get_upgrade_level(item["id"])
		if current_level >= int(item["max_level"]):
			status_label.text = "%s is already maxed." % item["name"]
			return

	if not PlayerState.spend_money(int(item["cost"])):
		status_label.text = "Not enough money."
		return

	if item["type"] == "upgrade":
		var next_level := PlayerState.get_upgrade_level(item["id"]) + 1
		PlayerState.set_upgrade_level(item["id"], next_level)
		status_label.text = "%s upgraded to Lv %d." % [item["name"], next_level]
		_refresh_tier_bars(tier_container, next_level, int(item["max_level"]))
	elif item["type"] == "energy":
		PlayerState.add_energy(int(item["energy"]))
		status_label.text = "%s restored energy." % item["name"]

	label.text = _item_text(item)
	_refresh_buy_button(item, button)
	_refresh_header()


func _refresh_header() -> void:
	money_label.text = "Money: PhP %d     Energy: %d/%d" % [
		PlayerState.money,
		PlayerState.energy,
		PlayerState.max_energy,
	]


func _ride() -> void:
	PlayerState.advance_to_random_stage()
	get_tree().change_scene_to_file(NEXT_STAGE_SCENE)


func _apply_button_font(button: Button) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 2)


func _refresh_buy_button(item: Dictionary, button: Button) -> void:
	if item["type"] != "upgrade":
		return

	var current_level := PlayerState.get_upgrade_level(item["id"])
	var max_level := int(item["max_level"])
	button.disabled = current_level >= max_level
	button.text = "MAX" if button.disabled else "BUY"


func _make_tier_bars(item: Dictionary) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.custom_minimum_size = Vector2(138.0, 34.0)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 4)

	if item["type"] != "upgrade":
		return container

	for index in int(item["max_level"]):
		var bar := Panel.new()
		bar.custom_minimum_size = Vector2(20.0, 30.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.set_meta("tier_index", index)
		container.add_child(bar)

	_refresh_tier_bars(
		container,
		PlayerState.get_upgrade_level(item["id"]),
		int(item["max_level"])
	)
	return container


func _refresh_tier_bars(container: HBoxContainer, level: int, max_level: int) -> void:
	for child in container.get_children():
		if not child is Panel:
			continue

		var tier_index := int(child.get_meta("tier_index", 0))
		var style := StyleBoxFlat.new()
		style.bg_color = TIER_FILLED_COLOR if tier_index < level else TIER_EMPTY_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = TIER_BORDER_COLOR
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_right = 3
		style.corner_radius_bottom_left = 3
		child.add_theme_stylebox_override("panel", style)

	if level >= max_level:
		container.modulate = Color(1.1, 1.05, 0.86, 1.0)
	else:
		container.modulate = Color.WHITE


func _connect_button_glow(button: BaseButton) -> void:
	button.modulate = BUTTON_NORMAL_MODULATE
	button.mouse_entered.connect(_set_button_glow.bind(button, true))
	button.mouse_exited.connect(_set_button_glow.bind(button, false))
	button.focus_entered.connect(_set_button_glow.bind(button, true))
	button.focus_exited.connect(_set_button_glow.bind(button, false))


func _set_button_glow(button: BaseButton, is_glowing: bool) -> void:
	var tween := create_tween()
	tween.tween_property(
		button,
		"modulate",
		BUTTON_GLOW_MODULATE if is_glowing else BUTTON_NORMAL_MODULATE,
		0.08
	)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = UI_FONT
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 2
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.95)
	return settings
