extends RefCounted

const InputHelper := preload("res://scripts/game/game_input.gd")
const PlayerHorn := preload("res://scripts/game/player_horn_controller.gd")
const HornTraffic := preload("res://scripts/game/vehicle_horn_response.gd")
const Geometry := preload("res://scripts/game/vehicle_geometry.gd")
const Entities := preload("res://scripts/game/vehicle_traffic_entities.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const Traffic := preload("res://scripts/game/vehicle_traffic_controller.gd")
const Maneuvers := preload("res://scripts/game/vehicle_traffic_maneuvers.gd")
const Spacing := preload("res://scripts/game/vehicle_traffic_spacing.gd")
const Navigation := preload("res://scripts/game/vehicle_lane_navigation.gd")
const Collisions := preload("res://scripts/game/vehicle_collision_controller.gd")
const Flow := preload("res://scripts/game/game_flow_controller.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	var game = load("res://scenes/main.tscn").instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = "short-morning-normal"
	host.get_tree().root.add_child(game)
	game.set_process(false)
	game.player_lane = 2
	game.player_speed = 250.0
	game.player.position.y = Geometry.sprite_y_for_hitbox_bottom(game.player, Geometry.lane_y(game, 2, game.get_viewport_rect().size), game.PLAYER_HITBOX_INSET, game)
	_test_input_and_audio(game)
	_test_targeting_and_patience(game)
	var seeds := _reaction_seeds(game)
	_test_speed_safety(game, int(seeds["speed"]))
	_test_yield_and_passing(game, int(seeds["yield"]))
	_test_blocked_shoulder(game, int(seeds["yield"]))
	_test_ignored_driver(game, int(seeds["ignore"]))
	_test_horn_lifecycle(game)
	var horn_ref: WeakRef = weakref(game.audio_manager.horn_player)
	game.audio_manager.set_horn_active(true)
	game.free()
	assert(horn_ref.get_ref() == null, "Leaving gameplay must free the dedicated horn player")
	PlayerState.reset()
	print("PASS: Q horn loop/release, tap gating, per-car patience/ignore, safe speed reactions, parked-level yield/pass-through, pause/focus/end cleanup")


static func _key(pressed: bool, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.physical_keycode = KEY_Q
	event.pressed = pressed
	event.echo = echo
	return event


static func _clear(game) -> void:
	PlayerHorn.stop(game)
	for entity: Dictionary in game.active_entities:
		if is_instance_valid(entity.get("sprite")):
			entity.sprite.free()
	game.active_entities.clear()
	TrafficIndex.invalidate(game)
	game.horn_press_cooldown = 0.0
	game.game_state = "playing"
	game.crash_repair_transition_active = false
	game.player_hit_invincible_timer = 0.0


static func _car(game, offset := 180.0, lane := 2, parked := false) -> Dictionary:
	var sprite := Sprite2D.new()
	sprite.texture = game.VEHICLE_TEXTURES.sedan
	sprite.scale = Geometry.scale_for_vehicle_in_lane(game, "sedan", Geometry.scale_for_height(sprite.texture, 90.0), lane)
	sprite.position.x = game.player.position.x + offset
	sprite.position.y = Geometry.sprite_y_for_hitbox_bottom(sprite, Geometry.entity_lane_y(game, lane, game.get_viewport_rect().size, parked), game.VEHICLE_HITBOX_INSET, game)
	game.add_child(sprite)
	var speed := 0.0 if parked else 100.0
	var entity := {
		"sprite": sprite,
		"lane": lane,
		"target_lane": lane,
		"vehicle_key": "sedan",
		"fallback_height": 90.0,
		"kind": "traffic",
		"spawn_side": "right",
		"moves_with_player": true,
		"world_speed": speed,
		"desired_world_speed": speed,
		"min_world_speed": speed,
		"max_world_speed": speed,
		"speed_change_timer": 100.0,
		"is_parked": parked,
		"is_busy_car": false,
		"overtake_speed_timer": 0.0,
		"pending_overtake_speed_boost": false,
		"lane_change_warning_active": false,
		"lane_change_cooldown": 0.0,
	}
	game.active_entities.append(entity)
	TrafficIndex.invalidate(game)
	return entity


static func _test_input_and_audio(game) -> void:
	_clear(game)
	var driver := _car(game)
	driver["horn_required_presses"] = 5
	assert(InputHelper.is_horn_event(_key(true)) and InputHelper.is_horn_event(_key(false)))
	assert(not InputHelper.is_horn_event(_key(true, true)))
	game._unhandled_input(_key(true))
	assert(game.horn_held and game.audio_manager.horn_player.playing)
	assert(driver.horn_press_count == 1)
	var playback = game.audio_manager.horn_player.get_stream_playback()
	game._unhandled_input(_key(true))
	game._unhandled_input(_key(true, true))
	assert(driver.horn_press_count == 1, "Held Q and keyboard repeat must not count as repeated honks")
	assert(game.audio_manager.horn_player.get_stream_playback() == playback, "A held horn cannot restart its audio every frame")
	var horn_stream: AudioStreamWAV = game.audio_manager.horn_player.stream
	assert(horn_stream != null and horn_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(horn_stream.format == AudioStreamWAV.FORMAT_16_BITS and horn_stream.loop_begin == 0)
	assert(horn_stream.loop_end > 0)
	var onset_peak := 0
	var onset_bytes := mini(horn_stream.data.size(), int(horn_stream.mix_rate * 0.01) * (4 if horn_stream.stereo else 2))
	var samples := horn_stream.data
	for offset in range(0, onset_bytes, 2):
		onset_peak = maxi(onset_peak, absi(samples.decode_s16(offset)))
	assert(onset_peak > 1000, "The horn must contain audible PCM within the first 10ms, without the source clip's startup silence")
	assert(game.audio_manager.horn_player.get_meta("audio_category") == "sfx")
	var previous_volume: float = AudioSettingsManager.get_category_volume("sfx")
	AudioSettingsManager.set_category_volume("sfx", 0.0)
	assert(game.audio_manager.horn_player.volume_db <= -79.0)
	AudioSettingsManager.set_category_volume("sfx", previous_volume)
	game._unhandled_input(_key(false))
	assert(not game.horn_held and not game.audio_manager.horn_player.playing)
	game._unhandled_input(_key(true))
	assert(driver.horn_press_count == 1, "Taps inside the cooldown cannot inflate patience counts")
	game._unhandled_input(_key(false))
	PlayerHorn.update(game, Tuning.HORN_PRESS_COOLDOWN + 0.01)
	game._unhandled_input(_key(true))
	assert(driver.horn_press_count == 2)
	game._unhandled_input(_key(false))


static func _test_targeting_and_patience(game) -> void:
	for invalid_case in ["other_lane", "parked", "oncoming", "behind", "distant", "changing", "speeder"]:
		_clear(game)
		var driver := _car(game)
		match invalid_case:
			"other_lane":
				driver.lane = 1
			"parked":
				driver.is_parked = true
			"oncoming":
				driver.moves_with_player = false
			"behind":
				driver.sprite.position.x = game.player.position.x - 200.0
			"distant":
				driver.sprite.position.x = game.player.position.x + 1500.0
			"changing":
				driver.target_lane = 1
			"speeder":
				driver.kind = "speeder"
		HornTraffic.press(game)
		assert(not driver.has("horn_press_count"), "Horn must reject %s traffic" % invalid_case)
	_clear(game)
	var near := _car(game)
	var far := _car(game, 450.0)
	game.player_lane = 1
	HornTraffic.press(game)
	assert(not near.has("horn_press_count"), "The horn does not persuade another lane's traffic")
	game.player_lane = 2
	HornTraffic.press(game)
	assert(near.horn_press_count == 1 and not far.has("horn_press_count"), "Only the nearest driver ahead should hear persuasion taps")
	var threshold := int(near.horn_required_presses)
	assert(threshold >= Tuning.HORN_MIN_PRESSES and threshold <= Tuning.HORN_MAX_PRESSES)
	HornTraffic.update(game, Tuning.HORN_REPEAT_WINDOW + 0.01)
	assert(near.horn_press_count == 0)
	HornTraffic.press(game)
	assert(near.horn_press_count == 1 and near.horn_required_presses == threshold, "A pause between honks clears counts without rerolling the same driver's patience")


static func _react(game, seed_value: int) -> Dictionary:
	_clear(game)
	game.rng.seed = seed_value
	var driver := _car(game)
	driver["horn_required_presses"] = 2
	HornTraffic.press(game)
	assert(not driver.has("horn_response"), "No driver responds before their patience threshold")
	HornTraffic.press(game)
	return driver


static func _reaction_seeds(game) -> Dictionary:
	var seeds: Dictionary = {}
	for seed_value in range(1, 128):
		var driver := _react(game, seed_value)
		var response := str(driver.get("horn_response", ""))
		assert(response in ["ignore", "speed", "yield"])
		if not seeds.has(response):
			seeds[response] = seed_value
		if seeds.size() == 3:
			break
	assert(seeds.size() == 3, "Seeded drivers must exercise each possible horn response")
	return seeds


static func _test_speed_safety(game, seed_value: int) -> void:
	var driver := _react(game, seed_value)
	game.main_vehicle_min_speed = 100.0
	game.main_vehicle_max_speed = 100.0
	for frame in range(4):
		Maneuvers.update_vehicle_speeds(game, 0.5)
	assert(float(driver.world_speed) > 100.0, "A persuaded driver must be able to exceed the ordinary bottom-lane cap")
	assert(float(driver.world_speed) <= Tuning.HORN_MAX_RESPONSE_SPEED)
	var blocker := _car(game)
	var driver_rect := Geometry.collision_rect(driver.sprite, game.VEHICLE_HITBOX_INSET, game)
	var blocker_rect := Geometry.collision_rect(blocker.sprite, game.VEHICLE_HITBOX_INSET, game)
	blocker.sprite.position.x += driver_rect.end.x + 8.0 - blocker_rect.position.x
	blocker.world_speed = 30.0
	blocker.desired_world_speed = 30.0
	Spacing.update_npc_following(game)
	Maneuvers.update_overtake_speed_boosts(game, 0.1)
	assert(float(driver.world_speed) <= 30.0, "Horn acceleration must still obey the front car after all speed-boost processing")
	blocker.sprite.free()
	game.active_entities.erase(blocker)
	TrafficIndex.invalidate(game)
	HornTraffic.update(game, Tuning.HORN_SPEED_SECONDS + 0.1)
	Maneuvers.update_vehicle_speeds(game, 0.1)
	assert(float(driver.world_speed) <= 100.0, "The normal lane cap resumes after the horn burst expires")


static func _test_yield_and_passing(game, seed_value: int) -> void:
	var driver := _react(game, seed_value)
	assert(driver.horn_yielding and not Entities.entity_collision_disabled(driver))
	assert(driver.world_speed == 0.0 and driver.desired_world_speed == 0.0)
	var original_x: float = game.player.position.x
	game.player.position.x = driver.sprite.position.x
	assert(not Collisions.collision_data(game).is_empty(), "The car remains solid while it is still visibly in the traffic lane")
	for frame in range(120):
		Navigation.update_entity_lane_position(game, driver, 1.0 / 60.0)
		HornTraffic.update_yield_clearance(game, driver)
	var parked_guide := Geometry.entity_lane_y(game, 2, game.get_viewport_rect().size, true)
	var driver_rect := Geometry.collision_rect(driver.sprite, game.VEHICLE_HITBOX_INSET, game)
	assert(absf(driver_rect.end.y - parked_guide) <= Tuning.HORN_YIELD_CLEAR_DISTANCE)
	assert(driver.horn_yield_clear and driver.is_parked and Entities.entity_collision_disabled(driver))
	assert(Collisions.collision_data(game).is_empty(), "The player can pass the yielded vehicle after it reaches parked-car level")
	assert(not Entities.active_collision_entities(game).has(driver))
	assert(TrafficIndex.in_lane(game, 2).has(driver), "Pulled-over cars remain real lane entities for spawn and lifetime handling")
	game.npc_random_lane_change_enabled = true
	game.npc_lane_change_chance_per_second = 1000.0
	game.stage_traffic = "busy"
	Maneuvers.update_random_lane_changes(game, 1.0)
	Maneuvers.update_busy_vehicle_ai(game, 1.0)
	Maneuvers.update_vehicle_overtake_ai(game, 1.0)
	assert(driver.lane == 2 and driver.target_lane == 2 and not driver.lane_change_warning_active, "A yielded driver cannot drift back into traffic through another AI")
	game.player.position.x = original_x
	game.npc_random_lane_change_enabled = false
	game.stage_traffic = "normal"


static func _test_blocked_shoulder(game, seed_value: int) -> void:
	_clear(game)
	game.rng.seed = seed_value
	var driver := _car(game)
	_car(game, 180.0, 2, true)
	driver["horn_required_presses"] = 2
	HornTraffic.press(game)
	HornTraffic.press(game)
	assert(driver.horn_response == "speed" and not bool(driver.get("horn_yielding", false)), "A driver cannot pull into an occupied parked-car space")


static func _test_ignored_driver(game, seed_value: int) -> void:
	var driver := _react(game, seed_value)
	var original_speed: float = driver.world_speed
	for tap in range(20):
		HornTraffic.press(game)
	HornTraffic.update(game, Tuning.HORN_REPEAT_WINDOW + 1.0)
	HornTraffic.press(game)
	assert(driver.horn_response == "ignore" and driver.world_speed == original_speed, "An uncooperative driver cannot be rerolled into cooperation by spamming")


static func _test_horn_lifecycle(game) -> void:
	_clear(game)
	game._unhandled_input(_key(true))
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(not game.horn_held and not game.audio_manager.horn_player.playing)
	game.horn_press_cooldown = 0.0
	game._unhandled_input(_key(true))
	game.get_tree().paused = true
	assert(not game.horn_held and not game.audio_manager.horn_player.playing, "Pausing stops the horn even if Q is released in the pause menu")
	game.get_tree().paused = false
	game.stage_tutorial.active = true
	game._unhandled_input(_key(true))
	assert(not game.horn_held)
	game.stage_tutorial.active = false
	game.crash_repair_transition_active = true
	game._unhandled_input(_key(true))
	assert(not game.horn_held)
	game.crash_repair_transition_active = false
	game.horn_press_cooldown = 0.0
	game._unhandled_input(_key(true))
	Flow.end_game(game, "YOU MADE IT", "Horn fixture completed")
	assert(not game.horn_held and not game.audio_manager.horn_player.playing, "A completed ride must stop a held horn before results")
