extends Node

# Pier ambience stays independent of fishing music and shared weather layers.
const WAVES := preload("res://assets/audio/ambience/waves.mp3")
const SEAGULLS := preload("res://assets/audio/ambience/seagulls.mp3")
const WAVES_BASE_DB := -10.0
const SEAGULL_BASE_DB := -14.0
const SEAGULL_CHECK_SECONDS := 10.0
const SEAGULL_CHANCE := 0.25

var active := false
var waves_player: AudioStreamPlayer
var seagull_player: AudioStreamPlayer
var timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "PierAudio"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	waves_player = _make_player("PierWaves", WAVES, WAVES_BASE_DB, true)
	seagull_player = _make_player("PierSeagulls", SEAGULLS, SEAGULL_BASE_DB, false)
	timer = Timer.new()
	timer.name = "SeagullTimer"
	timer.wait_time = SEAGULL_CHECK_SECONDS
	timer.timeout.connect(_on_seagull_check)
	add_child(timer)


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	if value:
		waves_player.play()
		timer.start(SEAGULL_CHECK_SECONDS)
	else:
		_stop_players()


func _on_seagull_check() -> void:
	if not active or seagull_player.playing:
		return
	if _rng.randf() < SEAGULL_CHANCE:
		seagull_player.play()


func _exit_tree() -> void:
	active = false
	_stop_players()


func _stop_players() -> void:
	if is_instance_valid(timer):
		timer.stop()
	if is_instance_valid(waves_player):
		waves_player.stop()
	if is_instance_valid(seagull_player):
		seagull_player.stop()


func _make_player(player_name: String, source: AudioStreamMP3, base_db: float, loop: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Master"
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = loop
	player.stream = stream
	add_child(player)
	AudioSettingsManager.register_player(player, "sfx", base_db)
	return player
