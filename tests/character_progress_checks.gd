extends RefCounted

const Economy := preload("res://scripts/game/game_economy_manager.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")


static func run() -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	PlayerState.reset()
	var unique_ids: Array[String] = []
	var generic_id := ""
	for character: Dictionary in PlayerState.get_mock_characters():
		var id := str(character.id)
		if PlayerState.is_unique_character(id):
			unique_ids.append(id)
		else:
			generic_id = id
	assert(not unique_ids.is_empty() and not generic_id.is_empty())
	for passenger_id: String in unique_ids:
		PlayerState.reset()
		PlayerState.set_current_mock_character(passenger_id)
		_complete_ride()
		_assert_only_passenger_progress(unique_ids, passenger_id)
		var snapshot := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
		PlayerState.unique_character_progress.clear()
		PlayerState.character_completed_rides.clear()
		assert(Codec.load_snapshot(PlayerState, snapshot))
		_assert_only_passenger_progress(unique_ids, passenger_id)
		# Catalog reads and viewing the terminal must not award any other bond.
		PlayerState.get_mock_characters()
		for other_id: String in unique_ids:
			PlayerState.get_character_by_id(other_id)
			PlayerState.get_unique_character_story_state(other_id)
		_assert_only_passenger_progress(unique_ids, passenger_id)

	PlayerState.reset()
	PlayerState.set_current_mock_character(generic_id)
	_complete_ride()
	_assert_only_passenger_progress(unique_ids, "")
	PlayerState.set_current_mock_character(unique_ids[0])
	Economy.store_failed_stage_result("short-noon-normal", "short", "noon", "normal", "", "", 50, 200, "TIME OUT")
	_assert_only_passenger_progress(unique_ids, "")
	PlayerState.set_unique_character_story_locked(unique_ids[0], true)
	_complete_ride()
	for id: String in unique_ids:
		assert(PlayerState.get_unique_character_progress(id) == 0, "A locked story must not grant bond to any character")
		assert(int(PlayerState.character_completed_rides.get(id, 0)) == (1 if id == unique_ids[0] else 0), "Completed rides remain passenger-specific even while bond is locked")
	PlayerState.reset()
	print("PASS: every named passenger gains only their own bond, save/load and catalog reads cannot spread it, generic/failed rides grant none, and story locks preserve independent ride counts")


static func _complete_ride() -> void:
	Economy.store_stage_result("short-morning-normal", "short", "morning", "normal", "", "", 200, 200, 1.0, 0.0, 0.0, 10.0, 2.0, 0)


static func _assert_only_passenger_progress(unique_ids: Array[String], passenger_id: String) -> void:
	for id: String in unique_ids:
		var expected := 1 if id == passenger_id else 0
		assert(PlayerState.get_unique_character_progress(id) == expected, "Completing %s must not award bond to %s" % [passenger_id, id])
		assert(int(PlayerState.character_completed_rides.get(id, 0)) == expected, "Completed ride counts must remain independent for every passenger")
