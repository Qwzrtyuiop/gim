extends RefCounted

const Conditions := preload("res://scripts/story/story_conditions.gd")
const Interface := preload("res://scripts/story/story_interface.gd")


class ChoiceOwner extends Control:
	var choice_container := VBoxContainer.new()
	var continue_label := Label.new()
	var choice_buttons: Array[BaseButton] = []
	var selected: Dictionary = {}

	func _init() -> void:
		add_child(choice_container)
		add_child(continue_label)

	func _choose_branch(choice: Dictionary) -> void:
		selected = choice


static func run(host: Node) -> void:
	PlayerState.reset()
	PlayerState.money = 250
	PlayerState.energy = 4
	PlayerState.gas = 35.5
	PlayerState.karma = -1
	PlayerState.current_day = 4
	PlayerState.current_phase = "noon"
	PlayerState.current_weather = "rain"
	PlayerState.upgrades = {"engine_tune": 2}
	PlayerState.unique_character_progress = {"ely": 3}
	PlayerState.event_values = {"trust": 3, "known_false": false, "zero": 0}
	var saves: int = PlayerState.get_meta("test_save_count", 0)

	assert(Conditions.matches_story_conditions({"min_money": 250}))
	assert(not Conditions.matches_story_conditions({"required_money_at_least": 251}))
	assert(Conditions.matches_story_conditions({"required_event": "known_false", "required_event_value": {"zero": 0}}))
	assert(Conditions.matches_story_conditions({"conditions": {
		"energy": 4, "min_gas": 35.0, "max_gas": 36.0, "max_karma": 0,
		"day": 4, "week": 1, "min_remaining_debt": 1,
		"phase": "noon", "weather": "rain",
		"min_upgrade_levels": {"engine_tune": 2},
		"character_id": "ely", "min_character_progress": 3,
		"event_value_ranges": {"trust": {"min": 2, "max": 4, "more_than": 1, "less_than": 5}},
	}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"min_energy": 5}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"max_gas": 35}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"weather": "clear"}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"min_upgrade_levels": {"engine_tune": 3}}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"min_character_progress": 1}}), "Progress conditions require an explicit character")
	assert(not Conditions.matches_story_conditions({"conditions": {"event_value_ranges": {"missing": {"min": 0}}}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"event_value_ranges": {"known_false": {"equals": 0}}}}), "Booleans are not numeric counters")
	assert(Conditions.matches_story_conditions({"required_min_energy": 4}))
	assert(not Conditions.matches_story_conditions({"required_min_energy": 5}))
	assert(Conditions.matches_story_conditions({"type": "set_weather", "weather": "clear", "day": 100, "energy": 100}), "Action parameters must not become implicit conditions")

	assert(Conditions.matches_story_conditions({"conditions": {"all": [
		{"min_energy": 4}, {"any": [{"min_money": 500}, {"phase": "noon"}]}, {"not": {"max_gas": 10}},
	]}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"any": []}}))
	assert(Conditions.matches_story_conditions({"conditions": {"all": []}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"not": "invalid"}}))
	assert(not Conditions.matches_story_conditions({"conditions": {"min_energy": "many"}}))
	for malformed in [
		{"min_energy": "bad"},
		{"event_value_ranges": {"trust": {"min": "bad"}}},
		{"event_value_ranges": {"trust": {"typo": 1}}},
		{"min_upgrade_levels": {"engine_tune": "bad"}},
		{"max_upgrade_levels": {"unknown_upgrade": 0}},
		{"max_upgrade_levels": {"engine_tune": 0.5}},
		{"phase": "dusk"},
		{"min_character_progress": 1},
	]:
		assert(not Conditions.matches_story_conditions({"conditions": {"not": malformed}}), "Malformed leaf conditions must fail closed under negation")
	assert(not Conditions.matches_story_conditions({"conditions": {"max_upgrade_levels": {"unknown_upgrade": 0}}}))
	assert(not Conditions.matches_story_conditions({"required_max_upgrade_levels": {"unknown_upgrade": 0}}))
	assert(Conditions.matches_story_conditions({"conditions": {"max_upgrade_levels": {"tire_grip": 0}}}), "Legacy upgrade ID is an intentional compatibility alias")
	var deep: Dictionary = {"min_energy": 1}
	for level in range(32):
		deep = {"not": deep}
	assert(not Conditions.matches_story_conditions({"conditions": deep}), "Over-deep negation must fail closed")
	assert(PlayerState.get_meta("test_save_count", 0) == saves, "Condition checks must not save progress")

	var owner := ChoiceOwner.new()
	host.add_child(owner)
	Interface.render_choices(owner, {"choices": [
		{"text": "Hidden", "conditions": {"min_energy": 10}},
		{"text": "Buy fuel", "conditions": {"min_money": 500}, "show_locked": true, "locked_text": "Kulang ang pera", "locked_reason": "Requires PhP 500."},
		{"text": "Leave", "next_index": 2},
	]})
	assert(owner.choice_buttons.size() == 2)
	assert(owner.choice_buttons[0].disabled and owner.choice_buttons[0].text == "Kulang ang pera")
	assert(owner.choice_buttons[0].tooltip_text == "Requires PhP 500.")
	owner.choice_buttons[0].pressed.emit()
	assert(owner.selected.is_empty(), "Locked choices must have no branch callback")
	assert(Interface.has_active_choices(owner) and not owner.continue_label.visible)
	assert(not owner.choice_buttons[1].disabled and owner.choice_buttons[1].text == "Leave")
	Interface.render_choices(owner, {"choices": [
		{"text": "Unavailable", "show_locked": true, "conditions": {"min_energy": 20}},
	]})
	assert(owner.choice_container.get_child_count() == 1, "Re-rendering removes old button controls immediately")
	assert(owner.choice_container.visible and not Interface.has_active_choices(owner))
	assert(owner.continue_label.visible, "An all-locked list must permit the line's fallback route")
	Interface.render_choices(owner, {"choices": [{"text": "Hidden", "conditions": {"min_energy": 20}}]})
	assert(owner.choice_buttons.is_empty() and not owner.choice_container.visible and owner.continue_label.visible)
	owner.free()
	assert(PlayerState.get_meta("test_save_count", 0) == saves, "Rendering options must not change or save game state")
	PlayerState.reset()
	print("PASS: resource/calendar/weather/upgrade/progress/counter conditions, boolean groups, and visible locked choices with safe continuation")
