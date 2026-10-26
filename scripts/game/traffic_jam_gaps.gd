extends RefCounted

# Short convoys leave pockets that survive random speed changes and lane AI.
const StageProfiles := preload("res://scripts/game/stage_profiles.gd")
const Geometry := preload("res://scripts/game/vehicle_geometry.gd")

var _convoy_count := 0
var _convoy_limit := 0


func reset() -> void:
	_convoy_count = 0
	_convoy_limit = 0


func can_spawn(owner, sprite: Sprite2D, lane_index: int, world_speed: float) -> bool:
	if owner.stage_traffic != "traffic-jam":
		return true
	var rect := _bumper_rect(owner, sprite)
	if lane_index == 1 and _convoy_limit > 0 and _convoy_count >= _convoy_limit:
		var front := _rightmost_main(owner)
		if not front.is_empty() and rect.position.x - _bumper_rect(owner, front.sprite).end.x < float(StageProfiles.TRAFFIC_JAM_SAFE_GAPS.gap_pixels):
			return false
	if lane_index != 2:
		return true
	# Leave the next pocket's shoulder clear while the new convoy is held back.
	if _convoy_limit > 0 and _convoy_count >= _convoy_limit:
		return false
	var seconds := float(StageProfiles.TRAFFIC_JAM_SAFE_GAPS.spawn_prediction_seconds)
	var future_rect := rect
	future_rect.position.x += (world_speed - owner.player_speed) * seconds
	var swept_rect := rect.merge(future_rect)
	for pair: Array in _gap_pairs(owner):
		var gap := _gap_rect(owner, pair[0], pair[1])
		var future_gap := _gap_rect(owner, pair[0], pair[1], seconds)
		if _x_intersects(swept_rect, gap.merge(future_gap)):
			return false
	return true


func spawned(owner, entity: Dictionary) -> void:
	if owner.stage_traffic != "traffic-jam" or int(entity.get("lane", -1)) != 1:
		return
	if _convoy_limit == 0 or _convoy_count >= _convoy_limit:
		var rear := _rightmost_main(owner, entity.sprite)
		if not rear.is_empty() and _convoy_limit > 0:
			rear["jam_follow_gap"] = float(StageProfiles.TRAFFIC_JAM_SAFE_GAPS.gap_pixels)
		_convoy_count = 0
		_convoy_limit = owner.rng.randi_range(int(StageProfiles.TRAFFIC_JAM_SAFE_GAPS.convoy_min), int(StageProfiles.TRAFFIC_JAM_SAFE_GAPS.convoy_max))
	_convoy_count += 1


static func reserved_gap_intersects(owner, rect: Rect2) -> bool:
	if str(owner.get("stage_traffic")) == "traffic-jam":
		for pair: Array in _gap_pairs(owner):
			if _x_intersects(rect, _gap_rect(owner, pair[0], pair[1])):
				return true
	return false


static func preserve_gaps(owner, delta: float) -> void:
	if owner.stage_traffic != "traffic-jam":
		return
	for pair: Array in _gap_pairs(owner):
		var rear: Dictionary = pair[0]
		var front: Dictionary = pair[1]
		var spare := _gap_rect(owner, rear, front).size.x - float(rear.jam_follow_gap)
		var response := float(StageProfiles.TRAFFIC_JAM_SAFE_GAPS.gap_speed_response)
		if spare >= 0.0:
			response = minf(response, 1.0 / maxf(0.001, delta))
		var cap := maxf(0.0, float(front.get("world_speed", 0.0)) + spare * response)
		rear["world_speed"] = minf(float(rear.get("world_speed", cap)), cap)
		rear["desired_world_speed"] = minf(float(rear.get("desired_world_speed", cap)), cap)


static func _main_entities(owner, excluded_sprite: Sprite2D = null) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	for entity: Dictionary in owner.active_entities:
		var sprite = entity.get("sprite")
		if not is_instance_valid(sprite) or sprite == excluded_sprite or int(entity.get("lane", -1)) != 1:
			continue
		if bool(entity.get("is_parked", false)) or bool(entity.get("horn_yield_clear", false)) or bool(entity.get("top_lane_evasive_offset_active", false)):
			continue
		if not bool(entity.get("moves_with_player", true)):
			continue
		entities.append(entity)
	entities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _bumper_rect(owner, a.sprite).get_center().x > _bumper_rect(owner, b.sprite).get_center().x
	)
	return entities


static func _rightmost_main(owner, excluded_sprite: Sprite2D = null) -> Dictionary:
	var entities := _main_entities(owner, excluded_sprite)
	return entities[0] if not entities.is_empty() else {}


static func _gap_pairs(owner) -> Array[Array]:
	var pairs: Array[Array] = []
	var entities := _main_entities(owner)
	for index in range(1, entities.size()):
		if float(entities[index].get("jam_follow_gap", 0.0)) > 0.0:
			pairs.append([entities[index], entities[index - 1]])
	return pairs


static func _gap_rect(owner, rear: Dictionary, front: Dictionary, seconds := 0.0) -> Rect2:
	var start: float = _bumper_rect(owner, rear.sprite).end.x + (float(rear.get("world_speed", 0.0)) - float(owner.player_speed)) * seconds
	var end: float = _bumper_rect(owner, front.sprite).position.x + (float(front.get("world_speed", 0.0)) - float(owner.player_speed)) * seconds
	return Rect2(start, 0.0, maxf(0.0, end - start), 1.0)


static func _bumper_rect(owner, sprite: Sprite2D) -> Rect2:
	return Geometry.collision_rect(sprite, Vector4(0.0, owner.VEHICLE_HITBOX_INSET.y, 0.0, owner.VEHICLE_HITBOX_INSET.w), owner)


static func _x_intersects(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x
