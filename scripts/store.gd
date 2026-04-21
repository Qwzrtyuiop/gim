extends Control

const STORE_SCENE := "res://scenes/store.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const STORE_BGM_PATH := "res://assets/stagebgm/store.mp3"
const FAIL_FADE_SECONDS := 0.35
const TIER_FILLED_COLOR := Color(0.86, 0.56, 0.18, 1.0)
const TIER_EMPTY_COLOR := Color(0.43, 0.34, 0.26, 0.84)
const TIER_BORDER_COLOR := Color(0.23, 0.16, 0.10, 0.92)
const LAST_ENERGY_WARNING := "Start the next day with critically low energy?\nYour vehicle will handle worse until John recovers."
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
		"description": "increase top speed and acceleration",
		"cost": 250,
		"cost_step": 70,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "brake_kit",
		"name": "Brake Kit",
		"description": "improve braking power",
		"cost": 200,
		"cost_step": 55,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "fuel_efficiency",
		"name": "Fuel Efficiency",
		"description": "less gas consumption and slightly cheaper boost",
		"cost": 150,
		"cost_step": 60,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "yosi",
		"name": "Warlboro Blue",
		"description": "Restore energy. May cause negative effects",
		"cost": 25,
		"type": "energy",
		"energy": 2,
	},
	
	{
		"id": "energy_snack",
		"name": "Energy Bar",
		"description": "Restore 2 energy",
		"cost": 50,
		"type": "energy",
		"energy": 2,
	},
	{
		"id": "full_meal",
		"name": "Budget Meal",
		"description": "Restore 5 energy",
		"cost": 120,
		"type": "energy",
		"energy": 5,
	},
	{
		"id": "gas_can",
		"name": "Gas Can",
		"description": "Add 10% gas",
		"type": "gas",
		"gas": 10.0,
	},
]

@onready var money_label: Label = $MoneyLabel
@onready var status_label: Label = $StatusLabel
@onready var item_list: VBoxContainer = $ItemScroll/ItemList
@onready var back_button: BaseButton = $BackButton
@onready var back_label: Label = $BackButton/BackLabel
@onready var ride_button: BaseButton = $RideButton
@onready var fade_overlay: ColorRect = $FadeOverlay

var ride_confirm_dialog: ConfirmationDialog
var stats_row_refs: Dictionary = {}
var bgm_player: AudioStreamPlayer
var store_item_rows: Array[Control] = []
var store_buy_buttons: Array[BaseButton] = []
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_text_panel: Panel
var tutorial_text_label: Label
var tutorial_step_index := 0
var tutorial_steps: Array[Dictionary] = []
var tutorial_active := false
var tutorial_disabled_controls: Dictionary = {}


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/store.tscn")
	PlayerState.ensure_daily_conditions_for_current_day()
	_create_stats_row()
	_configure_home_button()
	back_button.pressed.connect(_go_home)
	ride_button.pressed.connect(_attempt_ride)
	ButtonGlow.attach(self, back_button)
	ButtonGlow.attach(self, ride_button)
	_start_store_bgm()
	_create_dialogs()
	_build_items()
	_refresh_header()
	_build_tutorial()
	if not PlayerState.has_store_tutorial_shown():
		call_deferred("_start_tutorial")


func _unhandled_input(event: InputEvent) -> void:
	if tutorial_active:
		if event is InputEventMouseButton and event.pressed:
			_advance_tutorial()
			return
		if _is_any_press(event):
			_advance_tutorial()
		return
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_accept"):
		if back_button.visible and back_button.has_focus():
			_go_home()
		elif ride_button.has_focus():
			_attempt_ride()
	elif event.is_action_pressed("ui_cancel") and back_button.visible:
		_go_home()


func _build_items() -> void:
	store_item_rows.clear()
	store_buy_buttons.clear()
	for item in STORE_ITEMS:
		var row_frame := PanelContainer.new()
		row_frame.custom_minimum_size = Vector2(0.0, 108.0)
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

		var label := RichTextLabel.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.bbcode_enabled = false
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(0.0, 74.0)
		label.add_theme_font_override("normal_font", UI_FONT)
		label.add_theme_font_size_override("normal_font_size", 14)
		label.add_theme_color_override("default_color", Color(0.24, 0.16, 0.10, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.95, 0.92, 0.84, 0.92))
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_constant_override("line_separation", 6)
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
		store_item_rows.append(row_frame)
		store_buy_buttons.append(button)

		_refresh_buy_button(item, button)


func _item_text(item: Dictionary) -> String:
	var description := str(item["description"])
	if str(item.get("id", "")) == "yosi":
		if PlayerState.has_achievement("maninigarilyo"):
			description = "Restore %d energy. Continued usage will lead to severe consequences." % PlayerState.get_yosi_energy_restore()
		else:
			description = "Restore %d energy. May cause negative effects" % PlayerState.get_yosi_energy_restore()
	var cost_text: String = "PhP %d" % _item_cost(item)
	if item["type"] == "gas":
		cost_text = PlayerState.get_gas_price_text()
	var text: String = "%s  %s\n%s" % [item["name"], cost_text, description]
	if item["type"] == "upgrade":
		text += "  Lv %d/%d" % [
			PlayerState.get_upgrade_level(item["id"]),
			item["max_level"],
		]
	return text


