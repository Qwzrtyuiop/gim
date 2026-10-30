extends Control

signal location_selected(location_id: String)
signal closed

const Catalog := preload("res://scripts/map/topdown_map_catalog.gd")
const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const HubWeatherEffects := preload("res://scripts/ui/hub_weather_effects.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const STRESS_ICON := preload("res://assets/ui/icons/stress_brain.png")

var buttons: Dictionary = {}
var image_rect := Rect2()
var current_location := "home"
var map_region := "town"
var is_night := false
var enabled := true
var hovered_location := ""
var focused_location := ""
var back_button: Button
var info_panel: PanelContainer
var info_label: Label
var highlight_mode := InputHighlightMode.new()
var weather_effects: HubWeatherEffects
var travel_cost_provider: Callable
var energy_cursor: HBoxContainer
var energy_cursor_label: Label
var energy_cursor_icon: TextureRect
var stress_cursor: HBoxContainer
var stress_cursor_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weather_effects = HubWeatherEffects.new()
	weather_effects.configure(null)
	add_child(weather_effects)
	weather_effects.set_weather(PlayerState.current_weather)
	var all_regions: Dictionary = Catalog.REGIONS.duplicate()
	all_regions.merge(Catalog.NORTH_REGIONS)
	for location_id: String in all_regions:
		var button := Button.new()
		button.name = location_id.to_pascal_case() + "MapLocation"
		button.tooltip_text = Catalog.NAMES[location_id]
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if Catalog.is_locked(location_id) and location_id != "hospital" else Control.CURSOR_POINTING_HAND
		button.disabled = not enabled
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.mouse_entered.connect(_on_hovered.bind(location_id))
		button.mouse_exited.connect(_on_unhovered.bind(location_id))
		button.focus_entered.connect(_on_focused.bind(location_id))
		button.focus_exited.connect(_on_unfocused.bind(location_id))
		button.pressed.connect(_on_location_pressed.bind(location_id))
		add_child(button)
		UIAudioManager.attach_button(button)
		buttons[location_id] = button
	info_panel = _text_panel("", 11)
	info_label = info_panel.get_child(0) as Label
	add_child(info_panel)
	back_button = Button.new()
	back_button.name = "MapBackButton"
	back_button.text = "BACK"
	back_button.disabled = not enabled
	DashboardTheme.apply_button(back_button)
	back_button.pressed.connect(_close)
	add_child(back_button)
	UIAudioManager.attach_button(back_button)
	_build_energy_cursor()
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_info()
	_sync_region_buttons()
	_layout()


func _process(_delta: float) -> void:
	var cost := travel_energy_cost(hovered_location)
	var relief := _visit_stress_relief(hovered_location)
	energy_cursor.visible = enabled and is_visible_in_tree() and not highlight_mode.keyboard_active and not hovered_location.is_empty() and not Catalog.is_locked(hovered_location) and (cost > 0 or relief > 0)
	if not energy_cursor.visible:
		return
	energy_cursor_label.text = "-%d" % cost
	energy_cursor_label.visible = cost > 0
	energy_cursor_icon.visible = cost > 0
	stress_cursor.visible = relief > 0
	stress_cursor_label.text = "+%d" % relief
	energy_cursor.size = energy_cursor.get_combined_minimum_size()
	var cursor_at := get_local_mouse_position() + Vector2(18, 22)
	energy_cursor.position = cursor_at.clamp(Vector2(4, 4), (size - energy_cursor.size - Vector2(4, 4)).max(Vector2(4, 4)))


func travel_energy_cost(location_id: String) -> int:
	if not _regions().has(location_id) or not travel_cost_provider.is_valid():
		return 0
	return maxi(0, int(travel_cost_provider.call(location_id)))


func _visit_stress_relief(location_id: String) -> int:
	if location_id == current_location or not _regions().has(location_id) or Catalog.is_locked(location_id):
		return 0
	if PlayerState.has_visited_location_today(location_id):
		return 0
	if location_id == "park":
		return GameTuning.PARK_STRESS_RELIEF
	if location_id == "church":
		if PlayerState.get_current_time_of_day() == "night":
			return 0
		return PlayerState.get_church_stress_relief()
	return 0


func _build_energy_cursor() -> void:
	energy_cursor = HBoxContainer.new()
	energy_cursor.name = "TravelEnergyCursor"
	energy_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_cursor.z_index = 30
	energy_cursor.add_theme_constant_override("separation", 3)
	energy_cursor_label = Label.new()
	energy_cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_cursor_label.add_theme_font_override("font", FONT)
	energy_cursor_label.add_theme_font_size_override("font_size", 14)
	energy_cursor_label.add_theme_color_override("font_color", Color("ffe28a"))
	energy_cursor_label.add_theme_color_override("font_outline_color", Color("201409"))
	energy_cursor_label.add_theme_constant_override("outline_size", 3)
	energy_cursor.add_child(energy_cursor_label)
	energy_cursor_icon = TextureRect.new()
	energy_cursor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	energy_cursor_icon.texture = ENERGY_ICON
	energy_cursor_icon.custom_minimum_size = Vector2(22, 26)
	energy_cursor_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	energy_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_cursor.add_child(energy_cursor_icon)
	stress_cursor = HBoxContainer.new()
	stress_cursor.name = "VisitStressBenefit"
	stress_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stress_cursor.add_theme_constant_override("separation", 3)
	energy_cursor.add_child(stress_cursor)
	stress_cursor_label = energy_cursor_label.duplicate() as Label
	stress_cursor_label.add_theme_color_override("font_color", Color("f2b4cc"))
	stress_cursor.add_child(stress_cursor_label)
	var stress_icon := TextureRect.new()
	stress_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stress_icon.texture = STRESS_ICON
	stress_icon.custom_minimum_size = Vector2(24, 26)
	stress_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stress_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stress_cursor.add_child(stress_icon)
	stress_cursor.hide()
	add_child(energy_cursor)
	energy_cursor.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or not enabled or not is_visible_in_tree():
		return
	if highlight_mode.handle_input(event):
		_refresh_info()


func set_current_location(location_id: String) -> void:
	current_location = location_id
	_refresh_info()


func set_enabled(value: bool) -> void:
	enabled = value
	_sync_region_buttons()
	if back_button != null:
		back_button.disabled = not value
	if not value:
		_clear_focus()
		if energy_cursor != null:
			energy_cursor.hide()
	_refresh_info()


func get_background_texture() -> Texture2D:
	if map_region == "north":
		return Catalog.NORTH_NIGHT_BACKGROUND if is_night else Catalog.NORTH_BACKGROUND
	return Catalog.NIGHT_BACKGROUND if is_night else Catalog.BACKGROUND


func set_map_region(value: String) -> void:
	map_region = "north" if value == "north" else "town"
	if not is_node_ready():
		return
	_clear_focus()
	_sync_region_buttons()
	_layout()
	_refresh_info()
	if back_button != null and is_visible_in_tree():
		back_button.grab_focus()


func set_night(value: bool) -> void:
	is_night = value
	if is_node_ready():
		_layout()


func set_weather(value: String) -> void:
	weather_effects.set_weather(value)
	queue_redraw()


func active_location() -> String:
	return highlight_mode.active(hovered_location, focused_location) if enabled else ""


func region_for(location_id: String) -> Rect2:
	var regions := _regions()
	if not regions.has(location_id):
		return Rect2()
	var source: Rect2 = regions[location_id]
	var guide_size: Vector2 = Catalog.NORTH_ART_SIZE if map_region == "north" else Catalog.ART_SIZE
	return Rect2(image_rect.position + source.position / guide_size * image_rect.size, source.size / guide_size * image_rect.size)


func _regions() -> Dictionary:
	return Catalog.NORTH_REGIONS if map_region == "north" else Catalog.REGIONS


func _sync_region_buttons() -> void:
	var regions := _regions()
	for location_id: String in buttons:
		var active := regions.has(location_id)
		var locked := Catalog.is_locked(location_id)
		buttons[location_id].visible = active
		buttons[location_id].disabled = not enabled or not active
		buttons[location_id].mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked and location_id != "hospital" else Control.CURSOR_POINTING_HAND


func _layout() -> void:
	var art_size := get_background_texture().get_size()
	var ratio := minf(size.x / art_size.x, size.y / art_size.y)
	image_rect = Rect2((size - art_size * ratio) * 0.5, art_size * ratio)
	weather_effects.set_art_rect(image_rect)
	for location_id: String in buttons:
		var region := region_for(location_id)
		buttons[location_id].position = region.position
		buttons[location_id].size = region.size
	if info_panel != null:
		var panel_height := 76.0 if _visit_stress_relief(active_location()) > 0 else 54.0
		info_panel.size = Vector2(minf(600, maxf(180, size.x - 40)), panel_height)
		info_panel.position = Vector2((size.x - info_panel.size.x) * 0.5, size.y - panel_height - 22)
		if size.x < 1000:
			info_panel.position.y -= DashboardTheme.BUTTON_SIZE.y + 12
	if back_button != null:
		back_button.position = Vector2(20, size.y - DashboardTheme.BUTTON_SIZE.y - 16)
		back_button.size = DashboardTheme.BUTTON_SIZE
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17110b"))
	draw_texture_rect(get_background_texture(), image_rect, false, weather_effects.background_tint())
	var active := active_location()
	var regions := _regions()
	if regions.has(current_location) and current_location != active:
		draw_rect(region_for(current_location), Color(0.95, 0.87, 0.56, 0.65), false, 1.5)
	if not regions.has(active):
		return
	var region := region_for(active)
	var color := Color("edb773") if Catalog.is_locked(active) else Color("ffe28a")
	var fill := color
	fill.a = 0.16
	draw_rect(region, fill)
	draw_rect(region.grow(2), Color(0.13, 0.08, 0.03, 0.8), false, 5)
	draw_rect(region, color, false, 3)


func _refresh_info() -> void:
	if info_label != null:
		var active := active_location()
		if not Catalog.NAMES.has(active):
			info_label.text = "Hover a location to travel"
		elif Catalog.is_locked(active):
			info_label.text = "HOSPITAL" if active == "hospital" else "NOT YET UNLOCKED"
		elif active != current_location and PlayerState.has_visited_location_today(active):
			info_label.text = str(Catalog.NAMES[active]).to_upper() + "\nAlready visited today"
		else:
			var cost := travel_energy_cost(active)
			var instruction := "Click to travel (-%d energy)" % cost if cost > 0 else "Click to travel"
			var relief := _visit_stress_relief(active)
			if relief > 0:
				instruction += "\nReduce stress by %d" % relief
			info_label.text = str(Catalog.NAMES[active]).to_upper() + ("\nYou are here" if active == current_location else "\n" + instruction)
		_layout()
	queue_redraw()


func _on_hovered(location_id: String) -> void:
	if enabled:
		hovered_location = location_id
		_refresh_info()


func _on_unhovered(location_id: String) -> void:
	if hovered_location == location_id:
		hovered_location = ""
	_refresh_info()


func _on_focused(location_id: String) -> void:
	if enabled:
		focused_location = location_id
		_refresh_info()


func _on_unfocused(location_id: String) -> void:
	if focused_location == location_id:
		focused_location = ""
	_refresh_info()


func _on_location_pressed(location_id: String) -> void:
	if enabled and is_visible_in_tree() and _regions().has(location_id) and (location_id == "hospital" or not Catalog.is_locked(location_id)):
		if map_region == "north" and location_id == "town":
			set_map_region("town")
			return
		location_selected.emit(location_id)


func _close() -> void:
	if enabled and is_visible_in_tree():
		if map_region == "north":
			set_map_region("town")
			return
		closed.emit()


func _clear_focus() -> void:
	for button: Button in buttons.values():
		button.release_focus()
	if back_button != null:
		back_button.release_focus()
	hovered_location = ""
	focused_location = ""
	highlight_mode.reset()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_focus()
		_refresh_info()


static func _text_panel(text: String, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.055, 0.035, 0.9)
	style.border_color = Color("a18b60")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ffe3ac"))
	panel.add_child(label)
	return panel
