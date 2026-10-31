extends Node

# Fishing owns its music and reel loops; shared weather ambience stays untouched.
signal active_changed

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const MUSIC := preload("res://assets/audio/music/fishinggame/fishingloop.mp3")
const NIGHT_MUSIC := preload("res://assets/audio/music/fishinggame/fishing_night.mp3")
const IDLE := preload("res://assets/audio/sfx/fishinggame/reel_idle.mp3")
const PULL := preload("res://assets/audio/sfx/fishinggame/reel_pull.mp3")
const MUSIC_BASE_DB := 0.0
const IDLE_BASE_DB := -14.0
const PULL_BASE_DB := -8.0
const QUIET_REEL_DB := -60.0
const REEL_FADE_IN_SECONDS := 0.04

var active := false
var music_player: AudioStreamPlayer
var idle_player: AudioStreamPlayer
var pull_player: AudioStreamPlayer
var _normal_music: AudioStreamMP3
var _night_music: AudioStreamMP3
var _rng := RandomNumberGenerator.new()
var _weather := ""
var _reel_active := false
var _reel_direction := 0.0
var _reel_fades: Dictionary = {}


func _ready() -> void:
	name = "FishingAudio"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_normal_music = _looped_stream(MUSIC)
	_night_music = _looped_stream(NIGHT_MUSIC)
	music_player = _make_player("FishingMusic", "music", MUSIC_BASE_DB)
	idle_player = _make_player("ReelIdle", "sfx", IDLE_BASE_DB)
	idle_player.stream = _looped_stream(IDLE)
	pull_player = _make_player("ReelPull", "sfx", PULL_BASE_DB)
	pull_player.stream = _looped_stream(PULL)


func begin(night: bool, weather: String) -> void:
	if active:
		return
	_stop_reel_immediately()
	var special_track := night and _rng.randf() < GameTuning.FISHING_NIGHT_MUSIC_CHANCE
	music_player.stream = _night_music if special_track else _normal_music
	set_weather(weather)
	active = true
	_reel_active = true
	_reel_direction = 0.0
	# The host suspends its hub track before the fishing track begins.
	active_changed.emit()
	music_player.play()


func set_weather(weather: String) -> void:
	if _weather == weather:
		return
	_weather = weather
	if music_player != null:
		AudioSettingsManager.set_player_base_db(music_player, MUSIC_BASE_DB + RainAudioProfile.music_duck_db(_weather))


func set_reel_motion(direction: float) -> void:
	var next_direction := signf(direction)
	if not active or not _reel_active or _reel_direction == next_direction:
		return
	_reel_direction = next_direction
	_fade_reel(idle_player, IDLE_BASE_DB if next_direction > 0.0 else QUIET_REEL_DB, next_direction <= 0.0)
	_fade_reel(pull_player, PULL_BASE_DB if next_direction < 0.0 else QUIET_REEL_DB, next_direction >= 0.0)


func stop_reel() -> void:
	_reel_active = false
	_reel_direction = 0.0
	_fade_reel(idle_player, QUIET_REEL_DB, true)
	_fade_reel(pull_player, QUIET_REEL_DB, true)


func stop() -> void:
	stop_reel()
	if is_instance_valid(music_player):
		music_player.stop()
	if active:
		active = false
		active_changed.emit()


func _exit_tree() -> void:
	# Teardown must not ask a departing host to restart its background music.
	_stop_reel_immediately()
	if is_instance_valid(music_player):
		music_player.stop()
	active = false


func _fade_reel(player: AudioStreamPlayer, target_db: float, stop_after: bool) -> void:
	if not is_instance_valid(player):
		return
	var pending: Dictionary = _reel_fades.get(player, {})
	if not pending.is_empty() and is_equal_approx(float(pending.target_db), target_db):
		return
	_cancel_reel_fade(player)
	if not player.playing:
		if stop_after:
			return
		AudioSettingsManager.set_player_base_db(player, QUIET_REEL_DB)
		player.play()
	var duration := GameTuning.FISHING_REEL_SFX_FADE_SECONDS if stop_after else REEL_FADE_IN_SECONDS
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reel_fades[player] = {
		"tween": fade,
		"target_db": target_db,
	}
	var apply_volume := func(value: float) -> void:
		AudioSettingsManager.set_player_base_db(player, value)
	fade.tween_method(apply_volume, AudioSettingsManager.get_player_base_db(player), target_db, duration)
	fade.tween_callback(_finish_reel_fade.bind(player, fade, stop_after))


func _finish_reel_fade(player: AudioStreamPlayer, fade: Tween, stop_after: bool) -> void:
	var pending: Dictionary = _reel_fades.get(player, {})
	if pending.is_empty() or pending.tween != fade:
		return
	_reel_fades.erase(player)
	if stop_after and is_instance_valid(player):
		player.stop()


func _cancel_reel_fade(player: AudioStreamPlayer) -> void:
	var pending: Dictionary = _reel_fades.get(player, {})
	if pending.is_empty():
		return
	var fade: Tween = pending.tween
	fade.kill()
	_reel_fades.erase(player)


func _stop_reel_immediately() -> void:
	_reel_active = false
	_reel_direction = 0.0
	for player: AudioStreamPlayer in [idle_player, pull_player]:
		_cancel_reel_fade(player)
		if is_instance_valid(player):
			player.stop()


func _make_player(player_name: String, category: String, base_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Master"
	add_child(player)
	AudioSettingsManager.register_player(player, category, base_db)
	return player


func _looped_stream(source: AudioStreamMP3) -> AudioStreamMP3:
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = true
	return stream
