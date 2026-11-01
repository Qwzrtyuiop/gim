extends RefCounted

# Scene-local prototype state. Positions and fish sizes use water-space fractions.
signal fish_hooked(id: int)
signal fish_caught(total: int)
signal line_snapped(tip_position: Vector2)

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const FishingLine := preload("res://scripts/home/fishing_line.gd")
const FishSpecies := preload("res://scripts/home/fishing_species_catalog.gd")
const FishBehavior := preload("res://scripts/home/fishing_fish_behavior.gd")
const FishSchools := preload("res://scripts/home/fishing_fish_schools.gd")
const SURFACE_DEPTH := 0.04
const MAX_DEPTH := 0.92
const MIN_X := 0.05
const MAX_X := 0.95
const MIN_LINE_LENGTH := FishingLine.MIN_LENGTH
const MAX_LINE_LENGTH := FishingLine.MAX_LENGTH
const WATER_ASPECT := FishingLine.WATER_ASPECT
const ANCHOR_DEPTH := FishingLine.ANCHOR_DEPTH

var _line := FishingLine.new()
var _schools := FishSchools.new()
var _hook_position := Vector2(0.57, 0.07)
var hook_position: Vector2:
	get:
		return _hook_position
	set(value):
		teleport_hook(value)
var hook_tip_offset := Vector2.ZERO
var line_anchor_x := 0.57
var line_points: Array[Vector2] = []
var line_length := 0.055
var fish: Array[Dictionary] = []
var caught_count := 0
var catches: Array[Dictionary] = []
var hooked_fish_id := -1
var line_state := "free"
var last_event := ""
var reel_held := false
var fight_phase := "free"
var fight_seconds_left := 0.0
var automatic_reel_angle := 0.0
var reel_flick_speed := 0.0
var line_pressure := 0.0

var _rng := RandomNumberGenerator.new()
var _catch_rng := RandomNumberGenerator.new()
var _current_velocity := 0.0
var _current_target := 0.0
var _current_timer := 0.0
var _anchor_velocity := 0.0
var _anchor_target := 0.0
var _anchor_timer := 0.0
var _fight_velocity := 0.0
var _fight_target_velocity := 0.0
var _fight_direction := 1.0
var _fight_pull_scale := 1.0
var _fight_rest_scale := 1.0
var _fight_sideways_scale := 1.0
var _fight_timer := 0.0
var _pull_rate := 0.0
var _fight_strength := 1.0
var _line_pressure_rate := (GameTuning.FISHING_LINE_PRESSURE_MIN_RATE + GameTuning.FISHING_LINE_PRESSURE_MAX_RATE) * 0.5


