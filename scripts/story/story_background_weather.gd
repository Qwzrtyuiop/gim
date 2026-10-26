extends Control

# Authored rain masks follow the background through story camera movement.
const HubWeatherEffects := preload("res://scripts/ui/hub_weather_effects.gd")
const LOCATIONS := "res://assets/story/backgrounds/locations/"
const MARKERS := {
	"bar.png": "barrain_indoor.png",
	"barnight.png": "barnightrain.png",
	"hospitalday.png": "hospitalrain_indoor.png",
	"hospitalnight.png": "hospitalrain_indoor.png",
	"inhouse.png": "houserain_indoor.png",
	"inhouse_night.png": "houserain_indoor.png",
	"park.png": "parkrain.png",
	"parknight.png": "parkrain.png",
	"market.png": "marketrain.png",
	"marketnight.png": "marketrain.png",
}

var _background: TextureRect
var _effects: HubWeatherEffects
var _base_tint := Color.WHITE
var _weather := ""


static func apply(background: TextureRect, outdoor_without_mask := false) -> void:
	var layer := background.get_node_or_null("StoryBackgroundWeather") as Control
	var path: String = background.texture.resource_path if background.texture != null else ""
	var marker_file: String = MARKERS.get(path.get_file(), "") if path.begins_with(LOCATIONS) else ""
	if marker_file.is_empty() and layer == null and not outdoor_without_mask:
		return
	if layer == null:
		layer = load("res://scripts/story/story_background_weather.gd").new()
		layer.name = "StoryBackgroundWeather"
		background.add_child(layer)
	var marker: Texture2D = load(LOCATIONS + marker_file) as Texture2D if not marker_file.is_empty() else null
	layer.call("configure", background, marker, marker_file.get_basename().ends_with("_indoor"), outdoor_without_mask)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects = HubWeatherEffects.new()
	add_child(_effects)
	set_process(false)


func configure(background: TextureRect, marker: Texture2D, inside := false, outdoor_without_mask := false) -> void:
	if _background == null:
		_background = background
		_base_tint = background.self_modulate
	_effects.configure(marker, inside, true)
	visible = marker != null or outdoor_without_mask
	set_process(visible)
	_weather = ""
	if not visible:
		_background.self_modulate = _base_tint
		_effects.set_weather("clear")
		return
	_sync_weather()
	_sync_art_rect()


func _process(_delta: float) -> void:
	_sync_weather()
	_sync_art_rect()


func _sync_weather() -> void:
	# The weather getter can roll/save a phase. Presentation must remain read-only,
	# including when this scene is viewed as a memory.
	var current: String = PlayerState.current_weather
	if current == _weather:
		return
	_weather = current
	_effects.set_weather(current)
	_background.self_modulate = _base_tint * _effects.background_tint()


func _sync_art_rect() -> void:
	if _background.texture == null:
		return
	var rect := Rect2(Vector2.ZERO, _background.size)
	if _background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		var art_size: Vector2 = _background.texture.get_size()
		var fit := minf(_background.size.x / maxf(1.0, art_size.x), _background.size.y / maxf(1.0, art_size.y))
		var fitted: Vector2 = art_size * fit
		rect = Rect2((_background.size - fitted) * 0.5, fitted)
	if _effects.position != rect.position or _effects.size != rect.size:
		_effects.set_art_rect(rect)
