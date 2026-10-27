extends RefCounted

const Spawner := preload("res://scripts/game/vehicle_spawner.gd")
const Scheduler := preload("res://scripts/game/vehicle_spawn_scheduler.gd")
const Traffic := preload("res://scripts/game/vehicle_traffic_controller.gd")
const Geometry := preload("res://scripts/game/vehicle_geometry.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const Signals := preload("res://scripts/game/vehicle_traffic_signals.gd")
const Snapshot := preload("res://scripts/save/driving_save_snapshot.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	var game = load("res://scenes/main.tscn").instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = "short-morning-normal"
	host.get_tree().root.add_child(game)
	game.set_process(false)
	var four_car_seed := _test_counts_and_spacing(game)
	_test_warning_and_other_lanes(game)
	_test_offscreen_queue_and_resume(game, four_car_seed)
	game.free()
	await host.get_tree().process_frame
	PlayerState.reset()
	print("PASS: incoming groups cover counts one through four, visible bumper spacing, full advance warning, single other-lane spawns, offscreen queue survival and deterministic live-save restoration")


static func _test_counts_and_spacing(game) -> int:
	var four_car_seed := -1
	for profile: String in ["normal", "chill", "traffic-jam", "busy", "speeders"]:
		game.stage_traffic = profile
		var counts: Dictionary = {}
		for candidate in range(64):
			_clear_traffic(game)
			game.rng.seed = candidate
			assert(Spawner.spawn_incoming_group(game))
			var count: int = game.active_entities.size()
			assert(count >= 1 and count <= 4, "Each incoming wave contains one to four vehicles in every traffic profile")
			counts[count] = true
			if profile == "normal" and count == 4:
				four_car_seed = candidate
			for index in range(count):
				var entity: Dictionary = game.active_entities[index]
				assert(entity.lane == 0 and entity.target_lane == 0 and not entity.moves_with_player and entity.sprite.flip_h)
				var rect := _visible_rect(game, entity.sprite)
				assert(rect.position.x >= game.get_viewport_rect().size.x + Tuning.ONCOMING_SPAWN_EDGE_GAP - 0.01, "Every car begins completely outside the visible road")
				if index > 0:
					var previous := _visible_rect(game, game.active_entities[index - 1].sprite)
					var gap: float = rect.position.x - previous.end.x
					assert(gap >= Tuning.ONCOMING_GROUP_MIN_GAP - 0.01 and gap <= Tuning.ONCOMING_GROUP_MAX_GAP + 0.01, "Mixed vehicle sizes retain the configured visible bumper gap")
					assert(not Geometry.collision_rect(entity.sprite, game.VEHICLE_HITBOX_INSET, game).intersects(Geometry.collision_rect(game.active_entities[index - 1].sprite, game.VEHICLE_HITBOX_INSET, game)))
			if counts.size() == 4:
				break
		assert(counts.size() == 4, "All four group sizes must be reachable")
	assert(four_car_seed >= 0)
	_clear_traffic(game)
	return four_car_seed


static func _test_warning_and_other_lanes(game) -> void:
	game.stage_traffic = "normal"
	game.player_lane = 0
	game.top_lane_pressure = 1.0
	game.spawn_timers = [0.0, 1000.0, 1000.0]
	Signals.clear_oncoming_warning(game)
	Scheduler.update_spawns(game, 0.01)
	assert(game.active_entities.is_empty() and is_zero_approx(game.oncoming_warning_elapsed))
	var warning_duration: float = Tuning.ONCOMING_WARNING_FLASH_INTERVAL * Tuning.ONCOMING_WARNING_BEEPS
	for _pulse in range(4):
		Scheduler.update_spawns(game, warning_duration / 5.0)
		assert(game.active_entities.is_empty(), "Maximum pressure cannot shorten the group's advance warning")
	Scheduler.update_spawns(game, warning_duration / 5.0 + 0.01)
	assert(game.active_entities.size() >= 1 and game.active_entities.size() <= 4)
	assert(game.oncoming_warning_elapsed < 0.0 and game.spawn_timers[0] > 0.0, "One warning releases the complete group and schedules the next wave")
	_clear_traffic(game)
	game.player_lane = 1
	for lane in [1, 2]:
		game.spawn_timers = [1000.0, 1000.0, 1000.0]
		game.spawn_timers[lane] = 0.0
		Scheduler.update_spawns(game, 0.01)
		assert(game.active_entities.size() == 1 and int(game.active_entities[0].lane) == lane, "Other lanes retain single-vehicle arrivals")
		_clear_traffic(game)


static func _test_offscreen_queue_and_resume(game, four_car_seed: int) -> void:
	game.rng.seed = four_car_seed
	assert(Spawner.spawn_incoming_group(game) and game.active_entities.size() == 4)
	var last: Sprite2D = game.active_entities.back().sprite
	assert(last.position.x > game.get_viewport_rect().size.x + Traffic.FRONT_DESPAWN_EXTRA_X, "The regression needs a queued car beyond the old right-edge cleanup boundary")
	assert(not Scheduler.lane_has_spawn_room(game, 0), "The tail reserves the entrance until this wave has room to clear")
	var saved := Snapshot.capture(game)
	assert(saved.entities.size() == 4)
	var positions: Array[Vector2] = []
	for entity: Dictionary in game.active_entities:
		positions.append(entity.sprite.position)
	_clear_traffic(game)
	game.rng.randf()
	assert(Snapshot.restore(game, saved))
	assert(game.active_entities.size() == 4 and str(game.rng.state) == str(saved.rng_state))
	for index in range(4):
		assert(game.active_entities[index].sprite.position.is_equal_approx(positions[index]), "Saving and loading preserves the whole offscreen group")
	Traffic.update_entities(game, 0.01)
	assert(game.active_entities.size() == 4, "Queued tails must not be culled before entering from the right")
	var entered: Dictionary = {}
	for _step in range(240):
		for entity: Dictionary in game.active_entities:
			if _visible_rect(game, entity.sprite).position.x <= game.get_viewport_rect().size.x:
				entered[entity.sprite.get_instance_id()] = true
		Traffic.update_entities(game, 0.05)
		if game.active_entities.is_empty():
			break
	assert(entered.size() == 4 and game.active_entities.is_empty(), "All four cars enter the scene and eventually despawn behind the player")


static func _visible_rect(game, sprite: Sprite2D) -> Rect2:
	return Geometry.collision_rect(sprite, Vector4.ZERO, game)


static func _clear_traffic(game) -> void:
	for entity: Dictionary in game.active_entities:
		if is_instance_valid(entity.get("sprite")):
			entity.sprite.free()
	game.active_entities.clear()
	TrafficIndex.invalidate(game)
	Signals.clear_oncoming_warning(game)
