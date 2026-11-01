extends RefCounted

# Moving invisible ellipses guide small fish; inspection and hooked movement win.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const WATER_ASPECT := 1665.0 / 585.0

var _schools: Array[Dictionary] = []
var _next_id := 0


func reset(fish: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	_schools.clear()
	_next_id = 0
	for entry: Dictionary in fish:
		_clear_membership(entry)
		if not _is_small(entry):
			continue
		_assign(entry, rng, true)
		var school := _find(int(entry.school_id))
		entry.position = _target(school, int(entry.school_slot))
		entry.preferred_depth = Vector2(school.center).y
		entry.velocity = Vector2(float(school.speed), 0.0)
		entry.facing = 1 if float(school.speed) > 0.0 else -1


func update(delta: float, fish: Array[Dictionary], hooked_id: int, rng: RandomNumberGenerator) -> void:
	var by_id: Dictionary = {}
	for entry: Dictionary in fish:
		by_id[int(entry.id)] = entry
		entry.erase("school_target")
		entry.erase("school_velocity")
		var escape := maxf(0.0, float(entry.get("school_escape_seconds", 0.0)) - delta)
		entry.school_escape_seconds = escape
		if not _is_small(entry) or escape > 0.0 or int(entry.get("school_revision", -1)) != int(entry.get("appearance_revision", 0)):
			_clear_membership(entry)
		elif entry.has("school_id") and str(entry.get("behavior", "cruising")) == "cruising" and int(entry.id) != hooked_id:
			var school := _find(int(entry.school_id))
			var offset := Vector2(school.get("center", entry.position)) - Vector2(entry.position)
			if school.is_empty() or Vector2(offset.x * WATER_ASPECT, offset.y).length_squared() > 0.4225:
				# A long inspection can leave its old school far away. Regroup locally.
				_clear_membership(entry)
	for index in range(_schools.size() - 1, -1, -1):
		var school: Dictionary = _schools[index]
		var members: Array = school.members
		var slots: Dictionary = school.slots
		for slot in range(members.size() - 1, -1, -1):
			var entry: Dictionary = by_id.get(int(members[slot]), {})
			if entry.is_empty() or int(entry.get("school_id", -1)) != int(school.id):
				slots.erase(int(members[slot]))
				members.remove_at(slot)
		if members.is_empty():
			_schools.remove_at(index)
	for entry: Dictionary in fish:
		if _is_small(entry) and not entry.has("school_id") and int(entry.id) != hooked_id and float(entry.school_escape_seconds) <= 0.0 and float(entry.get("respawn_wait", 0.0)) <= 0.0:
			_assign(entry, rng)
	for school: Dictionary in _schools:
		var previous: Vector2 = school.center
		school.elapsed = float(school.elapsed) + delta
		var target_depth := float(school.depth) + sin(float(school.elapsed) * 0.6 + float(school.phase)) * 0.012
		var center := previous + Vector2(float(school.speed) * delta, 0.0)
		center.y = move_toward(center.y, target_depth, delta * 0.01)
		school.center = center
		var velocity := (center - previous) / maxf(delta, 0.00001)
		for id: int in school.members:
			var entry: Dictionary = by_id[id]
			if id == hooked_id or str(entry.get("behavior", "cruising")) != "cruising" or float(entry.get("respawn_wait", 0.0)) > 0.0:
				continue
			entry.school_target = _target(school, int(entry.school_slot))
			entry.school_velocity = velocity


func _assign(entry: Dictionary, rng: RandomNumberGenerator, initial := false) -> void:
	var chosen: Dictionary = {}
	var nearest := INF
	var position: Vector2 = entry.position
	for school: Dictionary in _schools:
		var candidate_members: Array = school.members
		if candidate_members.size() >= GameTuning.FISHING_SCHOOL_MAX_MEMBERS:
			continue
		var offset := Vector2(school.center) - position
		var distance := Vector2(offset.x * WATER_ASPECT, offset.y).length_squared()
		if distance < nearest and (initial or distance < 0.16):
			nearest = distance
			chosen = school
	if chosen.is_empty():
		var direction := 1.0 if Vector2(entry.velocity).x >= 0.0 else -1.0
		var radius: Vector2 = GameTuning.FISHING_SCHOOL_RADIUS
		var depth := clampf(float(entry.get("preferred_depth", position.y)), GameTuning.FISHING_FISH_MIN_DEPTH + radius.y, GameTuning.FISHING_FISH_MAX_DEPTH - radius.y)
		chosen = {
			"id": _next_id,
			"members": [],
			"slots": {},
			"center": Vector2(position.x, depth),
			"depth": depth,
			"speed": direction * rng.randf_range(GameTuning.FISHING_SCHOOL_SPEED_MIN, GameTuning.FISHING_SCHOOL_SPEED_MAX),
			"phase": rng.randf_range(0.0, TAU),
			"elapsed": 0.0,
		}
		_next_id += 1
		_schools.append(chosen)
	var used_slots: Dictionary = {}
	var assigned_slots: Dictionary = chosen.slots
	for assigned: int in assigned_slots.values():
		used_slots[assigned] = true
	# Slots are stable for an appearance, with deterministic spacing in its ellipse.
	var slot := 0
	while used_slots.has(slot):
		slot += 1
	entry.school_id = int(chosen.id)
	entry.school_slot = slot
	entry.school_revision = int(entry.get("appearance_revision", 0))
	assigned_slots[int(entry.id)] = slot
	var assigned_members: Array = chosen.members
	assigned_members.append(int(entry.id))


func _find(id: int) -> Dictionary:
	for school: Dictionary in _schools:
		if int(school.id) == id:
			return school
	return {}


func _target(school: Dictionary, slot: int) -> Vector2:
	var radius: Vector2 = GameTuning.FISHING_SCHOOL_RADIUS
	var angle := TAU * float(slot) / float(GameTuning.FISHING_SCHOOL_MAX_MEMBERS) + float(school.phase)
	var bob := sin(float(school.elapsed) * 1.8 + float(slot)) * 0.08
	return Vector2(school.center) + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * (0.72 + bob)


func _is_small(entry: Dictionary) -> bool:
	var length := float(entry.get("length_cm", INF))
	return is_finite(length) and length <= GameTuning.FISHING_SMALL_FISH_MAX_CM


func _clear_membership(entry: Dictionary) -> void:
	for key in ["school_id", "school_slot", "school_revision", "school_target", "school_velocity"]:
		entry.erase(key)
