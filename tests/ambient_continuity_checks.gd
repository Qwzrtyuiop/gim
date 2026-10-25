extends RefCounted

const Ambience := preload("res://scripts/ui/hub_night_ambience.gd")
const WeatherState := preload("res://scripts/state/player_weather_state.gd")
const RainProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STORE := "res://scenes/store.tscn"
const STATION := "res://scenes/ride_selection.tscn"
const MENU := "res://scenes/main_menu.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time("night")
	PlayerState.stage_round = 3
	PlayerState.money = 1000
	PlayerState.energy = 5
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	assert(WeatherState.set_story_weather(PlayerState, "rain"))
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)
	var original := _snapshot()
	var manager_id: int = AmbientAudioManager.get_instance_id()
	host.get_tree().change_scene_to_file(HOME)
	await host.get_tree().scene_changed
	var home = host.get_tree().current_scene
	assert(home.scene_file_path == HOME and home.night_ambience == AmbientAudioManager)
	var rain: AudioStreamPlayer = AmbientAudioManager.rain_player
	var night_playback = AmbientAudioManager.get_stream_playback()
	var rain_playback = rain.get_stream_playback()
	var rain_source: AudioStream = rain.stream
	var dog_deadline: float = AmbientAudioManager.dog_check_timer.time_left
	var previous_position := Vector2(AmbientAudioManager.get_playback_position(), rain.get_playback_position())
	assert(AmbientAudioManager.playing and rain.playing and not AmbientAudioManager.cars_player.playing)
	AmbientAudioManager._rng.seed = _dog_hit_seed()
	AmbientAudioManager._on_dog_check()
	assert(AmbientAudioManager.dogs_player.playing)
	var dog_playback = AmbientAudioManager.dogs_player.get_stream_playback()
	var dog_remaining: float = AmbientAudioManager.dog_stop_timer.time_left
	var home_music: WeakRef = weakref(home.bgm_player)
	home._show_info("outside")
	home.outside_buttons[0].pressed.emit()
	await host.get_tree().scene_changed
	var station = host.get_tree().current_scene
	assert(station.scene_file_path == STATION and home_music.get_ref() == null)
	_assert_shared(manager_id, night_playback, rain_playback, rain_source, previous_position)
	assert(AmbientAudioManager.cars_player.playing)
	assert(AmbientAudioManager.dog_check_timer.time_left <= dog_deadline)
	assert(AmbientAudioManager.dog_stop_timer.time_left <= dog_remaining)
	if AmbientAudioManager.dogs_player.playing:
		assert(AmbientAudioManager.dogs_player.get_stream_playback() == dog_playback, "A bark already playing must not restart between hubs")
	var cars_playback = AmbientAudioManager.cars_player.get_stream_playback()
	station._open_passengers()
	station._refresh_terminal()
	station._close_passengers()
	assert(AmbientAudioManager.cars_player.get_stream_playback() == cars_playback)
	_assert_no_local_ambience(station)
	var station_music: WeakRef = weakref(station.view.bgm_player)
	previous_position = Vector2(AmbientAudioManager.get_playback_position(), rain.get_playback_position())
	station._open_store()
	await host.get_tree().scene_changed
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == STORE and station_music.get_ref() == null)
	_assert_shared(manager_id, night_playback, rain_playback, rain_source, previous_position)
	assert(not AmbientAudioManager.cars_player.playing)
	_assert_no_local_ambience(store)
	store._refresh_header()
	var store_music: WeakRef = weakref(store.bgm_player)
	previous_position = Vector2(AmbientAudioManager.get_playback_position(), rain.get_playback_position())
	store.street.buttons.home.pressed.emit()
	await host.get_tree().scene_changed
	home = host.get_tree().current_scene
	assert(home.scene_file_path == HOME and store_music.get_ref() == null)
	_assert_shared(manager_id, night_playback, rain_playback, rain_source, previous_position)
	_assert_no_local_ambience(home)
	assert(_snapshot() == original, "Walking between hubs only changes navigation state, never resources, weather, progress, events or preferences")
	host.get_tree().paused = true
	var remaining: float = AmbientAudioManager.dog_check_timer.time_left
	await host.get_tree().process_frame
	assert(AmbientAudioManager.stream_paused and rain.stream_paused)
	assert(is_equal_approx(AmbientAudioManager.dog_check_timer.time_left, remaining))
	host.get_tree().paused = false
	assert(WeatherState.set_story_weather(PlayerState, "heavy rain"))
	home._render_day_start()
	assert(AmbientAudioManager.get_stream_playback() == night_playback)
	assert(rain.get_stream_playback() != rain_playback and rain.stream != rain_source)
	assert((rain.stream as AudioStreamMP3).data == RainProfile.HEAVY_STREAM.data)
	rain_playback = rain.get_stream_playback()
	rain_source = rain.stream
	home._render_day_start()
	assert(rain.get_stream_playback() == rain_playback and rain.stream == rain_source, "Only a changed rain track may replace playback")
	# Shared rain and the night bed also continue through driving/results handoff.
	AmbientAudioManager.enter_drive("heavy rain", "night")
	assert(AmbientAudioManager.get_stream_playback() == night_playback and rain.get_stream_playback() == rain_playback)
	assert(not AmbientAudioManager.dogs_player.playing and not AmbientAudioManager.cars_player.playing and AmbientAudioManager.dog_check_timer.is_stopped())
	AmbientAudioManager.enter_results({"rain_path": RainProfile.HEAVY_PATH, "rain_position": 0.0, "rain_base_db": RainProfile.volume_db("heavy rain")})
	assert(AmbientAudioManager.get_stream_playback() == night_playback and rain.get_stream_playback() == rain_playback, "Result carry cannot seek or duplicate an already running rain loop")
	host.get_tree().change_scene_to_file(MENU)
	await host.get_tree().scene_changed
	assert(host.get_tree().current_scene.scene_file_path == MENU)
	assert(not AmbientAudioManager.playing and not rain.playing and not AmbientAudioManager.dogs_player.playing and not AmbientAudioManager.cars_player.playing)
	assert(AmbientAudioManager.dog_check_timer.is_stopped() and AmbientAudioManager.dog_stop_timer.is_stopped())
	assert(AmbientAudioManager.get_instance_id() == manager_id and AmbientAudioManager.get_parent() == host.get_tree().root)
	var menu = host.get_tree().current_scene
	host.get_tree().current_scene = null
	menu.free()
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: shared ambience playback and dog cadence across actual home/station/store navigation, local music ownership, changed-weather replacement only, driving/results reuse, pause and unsupported-scene shutdown")


