extends Control

signal action_pressed(action: String)

const DAY := preload("res://assets/story/backgrounds/locations/inhouse.png")
const NIGHT := preload("res://assets/story/backgrounds/locations/inhouse_night.png")
const DAY_SELECTED := preload("res://assets/story/backgrounds/locations/Daywithselect.png")
const NIGHT_SELECTED := preload("res://assets/story/backgrounds/locations/Nightwithselect.png")
# Normalized image coordinates: each crop contains only one outlined object.
# The sleeping area is behind the curtained doorway on the right.
const REGIONS := {
	"radio": Rect2(0.044, 0.565, 0.083, 0.094),
	"calendar": Rect2(0.468, 0.426, 0.043, 0.122),
	"rest": Rect2(0.875, 0.258, 0.064, 0.452),
	"ride": Rect2(0.778, 0.865, 0.222, 0.135),
}
const TOOLTIPS := {
	"radio": "Radio: news and weather forecast",
	"calendar": "Calendar: weekly goal, debt and due date",
	"rest": "Rest",
	"ride": "Go outside: Ride or Shop",
}

class HotspotButton:
	extends Button
	var exit_shape := false
	func _has_point(point: Vector2) -> bool:
		if not exit_shape:
			return Rect2(Vector2.ZERO, size).has_point(point)
		var polygon := PackedVector2Array([
			Vector2(0, size.y), Vector2(size.x * 0.42, size.y * 0.10),
			Vector2(size.x, size.y * 0.27), size,
		])
		return Geometry2D.is_point_in_polygon(point, polygon)

var buttons: Dictionary = {}
var is_night := false
var image_rect := Rect2()
var hovered_action := ""
var focused_action := ""
var enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for action: String in REGIONS:
		var button := HotspotButton.new()
		button.name = action.capitalize() + "Hotspot"
		button.exit_shape = action == "ride"
		button.tooltip_text = TOOLTIPS[action]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
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

func set_night(value: bool) -> void:
	is_night = value
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
	var texture: Texture2D = NIGHT if is_night else DAY
	var ratio := minf(size.x / texture.get_width(), size.y / texture.get_height())
	image_rect = Rect2((size - texture.get_size() * ratio) * 0.5, texture.get_size() * ratio)
	for action: String in buttons:
		var region: Rect2 = REGIONS[action]
		var rect := Rect2(image_rect.position + region.position * image_rect.size, region.size * image_rect.size)
		# A little extra hover room helps with the small radio and calendar.
		if action in ["radio", "calendar"]:
			rect = rect.grow(7.0)
		buttons[action].position = rect.position
		buttons[action].size = rect.size
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.02, 0.015))
	var texture: Texture2D = NIGHT if is_night else DAY
	draw_texture_rect(texture, image_rect, false)
	var action := hovered_action if not hovered_action.is_empty() else focused_action
	if not enabled or not REGIONS.has(action):
		return
	var selected: Texture2D = NIGHT_SELECTED if is_night else DAY_SELECTED
	var region: Rect2 = REGIONS[action]
	var source := Rect2(region.position * selected.get_size(), region.size * selected.get_size())
	var destination := Rect2(image_rect.position + region.position * image_rect.size, region.size * image_rect.size)
	draw_texture_rect_region(selected, destination, source)
