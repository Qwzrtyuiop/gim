extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

@onready var list_container: VBoxContainer = $Panel/ScrollContainer/ListContainer
@onready var empty_label: Label = $Panel/EmptyLabel
@onready var main_panel: Panel = $Panel
@onready var back_button: BaseButton = $Panel/BackButton
@onready var back_label: Label = $Panel/BackButton/BackLabel
@onready var detail_overlay: ColorRect = $DetailOverlay
@onready var detail_panel: Panel = $DetailOverlay/DetailPanel
@onready var detail_title: Label = $DetailOverlay/DetailPanel/TitleLabel
@onready var detail_subtitle: Label = $DetailOverlay/DetailPanel/SubtitleLabel
@onready var detail_body: Label = $DetailOverlay/DetailPanel/BodyLabel
@onready var close_button: Button = $DetailOverlay/DetailPanel/CloseButton


func _ready() -> void:
	back_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ButtonGlow.attach(self, back_button)
	_apply_button_theme(close_button)
	_apply_panel_theme(main_panel, Color(0.10, 0.09, 0.08, 0.92))
	_apply_panel_theme(detail_panel, Color(0.11, 0.10, 0.08, 0.96))
	back_button.pressed.connect(_go_back)
	close_button.pressed.connect(_hide_details)
	detail_overlay.visible = false
	_populate_achievement_list()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if detail_overlay.visible:
			_hide_details()
			return
		_go_back()


func _populate_achievement_list() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var unlocked_ids := PlayerState.get_unlocked_achievement_ids()
	empty_label.visible = unlocked_ids.is_empty()
	if unlocked_ids.is_empty():
		return

	for achievement_id in unlocked_ids:
		var achievement_data := PlayerState.get_achievement_data(achievement_id)
		if achievement_data.is_empty():
			continue

		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s / %s" % [
			str(achievement_data.get("title", "")).to_upper(),
			str(achievement_data.get("subtitle", "")),
		]
		_apply_button_theme(button)
		button.pressed.connect(_show_details.bind(achievement_data))
		list_container.add_child(button)
		ButtonGlow.attach(self, button)

	if list_container.get_child_count() > 0:
		var first_button := list_container.get_child(0)
		if first_button is Button:
			(first_button as Button).grab_focus()


func _apply_button_theme(button: BaseButton) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.10, 0.06, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1.0))
	button.add_theme_constant_override("outline_size", 1)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.17, 0.12, 0.94)
	normal_style.border_color = Color(0.60, 0.45, 0.26, 1.0)
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 18.0
	normal_style.content_margin_right = 18.0
	normal_style.content_margin_top = 14.0
	normal_style.content_margin_bottom = 14.0

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.83, 0.63, 0.33, 0.98)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.35, 0.48, 0.31, 0.98)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)


func _apply_panel_theme(panel: Panel, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.71, 0.56, 0.31, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)


func _show_details(achievement_data: Dictionary) -> void:
	detail_title.text = str(achievement_data.get("title", "")).to_upper()
	detail_subtitle.text = str(achievement_data.get("subtitle", ""))
	detail_body.text = str(achievement_data.get("description", ""))
	detail_overlay.visible = true
	close_button.grab_focus()


func _hide_details() -> void:
	detail_overlay.visible = false


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
