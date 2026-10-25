extends Node

# One visit clock spans the street and terminal, regardless of player input.
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
]

var player: AudioStreamPlayer
var idle_timer: Timer
var active := false
var weather := "clear"
var _track_base_db := 0.0
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
	idle_timer = Timer.new()
	idle_timer.name = "IdleTimer"
	idle_timer.wait_time = IDLE_SECONDS
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timeout)
	add_child(idle_timer)
	idle_timer.start()


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
		idle_timer.start(IDLE_SECONDS)
		return
	var track: Dictionary = TRACKS[_rng.randi_range(0, TRACKS.size() - 1)]
	var source: AudioStreamMP3 = track.stream
	var loop := source.duplicate() as AudioStreamMP3
	loop.loop = true
	player.stream = loop
	_track_base_db = float(track.base_db)
	_refresh_volume()
	idle_timer.stop()
	active = true
	# Stop the normal station track before starting the idle track.
	active_changed.emit(true)
	player.play()
