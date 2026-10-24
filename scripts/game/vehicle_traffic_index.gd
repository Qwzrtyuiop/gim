extends RefCounted

# Buckets preserve active_entities order. Membership is rebuilt on spawn/remove,
# lane changes, and each frame; callers still apply their own collision rules.
const META := &"traffic_lane_index"


static func invalidate(owner) -> void:
	if owner.has_meta(META):
		owner.remove_meta(META)


static func lanes(owner) -> Array:
	var frame := Engine.get_process_frames()
	var cached: Dictionary = owner.get_meta(META, {})
	if int(cached.get("frame", -1)) == frame and int(cached.get("count", -1)) == owner.active_entities.size() and is_same(cached.get("source"), owner.active_entities):
		return cached.lanes
	var buckets: Array = [[], [], []]
	for entity: Dictionary in owner.active_entities:
		var lane := int(entity.get("lane", -1))
		if lane >= 0 and lane < 3 and is_instance_valid(entity.get("sprite")):
			buckets[lane].append(entity)
	owner.set_meta(META, {"frame": frame, "count": owner.active_entities.size(), "source": owner.active_entities, "lanes": buckets})
	return buckets


static func in_lane(owner, lane: int) -> Array:
	return lanes(owner)[lane] if lane >= 0 and lane < 3 else []
