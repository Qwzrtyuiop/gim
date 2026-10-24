extends RefCounted

const AchievementServiceData := preload("res://scripts/achievement_service.gd")
const StoryMemoryCatalog := preload("res://scripts/story/story_memory_catalog.gd")

# Builds the debug unlock panel and applies its achievement/gallery actions.


static func debug_unlock_all(owner) -> void:
	if owner.is_start_transitioning:
		return
	StoryMemoryCatalog.unlock_all(PlayerState)
	set_debug_unlock_message(owner, "Gallery and memories unlocked")


static func apply_debug_button_theme(owner, button: BaseButton) -> void:
	button.add_theme_font_override("font", owner.UI_FONT)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.52, 0.95))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	button.add_theme_constant_override("outline_size", 1)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.17, 0.12, 0.96)
	normal_style.border_color = Color(0.60, 0.45, 0.26, 1.0)
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(7)
	normal_style.content_margin_left = 14.0
	normal_style.content_margin_right = 14.0
	normal_style.content_margin_top = 10.0
	normal_style.content_margin_bottom = 10.0

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.83, 0.63, 0.33, 0.98)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.35, 0.48, 0.31, 0.98)

	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.16, 0.13, 0.11, 0.92)
	disabled_style.border_color = Color(0.34, 0.28, 0.22, 1.0)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)


static func apply_debug_panel_theme(owner, panel: Panel) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.97)
	style.border_color = Color(0.71, 0.56, 0.31, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	panel.add_theme_stylebox_override("panel", style)


static func build_debug_unlock_panel(owner) -> void:
	owner.debug_unlock_overlay = ColorRect.new()
	owner.debug_unlock_overlay.z_index = 40
	owner.debug_unlock_overlay.visible = false
	owner.debug_unlock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	owner.debug_unlock_overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	owner.debug_unlock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner.add_child(owner.debug_unlock_overlay)

	owner.debug_unlock_panel = Panel.new()
	owner.debug_unlock_panel.custom_minimum_size = Vector2(680.0, 500.0)
	owner.debug_unlock_panel.size = Vector2(680.0, 500.0)
	owner.debug_unlock_panel.position = Vector2(300.0, 86.0)
	apply_debug_panel_theme(owner, owner.debug_unlock_panel)
	owner.debug_unlock_overlay.add_child(owner.debug_unlock_panel)

	var title_label = Label.new()
	title_label.text = "DEBUG UNLOCK"
	title_label.position = Vector2(28.0, 20.0)
	title_label.size = Vector2(460.0, 36.0)
	title_label.add_theme_font_override("font", owner.UI_FONT)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 1)
	owner.debug_unlock_panel.add_child(title_label)

	owner.debug_close_button = Button.new()
	owner.debug_close_button.text = "CLOSE"
	owner.debug_close_button.position = Vector2(526.0, 18.0)
	owner.debug_close_button.size = Vector2(126.0, 42.0)
	apply_debug_button_theme(owner, owner.debug_close_button)
	owner.debug_close_button.pressed.connect(owner._close_debug_unlock_panel)
	owner.debug_unlock_panel.add_child(owner.debug_close_button)
	owner.ButtonGlow.attach(owner, owner.debug_close_button)
	UIAudioManager.attach_button(owner.debug_close_button)

	var tabs = TabContainer.new()
	tabs.position = Vector2(24.0, 76.0)
	tabs.size = Vector2(632.0, 396.0)
	tabs.clip_contents = true
	owner.debug_unlock_panel.add_child(tabs)

	var achievements_tab = MarginContainer.new()
	achievements_tab.name = "ACHIEVEMENTS"
	achievements_tab.add_theme_constant_override("margin_left", 10)
	achievements_tab.add_theme_constant_override("margin_top", 14)
	achievements_tab.add_theme_constant_override("margin_right", 10)
	achievements_tab.add_theme_constant_override("margin_bottom", 10)
	tabs.add_child(achievements_tab)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	achievements_tab.add_child(scroll)

	owner.debug_achievement_list = VBoxContainer.new()
	owner.debug_achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner.debug_achievement_list.add_theme_constant_override("separation", 8)
	scroll.add_child(owner.debug_achievement_list)

	var all_tab = MarginContainer.new()
	all_tab.name = "ALL"
	all_tab.add_theme_constant_override("margin_left", 10)
	all_tab.add_theme_constant_override("margin_top", 14)
	all_tab.add_theme_constant_override("margin_right", 10)
	all_tab.add_theme_constant_override("margin_bottom", 10)
	tabs.add_child(all_tab)

	var all_box = VBoxContainer.new()
	all_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_box.add_theme_constant_override("separation", 12)
	all_tab.add_child(all_box)

	var all_label = Label.new()
	all_label.text = "Unlock gallery memories only, or unlock every debug reward at once."
	all_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	all_label.add_theme_font_override("font", owner.UI_FONT)
	all_label.add_theme_font_size_override("font_size", 10)
	all_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	all_box.add_child(all_label)

	owner.debug_unlock_gallery_memory_button = Button.new()
	owner.debug_unlock_gallery_memory_button.custom_minimum_size = Vector2(0.0, 56.0)
	owner.debug_unlock_gallery_memory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner.debug_unlock_gallery_memory_button.text = "UNLOCK GALLERY + MEMORY ONLY"
	apply_debug_button_theme(owner, owner.debug_unlock_gallery_memory_button)
	owner.debug_unlock_gallery_memory_button.pressed.connect(owner._debug_unlock_gallery_memory_only)
	all_box.add_child(owner.debug_unlock_gallery_memory_button)
	owner.ButtonGlow.attach(owner, owner.debug_unlock_gallery_memory_button)
	UIAudioManager.attach_button(owner.debug_unlock_gallery_memory_button)

	owner.debug_unlock_memories_button = Button.new()
	owner.debug_unlock_memories_button.custom_minimum_size = Vector2(0.0, 56.0)
	owner.debug_unlock_memories_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner.debug_unlock_memories_button.text = "UNLOCK GALLERY + MEMORY + ACHIEVEMENTS"
	apply_debug_button_theme(owner, owner.debug_unlock_memories_button)
	owner.debug_unlock_memories_button.pressed.connect(owner._debug_unlock_all)
	all_box.add_child(owner.debug_unlock_memories_button)
	owner.ButtonGlow.attach(owner, owner.debug_unlock_memories_button)
	UIAudioManager.attach_button(owner.debug_unlock_memories_button)

	refresh_debug_achievement_list(owner)


