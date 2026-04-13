extends Control

const STORE_SCENE := "res://scenes/store.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const STORE_BGM_PATH := "res://assets/stagebgm/store.mp3"
const TIER_FILLED_COLOR := Color(0.86, 0.56, 0.18, 1.0)
const TIER_EMPTY_COLOR := Color(0.43, 0.34, 0.26, 0.84)
const TIER_BORDER_COLOR := Color(0.23, 0.16, 0.10, 0.92)
const LAST_ENERGY_WARNING := "Start the next day with your last energy?\nIf this trip goes bad, the run ends."
const ROW_BG_COLOR := Color(0.93, 0.88, 0.78, 0.76)
const ROW_BORDER_COLOR := Color(0.34, 0.22, 0.12, 0.86)
const BUY_BUTTON_BG := Color(0.46, 0.29, 0.17, 0.95)
const BUY_BUTTON_HOVER_BG := Color(0.80, 0.60, 0.28, 0.98)
const BUY_BUTTON_PRESSED_BG := Color(0.36, 0.53, 0.30, 0.98)
const BUY_BUTTON_DISABLED_BG := Color(0.42, 0.37, 0.32, 0.86)
const BUY_BUTTON_BORDER := Color(0.20, 0.12, 0.07, 0.96)
const STORE_ITEMS := [
	{
		"id": "engine_tune",
		"name": "Engine Tune",
		"description": "+8% acceleration, +4% top speed per level",
		"cost": 250,
		"cost_step": 70,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "brake_kit",
		"name": "Brake Kit",
		"description": "+10% braking per level",
		"cost": 200,
		"cost_step": 55,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "tire_grip",
		"name": "Tire Grip",
		"description": "+8% lane switching per level",
		"cost": 150,
		"cost_step": 60,
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
		"name": "Budget Meal",
		"description": "Restore 3 energy",
		"cost": 120,
		"type": "energy",
		"energy": 3,
	},
	{
		"id": "gas_can",
		"name": "Gas Can",
		"description": "Add 1 gas",
		"type": "gas",
		"gas": 1,
	},
]

@onready var money_label: Label = $MoneyLabel
@onready var status_label: Label = $StatusLabel
@onready var item_list: VBoxContainer = $ItemScroll/ItemList
@onready var back_button: BaseButton = $BackButton
@onready var ride_button: BaseButton = $RideButton

var ride_confirm_dialog: ConfirmationDialog
var stats_row_refs: Dictionary = {}
var bgm_player: AudioStreamPlayer


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/store.tscn")
	_create_stats_row()
	_refresh_back_button()
	back_button.pressed.connect(_back_to_selection)
	ride_button.pressed.connect(_attempt_ride)
	ButtonGlow.attach(self, back_button)
	ButtonGlow.attach(self, ride_button)
	_start_store_bgm()
	_create_dialogs()
	_build_items()
	_refresh_header()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_accept"):
		if back_button.visible and back_button.has_focus():
			_back_to_selection()
		elif ride_button.has_focus():
			_attempt_ride()
	elif event.is_action_pressed("ui_cancel") and back_button.visible:
		_back_to_selection()


func _build_items() -> void:
	for item in STORE_ITEMS:
		var row_frame := PanelContainer.new()
		row_frame.custom_minimum_size = Vector2(0.0, 92.0)
		row_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_frame.add_theme_stylebox_override("panel", _make_store_row_style())
		item_list.add_child(row_frame)

		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 16)
		row_margin.add_theme_constant_override("margin_top", 12)
		row_margin.add_theme_constant_override("margin_right", 16)
		row_margin.add_theme_constant_override("margin_bottom", 12)
		row_frame.add_child(row_margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row_margin.add_child(row)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.label_settings = _make_label_settings(14, Color(0.24, 0.16, 0.10, 1.0))
		label.text = _item_text(item)
		row.add_child(label)

		var tier_container := _make_tier_bars(item)
		row.add_child(tier_container)

		var button := Button.new()
		button.custom_minimum_size = Vector2(145.0, 48.0)
		button.text = "BUY"
		_apply_button_font(button)
		_apply_store_buy_button_style(button)
		UIAudioManager.attach_button(button)
		button.pressed.connect(_buy_item.bind(item, label, tier_container, button))
		row.add_child(button)

		_refresh_buy_button(item, button)


func _item_text(item: Dictionary) -> String:
	var text := "%s  PhP %d\n%s" % [item["name"], _item_cost(item), item["description"]]
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
	elif item["type"] == "gas" and PlayerState.gas >= PlayerState.max_gas:
		status_label.text = "Gas tank is already full."
		return

	var item_cost := _item_cost(item)
	if not PlayerState.spend_money(item_cost):
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
	elif item["type"] == "gas":
		var gas_before := PlayerState.gas
		PlayerState.add_gas(int(item.get("gas", 0)))
		status_label.text = "%s added %d gas." % [item["name"], PlayerState.gas - gas_before]

	label.text = _item_text(item)
	_refresh_buy_button(item, button)
	_refresh_header()


func _refresh_header() -> void:
	_refresh_stats_row()
	money_label.text = "Gas Price: PhP %d\n%s" % [
		PlayerState.get_gas_price(),
		PlayerState.get_debt_status_text(),
	]


func _start_store_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "StoreBGMPlayer"
	bgm_player.stream = load(STORE_BGM_PATH)
	bgm_player.bus = "Master"
	bgm_player.autoplay = false
	add_child(bgm_player)
	AudioSettingsManager.register_player(bgm_player, "music")
	bgm_player.play()


func _ride() -> void:
	if PlayerState.has_locked_pending_trip_selection():
		PlayerState.set_pending_trip_selection(STORE_SCENE, _selection_transition_mode())
		get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)
		return

	PlayerState.set_pending_trip_selection(STORE_SCENE, PlayerState.TRANSITION_RIDE)
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _back_to_selection() -> void:
	if not PlayerState.has_locked_pending_trip_selection():
		return

	PlayerState.set_pending_trip_selection(STORE_SCENE, _selection_transition_mode())
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _apply_button_font(button: Button) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.20, 0.11, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.20, 0.11, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.73, 0.68, 0.86))
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.95))
	button.add_theme_constant_override("outline_size", 1)


