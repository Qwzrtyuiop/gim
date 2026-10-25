extends RefCounted

const Ambience := preload("res://scripts/ui/hub_night_ambience.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STORE := "res://scenes/store.tscn"
const STATION := "res://scenes/ride_selection.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_hub_layers(host)
	await _test_dog_rolls(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: layered night/midnight hub ambience, station/terminal car continuity, five-second independent dog RNG, bounded non-overlapping barks, phase/pause gates, SFX volume and scene cleanup")


static func _setup(phase: String) -> void:
	AmbientAudioManager.stop_all()
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


static func _test_hub_layers(host: Node) -> void:
	for phase in ["noon", "night", "midnight"]:
		for scene_path in [HOME, STORE, STATION]:
			_setup(phase)
			var screen = load(scene_path).instantiate()
			host.get_tree().root.add_child(screen)
			await host.get_tree().process_frame
			await host.get_tree().process_frame
			var audio: Ambience = screen.night_ambience
			var night: bool = phase != "noon"
			assert(audio.playing == night)
			assert(audio.cars_player.playing == (night and scene_path == STATION))
			assert(audio.traffic_enabled == (scene_path == STATION))
			assert(audio.dog_check_timer.is_stopped() == (not night))
			assert(is_equal_approx(audio.dog_check_timer.wait_time, 5.0) and not audio.dog_check_timer.one_shot)
			assert(audio.dog_stop_timer.one_shot and audio.dog_stop_timer.is_stopped())
			assert(not audio.dogs_player.playing, "Night entry waits for the first five-second roll")
			assert(audio.stream.loop and audio.cars_player.stream.loop and not audio.dogs_player.stream.loop)
			assert(audio.cars_player.stream != Ambience.CARS_STREAM and not Ambience.CARS_STREAM.loop)
			assert(audio.dogs_player.stream != Ambience.DOGS_STREAM and not Ambience.DOGS_STREAM.loop)
			for layer: AudioStreamPlayer in [audio, audio.dogs_player, audio.cars_player]:
				assert(layer.get_meta("audio_category") == "sfx")
			if night:
				var remaining: float = audio.dog_check_timer.time_left
				assert(remaining > 4.0 and remaining <= 5.0)
				audio.refresh()
				assert(is_equal_approx(audio.dog_check_timer.time_left, remaining), "Refreshing a hub must not postpone the next dog roll")
			if night and scene_path == STATION:
				var cars_id: int = audio.cars_player.get_instance_id()
				var remaining: float = audio.dog_check_timer.time_left
				screen._open_passengers()
				assert(screen.passenger_overlay.visible and audio.cars_player.playing and audio.playing)
				screen._close_passengers()
				assert(audio.cars_player.get_instance_id() == cars_id and audio.cars_player.playing)
				assert(is_equal_approx(audio.dog_check_timer.time_left, remaining), "Terminal overlays share the station's running layers and timers")
			if phase == "midnight":
				var music: AudioStreamPlayer = screen.view.bgm_player if scene_path == STATION else screen.bgm_player
				assert(not music.playing, "Additional ambience cannot bring midnight music back")
			var references: Array[WeakRef] = []
			for owned in [audio, audio.dogs_player, audio.cars_player, audio.dog_check_timer, audio.dog_stop_timer]:
				references.append(weakref(owned))
			screen.free()
			for reference: WeakRef in references:
				assert(reference.get_ref() != null, "Shared ambience players and timers survive hub scene disposal")
			assert(audio == AmbientAudioManager and audio.get_parent() == host.get_tree().root)


static func _test_dog_rolls(host: Node) -> void:
	_setup("night")
	var audio := Ambience.new()
	audio.traffic_enabled = true
	host.get_tree().root.add_child(audio)
	await host.get_tree().process_frame
	for burst: Vector2 in Ambience.DOG_BURSTS:
		assert(burst.x >= 0.0 and burst.y <= Ambience.DOGS_STREAM.get_length())
		assert(burst.y > burst.x and burst.y - burst.x < Ambience.DOG_CHECK_INTERVAL)
	var original := _snapshot()
	var hit_seed := _seed_for(true)
	var miss_seed := _seed_for(false)
	audio._rng.seed = miss_seed
	audio.dog_check_timer.timeout.emit()
	assert(not audio.dogs_player.playing and audio.dog_stop_timer.is_stopped(), "A failed roll stays silent")
	audio._rng.seed = hit_seed
	seed(86420)
	var expected_random := randf()
	seed(86420)
	audio.dog_check_timer.timeout.emit()
	assert(randf() == expected_random, "Dog rolls must not consume the game's passenger/traffic RNG")
	assert(audio.dogs_player.playing and not audio.dog_stop_timer.is_stopped())
	assert(audio.dog_stop_timer.time_left > 0.0 and audio.dog_stop_timer.time_left < 5.0)
	assert(audio.playing and audio.cars_player.playing, "A bark layers over the existing night and car loops")
	# A successful roll during a bark still occurs, but cannot restart or stack it.
	audio.dog_stop_timer.start(0.1)
	audio._rng.seed = hit_seed
	var probe := RandomNumberGenerator.new()
	probe.seed = hit_seed
	probe.randf()
	audio.dog_check_timer.timeout.emit()
	assert(audio._rng.state == probe.state)
	assert(audio.dog_stop_timer.time_left <= 0.1, "A busy dog player keeps the original excerpt's deadline")
	var sfx_volume := AudioSettingsManager.get_category_volume("sfx")
	AudioSettingsManager.set_category_volume("sfx", 0.0)
	for layer: AudioStreamPlayer in [audio, audio.dogs_player, audio.cars_player]:
		assert(layer.volume_db <= AudioSettingsManager.SILENCE_DB)
	AudioSettingsManager.set_category_volume("sfx", sfx_volume)
	host.get_tree().paused = true
	var remaining: float = audio.dog_check_timer.time_left
	var random_state: int = audio._rng.state
	await host.get_tree().process_frame
	assert(audio.stream_paused and audio.dogs_player.stream_paused and audio.cars_player.stream_paused)
	audio._on_dog_check()
	assert(audio._rng.state == random_state and is_equal_approx(audio.dog_check_timer.time_left, remaining))
	host.get_tree().paused = false
	audio.dog_stop_timer.timeout.emit()
	assert(not audio.dogs_player.playing and audio.dog_stop_timer.is_stopped(), "The excerpt deadline ends the bark, not the whole two-minute recording")
	assert(audio.playing and audio.cars_player.playing)
	assert(_snapshot() == original, "Ambience cannot spend resources, advance time, save or consume an event")
	PlayerState.set_current_stage_time("noon")
	audio._on_dog_check()
	assert(audio._rng.state == random_state)
	assert(not audio.playing and not audio.cars_player.playing and not audio.dogs_player.playing)
	assert(audio.dog_check_timer.is_stopped() and audio.dog_stop_timer.is_stopped())
	PlayerState.set_current_stage_time("night")
	audio.refresh()
	assert(audio.playing and audio.cars_player.playing and not audio.dogs_player.playing)
	assert(audio.dog_check_timer.time_left > 4.0, "A new night starts a fresh five-second cadence")
	audio.free()


static func _seed_for(hit: bool) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(10000):
		probe.seed = candidate
		if (probe.randf() < Ambience.DOG_PLAY_CHANCE) == hit:
			return candidate
	assert(false, "Both RNG outcomes must be reachable")
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
		"consumed": PlayerState.consumed_story_triggers.duplicate(true),
		"pending": PlayerState.get_pending_trip_selection(),
		"saves": int(PlayerState.get_meta("test_save_count", 0)),
	}
