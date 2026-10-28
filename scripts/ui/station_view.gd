extends Control

signal action_pressed(action: String)

const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const DAY := preload("res://assets/story/backgrounds/locations/Updated_day.png")
const NIGHT := preload("res://assets/story/backgrounds/locations/Updated_night.png")
const DAY_SELECTED := preload("res://assets/story/backgrounds/locations/Updated_day_select.png")
const NIGHT_SELECTED := preload("res://assets/story/backgrounds/locations/Updated_night_select.png")
const HubWeatherEffects := preload("res://scripts/ui/hub_weather_effects.gd")
const RAIN_MARKER := preload("res://assets/story/backgrounds/locations/stationrain.png")
const ART_SIZE := Vector2(1672, 941)
const HIGHLIGHT_MARGIN_PIXELS := 12.0
const TOOLTIPS := {
	"map": "Tricycle: open map",
	"passengers": "Terminal: choose a passenger",
	"store": "Go to the store",
}

# Both phases share the new artwork's composition. Trace the supplied outlines
# in source pixels, then normalize for responsive hit testing and highlight UVs.
# The store entrance is now the narrow outlined area at the left image edge.
const HOTSPOT_POLYGONS := {
	"map": [
		Vector2(1672, 63), Vector2(1564, 15), Vector2(1506, 12),
		Vector2(1342, 37), Vector2(1214, 68), Vector2(1145, 90),
		Vector2(1132, 100), Vector2(1131, 120), Vector2(1143, 133),
		Vector2(1131, 167), Vector2(1144, 180), Vector2(1172, 185),
		Vector2(1166, 224), Vector2(1176, 236), Vector2(1319, 226),
		Vector2(1334, 214), Vector2(1358, 220), Vector2(1322, 334),
		Vector2(1225, 326), Vector2(1068, 322), Vector2(953, 329),
		Vector2(938, 340), Vector2(936, 365), Vector2(902, 393),
		Vector2(910, 405), Vector2(827, 588), Vector2(830, 645),
		Vector2(819, 655), Vector2(817, 669), Vector2(824, 680),
		Vector2(838, 689), Vector2(842, 716), Vector2(830, 719),
		Vector2(814, 732), Vector2(816, 781), Vector2(824, 810),
		Vector2(834, 818), Vector2(852, 823), Vector2(836, 832),
		Vector2(823, 852), Vector2(824, 866), Vector2(832, 880),
		Vector2(822, 892), Vector2(821, 907), Vector2(835, 941),
		Vector2(1672, 941),
	],
	# Follow the terminal sign, roof and waiting area. The right edge stops
	# short of the foreground tricycle; the left edge clears the store exit.
	"passengers": [
		Vector2(92, 132), Vector2(177, 151), Vector2(210, 69),
		Vector2(698, 123), Vector2(702, 191), Vector2(984, 248),
		Vector2(981, 267), Vector2(931, 278), Vector2(925, 323),
		Vector2(912, 325), Vector2(904, 368), Vector2(884, 408),
		Vector2(856, 475), Vector2(645, 490), Vector2(104, 501),
		Vector2(94, 476),
	],
	"store": [
		Vector2(59, 152), Vector2(0, 154),
		Vector2(0, 586), Vector2(64, 577),
	],
}

class HotspotButton:
	extends Button
	var polygon := PackedVector2Array()

	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point, polygon)

var buttons: Dictionary = {}
var image_rect := Rect2()
var hovered_action := ""
var focused_action := ""
var enabled := true
var is_night := false
var weather := "clear"
var weather_effects: HubWeatherEffects
var highlight_mode := InputHighlightMode.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for action: String in TOOLTIPS:
		var button := HotspotButton.new()
		button.name = action.capitalize() + "Hotspot"
		button.tooltip_text = TOOLTIPS[action]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = not enabled
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.mouse_entered.connect(func() -> void:
			if enabled:
				hovered_action = action
				queue_redraw()
		)
		button.mouse_exited.connect(func() -> void:
			if hovered_action == action:
				hovered_action = ""
			queue_redraw()
		)
		button.focus_entered.connect(func() -> void:
			if enabled:
				focused_action = action
				queue_redraw()
		)
		button.focus_exited.connect(func() -> void:
			if focused_action == action:
				focused_action = ""
			queue_redraw()
		)
		button.pressed.connect(func() -> void:
			if enabled:
				action_pressed.emit(action)
		)
		add_child(button)
		UIAudioManager.attach_button(button)
		buttons[action] = button
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	weather_effects = HubWeatherEffects.new()
	weather_effects.configure(RAIN_MARKER)
	add_child(weather_effects)
	move_child(weather_effects, 0)
	weather_effects.set_weather(weather)
	_layout()


