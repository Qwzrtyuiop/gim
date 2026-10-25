extends Node

const STAGE_BGM_NORMAL_CHILL_A_PATH := "res://assets/audio/music/driving/chill_normal_day_noon.mp3"
const STAGE_BGM_NORMAL_CHILL_B_PATH := "res://assets/audio/music/driving/normalstage1.mp3"
const STAGE_BGM_NORMAL_CHILL_C_PATH := "res://assets/audio/music/driving/normalstage2.mp3"
const STAGE_BGM_NORMAL_CHILL_D_PATH := "res://assets/audio/music/driving/normal3.mp3"
const STAGE_BGM_SPEEDER_BUSY_A_PATH := "res://assets/audio/music/driving/speederbusy.mp3"
const STAGE_BGM_SPEEDER_BUSY_B_PATH := "res://assets/audio/music/driving/speederbusy2.mp3"
const STAGE_BGM_SPEEDER_BUSY_C_PATH := "res://assets/audio/music/driving/speederbusy3.mp3"
const STAGE_BGM_SPEEDER_BUSY_D_PATH := "res://assets/audio/music/driving/speederbusy4.mp3"
const STAGE_BGM_TRAFFIC_JAM_PATH := "res://assets/audio/music/driving/traffic_jam.mp3"
const STAGE_BGM_RAIN_LOOP_PATH := "res://assets/audio/ambience/rain_loop.mp3"
const CRASH_SFX := preload("res://assets/audio/sfx/driving/crash.mp3")
const HORN_SFX := preload("res://assets/audio/sfx/driving/hold_horn.wav")

const STAGE_BGM_NORMAL_CHILL_PATHS := [
	STAGE_BGM_NORMAL_CHILL_A_PATH,
	STAGE_BGM_NORMAL_CHILL_B_PATH,
	STAGE_BGM_NORMAL_CHILL_C_PATH,
	STAGE_BGM_NORMAL_CHILL_D_PATH,
]
const STAGE_BGM_SPEEDER_BUSY_PATHS := [
	STAGE_BGM_SPEEDER_BUSY_A_PATH,
	STAGE_BGM_SPEEDER_BUSY_B_PATH,
	STAGE_BGM_SPEEDER_BUSY_C_PATH,
	STAGE_BGM_SPEEDER_BUSY_D_PATH,
]

var speeder_beep_player: AudioStreamPlayer
var crash_sfx_player: AudioStreamPlayer
var horn_player: AudioStreamPlayer
var stage_bgm_player: AudioStreamPlayer
var rain_loop_bgm_player: AudioStreamPlayer
var current_stage_bgm_path := ""


func setup(parent: Node) -> void:
	speeder_beep_player = AudioStreamPlayer.new()
	var beep_stream := AudioStreamGenerator.new()
	beep_stream.mix_rate = 22050.0
	beep_stream.buffer_length = 0.12
	speeder_beep_player.stream = beep_stream
	parent.add_child(speeder_beep_player)
	AudioSettingsManager.register_player(speeder_beep_player, "sfx")

	crash_sfx_player = AudioStreamPlayer.new()
	crash_sfx_player.name = "CrashSFXPlayer"
	crash_sfx_player.stream = CRASH_SFX
	crash_sfx_player.bus = "Master"
	parent.add_child(crash_sfx_player)
	AudioSettingsManager.register_player(crash_sfx_player, "sfx")

	horn_player = AudioStreamPlayer.new()
	horn_player.name = "PlayerHornSFXPlayer"
	horn_player.bus = "Master"
	# The derived PCM clip starts at the audible onset and excludes the MP3's
	# silent padding, so short taps start promptly and held loops stay audible.
	var horn_stream := HORN_SFX.duplicate() as AudioStreamWAV
	horn_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	horn_stream.loop_begin = 0
	horn_stream.loop_end = roundi(horn_stream.get_length() * horn_stream.mix_rate)
	horn_player.stream = horn_stream
	parent.add_child(horn_player)
	AudioSettingsManager.register_player(horn_player, "sfx")

	stage_bgm_player = AudioStreamPlayer.new()
	stage_bgm_player.name = "StageBGMPlayer"
	stage_bgm_player.bus = "Master"
	parent.add_child(stage_bgm_player)
	AudioSettingsManager.register_player(stage_bgm_player, "music")

	rain_loop_bgm_player = AudioStreamPlayer.new()
	rain_loop_bgm_player.name = "RainLoopBGMPlayer"
	rain_loop_bgm_player.bus = "Master"
	rain_loop_bgm_player.stream = _load_audio_stream(STAGE_BGM_RAIN_LOOP_PATH)
	parent.add_child(rain_loop_bgm_player)
	AudioSettingsManager.register_player(rain_loop_bgm_player, "music", -8.0)


