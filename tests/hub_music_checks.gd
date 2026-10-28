extends RefCounted

const WeatherState := preload("res://scripts/state/player_weather_state.gd")
const RainProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STORE := "res://scenes/store.tscn"
const SELECTION := "res://scenes/ride_selection.tscn"
const MENU := "res://scenes/main_menu.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false), "Use the isolated runner to protect real saves")
	await _test_map_and_store_continuity(host)
	await _test_weather_priority(host)
	await _test_bar_and_midnight(host)
	HubMusicManager.stop_all()
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: persistent hub music across real market/street/store travel, food/mechanic gates and theme resume, day rain/night rain priority, pause, bar suspension, midnight AFK precedence and unsupported-scene shutdown")


static func _setup(phase := "morning", weather := "clear", midnight := false) -> void:
	HubMusicManager.stop_all()
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time(phase)
	PlayerState.stage_round = 4
	PlayerState.money = 1000
	PlayerState.energy = 5
	PlayerState.gas = 80.0
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	assert(WeatherState.set_story_weather(PlayerState, weather))
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)
	var rider: Dictionary = PlayerState.get_character_by_id("generic_guy")
	rider.merge({
		"stage_traffic": "chill",
		"stage_special_type": PlayerState.STAGE_SPECIAL_TYPE_NONE,
		"special_stage_id": "",
		"pickup_location": "station",
		"pickup_variant": "",
	}, true)
	PlayerState.lock_pending_trip_selection({"short": [rider], "medium": [], "long": []}, "short")
	if midnight:
		PlayerState.set_last_stage_result({"day": 3, "time_of_day": "night", "completed": true})


static func _scene(host: Node, path: String) -> Variant:
	host.get_tree().change_scene_to_file(path)
	await host.get_tree().scene_changed
	return host.get_tree().current_scene


static func _budget() -> Array:
	return [PlayerState.money, PlayerState.energy, PlayerState.stress, PlayerState.hull, PlayerState.gas, PlayerState.current_day, PlayerState.stage_round]


static func _assert_track(path: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = HubMusicManager.player
	assert(player != null and player.playing and not player.stream_paused)
	assert(HubMusicManager.current_path == path)
	assert(player.get_parent() == HubMusicManager and HubMusicManager.get_parent() == (Engine.get_main_loop() as SceneTree).root)
	assert(player.get_meta("audio_category") == "music" and (player.stream as AudioStreamMP3).loop)
	return player


static func _assert_uninterrupted(player: AudioStreamPlayer, source: AudioStream, playback) -> void:
	assert(HubMusicManager.player == player and player.playing and not player.stream_paused)
	assert(player.stream == source and player.get_stream_playback() == playback, "Matching hub tracks must keep the same stream and playback object")


static func _test_map_and_store_continuity(host: Node) -> void:
	_setup()
	var original := _budget()
	var home = await _scene(host, HOME)
	var player := _assert_track(HubMusicManager.HOME_PATH)
	assert(home.bgm_player == player)
	home._open_map()
	_assert_track(HubMusicManager.DEFAULT_PATH)
	var source: AudioStream = player.stream
	var playback = player.get_stream_playback()
	home.home_map.map_view.buttons.market.pressed.emit()
	await host.get_tree().scene_changed
	var selection = host.get_tree().current_scene
	assert(selection.scene_file_path == SELECTION and selection.pickup_location == "market" and selection.view.bgm_player == player)
	_assert_uninterrupted(player, source, playback)
	selection._close_passengers(false)
	selection._open_map()
	selection.travel_map.map_view.buttons.street.pressed.emit()
	await host.get_tree().scene_changed
	selection = host.get_tree().current_scene
	assert(selection.pickup_location == "street" and selection.view.bgm_player == player)
	_assert_uninterrupted(player, source, playback)
	selection._open_store()
	await host.get_tree().scene_changed
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == STORE and store.bgm_player == player)
	_assert_uninterrupted(player, source, playback)
	store._open_shop("food")
	assert(store.shop_overlay.visible and store.active_category == "food")
	_assert_uninterrupted(player, source, playback)
	store.hub_dialogue.clear()
	store._close_shop()
	_assert_uninterrupted(player, source, playback)
	# A known position makes a reset distinguishable from a restored theme,
	# without waiting for the song to play in real time.
	player.seek(1.0)
	await host.get_tree().process_frame
	var position: float = player.get_playback_position()
	store._open_shop("tricycle")
	assert(_assert_track(HubMusicManager.MECHANIC_PATH) == player and player.stream != source)
	store.hub_dialogue.clear()
	store._close_shop()
	assert(_assert_track(HubMusicManager.DEFAULT_PATH) == player and player.stream == source)
	assert(player.get_playback_position() + 0.02 >= position, "Closing the mechanic resumes the previous background theme rather than starting it over")
	playback = player.get_stream_playback()
	store._refresh_header()
	_assert_uninterrupted(player, source, playback)
	host.get_tree().paused = true
	await host.get_tree().process_frame
	assert(player.stream_paused and player.get_stream_playback() == playback)
	host.get_tree().paused = false
	await host.get_tree().process_frame
	_assert_uninterrupted(player, source, playback)
	assert(_budget() == original, "Music/navigation/shop browsing cannot spend resources or advance the clock")
	await _scene(host, MENU)
	assert(HubMusicManager.player == player and not player.playing, "Leaving supported hubs stops music without deleting the persistent player")


