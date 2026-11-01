extends RefCounted

# Verlet positions use water-height units so horizontal and vertical lengths agree.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const WATER_ASPECT := 1665.0 / 585.0
const SEGMENTS := 20
const MIN_LENGTH := 0.04
const MAX_LENGTH := 1.2
const MIN_X := 0.05
const MAX_X := 0.95
const ANCHOR_DEPTH := 10.0 / 585.0
const MIN_HOOK_DEPTH := 0.04
const MAX_HOOK_DEPTH := 0.92

var length := 0.055
var _points: Array[Vector2] = []
var _previous: Array[Vector2] = []
var _last_delta := 1.0 / 60.0
var _elapsed := 0.0


func reset(anchor: Vector2, endpoint: Vector2) -> void:
	var start := _to_space(anchor)
	var finish := _to_space(endpoint)
	var span := finish - start
	length = clampf(span.length(), MIN_LENGTH, MAX_LENGTH)
	if span.is_zero_approx():
		span = Vector2.DOWN * length
	elif span.length() > MAX_LENGTH:
		span = span.normalized() * length
	_points.clear()
	_previous.clear()
	for index in range(SEGMENTS + 1):
		var point := start + span * float(index) / float(SEGMENTS)
		_points.append(point)
		_previous.append(point)
	_last_delta = 1.0 / 60.0
	_elapsed = 0.0
	_constrain(start)


func set_length(value: float, anchor: Vector2, keep_endpoint := false) -> void:
	if not is_finite(value) or _points.is_empty():
		return
	var next_length := clampf(value, MIN_LENGTH, MAX_LENGTH)
	if keep_endpoint:
		var endpoint: Vector2 = _points.back()
		length = next_length
		_shape_between(_to_space(anchor), endpoint)
		return
	var ratio := next_length / maxf(length, 0.00001)
	var old_anchor := _points[0]
	var next_anchor := _to_space(anchor)
	# Reel the entire string toward its anchor, including sideways displacement.
	for index in range(_points.size()):
		_points[index] = next_anchor + (_points[index] - old_anchor) * ratio
		_previous[index] = next_anchor + (_previous[index] - old_anchor) * ratio
	length = next_length
	_constrain(next_anchor)


func endpoint_distance(anchor: Vector2) -> float:
	return _to_space(anchor).distance_to(_points.back()) if not _points.is_empty() else 0.0


func is_taut(anchor: Vector2) -> bool:
	return endpoint_distance(anchor) >= length - maxf(0.001, length * 0.02)


func pull_available(distance: float, anchor: Vector2, sideways: float) -> void:
	if _points.is_empty() or distance <= 0.0:
		return
	var start := _to_space(anchor)
	var endpoint: Vector2 = _points.back()
	if is_taut(anchor) and not is_zero_approx(sideways):
		_swing_taut_endpoint(start, endpoint, distance, sideways)
		return
	# Spend available slack on depth first, then allow a small lateral struggle.
	# Never reconstruct or flip the entire span when a fish reaches the bottom.
	var horizontal := endpoint.x - start.x
	var reachable_depth := start.y + sqrt(maxf(0.0, length * length - horizontal * horizontal))
	var next_depth := minf(endpoint.y + distance, minf(MAX_HOOK_DEPTH, reachable_depth))
	next_depth = maxf(endpoint.y, next_depth)
	var vertical := next_depth - start.y
	var horizontal_room := sqrt(maxf(0.0, length * length - vertical * vertical))
	var left := maxf(MIN_X * WATER_ASPECT, start.x - horizontal_room)
	var right := minf(MAX_X * WATER_ASPECT, start.x + horizontal_room)
	var lateral := sideways * WATER_ASPECT
	var edge_margin := 0.06 * WATER_ASPECT
	if endpoint.x < MIN_X * WATER_ASPECT + edge_margin:
		lateral = absf(lateral)
	elif endpoint.x > MAX_X * WATER_ASPECT - edge_margin:
		lateral = -absf(lateral)
	var lateral_scale := 0.25 if endpoint.y < MAX_HOOK_DEPTH - 0.02 else 1.0
	var next_x := clampf(endpoint.x + lateral * distance * lateral_scale, left, right)
	_shape_between(start, Vector2(next_x, next_depth))


