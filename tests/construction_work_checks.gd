extends RefCounted

const Construction := preload("res://scripts/state/player_construction_state.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Reader := preload("res://scripts/story_scene.gd")
const Interface := preload("res://scripts/story/story_interface.gd")
const Conditions := preload("res://scripts/story/story_conditions.gd")
const Intro := preload("res://scripts/story/payloads/characters/benny/benny_construction_introduction.gd")
const IntroTagalog := preload("res://scripts/story/payloads/characters/benny/benny_construction_introduction_tagalog.gd")
const Offer := preload("res://scripts/story/payloads/characters/benny/benny_construction_work_offer.gd")
const WorkOverlay := preload("res://scenes/construction_work_overlay.tscn")
const Tuning := preload("res://scripts/config/game_tuning.gd")


class ChoiceOwner extends Control:
	var choice_container := VBoxContainer.new()
	var continue_label := Label.new()
	var choice_buttons: Array[BaseButton] = []
	var selected: Dictionary = {}

	func _init() -> void:
		add_child(choice_container)
		add_child(continue_label)
		choice_container.size = Vector2(440, 0)

	func _choose_branch(choice: Dictionary) -> void:
		selected = choice


static func run(suite: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false), "Use the isolated Python runner")
	await _test_intro_rates()
	_test_shift_and_resume()
	_test_unavailable()
	await _test_offer_controls(suite)
	await _test_work_geometry(suite)
	PlayerState.reset()
	print("PASS: construction intro rate capture and replay isolation, immutable 500/750 pay, Benny-only bond, two-energy daily work, phase/Midnight progression, owned pending receipts and save/resume, guarded choices and responsive working/complete overlay")


static func _test_intro_rates() -> void:
	for builder in [Intro, IntroTagalog]:
		for has_tropa: bool in [false, true]:
			PlayerState.reset()
			var payload: Dictionary = builder.build()
			# Build before the achievement changes: the action must inspect its
			# execution-time state rather than freeze a value while building art.
			if has_tropa:
				PlayerState.unlock_achievement("tropa")
			var expected := 750 if has_tropa else 500
			var reader = Reader.new()
			reader.story_payload = payload
			var final_line: Dictionary = payload.composition[51]
			assert(final_line.actions[0].id == Construction.UNLOCK_EVENT, "Existing saved action cursor zero remains the unlock")
			await reader._run_line_actions(final_line)
			assert(bool(PlayerState.get_event_value(Construction.UNLOCK_EVENT, false)))
			assert(PlayerState.get_construction_work_pay() == expected)
			assert(PlayerState.money == 0 and PlayerState.energy == PlayerState.max_energy, "The introduction promises work without paying for a shift")
			var snapshot := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
			PlayerState.reset()
			assert(Codec.load_snapshot(PlayerState, snapshot))
			PlayerState.unlock_achievement("tropa")
			# Simulate a resumed cursor after action zero, then a repeated final
			# line. Neither can renegotiate an already captured agreement.
			await reader._run_line_actions(final_line, 1)
			await reader._run_line_actions(final_line)
			assert(PlayerState.get_construction_work_pay() == expected, "Later Tropa and replayed unlock actions cannot change the agreed pay")
			reader.free()
		for replay_key: String in ["replay", "memory_replay"]:
			PlayerState.reset()
			var payload: Dictionary = builder.build()
			payload[replay_key] = true
			var reader = Reader.new()
			reader.story_payload = payload
			var before := _activity_state()
			await reader._run_line_actions(payload.composition[51])
			assert(_activity_state() == before, "Viewing construction memories cannot unlock work or capture a rate")
			reader.free()
	PlayerState.reset()
	PlayerState.event_values[Construction.UNLOCK_EVENT] = true
	assert(PlayerState.get_construction_work_pay() == 750, "Older unlocked saves keep their already promised 750-peso agreement")
	assert(not PlayerState.has_event_value(Construction.PAY_EVENT), "Reading a legacy pay agreement must not mutate state")


