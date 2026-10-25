extends RefCounted

const Catalog := preload("res://scripts/story/story_catalog.gd")
const PassengerPool := preload("res://scripts/ride_selection/passenger_pool.gd")

class SelectionContext extends RefCounted:
	var mode := "current_stage"

	func _transition_mode() -> String:
		return mode


static func run() -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	var selection := SelectionContext.new()
	var pool := PassengerPool.new(selection)
	var used_ids: Dictionary = {}
	for character: Dictionary in PlayerState.get_mock_characters():
		if character.id != "jessa":
			used_ids[character.id] = true
	for seen in [false, true]:
		if seen:
			PlayerState.mark_mock_character_seen("jessa")
			PlayerState.set_unique_character_progress("jessa", 1)
		for phase in ["morning", "noon", "night"]:
			PlayerState.set_current_stage_time(phase)
			var jessa := Catalog.get_character_by_id(PlayerState, "jessa")
			assert(jessa.eligible_times == ["morning", "noon"])
			var picked := pool._pick_character_for_distance("short", used_ids, {"jessa": true}, true)
			assert((picked.get("id", "") == "jessa") == (phase != "night"), "The first encounter must be available by day, even after her card has been seen or a ride has completed")
	PlayerState.set_event_value("jessa_runaway_fare_seen", false)
	assert(Catalog.get_character_by_id(PlayerState, "jessa").eligible_times == ["morning", "noon"], "A false event value does not complete the first encounter")
	var copy := Catalog.get_character_by_id(PlayerState, "jessa")
	copy.eligible_times.append("night")
	copy.intro_eligible_times.clear()
	assert(Catalog.get_character_by_id(PlayerState, "jessa").eligible_times == ["morning", "noon"], "Returned availability cannot modify catalog defaults")
	PlayerState.set_current_stage_time("noon")
	selection.mode = PlayerState.TRANSITION_RIDE
	assert(not pool._supports_time_in_selection(Catalog.get_character_by_id(PlayerState, "jessa")), "Availability uses the projected ride phase rather than the current clock")
	PlayerState.set_event_value("jessa_runaway_fare_seen", true)
	assert(pool._supports_time_in_selection(Catalog.get_character_by_id(PlayerState, "jessa")))
	selection.mode = PlayerState.TRANSITION_CURRENT_STAGE
	for phase in ["morning", "noon", "night"]:
		PlayerState.set_current_stage_time(phase)
		var jessa := Catalog.get_character_by_id(PlayerState, "jessa")
		assert(jessa.eligible_times == ["night"])
		var picked := pool._pick_character_for_distance("short", used_ids, {"jessa": true}, true)
		assert((picked.get("id", "") == "jessa") == (phase == "night"), "After her first story, Jessa retains her existing nighttime availability")
	PlayerState.reset()
	assert(Catalog.get_character_by_id(PlayerState, "jessa").eligible_times == ["morning", "noon"])
	print("PASS: Jessa daytime first-offer availability, seen/progress independence, projected phase and later-night availability")
