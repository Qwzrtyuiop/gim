extends RefCounted


static func set_pending_trip_selection(player_state, return_scene: String, transition_mode: String, allow_back: bool = true) -> void:
	var safe_transition_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	var should_preserve_locked_selection: bool = (
		safe_transition_mode == player_state.TRANSITION_RIDE
		or safe_transition_mode == player_state.TRANSITION_CURRENT_STAGE
	)
	var locked_characters: Array = []
	var locked_character_pools: Dictionary = {}
	var locked_distance: String = ""
	if should_preserve_locked_selection:
		locked_characters = player_state.pending_trip_selection.get("locked_characters", [])
		locked_characters = locked_characters.duplicate(true)
		locked_character_pools = Dictionary(player_state.pending_trip_selection.get("locked_character_pools", {})).duplicate(true)
		locked_distance = str(player_state.pending_trip_selection.get("selected_distance", ""))
	player_state.pending_trip_selection = {
		"return_scene": return_scene,
		"transition_mode": safe_transition_mode,
		"allow_back": bool(allow_back),
	}
	if not locked_character_pools.is_empty():
		player_state.pending_trip_selection["locked_character_pools"] = locked_character_pools
	if not locked_characters.is_empty():
		player_state.pending_trip_selection["locked_characters"] = locked_characters
	if player_state.STAGE_DIFFICULTIES.has(locked_distance):
		player_state.pending_trip_selection["selected_distance"] = locked_distance
	player_state.save_progress()


static func get_pending_trip_selection(player_state) -> Dictionary:
	return player_state.pending_trip_selection.duplicate(true)


static func has_locked_pending_trip_selection(player_state) -> bool:
	var locked_character_pools: Dictionary = Dictionary(player_state.pending_trip_selection.get("locked_character_pools", {}))
	for difficulty_variant in player_state.STAGE_DIFFICULTIES:
		var difficulty: String = str(difficulty_variant)
		var pool: Array = locked_character_pools.get(difficulty, [])
		if not pool.is_empty():
			return true
	var locked_characters: Array = player_state.pending_trip_selection.get("locked_characters", [])
	return not locked_characters.is_empty()


static func get_locked_pending_trip_character_pools(player_state) -> Dictionary:
	var locked_character_pools: Dictionary = Dictionary(player_state.pending_trip_selection.get("locked_character_pools", {}))
	return locked_character_pools.duplicate(true)


static func get_locked_pending_trip_characters(player_state) -> Array:
	var locked_character_pools: Dictionary = Dictionary(player_state.pending_trip_selection.get("locked_character_pools", {}))
	if not locked_character_pools.is_empty():
		var selected_distance: String = get_locked_pending_trip_distance(player_state)
		if selected_distance.is_empty():
			selected_distance = "short"
		var selected_pool: Array = locked_character_pools.get(selected_distance, [])
		return selected_pool.duplicate(true)
	var locked_characters: Array = player_state.pending_trip_selection.get("locked_characters", [])
	return locked_characters.duplicate(true)


static func get_locked_pending_trip_distance(player_state) -> String:
	var locked_distance: String = str(player_state.pending_trip_selection.get("selected_distance", ""))
	return locked_distance if player_state.STAGE_DIFFICULTIES.has(locked_distance) else ""


static func lock_pending_trip_selection(player_state, locked_character_data, selected_distance: String) -> void:
	player_state.pending_trip_selection.erase("locked_characters")
	player_state.pending_trip_selection.erase("locked_character_pools")
	if locked_character_data is Dictionary:
		player_state.pending_trip_selection["locked_character_pools"] = Dictionary(locked_character_data).duplicate(true)
	elif locked_character_data is Array:
		player_state.pending_trip_selection["locked_characters"] = Array(locked_character_data).duplicate(true)
	player_state.pending_trip_selection["selected_distance"] = selected_distance if player_state.STAGE_DIFFICULTIES.has(selected_distance) else "short"
	player_state.save_progress()


static func clear_pending_trip_selection(player_state) -> void:
	player_state.pending_trip_selection.clear()
	player_state.save_progress()


static func set_pending_story(player_state, story_payload: Dictionary, save_immediately: bool = true) -> void:
	player_state.pending_story = story_payload.duplicate(true)
	if save_immediately:
		player_state.save_progress()


static func get_pending_story(player_state) -> Dictionary:
	return player_state.pending_story.duplicate(true)


static func clear_pending_story(player_state) -> void:
	player_state.pending_story.clear()
	player_state.save_progress()


static func set_pending_sleep_transition_state(player_state, state: Dictionary) -> void:
	player_state.pending_sleep_transition_state = state.duplicate(true)
	player_state.save_progress()


static func get_pending_sleep_transition_state(player_state) -> Dictionary:
	return player_state.pending_sleep_transition_state.duplicate(true)


static func clear_pending_sleep_transition_state(player_state) -> void:
	player_state.pending_sleep_transition_state.clear()
	player_state.save_progress()


static func set_pending_gameplay_entry_fade(player_state, duration: float) -> void:
	player_state.pending_gameplay_entry_fade_duration = maxf(0.0, duration)
	player_state.save_progress()


static func consume_pending_gameplay_entry_fade(player_state) -> float:
	var duration: float = player_state.pending_gameplay_entry_fade_duration
	player_state.pending_gameplay_entry_fade_duration = 0.0
	player_state.save_progress()
	return maxf(0.0, duration)


static func clear_pending_gameplay_entry_fade(player_state) -> void:
	player_state.pending_gameplay_entry_fade_duration = 0.0
	player_state.save_progress()


static func set_pending_result_music(player_state, music_state: Dictionary) -> void:
	player_state.pending_result_music = music_state.duplicate(true)


static func consume_pending_result_music(player_state) -> Dictionary:
	var music_state: Dictionary = player_state.pending_result_music.duplicate(true)
	player_state.pending_result_music.clear()
	return music_state


static func clear_pending_result_music(player_state) -> void:
	player_state.pending_result_music.clear()


static func has_pending_night_phase_skip(player_state) -> bool:
	return player_state.pending_skip_night_phase


static func set_pending_night_phase_skip(player_state, enabled: bool) -> void:
	player_state.pending_skip_night_phase = bool(enabled)
	player_state.save_progress()


static func clear_pending_night_phase_skip(player_state) -> void:
	if not player_state.pending_skip_night_phase:
		return
	player_state.pending_skip_night_phase = false
	player_state.save_progress()


static func set_sleep_transition_resume_step(player_state, resume_step: String) -> void:
	player_state.pending_sleep_transition_state["resume_step"] = resume_step
	player_state.save_progress()


static func get_sleep_transition_resume_step(player_state) -> String:
	return str(player_state.pending_sleep_transition_state.get("resume_step", ""))


static func reset_pending_runtime_state(player_state) -> void:
	player_state.active_event_special_stage.clear()
	player_state.pending_stage_energy_cost = false
	player_state.pending_trip_selection.clear()
	player_state.pending_story.clear()
	player_state.pending_sleep_transition_state.clear()
	player_state.pending_gameplay_entry_fade_duration = 0.0
	player_state.pending_crash_repair.clear()
	player_state.pending_result_music.clear()
	player_state.pending_skip_night_phase = false