static func _test_shift_and_resume() -> void:
	for phase: String in ["morning", "noon", "night"]:
		_setup_job(phase)
		var fare_history := PlayerState.get_last_stage_result()
		var before := _activity_state()
		var saves: int = PlayerState.get_meta("test_save_count", 0)
		assert(PlayerState.can_do_construction_work())
		assert(_activity_state() == before and int(PlayerState.get_meta("test_save_count", 0)) == saves, "Availability checks must remain pure")
		PlayerState.set_event_value(Construction.ACCEPTED_EVENT, true)
		saves = PlayerState.get_meta("test_save_count", 0)
		var receipt: Dictionary = PlayerState.begin_construction_work()
		assert(not receipt.is_empty())
		assert(PlayerState.money == 600 and PlayerState.energy == 3)
		assert(PlayerState.stress == 6 and PlayerState.hull == 8 and is_equal_approx(PlayerState.gas, 64.5), "Working spends only its quoted energy, with no ride stress or vehicle damage")
		assert(PlayerState.get_current_day() == 9 and int(PlayerState.stage_round) == 1)
		assert(int(PlayerState.get_event_value(Construction.LAST_WORK_DAY, 0)) == 9)
		assert(int(PlayerState.get_meta("test_save_count", 0)) - saves == 1, "Pay, bond, claim, energy, clock and pending presentation must save atomically")
		assert(PlayerState.get_last_stage_result() == fare_history, "A shift cannot fabricate a ride or overwrite an unpaid fare")
		for character: Dictionary in PlayerState.get_mock_characters():
			var id := str(character.id)
			if PlayerState.is_unique_character(id):
				var expected := 3 if id == "benny" else (4 if id == "cel" else 0)
				assert(PlayerState.get_unique_character_progress(id) == expected, "Construction work may increase only Benny's bond")
		assert(PlayerState.character_completed_rides.is_empty(), "Work does not count as passenger rides")
		if phase == "night":
			assert(PlayerState.is_midnight() and not PlayerState.are_passengers_available())
			assert(str(receipt.phase_after) == "Midnight", "Evening work consumes the night without sleeping through the next day")
		else:
			assert(PlayerState.get_current_time_of_day() == ("noon" if phase == "morning" else "night"))
			assert(not PlayerState.is_midnight())
		var stored_receipt: Dictionary = PlayerState.get_event_value(Construction.PENDING_EVENT, {}).duplicate(true)
		receipt["pay"] = -1
		assert(PlayerState.get_event_value(Construction.PENDING_EVENT, {}) == stored_receipt, "A caller cannot mutate the saved receipt through a fresh returned dictionary")
		var snapshot := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
		var after := _activity_state()
		PlayerState.reset()
		assert(Codec.load_snapshot(PlayerState, snapshot))
		saves = PlayerState.get_meta("test_save_count", 0)
		var resumed: Dictionary = PlayerState.begin_construction_work()
		assert(resumed == stored_receipt and _activity_state() == after)
		assert(int(PlayerState.get_meta("test_save_count", 0)) == saves, "Resuming a paid work receipt cannot charge, reward or save again")
		resumed["day"] = 99
		assert(PlayerState.get_event_value(Construction.PENDING_EVENT, {}) == stored_receipt)
		PlayerState.finish_construction_work_presentation()
		assert(Dictionary(PlayerState.get_event_value(Construction.PENDING_EVENT, {})).is_empty())
		var finished := _activity_state()
		PlayerState.set_event_value(Construction.ACCEPTED_EVENT, true)
		assert(PlayerState.begin_construction_work().is_empty() and _activity_state() == finished, "A stale Yes cannot repeat a daily shift after presentation")
		PlayerState.current_day = 10
		PlayerState.current_phase = "morning"
		PlayerState.energy = PlayerState.max_energy
		PlayerState.set_event_value(Construction.ACCEPTED_EVENT, true)
		assert(not PlayerState.begin_construction_work().is_empty(), "The dated daily claim must reopen on the next day")
		assert(PlayerState.money == 1100 and PlayerState.get_unique_character_progress("benny") == 4)
	_setup_job("noon", 750)
	PlayerState.set_event_value(Construction.ACCEPTED_EVENT, true)
	assert(int(PlayerState.begin_construction_work().pay) == 750 and PlayerState.money == 850)
	_setup_job("morning")
	PlayerState.set_unique_character_story_locked("benny", true)
	PlayerState.set_event_value(Construction.ACCEPTED_EVENT, true)
	assert(not PlayerState.begin_construction_work().is_empty())
	assert(PlayerState.money == 600 and PlayerState.energy == 3 and int(PlayerState.get_event_value(Construction.LAST_WORK_DAY, 0)) == 9)
	assert(PlayerState.get_unique_character_progress("benny") == 3, "Each shift grants Benny bond even when an earlier choice closed his story")
	assert(PlayerState.is_unique_character_story_locked("benny"), "Working together cannot reopen Benny's closed narrative route")
	assert(PlayerState.get_unique_character_progress("cel") == 4 and PlayerState.character_completed_rides.is_empty())


