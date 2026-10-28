extends Control

# Draws only the current locked offers at their authored terminal positions.
# Offer generation, story eligibility, and departure costs stay in the coordinator.
signal offer_pressed(distance: String, slot: int)
signal offer_focused(distance: String, slot: int)
signal object_pressed(object_id: String)

const SpawnCatalog := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")
const AreaSpawnCatalog := preload("res://scripts/ride_selection/passenger_area_spawn_catalog.gd")
const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const PassengerTripCard := preload("res://scripts/ride_selection/passenger_trip_card.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HubWeatherEffects := preload("res://scripts/ui/hub_weather_effects.gd")
const RAIN_MARKER := preload("res://assets/story/backgrounds/locations/terminalrain.png")
const MARKET_RAIN_MARKER := preload("res://assets/story/backgrounds/locations/marketrain.png")
const HOVER_SCALE := 1.06
const PLACEHOLDER_AREA := Rect2(375, 710, 1030, 70)
const DAY_OBJECT_REGIONS := {
	"trashcan": Rect2(100, 440, 98, 132),
}

class PassengerButton:
	extends Button
	var source_region := Rect2()
	var texture: Texture2D
	var alpha_image: Image
	var is_placeholder := false
	var spawn_slot := -1

	func _has_point(point: Vector2) -> bool:
		if not Rect2(Vector2.ZERO, size).has_point(point):
			return false
		if is_placeholder or alpha_image == null:
			return true
		var pixel: Vector2 = point / size * Vector2(alpha_image.get_size())
		# Small gaps around a sleeve or shoe stay easy to target. Faint cast
		# shadows do not become separate clickable passengers.
		for offset_y in [-3, 0, 3]:
			for offset_x in [-3, 0, 3]:
				var sample := Vector2i(pixel) + Vector2i(offset_x, offset_y)
				if sample.x < 0 or sample.y < 0 or sample.x >= alpha_image.get_width() or sample.y >= alpha_image.get_height():
					continue
				if alpha_image.get_pixelv(sample).a >= 0.7:
					return true
		return false

var buttons: Dictionary = {}
var image_rect := Rect2()
var info_label: Label
var status_label: Label
var close_button: Button
var store_button: Button
var info_panel: PanelContainer
var enabled := true
var is_night := false
var pickup_location := "station"
var weather := "clear"
var weather_effects: HubWeatherEffects
var hovered_id := ""
var focused_id := ""
var _offers: Dictionary = {}
var _art: Dictionary = {}
var _draw_order: Array[String] = []
var _interface_built := false
var _highlight_mode := InputHighlightMode.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_interface()
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	weather_effects = HubWeatherEffects.new()
	weather_effects.configure(RAIN_MARKER)
	add_child(weather_effects)
	move_child(weather_effects, 0)
	weather_effects.set_weather(weather)
	_layout()


func _input(event: InputEvent) -> void:
	if enabled and is_visible_in_tree() and _highlight_mode.handle_input(event):
		_refresh_info()


func _gui_input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree() or is_night:
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	# Background objects have no button, hover art, tooltip, or cursor override.
	# Passenger controls receive their own clicks before this background handler.
	for object_id: String in DAY_OBJECT_REGIONS:
		if object_rect_for(object_id).has_point(event.position):
			accept_event()
			object_pressed.emit(object_id)
			return


func object_rect_for(object_id: String) -> Rect2:
	if pickup_location != "station" or is_night or not is_visible_in_tree() or not DAY_OBJECT_REGIONS.has(object_id):
		return Rect2()
	var region: Rect2 = DAY_OBJECT_REGIONS[object_id]
	return Rect2(image_rect.position + region.position / SpawnCatalog.ART_SIZE * image_rect.size, region.size / SpawnCatalog.ART_SIZE * image_rect.size)


func set_keyboard_navigation(value: bool) -> void:
	_highlight_mode.keyboard_active = value
	_refresh_info()


func set_weather(value: String) -> void:
	weather = value
	if weather_effects != null:
		weather_effects.set_weather(value)
	queue_redraw()


func is_keyboard_navigation() -> bool:
	return _highlight_mode.keyboard_active


func active_offer_id() -> String:
	return _highlight_mode.active(hovered_id, focused_id)


func get_background_texture() -> Texture2D:
	if pickup_location != "station":
		return AreaSpawnCatalog.background(pickup_location, is_night, is_night and PlayerState.is_midnight())
	return SpawnCatalog.NIGHT_BACKGROUND if is_night else SpawnCatalog.DAY_BACKGROUND


func set_pickup_location(location_id: String) -> void:
	pickup_location = location_id if location_id in ["market", "street"] else "station"
	close_button.text = "MAP"
	close_button.tooltip_text = "Open the town map"
	if weather_effects != null:
		var marker: Texture2D = RAIN_MARKER if pickup_location == "station" else (MARKET_RAIN_MARKER if pickup_location == "market" else null)
		weather_effects.configure(marker)
		weather_effects.set_weather(weather)


func set_offers(offers: Array, night: bool) -> void:
	_build_interface()
	is_night = night
	_clear_offers()
	var prepared: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var occupied_slots: Dictionary = {}
	var generic_ids: Array[String] = []
	var placeholder_count := 0
	for offer_variant in offers:
		if not offer_variant is Dictionary:
			continue
		var offer: Dictionary = offer_variant
		var character: Dictionary = offer.get("character", {})
		var character_id := str(character.get("id", ""))
		if character_id.is_empty() or seen_ids.has(character_id):
			continue
		seen_ids[character_id] = true
		var presentation: Dictionary = SpawnCatalog.midnight_entry(character_id) if str(offer.get("presentation", "")) == "midnight" else SpawnCatalog.entry(character_id, night)
		if pickup_location != "station":
			var variant := str(character.get("pickup_variant", ""))
			if bool(character.get("is_generic", false)) or character_id.begins_with("generic_"):
				presentation = AreaSpawnCatalog.generic_entry(pickup_location, variant.trim_prefix("slot_").to_int(), night)
			else:
				presentation = AreaSpawnCatalog.entry(pickup_location, character_id, night, variant)
			if presentation.is_empty():
				continue
		var record := offer.duplicate(true)
		record["character_id"] = character_id
		record["presentation"] = presentation
		prepared.append(record)
		if pickup_location == "station" and SpawnCatalog.GENERIC_IDS.has(character_id):
			generic_ids.append(character_id)
		elif pickup_location == "station" and not presentation.is_empty():
			var slot := int(SpawnCatalog.GENERIC_SLOT_BY_CHARACTER.get(character_id, -1))
			if slot >= 0:
				occupied_slots[slot] = true
	var generic_presentations := _generic_presentations(generic_ids, occupied_slots)
	for record in prepared:
		if generic_presentations.has(record.character_id):
			record.presentation = generic_presentations[record.character_id]
		if Dictionary(record.presentation).is_empty():
			placeholder_count += 1
	var placeholder_index := 0
	for record in prepared:
		var character_id: String = record.character_id
		var presentation: Dictionary = record.presentation
		var placeholder := presentation.is_empty()
		var source_region: Rect2
		var texture: Texture2D
		if placeholder:
			source_region = _placeholder_region(placeholder_index, placeholder_count)
			placeholder_index += 1
		else:
			source_region = presentation.region
			texture = presentation.texture
		_offers[character_id] = record
		_art[character_id] = {
			"region": source_region,
			"texture": texture,
			"placeholder": placeholder,
			"opacity": float(presentation.get("opacity", 1.0)),
			"slot": int(presentation.get("slot", SpawnCatalog.GENERIC_SLOT_BY_CHARACTER.get(character_id, -1))),
		}
		_draw_order.append(character_id)
		_create_passenger_button(character_id, source_region, texture, placeholder)
	_draw_order.sort_custom(func(left: String, right: String) -> bool:
		var left_region: Rect2 = _art[left].region
		var right_region: Rect2 = _art[right].region
		return left_region.end.y < right_region.end.y
	)
	# UI controls stay after passengers in GUI picking order.
	for control in [status_label, info_panel, close_button, store_button]:
		move_child(control, get_child_count() - 1)
	_layout()
	_refresh_info()


func _generic_presentations(generic_ids: Array[String], occupied_slots: Dictionary) -> Dictionary:
	var free_slots: Array[int] = []
	for slot in range(SpawnCatalog.GENERIC_ENTRIES.size()):
		if not occupied_slots.has(slot):
			free_slots.append(slot)
	var result: Dictionary = {}
	var overflow_count := 0
	# Canonical order keeps each rider's pose stable when offer order changes.
	for character_id: String in SpawnCatalog.GENERIC_IDS:
		if not generic_ids.has(character_id):
			continue
		if not free_slots.is_empty():
			var slot: int = free_slots.pop_front()
			# Choose once per day/phase without consuming gameplay randomness.
			# Each alternate keeps its own authored size and canvas position.
			var appearance_key := "%d:%s:%s" % [PlayerState.current_day, PlayerState.current_phase, character_id]
			var presentation := SpawnCatalog.generic_entry(slot, appearance_key.hash() % 2 == 0)
			presentation["slot"] = slot
			result[character_id] = presentation
		else:
			# Nine offers can outnumber the eight shared standing/seated spots.
			# This narrow pose fits left of Dante and every authored main slot.
			var presentation := SpawnCatalog.generic_entry(0)
			var region: Rect2 = presentation.region
			region.position = Vector2(28 + overflow_count * 80, 360)
			presentation["region"] = region
			presentation["slot"] = -2 - overflow_count
			result[character_id] = presentation
			overflow_count += 1
	return result


func set_enabled(value: bool) -> void:
	_build_interface()
	enabled = value
	for button: Button in buttons.values():
		button.disabled = not value
	close_button.disabled = not value
	store_button.disabled = not value
	if not value:
		_clear_focus()
	queue_redraw()


# Normalized bounds in the shared terminal image, independent of letterboxing.
func region_for(character_id: String) -> Rect2:
	if not _art.has(character_id):
		return Rect2()
	var region: Rect2 = _art[character_id].region
	return Rect2(region.position / SpawnCatalog.ART_SIZE, region.size / SpawnCatalog.ART_SIZE)


# A hover replaces the resting sprite with one larger image. Keep its feet at
# the authored ground position while growing upward and equally to both sides.
func sprite_rect_for(character_id: String, highlighted := false) -> Rect2:
	if not _art.has(character_id):
		return Rect2()
	var art: Dictionary = _art[character_id]
	var region: Rect2 = art.region
	var destination := Rect2(image_rect.position + region.position / SpawnCatalog.ART_SIZE * image_rect.size, region.size / SpawnCatalog.ART_SIZE * image_rect.size)
	if highlighted and not bool(art.placeholder):
		var growth := destination.size * (HOVER_SCALE - 1.0)
		destination.position -= Vector2(growth.x * 0.5, growth.y)
		destination.size += growth
	return destination


func focus_first_offer() -> void:
	if not enabled or not is_visible_in_tree():
		return
	for character_id: String in _draw_order:
		var button: Button = buttons[character_id]
		if not button.disabled:
			button.grab_focus()
			return
	store_button.grab_focus()


func _create_passenger_button(character_id: String, region: Rect2, texture: Texture2D, placeholder: bool) -> void:
	var button := PassengerButton.new()
	button.name = character_id.to_pascal_case() + "Passenger"
	button.source_region = region
	button.texture = texture
	button.is_placeholder = placeholder
	button.spawn_slot = int(_art[character_id].slot)
	if texture != null:
		button.alpha_image = texture.get_image()
	button.disabled = not enabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = str(_offers[character_id].get("details", ""))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.mouse_entered.connect(_on_offer_hovered.bind(character_id))
	button.mouse_exited.connect(_on_offer_unhovered.bind(character_id))
	button.focus_entered.connect(_on_offer_focused.bind(character_id))
	button.focus_exited.connect(_on_offer_unfocused.bind(character_id))
	button.pressed.connect(_on_offer_pressed.bind(character_id))
	add_child(button)
	UIAudioManager.attach_button(button)
	buttons[character_id] = button


func _on_offer_hovered(character_id: String) -> void:
	if not enabled:
		return
	hovered_id = character_id
	_emit_focus(character_id)
	_refresh_info()


func _on_offer_unhovered(character_id: String) -> void:
	if hovered_id == character_id:
		hovered_id = ""
	_refresh_info()


func _on_offer_focused(character_id: String) -> void:
	if not enabled:
		return
	focused_id = character_id
	_emit_focus(character_id)
	_refresh_info()


func _on_offer_unfocused(character_id: String) -> void:
	if focused_id == character_id:
		focused_id = ""
	_refresh_info()


func _on_offer_pressed(character_id: String) -> void:
	if not enabled or not is_visible_in_tree() or not _offers.has(character_id):
		return
	var offer: Dictionary = _offers[character_id]
	offer_pressed.emit(str(offer.get("distance", "short")), int(offer.get("slot", -1)))


func _emit_focus(character_id: String) -> void:
	var offer: Dictionary = _offers[character_id]
	offer_focused.emit(str(offer.get("distance", "short")), int(offer.get("slot", -1)))


func _refresh_info() -> void:
	var character_id := active_offer_id()
	var show_info := enabled and _offers.has(character_id)
	info_panel.visible = show_info
	var summary: Dictionary = {}
	if show_info:
		var offer: Dictionary = _offers[character_id]
		summary = offer.get("summary", {
			"name": str(offer.get("details", "")),
			"distance": str(offer.get("distance", "")).capitalize(),
		})
	info_panel.set_summary(summary)
	call_deferred("_layout_information")
	queue_redraw()


func _clear_offers() -> void:
	_clear_focus()
	for button: Button in buttons.values():
		remove_child(button)
		button.queue_free()
	buttons.clear()
	_offers.clear()
	_art.clear()
	_draw_order.clear()


func _clear_focus() -> void:
	for button: Button in buttons.values():
		button.release_focus()
	if close_button != null:
		close_button.release_focus()
	if store_button != null:
		store_button.release_focus()
	hovered_id = ""
	focused_id = ""
	_highlight_mode.reset()
	if info_panel != null:
		info_panel.hide()
		info_panel.set_summary({})


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_focus()
		queue_redraw()


func _build_interface() -> void:
	if _interface_built:
		return
	_interface_built = true
	status_label = _label(10)
	status_label.name = "TerminalStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	info_panel = PassengerTripCard.new()
	info_panel.name = "PassengerInformation"
	add_child(info_panel)
	info_panel.set_summary({})
	info_label = info_panel.route_label
	info_panel.hide()
	close_button = _button("MAP")
	close_button.name = "PassengerMap"
	close_button.tooltip_text = "Open the town map"
	add_child(close_button)
	store_button = _button("STORE")
	store_button.name = "TerminalStore"
	store_button.tooltip_text = "Store: stress relief, hull repairs, upgrades and gas"
	add_child(store_button)
	UIAudioManager.attach_button(close_button)
	UIAudioManager.attach_button(store_button)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("faefd5"))
	label.add_theme_color_override("font_outline_color", Color("181008"))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	DashboardTheme.apply_button(button)
	return button


