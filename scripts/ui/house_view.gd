extends Control

signal action_pressed(action: String)

const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const Selectables := preload("res://scripts/ui/house_selectable_catalog.gd")
const DAY := preload("res://assets/story/backgrounds/locations/inhouse.png")
const NIGHT := preload("res://assets/story/backgrounds/locations/inhouse_night.png")
const HubWeatherEffects := preload("res://scripts/ui/hub_weather_effects.gd")
const RAIN_MARKER := preload("res://assets/story/backgrounds/locations/houserain_indoor.png")
const REGIONS := Selectables.REGIONS
const HOVER_SCALE := 1.06
const TOOLTIPS := {
	"radio": "Radio: news and weather forecast",
	"calendar": "Calendar: weekly goal, debt and due date",
	"rest": "Rest",
	"ride": "Go outside: Ride or Shop",
}

class HotspotButton:
	extends Button
	var alpha_image: Image
	var exit_shape := false

	func _has_point(point: Vector2) -> bool:
		if not Rect2(Vector2.ZERO, size).has_point(point):
			return false
		if exit_shape:
			return Geometry2D.is_point_in_polygon(point, exit_polygon(size))
		if alpha_image == null or size.x <= 0 or size.y <= 0:
			return false
		var pixel := Vector2i(point / size * Vector2(alpha_image.get_size()))
		# Cache/sample the shared authored alpha instead of maintaining separate
		# day/night rectangles. A tiny source-pixel margin helps thin antenna art.
		for offset_y in [-2, 0, 2]:
			for offset_x in [-2, 0, 2]:
				var sample := pixel + Vector2i(offset_x, offset_y)
				if sample.x < 0 or sample.y < 0 or sample.x >= alpha_image.get_width() or sample.y >= alpha_image.get_height():
					continue
				if alpha_image.get_pixelv(sample).a >= 0.7:
					return true
		return false

	static func exit_polygon(area: Vector2) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(0, area.y),
			Vector2(area.x * 0.42, area.y * 0.10),
			Vector2(area.x, area.y * 0.27),
			area,
		])

var buttons: Dictionary = {}
var is_night := false
var weather := "clear"
var weather_effects: HubWeatherEffects
var image_rect := Rect2()
var hovered_action := ""
var focused_action := ""
var enabled := true
var highlight_mode := InputHighlightMode.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for action: String in REGIONS:
		var button := HotspotButton.new()
		button.name = action.capitalize() + "Hotspot"
		button.exit_shape = action == "ride"
		button.alpha_image = Selectables.alpha_image(action)
		button.disabled = not enabled
		button.tooltip_text = TOOLTIPS[action]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
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
	weather_effects = HubWeatherEffects.new()
	weather_effects.configure(RAIN_MARKER, true)
	add_child(weather_effects)
	move_child(weather_effects, 0)
	weather_effects.set_weather(weather)
	_layout()


func _input(event: InputEvent) -> void:
	if enabled and is_visible_in_tree() and highlight_mode.handle_input(event):
		queue_redraw()


func active_action() -> String:
	return highlight_mode.active(hovered_action, focused_action) if enabled else ""


func set_keyboard_navigation(value: bool) -> void:
	highlight_mode.keyboard_active = value
	queue_redraw()


func is_keyboard_navigation() -> bool:
	return highlight_mode.keyboard_active


func set_night(value: bool) -> void:
	is_night = value
	# Lighting changes the background and selected art only. Positions and cached
	# alpha masks remain the same; there is no second set of hitbox calculations.
	queue_redraw()


func set_weather(value: String) -> void:
	weather = value
	if weather_effects != null:
		weather_effects.set_weather(value)
	queue_redraw()


func set_enabled(value: bool) -> void:
	enabled = value
	for button: Button in buttons.values():
		button.disabled = not value
	if not value:
		_clear_focus()
	queue_redraw()


func sprite_rect_for(action: String, highlighted := false) -> Rect2:
	if not REGIONS.has(action):
		return Rect2()
	var region: Rect2 = REGIONS[action]
	var rect := Rect2(image_rect.position + region.position * image_rect.size, region.size * image_rect.size)
	if highlighted and Selectables.ENTRIES.has(action):
		var growth := rect.size * (HOVER_SCALE - 1.0)
		rect.position -= Vector2(growth.x * 0.5, growth.y)
		rect.size += growth
	return rect


func _layout() -> void:
	var ratio := minf(size.x / Selectables.ART_SIZE.x, size.y / Selectables.ART_SIZE.y)
	image_rect = Rect2((size - Selectables.ART_SIZE * ratio) * 0.5, Selectables.ART_SIZE * ratio)
	for action: String in buttons:
		var rect := sprite_rect_for(action)
		buttons[action].position = rect.position
		buttons[action].size = rect.size
	if weather_effects != null:
		weather_effects.set_art_rect(image_rect)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.02, 0.015))
	draw_texture_rect(NIGHT if is_night else DAY, image_rect, false, weather_effects.background_tint())
	var action := active_action()
	if not REGIONS.has(action):
		return
	if action == "ride":
		_draw_exit_highlight()
		return
	# Draw the selected object last, once, above the room artwork. Hit testing
	# keeps its resting mask so enlarged edges cannot toggle hover repeatedly.
	draw_texture_rect(Selectables.texture_for(action, is_night), sprite_rect_for(action, true), false, weather_effects.background_tint())


func _draw_exit_highlight() -> void:
	var rect := sprite_rect_for("ride")
	var polygon := HotspotButton.exit_polygon(rect.size)
	for index in polygon.size():
		polygon[index] += rect.position
	draw_colored_polygon(polygon, Color(0.9, 0.75, 0.4, 0.08))
	polygon.append(polygon[0])
	draw_polyline(polygon, Color(0.9, 0.75, 0.4, 0.7), 1.5, true)


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
