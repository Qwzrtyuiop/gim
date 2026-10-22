extends Control

signal action_pressed(action: String)

const BACKGROUND := preload("res://assets/story/backgrounds/locations/store.png")
const SELECTED := preload("res://assets/story/backgrounds/locations/storewithselect.png")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const REGIONS := {
	"tricycle": Rect2(0.106, 0.357, 0.402, 0.537),
	"food": Rect2(0.639, 0.435, 0.277, 0.262),
	"home": Rect2(0.0, 552.0 / 1536.0, 169.0 / 2816.0, 903.0 / 1536.0),
	"station": Rect2(2636.0 / 2816.0, 554.0 / 1536.0, 179.0 / 2816.0, 899.0 / 1536.0),
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for action: String in REGIONS:
		var button := Button.new()
		button.name = action.capitalize() + "Hotspot"
		button.tooltip_text = TOOLTIPS[action]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		if action in ["home", "station"]:
			# Keep the original street signs separate so their text does not
			# expand the narrow exit hotspots beyond the outlined posts.
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
		button.mouse_entered.connect(func() -> void:
			hovered_action = action
			queue_redraw()
		)
		button.mouse_exited.connect(func() -> void:
			if hovered_action == action:
				hovered_action = ""
			queue_redraw()
		)
		button.focus_entered.connect(func() -> void:
			focused_action = action
			queue_redraw()
		)
		button.focus_exited.connect(func() -> void:
			if focused_action == action:
				focused_action = ""
			queue_redraw()
		)
		button.pressed.connect(func() -> void: action_pressed.emit(action))
		add_child(button)
		UIAudioManager.attach_button(button)
		buttons[action] = button
	resized.connect(_layout)
	_layout()


func set_enabled(value: bool) -> void:
	enabled = value
	for button: Button in buttons.values():
		button.disabled = not value
		if not value:
			button.release_focus()
	if not value:
		hovered_action = ""
		focused_action = ""
	queue_redraw()


func _layout() -> void:
	var ratio := minf(size.x / BACKGROUND.get_width(), size.y / BACKGROUND.get_height())
	image_rect = Rect2((size - BACKGROUND.get_size() * ratio) * 0.5, BACKGROUND.get_size() * ratio)
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
	draw_texture_rect(BACKGROUND, image_rect, false)
	var action := hovered_action if not hovered_action.is_empty() else focused_action
	for exit_action: String in exit_labels:
		exit_labels[exit_action].add_theme_color_override("font_color", Color("ffdf52") if enabled and action == exit_action else Color("f5dfac"))
	if not enabled or not REGIONS.has(action):
		return
	var region: Rect2 = REGIONS[action]
	draw_texture_rect_region(SELECTED,
		Rect2(image_rect.position + region.position * image_rect.size, region.size * image_rect.size),
		Rect2(region.position * SELECTED.get_size(), region.size * SELECTED.get_size()))