static func _assert_shared(manager_id: int, night_playback, rain_playback, rain_source: AudioStream, previous_position: Vector2) -> void:
	assert(AmbientAudioManager.get_instance_id() == manager_id)
	assert(AmbientAudioManager.playing and AmbientAudioManager.rain_player.playing)
	assert(AmbientAudioManager.get_stream_playback() == night_playback and AmbientAudioManager.rain_player.get_stream_playback() == rain_playback, "Scene changes preserve the exact playback objects")
	assert(AmbientAudioManager.rain_player.stream == rain_source)
	assert(AmbientAudioManager.get_playback_position() + 0.02 >= previous_position.x)
	assert(AmbientAudioManager.rain_player.get_playback_position() + 0.02 >= previous_position.y)


static func _assert_no_local_ambience(scene: Node) -> void:
	for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false):
		assert(player.name not in ["HubNightAmbience", "NightDogs", "NightCars", "RainAmbience", "StageResultsRainLoopPlayer"])


static func _dog_hit_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(10000):
		probe.seed = candidate
		if probe.randf() < Ambience.DOG_PLAY_CHANCE:
			return candidate
	assert(false)
	return 0


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"progress": PlayerState.unique_character_progress.duplicate(true),
		"events": PlayerState.event_values.duplicate(true),
		"weather": PlayerState.weather_phase_cache.duplicate(true),
		"preferences": AudioSettingsManager.category_volumes.duplicate(true),
	}
