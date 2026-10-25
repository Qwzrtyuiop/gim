extends RefCounted

const IdleMusic := preload("res://scripts/ui/station_idle_music.gd")
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STORE := "res://scenes/store.tscn"
const STATION := "res://scenes/ride_selection.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	for phase in ["noon", "midnight"]:
		for index in range(IdleMusic.TRACKS.size()):
			await _test_station(host, phase, index)
	for path in [HOME, STORE]:
		_setup("noon")
		var screen = load(path).instantiate()
		host.get_tree().root.add_child(screen)
		await host.get_tree().process_frame
		for child in screen.get_children():
			assert(not child is IdleMusic, "Only the station owns an AFK music clock")
		screen.free()
	PlayerState.reset()
	print("PASS: sixty-second station visits, both seeded looping tracks, input/terminal/confirmation continuity, normal-track exclusion, midnight exception, paused/blocked entry, isolated RNG/state and scene ownership")


static func _setup(phase: String) -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time("night" if phase == "midnight" else phase)
	PlayerState.stage_round = 3
	PlayerState.money = 1000
	PlayerState.energy = 4
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)
	if phase == "midnight":
		PlayerState.set_last_stage_result({"day": 3, "time_of_day": "night", "completed": true})


static func _test_station(host: Node, phase: String, track_index: int) -> void:
	_setup(phase)
	var station = load(STATION).instantiate()
	host.get_tree().root.add_child(station)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var idle: IdleMusic = station.idle_music
	assert(not idle.active and not idle.player.playing)
	assert(idle.idle_timer.one_shot and is_equal_approx(idle.idle_timer.wait_time, 60.0))
	assert(idle.idle_timer.time_left > 59.0 and idle.idle_timer.time_left <= 60.0)
	assert(idle.player.get_meta("audio_category") == "music")
	assert(station.view.bgm_player.playing == (phase != "midnight"))
	# Staying at the station counts toward the visit even while using its UI.
	var remaining: float = idle.idle_timer.time_left
	for event: InputEvent in _activity_events():
		station._input(event)
		assert(not idle.active and is_equal_approx(idle.idle_timer.time_left, remaining), "Input must not reset the station visit clock")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(5, 5)
	motion.relative = Vector2(2, 0)
	host.get_viewport().push_input(motion, true)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	assert(idle.idle_timer.time_left <= remaining, "Real pointer movement cannot postpone the music")
	remaining = idle.idle_timer.time_left
	_exercise_terminal(station)
	assert(not idle.active and is_equal_approx(idle.idle_timer.time_left, remaining), "Terminal and confirmation interactions share the original visit clock")
	host.get_tree().paused = true
	remaining = idle.idle_timer.time_left
	await host.get_tree().process_frame
	idle._on_idle_timeout()
	assert(not idle.active and is_equal_approx(idle.idle_timer.time_left, remaining), "Pause freezes the visit clock and rejects manual expiry callbacks")
	host.get_tree().paused = false
	station.is_departing = true
	idle._on_idle_timeout()
	assert(not idle.active and not idle.player.playing, "Departing stations cannot start a visit track")
	station.is_departing = false
	var original := _snapshot()
	idle._rng.seed = _seed_for_index(track_index)
	seed(92833)
	var expected_random := randf()
	seed(92833)
	idle.idle_timer.timeout.emit()
	assert(randf() == expected_random, "Visit track selection must not consume gameplay RNG")
	assert(idle.active and idle.player.playing and not station.view.bgm_player.playing)
	assert(idle.idle_timer.is_stopped())
	var source: AudioStreamMP3 = IdleMusic.TRACKS[track_index].stream
	var playing_stream := idle.player.stream as AudioStreamMP3
	assert(playing_stream != null and playing_stream.loop)
	assert(playing_stream != source and not source.loop)
	assert(playing_stream.data == source.data, "Each fresh visit can select the corresponding seeded track")
	assert(is_equal_approx(AudioSettingsManager.get_player_base_db(idle.player), float(IdleMusic.TRACKS[track_index].base_db) + RainAudioProfile.music_duck_db(PlayerState.get_current_weather())))
	var random_state: int = idle._rng.state
	idle._on_idle_timeout()
	station._refresh_terminal()
	assert(idle._rng.state == random_state and idle.player.stream == playing_stream and idle.active and not station.view.bgm_player.playing, "Repeated callbacks and refreshes keep the same looping track")
	assert(_snapshot() == original, "Visit music does not save, advance the clock, spend resources or consume stories")
	if phase == "midnight":
		assert(station.night_ambience.playing and station.night_ambience.cars_player.playing, "Visit music layers over midnight ambience")
	_exercise_terminal(station)
	for event: InputEvent in _activity_events():
		station._input(event)
		assert(idle.active and idle.player.playing and idle.player.stream == playing_stream and idle.idle_timer.is_stopped())
	host.get_viewport().push_input(motion, true)
	await host.get_tree().process_frame
	assert(idle.active and idle.player.playing and not station.view.bgm_player.playing, "Pointer movement and UI interaction cannot stop music during a station visit")
	host.get_tree().paused = true
	await host.get_tree().process_frame
	assert(idle.player.stream_paused)
	host.get_tree().paused = false
	var references: Array[WeakRef] = [weakref(idle), weakref(idle.player), weakref(idle.idle_timer)]
	station.free()
	for reference: WeakRef in references:
		assert(reference.get_ref() == null, "Scene changes free the idle player and timer")


static func _exercise_terminal(station) -> void:
	var music = station.idle_music
	var player_id: int = music.player.get_instance_id()
	station._open_passengers()
	assert(station.passenger_overlay.visible)
	if not station.terminal_offers.is_empty():
		var offer: Dictionary = station.terminal_offers[0]
		station._choose_offer(str(offer.distance), int(offer.slot))
		assert(station.confirmation.visible)
		station.confirmation.cancel_button.pressed.emit()
		assert(not station.confirmation.visible)
	station._close_passengers()
	assert(music.player.get_instance_id() == player_id)
	if music.active:
		assert(music.player.playing and not station.view.bgm_player.playing, "Terminal/confirmation interactions keep the visit's chosen music")


static func _activity_events() -> Array[InputEvent]:
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(1, 0)
	var button := InputEventJoypadButton.new()
	button.pressed = true
	var axis := InputEventJoypadMotion.new()
	axis.axis_value = 0.6
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0, 1)
	var action := InputEventAction.new()
	action.action = "ui_right"
	action.pressed = true
	return [key, click, motion, button, axis, touch, drag, action]


static func _seed_for_index(index: int) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(10000):
		probe.seed = candidate
		if probe.randi_range(0, IdleMusic.TRACKS.size() - 1) == index:
			return candidate
	assert(false, "Each idle track must be reachable")
	return 0


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"round": PlayerState.stage_round,
		"events": PlayerState.event_values.duplicate(true),
		"pending": PlayerState.get_pending_trip_selection(),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}