func _placeholder_region(index: int, count: int) -> Rect2:
	var gap := 22.0
	var width := minf(110.0, (PLACEHOLDER_AREA.size.x - gap * (count - 1)) / maxf(1.0, count))
	var group_width := width * count + gap * (count - 1)
	return Rect2(
		Vector2(PLACEHOLDER_AREA.position.x + (PLACEHOLDER_AREA.size.x - group_width) * 0.5 + index * (width + gap), PLACEHOLDER_AREA.position.y),
		Vector2(width, PLACEHOLDER_AREA.size.y)
	)


func _layout() -> void:
	if not _interface_built:
		return
	var ratio := minf(size.x / SpawnCatalog.ART_SIZE.x, size.y / SpawnCatalog.ART_SIZE.y)
	image_rect = Rect2((size - SpawnCatalog.ART_SIZE * ratio) * 0.5, SpawnCatalog.ART_SIZE * ratio)
	for character_id: String in buttons:
		var button: PassengerButton = buttons[character_id]
		button.position = image_rect.position + button.source_region.position * ratio
		button.size = button.source_region.size * ratio
	var navigation := DashboardTheme.layout_button_row([close_button, store_button], size)
	var status_left := navigation.end.x + 16.0
	status_label.position = Vector2(status_left, size.y - 52)
	status_label.size = Vector2(maxf(0.0, size.x - status_left - 24.0), 40)
	if status_label.size.x < 200.0:
		status_label.position = Vector2(24, navigation.position.y - 48.0)
		status_label.size = Vector2(maxf(0.0, size.x - 48.0), 40)
	_layout_information()
	if weather_effects != null:
		weather_effects.set_art_rect(image_rect)
	queue_redraw()


