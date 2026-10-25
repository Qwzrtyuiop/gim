extends RefCounted

const Economy := preload("res://scripts/game/game_economy_manager.gd")
const Departure := preload("res://scripts/ride_selection/ride_departure.gd")
const PassengerStory := preload("res://scripts/ride_selection/passenger_story.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Ambience := preload("res://scripts/ui/hub_night_ambience.gd")
const SelectionView := preload("res://scripts/ride_selection/selection_view.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const STATION := "res://scenes/ride_selection.tscn"
const STORE := "res://scenes/store.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_clock_and_resume()
	await _test_stale_confirmation(host)
	await _test_empty_terminal(host)
	await _test_midnight_walk_and_sleep(host)
	await _test_audio_lifecycle(host)
	await _test_result_music(host)
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: Midnight from dated night results/save reload, closed random/seeded/cached/story departures, stale confirmation, free home/station/store visits, sleep reopening, silent midnight music, result rain carry and owned night ambience/pause")


static func _setup(phase := "night") -> void:
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.set_current_stage_time(phase)
	PlayerState.stage_round = 3
	PlayerState.money = 1000
	PlayerState.energy = 4
	PlayerState.gas = 70
	PlayerState.home_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.ensure_daily_conditions_for_current_day()
	PlayerState.set_current_mock_character("generic_guy")
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)


static func _finish_night() -> void:
	Economy.store_stage_result("short-night-chill", "short", "night", "chill", "", "", 620, 620, 0.2, 0, 1, 8, 2, 0)


static func _test_clock_and_resume() -> void:
	_setup("noon")
	Economy.store_stage_result("short-noon-chill", "short", "noon", "chill", "", "", 620, 620, 0.2, 0, 1, 8, 2, 0)
	assert(PlayerState.get_current_time_of_day() == "night" and PlayerState.are_passengers_available())
	assert(PlayerState.get_hub_time_name() == "Night", "Reaching night after noon still permits the night's ride")
	_finish_night()
	assert(PlayerState.is_midnight() and not PlayerState.are_passengers_available())
	assert(PlayerState.get_hub_time_name() == "Midnight" and PlayerState.get_current_time_of_day() == "night")
	assert(PlayerState.get_hub_time_name(4, "morning") == "Morning")
	var path := "res://test_user/midnight_resume.tres"
	Codec.save_to_path(PlayerState, path, PlayerState.SAVE_VERSION)
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, path))
	assert(PlayerState.is_midnight() and not PlayerState.are_passengers_available(), "Existing result fields retain closure across save/reload")
	PlayerState.prepare_day_start(4)
	assert(not PlayerState.is_midnight() and PlayerState.are_passengers_available())
	PlayerState.set_current_stage_time("night")
	assert(PlayerState.get_hub_time_name() == "Night" and PlayerState.are_passengers_available(), "Yesterday's night result cannot close tonight")
	Economy.store_failed_stage_result("short-night-chill", "short", "night", "chill", "", "", 200, 620, "Out of fuel")
	assert(PlayerState.is_midnight(), "A trip that ended unsuccessfully still spent its night slot")
	_setup()
	PlayerState.last_stage_result = {"day": 3, "time_of_day": "noon", "bayanihan_skipped_phase": "night"}
	assert(PlayerState.is_midnight() and not PlayerState.are_passengers_available())
	PlayerState.last_stage_result.clear()
	PlayerState.set_pending_night_phase_skip(true)
	assert(not PlayerState.is_midnight() and not PlayerState.are_passengers_available(), "Reserved story nights cannot be bypassed through home either")


static func _test_stale_confirmation(host: Node) -> void:
	_setup()
	var station = await _scene(host, STATION)
	station._open_passengers()
	var offer: Dictionary = station.terminal_offers[0].duplicate(true)
	station._choose_offer(str(offer.distance), int(offer.slot))
	assert(station.confirmation.visible)
	_finish_night()
	var original := _snapshot()
	station.confirmation.confirm_button.pressed.emit()
	assert(not station.confirmation.visible and not station.is_departing)
	assert(station.terminal_offers.is_empty() and station.terminal_view.buttons.is_empty())
	assert(_snapshot() == original, "A stale confirmation cannot pay, advance or consume a story after closure")
	station._depart_with_offer(offer)
	assert(_snapshot() == original and not station.is_departing)
	station.free()


