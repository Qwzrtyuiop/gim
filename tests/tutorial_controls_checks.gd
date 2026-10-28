extends RefCounted

const Tutorial := preload("res://scripts/game/stage_tutorial_controller.gd")
const GameInput := preload("res://scripts/game/game_input.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	assert(PlayerState.max_energy == 5 and PlayerState.energy == 5, "Driving tutorials start from the five-point daily energy budget")
	var game = load("res://scenes/main.tscn").instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = "short-morning-normal"
	host.get_tree().root.add_child(game)
	game.set_process(false)
	game.target_distance = 1000000.0
	game.time_left = 10000.0
	var original := _snapshot(game)
	var tutorial: Tutorial = game.stage_tutorial
	assert(Tutorial.PHASES.size() == 6, "Driving onboarding contains six focused control lessons")
	for phase: String in Tutorial.PHASES:
		var prompt := str(Tutorial.PROMPTS[phase]).to_lower()
		for resource in ["energy", "stress", "hull", "debt"]:
			assert(not prompt.contains(resource), "Driving onboarding must leave resource lessons to the station")
	# This key is intentionally held before show(): the handoff must poll it
	# even though the tutorial never received its pressed event.
	await _send_key(host, KEY_LEFT, true)
	tutorial.show(game)
	assert(tutorial.active and tutorial.phase == "up" and tutorial.overlay.visible)
	await _send_key(host, KEY_Q, true)
	await _send_key(host, KEY_Q, false)
	assert(tutorial.phase == "up", "The wrong key cannot skip a control lesson")
	await _send_key(host, KEY_W, true, true, true)
	await _send_key(host, KEY_W, false, false, true)
	assert(tutorial.phase == "up", "Echo and release events cannot complete a control lesson")
	_assert_frozen(game, original)
	await _send_key(host, KEY_W, true, false, true)
	assert(tutorial.phase == "down")
	await _send_key(host, KEY_W, false, false, true)
	assert(tutorial.phase == "down", "Releasing a previous lesson's key cannot advance the next lesson")
	await _send_key(host, KEY_DOWN, true)
	assert(tutorial.phase == "accelerate")
	await _send_key(host, KEY_DOWN, false)
	await _send_key(host, KEY_D, true, false, true)
	assert(tutorial.phase == "brake" and GameInput.is_accelerating())
	_assert_frozen(game, original)
	await _send_key(host, KEY_A, true)
	assert(tutorial.phase == "boost")
	await _send_key(host, KEY_A, false)
	await _send_key(host, KEY_SHIFT, true)
	assert(tutorial.phase == "horn" and GameInput.is_boosting())
	_assert_frozen(game, original)
	await _send_key(host, KEY_Q, true)
	assert(tutorial.active and tutorial.phase == "release", "The final Q press waits for control release before gameplay")
	assert(tutorial.hint_label.text == "Release the controls to start driving.")
	assert(not game.horn_held and not game.boost_active, "Rehearsal input cannot sound the horn or enable boost")
	_assert_frozen(game, original)
	await _send_key(host, KEY_Q, false)
	assert(tutorial.active and tutorial.phase == "release")
	await _send_key(host, KEY_D, false, false, true)
	assert(tutorial.active and tutorial.phase == "release", "Held Shift still blocks the handoff after throttle and Q release")
	_assert_frozen(game, original)
	await _send_key(host, KEY_SHIFT, false)
	assert(tutorial.active and tutorial.phase == "release", "Controls held before show() must also be released")
	_assert_frozen(game, original)
	await _send_key(host, KEY_LEFT, false)
	assert(not tutorial.active and not tutorial.input_lock_active and tutorial.phase.is_empty() and not tutorial.overlay.visible)
	assert(not GameInput.is_boosting() and not GameInput.is_accelerating() and not GameInput.is_braking())
	assert(_snapshot(game) == original, "Completing control practice cannot alter resources, time, lane, distance or traffic")
	# A fresh gameplay press must still reach the normal horn after the gate.
	await _send_key(host, KEY_Q, true)
	assert(game.horn_held and game.audio_manager.horn_player.playing, "The first fresh Q press after practice must sound the horn")
	await _send_key(host, KEY_Q, false)
	assert(not game.horn_held and not game.audio_manager.horn_player.playing)
	assert(_snapshot(game) == original)
	await _test_alternate_bindings(host, game, original)
	# Save restoration and teardown call end() directly: that remains immediate.
	tutorial.show(game)
	await _send_key(host, KEY_SHIFT, true)
	tutorial._set_phase("release")
	tutorial.end()
	assert(not tutorial.active and not tutorial.input_lock_active and not tutorial.overlay.visible)
	await _send_key(host, KEY_SHIFT, false)
	assert(_snapshot(game) == original)
	game.audio_manager.horn_player.stop()
	game.audio_manager.stage_bgm_player.stop()
	game.free()
	await host.get_tree().process_frame
	AmbientAudioManager.stop_all()
	PlayerState.reset()
	print("PASS: six focused driving controls, physical/logical WASD and arrows, wrong/repeat/release input isolation, frozen gameplay/resources, preheld-key release handoff, fresh horn input and immediate restore/teardown end")


static func _test_alternate_bindings(host: Node, game, original: Dictionary) -> void:
	var tutorial: Tutorial = game.stage_tutorial
	tutorial.show(game)
	var keys := [KEY_UP, KEY_S, KEY_RIGHT, KEY_LEFT, KEY_SHIFT, KEY_Q]
	for index in range(keys.size()):
		await _send_key(host, keys[index], true)
		var expected := "release" if index == keys.size() - 1 else str(Tutorial.PHASES[index + 1])
		assert(tutorial.phase == expected, "Alternate driving key must advance exactly one lesson")
		_assert_frozen(game, original)
		await _send_key(host, keys[index], false)
	assert(not tutorial.active and tutorial.phase.is_empty())
	assert(_snapshot(game) == original)


static func _assert_frozen(game, original: Dictionary) -> void:
	game._process(0.5)
	assert(_snapshot(game) == original, "Tutorial steps and the release handoff must freeze timer, distance, fuel and traffic")


static func _snapshot(game) -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"stress": PlayerState.stress,
		"hull": PlayerState.hull,
		"gas": PlayerState.gas,
		"day": PlayerState.current_day,
		"phase": PlayerState.current_phase,
		"time_left": game.time_left,
		"distance": game.distance,
		"lane": game.player_lane,
		"entities": game.active_entities.size(),
		"spawn_timers": game.spawn_timers.duplicate(true),
		"pressure": game.top_lane_pressure,
	}


static func _send_key(host: Node, key: Key, pressed: bool, echo := false, physical_only := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = 0 if physical_only else key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await host.get_tree().process_frame