static func _test_weather_priority(host: Node) -> void:
	_setup("noon")
	var original := _budget()
	var store = await _scene(host, STORE)
	var player := _assert_track(HubMusicManager.DEFAULT_PATH)
	var source: AudioStream = player.stream
	var playback = player.get_stream_playback()
	assert(WeatherState.set_story_weather(PlayerState, "rain"))
	store._refresh_header()
	_assert_uninterrupted(player, source, playback)
	assert(is_equal_approx(AudioSettingsManager.get_player_base_db(player), RainProfile.music_duck_db("rain")), "Day rain ducks the current background without selecting the night theme")
	PlayerState.set_current_stage_time("night")
	store._refresh_header()
	_assert_track(HubMusicManager.RAINY_NIGHT_PATH)
	source = player.stream
	playback = player.get_stream_playback()
	for category: String in ["food", "tricycle"]:
		store._open_shop(category)
		assert(store.shop_overlay.visible)
		_assert_uninterrupted(player, source, playback)
		assert(HubMusicManager.current_path == HubMusicManager.RAINY_NIGHT_PATH, "Rainy-night music overrides both shop categories")
		store.hub_dialogue.clear()
		store._close_shop()
		_assert_uninterrupted(player, source, playback)
	assert(WeatherState.set_story_weather(PlayerState, "heavy rain"))
	store._refresh_header()
	_assert_uninterrupted(player, source, playback)
	assert(WeatherState.set_story_weather(PlayerState, "clear"))
	store._refresh_header()
	assert(not player.playing, "Clear nights have no default background music")
	store._open_shop("tricycle")
	_assert_track(HubMusicManager.MECHANIC_PATH)
	assert(WeatherState.set_story_weather(PlayerState, "rain"))
	store._refresh_header()
	_assert_track(HubMusicManager.RAINY_NIGHT_PATH)
	PlayerState.set_current_stage_time("morning")
	store._refresh_header()
	_assert_track(HubMusicManager.MECHANIC_PATH)
	assert(_budget() == original, "Weather/phase requests change music without buying items or advancing a stage")
	await _scene(host, MENU)


static func _test_bar_and_midnight(host: Node) -> void:
	_setup("night")
	var home = await _scene(host, HOME)
	var player: AudioStreamPlayer = HubMusicManager.player
	assert(not player.playing, "Clear-night home interiors have no default music")
	home._open_map()
	assert(not player.playing, "Clear-night maps and outdoor locations stay silent")
	var world = home.home_map
	world.map_view.buttons.bar.pressed.emit()
	assert(world.travel_confirmation.visible)
	world.travel_confirmation.confirm_button.pressed.emit()
	world.entrance_button.pressed.emit()
	assert(world.bar_audio.active and world.bar_audio.music_player.playing and not player.playing, "The bar track has priority over shared background music")
	world.exit_button.pressed.emit()
	assert(not world.bar_audio.active and not world.bar_audio.music_player.playing)
	assert(not player.playing, "Leaving the bar returns to nighttime ambience without background music")
	await _scene(host, MENU)
	_setup("night", "rain", true)
	var station = await _scene(host, SELECTION)
	assert(station.view.bgm_player == player and not player.playing, "Midnight blocks rainy-night background music")
	station._open_passengers()
	station.idle_music._on_idle_timeout()
	assert(station.idle_music.active and station.idle_music.player.playing and not player.playing, "The midnight passenger AFK track plays alone above the blocked background")
	var idle_playback = station.idle_music.player.get_stream_playback()
	station._refresh_terminal()
	assert(station.idle_music.player.get_stream_playback() == idle_playback and not player.playing)
	station._close_passengers()
	assert(not station.idle_music.active and not station.idle_music.player.playing and not player.playing)
	await _scene(host, MENU)
	var menu = host.get_tree().current_scene
	host.get_tree().current_scene = null
	menu.free()
	await host.get_tree().process_frame