static func _test_empty_terminal(host: Node) -> void:
	_setup()
	var rider := PlayerState.get_character_by_id("generic_guy")
	rider.merge({"active_distance": "short", "stage_traffic": "chill"}, true)
	var pools := {"short": [rider], "medium": [], "long": []}
	PlayerState.lock_pending_trip_selection(pools, "short")
	PlayerState.seed_rider_for_stage("hana", 3, "night", "short")
	_finish_night()
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_RIDE)
	var consumed := PlayerState.consumed_seeded_rider_rules.duplicate(true)
	var seen := PlayerState.seen_mock_characters.duplicate(true)
	var station = await _scene(host, STATION)
	assert(station._transition_mode() == PlayerState.TRANSITION_CURRENT_STAGE)
	assert(station._display_day() == 3)
	station._open_passengers()
	assert(station.terminal_view.buttons.is_empty() and station.terminal_offers.is_empty())
	assert(station.status_header.day_label.text.contains("Midnight"))
	assert(station.status_label.text.to_lower().contains("midnight"))
	assert(PlayerState.get_locked_pending_trip_character_pools() == pools)
	assert(PlayerState.consumed_seeded_rider_rules == consumed and PlayerState.seen_mock_characters == seen)
	var original := _snapshot()
	assert(station.passenger_pool.roll() == {"short": [], "medium": [], "long": []})
	assert(PlayerState.get_seeded_rider_pool_setup({"day": 3, "time_of_day": "night"}).rule_ids.is_empty())
	for mode in [PlayerState.TRANSITION_CURRENT_STAGE, PlayerState.TRANSITION_RIDE, PlayerState.TRANSITION_REST_TO_NEXT_DAY]:
		assert(Departure.start(rider, "short", mode).scene.is_empty())
	assert(not PassengerStory.begin(PlayerState.get_character_by_id("jessa"), "short", PlayerState.TRANSITION_CURRENT_STAGE))
	assert(_snapshot() == original, "Closed random, seeded, cached and scripted entry paths have no effects")
	station.free()


static func _test_midnight_walk_and_sleep(host: Node) -> void:
	_setup()
	_finish_night()
	PlayerState.claim_last_stage_total()
	var original := _resources()
	var home = await _scene(host, HOME)
	assert(home.status_header.day_label.text.contains("Midnight"))
	home._show_info("outside")
	home.outside_buttons[0].pressed.emit()
	await host.get_tree().scene_changed
	var station = host.get_tree().current_scene
	assert(station.scene_file_path == STATION, "Home Ride goes to the station street, even at midnight")
	home.free()
	station._open_passengers()
	assert(station.terminal_view.buttons.is_empty() and station.passenger_overlay.visible)
	station._open_store()
	await host.get_tree().scene_changed
	var store = host.get_tree().current_scene
	assert(store.scene_file_path == STORE and store.street.is_night)
	assert(store.status_header.day_label.text.contains("Midnight"))
	store._open_shop("food")
	assert(not store.shop_overlay.visible and store.street.is_midnight, "Midnight stores remain closed while their exits stay available")
	store.street.buttons.home.pressed.emit()
	await host.get_tree().scene_changed
	home = host.get_tree().current_scene
	assert(home.scene_file_path == HOME and PlayerState.is_midnight())
	assert(_resources() == original, "Walking after midnight costs no energy, money, gas or turn")
	home._show_info("rest")
	home.rest_confirm.pressed.emit()
	await host.get_tree().scene_changed
	assert(host.get_tree().current_scene.scene_file_path == "res://scenes/sleep_transition.tscn")
	await host.get_tree().scene_changed
	home = host.get_tree().current_scene
	assert(home.scene_file_path == HOME and PlayerState.get_current_day() == 4)
	assert(PlayerState.are_passengers_available() and not PlayerState.is_midnight())
	assert(not home.night_ambience.playing)
	home._show_info("outside")
	home.outside_buttons[0].pressed.emit()
	await host.get_tree().scene_changed
	station = host.get_tree().current_scene
	station._open_passengers()
	assert(not station.terminal_view.buttons.is_empty(), "Sleeping reopens the terminal in the new morning")
	host.get_tree().current_scene = null
	station.free()