static func _test_unavailable() -> void:
	for blocked: String in ["locked", "energy", "daily", "midnight", "story", "memory", "repair", "special", "failed"]:
		_setup_job("night" if blocked == "midnight" else "morning")
		match blocked:
			"locked":
				PlayerState.event_values.erase(Construction.UNLOCK_EVENT)
			"energy":
				PlayerState.energy = 1
			"daily":
				PlayerState.event_values[Construction.LAST_WORK_DAY] = 9
			"midnight":
				PlayerState.event_values["night_phase_consumed_day"] = 9
			"story":
				PlayerState.pending_story = {"story_id": "busy"}
			"memory":
				PlayerState.pending_memory_replay = {"story_id": "memory"}
			"repair":
				PlayerState.pending_crash_repair = {"target_day": 10}
			"special":
				PlayerState.active_event_special_stage = {"id": "busy"}
			"failed":
				PlayerState.run_failed = true
		var before := _activity_state()
		assert(not PlayerState.can_do_construction_work() and _activity_state() == before)
		PlayerState.set_event_value(Construction.ACCEPTED_EVENT, true)
		assert(PlayerState.begin_construction_work().is_empty())
		assert(_activity_state() == before, "Rejected %s work cannot spend energy, advance, award pay/bond or claim the day" % blocked)
	_setup_job("morning")
	var before := _activity_state()
	assert(PlayerState.begin_construction_work().is_empty() and _activity_state() == before, "Merely entering the site or asking about work cannot start a shift")


static func _test_offer_controls(suite: Node) -> void:
	_setup_job("morning", 750)
	var owner := ChoiceOwner.new()
	suite.get_tree().root.add_child(owner)
	var offer: Dictionary = Offer.build()
	Interface.render_choices(owner, offer.composition[0])
	assert(owner.choice_buttons.size() == 2 and owner.choice_buttons[0].text == "Yes" and owner.choice_buttons[1].text == "No")
	var details: PanelContainer = owner.choice_container.get_node("ChoiceDetails")
	assert(str(details.get_child(0).text) == "Pay: PhP 750\n2 energy  |  1 phase", "Work details belong to their summary rather than overflowing the Yes label")
	assert(not owner.choice_buttons[0].disabled)
	PlayerState.energy = 1
	Interface.render_choices(owner, Offer.build().composition[0])
	assert(owner.choice_container.get_child_count() == 3, "Refreshing offers cannot duplicate the summary panel")
	assert(owner.choice_buttons.size() == 2 and owner.choice_buttons[0].disabled and owner.choice_buttons[0].text == "Yes")
	assert(owner.choice_buttons[0].tooltip_text == "Need 2 energy.")
	assert(not owner.choice_buttons[1].disabled)
	PlayerState.current_phase = "night"
	PlayerState.energy = 5
	PlayerState.event_values["night_phase_consumed_day"] = 9
	Interface.render_choices(owner, Offer.build().composition[0])
	assert(owner.choice_buttons[0].disabled and owner.choice_buttons[0].tooltip_text == "Done for tonight.")
	var reader = Reader.new()
	reader.story_payload = offer
	var before := _activity_state()
	await reader._run_choice_actions(offer.composition[0].choices[1])
	assert(_activity_state() == before, "No leaves money, energy, time, bond and the daily claim unchanged")
	reader.story_payload["memory_replay"] = true
	await reader._run_choice_actions(offer.composition[0].choices[0])
	assert(not bool(PlayerState.get_event_value(Construction.ACCEPTED_EVENT, false)), "Memory choices cannot create an accepted work claim")
	reader.free()
	owner.free()
	await _settle(suite)