func start_stage_bgm(stage_time_of_day: String, stage_traffic: String, rng: RandomNumberGenerator) -> void:
	if stage_bgm_player == null:
		return

	var bgm_pool := _get_stage_bgm_pool(stage_time_of_day, stage_traffic)
	if bgm_pool.is_empty():
		return

	current_stage_bgm_path = str(bgm_pool[rng.randi_range(0, bgm_pool.size() - 1)])
	stage_bgm_player.stream = _load_audio_stream(current_stage_bgm_path)
	stage_bgm_player.play()


func start_rain_loop_bgm(stage_weather: String) -> void:
	if rain_loop_bgm_player == null:
		return

	if stage_weather != "rain" and stage_weather != "heavy rain":
		rain_loop_bgm_player.stop()
		return

	var base_db := -5.0 if stage_weather == "heavy rain" else -8.0
	AudioSettingsManager.set_player_base_db(rain_loop_bgm_player, base_db)
	if rain_loop_bgm_player.playing:
		return
	rain_loop_bgm_player.play()


func play_speeder_beep() -> void:
	if speeder_beep_player == null:
		return

	speeder_beep_player.play()
	var playback := speeder_beep_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	# play() creates a fresh generator playback. Clearing it after starting
	# is rejected by Godot because the playback is already active.
	var sample_rate := 22050.0
	var frequency := 880.0
	var frames := int(sample_rate * 0.08)
	for frame_index in range(frames):
		var fade := 1.0 - float(frame_index) / float(frames)
		var sample := sin(TAU * frequency * float(frame_index) / sample_rate) * 0.18 * fade
		playback.push_frame(Vector2(sample, sample))


func play_crash_sfx() -> void:
	if crash_sfx_player == null:
		return
	crash_sfx_player.stop()
	crash_sfx_player.play()


func is_crash_sfx_playing() -> bool:
	return is_instance_valid(crash_sfx_player) and crash_sfx_player.playing


func set_horn_active(active: bool) -> void:
	if not is_instance_valid(horn_player):
		return
	if not active:
		stop_horn()
		return
	# Input edges start the horn; polling a held key must not restart its loop.
	if not horn_player.playing:
		horn_player.play()


func stop_horn() -> void:
	if is_instance_valid(horn_player):
		horn_player.stop()


func get_result_music_carry_state() -> Dictionary:
	var state: Dictionary = {}
	var stage_music_is_playing := stage_bgm_player != null and is_instance_valid(stage_bgm_player) and stage_bgm_player.playing
	if stage_music_is_playing and not current_stage_bgm_path.is_empty():
		state["stage_path"] = current_stage_bgm_path
		state["stage_position"] = stage_bgm_player.get_playback_position()
		state["stage_base_db"] = AudioSettingsManager.get_player_base_db(stage_bgm_player)

	var rain_music_is_playing := rain_loop_bgm_player != null and is_instance_valid(rain_loop_bgm_player) and rain_loop_bgm_player.playing
	if rain_music_is_playing:
		state["rain_path"] = STAGE_BGM_RAIN_LOOP_PATH
		state["rain_position"] = rain_loop_bgm_player.get_playback_position()
		state["rain_base_db"] = AudioSettingsManager.get_player_base_db(rain_loop_bgm_player)

	return state


func _get_stage_bgm_pool(_stage_time_of_day: String, stage_traffic: String) -> Array:
	match stage_traffic:
		"speeders":
			return STAGE_BGM_SPEEDER_BUSY_PATHS
		"traffic-jam":
			return [STAGE_BGM_TRAFFIC_JAM_PATH]
		"busy":
			return STAGE_BGM_SPEEDER_BUSY_PATHS
		"chill":
			return STAGE_BGM_NORMAL_CHILL_PATHS
		"normal":
			return STAGE_BGM_NORMAL_CHILL_PATHS
	return STAGE_BGM_NORMAL_CHILL_PATHS


func _load_audio_stream(path: String):
	var stream = load(path)
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		stream.loop = true
	return stream