static func open_debug_unlock_panel(owner) -> void:
	if owner.is_start_transitioning or owner.debug_unlock_overlay == null:
		return
	refresh_debug_achievement_list(owner)
	owner.debug_unlock_overlay.visible = true
	owner.debug_close_button.grab_focus()


static func close_debug_unlock_panel(owner) -> void:
	if owner.debug_unlock_overlay == null:
		return
	owner.debug_unlock_overlay.visible = false


static func is_debug_unlock_panel_open(owner) -> bool:
	return owner.debug_unlock_overlay != null and owner.debug_unlock_overlay.visible


static func refresh_debug_achievement_list(owner) -> void:
	if owner.debug_achievement_list == null:
		return
	for child in owner.debug_achievement_list.get_children():
		child.queue_free()

	for achievement_id_variant in AchievementServiceData.ORDER:
		var achievement_id = str(achievement_id_variant)
		var achievement_data = PlayerState.get_achievement_data(achievement_id)
		if achievement_data.is_empty():
			continue

		var is_unlocked = bool(achievement_data.get("unlocked", false))
		var button = Button.new()
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s / %s%s" % [
			str(achievement_data.get("title", "")).to_upper(),
			str(achievement_data.get("subtitle", "")),
			"  UNLOCKED" if is_unlocked else "",
		]
		button.disabled = is_unlocked
		apply_debug_button_theme(owner, button)
		if not is_unlocked:
			button.pressed.connect(owner._debug_unlock_achievement.bind(achievement_id))
		owner.debug_achievement_list.add_child(button)
		owner.ButtonGlow.attach(owner, button)
		UIAudioManager.attach_button(button)


static func debug_unlock_achievement(owner, achievement_id: String) -> void:
	var achievement_data = PlayerState.get_achievement_data(achievement_id)
	if achievement_data.is_empty():
		return
	PlayerState.unlock_achievement(achievement_id)
	refresh_debug_achievement_list(owner)
	set_debug_unlock_message(owner, "Achievement unlocked: %s" % str(achievement_data.get("title", achievement_id)).to_upper())


static func debug_unlock_gallery_memory_only(owner) -> void:
	StoryMemoryCatalog.unlock_gallery_and_memories_only(PlayerState)
	set_debug_unlock_message(owner, "Gallery and memories unlocked")


static func set_debug_unlock_message(owner, message: String) -> void:
	owner.debug_unlock_message_text = message
	owner.debug_unlock_message_time = 1.8
	owner.hint_label.text = owner.debug_unlock_message_text