func _layout_information() -> void:
	if info_panel == null:
		return
	var minimum := info_panel.get_combined_minimum_size()
	var available_width := maxf(1.0, size.x - 40.0)
	var width := maxf(minimum.x, minf(image_rect.size.x * 1000.0 / SpawnCatalog.ART_SIZE.x, available_width))
	var height := maxf(150.0, minimum.y)
	var top := HubStatusHeader.CONTENT_TOP + 24.0
	# Keep the preview above both the status strip and horizontal navigation.
	var bottom := minf(image_rect.end.y - 16.0, minf(status_label.position.y - 12.0, close_button.position.y - 12.0))
	var available_height := maxf(1.0, bottom - top)
	var fit := minf(1.0, minf(available_width / width, available_height / height))
	var left := (size.x - width * fit) * 0.5
	info_panel.size = Vector2(width, height)
	info_panel.scale = Vector2.ONE * fit
	info_panel.position = Vector2(
		left,
		bottom - height * fit,
	)
	status_label.show()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17110b"))
	var background := get_background_texture()
	draw_texture_rect(background, image_rect, false, weather_effects.background_tint())
	var selected_id := active_offer_id()
	for character_id: String in _draw_order:
		if enabled and selected_id == character_id:
			continue
		_draw_passenger(character_id, false)
	# Promote hover/focus art above every normal sprite, regardless of foot depth.
	# Draw it only once so translucent edges and shadows keep their original alpha.
	if enabled and _art.has(selected_id):
		_draw_passenger(selected_id, true)


func _draw_passenger(character_id: String, highlighted: bool) -> void:
	var art: Dictionary = _art[character_id]
	var destination := sprite_rect_for(character_id, highlighted)
	if bool(art.placeholder):
		var color := Color("ffe0a1") if highlighted else Color(0.91, 0.84, 0.68, 0.75)
		draw_rect(destination, Color(0.06, 0.04, 0.025, 0.20), true)
		draw_rect(destination, color, false, 2.0 if highlighted else 1.0)
		return
	var texture: Texture2D = art.texture
	var tint := Color(1.12, 1.12, 1.06) if highlighted else Color.WHITE
	tint.a = float(art.opacity)
	draw_texture_rect(texture, destination, false, tint)
