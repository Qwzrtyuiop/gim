extends RefCounted

const InputHelper := preload("res://scripts/game/game_input.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const HornTraffic := preload("res://scripts/game/vehicle_horn_response.gd")


static func handle_input(owner, event: InputEvent) -> bool:
	if not InputHelper.is_horn_event(event):
		return false
	if not event.pressed:
		stop(owner)
		return true
	if not allowed(owner):
		# Preserve any-key tutorial/end-screen input when driving is locked.
		return false
	if owner.horn_held:
		return true
	owner.horn_held = true
	owner.audio_manager.set_horn_active(true)
	if owner.horn_press_cooldown <= 0.0:
		owner.horn_press_cooldown = Tuning.HORN_PRESS_COOLDOWN
		HornTraffic.press(owner)
	return true


static func allowed(owner) -> bool:
	return (
		owner.game_state == "playing"
		and not owner.crash_repair_transition_active
		and not owner.get_tree().paused
		and (owner.stage_tutorial == null or not owner.stage_tutorial.active and not owner.stage_tutorial.input_lock_active)
	)


static func update(owner, delta: float) -> void:
	owner.horn_press_cooldown = maxf(0.0, owner.horn_press_cooldown - delta)
	if owner.horn_held and (not allowed(owner) or not InputHelper.is_horn_pressed()):
		stop(owner)
	if allowed(owner):
		HornTraffic.update(owner, delta)


static func stop(owner) -> void:
	owner.horn_held = false
	if is_instance_valid(owner.audio_manager):
		owner.audio_manager.stop_horn()
