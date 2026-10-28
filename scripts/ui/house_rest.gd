extends Control

signal closed
signal confirmed

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const DESIGN_SIZE := Vector2(768, 512)
const TEXTURE := preload("res://assets/ui/frames/pillow.png")
const FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const INK := Color("392719")

var title_label: Label
var recovery_label: Label
var time_label: Label
var cancel_button: Button
var confirm_button: Button
var _highlight_mode := InputHighlightMode.new()


func _ready() -> void:
	name = "HouseRest"
	size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := TextureRect.new()
	background.name = "PillowBackground"
	background.texture = TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = DESIGN_SIZE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	# The pillow's flat center is the writing area; leave its folded edges clear.
	title_label = _label(Rect2(154, 145, 460, 44), 36, INK)
	recovery_label = _label(Rect2(154, 205, 460, 40), 24, Color("7a512b"))
	time_label = _label(Rect2(154, 258, 460, 32), 24, Color("625648"))
	cancel_button = _button("Not Yet", Vector2(204, 318))
	cancel_button.name = "CancelRest"
	cancel_button.pressed.connect(func() -> void: closed.emit())
	confirm_button = _button("", Vector2(396, 318))
	confirm_button.name = "ConfirmRest"
	confirm_button.pressed.connect(func() -> void: confirmed.emit())
	refresh()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and _highlight_mode.handle_input(event):
		_refresh_button_glow(cancel_button)
		_refresh_button_glow(confirm_button)


func refresh() -> void:
	_highlight_mode.reset()
	var phase := PlayerState.get_current_time_of_day()
	var sleeping := phase == "night"
	title_label.text = "Sleep until morning?" if sleeping else "Take a short rest?"
	recovery_label.text = "ENERGY TO %d / STRESS -%d" % [PlayerState.max_energy, GameTuning.NIGHT_SLEEP_STRESS_RELIEF] if sleeping else "+%d ENERGY / STRESS -%d" % [GameTuning.REST_ENERGY_RESTORE, GameTuning.REST_STRESS_RELIEF]
	if sleeping:
		time_label.text = "DAY %d / MORNING" % (PlayerState.get_current_day() + 1)
	else:
		time_label.text = "CONTINUE AT %s" % ("NOON" if phase == "morning" else "NIGHT")
	confirm_button.text = "Sleep" if sleeping else "Rest"
	_refresh_button_glow(cancel_button)
	_refresh_button_glow(confirm_button)


func _label(rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _button(text: String, at: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(168, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("9c6a29"))
	button.add_theme_color_override("font_focus_color", Color("9c6a29"))
	button.add_theme_color_override("font_pressed_color", Color("604019"))
	button.add_theme_color_override("font_disabled_color", Color("95897c"))
	button.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	button.add_theme_constant_override("outline_size", 2)
	button.mouse_entered.connect(_refresh_button_glow.bind(button))
	button.mouse_exited.connect(_refresh_button_glow.bind(button))
	button.focus_entered.connect(_refresh_button_glow.bind(button))
	button.focus_exited.connect(_refresh_button_glow.bind(button))
	add_child(button)
	UIAudioManager.attach_button(button)
	return button


func _refresh_button_glow(button: Button) -> void:
	var glowing := button.is_hovered() or (_highlight_mode.keyboard_active and button.has_focus())
	button.add_theme_color_override("font_focus_color", Color("9c6a29") if glowing else INK)
	button.add_theme_color_override("font_outline_color", Color(0.95, 0.78, 0.44, 0.6) if glowing else Color.TRANSPARENT)
