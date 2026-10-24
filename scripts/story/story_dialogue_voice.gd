extends Node

# Dedicated, original dialogue blips. Story ambience and authored SFX keep their own player.
const SAMPLE_RATE := 22050
const BLIP_SECONDS := 0.03
const DEFAULT_VOLUME_DB := -22.0
static var _default_blip: AudioStreamWAV
static var _voiced_characters: RegEx

var player: AudioStreamPlayer
var sound_enabled := true
var voice_pitch := 1.0
var voice_every := 2
var voice_interval := 0.045
var _eligible_characters := 0
var _cooldown := 0.0
var _played_this_tick := false


func setup() -> void:
	if is_instance_valid(player):
		return
	player = AudioStreamPlayer.new()
	player.name = "DialogueBlipPlayer"
	player.bus = &"Master"
	player.stream = default_blip()
	add_child(player)
	AudioSettingsManager.register_player(player, "sfx", DEFAULT_VOLUME_DB)


func configure(settings: Dictionary) -> void:
	setup()
	stop()
	sound_enabled = settings.get("sound_enabled", true) if settings.get("sound_enabled", true) is bool else true
	voice_pitch = _number(settings.get("voice_pitch", 1.0), 1.0, 0.25, 4.0)
	voice_every = int(_number(settings.get("voice_every", 2), 2.0, 1.0, 20.0))
	voice_interval = _number(settings.get("voice_interval", 0.045), 0.045, 0.01, 1.0)
	player.pitch_scale = voice_pitch
	AudioSettingsManager.set_player_base_db(player, _number(settings.get("voice_volume_db", DEFAULT_VOLUME_DB), DEFAULT_VOLUME_DB, -80.0, 0.0))
	var stream_ref = settings.get("voice_stream", null)
	player.stream = _configured_stream(stream_ref)


# Call once per reveal update, before its character loop. Long frames never queue a burst.
func tick(delta: float) -> void:
	if not is_inside_tree() or not can_process():
		return
	_cooldown = maxf(0.0, _cooldown - maxf(0.0, delta))
	_played_this_tick = false


func play_character(character: String) -> bool:
	if not sound_enabled or not is_instance_valid(player) or not is_inside_tree() or not can_process():
		return false
	if not is_voiced_character(character):
		return false
	_eligible_characters += 1
	if (_eligible_characters - 1) % voice_every != 0 or _cooldown > 0.0 or _played_this_tick:
		return false
	# Respect both categories before starting a voice, including changes mid-line.
	if AudioSettingsManager.get_category_volume("sfx") <= 0.0 or AudioSettingsManager.get_category_volume("master") <= 0.0:
		return false
	player.pitch_scale = voice_pitch
	AudioSettingsManager.apply_player_volume(player)
	player.play()
	_cooldown = voice_interval
	_played_this_tick = true
	return true


func stop() -> void:
	if is_instance_valid(player):
		player.stop()
	_eligible_characters = 0
	_cooldown = 0.0
	_played_this_tick = false


static func is_voiced_character(character: String) -> bool:
	if _voiced_characters == null:
		_voiced_characters = RegEx.new()
		_voiced_characters.compile("[\\p{L}\\p{N}]")
	return _voiced_characters.search(character) != null


static func default_blip() -> AudioStreamWAV:
	if _default_blip != null:
		return _default_blip
	var frames := int(SAMPLE_RATE * BLIP_SECONDS)
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	for index in range(frames):
		var time := float(index) / SAMPLE_RATE
		var phase := fposmod(time * 330.0, 1.0)
		var square := 1.0 if phase < 0.28 else -1.0
		var triangle := 1.0 - 4.0 * absf(phase - 0.5)
		# Fade both ends to avoid clicks; the mixed waveform keeps a soft retro timbre.
		var attack := minf(1.0, time / 0.003)
		var release := pow(maxf(0.0, 1.0 - float(index) / frames), 1.4)
		var sample := clampf((square * 0.32 + triangle * 0.35) * attack * release, -1.0, 1.0)
		samples.encode_s16(index * 2, int(sample * 32767.0))
	_default_blip = AudioStreamWAV.new()
	_default_blip.format = AudioStreamWAV.FORMAT_16_BITS
	_default_blip.mix_rate = SAMPLE_RATE
	_default_blip.stereo = false
	_default_blip.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_default_blip.data = samples
	return _default_blip


static func _configured_stream(stream_ref) -> AudioStream:
	var stream: AudioStream
	if stream_ref is AudioStream:
		stream = stream_ref
	elif stream_ref is String and not stream_ref.is_empty() and ResourceLoader.exists(stream_ref):
		stream = load(stream_ref) as AudioStream
	if stream == null:
		return default_blip()
	# Custom voice clips are isolated from their imported resource and never loop.
	var configured := stream.duplicate(true) as AudioStream
	if configured is AudioStreamWAV:
		configured.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif configured is AudioStreamMP3 or configured is AudioStreamOggVorbis:
		configured.loop = false
	return configured if configured != null else default_blip()


static func _number(value, fallback: float, minimum: float, maximum: float) -> float:
	if (not value is int and not value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)