func _buy_item(item: Dictionary, label: RichTextLabel, tier_container: HBoxContainer, button: Button) -> void:
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
		PlayerState.record_store_purchase(str(item["type"]))
		status_label.text = "%s upgraded to Lv %d." % [item["name"], next_level]
		_refresh_tier_bars(tier_container, next_level, int(item["max_level"]))
	elif item["type"] == "energy":
		var restored_energy := int(item["energy"])
		if str(item.get("id", "")) == "yosi":
			restored_energy = PlayerState.get_yosi_energy_restore()
		PlayerState.add_energy(restored_energy)
		PlayerState.record_store_purchase(str(item["type"]))
		if str(item.get("id", "")) == "yosi":
			PlayerState.record_yosi_purchase()
			if PlayerState.is_run_failed():
				await _fade_to_scene(GAME_OVER_SCENE)
				return
		status_label.text = "%s restored energy." % item["name"]
	elif item["type"] == "gas":
		var gas_before := PlayerState.gas
		PlayerState.add_gas(float(item.get("gas", PlayerState.GAS_CAN_PERCENT)))
		status_label.text = "%s added %.1f%% gas." % [item["name"], PlayerState.gas - gas_before]

	label.text = _item_text(item)
	_refresh_buy_button(item, button)
	_refresh_header()


func _refresh_header() -> void:
	_refresh_stats_row()
	money_label.text = "Gas Price: %s / 10%%\n%s" % [
		PlayerState.get_gas_price_text(),
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

	PlayerState.set_pending_trip_selection(STORE_SCENE, _selection_transition_mode())
	get_tree().change_scene_to_file(RIDE_SELECTION_SCENE)


func _go_home() -> void:
	PlayerState.clear_pending_trip_selection()
	get_tree().change_scene_to_file(HOME_SCENE)


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


func _configure_home_button() -> void:
	back_button.visible = true
	if back_label != null:
		back_label.text = "HOME"
		back_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80, 1.0))
		back_label.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.05, 0.95))
	back_button.tooltip_text = "Home"


func _selection_transition_mode() -> String:
	var pending_selection := PlayerState.get_pending_trip_selection()
	return PlayerState.normalize_transition_mode(str(pending_selection.get("transition_mode", PlayerState.TRANSITION_RIDE)))


func _refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return

	PlayerStatsRow.refresh(stats_row_refs)


