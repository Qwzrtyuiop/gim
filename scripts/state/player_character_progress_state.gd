extends RefCounted

const StoryCatalog := preload("res://scripts/story/story_catalog.gd")


static func set_current_mock_character(player_state, character_id: String) -> void:
	var safe_character_id: String = str(character_id).strip_edges().to_lower()
	player_state.current_mock_character_id = safe_character_id
	player_state.save_progress()


static func get_current_mock_character_id(player_state) -> String:
	return player_state.current_mock_character_id


static func mark_mock_character_seen(player_state, character_id: String) -> void:
	player_state.seen_mock_characters[character_id] = true
	player_state.save_progress()


static func has_seen_mock_character(player_state, character_id: String) -> bool:
	return bool(player_state.seen_mock_characters.get(character_id, false))


static func unique_character_progress(player_state, character_id: String) -> int:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	if safe_id.is_empty():
		return 0
	return int(player_state.unique_character_progress.get(safe_id, 0))


static func is_unique_character_story_locked(player_state, character_id: String) -> bool:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return false
	return bool(player_state.locked_unique_character_stories.get(safe_id, false))


static func set_unique_character_story_locked(player_state, character_id: String, locked: bool = true) -> bool:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return false
	var should_lock: bool = bool(locked)
	if should_lock:
		player_state.locked_unique_character_stories[safe_id] = true
	else:
		player_state.locked_unique_character_stories.erase(safe_id)
	player_state.save_progress()
	return should_lock


static func set_unique_character_progress(player_state, character_id: String, progress: int) -> int:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	if safe_id.is_empty() or not is_unique_character(safe_id):
		return unique_character_progress(player_state, safe_id)
	player_state.unique_character_progress[safe_id] = maxi(0, int(progress))
	player_state.save_progress()
	return int(player_state.unique_character_progress[safe_id])


static func increment_unique_character_progress(player_state, character_id: String, amount: int = 1) -> int:
	var safe_id: String = str(character_id).strip_edges().to_lower()
	var safe_amount: int = maxi(0, int(amount))
	if safe_id.is_empty() or safe_amount <= 0 or not is_unique_character(safe_id):
		return unique_character_progress(player_state, safe_id)
	if is_unique_character_story_locked(player_state, safe_id):
		return unique_character_progress(player_state, safe_id)
	player_state.unique_character_progress[safe_id] = unique_character_progress(player_state, safe_id) + safe_amount
	player_state.save_progress()
	return int(player_state.unique_character_progress[safe_id])


static func has_consumed_unique_session_dialogue(player_state, entry_id: String) -> bool:
	var safe_entry_id: String = str(entry_id).strip_edges()
	if safe_entry_id.is_empty():
		return false
	return bool(player_state.consumed_unique_session_dialogue.get(safe_entry_id, false))


static func consume_unique_session_dialogue(player_state, entry_id: String) -> void:
	var safe_entry_id: String = str(entry_id).strip_edges()
	if safe_entry_id.is_empty() or has_consumed_unique_session_dialogue(player_state, safe_entry_id):
		return
	player_state.consumed_unique_session_dialogue[safe_entry_id] = true
	player_state.save_progress()


static func is_unique_character(character_id: String) -> bool:
	return StoryCatalog.is_unique_character(character_id)


static func reset_character_progress_state(player_state) -> void:
	player_state.current_mock_character_id = ""
	player_state.seen_mock_characters.clear()
	player_state.unique_character_progress.clear()
	player_state.locked_unique_character_stories.clear()
	player_state.consumed_unique_session_dialogue.clear()