func _input(event: InputEvent) -> void:
	if enabled and is_visible_in_tree() and highlight_mode.handle_input(event):
		queue_redraw()


func set_keyboard_navigation(value: bool) -> void:
	highlight_mode.keyboard_active = value
	queue_redraw()


func is_keyboard_navigation() -> bool:
	return highlight_mode.keyboard_active


func active_action() -> String:
	return highlight_mode.active(hovered_action, focused_action) if enabled else ""


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		for button: Button in buttons.values():
			button.release_focus()
		hovered_action = ""
		focused_action = ""
		highlight_mode.reset()
		queue_redraw()


func set_night(value: bool) -> void:
	is_night = value
	_layout()


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
			button.release_focus()
	if not value:
		hovered_action = ""
		focused_action = ""
		highlight_mode.reset()
	queue_redraw()


func polygon_for(action: String) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point: Vector2 in HOTSPOT_POLYGONS.get(action, []):
		polygon.append(point / ART_SIZE)
	return polygon


func region_rect(action: String) -> Rect2:
	var polygon := polygon_for(action)
	if polygon.is_empty():
		return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds


func _layout() -> void:
	var texture: Texture2D = NIGHT if is_night else DAY
	var ratio := minf(size.x / texture.get_width(), size.y / texture.get_height())
	image_rect = Rect2((size - texture.get_size() * ratio) * 0.5, texture.get_size() * ratio)
	for action: String in buttons:
		var button: HotspotButton = buttons[action]
		var bounds := region_rect(action)
		button.position = image_rect.position + bounds.position * image_rect.size
		button.size = bounds.size * image_rect.size
		button.polygon.clear()
		for point in polygon_for(action):
			button.polygon.append((point - bounds.position) * image_rect.size)
	if weather_effects != null:
		weather_effects.set_art_rect(image_rect)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17110b"))
	var texture: Texture2D = NIGHT if is_night else DAY
	draw_texture_rect(texture, image_rect, false, weather_effects.background_tint())
	var action := active_action()
	if not enabled or not buttons.has(action):
		return
	if action == "passengers":
		_draw_terminal_highlight()
		return
	var selected: Texture2D = NIGHT_SELECTED if is_night else DAY_SELECTED
	for polygon: PackedVector2Array in _highlight_polygons(action):
		var destination := PackedVector2Array()
		for point in polygon:
			destination.append(image_rect.position + point * image_rect.size)
		draw_polygon(destination, PackedColorArray([weather_effects.background_tint()]), polygon, selected)


func _draw_terminal_highlight() -> void:
	var outline := PackedVector2Array()
	for point in polygon_for("passengers"):
		outline.append(image_rect.position + point * image_rect.size)
	draw_colored_polygon(outline, Color(1.0, 0.88, 0.60, 0.055))
	outline.append(outline[0])
	draw_polyline(outline, Color(0.10, 0.075, 0.045, 0.60), 5.0, true)
	draw_polyline(outline, Color(1.0, 0.88, 0.60, 0.82), 2.0, true)


func _highlight_polygons(action: String) -> Array[PackedVector2Array]:
	var texture: Texture2D = NIGHT_SELECTED if is_night else DAY_SELECTED
	var pixels := PackedVector2Array()
	for point in polygon_for(action):
		pixels.append(point * texture.get_size())
	var image_bounds := PackedVector2Array([
		Vector2.ZERO, Vector2(texture.get_width(), 0),
		texture.get_size(), Vector2(0, texture.get_height()),
	])
	var polygons: Array[PackedVector2Array] = []
	# Leave room around the traced silhouette for the complete painted outline,
	# while clipping to the image so highlights cannot cover letterbox bars.
	for expanded in Geometry2D.offset_polygon(pixels, HIGHLIGHT_MARGIN_PIXELS):
		for clipped in Geometry2D.intersect_polygons(expanded, image_bounds):
			var uvs := PackedVector2Array()
			for point in clipped:
				uvs.append(point / texture.get_size())
			polygons.append(uvs)
	return polygons