func _build_tutorial() -> void:
	tutorial_steps.clear()
	tutorial_step_index = 0

	tutorial_overlay = Control.new()
	tutorial_overlay.anchor_right = 1.0
	tutorial_overlay.anchor_bottom = 1.0
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.focus_mode = Control.FOCUS_ALL
	tutorial_overlay.z_index = 200
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)

	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.add_child(backdrop)

	tutorial_highlight = Panel.new()
	tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_highlight.z_index = 1
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	highlight_style.border_color = Color(0.98, 0.92, 0.68, 0.95)
	highlight_style.set_border_width_all(3)
	highlight_style.set_corner_radius_all(8)
	tutorial_highlight.add_theme_stylebox_override("panel", highlight_style)
	tutorial_overlay.add_child(tutorial_highlight)

	tutorial_text_panel = Panel.new()
	tutorial_text_panel.z_index = 2
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.06, 0.92)
	panel_style.border_color = Color(0.82, 0.66, 0.40, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	tutorial_text_panel.add_theme_stylebox_override("panel", panel_style)
	tutorial_overlay.add_child(tutorial_text_panel)

	tutorial_text_label = _make_tutorial_label()
	tutorial_text_label.anchor_right = 1.0
	tutorial_text_label.anchor_bottom = 1.0
	tutorial_text_label.offset_left = 12.0
	tutorial_text_label.offset_top = 10.0
	tutorial_text_label.offset_right = -12.0
	tutorial_text_label.offset_bottom = -10.0
	tutorial_text_panel.add_child(tutorial_text_label)

	var stats_row := stats_row_refs.get("row") as Control
	var stats_targets := [stats_row] if stats_row != null else [money_label]
	tutorial_steps.append({
		"text": "Your money, energy, and gas are shown here before you buy anything.",
		"targets": stats_targets,
	})
	tutorial_steps.append({
		"text": "This is the store list. Upgrades improve the vehicle, food restores energy, and gas adds 10%.",
		"targets": [item_list],
	})
	if not store_item_rows.is_empty():
		tutorial_steps.append({
			"text": "Each row shows the item name, price, effect, and upgrade level when it has one.",
			"targets": [store_item_rows[0]],
		})
	if not store_buy_buttons.is_empty():
		tutorial_steps.append({
			"text": "Press BUY to spend money on that item. Disabled buttons mean the item is maxed or already full.",
			"targets": [store_buy_buttons[0]],
		})
	tutorial_steps.append({
		"text": "Gas price changes by day. One gas can always fills 10% of the tank.",
		"targets": [money_label],
	})
	tutorial_steps.append({
		"text": "HOME returns to the house screen. RIDE opens passenger selection.",
		"targets": [ride_button, back_button],
	})


func _start_tutorial() -> void:
	if tutorial_overlay == null or tutorial_steps.is_empty():
		return
	if PlayerState.has_store_tutorial_shown():
		return
	PlayerState.mark_store_tutorial_shown()
	_set_tutorial_active(true)
	_show_tutorial_step(0)


func _advance_tutorial() -> void:
	if not tutorial_active:
		return
	var next_index := tutorial_step_index + 1
	if next_index >= tutorial_steps.size():
		_end_tutorial()
		return
	_show_tutorial_step(next_index)


func _show_tutorial_step(step_index: int) -> void:
	tutorial_step_index = clampi(step_index, 0, tutorial_steps.size() - 1)
	var step: Dictionary = tutorial_steps[tutorial_step_index]
	tutorial_text_label.text = "%s\n\nPress any key to continue" % str(step.get("text", ""))
	tutorial_text_label.visible = true
	_layout_tutorial_for_targets(step.get("targets", []))


func _layout_tutorial_for_targets(targets: Array) -> void:
	var rect := _union_global_rect(targets)
	var label_size := Vector2(620.0, 88.0)
	if tutorial_text_label != null:
		var text_len := tutorial_text_label.text.length()
		if text_len > 180:
			label_size.y = 170.0
		elif text_len > 120:
			label_size.y = 140.0
	if rect.size == Vector2.ZERO:
		tutorial_highlight.visible = false
		tutorial_text_panel.size = label_size
		tutorial_text_panel.global_position = Vector2(
			(get_viewport_rect().size.x - label_size.x) * 0.5,
			120.0
		)
		return

	var padding := 14.0
	rect.position -= Vector2(padding, padding)
	rect.size += Vector2(padding * 2.0, padding * 2.0)
	tutorial_highlight.visible = true
	tutorial_highlight.global_position = rect.position
	tutorial_highlight.size = rect.size

	var label_pos := rect.position + Vector2((rect.size.x - label_size.x) * 0.5, rect.size.y + 16.0)
	if label_pos.y + label_size.y > get_viewport_rect().size.y - 12.0:
		label_pos.y = rect.position.y - label_size.y - 16.0
	label_pos.y = maxf(label_pos.y, 12.0)
	label_pos.x = clampf(label_pos.x, 20.0, get_viewport_rect().size.x - label_size.x - 20.0)
	tutorial_text_panel.size = label_size
	tutorial_text_panel.global_position = label_pos


func _union_global_rect(targets: Array) -> Rect2:
	var has_rect := false
	var rect := Rect2()
	for target in targets:
		var control := target as Control
		if control == null or not control.visible:
			continue
		var target_rect := control.get_global_rect()
		if not has_rect:
			rect = target_rect
			has_rect = true
		else:
			rect = rect.merge(target_rect)
	return rect


func _set_tutorial_active(is_active: bool) -> void:
	tutorial_active = is_active
	if tutorial_overlay != null:
		tutorial_overlay.visible = is_active
		if is_active:
			tutorial_overlay.grab_focus()
	if tutorial_text_panel != null:
		tutorial_text_panel.visible = is_active
	if tutorial_text_label != null:
		tutorial_text_label.visible = is_active

	var controls: Array = [back_button, ride_button]
	controls.append_array(store_buy_buttons)
	if is_active:
		tutorial_disabled_controls.clear()
		for control in controls:
			if control == null:
				continue
			tutorial_disabled_controls[control] = control.disabled
			control.disabled = true
	else:
		for control in tutorial_disabled_controls.keys():
			var button := control as BaseButton
			if button == null:
				continue
			button.disabled = bool(tutorial_disabled_controls.get(button, false))
		tutorial_disabled_controls.clear()


func _end_tutorial() -> void:
	_set_tutorial_active(false)


func _make_tutorial_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


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
	if PlayerState.get_current_time_of_day() == "night" and PlayerState.energy <= 2:
		ride_confirm_dialog.popup_centered()
		return

	_ride()


func _create_dialogs() -> void:
	ride_confirm_dialog = ConfirmationDialog.new()
	ride_confirm_dialog.title = "Low Energy"
	ride_confirm_dialog.dialog_text = LAST_ENERGY_WARNING
	ride_confirm_dialog.get_ok_button().text = "START DAY"
	ride_confirm_dialog.get_cancel_button().text = "BACK"
	ride_confirm_dialog.confirmed.connect(_ride)
	add_child(ride_confirm_dialog)


func _fade_to_scene(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, FAIL_FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