func _item_cost(item: Dictionary) -> int:
	if item["type"] == "gas":
		return PlayerState.get_gas_price()

	if item["type"] != "upgrade":
		return int(item["cost"])

	var current_level := PlayerState.get_upgrade_level(item["id"])
	var cost_step := int(item.get("cost_step", 0))
	return int(item["cost"]) + current_level * cost_step


func _refresh_buy_button(item: Dictionary, button: Button) -> void:
	if item["type"] == "upgrade":
		var current_level := PlayerState.get_upgrade_level(item["id"])
		var max_level := int(item["max_level"])
		button.disabled = current_level >= max_level
		button.text = "MAX" if button.disabled else "BUY"
		return

	if item["type"] == "gas":
		button.disabled = PlayerState.gas >= PlayerState.max_gas
		button.text = "FULL" if button.disabled else "BUY"


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


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = UI_FONT
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 1
	settings.outline_color = Color(0.95, 0.92, 0.84, 0.92)
	return settings


func _create_stats_row() -> void:
	stats_row_refs = PlayerStatsRow.create({
		"font": UI_FONT,
		"font_size": 12,
		"font_color": Color(0.24, 0.16, 0.10, 1.0),
		"outline_color": Color(0.95, 0.92, 0.84, 0.92),
	})
	var stats_row := stats_row_refs["row"] as HBoxContainer
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.layout_mode = 1
	stats_row.anchors_preset = 10
	stats_row.anchor_right = 1.0
	stats_row.offset_top = 118.0
	stats_row.offset_bottom = 146.0
	stats_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(stats_row)


func _refresh_back_button() -> void:
	back_button.visible = PlayerState.has_locked_pending_trip_selection()


func _selection_transition_mode() -> String:
	var pending_selection := PlayerState.get_pending_trip_selection()
	return PlayerState.normalize_transition_mode(str(pending_selection.get("transition_mode", PlayerState.TRANSITION_RIDE)))


func _refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return

	PlayerStatsRow.refresh(stats_row_refs)


func _make_store_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ROW_BORDER_COLOR
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


func _apply_store_buy_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_buy_button_style(BUY_BUTTON_BG))
	button.add_theme_stylebox_override("hover", _make_buy_button_style(BUY_BUTTON_HOVER_BG))
	button.add_theme_stylebox_override("pressed", _make_buy_button_style(BUY_BUTTON_PRESSED_BG))
	button.add_theme_stylebox_override("focus", _make_buy_button_style(BUY_BUTTON_HOVER_BG))
	button.add_theme_stylebox_override("disabled", _make_buy_button_style(BUY_BUTTON_DISABLED_BG))


func _make_buy_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = BUY_BUTTON_BORDER
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style


func _attempt_ride() -> void:
	if PlayerState.get_current_time_of_day() == "night" and PlayerState.energy == 1:
		ride_confirm_dialog.popup_centered()
		return

	_ride()


func _create_dialogs() -> void:
	ride_confirm_dialog = ConfirmationDialog.new()
	ride_confirm_dialog.title = "Last Energy"
	ride_confirm_dialog.dialog_text = LAST_ENERGY_WARNING
	ride_confirm_dialog.get_ok_button().text = "START DAY"
	ride_confirm_dialog.get_cancel_button().text = "BACK"
	ride_confirm_dialog.confirmed.connect(_ride)
	add_child(ride_confirm_dialog)
