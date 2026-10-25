extends RefCounted

const Profile := preload("res://scripts/audio/rain_audio_profile.gd")
const WeatherState := preload("res://scripts/state/player_weather_state.gd")
const DrivingAudio := preload("res://scripts/game/game_audio_manager.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STORE := "res://scenes/store.tscn"
const STATION := "res://scenes/ride_selection.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_profile()
	await _test_hubs(host)
	await _test_driving_and_results(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: shared normal/heavy rain audio, daytime/midnight hub loops, noncumulative music duck/restoration, independent SFX settings, station idle/terminal continuity, driving/result carry, pause and ownership")


static func _test_profile() -> void:
	assert(Profile.NORMAL_PATH.ends_with("ambience/rain.mp3") and Profile.HEAVY_PATH.ends_with("ambience/rain_loop.mp3"))
	assert(Profile.stream_for("rain") == Profile.NORMAL_STREAM and Profile.stream_for("heavy rain") == Profile.HEAVY_STREAM)
	assert(Profile.path_for("rain") == Profile.NORMAL_PATH and Profile.path_for("heavy rain") == Profile.HEAVY_PATH)
	assert(is_equal_approx(Profile.volume_db("rain"), -3.0) and is_equal_approx(Profile.volume_db("heavy rain"), -6.0))
	assert(is_equal_approx(Profile.music_duck_db("rain"), -8.0) and is_equal_approx(Profile.music_duck_db("heavy rain"), -12.0))
	for weather in ["clear", "cloudy"]:
		assert(Profile.stream_for(weather) == null and Profile.path_for(weather).is_empty())
		assert(is_zero_approx(Profile.music_duck_db(weather)))


static func _setup(midnight := false) -> void:
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time("night" if midnight else "noon")
	PlayerState.stage_round = 3
	PlayerState.money = 1000
	PlayerState.energy = 4
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	assert(WeatherState.set_story_weather(PlayerState, "clear"))
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)
	if midnight:
		PlayerState.set_last_stage_result({"day": 3, "time_of_day": "night", "completed": true, "total": 0})


static func _test_hubs(host: Node) -> void:
	var preferences := AudioSettingsManager.category_volumes.duplicate(true)
	for midnight in [false, true]:
		for path in [HOME, STORE, STATION]:
			_setup(midnight)
			var screen = load(path).instantiate()
			host.get_tree().root.add_child(screen)
			await host.get_tree().process_frame
			await host.get_tree().process_frame
			var rain: AudioStreamPlayer = screen.night_ambience.rain_player
			var music: AudioStreamPlayer = screen.view.bgm_player if path == STATION else screen.bgm_player
			var visit_remaining: float = screen.idle_music.idle_timer.time_left if path == STATION else 0.0
			for weather in ["clear", "cloudy", "rain", "heavy rain", "rain", "clear"]:
				assert(WeatherState.set_story_weather(PlayerState, weather))
				var original := _snapshot()
				_refresh(screen, path)
				_assert_rain(rain, weather)
				assert(music.playing == (not midnight))
				assert(is_equal_approx(AudioSettingsManager.get_player_base_db(music), Profile.music_duck_db(weather)))
				assert(screen.night_ambience.playing == midnight, "Daytime rain must not start the night ambience bed")
				var stream: AudioStream = rain.stream
				var playback = rain.get_stream_playback() if rain.playing else null
				_refresh(screen, path)
				assert(rain.stream == stream)
				if rain.playing:
					assert(rain.get_stream_playback() == playback, "Unchanged weather cannot restart its rain loop")
				assert(is_equal_approx(AudioSettingsManager.get_player_base_db(music), Profile.music_duck_db(weather)), "Repeated refreshes cannot stack music ducking")
				assert(_snapshot() == original, "Refreshing cached rain audio cannot save, spend resources or change time/weather")
				if path == STATION:
					assert(is_equal_approx(screen.idle_music.idle_timer.time_left, visit_remaining), "Weather changes cannot reset the station visit timer")
				if not midnight and path == HOME and weather == "rain":
					_test_audio_categories(rain, music)
			if path == STATION:
				_test_station_idle(screen)
				for view in [screen.station, screen.terminal_view]:
					assert(view.weather_effects.find_children("*", "AudioStreamPlayer", true, false).is_empty(), "Visual rain helpers cannot add duplicate audio")
			assert(WeatherState.set_story_weather(PlayerState, "heavy rain"))
			_refresh(screen, path)
			host.get_tree().paused = true
			await host.get_tree().process_frame
			assert(rain.stream_paused)
			host.get_tree().paused = false
			var reference: WeakRef = weakref(rain)
			screen.free()
			assert(reference.get_ref() == AmbientAudioManager.rain_player, "Rain survives scene-local music and controls")
	assert(AudioSettingsManager.category_volumes == preferences, "Rain never rewrites the player's category preferences")


static func _test_station_idle(station) -> void:
	station.idle_music._on_idle_timeout()
	assert(station.idle_music.active and not station.view.bgm_player.playing)
	var player: AudioStreamPlayer = station.idle_music.player
	var source: AudioStream = player.stream
	var playback = player.get_stream_playback()
	var track_base := AudioSettingsManager.get_player_base_db(player)
	for weather in ["rain", "heavy rain", "clear"]:
		assert(WeatherState.set_story_weather(PlayerState, weather))
		station._refresh_terminal()
		assert(player.stream == source and player.get_stream_playback() == playback and player.playing)
		assert(station.idle_music.idle_timer.is_stopped() and not station.view.bgm_player.playing)
		assert(is_equal_approx(AudioSettingsManager.get_player_base_db(player), track_base + Profile.music_duck_db(weather)))
	assert(WeatherState.set_story_weather(PlayerState, "rain"))
	station._refresh_terminal()
	var rain: AudioStreamPlayer = station.night_ambience.rain_player
	var rain_source: AudioStream = rain.stream
	var rain_playback = rain.get_stream_playback()
	station._open_passengers()
	station._close_passengers()
	assert(station.night_ambience.rain_player == rain and rain.stream == rain_source and rain.get_stream_playback() == rain_playback, "Street and terminal share one uninterrupted rain player")


static func _test_audio_categories(rain: AudioStreamPlayer, music: AudioStreamPlayer) -> void:
	var music_volume := AudioSettingsManager.get_category_volume("music")
	var sfx_volume := AudioSettingsManager.get_category_volume("sfx")
	var rain_db := rain.volume_db
	var music_db := music.volume_db
	AudioSettingsManager.set_category_volume("music", 0.0)
	assert(music.volume_db <= AudioSettingsManager.SILENCE_DB and is_equal_approx(rain.volume_db, rain_db))
	AudioSettingsManager.set_category_volume("music", music_volume)
	AudioSettingsManager.set_category_volume("sfx", 0.0)
	assert(rain.volume_db <= AudioSettingsManager.SILENCE_DB and is_equal_approx(music.volume_db, music_db))
	AudioSettingsManager.set_category_volume("sfx", sfx_volume)


static func _test_driving_and_results(host: Node) -> void:
	for weather in ["rain", "heavy rain"]:
		_setup()
		var owner := Node.new()
		host.get_tree().root.add_child(owner)
		var audio := DrivingAudio.new()
		owner.add_child(audio)
		audio.setup(owner)
		var rng := RandomNumberGenerator.new()
		rng.seed = 771
		audio.start_stage_bgm("noon", "traffic-jam", rng)
		audio.start_rain_loop_bgm(weather)
		_assert_rain(audio.rain_loop_bgm_player, weather)
		assert(is_equal_approx(AudioSettingsManager.get_player_base_db(audio.stage_bgm_player), Profile.music_duck_db(weather)))
		var playback = audio.rain_loop_bgm_player.get_stream_playback()
		audio.start_rain_loop_bgm(weather)
		assert(audio.rain_loop_bgm_player.get_stream_playback() == playback)
		var carry := audio.get_result_music_carry_state()
		assert(carry.rain_path == Profile.path_for(weather))
		assert(is_equal_approx(float(carry.rain_base_db), Profile.volume_db(weather)))
		assert(is_equal_approx(float(carry.stage_base_db), Profile.music_duck_db(weather)))
		assert(absf(float(carry.rain_position) - audio.rain_loop_bgm_player.get_playback_position()) < 0.1)
		audio.start_rain_loop_bgm("clear")
		assert(not audio.rain_loop_bgm_player.playing and is_zero_approx(AudioSettingsManager.get_player_base_db(audio.stage_bgm_player)))
		audio.start_rain_loop_bgm(weather)
		var shared_rain: AudioStreamPlayer = audio.rain_loop_bgm_player
		var shared_playback = shared_rain.get_stream_playback()
		assert(shared_rain == AmbientAudioManager.rain_player)
		owner.free()
		assert(shared_rain.playing and shared_rain.get_stream_playback() == shared_playback, "Driving scene-local audio disposal cannot restart or free rain")
		for midnight in [false, true]:
			_setup(midnight)
			PlayerState.set_pending_result_music(carry)
			var results = load("res://scenes/stage_results.tscn").instantiate()
			host.get_tree().root.add_child(results)
			await host.get_tree().process_frame
			var rain: AudioStreamPlayer = AmbientAudioManager.rain_player
			assert(results.get_node_or_null("StageResultsRainLoopPlayer") == null)
			_assert_rain(rain, weather)
			var music := results.get_node_or_null("StageResultsBGMPlayer") as AudioStreamPlayer
			assert((music == null) == midnight)
			if music != null:
				assert(music.playing and is_equal_approx(AudioSettingsManager.get_player_base_db(music), Profile.music_duck_db(weather)))
			assert(PlayerState.pending_result_music.is_empty())
			results.free()


static func _assert_rain(player: AudioStreamPlayer, weather: String) -> void:
	var wet := weather == "rain" or weather == "heavy rain"
	assert(player.playing == wet)
	assert(player.get_meta("audio_category") == "sfx")
	if wet:
		var stream := player.stream as AudioStreamMP3
		var source: AudioStreamMP3 = Profile.stream_for(weather)
		assert(stream != null and stream.loop and stream != source)
		assert(stream.data == source.data and not source.loop)
		assert(is_equal_approx(AudioSettingsManager.get_player_base_db(player), Profile.volume_db(weather)))


static func _refresh(screen, path: String) -> void:
	if path == HOME:
		screen._render_day_start()
	elif path == STORE:
		screen._refresh_header()
	else:
		screen._refresh_terminal()


static func _snapshot() -> Dictionary:
	return {"money": PlayerState.money, "energy": PlayerState.energy, "gas": PlayerState.gas, "day": PlayerState.current_day, "phase": PlayerState.current_phase, "round": PlayerState.stage_round, "weather": PlayerState.current_weather, "cache": PlayerState.weather_phase_cache.duplicate(true), "saves": int(PlayerState.get_meta("test_save_count", 0))}
