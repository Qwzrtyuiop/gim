extends Node

# Count time on the eligible passenger screen, regardless of player input.
signal active_changed(active: bool)

const IDLE_SECONDS := 60.0
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const TRACKS := [
	{
		"stream": preload("res://assets/audio/music/story/jazz.mp3"),
		"base_db": -14.0,
	},
	{
		"stream": preload("res://assets/audio/music/story/midnight.mp3"),
		"base_db": 0.0,
	},
	{
		"stream": preload("res://assets/audio/music/story/midnight2.mp3"),
		"base_db": 0.0,
	},
]

var player: AudioStreamPlayer
var idle_timer: Timer
var active := false
var weather := "clear"
var _track_base_db := 0.0
var _track_index := -1
var can_play: Callable
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "StationIdleMusic"
	_rng.randomize()
	player = AudioStreamPlayer.new()
	player.name = "IdleMusicPlayer"
	player.bus = &"Master"
	add_child(player)
	AudioSettingsManager.register_player(player, "music")
	player.finished.connect(_on_track_finished)
	idle_timer = Timer.new()
	idle_timer.name = "IdleTimer"
	idle_timer.wait_time = IDLE_SECONDS
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timeout)
	add_child(idle_timer)
	refresh_availability()


func refresh_availability() -> void:
	if can_play.is_valid() and not bool(can_play.call()):
		idle_timer.stop()
		player.stop()
		if active:
			active = false
			active_changed.emit(false)
	elif not active and idle_timer.is_stopped():
		idle_timer.start(IDLE_SECONDS)


func set_weather(value: String) -> void:
	weather = value
	_refresh_volume()


func _refresh_volume() -> void:
	if player != null:
		AudioSettingsManager.set_player_base_db(player, _track_base_db + RainAudioProfile.music_duck_db(weather))


func _on_idle_timeout() -> void:
	if not is_inside_tree() or get_tree().paused or active:
		return
	if can_play.is_valid() and not bool(can_play.call()):
		refresh_availability()
		return
	idle_timer.stop()
	active = true
	# Stop the normal station track before starting the idle track.
	active_changed.emit(true)
	_play_next_track()


func _on_track_finished() -> void:
	if not active or not is_inside_tree() or get_tree().paused:
		return
	if can_play.is_valid() and not bool(can_play.call()):
		refresh_availability()
		return
	_play_next_track()


func _play_next_track() -> void:
	var candidates: Array[int] = []
	for index in range(TRACKS.size()):
		if index != _track_index or TRACKS.size() == 1:
			candidates.append(index)
	if candidates.is_empty():
		return
	_track_index = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var track: Dictionary = TRACKS[_track_index]
	var source: AudioStreamMP3 = track.stream
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = false
	player.stream = stream
	_track_base_db = float(track.base_db)
	_refresh_volume()
	player.play()
