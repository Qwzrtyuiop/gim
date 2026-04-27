extends RefCounted


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