func reset(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
		_catch_rng.randomize()
	else:
		_rng.seed = seed_value
		_catch_rng.seed = seed_value
	hook_tip_offset = Vector2.ZERO
	line_anchor_x = 0.57
	_line.reset(_line_anchor(), Vector2(0.57, 0.07))
	_refresh_line()
	caught_count = 0
	catches.clear()
	hooked_fish_id = -1
	line_state = "free"
	last_event = ""
	reel_held = false
	fight_phase = "free"
	fight_seconds_left = 0.0
	automatic_reel_angle = 0.0
	stop_reel_flick()
	line_pressure = 0.0
	_current_velocity = 0.0
	_current_target = 0.0
	_current_timer = 0.0
	_anchor_velocity = 0.0
	_anchor_target = 0.0
	_anchor_timer = 0.0
	_fight_velocity = 0.0
	_reset_fight_profile()
	_pull_rate = 0.0
	_fight_strength = 1.0
	_line_pressure_rate = (GameTuning.FISHING_LINE_PRESSURE_MIN_RATE + GameTuning.FISHING_LINE_PRESSURE_MAX_RATE) * 0.5
	fish.clear()
	for id in range(GameTuning.FISHING_FISH_COUNT):
		fish.append(_make_fish(id))
	_schools.reset(fish, _rng)


func update(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	# Small steps keep fish/hook contact stable during ordinary frame-rate drops.
	var steps := clampi(ceili(delta / (1.0 / 60.0)), 1, 360)
	var step_seconds := delta / float(steps)
	for _index in range(steps):
		_step(step_seconds)


func set_reel_held(value: bool) -> void:
	reel_held = value
	if value:
		stop_reel_flick()


func start_reel_flick(angular_speed: float) -> void:
	if reel_held or hooked_fish_id >= 0 or _line.length >= MAX_LINE_LENGTH or not is_finite(angular_speed):
		return
	if angular_speed < GameTuning.FISHING_REEL_FLICK_MIN_SPEED:
		return
	reel_flick_speed = minf(angular_speed * GameTuning.FISHING_REEL_FLICK_GAIN, GameTuning.FISHING_REEL_FLICK_MAX_SPEED)


func stop_reel_flick() -> void:
	reel_flick_speed = 0.0


func is_line_taut() -> bool:
	return _line.is_taut(_line_anchor())


func is_reel_in_blocked() -> bool:
	return hooked_fish_id >= 0 and fight_phase == "pulling" and is_line_taut()


func reel(angle_delta: float) -> float:
	if not is_finite(angle_delta) or is_zero_approx(angle_delta):
		return 0.0
	if angle_delta < 0.0 and is_reel_in_blocked():
		return 0.0
	var old_tip := hook_tip_position()
	var old_length := line_length
	# Screen-space atan2 grows clockwise: positive lets line out, negative reels in.
	var next_length := line_length + angle_delta * GameTuning.FISHING_REEL_LINE_PER_RADIAN
	var fighting := hooked_fish_id >= 0 and fight_phase == "pulling"
	if fighting and angle_delta < 0.0:
		# Take up slack, stopping at the fish's actual distance rather than moving it.
		next_length = maxf(next_length, _line.endpoint_distance(_line_anchor()))
	_line.set_length(next_length, _line_anchor(), fighting)
	_refresh_line()
	if hooked_fish_id >= 0 and angle_delta > 0.0:
		# Only line the player actually feeds out opens the pressure valve.
		# This runs before hooking, so a free cast cannot prepay a new fish's relief.
		var paid_out := maxf(0.0, line_length - old_length)
		line_pressure = maxf(0.0, line_pressure - paid_out * GameTuning.FISHING_LINE_PRESSURE_RELIEF_PER_LINE_UNIT)
	if hooked_fish_id < 0:
		_try_hook(old_tip, hook_tip_position(), old_length)
	_sync_attached_fish()
	_try_land()
	return (line_length - old_length) / GameTuning.FISHING_REEL_LINE_PER_RADIAN


func hook_tip_position() -> Vector2:
	return hook_position + hook_tip_offset


func teleport_hook(value: Vector2) -> void:
	if not is_finite(value.x) or not is_finite(value.y):
		return
	var safe := Vector2(clampf(value.x, MIN_X, MAX_X), clampf(value.y, SURFACE_DEPTH, MAX_DEPTH))
	_line.reset(_line_anchor(), safe)
	_refresh_line()
	_sync_attached_fish()


func fish_mouth_position(entry: Dictionary) -> Vector2:
	var fish_size: Vector2 = entry.size
	var offset: Vector2 = entry.get("mouth_offset", Vector2(fish_size.x * 0.5, 0.0))
	var facing := int(entry.get("facing", 1))
	return Vector2(entry.position) + Vector2(offset.x * facing, offset.y)


func _line_anchor() -> Vector2:
	return Vector2(line_anchor_x, ANCHOR_DEPTH)


func _refresh_line() -> void:
	line_length = _line.length
	line_points = _line.normalized_points()
	if not line_points.is_empty():
		_hook_position = line_points.back()


func _step(delta: float) -> void:
	_current_timer -= delta
	if _current_timer <= 0.0:
		_current_timer = _rng.randf_range(0.6, 1.3)
		_current_target = _rng.randf_range(-GameTuning.FISHING_CURRENT_SPEED, GameTuning.FISHING_CURRENT_SPEED)
	_current_velocity = move_toward(_current_velocity, _current_target, delta * GameTuning.FISHING_CURRENT_SPEED * 2.0)
	_move_line_anchor(delta)
	_move_fish(delta)
	var old_tip := hook_tip_position()
	var old_length := line_length
	if hooked_fish_id >= 0:
		_update_fight(delta)
	_line.step(delta, _line_anchor(), _current_velocity, _fight_velocity, hooked_fish_id >= 0 and fight_phase == "pulling", _fight_strength)
	if hooked_fish_id >= 0 and fight_phase == "pulling":
		_line.pull_available(delta * GameTuning.FISHING_FISH_STRETCH_SPEED * _fight_strength, _line_anchor(), _fight_velocity)
	# Sample tension before automatic payout adds slack. Letting go of the reel
	# cannot count as manually opening the valve or hide a taut fish's pressure.
	if _update_line_pressure(delta):
		return
	_update_unheld_reel(delta)
	_refresh_line()
	if hooked_fish_id < 0:
		_try_hook(old_tip, hook_tip_position(), old_length)
	_sync_attached_fish()
	_try_land()


func _update_line_pressure(delta: float) -> bool:
	if hooked_fish_id < 0 or fight_phase != "pulling" or not is_line_taut():
		return false
	line_pressure = minf(1.0, line_pressure + _line_pressure_rate * delta)
	if line_pressure < 1.0:
		return false
	_refresh_line()
	_sync_attached_fish()
	_snap_line()
	return true


func _snap_line() -> void:
	stop_reel_flick()
	var snapped_tip := hook_tip_position()
	for entry: Dictionary in fish:
		if int(entry.id) != hooked_fish_id:
			continue
		var position: Vector2 = entry.position
		var direction := 1 if position.x >= 0.5 else -1
		entry.velocity = Vector2(float(direction) * GameTuning.FISHING_SNAPPED_FISH_ESCAPE_SPEED, 0.0)
		entry.facing = direction
		FishBehavior.initialize(entry, _rng)
		entry.turn_timer = GameTuning.FISHING_SNAPPED_FISH_RETRY_SECONDS
		entry.interest_timer = GameTuning.FISHING_SNAPPED_FISH_RETRY_SECONDS
		entry.school_escape_seconds = GameTuning.FISHING_SNAPPED_FISH_RETRY_SECONDS
		break
	hooked_fish_id = -1
	line_state = "free"
	last_event = "snapped"
	reel_held = false
	fight_phase = "free"
	fight_seconds_left = 0.0
	_fight_velocity = 0.0
	_reset_fight_profile()
	_pull_rate = 0.0
	_fight_strength = 1.0
	line_pressure = 0.0
	# Restring the empty hook immediately; the escaped fish grants no catch.
	_line.reset(_line_anchor(), Vector2(line_anchor_x, 0.07))
	_refresh_line()
	line_snapped.emit(snapped_tip)


func _update_unheld_reel(delta: float) -> void:
	if reel_held or _line.length >= MAX_LINE_LENGTH:
		stop_reel_flick()
		return
	var payout_speed := GameTuning.FISHING_IDLE_PAYOUT_SPEED
	if hooked_fish_id >= 0 and fight_phase == "pulling" and _line.is_taut(_line_anchor()):
		payout_speed = maxf(payout_speed, _pull_rate)
	var flick_turn := 0.0
	if hooked_fish_id >= 0:
		stop_reel_flick()
	elif reel_flick_speed > 0.0:
		# Integrate exponential drag exactly, keeping flick travel independent of FPS.
		var drag := GameTuning.FISHING_REEL_FLICK_DRAG
		var retention := exp(-drag * delta)
		flick_turn = reel_flick_speed * (1.0 - retention) / drag
		reel_flick_speed *= retention
		if reel_flick_speed < GameTuning.FISHING_REEL_FLICK_STOP_SPEED:
			stop_reel_flick()
	var previous_length := _line.length
	var previous_tip := hook_tip_position()
	# Lower the free hook; feed slack without moving an attached fish abruptly.
	_line.set_length(previous_length + payout_speed * delta + flick_turn * GameTuning.FISHING_REEL_LINE_PER_RADIAN, _line_anchor(), hooked_fish_id >= 0)
	_refresh_line()
	if flick_turn > 0.0:
		# Stop at the first bite crossed; coasting never carries into a fish fight.
		_try_hook(previous_tip, hook_tip_position(), previous_length)
	automatic_reel_angle += maxf(0.0, _line.length - previous_length) / GameTuning.FISHING_REEL_LINE_PER_RADIAN
	if _line.length >= MAX_LINE_LENGTH:
		stop_reel_flick()


func _move_line_anchor(delta: float) -> void:
	if hooked_fish_id >= 0:
		# Follow the attached mouth with a little lag, rather than drifting separately.
		var follow := 1.0 - exp(-GameTuning.FISHING_HOOKED_ANCHOR_FOLLOW_RATE * delta)
		line_anchor_x = clampf(lerpf(line_anchor_x, hook_tip_position().x, follow), MIN_X, MAX_X)
		_anchor_velocity = 0.0
		_anchor_target = 0.0
		_anchor_timer = 0.0
		return
	# Without a fish, surface water carries the top independently of the hook.
	_anchor_timer -= delta
	if _anchor_timer <= 0.0:
		_anchor_timer = _rng.randf_range(0.7, 1.4)
		_anchor_target = _rng.randf_range(-GameTuning.FISHING_CURRENT_SPEED, GameTuning.FISHING_CURRENT_SPEED) * 0.65
	_anchor_velocity = move_toward(_anchor_velocity, _anchor_target, delta * GameTuning.FISHING_CURRENT_SPEED)
	line_anchor_x = clampf(line_anchor_x + _anchor_velocity * delta, MIN_X, MAX_X)
	if line_anchor_x <= MIN_X:
		_anchor_target = absf(_anchor_target)
	elif line_anchor_x >= MAX_X:
		_anchor_target = -absf(_anchor_target)


func _update_fight(delta: float) -> void:
	fight_seconds_left -= delta
	if fight_seconds_left <= 0.0:
		if fight_phase == "pulling":
			fight_phase = "resting"
			fight_seconds_left = _rng.randf_range(GameTuning.FISHING_REST_MIN_SECONDS, GameTuning.FISHING_REST_MAX_SECONDS) * _fight_rest_scale
			_pull_rate = 0.0
			_fight_velocity = 0.0
			_fight_target_velocity = 0.0
		else:
			_begin_pull_burst()
	if fight_phase != "pulling":
		return
	_fight_timer -= delta
	if _fight_timer <= 0.0:
		_choose_lateral_pull(true)
	# Reverse promptly at an edge, while smoothing the fish's actual movement.
	if hook_position.x < MIN_X + 0.06:
		_fight_direction = 1.0
		_fight_target_velocity = absf(_fight_target_velocity)
	elif hook_position.x > MAX_X - 0.06:
		_fight_direction = -1.0
		_fight_target_velocity = -absf(_fight_target_velocity)
	_fight_velocity = move_toward(_fight_velocity, _fight_target_velocity, delta * GameTuning.FISHING_SIDEWAYS_SMOOTH_RATE * _fight_strength)


func _begin_pull_burst() -> void:
	fight_phase = "pulling"
	fight_seconds_left = _rng.randf_range(GameTuning.FISHING_PULL_BURST_MIN_SECONDS, GameTuning.FISHING_PULL_BURST_MAX_SECONDS) * _fight_pull_scale
	_fight_direction = -1.0 if _rng.randf() < 0.5 else 1.0
	_choose_lateral_pull(false)


func _choose_lateral_pull(allow_reverse: bool) -> void:
	if allow_reverse and _rng.randf() < 0.75:
		_fight_direction *= -1.0
	_fight_timer = _rng.randf_range(GameTuning.FISHING_SIDEWAYS_INTERVAL_MIN_SECONDS, GameTuning.FISHING_SIDEWAYS_INTERVAL_MAX_SECONDS) * _fight_sideways_scale
	_fight_target_velocity = _fight_direction * _rng.randf_range(0.65, 1.0) * GameTuning.FISHING_FISH_LATERAL_SPEED * _fight_strength
	_pull_rate = _rng.randf_range(GameTuning.FISHING_FISH_PULL_MIN, GameTuning.FISHING_FISH_PULL_MAX) * _fight_strength


func _reset_fight_profile() -> void:
	_fight_target_velocity = 0.0
	_fight_timer = 0.0
	_fight_direction = 1.0
	_fight_pull_scale = 1.0
	_fight_rest_scale = 1.0
	_fight_sideways_scale = 1.0


func _make_fish(id: int) -> Dictionary:
	var direction := -1.0 if _rng.randf() < 0.5 else 1.0
	var entry := {
		"id": id,
		"position": Vector2(_rng.randf_range(0.10, 0.90), _roll_fish_depth()),
		"size": Vector2(0.035, 0.045),
		"velocity": Vector2(direction * _rng.randf_range(0.035, 0.075), 0.0),
		"facing": int(direction),
		"mouth_offset": Vector2(0.0175, 0.0),
		"turn_timer": _rng.randf_range(1.0, 3.5),
		"respawn_wait": 0.0,
	}
	entry.preferred_depth = Vector2(entry.position).y
	_assign_fish_identity(entry)
	FishBehavior.initialize(entry, _rng)
	return entry


func _roll_fish_depth() -> float:
	return lerpf(GameTuning.FISHING_FISH_MIN_DEPTH, GameTuning.FISHING_FISH_MAX_DEPTH, pow(_rng.randf(), GameTuning.FISHING_FISH_DEPTH_BIAS))


func _assign_fish_identity(entry: Dictionary) -> void:
	var small_slot := int(entry.id) >= GameTuning.FISHING_FISH_COUNT - GameTuning.FISHING_SMALL_FISH_COUNT
	var identity := FishSpecies.roll(_catch_rng, GameTuning.FISHING_SMALL_FISH_MAX_CM if small_slot else INF)
	var old_scale := float(entry.get("size_scale", 1.0))
	var size_scale := FishSpecies.visual_scale(float(identity.length_cm))
	entry.fish_id = identity.fish_id
	entry.length_cm = identity.length_cm
	entry.size_scale = size_scale
	entry.size = Vector2(entry.size) * (size_scale / old_scale)
	var old_mouth: Vector2 = entry.get("mouth_offset", Vector2.ZERO)
	entry.mouth_offset = old_mouth * (size_scale / old_scale)
	# Each new fish keeps its own pace; individual bursts still vary within it.
	entry.fight_pull_scale = _rng.randf_range(GameTuning.FISHING_FIGHT_PACE_MIN, GameTuning.FISHING_FIGHT_PACE_MAX)
	entry.fight_rest_scale = _rng.randf_range(GameTuning.FISHING_FIGHT_PACE_MIN, GameTuning.FISHING_FIGHT_PACE_MAX)
	entry.fight_sideways_scale = _rng.randf_range(GameTuning.FISHING_SIDEWAYS_PACE_MIN, GameTuning.FISHING_SIDEWAYS_PACE_MAX)


func _move_fish(delta: float) -> void:
	_schools.update(delta, fish, hooked_fish_id, _rng)
	for entry: Dictionary in fish:
		if int(entry.id) == hooked_fish_id:
			continue
		if float(entry.get("respawn_wait", 0.0)) > 0.0:
			entry.respawn_wait = maxf(0.0, float(entry.respawn_wait) - delta)
			continue
		FishBehavior.steer(entry, hook_tip_position(), delta, _rng, hooked_fish_id < 0)
		var velocity: Vector2 = entry.velocity
		var at: Vector2 = entry.position
		var half_size: Vector2 = entry.size * 0.5
		at += velocity * delta
		if at.x < -0.1 - half_size.x or at.x > 1.1 + half_size.x:
			# Leave the water view fully, then enter from the opposite bank later.
			var direction := 1.0 if velocity.x > 0.0 else -1.0
			at = Vector2(-0.08 - half_size.x if direction > 0.0 else 1.08 + half_size.x, _roll_fish_depth())
			entry.preferred_depth = at.y
			entry.school_escape_seconds = 0.0
			velocity.x = direction * _rng.randf_range(0.04, 0.085)
			entry.respawn_wait = _rng.randf_range(GameTuning.FISHING_FISH_RESPAWN_MIN_SECONDS, GameTuning.FISHING_FISH_RESPAWN_MAX_SECONDS)
			entry.turn_timer = _rng.randf_range(3.0, 6.0)
			entry.appearance_revision = int(entry.get("appearance_revision", 0)) + 1
			_assign_fish_identity(entry)
			entry.velocity = velocity
			FishBehavior.initialize(entry, _rng)
		entry.position = at
		entry.velocity = velocity
		if str(entry.get("behavior", "cruising")) == "cruising" and not is_zero_approx(velocity.x):
			entry.facing = 1 if velocity.x > 0.0 else -1


func _try_hook(from_tip: Vector2, to_tip: Vector2, from_length: float = -1.0) -> void:
	var nearest := INF
	var candidate: Dictionary = {}
	for entry: Dictionary in fish:
		if float(entry.get("respawn_wait", 0.0)) > 0.0:
			continue
		if str(entry.get("behavior", "cruising")) != "biting":
			continue
		var fish_size: Vector2 = entry.size
		var fish_center: Vector2 = entry.position
		var contact := _segment_entry(from_tip, to_tip, Rect2(fish_center - fish_size * 0.5, fish_size))
		if contact < nearest:
			nearest = contact
			candidate = entry
	if candidate.is_empty():
		return
	# Stop new reel travel at contact, retaining the line already out before it.
	# Resetting only to the straight contact distance would erase existing slack.
	var initial_length := from_length if from_length >= 0.0 else line_length
	var contact_position := from_tip.lerp(to_tip, nearest) - hook_tip_offset
	var from_span := from_tip - hook_tip_offset - _line_anchor()
	var contact_span := contact_position - _line_anchor()
	var from_distance := Vector2(from_span.x * WATER_ASPECT, from_span.y).length()
	var contact_distance := Vector2(contact_span.x * WATER_ASPECT, contact_span.y).length()
	var contact_length := initial_length
	if from_distance > 0.00001 and not is_equal_approx(initial_length, line_length):
		# Free reeling scales the whole rope. Use its starting slack ratio, since
		# water bounds can clip the final hook position before a long cast ends.
		contact_length = clampf(initial_length * contact_distance / from_distance, minf(initial_length, line_length), maxf(initial_length, line_length))
	teleport_hook(contact_position)
	_line.set_length(maxf(contact_length, line_length), _line_anchor(), true)
	_refresh_line()
	if not candidate.has("facing"):
		var velocity: Vector2 = candidate.velocity
		candidate.facing = -1 if velocity.x < 0.0 else 1
	hooked_fish_id = int(candidate.id)
	stop_reel_flick()
	_fight_pull_scale = float(candidate.get("fight_pull_scale", 1.0))
	_fight_rest_scale = float(candidate.get("fight_rest_scale", 1.0))
	_fight_sideways_scale = float(candidate.get("fight_sideways_scale", 1.0))
	_fight_strength = 1.0
	line_pressure = 0.0
	_line_pressure_rate = (GameTuning.FISHING_LINE_PRESSURE_MIN_RATE + GameTuning.FISHING_LINE_PRESSURE_MAX_RATE) * 0.5
	if candidate.has("length_cm"):
		var fraction := clampf(inverse_lerp(FishSpecies.MIN_LENGTH_CM, FishSpecies.MAX_LENGTH_CM, float(candidate.length_cm)), 0.0, 1.0)
		_fight_strength = lerpf(GameTuning.FISHING_FISH_POWER_MIN, GameTuning.FISHING_FISH_POWER_MAX, fraction)
		# No mass catalog exists yet: actual catch length cubed supplies a relative
		# weight proxy, independently of the randomly assigned silhouette artwork.
		var length_ratio := maxf(0.0, float(candidate.length_cm)) / GameTuning.FISHING_LINE_PRESSURE_WEIGHT_REFERENCE_CM
		var relative_weight := length_ratio * length_ratio * length_ratio
		var load_fraction := relative_weight / (1.0 + relative_weight)
		_line_pressure_rate = lerpf(GameTuning.FISHING_LINE_PRESSURE_MIN_RATE, GameTuning.FISHING_LINE_PRESSURE_MAX_RATE, load_fraction)
	line_state = "hooked"
	last_event = "hooked"
	_begin_pull_burst()
	fish_hooked.emit(hooked_fish_id)


func _sync_attached_fish() -> void:
	if hooked_fish_id < 0:
		return
	for entry: Dictionary in fish:
		if int(entry.id) == hooked_fish_id:
			var horizontal := _current_velocity + _fight_velocity
			if fight_phase == "pulling" and absf(_fight_velocity) > 0.005:
				horizontal = _fight_velocity
			if absf(horizontal) > 0.005:
				entry.facing = 1 if horizontal > 0.0 else -1
			var fish_size: Vector2 = entry.size
			var offset: Vector2 = entry.get("mouth_offset", Vector2(fish_size.x * 0.5, 0.0))
			var facing := int(entry.get("facing", 1))
			entry.position = hook_tip_position() - Vector2(offset.x * facing, offset.y)
			entry.velocity = Vector2(horizontal, _pull_rate)
			return


func _try_land() -> void:
	if hooked_fish_id < 0 or line_length > MIN_LINE_LENGTH + 0.00001:
		return
	var landed_id := hooked_fish_id
	var landed_index := -1
	for index in range(fish.size()):
		if int(fish[index].id) == landed_id:
			landed_index = index
			break
	if landed_index < 0:
		return
	var landed: Dictionary = fish[landed_index]
	if not landed.has("fish_id"):
		_assign_fish_identity(landed)
	catches.append({
		"fish_id": str(landed.fish_id),
		"length_cm": float(landed.length_cm),
	})
	hooked_fish_id = -1
	stop_reel_flick()
	line_state = "free"
	caught_count += 1
	last_event = "caught"
	fight_phase = "free"
	fight_seconds_left = 0.0
	_fight_velocity = 0.0
	_reset_fight_profile()
	_pull_rate = 0.0
	_fight_strength = 1.0
	line_pressure = 0.0
	fish[landed_index] = _make_fish(landed_id)
	fish_caught.emit(caught_count)


func _segment_entry(from_tip: Vector2, to_tip: Vector2, rect: Rect2) -> float:
	var direction := to_tip - from_tip
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			if from_tip[axis] < rect.position[axis] or from_tip[axis] > rect.end[axis]:
				return INF
			continue
		var near := (rect.position[axis] - from_tip[axis]) / direction[axis]
		var far := (rect.end[axis] - from_tip[axis]) / direction[axis]
		if near > far:
			var swap := near
			near = far
			far = swap
		enter = maxf(enter, near)
		leave = minf(leave, far)
		if enter > leave:
			return INF
	return enter
