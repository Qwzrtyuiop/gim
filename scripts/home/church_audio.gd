extends Node

# Location ambience is separate from shared weather and nighttime audio.
const AMBIENCE := preload("res://assets/audio/ambience/church.mp3")
const AMBIENCE_BASE_DB := -8.0

var active := false
var ambience_player: AudioStreamPlayer


func _ready() -> void:
	name = "ChurchAudio"
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "ChurchAmbience"
	var stream := AMBIENCE.duplicate() as AudioStreamMP3
	stream.loop = true
	ambience_player.stream = stream
	add_child(ambience_player)
	AudioSettingsManager.register_player(ambience_player, "sfx", AMBIENCE_BASE_DB)


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	if value:
		ambience_player.play()
	else:
		ambience_player.stop()