static func _test_audio_lifecycle(host: Node) -> void:
	for phase in ["noon", "night", "midnight"]:
		for scene_path in [HOME, STORE, STATION]:
			_setup("night" if phase == "midnight" else phase)
			if phase == "midnight":
				_finish_night()
			var screen = await _scene(host, scene_path)
			var audio: AudioStreamPlayer = screen.night_ambience
			var music: AudioStreamPlayer = screen.view.bgm_player if scene_path == STATION else screen.bgm_player
			assert(music.playing == (phase != "midnight"), "All hubs stop music at midnight; noon and ordinary night retain hub music")
			assert(audio.playing == (phase != "noon"))
			assert(audio.stream is AudioStreamMP3 and audio.stream.loop)
			assert(audio.get_meta("audio_category") == "sfx")
			assert(audio.stream != Ambience.NIGHT_STREAM and not Ambience.NIGHT_STREAM.loop)
			if phase == "midnight" and scene_path != HOME:
				if scene_path == STATION:
					screen._open_passengers()
					assert(screen.passenger_overlay.visible)
				else:
					screen._open_shop("food")
					assert(not screen.shop_overlay.visible)
				assert(not music.playing and audio.playing, "The midnight terminal and closed store keep ambience without music")
			if phase != "noon":
				host.get_tree().paused = true
				await host.get_tree().process_frame
				assert(audio.stream_paused)
				host.get_tree().paused = false
				audio.refresh()
				assert(audio.playing)
			var reference: WeakRef = weakref(audio)
			screen.free()
			assert(reference.get_ref() == AmbientAudioManager and audio.get_parent() == host.get_tree().root, "Hub ambience belongs to the persistent service, not the departing scene")
	for scene_path in [HOME, STORE, STATION]:
		_setup()
		var screen = await _scene(host, scene_path)
		var music: AudioStreamPlayer = screen.view.bgm_player if scene_path == STATION else screen.bgm_player
		assert(music.playing)
		_finish_night()
		if scene_path == STATION:
			screen._refresh_terminal()
		elif scene_path == HOME:
			screen._render_day_start()
		else:
			screen._refresh_header()
		assert(not music.playing and screen.night_ambience.playing, "Refreshing an open hub after night completion stops existing music and keeps ambience")
		screen.free()
	_setup("noon")
	var home = await _scene(host, HOME)
	home._show_info("rest")
	home.rest_confirm.pressed.emit()
	await host.get_tree().create_timer(0.7).timeout
	assert(PlayerState.get_current_time_of_day() == "night" and home.night_ambience.playing, "Resting into night at home starts the ambience without changing scene")
	home.free()


static func _test_result_music(host: Node) -> void:
	for completed_phase in ["noon", "night"]:
		_setup(completed_phase)
		if completed_phase == "night":
			_finish_night()
		else:
			Economy.store_stage_result("short-noon-chill", "short", "noon", "chill", "", "", 620, 620, 0.2, 0, 1, 8, 2, 0)
		assert(PlayerState.get_current_time_of_day() == "night")
		PlayerState.set_pending_result_music({
			"stage_path": SelectionView.RIDE_SELECT_BGM_PATH,
			"rain_path": "res://assets/audio/ambience/rain_loop.mp3",
		})
		var results = await _scene(host, "res://scenes/stage_results.tscn")
		var music := results.get_node_or_null("StageResultsBGMPlayer") as AudioStreamPlayer
		var rain: AudioStreamPlayer = AmbientAudioManager.rain_player
		assert(results.get_node_or_null("StageResultsRainLoopPlayer") == null, "Results reuse the shared rain rather than duplicating it")
		if completed_phase == "night":
			assert(music == null, "A completed night trip is already midnight on the results screen, so its stage music must not carry")
		else:
			assert(music != null and music.playing, "Noon results reaching ordinary night keep their carried stage music")
		assert(rain != null and rain.playing, "Rain ambience carries into results even at midnight")
		assert(PlayerState.pending_result_music.is_empty())
		var player_count: int = results.carried_music_players.size()
		results._start_carried_result_music()
		assert(results.carried_music_players.size() == player_count and PlayerState.pending_result_music.is_empty(), "The carried state is consumed once without duplicating audio players")
		results.free()


static func _resources() -> Dictionary:
	return {"money": PlayerState.money, "energy": PlayerState.energy, "gas": PlayerState.gas, "day": PlayerState.current_day, "phase": PlayerState.current_phase, "round": PlayerState.stage_round}


static func _snapshot() -> Dictionary:
	var values := _resources()
	values.merge({"pending": PlayerState.get_pending_trip_selection(), "story": PlayerState.get_pending_story(), "consumed": PlayerState.consumed_story_triggers.duplicate(true), "saves": int(PlayerState.get_meta("test_save_count", 0))})
	return values


static func _scene(host: Node, path: String):
	var screen = load(path).instantiate()
	host.get_tree().root.add_child(screen)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return screen
