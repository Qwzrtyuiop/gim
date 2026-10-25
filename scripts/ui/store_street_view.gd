extends Control

signal action_pressed(action: String)

const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const BACKGROUND := preload("res://assets/story/backgrounds/locations/store.png")
const NIGHT := preload("res://assets/story/backgrounds/locations/storenight.png")
const SELECTED := preload("res://assets/story/backgrounds/locations/store_select.png")
const ART_SIZE := Vector2(1698, 926)
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
# The supplied sheet marks rectangular interaction areas. Their full interiors
# are clickable, including the transparent space inside each drawn border.
# One layout serves both background phases; no alpha scan is needed for input.
const REGIONS := {
	"tricycle": Rect2(203.0 / 1698.0, 352.0 / 926.0, 653.0 / 1698.0, 470.0 / 926.0),
	"food": Rect2(1089.0 / 1698.0, 409.0 / 926.0, 448.0 / 1698.0, 236.0 / 926.0),
	"home": Rect2(1.0 / 1698.0, 353.0 / 926.0, 89.0 / 1698.0, 495.0 / 926.0),
	"station": Rect2(1592.0 / 1698.0, 410.0 / 926.0, 103.0 / 1698.0, 453.0 / 926.0),
}
const TOOLTIPS := {
	"tricycle": "Lito's: tricycle upgrades and gas",
	"food": "Mang Eddie's: food and energy",
	"home": "Go home",
	"station": "Go to the station: select a passenger",
}

var buttons: Dictionary = {}
var exit_labels: Dictionary = {}
var image_rect := Rect2()
var hovered_action := ""
var focused_action := ""
var enabled := true
var is_night := false
var highlight_mode := InputHighlightMode.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for action: String in REGIONS:
		var button := Button.new()
		button.name = action.capitalize() + "Hotspot"
		button.tooltip_text = TOOLTIPS[action]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = not enabled
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		if action in ["home", "station"]:
			# The existing street captions remain separate from the narrow exit
			# rectangles so their text cannot expand the authored hit areas.
			var label := Label.new()
			label.text = "< HOME" if action == "home" else "STATION >"
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_override("font", FONT)
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color("f5dfac"))
			label.add_theme_color_override("font_outline_color", Color("201409"))
			label.add_theme_constant_override("outline_size", 4)
			add_child(label)
			exit_labels[action] = label
		button.mouse_entered.connect(_on_hovered.bind(action))
		button.mouse_exited.connect(_on_unhovered.bind(action))
		button.focus_entered.connect(_on_focused.bind(action))
		button.focus_exited.connect(_on_unfocused.bind(action))
		button.pressed.connect(_on_action_pressed.bind(action))
		add_child(button)
		UIAudioManager.attach_button(button)
		buttons[action] = button
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	_layout()


func _input(event: InputEvent) -> void:
	if enabled and is_visible_in_tree() and highlight_mode.handle_input(event):
		queue_redraw()


func active_action() -> String:
	return highlight_mode.active(hovered_action, focused_action) if enabled else ""


func set_night(value: bool) -> void:
	is_night = value
	queue_redraw()


func set_enabled(value: bool) -> void:
	enabled = value
	for button: Button in buttons.values():
		button.disabled = not value
	if not value:
		_clear_focus()
	queue_redraw()


func _layout() -> void:
	var ratio := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	image_rect = Rect2((size - ART_SIZE * ratio) * 0.5, ART_SIZE * ratio)
	for action: String in buttons:
		var region: Rect2 = REGIONS[action]
		buttons[action].position = image_rect.position + region.position * image_rect.size
		buttons[action].size = region.size * image_rect.size
	for action: String in exit_labels:
		var sign_region := Rect2(0.0 if action == "home" else 0.82, 0.90, 0.18, 0.10)
		exit_labels[action].position = image_rect.position + sign_region.position * image_rect.size
		exit_labels[action].size = sign_region.size * image_rect.size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17110b"))
	draw_texture_rect(NIGHT if is_night else BACKGROUND, image_rect, false)
	var action := active_action()
	for exit_action: String in exit_labels:
		exit_labels[exit_action].add_theme_color_override("font_color", Color("ffdf52") if action == exit_action else Color("f5dfac"))
	if not REGIONS.has(action):
		return
	var region: Rect2 = REGIONS[action]
	var source := Rect2((region.position * ART_SIZE).round(), (region.size * ART_SIZE).round())
	draw_texture_rect_region(SELECTED,
		Rect2(image_rect.position + region.position * image_rect.size, region.size * image_rect.size),
		source)


func _on_hovered(action: String) -> void:
	if enabled:
		hovered_action = action
		queue_redraw()


func _on_unhovered(action: String) -> void:
	if hovered_action == action:
		hovered_action = ""
	queue_redraw()


func _on_focused(action: String) -> void:
	if enabled:
		focused_action = action
		queue_redraw()


func _on_unfocused(action: String) -> void:
	if focused_action == action:
		focused_action = ""
	queue_redraw()


func _on_action_pressed(action: String) -> void:
	if enabled and is_visible_in_tree():
		action_pressed.emit(action)


func _clear_focus() -> void:
	for button: Button in buttons.values():
		button.release_focus()
	hovered_action = ""
	focused_action = ""
	highlight_mode.reset()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_focus()
		queue_redraw()
