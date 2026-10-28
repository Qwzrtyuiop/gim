extends RefCounted

const Events := preload("res://scripts/story/generic_passenger_events.gd")
const RandomEvents := preload("res://scripts/story/random_ride_event_service.gd")
const Economy := preload("res://scripts/game/game_economy_manager.gd")
const Catalog := preload("res://scripts/story/story_payload_catalog.gd")
const Payload := preload("res://scripts/story/story_payload.gd")
const Actions := preload("res://scripts/story/story_action_runner.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const STORY_SCENE := "res://scenes/story_scene.tscn"
const REWARDS := {
	"generic_keep_the_change": Vector2i(20, 1),
	"generic_a_compliment": Vector2i(0, 2),
	"generic_an_extra_tip": Vector2i(15, 1),
	"generic_lucky_day": Vector2i(30, 1),
	"generic_a_quiet_ride": Vector2i(0, 2),
	"generic_rounding_up": Vector2i(20, 0),
	"generic_a_friendly_passenger": Vector2i(0, 2),
	"generic_a_small_favor": Vector2i(25, 1),
	"generic_an_unexpected_conversation": Vector2i(0, 2),
	"generic_a_generous_stranger": Vector2i(40, 1),
}

class ActionOwner extends RefCounted:
	var story_payload: Dictionary = {}


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	var language: String = StoryLanguageManager.get_language()
	var instant: bool = ProjectSettings.get_setting("testing/instant_story_text", false)
	StoryLanguageManager.set_language("english")
	ProjectSettings.set_setting("testing/instant_story_text", true)
	_test_eligibility_and_crash_capture()
	_test_unlock_gates_and_story_priority()
	_test_single_roll_and_repeat()
	await _test_authored_rewards()
	await _test_checkpoint_and_replay(host)
	StoryLanguageManager.set_language(language)
	ProjectSettings.set_setting("testing/instant_story_text", instant)
	PlayerState.reset()
	print("PASS: ten generic ride stories, crash/time/day restrictions, post-Day2 and generic-only gates, scheduled/character priority, one roll per result, repeat cursor reset, authored rewards and checkpoint/replay isolation")


static func _result(day := 3, phase := "morning", character := "generic_guy") -> Dictionary:
	return {"completed": true, "paid_out": false, "day": day, "time_of_day": phase, "character_id": character, "had_crash": false, "vehicle_collision_count": 0, "overtime": 0.0, "fare": 100, "bonus": 20, "total": 120}


static func _setup(day := 3, gate := true, character := "generic_guy") -> void:
	PlayerState.reset()
	PlayerState.current_day = day
	PlayerState.current_phase = "noon"
	PlayerState.set_current_mock_character(character)
	if gate:
		PlayerState.set_event_value("day_2_station_bill", true)
	PlayerState.consumed_story_triggers[RandomEvents.CONSUMED_KEY] = true
	PlayerState.consumed_story_triggers[RandomEvents.BAYANIHAN_CONSUMED_KEY] = true
	PlayerState.set_last_stage_result(_result(day, "morning", character))


static func _test_eligibility_and_crash_capture() -> void:
	var ride := _result()
	var eligible := Events.eligible_story_ids(ride)
	assert(eligible.size() == 10 and REWARDS.size() == 10)
	for id: String in REWARDS:
		assert(eligible.has(id))
	ride.had_crash = true
	assert(not Events.eligible_story_ids(ride).has("generic_a_quiet_ride"))
	ride.had_crash = false
	ride.vehicle_collision_count = 1
	assert(not Events.eligible_story_ids(ride).has("generic_a_quiet_ride"), "Older results with only collision counts still reject quiet rides")
	ride.vehicle_collision_count = 0
	ride.overtime = 0.01
	assert(not Events.eligible_story_ids(ride).has("generic_keep_the_change"))
	ride.overtime = 0.0
	ride.time_of_day = "night"
	assert(not Events.eligible_story_ids(ride).has("generic_an_extra_tip"))
	ride.time_of_day = "noon"
	assert(Events.eligible_story_ids(ride).has("generic_an_extra_tip"), "Eligibility uses the completed ride phase, even after live time advances to night")
	_setup()
	PlayerState.record_stage_crash()
	Economy.store_stage_result("short-morning-normal", "short", "morning", "normal", "", "", 500, 500, 0.2, 0, 1.25, 10, 2, 0)
	assert(PlayerState.get_last_stage_result().had_crash and not PlayerState.current_trip_had_crash, "Completion must capture the crash before achievement tracking resets the ride flag")


static func _test_unlock_gates_and_story_priority() -> void:
	for data: Array in [[1, false], [2, true], [3, false]]:
		_setup(int(data[0]), bool(data[1]))
		assert(RandomEvents.prepare(PlayerState).is_empty())
		assert(PlayerState.last_stage_result.random_event_checked)
		PlayerState.set_event_value("day_2_station_bill", true)
		PlayerState.current_day = 3
		assert(RandomEvents.prepare(PlayerState).is_empty(), "A blocked result cannot reroll when the unlock state changes later")
	_setup(3, true, "benny")
	for seed_value in range(20):
		PlayerState.rng.seed = seed_value
		PlayerState.set_last_stage_result(_result(3, "morning", "benny"))
		assert(RandomEvents.prepare(PlayerState).is_empty(), "Minor stories belong to generic passengers only")
	_setup(2, false)
	var story := Economy.stage_complete_story_payload("short-morning-normal", "short", "morning", "normal")
	assert(story.get("story_id", "") == "day_02_station_bill")
	assert(not PlayerState.last_stage_result.get("random_event_checked", false), "The Day2 story must take priority without consuming a generic roll")
	_setup(3, true, "cel")
	PlayerState.set_unique_character_progress("cel", 2)
	story = Economy.stage_complete_story_payload("short-morning-normal", "short", "morning", "normal")
	assert(story.get("story_id", "") == "celina_first_encounter")
	assert(not PlayerState.last_stage_result.get("random_event_checked", false), "Character stories must run before the fallback RNG")


static func _find_minor(wanted := "") -> Dictionary:
	# Search seeds through the production selector, batching fixture disk writes.
	PlayerState._begin_state_batch()
	var payload: Dictionary = {}
	for seed_value in range(1024):
		PlayerState.clear_pending_story()
		PlayerState.rng.seed = seed_value
		PlayerState.set_last_stage_result(_result())
		payload = RandomEvents.prepare(PlayerState)
		if not payload.is_empty() and (wanted.is_empty() or payload.story_id == wanted):
			break
	PlayerState._end_state_batch()
	assert(not payload.is_empty() and (wanted.is_empty() or payload.story_id == wanted), "Expected to find an eligible minor event across fixed fixture seeds")
	return payload


static func _test_single_roll_and_repeat() -> void:
	_setup()
	PlayerState.set_last_seen_story_section("generic_keep_the_change", 2)
	var first := _find_minor("generic_keep_the_change")
	assert(PlayerState.get_last_seen_story_section(first.story_id) == 0, "A fresh repeat starts at its first line rather than the old reward section")
	PlayerState.set_last_seen_story_section(first.story_id, 1)
	var rng_state: int = PlayerState.rng.state
	var same := RandomEvents.prepare(PlayerState)
	assert(same == first and PlayerState.get_last_seen_story_section(first.story_id) == 1 and PlayerState.rng.state == rng_state, "An already selected pending event cannot reroll or reset its checkpoint")
	PlayerState.clear_pending_story()
	assert(RandomEvents.prepare(PlayerState).is_empty())
	PlayerState.set_last_seen_story_section(first.story_id, 2)
	var repeat := _find_minor("generic_keep_the_change")
	assert(repeat.story_id == first.story_id and PlayerState.get_last_seen_story_section(first.story_id) == 0)


static func _test_authored_rewards() -> void:
	for language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(language)
		for id: String in REWARDS:
			_setup()
			PlayerState.money = 100
			PlayerState.stress = 8
			var owner := ActionOwner.new()
			owner.story_payload = Catalog.build(id)
			assert(Payload.validate(owner.story_payload).is_empty())
			for line: Dictionary in owner.story_payload.composition:
				for action: Dictionary in line.get("actions", []):
					await Actions.run(owner, action)
			var reward: Vector2i = REWARDS[id]
			assert(PlayerState.money == 100 + reward.x and PlayerState.stress == 8 - reward.y, "Authored %s reward must match in %s" % [id, language])
			owner.story_payload["replay"] = true
			for line: Dictionary in owner.story_payload.composition:
				for action: Dictionary in line.get("actions", []):
					await Actions.run(owner, action)
			assert(PlayerState.money == 100 + reward.x and PlayerState.stress == 8 - reward.y, "Memory actions cannot grant a second reward")
	StoryLanguageManager.set_language("english")


static func _reader(host: Node, payload: Dictionary):
	PlayerState.set_pending_story(payload)
	var reader = load(STORY_SCENE).instantiate()
	reader.inline_complete_callback = func(_destination: String) -> void: pass
	host.get_tree().root.add_child(reader)
	await host.get_tree().create_timer(0.5).timeout
	assert(not reader.is_input_locked)
	return reader


static func _test_checkpoint_and_replay(host: Node) -> void:
	_setup()
	PlayerState.money = 100
	PlayerState.stress = 8
	var reader = await _reader(host, _find_minor("generic_keep_the_change"))
	assert(reader.current_line_index == 0 and PlayerState.money == 100)
	await reader._show_line(reader.story_lines.size() - 1)
	assert(PlayerState.money == 120 and PlayerState.stress == 7)
	var saved := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	reader.free()
	PlayerState.reset()
	assert(Codec.load_snapshot(PlayerState, saved))
	reader = await _reader(host, PlayerState.get_pending_story())
	assert(reader.current_line_index == reader.story_lines.size() - 1 and PlayerState.money == 120 and PlayerState.stress == 7, "Loading a reward-line checkpoint cannot grant its effects again")
	reader.free()
	PlayerState.clear_pending_story()
	var replay := Catalog.build("generic_keep_the_change")
	replay["replay"] = true
	reader = await _reader(host, replay)
	await reader._show_line(reader.story_lines.size() - 1)
	assert(PlayerState.money == 120 and PlayerState.stress == 7)
	reader.free()
	PlayerState.clear_pending_story()
