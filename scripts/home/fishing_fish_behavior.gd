extends RefCounted

# Interest and bite decisions happen once per timed attempt, independent of FPS.
# The session integrates the returned velocity and owns respawn/hook attachment.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const WATER_ASPECT := 1665.0 / 585.0
const CHECK_DISTANCE := 0.025
const APPROACH_SECONDS := 5.0
const BITE_SECONDS := 2.0


static func initialize(entry: Dictionary, rng: RandomNumberGenerator) -> void:
	var velocity: Vector2 = entry.velocity
	entry.behavior = "cruising"
	entry.cruise_speed = maxf(absf(velocity.x), 0.035)
	entry.interest_timer = rng.randf_range(1.2, 2.5)
	entry.approach_timer = 0.0
	entry.check_timer = 0.0
	entry.check_elapsed = 0.0
	entry.bite_timer = 0.0
	entry.inspection_facing = int(entry.get("facing", 1))


static func steer(entry: Dictionary, hook_tip: Vector2, delta: float, rng: RandomNumberGenerator, hook_available: bool) -> void:
	if not entry.has("behavior"):
		initialize(entry, rng)
	var behavior := str(entry.behavior)
	if behavior != "cruising" and not hook_available:
		_resume_cruising(entry, hook_tip, rng)
		return
	match behavior:
		"approaching":
			entry.approach_timer = float(entry.get("approach_timer", APPROACH_SECONDS)) - delta
			if float(entry.approach_timer) <= 0.0:
				_resume_cruising(entry, hook_tip, rng)
				return
			if _water_distance(_mouth(entry), hook_tip) <= CHECK_DISTANCE:
				entry.behavior = "checking"
				entry.check_timer = rng.randf_range(0.7, 1.4)
				entry.check_elapsed = 0.0
			_swim_to_mouth(entry, hook_tip, delta)
		"checking":
			# A moving hook must still be nearby when the fish decides to bite.
			if _water_distance(_mouth(entry), hook_tip) > GameTuning.FISHING_HOOK_INTEREST_RADIUS * 1.5:
				_resume_cruising(entry, hook_tip, rng)
				return
			entry.check_elapsed = float(entry.get("check_elapsed", 0.0)) + delta
			entry.check_timer = float(entry.get("check_timer", 0.7)) - delta
			if float(entry.check_timer) <= 0.0:
				if rng.randf() < GameTuning.FISHING_HOOK_BITE_CHANCE:
					entry.behavior = "biting"
					entry.bite_timer = BITE_SECONDS
					_swim_to_mouth(entry, hook_tip, delta)
				else:
					_resume_cruising(entry, hook_tip, rng)
				return
			var elapsed := float(entry.check_elapsed)
			var inspect_offset := Vector2(sin(elapsed * 5.0) * 0.008 / WATER_ASPECT, cos(elapsed * 4.0) * 0.012)
			_swim_to_mouth(entry, hook_tip + inspect_offset, delta)
		"biting":
			entry.bite_timer = float(entry.get("bite_timer", BITE_SECONDS)) - delta
			if float(entry.bite_timer) <= 0.0:
				_resume_cruising(entry, hook_tip, rng)
				return
			_swim_to_mouth(entry, hook_tip, delta)
		_:
			_cruise(entry, hook_tip, delta, rng, hook_available)


static func _cruise(entry: Dictionary, hook_tip: Vector2, delta: float, rng: RandomNumberGenerator, hook_available: bool) -> void:
	var velocity: Vector2 = entry.velocity
	entry.turn_timer = float(entry.get("turn_timer", 1.0)) - delta
	if float(entry.turn_timer) <= 0.0:
		entry.turn_timer = rng.randf_range(1.0, 3.5)
		if rng.randf() < 0.4:
			velocity.x *= -1.0
	velocity.y = 0.0
	entry.velocity = velocity
	if not is_zero_approx(velocity.x):
		entry.facing = 1 if velocity.x > 0.0 else -1
	entry.interest_timer = float(entry.get("interest_timer", 1.2)) - delta
	if float(entry.interest_timer) > 0.0:
		return
	entry.interest_timer = rng.randf_range(1.2, 2.5)
	var position: Vector2 = entry.position
	if not hook_available or position.x < 0.0 or position.x > 1.0:
		return
	if _water_distance(_mouth(entry), hook_tip) > GameTuning.FISHING_HOOK_INTEREST_RADIUS:
		return
	if rng.randf() >= GameTuning.FISHING_HOOK_CHECK_CHANCE:
		return
	entry.behavior = "approaching"
	entry.approach_timer = APPROACH_SECONDS
	var horizontal := hook_tip.x - position.x
	entry.inspection_facing = int(entry.get("facing", 1)) if absf(horizontal) < 0.005 else (1 if horizontal > 0.0 else -1)
	entry.facing = entry.inspection_facing
	_swim_to_mouth(entry, hook_tip, delta)


static func _swim_to_mouth(entry: Dictionary, target: Vector2, delta: float) -> void:
	# Keep the selected facing throughout inspection so the authored mouth cannot flip.
	entry.facing = int(entry.get("inspection_facing", entry.get("facing", 1)))
	var offset := target - _mouth(entry)
	var water_offset := Vector2(offset.x * WATER_ASPECT, offset.y)
	var distance := water_offset.length()
	var speed := minf(GameTuning.FISHING_HOOK_INSPECT_SPEED, distance / maxf(delta, 0.00001))
	var velocity := water_offset.normalized() * speed
	entry.velocity = Vector2(velocity.x / WATER_ASPECT, velocity.y)


static func _resume_cruising(entry: Dictionary, hook_tip: Vector2, rng: RandomNumberGenerator) -> void:
	var position: Vector2 = entry.position
	var direction := -1 if int(entry.get("facing", 1)) > 0 else 1
	if absf(position.x - hook_tip.x) > 0.005:
		direction = 1 if position.x > hook_tip.x else -1
	entry.behavior = "cruising"
	entry.velocity = Vector2(float(direction) * float(entry.get("cruise_speed", 0.05)), 0.0)
	entry.facing = direction
	entry.turn_timer = rng.randf_range(1.5, 3.5)
	entry.interest_timer = rng.randf_range(4.0, 8.0)
	entry.approach_timer = 0.0
	entry.check_timer = 0.0
	entry.check_elapsed = 0.0
	entry.bite_timer = 0.0


static func _mouth(entry: Dictionary) -> Vector2:
	var position: Vector2 = entry.position
	var offset: Vector2 = entry.get("mouth_offset", Vector2.ZERO)
	return position + Vector2(offset.x * int(entry.get("facing", 1)), offset.y)


static func _water_distance(from: Vector2, to: Vector2) -> float:
	var offset := to - from
	return Vector2(offset.x * WATER_ASPECT, offset.y).length()
