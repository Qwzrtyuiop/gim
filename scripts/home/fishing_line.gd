extends RefCounted

# Verlet positions use water-height units so horizontal and vertical lengths agree.
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
	var span: Vector2 = _points.back() - start
	var direction: Vector2 = span.normalized() if span.length() > 0.0001 else Vector2.DOWN
	# A fish pulls the endpoint outward, taking up slack before drawing new line.
	direction = direction.lerp(Vector2(sideways * WATER_ASPECT, 1.0).normalized(), 0.04).normalized()
	var reach := minf(length, span.length() + distance)
	var maximum_y := MAX_HOOK_DEPTH - start.y
	var next_span: Vector2 = direction * reach
	if next_span.y > maximum_y:
		# At the bottom, fight sideways so the remaining line can still become taut.
		next_span.y = maximum_y
		var horizontal := sqrt(maxf(0.0, reach * reach - maximum_y * maximum_y))
		var side := signf(span.x) if absf(span.x) > 0.01 else (-1.0 if sideways < 0.0 else 1.0)
		if start.x + horizontal * side > MAX_X * WATER_ASPECT or start.x + horizontal * side < MIN_X * WATER_ASPECT:
			side *= -1.0
		next_span.x = horizontal * side
	_shape_between(start, start + next_span)


func _shape_between(anchor: Vector2, endpoint: Vector2) -> void:
	var span := endpoint - anchor
	var perpendicular := Vector2(-span.y, span.x).normalized()
	var low := 0.0
	var high := length * 0.5
	# Preserve the paid-out length as a slack curve without teleporting the fish.
	for _iteration in range(12):
		var amplitude := (low + high) * 0.5
		var arc := 0.0
		var previous := anchor
		for index in range(1, SEGMENTS + 1):
			var amount := float(index) / SEGMENTS
			var point := anchor.lerp(endpoint, amount) + perpendicular * sin(amount * PI) * amplitude
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
				acceleration += Vector2(fight * WATER_ASPECT * 7.0, 0.8 * fight_strength)
		_points[index] = point + velocity + acceleration * delta * delta
	_last_delta = delta
	_constrain(_to_space(anchor))


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
			if distance > 0.000001:
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
	point.x = clampf(point.x, MIN_X * WATER_ASPECT, MAX_X * WATER_ASPECT)
	point.y = clampf(point.y, MIN_HOOK_DEPTH if index == SEGMENTS else ANCHOR_DEPTH, MAX_HOOK_DEPTH)
	_points[index] = point


func _to_space(point: Vector2) -> Vector2:
	return Vector2(point.x * WATER_ASPECT, point.y)