func _swing_taut_endpoint(anchor: Vector2, endpoint: Vector2, distance: float, sideways: float) -> void:
	var span := endpoint - anchor
	var radius := minf(length, span.length())
	if radius <= 0.00001:
		return
	# Rotate along the paid-out radius instead of locking X at the deepest point.
	# The angular step is small and time-limited, so a struggle cannot jump upward.
	var angle := atan2(span.x, span.y)
	var angular_limit := maxf(GameTuning.FISHING_TAUT_SWING_MAX_ANGLE, absf(angle))
	var bottom_angle := acos(clampf((MAX_HOOK_DEPTH - anchor.y) / radius, 0.0, 1.0))
	if bottom_angle > 0.0:
		angular_limit = maxf(angular_limit, bottom_angle + 0.2)
	var depth_limit := acos(clampf((MIN_HOOK_DEPTH - anchor.y) / radius, 0.0, 1.0))
	var left := maxf(-minf(angular_limit, depth_limit), asin(clampf((MIN_X * WATER_ASPECT - anchor.x) / radius, -1.0, 1.0)))
	var right := minf(minf(angular_limit, depth_limit), asin(clampf((MAX_X * WATER_ASPECT - anchor.x) / radius, -1.0, 1.0)))
	# A long line at the seabed has two valid arcs. Stay on the current side.
	if bottom_angle > 0.0:
		if angle < 0.0:
			right = minf(right, -bottom_angle)
		else:
			left = maxf(left, bottom_angle)
	if left > right:
		return
	var direction := signf(sideways)
	if angle <= left + 0.001:
		direction = 1.0
	elif angle >= right - 0.001:
		direction = -1.0
	var intensity := clampf(absf(sideways) * WATER_ASPECT, 0.35, 1.0)
	var angular_step := minf(distance * intensity * GameTuning.FISHING_TAUT_SWING_GAIN / maxf(radius, 0.08), GameTuning.FISHING_TAUT_SWING_MAX_SPEED * _last_delta)
	var next_angle := clampf(angle + direction * angular_step, left, right)
	_shape_between(anchor, anchor + Vector2(sin(next_angle), cos(next_angle)) * radius)


func _shape_between(anchor: Vector2, endpoint: Vector2) -> void:
	var span := endpoint - anchor
	var perpendicular := Vector2(-span.y, span.x).normalized()
	var water_center := Vector2((MIN_X + MAX_X) * WATER_ASPECT * 0.5, (ANCHOR_DEPTH + MAX_HOOK_DEPTH) * 0.5)
	if perpendicular.dot(water_center - anchor.lerp(endpoint, 0.5)) < 0.0:
		perpendicular = -perpendicular
	var low := 0.0
	var high := length * 0.5
	# Preserve the paid-out length as a slack curve without teleporting the fish.
	for _iteration in range(12):
		var amplitude := (low + high) * 0.5
		var arc := 0.0
		var previous := anchor
		for index in range(1, SEGMENTS + 1):
			var amount := float(index) / SEGMENTS
			var point := _bounded_position(anchor.lerp(endpoint, amount) + perpendicular * sin(amount * PI) * amplitude, index == SEGMENTS)
			arc += previous.distance_to(point)
			previous = point
		if arc <= length:
			low = amplitude
		else:
			high = amplitude
	for index in range(SEGMENTS + 1):
		var amount := float(index) / SEGMENTS
		_points[index] = anchor.lerp(endpoint, amount) + perpendicular * sin(amount * PI) * low
		if index > 0:
			_bound_point(index)
		_previous[index] = _points[index]


