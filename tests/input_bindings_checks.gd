extends RefCounted

const GameInput := preload("res://scripts/game/game_input.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	var counts := {}
	for action: StringName in InputBindings.WASD_ACTIONS:
		counts[action] = InputMap.action_get_events(action).size()
	InputBindings._enter_tree()
	for action: StringName in InputBindings.WASD_ACTIONS:
		assert(InputMap.action_get_events(action).size() == counts[action], "Reinstalling bindings cannot duplicate the input events")
		var letter := _key(InputBindings.WASD_ACTIONS[action], true)
		assert(letter.is_action_pressed(action), "Physical WASD keys must work without logical keycodes")
	for pair in [[KEY_UP, "ui_up"], [KEY_DOWN, "ui_down"], [KEY_LEFT, "ui_left"], [KEY_RIGHT, "ui_right"]]:
		var arrow := _key(pair[0], true)
		arrow.keycode = pair[0]
		assert(arrow.is_action_pressed(pair[1]), "WASD aliases must retain the arrow keys")
	PlayerState.reset()
	var game = load("res://scenes/main.tscn").instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = "short-morning-normal"
	host.get_tree().root.add_child(game)
	game.set_process(false)
	game.game_state = "playing"
	game.player_hit_recovery_timer = 0.0
	game.player_lane = 1
	game._unhandled_input(_key(KEY_W, true))
	assert(game.player_lane == 0, "Physical W must move the player up one lane")
	game._unhandled_input(_key(KEY_S, true))
	assert(game.player_lane == 1, "Physical S must move the player down one lane")
	var repeat := _key(KEY_S, true)
	repeat.echo = true
	game._unhandled_input(repeat)
	assert(game.player_lane == 1, "Held-key repeats must not change lanes repeatedly")
	for key in [KEY_D, KEY_A]:
		Input.parse_input_event(_key(key, true))
		Input.flush_buffered_events()
		assert(GameInput.is_accelerating() if key == KEY_D else GameInput.is_braking())
		Input.parse_input_event(_key(key, false))
		Input.flush_buffered_events()
	assert(not GameInput.is_accelerating() and not GameInput.is_braking())
	game.free()
	await host.get_tree().process_frame
	PlayerState.reset()
	print("PASS: physical WASD and retained arrows, idempotent bindings, actual lane changes, repeat isolation and throttle/brake press-release")


static func _key(key: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	return event