static func _test_work_geometry(suite: Node) -> void:
	for dimensions: Vector2 in [Vector2(1280, 720), Vector2(640, 360)]:
		var parent := Control.new()
		suite.get_tree().root.add_child(parent)
		parent.size = dimensions
		var overlay = WorkOverlay.instantiate()
		parent.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var completions := {"count": 0}
		overlay.finished.connect(func() -> void: completions.count += 1)
		overlay.present({"day": 9, "phase_after": "Midnight", "pay": 750, "energy_cost": 2})
		overlay.set_process(false)
		await _settle(suite)
		_assert_overlay(overlay, dimensions)
		assert(overlay.title_label.text.begins_with("WORKING") and not overlay.continue_button.visible)
		overlay._finish()
		assert(overlay.active and int(completions.count) == 0, "Work cannot finish before the dot transition completes")
		var first_title: String = overlay.title_label.text
		overlay._process(0.51)
		assert(overlay.title_label.text != first_title, "The work transition must animate its loading dots")
		overlay._process(Tuning.CONSTRUCTION_WORK_PRESENTATION_SECONDS)
		await _settle(suite)
		_assert_overlay(overlay, dimensions)
		assert(overlay.title_label.text == "WORK COMPLETE" and overlay.continue_button.visible and not overlay.continue_button.disabled)
		overlay._finish()
		overlay._finish()
		assert(not overlay.active and int(completions.count) == 1)
		parent.free()
		await _settle(suite)


static func _assert_overlay(overlay, dimensions: Vector2) -> void:
	var bounds := Rect2(Vector2.ZERO, dimensions)
	var panel_bounds: Rect2 = overlay.panel.get_global_transform() * Rect2(Vector2.ZERO, overlay.panel.size)
	assert(bounds.grow(0.5).encloses(panel_bounds), "Work panel must fit %s: %s" % [dimensions, panel_bounds])
	assert(panel_bounds.get_center().distance_to(dimensions * 0.5) <= 1.0, "Work panel must remain centered after content minimums change")
	for node: Control in overlay.get_node("Center/Panel/Content").get_children():
		if node.is_visible_in_tree():
			var child_bounds := node.get_global_transform() * Rect2(Vector2.ZERO, node.size)
			assert(panel_bounds.grow(0.5).encloses(child_bounds), "Visible work content must fit inside its panel")
			assert(node.get_combined_minimum_size().x <= node.size.x + 0.5, "Work text/buttons cannot clip horizontally")


static func _setup_job(phase: String, pay := 500) -> void:
	PlayerState.reset()
	PlayerState.current_day = 9
	PlayerState.current_phase = phase
	PlayerState.current_stage_type = "short-%s-normal" % phase
	PlayerState.money = 100
	PlayerState.energy = 5
	PlayerState.stress = 6
	PlayerState.hull = 8
	PlayerState.gas = 64.5
	PlayerState.event_values = {Construction.UNLOCK_EVENT: true, Construction.PAY_EVENT: pay}
	PlayerState.unique_character_progress = {"benny": 2, "cel": 4}
	PlayerState.last_stage_result = {"day": 8, "time_of_day": "morning", "total": 123, "paid_out": true}


static func _activity_state() -> Dictionary:
	var events: Dictionary = PlayerState.get_event_values().duplicate(true)
	# Rejected/stale requests deliberately clear this transient consent marker.
	events.erase(Construction.ACCEPTED_EVENT)
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"stress": PlayerState.stress,
		"hull": PlayerState.hull,
		"gas": PlayerState.gas,
		"day": PlayerState.get_current_day(),
		"phase": PlayerState.get_current_time_of_day(),
		"round": PlayerState.stage_round,
		"events": events,
		"progress": PlayerState.unique_character_progress.duplicate(true),
		"rides": PlayerState.character_completed_rides.duplicate(true),
		"last_result": PlayerState.get_last_stage_result(),
	}


static func _settle(suite: Node) -> void:
	await suite.get_tree().process_frame
	await suite.get_tree().process_frame