func step(delta: float, anchor: Vector2, current: float, fight: float = 0.0, hooked: bool = false, fight_strength: float = 1.0) -> void:
	if _points.is_empty() or delta <= 0.0:
		return
	var previous_depth: float = _points.back().y
	_elapsed += delta
	var retention := exp(-4.0 * delta)
	var time_ratio := delta / maxf(_last_delta, 0.00001)
	for index in range(1, _points.size()):
		var point := _points[index]
		var velocity := (point - _previous[index]) * time_ratio * retention
		_previous[index] = point
		var wave := sin(_elapsed * 1.7 + float(index) * 0.7) * absf(current) * 0.65
		var acceleration := Vector2((current + wave) * WATER_ASPECT * 4.0, 0.22)
		if index == SEGMENTS:
			acceleration.y += 0.45
			if hooked:
				acceleration += Vector2(fight * WATER_ASPECT * GameTuning.FISHING_FISH_LATERAL_FORCE, 0.8 * fight_strength)
		_points[index] = point + velocity + acceleration * delta * delta
	_last_delta = delta
	var start := _to_space(anchor)
	_constrain(start)
	if hooked and _points.back().y < previous_depth:
		# A taut rope can block a downward pull; it must not lift the fish instead.
		var endpoint: Vector2 = _points.back()
		endpoint.y = minf(previous_depth, minf(MAX_HOOK_DEPTH, start.y + length))
		var vertical := endpoint.y - start.y
		var horizontal_room := sqrt(maxf(0.0, length * length - vertical * vertical))
		endpoint.x = clampf(endpoint.x, maxf(MIN_X * WATER_ASPECT, start.x - horizontal_room), minf(MAX_X * WATER_ASPECT, start.x + horizontal_room))
		_shape_between(start, endpoint)


func normalized_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in _points:
		result.append(Vector2(point.x / WATER_ASPECT, point.y))
	return result


func _constrain(anchor: Vector2) -> void:
	if _points.is_empty():
		return
	var rest := length / float(SEGMENTS)
	# Adjacent segments share corrections; the surface end remains pinned.
	for _iteration in range(32):
		_points[0] = anchor
		for index in range(1, _points.size()):
			var span := _points[index] - _points[index - 1]
			var distance := span.length()
			if distance > rest:
				var correction := span * (distance - rest) / distance
				if index == 1:
					_points[index] -= correction
				else:
					_points[index - 1] += correction * 0.5
					_points[index] -= correction * 0.5
			_bound_point(index)
	# A final pass caps stretch even after large mouse turns or frame drops.
	_points[0] = anchor
	_previous[0] = anchor
	for index in range(1, _points.size()):
		var span := _points[index] - _points[index - 1]
		if span.length() > rest:
			_points[index] = _points[index - 1] + span.normalized() * rest
		_bound_point(index)


func _bound_point(index: int) -> void:
	var point := _points[index]
	var bounded := _bounded_position(point, index == SEGMENTS)
	var previous := _previous[index]
	# Remove outward momentum only; tangential motion can slide off a corner.
	if bounded.x != point.x or (bounded.x <= MIN_X * WATER_ASPECT and previous.x > bounded.x) or (bounded.x >= MAX_X * WATER_ASPECT and previous.x < bounded.x):
		previous.x = bounded.x
	var minimum_y := MIN_HOOK_DEPTH if index == SEGMENTS else ANCHOR_DEPTH
	if bounded.y != point.y or (bounded.y <= minimum_y and previous.y > bounded.y) or (bounded.y >= MAX_HOOK_DEPTH and previous.y < bounded.y):
		previous.y = bounded.y
	_points[index] = bounded
	_previous[index] = previous


func _bounded_position(point: Vector2, endpoint: bool) -> Vector2:
	return Vector2(
		clampf(point.x, MIN_X * WATER_ASPECT, MAX_X * WATER_ASPECT),
		clampf(point.y, MIN_HOOK_DEPTH if endpoint else ANCHOR_DEPTH, MAX_HOOK_DEPTH),
	)


func _to_space(point: Vector2) -> Vector2:
	return Vector2(point.x * WATER_ASPECT, point.y)
