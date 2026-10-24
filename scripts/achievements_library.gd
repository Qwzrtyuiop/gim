extends Control

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const LibraryTheme := preload("res://scripts/library/library_theme.gd")

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
	UIAudioManager.attach_button(close_button)
	LibraryTheme.apply_achievement_button(close_button)
	LibraryTheme.apply_panel(main_panel, Color(0.10, 0.09, 0.08, 0.92), 12)
	LibraryTheme.apply_panel(detail_panel, Color(0.11, 0.10, 0.08, 0.96), 12)
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
		LibraryTheme.apply_achievement_button(button)
		button.pressed.connect(_show_details.bind(achievement_data))
		list_container.add_child(button)
		ButtonGlow.attach(self, button)

	if list_container.get_child_count() > 0:
		var first_button := list_container.get_child(0)
		if first_button is Button:
			(first_button as Button).grab_focus()


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
