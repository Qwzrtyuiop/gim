extends Control

# Prototype travel stays scene-local until these locations have gameplay hubs.
# Only departures to existing hubs change scenes; browsing never advances time.
signal closed
signal destination_requested(scene_path: String)
signal bar_music_changed
signal bar_character_interacted(character_id: String)

const MapView := preload("res://scripts/map/topdown_map_view.gd")
const MapCatalog := preload("res://scripts/map/topdown_map_catalog.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const HubStatusHeader := preload("res://scripts/ui/hub_status_header.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const InputHighlightMode := preload("res://scripts/ui/input_highlight_mode.gd")
const BackgroundWeather := preload("res://scripts/story/story_background_weather.gd")
const BarAlmaSpawn := preload("res://scripts/home/bar_alma_spawn.gd")
const BarAudio := preload("res://scripts/home/bar_audio.gd")
const LOCATIONS := "res://assets/story/backgrounds/locations/"
const STATION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const BAR_ENTRANCE := Rect2(185, 12, 1275, 815)
const BENNY_TEXTURE := preload("res://assets/characters/sprites/bennybar.png")
const BENNY_REGION := Rect2(735, 328, 250, 470)
const BENNY_MIN_BOND := 2
const BENNY_SPAWN_CHANCE := 0.30
const BAR_CLOSED_MESSAGE := "It's closed. I should try again later."
const NORTH_ROAD_UNLOCK_DAY := 8
const NORTH_ROAD_CLOSED_MESSAGE := "There's road construction ahead. I can't get through. It'll take about a week or so. I should check again later."
const BACKGROUNDS := {
	"market": ["market.png", "marketnight.png"],
	"park": ["park.png", "parknight.png"],
	"hospital": ["hospitalday.png", "hospitalnight.png"],
	"bar": ["barnight.png", "barnight.png"],
}

var map_view: MapView
var location_view: Control
var background: TextureRect
var alma_spawn: BarAlmaSpawn
var benny_spawn: TextureButton
var bar_audio: BarAudio
var status_header: HubStatusHeader
var map_button: Button
var home_button: Button
var store_button: Button
var entrance_button: Button
var exit_button: Button
var hub_dialogue: HubDialogue
var current_location := "home"
var inside_bar := false
var _bar_rng := RandomNumberGenerator.new()
var entrance_highlight_mode := InputHighlightMode.new()
var entrance_focus_style: StyleBoxFlat


func _ready() -> void:
	name = "HomeMap"
	_bar_rng.randomize()
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_view = MapView.new()
	add_child(map_view)
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.location_selected.connect(_visit)
	map_view.closed.connect(_close)
	_build_location_view()
	bar_audio = BarAudio.new()
	add_child(bar_audio)
	bar_audio.active_changed.connect(bar_music_changed.emit)
	resized.connect(_layout)
	_layout()
	hide()
	map_view.set_enabled(false)
	set_process(false)


func _process(_delta: float) -> void:
	if benny_spawn.self_modulate != background.self_modulate:
		benny_spawn.self_modulate = background.self_modulate


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not location_view.visible:
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


func open() -> void:
	current_location = "home"
	map_view.set_map_region("town")
	map_view.set_night(PlayerState.get_current_time_of_day() == "night")
	show()
	_show_map()


func _show_map() -> void:
	_set_bar_active(false)
	AmbientAudioManager.set_rain_indoors(false)
	hub_dialogue.clear()
	entrance_highlight_mode.reset()
	_update_entrance_focus()
	inside_bar = false
	location_view.hide()
	background.texture = null
	BackgroundWeather.apply(background)
	for button in [map_button, home_button, store_button, entrance_button, exit_button]:
		button.release_focus()
	map_view.set_current_location(current_location)
	map_view.set_weather(PlayerState.current_weather)
	map_view.show()
	map_view.set_enabled(true)
	map_view.back_button.grab_focus()


func _visit(location_id: String) -> void:
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
		_close()
		return
	if location_id == "station":
		_depart(STATION_SCENE)
		return
	var north_destination := map_view.map_region == "north" and MapCatalog.NORTH_REGIONS.has(location_id)
	if not BACKGROUNDS.has(location_id) and not north_destination:
		return
	current_location = location_id
	_set_bar_active(false)
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
		background.texture = load(LOCATIONS + str(art[1 if night else 0])) as Texture2D
	BackgroundWeather.apply(background, north_destination)
	_refresh_rain_environment()
	entrance_button.visible = location_id == "bar"
	exit_button.hide()
	store_button.visible = location_id == "market"
	status_header.refresh()
	location_view.show()
	map_button.grab_focus()
	_layout()


func _depart(scene_path: String) -> void:
	_set_bar_active(false)
	hub_dialogue.clear()
	map_view.set_enabled(false)
	for button in [map_button, home_button, store_button, entrance_button, exit_button]:
		button.disabled = true
	destination_requested.emit(scene_path)


func _close() -> void:
	_set_bar_active(false)
	AmbientAudioManager.set_rain_indoors(true)
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
	exit_button.grab_focus()
	_layout()


func _show_bar_closed(target: String) -> void:
	hub_dialogue.say(BAR_CLOSED_MESSAGE, {
		"speaker": "John Toda",
		"target": target,
		"show_tail": false,
		"duration": 3.5,
		"blocking": false,
	})


func _exit_bar() -> void:
	if not inside_bar:
		return
	_set_bar_active(false)
	hub_dialogue.clear()
	inside_bar = false
	background.texture = load(LOCATIONS + "barnight.png") as Texture2D
	BackgroundWeather.apply(background)
	_refresh_rain_environment()
	exit_button.release_focus()
	exit_button.hide()
	entrance_button.show()
	map_button.grab_focus()
	_layout()


func _set_bar_active(value: bool) -> void:
	alma_spawn.set_active(value)
	# Roll once on entry, independently of passenger and driving RNG.
	var benny_present := value and PlayerState.get_unique_character_progress("benny") >= BENNY_MIN_BOND and _bar_rng.randf() < BENNY_SPAWN_CHANCE
	benny_spawn.visible = benny_present
	benny_spawn.disabled = not benny_present
	benny_spawn.self_modulate = background.self_modulate
	if not value:
		benny_spawn.release_focus()
	bar_audio.set_active(value)
	set_process(value)


func _on_bar_character_interacted(character_id: String) -> void:
	if not inside_bar or not location_view.is_visible_in_tree() or hub_dialogue.blocks_input():
		return
	hub_dialogue.say("...", {
		"target": "bar:" + character_id,
		"character_id": character_id,
		"duration": 2.5,
	})
	bar_character_interacted.emit(character_id)


func _alma_message_target() -> Rect2:
	if not alma_spawn.active or not alma_spawn.is_visible_in_tree():
		return Rect2()
	return alma_spawn.get_global_transform_with_canvas() * alma_spawn.sprite_rect


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
	alma_spawn = BarAlmaSpawn.new()
	background.add_child(alma_spawn)
	alma_spawn.interacted.connect(_on_bar_character_interacted)
	_build_benny_spawn()
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
	home_button = _button("HOME", _close)
	store_button = _button("STORE", _depart.bind(STORE_SCENE))
	exit_button = _button("OUTSIDE", _exit_bar)
	exit_button.hide()
	hub_dialogue = HubDialogue.new()
	add_child(hub_dialogue)
	hub_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub_dialogue.safe_top = HubStatusHeader.CONTENT_TOP
	hub_dialogue.register_control("entrance", entrance_button)
	hub_dialogue.register_control("map_bar", map_view.buttons.bar)
	hub_dialogue.register_control("map_north", map_view.buttons.north)
	hub_dialogue.register_control("bar:benny", benny_spawn)
	hub_dialogue.register_target("bar:alma", _alma_message_target)
	location_view.hide()


func _build_benny_spawn() -> void:
	benny_spawn = TextureButton.new()
	benny_spawn.name = "BennyBarSpawn"
	benny_spawn.ignore_texture_size = true
	benny_spawn.stretch_mode = TextureButton.STRETCH_SCALE
	benny_spawn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var atlas := AtlasTexture.new()
	atlas.atlas = BENNY_TEXTURE
	atlas.region = BENNY_REGION
	atlas.filter_clip = true
	benny_spawn.texture_normal = atlas
	var image := BENNY_TEXTURE.get_image()
	if image.is_compressed():
		image.decompress()
	var mask := BitMap.new()
	mask.create_from_image_alpha(image.get_region(Rect2i(BENNY_REGION)), 0.7)
	benny_spawn.texture_click_mask = mask
	benny_spawn.pressed.connect(_on_bar_character_interacted.bind("benny"))
	background.add_child(benny_spawn)
	benny_spawn.hide()
	benny_spawn.disabled = true


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
	map_button.position = Vector2(20, size.y - 60)
	map_button.size = DashboardTheme.BUTTON_SIZE
	home_button.position = Vector2(size.x - DashboardTheme.BUTTON_SIZE.x - 20, size.y - 60)
	home_button.size = DashboardTheme.BUTTON_SIZE
	store_button.position = Vector2(size.x - DashboardTheme.BUTTON_SIZE.x - 20, size.y - 116)
	store_button.size = DashboardTheme.BUTTON_SIZE
	exit_button.position = store_button.position
	exit_button.size = DashboardTheme.BUTTON_SIZE
	if background.texture != null:
		var art_size := background.texture.get_size()
		var fit := minf(size.x / art_size.x, size.y / art_size.y)
		entrance_button.position = (size - art_size * fit) * 0.5 + BAR_ENTRANCE.position * fit
		entrance_button.size = BAR_ENTRANCE.size * fit
		benny_spawn.position = (background.size - art_size * fit) * 0.5 + BENNY_REGION.position * fit
		benny_spawn.size = BENNY_REGION.size * fit
