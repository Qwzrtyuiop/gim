extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")


static func story_upgrade_definition(upgrade_id: String) -> Dictionary:
	var safe_id := upgrade_id.strip_edges().to_lower()
	if safe_id == "tire_grip":
		safe_id = "fuel_efficiency"
	for item: Dictionary in GameTuning.STORE_ITEMS:
		if item.get("type", "") == "upgrade" and item.get("id", "") == safe_id:
			return item.duplicate(true)
	return {}


static func set_story_upgrade_level(player_state, upgrade_id: String, level: int) -> bool:
	var definition := story_upgrade_definition(upgrade_id)
	if definition.is_empty():
		return false
	var safe_id: String = definition.id
	player_state._begin_state_batch()
	# The old key must not override an explicit new level through max(old, new).
	if safe_id == player_state.FUEL_EFFICIENCY_UPGRADE_ID:
		player_state.upgrades.erase(player_state.LEGACY_TIRE_GRIP_UPGRADE_ID)
	set_upgrade_level(player_state, safe_id, clampi(level, 0, int(definition.max_level)))
	player_state._end_state_batch()
	return true


static func set_upgrade_level(player_state, upgrade_id: String, level: int) -> void:
	var safe_level: int = max(0, level)
	player_state.upgrades[upgrade_id] = safe_level
	player_state.upgrade_changed.emit(upgrade_id, safe_level)
	player_state.save_progress()


static func get_upgrade_level(player_state, upgrade_id: String) -> int:
	if upgrade_id == player_state.FUEL_EFFICIENCY_UPGRADE_ID:
		return maxi(
			int(player_state.upgrades.get(player_state.FUEL_EFFICIENCY_UPGRADE_ID, 0)),
			int(player_state.upgrades.get(player_state.LEGACY_TIRE_GRIP_UPGRADE_ID, 0))
		)
	return int(player_state.upgrades.get(upgrade_id, 0))


static func fuel_efficiency_level(player_state) -> int:
	return get_upgrade_level(player_state, player_state.FUEL_EFFICIENCY_UPGRADE_ID)
