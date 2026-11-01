extends RefCounted

# Passing keeps the logical lane fixed while presentation moves between lanes.
const GameTuning := preload("res://scripts/config/game_tuning.gd")


static func try_start(owner) -> bool:
	if owner.game_state != "playing" or owner.crash_repair_transition_active:
		return false
	if owner.get_tree().paused or not is_instance_valid(owner.player):
		return false
	if owner.player_hit_recovery_timer > 0.0 or owner.player_passing_cooldown > 0.0 or is_active(owner):
		return false
	if owner.stage_tutorial != null and (owner.stage_tutorial.active or owner.stage_tutorial.input_lock_active):
		return false
	if owner.alma_delivery_equipment != null and owner.alma_delivery_equipment.tutorial_active:
		return false
	if PlayerState.stage_uses_gas() and not PlayerState.spend_gas(GameTuning.PLAYER_PASSING_GAS_COST_PERCENT):
		return false
	owner.player_passing_origin_lane = clampi(owner.player_lane, 0, 2)
	owner.player_passing_time_left = GameTuning.PLAYER_PASSING_SECONDS
	owner.player_passing_cooldown = GameTuning.PLAYER_PASSING_COOLDOWN_SECONDS
	owner.player_passing_blend = 0.0
	return true


static func update(owner, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if owner.game_state != "playing":
		cancel(owner)
		return
	owner.player_passing_cooldown = maxf(0.0, owner.player_passing_cooldown - delta)
	if owner.player_hit_recovery_timer > 0.0:
		cancel(owner)
		return
	owner.player_passing_time_left = maxf(0.0, owner.player_passing_time_left - delta)
	var target := 1.0 if owner.player_passing_time_left > 0.0 else 0.0
	owner.player_passing_blend = move_toward(
		clampf(owner.player_passing_blend, 0.0, 1.0),
		target,
		delta / GameTuning.PLAYER_PASSING_TRANSITION_SECONDS
	)
	if not is_active(owner):
		owner.player_passing_origin_lane = -1


static func reset(owner) -> void:
	cancel(owner)
	owner.player_passing_cooldown = 0.0


static func cancel(owner) -> void:
	owner.player_passing_time_left = 0.0
	owner.player_passing_blend = 0.0
	owner.player_passing_origin_lane = -1


static func is_active(owner) -> bool:
	return owner.player_passing_time_left > 0.0 or owner.player_passing_blend > 0.001


static func blend(owner) -> float:
	return clampf(owner.player_passing_blend, 0.0, 1.0)


static func adjacent_lane(owner) -> int:
	var origin: int = owner.player_passing_origin_lane
	if origin < 0:
		origin = clampi(owner.player_lane, 0, 2)
	return 1 if origin == 0 else origin - 1
