extends "res://scripts/ui/hub_night_ambience.gd"

# Location entry changes this mix without recreating its looping players.
const SUPPORTED_SCENES := [
	"res://scenes/day_start_scene.tscn",
	"res://scenes/store.tscn",
	"res://scenes/ride_selection.tscn",
	"res://scenes/main.tscn",
	"res://scenes/stage_results.tscn",
]

var _mode := ""
var _hub_station := false
var _override_weather := ""
var _override_phase := ""


func _ready() -> void:
	# Menu startup must not resolve daily weather or write player state.
	auto_refresh = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	super._ready()
	name = "AmbientAudioManager"
	stop_all()
	get_tree().scene_changed.connect(_on_scene_changed)


func enter_hub(station := false) -> void:
	_mode = "hub"
	_hub_station = station
	_override_weather = ""
	_override_phase = ""
	refresh()


func enter_drive(weather: String, phase: String) -> void:
	_mode = "drive"
	_hub_station = false
	_override_weather = weather
	_override_phase = phase.strip_edges().to_lower()
	refresh()


func enter_results(music_state: Dictionary) -> void:
	var path := str(music_state.get("rain_path", "")).strip_edges()
	var weather := "clear"
	if path == RainAudioProfile.NORMAL_PATH:
		weather = "rain"
	elif path == RainAudioProfile.HEAVY_PATH:
		weather = "heavy rain"
	elif music_state.is_empty():
		weather = _override_weather if _mode == "results" else PlayerState.get_current_weather()
	var rain_continues := rain_player.playing and _rain_path == RainAudioProfile.path_for(weather)
	_mode = "results"
	_hub_station = false
	_override_weather = weather
	_override_phase = PlayerState.get_current_time_of_day()
	refresh()
	# Existing continuous loops keep their position. A story or cold resume may
	# have stopped the service, in which case retain the recorded result offset.
	if not rain_continues and rain_player.playing and not path.is_empty():
		rain_player.seek(maxf(0.0, float(music_state.get("rain_position", 0.0))))


func refresh() -> void:
	match _mode:
		"hub":
			refresh_for(PlayerState.get_current_weather(), PlayerState.get_current_time_of_day() == "night", _hub_station)
		"drive", "results":
			refresh_for(_override_weather, _override_phase == "night", false, false)
		_:
			stop_all()


func stop_all() -> void:
	_mode = ""
	_hub_station = false
	_override_weather = ""
	_override_phase = ""
	refresh_for("clear", false, false, false)


func _on_dog_check() -> void:
	if _mode == "hub":
		super._on_dog_check()


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path in SUPPORTED_SCENES:
		return
	stop_all()
