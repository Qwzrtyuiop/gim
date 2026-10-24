extends RefCounted

# Dialogue, choice controls, visual theme, and debt overlays.

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const StoryConditions := preload("res://scripts/story/story_conditions.gd")
const StoryDebtTransition := preload("res://scripts/story/story_debt_transition.gd")
const PlayerDebtState := preload("res://scripts/state/player_debt_state.gd")
const DEFAULT_CONTINUE_HINT := "ENTER / CLICK"
const DIALOGUE_PANEL_COLOR := Color(0.09, 0.08, 0.07, 0.92)
const DIALOGUE_PANEL_BORDER := Color(0.71, 0.58, 0.39, 0.95)
const PORTRAIT_PANEL_COLOR := Color(0.12, 0.10, 0.09, 0.82)
const PORTRAIT_PANEL_BORDER := Color(0.60, 0.48, 0.33, 0.95)
const CHOICE_BUTTON_BG := Color(0.42, 0.27, 0.17, 0.96)
const CHOICE_BUTTON_HOVER_BG := Color(0.78, 0.59, 0.29, 0.98)
const CHOICE_BUTTON_PRESSED_BG := Color(0.28, 0.45, 0.28, 0.98)
const CHOICE_BUTTON_BORDER := Color(0.13, 0.09, 0.06, 0.98)


static func apply_line_text(owner, line: Dictionary) -> void:
	var speaker := str(line.get("speaker", ""))
	var body_text := str(line.get("text", ""))
	var continue_text := str(line.get("continue_hint", DEFAULT_CONTINUE_HINT))
	set_dialogue_content(owner, speaker, body_text, continue_text, true)
	# Authored introductions can control the label without changing the speaker
	# identity used for portraits or saved passenger progress.
	if line.has("speaker_display_name"):
		owner.speaker_label.text = str(line["speaker_display_name"]).to_upper()


static func render_choices(owner, line: Dictionary) -> void:
	clear_choice_buttons(owner)
	var raw_choices: Array = line.get("choices", [])
	if raw_choices.is_empty():
		owner.choice_container.visible = false
		owner.continue_label.visible = true
		return

	owner.continue_label.visible = false
	owner.choice_container.visible = true

	for choice_data_variant in raw_choices:
		if not choice_data_variant is Dictionary:
			continue

		var choice_data: Dictionary = (choice_data_variant as Dictionary).duplicate(true)
		if not StoryConditions.matches_story_conditions(choice_data):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(420.0, 54.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(choice_data.get("text", "CONTINUE"))
		var is_disabled := bool(choice_data.get("disabled", not bool(choice_data.get("enabled", true))))
		button.disabled = is_disabled
		button.focus_mode = Control.FOCUS_NONE
		apply_choice_button_theme(button)
		if not is_disabled:
			button.pressed.connect(owner._choose_branch.bind(choice_data))
		owner.choice_container.add_child(button)
		owner.choice_buttons.append(button)
		if not is_disabled:
			ButtonGlow.attach(owner, button)

	if owner.choice_buttons.is_empty():
		owner.choice_container.visible = false
		owner.continue_label.visible = true


static func has_active_choices(owner) -> bool:
	return owner.choice_container.visible and not owner.choice_buttons.is_empty()


static func clear_choice_buttons(owner) -> void:
	for button in owner.choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	owner.choice_buttons.clear()


static func apply_theme(owner) -> void:
	owner.clip_contents = true
	owner.background.anchor_left = 0.0
	owner.background.anchor_top = 0.0
	owner.background.anchor_right = 0.0
	owner.background.anchor_bottom = 0.0
	owner.background.offset_left = 0.0
	owner.background.offset_top = 0.0
	owner.background.offset_right = 0.0
	owner.background.offset_bottom = 0.0
	owner.background.position = Vector2.ZERO
	owner.background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner.background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner.background_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.debt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.left_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.right_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_label_theme(owner.chapter_label, 12, Color(0.96, 0.92, 0.78, 1.0), Color.BLACK, 2)
	apply_label_theme(owner.debt_remaining_label, 11, Color(0.96, 0.92, 0.78, 1.0), Color.BLACK, 2)
	apply_label_theme(owner.debt_due_label, 10, Color(0.88, 0.84, 0.74, 1.0), Color.BLACK, 1)
	apply_label_theme(owner.speaker_label, 16, Color(0.96, 0.84, 0.56, 1.0), Color.BLACK, 2)
	apply_label_theme(owner.body_label, 13, Color(0.98, 0.96, 0.90, 1.0), Color.BLACK, 2)
	apply_label_theme(owner.continue_label, 10, Color(0.88, 0.84, 0.74, 1.0), Color.BLACK, 1)
	owner.left_portrait_frame.visible = false
	owner.right_portrait_frame.visible = false
	owner.dialogue_panel.visible = false
	owner.debt_overlay.visible = false
	owner.debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	owner.speaker_label.visible = false
	owner.body_label.text = ""
	owner.continue_label.visible = false
	owner.choice_container.visible = false

	owner.debt_overlay.add_theme_stylebox_override("panel", make_panel_style(Color(0.12, 0.10, 0.09, 0.86), DIALOGUE_PANEL_BORDER, 10))
	owner.dialogue_panel.add_theme_stylebox_override("panel", make_panel_style(DIALOGUE_PANEL_COLOR, DIALOGUE_PANEL_BORDER, 10))
	owner.left_portrait_frame.add_theme_stylebox_override("panel", make_panel_style(PORTRAIT_PANEL_COLOR, PORTRAIT_PANEL_BORDER, 10))
	owner.right_portrait_frame.add_theme_stylebox_override("panel", make_panel_style(PORTRAIT_PANEL_COLOR, PORTRAIT_PANEL_BORDER, 10))
	owner.fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	owner.background_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)


