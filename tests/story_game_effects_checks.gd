extends RefCounted

const Effects := preload("res://scripts/story/story_game_effects.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")

class StoryOwner extends RefCounted:
	var story_payload: Dictionary = {}


static func run(_host: Node) -> void:
	PlayerState.reset()
	var owner := StoryOwner.new()
	Effects.run(owner, {"type": "set_resource", "resource": "money", "value": 1000})
	Effects.run(owner, {"type": "change_resource", "resource": "money", "amount": -200})
	Effects.run(owner, {"type": "set_resource", "resource": "energy", "value": 999})
	Effects.run(owner, {"type": "set_resource", "resource": "gas", "value": 25.5})
	Effects.run(owner, {"type": "add_gas", "amount": 4.5})
	Effects.run(owner, {"type": "spend_gas", "amount": 7.25})
	Effects.run(owner, {"type": "change_resource", "resource": "karma", "amount": -3})
	assert(PlayerState.money == 800 and PlayerState.energy == PlayerState.max_energy)
	assert(is_equal_approx(PlayerState.gas, 22.75) and PlayerState.karma == -3)
	Effects.run(owner, {"type": "change_resource", "resource": "gas", "amount": -500.0})
	Effects.run(owner, {"type": "change_resource", "resource": "money", "amount": -5000})
	assert(PlayerState.gas == 0.0 and PlayerState.money == 0)
	Effects.run(owner, {"type": "set_resource", "resource": "energy", "value": 1})
	Effects.run(owner, {"type": "restore_energy", "amount": 2})
	assert(PlayerState.energy == 3)
	Effects.run(owner, {"type": "restore_energy"})
	assert(PlayerState.energy == PlayerState.max_energy)
	PlayerState.energy = 3
	Effects.run(owner, {"type": "restore_energy", "amount": 9223372036854775807})
	assert(PlayerState.energy == PlayerState.max_energy, "Oversized recovery must fill energy without integer overflow")

	Effects.run(owner, {"type": "set_upgrade_level", "id": "engine_tune", "level": 50})
	assert(PlayerState.get_upgrade_level("engine_tune") == 5)
	Effects.run(owner, {"type": "add_upgrade_level", "id": "engine_tune", "amount": -2})
	assert(PlayerState.get_upgrade_level("engine_tune") == 3)
	PlayerState.upgrades["tire_grip"] = 5
	Effects.run(owner, {"type": "set_upgrade_level", "id": "tire_grip", "level": 1})
	assert(PlayerState.get_upgrade_level("fuel_efficiency") == 1)
	assert(not PlayerState.upgrades.has("tire_grip"))
	Effects.run(owner, {"type": "increment_event_value", "id": "Benny_Trust"})
	Effects.run(owner, {"type": "increment_event_value", "id": "benny_trust", "amount": 2})
	assert(PlayerState.get_event_value("benny_trust") == 3)

	PlayerState.money = 100
	PlayerState.remaining_debt = 300
	PlayerState.debt_carryover = 40
	PlayerState.last_debt_collection_day = 8
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	Effects.run(owner, {"type": "pay_debt", "amount": 200})
	assert(PlayerState.money == 0 and PlayerState.remaining_debt == 200)
	assert(PlayerState.get_meta("test_save_count", 0) - saves == 1)
	assert(PlayerState.last_debt_collection_day == 8 and PlayerState.debt_carryover == 40)
	Effects.run(owner, {"type": "forgive_debt", "amount": 999})
	assert(PlayerState.remaining_debt == 0 and PlayerState.money == 0)
	assert(PlayerState.last_debt_collection_day == 8 and PlayerState.debt_carryover == 40)

	Effects.run(owner, {"type": "set_weather", "weather": "heavy-rain"})
	assert(PlayerState.get_stage_weather("morning") == "heavy rain", "Explicit story weather works even on Day 1")
	assert(PlayerState.get_stage_weather("noon") == "clear", "Story weather changes only the current phase")
	Codec.save_to_path(PlayerState, "res://test_user/story_effects.tres", PlayerState.SAVE_VERSION)
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/story_effects.tres"))
	assert(PlayerState.get_upgrade_level("fuel_efficiency") == 1 and PlayerState.get_event_value("benny_trust") == 3)
	assert(PlayerState.get_stage_weather("morning") == "heavy rain" and PlayerState.remaining_debt == 0)

	var snapshot := _snapshot()
	saves = PlayerState.get_meta("test_save_count", 0)
	for invalid: Dictionary in [
		{"type": "set_resource", "resource": "remaining_debt", "value": 100},
		{"type": "set_resource", "resource": "money", "value": "500"},
		{"type": "set_resource", "resource": "energy", "value": 1.5},
		{"type": "set_upgrade_level", "id": "unknown_upgrade", "level": 4},
		{"type": "set_weather", "weather": "snow"},
		{"type": "pay_debt", "amount": -5},
		{"type": "increment_event_value", "id": 7},
		{"type": "change_resource", "resource": "gas", "amount": INF},
	]:
		assert(not Effects.validate(invalid).is_empty())
		Effects.run(owner, invalid)
	assert(_snapshot() == snapshot and PlayerState.get_meta("test_save_count", 0) == saves, "Rejected effects must not partially change or save state")
	PlayerState.set_event_value("not_a_counter", "text")
	saves = PlayerState.get_meta("test_save_count", 0)
	Effects.run(owner, {"type": "increment_event_value", "id": "not_a_counter"})
	Effects.run(owner, {"type": "spend_gas", "amount": PlayerState.max_gas + 1.0})
	assert(PlayerState.get_event_value("not_a_counter") == "text" and PlayerState.get_meta("test_save_count", 0) == saves)

	for replay_key: String in ["replay", "memory_replay"]:
		owner.story_payload = {replay_key: true}
		snapshot = _snapshot()
		saves = PlayerState.get_meta("test_save_count", 0)
		for action: Dictionary in [
			{"type": "set_resource", "resource": "money", "value": 500},
			{"type": "increment_event_value", "id": "benny_trust"},
			{"type": "set_weather", "weather": "rain"},
			{"type": "set_upgrade_level", "id": "engine_tune", "level": 1},
			{"type": "forgive_debt", "amount": 100},
		]:
			assert(Effects.is_persistent(str(action.type)))
			Effects.run(owner, action)
		assert(_snapshot() == snapshot and PlayerState.get_meta("test_save_count", 0) == saves)
	PlayerState.reset()
	assert(PlayerState.get_stage_weather("morning") == "clear", "Ordinary Day 1 weather remains unchanged")
	print("PASS: narrative resources, capped/legacy upgrades, counters, debt, phase weather, save/load, rejected input and replay isolation")


static func _snapshot() -> Dictionary:
	return {
		"money": PlayerState.money,
		"energy": PlayerState.energy,
		"gas": PlayerState.gas,
		"karma": PlayerState.karma,
		"upgrades": PlayerState.upgrades.duplicate(true),
		"events": PlayerState.get_event_values(),
		"debt": PlayerState.remaining_debt,
		"carryover": PlayerState.debt_carryover,
		"collection_day": PlayerState.last_debt_collection_day,
		"weather": PlayerState.weather_phase_cache.duplicate(true),
	}
