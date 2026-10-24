extends RefCounted

# Builds shop item rows, refreshes their state, and applies purchases.
const TIER_FILLED_COLOR := Color(0.86, 0.56, 0.18, 1.0)
const TIER_EMPTY_COLOR := Color(0.43, 0.34, 0.26, 0.84)
const TIER_BORDER_COLOR := Color(0.23, 0.16, 0.10, 0.92)
const ROW_BG_COLOR := Color(0.93, 0.88, 0.78, 0.76)
const ROW_BORDER_COLOR := Color(0.34, 0.22, 0.12, 0.86)
const BUY_BUTTON_BG := Color(0.46, 0.29, 0.17, 0.95)
const BUY_BUTTON_HOVER_BG := Color(0.80, 0.60, 0.28, 0.98)
const BUY_BUTTON_PRESSED_BG := Color(0.36, 0.53, 0.30, 0.98)
const BUY_BUTTON_DISABLED_BG := Color(0.42, 0.37, 0.32, 0.86)
const BUY_BUTTON_BORDER := Color(0.20, 0.12, 0.07, 0.96)


static func build_items(owner) -> void:
	owner.store_item_rows.clear()
	owner.store_buy_buttons.clear()
	for item in owner.StoreItemCatalog.ITEMS:
		var row_frame = PanelContainer.new()
		row_frame.custom_minimum_size = Vector2(0.0, 108.0)
		row_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_frame.add_theme_stylebox_override("panel", make_store_row_style(owner))
		owner.item_list.add_child(row_frame)

		var row_margin = MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 16)
		row_margin.add_theme_constant_override("margin_top", 12)
		row_margin.add_theme_constant_override("margin_right", 16)
		row_margin.add_theme_constant_override("margin_bottom", 12)
		row_frame.add_child(row_margin)

		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_margin.add_child(row)

		var label = RichTextLabel.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.bbcode_enabled = false
		label.fit_content = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(0.0, 48.0)
		label.add_theme_font_override("normal_font", owner.UI_FONT)
		label.add_theme_font_size_override("normal_font_size", 12)
		label.add_theme_color_override("default_color", Color(0.24, 0.16, 0.10, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.95, 0.92, 0.84, 0.92))
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_constant_override("line_separation", 6)
		label.text = item_text(owner, item)
		row.add_child(label)

		var actions = HBoxContainer.new()
		row.add_child(actions)
		var tier_container = make_tier_bars(owner, item)
		actions.add_child(tier_container)
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(spacer)

		var button = Button.new()
		button.custom_minimum_size = Vector2(120.0, 40.0)
		button.text = "BUY"
		apply_button_font(owner, button)
		apply_store_buy_button_style(owner, button)
		UIAudioManager.attach_button(button)
		button.pressed.connect(owner._buy_item.bind(item, label, tier_container, button))
		actions.add_child(button)
		owner.store_item_rows.append(row_frame)
		owner.store_buy_buttons.append(button)

		refresh_buy_button(owner, item, button)


static func item_text(owner, item: Dictionary) -> String:
	var description_values = item.duplicate()
	if item.has("gas"):
		description_values["gas"] = String.num(float(item["gas"])).trim_suffix(".0")
	var description = str(item["description"]).format(description_values)
	if str(item.get("id", "")) == "yosi":
		if PlayerState.has_achievement("maninigarilyo"):
			description = "Restore %d energy. Continued usage will lead to severe consequences." % PlayerState.get_yosi_energy_restore()
		else:
			description = "Restore %d energy. May cause negative effects" % PlayerState.get_yosi_energy_restore()
	var cost_text: String = "PhP %d" % item_cost(owner, item)
	if item["type"] == "gas":
		cost_text = PlayerState.get_gas_price_text()
	var text: String = "%s  %s\n%s" % [item["name"], cost_text, description]
	if item["type"] == "upgrade":
		text += "  Lv %d/%d" % [
			PlayerState.get_upgrade_level(item["id"]),
			item["max_level"],
		]
	return text


