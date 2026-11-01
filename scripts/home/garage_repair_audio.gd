extends Node

# Repair-session sounds stay separate from shared weather and hub music.
const AMBIENCE := preload("res://assets/audio/ambience/repair.mp3")
const HIT := preload("res://assets/audio/sfx/repairgame/hit.mp3")
const MISS := preload("res://assets/audio/sfx/repairgame/miss.mp3")
const AMBIENCE_BASE_DB := -8.0
const RESULT_BASE_DB := 0.0

var active := false
var ambience_player: AudioStreamPlayer
var result_player: AudioStreamPlayer
var _hit_stream: AudioStreamMP3
var _miss_stream: AudioStreamMP3


func _ready() -> void:
	name = "GarageRepairAudio"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ambience_player = _make_player("RepairAmbience", AMBIENCE_BASE_DB)
	ambience_player.stream = _copy_stream(AMBIENCE, true)
	result_player = _make_player("RepairResult", RESULT_BASE_DB)
	_hit_stream = _copy_stream(HIT, false)
	_miss_stream = _copy_stream(MISS, false)


func begin() -> void:
	if active:
		return
	active = true
	ambience_player.play()


func play_result(success: bool) -> void:
	if not active:
		return
	result_player.stream = _hit_stream if success else _miss_stream
	result_player.play()


func stop() -> void:
	active = false
	if is_instance_valid(ambience_player):
		ambience_player.stop()
	if is_instance_valid(result_player):
		result_player.stop()


func _exit_tree() -> void:
	stop()


func _make_player(player_name: String, base_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Master"
	add_child(player)
	AudioSettingsManager.register_player(player, "sfx", base_db)
	return player


func _copy_stream(source: AudioStreamMP3, loop: bool) -> AudioStreamMP3:
	var stream := source.duplicate() as AudioStreamMP3
	stream.loop = loop
	return stream
