extends Node

signal active_changed

const MUSIC := preload("res://assets/audio/music/story/bar.mp3")
const AMBIENCE := preload("res://assets/audio/ambience/bar_ambience.mp3")
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const MUSIC_BASE_DB := 0.0
const AMBIENCE_BASE_DB := -8.0

var active := false
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var _weather := ""


func _ready() -> void:
	name = "BarAudio"
	music_player = _make_player("BarMusic", MUSIC, "music", MUSIC_BASE_DB)
	ambience_player = _make_player("BarAmbience", AMBIENCE, "sfx", AMBIENCE_BASE_DB)
	set_process(false)


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	set_process(value)
	if not value:
		music_player.stop()
		ambience_player.stop()
		_weather = ""
	# The parent suspends its normal music before the bar track begins.
	active_changed.emit()
	if value:
		_refresh_mix()
		music_player.play()
		ambience_player.play()


func _process(_delta: float) -> void:
	if _weather != PlayerState.current_weather:
		_refresh_mix()


func _refresh_mix() -> void:
	_weather = PlayerState.current_weather
	AudioSettingsManager.set_player_base_db(music_player, MUSIC_BASE_DB + RainAudioProfile.music_duck_db(_weather))


func _make_player(player_name: String, source: AudioStreamMP3, category: String, base_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Master"
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = true
	player.stream = stream
	add_child(player)
	AudioSettingsManager.register_player(player, category, base_db)
	return player