static func buy_item(owner, item: Dictionary, label: RichTextLabel, tier_container: HBoxContainer, button: Button) -> void:
	if owner.tutorial_active or not owner.shop_overlay.visible or owner.is_transitioning:
		return
	if item["type"] == "upgrade":
		var current_level = PlayerState.get_upgrade_level(item["id"])
		if current_level >= int(item["max_level"]):
			owner.status_label.text = "%s is already maxed." % item["name"]
			return
	elif item["type"] == "gas" and PlayerState.gas >= PlayerState.max_gas:
		owner.status_label.text = "Gas tank is already full."
		return

	var item_cost = item_cost(owner, item)
	if not PlayerState.spend_money(item_cost):
		owner.status_label.text = "Not enough money."
		return

	if item["type"] == "upgrade":
		var next_level = PlayerState.get_upgrade_level(item["id"]) + 1
		PlayerState.set_upgrade_level(item["id"], next_level)
		PlayerState.record_store_purchase(str(item["type"]))
		owner.status_label.text = "%s upgraded to Lv %d." % [item["name"], next_level]
		refresh_tier_bars(owner, tier_container, next_level, int(item["max_level"]))
	elif item["type"] == "energy":
		var restored_energy = int(item["energy"])
		if str(item.get("id", "")) == "yosi":
			restored_energy = PlayerState.get_yosi_energy_restore()
		PlayerState.add_energy(restored_energy)
		PlayerState.record_store_purchase(str(item["type"]))
		if str(item.get("id", "")) == "yosi":
			PlayerState.record_yosi_purchase()
			if PlayerState.is_run_failed():
				await owner._fade_to_scene(owner.GAME_OVER_SCENE)
				return
		owner.status_label.text = "%s restored energy." % item["name"]
	elif item["type"] == "gas":
		var gas_before = PlayerState.gas
		PlayerState.add_gas(float(item.get("gas", PlayerState.GAS_CAN_PERCENT)))
		owner.status_label.text = "%s added %.1f%% gas." % [item["name"], PlayerState.gas - gas_before]

	label.text = item_text(owner, item)
	refresh_buy_button(owner, item, button)
	owner._refresh_header()


static func apply_button_font(owner, button: Button) -> void:
	button.add_theme_font_override("font", owner.UI_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.20, 0.11, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.20, 0.11, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.73, 0.68, 0.86))
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.95))
	button.add_theme_constant_override("outline_size", 1)


static func item_cost(owner, item: Dictionary) -> int:
	if item["type"] == "gas":
		return PlayerState.get_gas_price()

	if item["type"] != "upgrade":
		return int(item["cost"])

	var current_level = PlayerState.get_upgrade_level(item["id"])
	var cost_step = int(item.get("cost_step", 0))
	return int(item["cost"]) + current_level * cost_step


static func refresh_buy_button(owner, item: Dictionary, button: Button) -> void:
	if item["type"] == "upgrade":
		var current_level = PlayerState.get_upgrade_level(item["id"])
		var max_level = int(item["max_level"])
		button.disabled = current_level >= max_level
		button.text = "MAX" if button.disabled else "BUY"
		return

	if item["type"] == "gas":
		button.disabled = PlayerState.gas >= PlayerState.max_gas
		button.text = "FULL" if button.disabled else "BUY"


static func make_tier_bars(owner, item: Dictionary) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(138.0, 34.0)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 4)

	if item["type"] != "upgrade":
		return container

	for index in int(item["max_level"]):
		var bar = Panel.new()
		bar.custom_minimum_size = Vector2(20.0, 30.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.set_meta("tier_index", index)
		container.add_child(bar)

	refresh_tier_bars(owner,
		container,
		PlayerState.get_upgrade_level(item["id"]),
		int(item["max_level"])
	)
	return container


static func refresh_tier_bars(owner, container: HBoxContainer, level: int, max_level: int) -> void:
	for child in container.get_children():
		if not child is Panel:
			continue

		var tier_index = int(child.get_meta("tier_index", 0))
		var style = StyleBoxFlat.new()
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


static func make_store_row_style(owner) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
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


static func apply_store_buy_button_style(owner, button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_buy_button_style(owner, BUY_BUTTON_BG))
	button.add_theme_stylebox_override("hover", make_buy_button_style(owner, BUY_BUTTON_HOVER_BG))
	button.add_theme_stylebox_override("pressed", make_buy_button_style(owner, BUY_BUTTON_PRESSED_BG))
	button.add_theme_stylebox_override("focus", make_buy_button_style(owner, BUY_BUTTON_HOVER_BG))
	button.add_theme_stylebox_override("disabled", make_buy_button_style(owner, BUY_BUTTON_DISABLED_BG))


static func make_buy_button_style(owner, color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
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
