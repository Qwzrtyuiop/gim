extends Node

# Hubs share one player and remember each theme's position between visits.
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const DEFAULT_PATH := "res://assets/audio/music/driving/normalstage1.mp3"
const HOME_PATH := "res://assets/audio/music/story/peace.mp3"
const MECHANIC_PATH := "res://assets/audio/music/menus/store.mp3"
const RAINY_NIGHT_PATH := "res://assets/audio/music/driving/night_station.mp3"
const SUPPORTED_SCENES := [
	"res://scenes/day_start_scene.tscn",
	"res://scenes/store.tscn",
	"res://scenes/ride_selection.tscn",
]

var player: AudioStreamPlayer
var current_path := ""
var _positions: Dictionary = {}
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = AudioStreamPlayer.new()
	player.name = "HubMusicPlayer"
	player.bus = &"Master"
	add_child(player)
	AudioSettingsManager.register_player(player, "music")
	# Startup never resolves weather or modifies player progress.
	get_tree().scene_changed.connect(_on_scene_changed)


static func background_path(home_interior := false) -> String:
	if PlayerState.get_current_time_of_day() == "night" and not RainAudioProfile.path_for(PlayerState.current_weather).is_empty():
		return RAINY_NIGHT_PATH
	return HOME_PATH if home_interior else DEFAULT_PATH


func request_track(path: String, base_db := 0.0, blocked := false) -> AudioStreamPlayer:
	AudioSettingsManager.set_player_base_db(player, base_db)
	var desired_path := path.strip_edges()
	if desired_path.is_empty():
		_suspend()
		return player
	if desired_path != current_path:
		_remember_position()
		player.stop()
		player.stream = _stream_for(desired_path)
		current_path = desired_path if player.stream != null else ""
	if blocked or current_path.is_empty():
		_suspend()
	elif not player.playing:
		player.play(maxf(0.0, float(_positions.get(current_path, 0.0))))
	return player


func stop_all() -> void:
	player.stop()
	player.stream = null
	current_path = ""
	_positions.clear()


func _suspend() -> void:
	_remember_position()
	player.stop()


func _remember_position() -> void:
	if not current_path.is_empty() and player.playing:
		_positions[current_path] = player.get_playback_position()


func _stream_for(path: String) -> AudioStreamMP3:
	if _streams.has(path):
		return _streams[path] as AudioStreamMP3
	var source := load(path) as AudioStreamMP3
	if source == null:
		return null
	var loop := source.duplicate() as AudioStreamMP3
	loop.loop = true
	_streams[path] = loop
	return loop


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path in SUPPORTED_SCENES:
		return
	stop_all()
