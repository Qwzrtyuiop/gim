extends Node

const STAGE_BGM_MORNING_CHILL_PATH := "res://assets/stagebgm/morning_chill.mp3"
const STAGE_BGM_NIGHT_CHILL_PATH := "res://assets/stagebgm/night_chill.mp3"
const STAGE_BGM_NORMAL_PATH := "res://assets/stagebgm/normalstage1.mp3"
const STAGE_BGM_SPEEDER_A_PATH := "res://assets/stagebgm/speeder.mp3"
const STAGE_BGM_SPEEDER_B_PATH := "res://assets/stagebgm/speeder2.mp3"
const STAGE_BGM_TRAFFIC_JAM_PATH := "res://assets/stagebgm/traffic_jam.mp3"
const STAGE_BGM_RAIN_LOOP_PATH := "res://assets/stagebgm/rainloop.mp3"
const CRASH_SFX := preload("res://assets/sfx/crash.mp3")

var speeder_beep_player: AudioStreamPlayer
var crash_sfx_player: AudioStreamPlayer
var stage_bgm_player: AudioStreamPlayer
var rain_loop_bgm_player: AudioStreamPlayer


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

	stage_bgm_player.stream = bgm_pool[rng.randi_range(0, bgm_pool.size() - 1)]
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

	playback.clear_buffer()
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


func _get_stage_bgm_pool(stage_time_of_day: String, stage_traffic: String) -> Array:
	match stage_traffic:
		"speeders":
			return [_load_audio_stream(STAGE_BGM_SPEEDER_A_PATH), _load_audio_stream(STAGE_BGM_SPEEDER_B_PATH)]
		"traffic-jam":
			return [_load_audio_stream(STAGE_BGM_TRAFFIC_JAM_PATH)]
		"busy":
			return [_load_audio_stream(STAGE_BGM_SPEEDER_A_PATH), _load_audio_stream(STAGE_BGM_SPEEDER_B_PATH)]
		"chill":
			if stage_time_of_day == "night":
				return [_load_audio_stream(STAGE_BGM_NIGHT_CHILL_PATH)]
			return [_load_audio_stream(STAGE_BGM_MORNING_CHILL_PATH), _load_audio_stream(STAGE_BGM_NORMAL_PATH)]
		"normal":
			if stage_time_of_day == "night":
				return [_load_audio_stream(STAGE_BGM_NIGHT_CHILL_PATH), _load_audio_stream(STAGE_BGM_NORMAL_PATH)]
			return [_load_audio_stream(STAGE_BGM_NORMAL_PATH), _load_audio_stream(STAGE_BGM_MORNING_CHILL_PATH)]
	return [_load_audio_stream(STAGE_BGM_NORMAL_PATH)]


func _load_audio_stream(path: String):
	var stream = load(path)
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		stream.loop = true
	return stream
