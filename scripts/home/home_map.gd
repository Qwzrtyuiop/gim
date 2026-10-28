extends Control

# Prototype travel stays scene-local until these locations have gameplay hubs.
# Only departures to existing hubs change scenes; browsing never advances time.
signal closed
signal destination_requested(scene_path: String)
signal bar_music_changed
signal bar_character_interacted(character_id: String)
signal hospital_character_interacted(character_id: String)
signal park_character_interacted(character_id: String)

const MapView := preload("res://scripts/map/topdown_map_view.gd")
const MapCatalog := preload("res://scripts/map/topdown_map_catalog.gd")
const TravelConfirmation := preload("res://scripts/home/map_travel_confirmation.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const BackgroundWeather := preload("res://scripts/story/story_background_weather.gd")
const BarAlmaSpawn := preload("res://scripts/home/bar_alma_spawn.gd")
const BarCharacters := preload("res://scripts/home/bar_characters.gd")
const BarAudio := preload("res://scripts/home/bar_audio.gd")
const BarShop := preload("res://scripts/store/bar_shop.gd")
const HospitalCelinaSpawn := preload("res://scripts/home/hospital_celina_spawn.gd")
const HospitalCharacters := preload("res://scripts/home/hospital_characters.gd")
const HospitalAudio := preload("res://scripts/home/hospital_audio.gd")
const HospitalEncounter := preload("res://scripts/home/hospital_encounter.gd")
const HospitalShop := preload("res://scripts/store/hospital_shop.gd")
const LOCATIONS := "res://assets/story/backgrounds/locations/"
const HOME_SCENE := "res://scenes/day_start_scene.tscn"
const STATION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const BAR_ENTRANCE := Rect2(185, 12, 1275, 815)
const BAR_CLOSED_MESSAGE := "It's closed. I should try again later."
const HOSPITAL_LOCKED_MESSAGE := "I don't really have a reason to go there.."
const NORTH_ROAD_UNLOCK_DAY := 8
const FREE_TRAVEL_LOCATIONS := ["home", "station", "store", "market", "street"]
const NORTH_ROAD_CLOSED_MESSAGE := "There's road construction ahead. I can't get through. It'll take about a week or so. I should check again later."
const BACKGROUNDS := {
	"market": ["market.png", "marketnight.png"],
	"street": ["passengerstreetday.png", "passengerstreetnight.png", "passengerstreetmidnight.png"],
	"park": ["park.png", "parknight.png"],
	"hospital": ["hospitalday.png", "hospitalnight.png"],
	"bar": ["barnight.png", "barnight.png"],
}

var map_view: MapView
var location_view: Control
var background: TextureRect
var bar_characters: BarCharacters
var celina_spawn: HospitalCelinaSpawn
var hospital_characters: HospitalCharacters
var hospital_audio: HospitalAudio
# Keep the scene's public node references for callers that inspect the bar cast.
var alma_spawn: BarAlmaSpawn
var benny_spawn: TextureButton
var bar_audio: BarAudio
var status_header: HubStatusHeader
var map_button: Button
var store_button: Button
var entrance_button: Button
var exit_button: Button
var shop_button: Button
var bar_shop: BarShop
var hospital_shop: HospitalShop
var hub_dialogue: HubDialogue
var origin_location := "home"
var current_location := "home"
var inside_bar := false
var entrance_highlight_mode := InputHighlightMode.new()
var entrance_focus_style: StyleBoxFlat
var travel_confirmation: TravelConfirmation
var _pending_destination := ""
var _shop_disabled_controls: Dictionary = {}
var _suppress_shop_closing_dialogue := false


func _ready() -> void:
	name = "HomeMap"
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_view = MapView.new()
	map_view.travel_cost_provider = travel_energy_cost
	add_child(map_view)
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.location_selected.connect(_request_visit)
	map_view.closed.connect(_close)
	_build_location_view()
	travel_confirmation = TravelConfirmation.new()
	add_child(travel_confirmation)
	travel_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_confirmation.confirmed.connect(_confirm_travel)
	travel_confirmation.cancelled.connect(_cancel_travel)
	bar_audio = BarAudio.new()
	add_child(bar_audio)
	bar_audio.active_changed.connect(bar_music_changed.emit)
	hospital_audio = HospitalAudio.new()
	add_child(hospital_audio)
	resized.connect(_layout)
	_layout()
	hide()
	map_view.set_enabled(false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not location_view.visible:
		return
	if bar_shop.visible:
		if bar_shop.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if hospital_shop.visible:
		if hospital_shop.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if hub_dialogue.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if entrance_highlight_mode.handle_input(event):
		_update_entrance_focus()
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			if inside_bar:
				_exit_bar()
			else:
				_show_map()


func open(origin: String = "home") -> void:
	origin_location = origin if origin in ["home", "station", "store"] else "home"
	current_location = "market" if origin_location == "store" else origin_location
	if origin_location == "station":
		var pickup: String = PlayerState.get_pending_pickup_location()
		if pickup in ["market", "street"]:
			current_location = pickup
	map_view.set_map_region("town")
	map_view.set_night(PlayerState.get_current_time_of_day() == "night")
	show()
	_show_map()


func _show_map() -> void:
	_close_bar_shop()
	_close_hospital_shop()
	_dismiss_travel_confirmation()
	_set_bar_active(false)
	_set_hospital_active(false)
	AmbientAudioManager.set_rain_indoors(false)
	hub_dialogue.clear()
	entrance_highlight_mode.reset()
	_update_entrance_focus()
	inside_bar = false
	shop_button.hide()
	location_view.hide()
	background.texture = null
	BackgroundWeather.apply(background)
	for button in [map_button, store_button, entrance_button, exit_button, shop_button]:
		button.release_focus()
	map_view.set_current_location(current_location)
	map_view.set_weather(PlayerState.current_weather)
	map_view.show()
	map_view.set_enabled(true)
	map_view.back_button.grab_focus()


func travel_energy_cost(location_id: String) -> int:
	if location_id == current_location or location_id in FREE_TRAVEL_LOCATIONS or location_id in ["north", "town"] or MapCatalog.is_locked(location_id):
		return 0
	if location_id == "bar" and PlayerState.get_current_time_of_day() != "night":
		return 0
	var north_destination := map_view != null and map_view.map_region == "north" and MapCatalog.NORTH_REGIONS.has(location_id)
	if not BACKGROUNDS.has(location_id) and not north_destination:
		return 0
	return GameTuning.MAP_TRAVEL_ENERGY_COST


func _request_visit(location_id: String) -> void:
	if not is_visible_in_tree() or not map_view.visible or not map_view.enabled or not _pending_destination.is_empty():
		return
	var cost := travel_energy_cost(location_id)
	if cost <= 0 or PlayerState.energy < cost:
		_visit(location_id)
		return
	_pending_destination = location_id
	hub_dialogue.clear()
	map_view.set_enabled(false)
	travel_confirmation.present(str(MapCatalog.NAMES.get(location_id, location_id.capitalize())), cost)


func _confirm_travel() -> void:
	if _pending_destination.is_empty() or not is_visible_in_tree() or not map_view.visible:
		return
	var destination := _pending_destination
	_dismiss_travel_confirmation()
	map_view.set_enabled(true)
	_visit(destination)


func _cancel_travel() -> void:
	var destination := _pending_destination
	_dismiss_travel_confirmation()
	if not is_visible_in_tree() or not map_view.visible:
		return
	map_view.set_enabled(true)
	if map_view.buttons.has(destination):
		map_view.buttons[destination].grab_focus()
	else:
		map_view.back_button.grab_focus()


func _dismiss_travel_confirmation() -> void:
	_pending_destination = ""
	if travel_confirmation != null:
		travel_confirmation.dismiss()


func _visit(location_id: String) -> void:
	if MapCatalog.is_locked(location_id):
		if location_id == "hospital":
			_show_location_message(HOSPITAL_LOCKED_MESSAGE, "map_hospital")
		return
	_close_bar_shop()
	_close_hospital_shop()
	if location_id == "north":
		if PlayerState.get_current_day() < NORTH_ROAD_UNLOCK_DAY:
			hub_dialogue.say(NORTH_ROAD_CLOSED_MESSAGE, {
				"speaker": "John Toda",
				"target": "map_north",
				"show_tail": false,
				"duration": 6.0,
				"width": 480,
				"blocking": false,
			})
			return
		hub_dialogue.clear()
		map_view.set_map_region("north")
		return
	if location_id == "town":
		hub_dialogue.clear()
		map_view.set_map_region("town")
		return
	if location_id == "bar" and PlayerState.get_current_time_of_day() != "night":
		_show_bar_closed("map_bar")
		return
	if location_id == "home":
		if origin_location == "home":
			_close()
		else:
			_depart(HOME_SCENE)
		return
	if location_id == "station":
		var previous_pickup: String = PlayerState.get_pending_pickup_location()
		PlayerState.set_pending_pickup_location("station")
		if origin_location == "station" and previous_pickup == "station":
			_close()
		else:
			_depart(STATION_SCENE)
		return
	if location_id in ["market", "street"]:
		PlayerState.set_pending_pickup_location(location_id)
		_depart(STATION_SCENE)
		return
	var north_destination := map_view.map_region == "north" and MapCatalog.NORTH_REGIONS.has(location_id)
	if not BACKGROUNDS.has(location_id) and not north_destination:
		return
	var energy_cost := travel_energy_cost(location_id)
	if energy_cost > 0:
		PlayerState._begin_state_batch()
		if not PlayerState.spend_energy(energy_cost):
			PlayerState._end_state_batch()
			if map_view.buttons.has(location_id):
				hub_dialogue.register_control("map_destination", map_view.buttons[location_id])
			hub_dialogue.say("I'm too tired to go there. I should head home and rest.", {
				"speaker": "John Toda",
				"target": "map_destination",
				"show_tail": false,
				"duration": 4.0,
				"blocking": false,
			})
			return
		if location_id == "park":
			PlayerState.relieve_stress(GameTuning.PARK_STRESS_RELIEF)
		PlayerState._end_state_batch()
	current_location = location_id
	_set_bar_active(false)
	_set_hospital_active(false)
	entrance_highlight_mode.reset()
	_update_entrance_focus()
	inside_bar = false
	hub_dialogue.clear()
	map_view.set_enabled(false)
	map_view.hide()
	var night: bool = PlayerState.get_current_time_of_day() == "night"
	if north_destination:
		# Use the authored map area until this destination has its own background.
		var map_texture: Texture2D = map_view.get_background_texture()
		var source: Rect2 = MapCatalog.NORTH_REGIONS[location_id]
		var destination := AtlasTexture.new()
		destination.atlas = map_texture
		destination.region = Rect2(source.position / MapCatalog.NORTH_ART_SIZE * map_texture.get_size(), source.size / MapCatalog.NORTH_ART_SIZE * map_texture.get_size())
		destination.filter_clip = true
		background.texture = destination
	else:
		var art: Array = BACKGROUNDS[location_id]
		var phase_index := 2 if night and PlayerState.is_midnight() and art.size() > 2 else (1 if night else 0)
		background.texture = load(LOCATIONS + str(art[phase_index])) as Texture2D
	BackgroundWeather.apply(background, north_destination)
	_refresh_rain_environment()
	entrance_button.visible = location_id == "bar"
	exit_button.hide()
	shop_button.hide()
	store_button.visible = location_id == "market"
	status_header.refresh()
	location_view.show()
	_set_hospital_active(location_id == "hospital")
	map_button.grab_focus()
	_layout()


func _depart(scene_path: String) -> void:
	_close_bar_shop()
	_close_hospital_shop()
	_dismiss_travel_confirmation()
	_set_bar_active(false)
	_set_hospital_active(false)
	hub_dialogue.clear()
	map_view.set_enabled(false)
	for button in [map_button, store_button, entrance_button, exit_button, shop_button]:
		button.disabled = true
	destination_requested.emit(scene_path)


func _close() -> void:
	_close_bar_shop()
	_close_hospital_shop()
	_dismiss_travel_confirmation()
	_set_bar_active(false)
	_set_hospital_active(false)
	AmbientAudioManager.set_rain_indoors(origin_location == "home")
	hub_dialogue.clear()
	map_view.set_enabled(false)
	background.texture = null
	BackgroundWeather.apply(background)
	hide()
	closed.emit()


func _enter_bar() -> void:
	if current_location != "bar" or inside_bar or not location_view.is_visible_in_tree():
		return
	if PlayerState.get_current_time_of_day() != "night":
		_show_bar_closed("entrance")
		return
	hub_dialogue.clear()
	inside_bar = true
	background.texture = load(LOCATIONS + "bar.png") as Texture2D
	BackgroundWeather.apply(background)
	_set_bar_active(true)
	_refresh_rain_environment()
	entrance_button.release_focus()
	entrance_button.hide()
	exit_button.show()
	shop_button.show()
	exit_button.grab_focus()
	_layout()


func _show_bar_closed(target: String) -> void:
	_show_location_message(BAR_CLOSED_MESSAGE, target)


func _show_location_message(message: String, target: String) -> void:
	hub_dialogue.say(message, {
		"speaker": "John Toda",
		"target": target,
		"show_tail": false,
		"duration": 3.5,
		"blocking": false,
	})


func _exit_bar() -> void:
	if not inside_bar:
		return
	_close_bar_shop()
	_set_bar_active(false)
	hub_dialogue.clear()
	inside_bar = false
	background.texture = load(LOCATIONS + "barnight.png") as Texture2D
	BackgroundWeather.apply(background)
	_refresh_rain_environment()
	exit_button.release_focus()
	exit_button.hide()
	shop_button.hide()
	entrance_button.show()
	map_button.grab_focus()
	_layout()


func _can_open_bar_shop() -> bool:
	return is_visible_in_tree() and location_view.visible and current_location == "bar" and inside_bar and PlayerState.get_current_time_of_day() == "night" and not hub_dialogue.blocks_input() and not hospital_shop.visible


func _open_bar_shop() -> void:
	if not _can_open_bar_shop() or bar_shop.visible:
		return
	hub_dialogue.clear()
	if not bar_shop.open():
		return
	_lock_shop_controls()
	bar_characters.set_interaction_enabled(false)


func _lock_shop_controls() -> void:
	_shop_disabled_controls.clear()
	for button: BaseButton in [map_button, store_button, entrance_button, exit_button, shop_button]:
		_shop_disabled_controls[button] = button.disabled
		button.disabled = true


func _close_bar_shop() -> void:
	if bar_shop != null:
		_suppress_shop_closing_dialogue = true
		bar_shop.close()
		_suppress_shop_closing_dialogue = false


func _on_bar_shop_closed() -> void:
	_restore_shop_controls()
	bar_characters.set_interaction_enabled(true)
	if inside_bar and location_view.is_visible_in_tree() and shop_button.visible:
		shop_button.grab_focus()
		if not _suppress_shop_closing_dialogue:
			bar_characters.say_shop_closing_line()


func _restore_shop_controls() -> void:
	for button: BaseButton in _shop_disabled_controls:
		if is_instance_valid(button):
			button.disabled = bool(_shop_disabled_controls[button])
	_shop_disabled_controls.clear()


func _can_open_hospital_shop() -> bool:
	return is_visible_in_tree() and location_view.visible and not map_view.visible and current_location == "hospital" and not bar_shop.visible and not hub_dialogue.blocks_input() and bool(PlayerState.get_event_value("celina_hospital_shop_unlocked", false))


func _open_hospital_shop() -> void:
	if not _can_open_hospital_shop() or hospital_shop.visible:
		return
	hub_dialogue.clear()
	if not hospital_shop.open():
		return
	_lock_shop_controls()
	celina_spawn.disabled = true


func _close_hospital_shop() -> void:
	if hospital_shop != null:
		hospital_shop.close()


func _on_hospital_shop_closed() -> void:
	_restore_shop_controls()
	celina_spawn.disabled = not celina_spawn.active
	if location_view.is_visible_in_tree() and current_location == "hospital":
		celina_spawn.grab_focus()


func _handle_hospital_celina_click(character_id: String) -> bool:
	if current_location != "hospital" or not is_visible_in_tree() or not location_view.visible or map_view.visible or hospital_shop.visible or bar_shop.visible:
		return true
	if HospitalEncounter.can_start():
		_on_hospital_character_interacted(character_id)
		hub_dialogue.clear()
		if HospitalEncounter.start():
			_depart(HospitalEncounter.STORY_SCENE)
		return true
	if bool(PlayerState.get_event_value("celina_hospital_shop_unlocked", false)):
		_on_hospital_character_interacted(character_id)
		_open_hospital_shop()
		return true
	return false


func restore_hospital_after_story() -> void:
	# The trip to the hospital was already paid before the story began.
	current_location = "hospital"
	_visit("hospital")


func _on_bar_character_interacted(character_id: String) -> void:
	if character_id == "alma" and alma_spawn.active and alma_spawn.is_visible_in_tree():
		_relieve_character_stress("bar", character_id)
	elif character_id == "benny" and benny_spawn.is_visible_in_tree() and not benny_spawn.disabled:
		_relieve_character_stress("bar", character_id)
	bar_character_interacted.emit(character_id)


func _on_hospital_character_interacted(character_id: String) -> void:
	if character_id == "cel" and celina_spawn.active and celina_spawn.is_visible_in_tree():
		_relieve_character_stress("hospital", character_id)
	hospital_character_interacted.emit(character_id)


# Connect future authored Park character controls here when their art is added.
func _on_park_character_interacted(character_id: String) -> void:
	_relieve_character_stress("park", character_id)
	park_character_interacted.emit(character_id)


func _relieve_character_stress(location_id: String, character_id: String) -> int:
	if not is_visible_in_tree() or not location_view.visible or map_view.visible or current_location != location_id:
		return 0
	if bar_shop.visible or hospital_shop.visible or hub_dialogue.blocks_input() or (location_id == "bar" and not inside_bar):
		return 0
	return PlayerState.relieve_character_interaction(location_id, character_id)


func _set_bar_active(value: bool) -> void:
	bar_characters.set_active(value)
	bar_audio.set_active(value)


func _set_hospital_active(value: bool) -> void:
	hospital_characters.set_active(value, PlayerState.get_current_time_of_day() != "night")
	hospital_audio.set_active(value)


func _refresh_rain_environment() -> void:
	AmbientAudioManager.set_rain_indoors(BackgroundWeather.is_indoor_background(background.texture))


func _update_entrance_focus() -> void:
	entrance_button.add_theme_stylebox_override("focus", entrance_focus_style if entrance_highlight_mode.keyboard_active else StyleBoxEmpty.new())


func _build_location_view() -> void:
	location_view = Control.new()
	add_child(location_view)
	location_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("17110b")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_view.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background = TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_view.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_characters = BarCharacters.new()
	add_child(bar_characters)
	bar_characters.setup(background)
	bar_characters.interacted.connect(_on_bar_character_interacted)
	alma_spawn = bar_characters.alma_spawn
	benny_spawn = bar_characters.benny_spawn
	hospital_characters = HospitalCharacters.new()
	add_child(hospital_characters)
	hospital_characters.setup(background)
	hospital_characters.interacted.connect(_on_hospital_character_interacted)
	celina_spawn = hospital_characters.celina_spawn
	celina_spawn.interaction_override = _handle_hospital_celina_click
	entrance_button = Button.new()
	entrance_button.name = "BarEntrance"
	entrance_button.tooltip_text = "Enter"
	entrance_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	entrance_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	entrance_button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	entrance_focus_style = StyleBoxFlat.new()
	entrance_focus_style.bg_color = Color(1.0, 0.88, 0.54, 0.12)
	entrance_focus_style.border_color = Color("ffe28a")
	entrance_focus_style.set_border_width_all(2)
	for state in ["hover", "pressed"]:
		entrance_button.add_theme_stylebox_override(state, entrance_focus_style)
	_update_entrance_focus()
	entrance_button.pressed.connect(_enter_bar)
	location_view.add_child(entrance_button)
	UIAudioManager.attach_button(entrance_button)
	entrance_button.hide()
	status_header = HubStatusHeader.new()
	location_view.add_child(status_header)
	map_button = _button("MAP", _show_map)
	store_button = _button("STORE", _depart.bind(STORE_SCENE))
	exit_button = _button("OUTSIDE", _exit_bar)
	exit_button.hide()
	shop_button = _button("SHOP", _open_bar_shop)
	shop_button.name = "BarShopButton"
	shop_button.hide()
	hub_dialogue = HubDialogue.new()
	add_child(hub_dialogue)
	hub_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_dialogue.safe_top = HubStatusHeader.CONTENT_TOP
	hub_dialogue.register_control("entrance", entrance_button)
	hub_dialogue.register_control("map_bar", map_view.buttons.bar)
	hub_dialogue.register_control("map_hospital", map_view.buttons.hospital)
	hub_dialogue.register_control("map_north", map_view.buttons.north)
	bar_characters.setup_dialogue(hub_dialogue)
	hospital_characters.setup_dialogue(hub_dialogue)
	bar_shop = BarShop.new()
	bar_shop.can_shop = _can_open_bar_shop
	add_child(bar_shop)
	bar_shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_shop.closed.connect(_on_bar_shop_closed)
	hospital_shop = HospitalShop.new()
	hospital_shop.can_shop = _can_open_hospital_shop
	add_child(hospital_shop)
	hospital_shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hospital_shop.closed.connect(_on_hospital_shop_closed)
	location_view.hide()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	DashboardTheme.apply_button(button)
	button.pressed.connect(action)
	location_view.add_child(button)
	UIAudioManager.attach_button(button)
	return button


func _layout() -> void:
	if location_view == null:
		return
	status_header.layout_in(size)
	DashboardTheme.layout_button_row([map_button, shop_button, store_button, exit_button], size)
	if background.texture != null:
		var art_size := background.texture.get_size()
		var fit := minf(size.x / art_size.x, size.y / art_size.y)
		entrance_button.position = (size - art_size * fit) * 0.5 + BAR_ENTRANCE.position * fit
		entrance_button.size = BAR_ENTRANCE.size * fit
	bar_characters.layout_in(size)
