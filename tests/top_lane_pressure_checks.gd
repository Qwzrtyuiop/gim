extends RefCounted

const Scheduler := preload("res://scripts/game/vehicle_spawn_scheduler.gd")
const Snapshot := preload("res://scripts/save/driving_save_snapshot.gd")
const Flow := preload("res://scripts/game/game_flow_controller.gd")
const Signals := preload("res://scripts/game/vehicle_traffic_signals.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	var game = load("res://scenes/main.tscn").instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = "short-morning-normal"
	host.get_tree().root.add_child(game)
	game.set_process(false)
	assert(is_zero_approx(game.top_lane_pressure), "Fresh rides start without accumulated top-lane pressure")
	_test_growth_and_decay(game)
	_test_spawn_clock_and_warning(game)
	_test_inactive_gates(game)
	_test_snapshot(game)
	game.top_lane_pressure = 0.9
	Flow.reset_game(game)
	assert(is_zero_approx(game.top_lane_pressure), "Retrying a ride resets its lane pressure")
	game.free()
	await host.get_tree().process_frame
	PlayerState.reset()
	print("PASS: hidden top-lane pressure rises faster than it decays, bounds/time-step independence, lane-zero spawn clock and full warnings, inactive gates, retry reset and compatible driving save restoration")


static func _test_growth_and_decay(game) -> void:
	var rng_state: int = game.rng.state
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	game.player_lane = 0
	game.top_lane_pressure = 0.0
	Scheduler.update_top_lane_pressure(game, 5.0)
	var single_step: float = game.top_lane_pressure
	assert(single_step > 0.0 and single_step < 1.0)
	game.top_lane_pressure = 0.0
	for frame in range(50):
		Scheduler.update_top_lane_pressure(game, 0.1)
	assert(is_equal_approx(game.top_lane_pressure, single_step), "Accumulation must depend on elapsed time rather than frame count")
	game.top_lane_pressure = 0.5
	Scheduler.update_top_lane_pressure(game, 5.0)
	var increase: float = game.top_lane_pressure - 0.5
	for lane in [1, 2]:
		game.player_lane = lane
		game.top_lane_pressure = 0.5
		Scheduler.update_top_lane_pressure(game, 5.0)
		var decrease: float = 0.5 - game.top_lane_pressure
		assert(decrease > 0.0 and decrease < increase, "Leaving either lower lane drains pressure more slowly than top-lane accumulation")
		Scheduler.update_top_lane_pressure(game, Tuning.TOP_LANE_PRESSURE_DECAY_SECONDS * 2.0)
		assert(is_zero_approx(game.top_lane_pressure))
	game.player_lane = 0
	Scheduler.update_top_lane_pressure(game, Tuning.TOP_LANE_PRESSURE_FILL_SECONDS * 2.0)
	assert(is_equal_approx(game.top_lane_pressure, 1.0))
	assert(is_equal_approx(Scheduler.top_lane_spawn_rate(game), Tuning.TOP_LANE_PRESSURE_MAX_SPAWN_RATE))
	assert(game.rng.state == rng_state and int(PlayerState.get_meta("test_save_count", 0)) == saves, "The hidden float cannot consume RNG or write progression every frame")


static func _test_spawn_clock_and_warning(game) -> void:
	game.game_state = "playing"
	game.player_lane = 0
	game.top_lane_pressure = 1.0
	game.spawn_timers = [100.0, 100.0, 100.0]
	var rng_state: int = game.rng.state
	Scheduler.update_spawns(game, 0.5)
	assert(is_equal_approx(game.spawn_timers[0], 100.0 - 0.5 * Tuning.TOP_LANE_PRESSURE_MAX_SPAWN_RATE))
	assert(is_equal_approx(game.spawn_timers[1], 99.5) and is_equal_approx(game.spawn_timers[2], 99.5), "Pressure must not speed up middle or shoulder spawns")
	assert(game.rng.state == rng_state)
	game.spawn_timers = [1.0, 100.0, 100.0]
	game.top_lane_pressure = 0.0
	Scheduler.update_spawns(game, 0.4)
	assert(game.oncoming_warning_elapsed < 0.0)
	game.spawn_timers = [1.0, 100.0, 100.0]
	game.top_lane_pressure = 1.0
	Scheduler.update_spawns(game, 0.4)
	assert(is_zero_approx(game.oncoming_warning_elapsed), "Higher pressure must bring the next top-lane arrival forward")
	assert(game.active_entities.is_empty(), "An increased spawn rate must still start the existing warning before creating a car")
	Scheduler.update_spawns(game, 0.1)
	assert(is_equal_approx(game.oncoming_warning_elapsed, 0.1), "Pressure cannot accelerate the audible warning clock")
	assert(game.active_entities.is_empty())
	Signals.clear_oncoming_warning(game)
	game.spawn_timers = [100.0, 100.0, 100.0]


static func _test_inactive_gates(game) -> void:
	game.top_lane_pressure = 0.4
	var timers: Array = game.spawn_timers.duplicate()
	for state in ["story", "YOU MADE IT", "TIME OUT"]:
		game.game_state = state
		Scheduler.update_spawns(game, 1.0)
		assert(is_equal_approx(game.top_lane_pressure, 0.4) and game.spawn_timers == timers)
	game.game_state = "playing"
	game.get_tree().paused = true
	Scheduler.update_top_lane_pressure(game, 1.0)
	assert(is_equal_approx(game.top_lane_pressure, 0.4), "A paused game must not fill or drain pressure")
	game.get_tree().paused = false
	game.stage_tutorial.active = true
	game._process(0.1)
	assert(is_equal_approx(game.top_lane_pressure, 0.4) and game.spawn_timers == timers)
	game.stage_tutorial.active = false
	game.stage_tutorial.input_lock_active = true
	game._process(0.1)
	assert(is_equal_approx(game.top_lane_pressure, 0.4) and game.spawn_timers == timers)
	game.stage_tutorial.input_lock_active = false


static func _test_snapshot(game) -> void:
	game.game_state = "playing"
	game.top_lane_pressure = 0.72
	var saved: Dictionary = Snapshot.capture(game)
	assert(is_equal_approx(float(saved.values.top_lane_pressure), 0.72))
	game.top_lane_pressure = 0.0
	assert(Snapshot.restore(game, saved))
	assert(is_equal_approx(game.top_lane_pressure, 0.72), "Driving saves resume the pressure instead of granting a fresh top lane")
	var legacy := saved.duplicate(true)
	legacy.values.erase("top_lane_pressure")
	game.top_lane_pressure = 0.9
	assert(Snapshot.restore(game, legacy) and is_zero_approx(game.top_lane_pressure), "Old runtime saves explicitly default to zero, even on a reused scene")
	for pair in [[-0.5, 0.0], [2.0, 1.0]]:
		var bounded := saved.duplicate(true)
		bounded.values.top_lane_pressure = pair[0]
		assert(Snapshot.restore(game, bounded) and is_equal_approx(game.top_lane_pressure, pair[1]))
	for invalid in ["bad", true, NAN, INF]:
		var damaged := saved.duplicate(true)
		damaged.values.top_lane_pressure = invalid
		game.top_lane_pressure = 0.42
		game.distance = 123.0
		assert(not Snapshot.restore(game, damaged))
		assert(is_equal_approx(game.top_lane_pressure, 0.42) and is_equal_approx(game.distance, 123.0), "Malformed pressure must be rejected before the active drive is changed")
