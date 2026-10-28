extends RefCounted

# Nested event data already participates in the version-5 save/reset contract.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const EVENT_ID := "beta_blocker_stress_shield"
const MAX_POINTS := GameTuning.BETA_BLOCKER_STRESS_SHIELD_POINTS


static func points(player_state) -> int:
	var shield := _record(player_state)
	return clampi(int(shield.get("points", 0)), 0, MAX_POINTS)


static func has_shield(player_state) -> bool:
	var shield := _record(player_state)
	return bool(shield.get("active", false)) or points(player_state) > 0


static func is_pending(player_state) -> bool:
	var shield := _record(player_state)
	return not bool(shield.get("active", false)) and points(player_state) > 0


static func grant(player_state, amount: int = MAX_POINTS) -> bool:
	if has_shield(player_state) or amount <= 0:
		return false
	_store(player_state, {
		"points": clampi(amount, 1, MAX_POINTS),
		"active": false,
	})
	return true


static func begin_ride(player_state) -> void:
	if not is_pending(player_state):
		return
	var shield := _record(player_state)
	shield["active"] = true
	_store(player_state, shield)


static func absorb(player_state, amount: int) -> int:
	var shield := _record(player_state)
	if amount <= 0 or not bool(shield.get("active", false)):
		return 0
	var absorbed := mini(amount, points(player_state))
	if absorbed > 0:
		shield["points"] = points(player_state) - absorbed
		_store(player_state, shield)
	return absorbed


static func finish_ride(player_state) -> void:
	# Pending medicine waits for a ride; unused active points expire with that ride.
	if not bool(_record(player_state).get("active", false)):
		return
	player_state.clear_event_value(EVENT_ID)
	player_state.stress_shield_changed.emit(0)


static func _record(player_state) -> Dictionary:
	var stored: Variant = player_state.get_event_value(EVENT_ID, {})
	return stored.duplicate(true) if stored is Dictionary else {}


static func _store(player_state, shield: Dictionary) -> void:
	player_state.set_event_value(EVENT_ID, shield)
	player_state.stress_shield_changed.emit(points(player_state))