static func apply_label_theme(label: Label, font_size: int, font_color: Color, outline_color: Color, outline_size: int) -> void:
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)


static func apply_choice_button_theme(button: Button) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.16, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.16, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.56, 0.50, 0.9))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_stylebox_override("normal", make_panel_style(CHOICE_BUTTON_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("hover", make_panel_style(CHOICE_BUTTON_HOVER_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("pressed", make_panel_style(CHOICE_BUTTON_PRESSED_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("focus", make_panel_style(CHOICE_BUTTON_HOVER_BG, CHOICE_BUTTON_BORDER, 7))
	button.add_theme_stylebox_override("disabled", make_panel_style(Color(0.18, 0.13, 0.10, 0.9), Color(0.10, 0.08, 0.06, 0.9), 7))


static func make_panel_style(bg_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


static func show_weekly_debt_transition(owner) -> void:
	hide_weekly_debt_transition(owner)
	owner.weekly_debt_transition = StoryDebtTransition.new()
	owner.add_child(owner.weekly_debt_transition)
	owner.weekly_debt_transition.setup(PlayerDebtState.first_week_transition_report(PlayerState))
	owner.dialogue_panel.visible = false
	await owner.weekly_debt_transition.play()


static func hide_weekly_debt_transition(owner) -> void:
	if is_instance_valid(owner.weekly_debt_transition):
		owner.remove_child(owner.weekly_debt_transition)
		owner.weekly_debt_transition.queue_free()
	owner.weekly_debt_transition = null


static func show_debt_overlay(owner, overlay_data) -> void:
	var config: Dictionary = {}
	if overlay_data is Dictionary:
		config = (overlay_data as Dictionary).duplicate(true)
	var display_day := int(config.get("day", PlayerState.get_current_day()))
	owner.debt_remaining_label.text = str(config.get(
		"remaining_text",
		"Debt Remaining: PhP %d" % PlayerState.get_total_debt_goal()
	))
	owner.debt_due_label.text = str(config.get(
		"due_text",
		PlayerState.get_debt_due_text(display_day)
	))
	var fade_duration := float(config.get("fade_in", config.get("duration", 0.24)))
	if owner.debt_overlay_tween:
		owner.debt_overlay_tween.kill()
	owner.debt_overlay.visible = true
	owner.debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if fade_duration <= 0.0:
		owner.debt_overlay.modulate = Color.WHITE
		return
	owner.debt_overlay_tween = owner.create_tween()
	owner.debt_overlay_tween.tween_property(owner.debt_overlay, "modulate:a", 1.0, fade_duration)
	await owner.debt_overlay_tween.finished
	owner.debt_overlay_tween = null


static func hide_debt_overlay(owner, overlay_data) -> void:
	var fade_duration := 0.2
	if overlay_data is Dictionary:
		fade_duration = float((overlay_data as Dictionary).get("fade_out", (overlay_data as Dictionary).get("duration", fade_duration)))
	elif overlay_data != null:
		fade_duration = float(overlay_data)
	if not owner.debt_overlay.visible:
		return
	if owner.debt_overlay_tween:
		owner.debt_overlay_tween.kill()
	if fade_duration <= 0.0:
		owner.debt_overlay.visible = false
		owner.debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return
	owner.debt_overlay_tween = owner.create_tween()
	owner.debt_overlay_tween.tween_property(owner.debt_overlay, "modulate:a", 0.0, fade_duration)
	await owner.debt_overlay_tween.finished
	owner.debt_overlay.visible = false
	owner.debt_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	owner.debt_overlay_tween = null


static func set_dialogue_content(owner, speaker: String, body_text: String, continue_text: String, is_visible: bool) -> void:
	owner.dialogue_panel.visible = is_visible
	owner.speaker_label.visible = not speaker.is_empty()
	owner.speaker_label.text = PlayerState.get_speaker_display_name(speaker).to_upper()
	owner.body_label.text = body_text
	owner.continue_label.text = continue_text if not continue_text.is_empty() else DEFAULT_CONTINUE_HINT
