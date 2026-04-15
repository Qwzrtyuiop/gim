extends RefCounted
class_name StoryEventHandler


static func normalize_event_id(event_id: String) -> String:
	return str(event_id).strip_edges().to_lower()


static func set_event_value(store: Dictionary, event_id: String, value) -> bool:
	var safe_id := normalize_event_id(event_id)
	if safe_id.is_empty():
		return false
	store[safe_id] = value
	return true


static func set_event_values(store: Dictionary, values: Dictionary) -> bool:
	if values.is_empty():
		return false

	var changed := false
	for event_id in values.keys():
		if set_event_value(store, str(event_id), values[event_id]):
			changed = true
	return changed


static func get_event_value(store: Dictionary, event_id: String, default_value = null):
	var safe_id := normalize_event_id(event_id)
	if safe_id.is_empty():
		return default_value
	return store.get(safe_id, default_value)


static func has_event_value(store: Dictionary, event_id: String) -> bool:
	var safe_id := normalize_event_id(event_id)
	return not safe_id.is_empty() and store.has(safe_id)


static func clear_event_value(store: Dictionary, event_id: String) -> bool:
	var safe_id := normalize_event_id(event_id)
	if safe_id.is_empty() or not store.has(safe_id):
		return false
	store.erase(safe_id)
	return true


static func clear_event_values(store: Dictionary) -> bool:
	if store.is_empty():
		return false
	store.clear()
	return true


static func get_event_values(store: Dictionary) -> Dictionary:
	return store.duplicate(true)


static func matches_required_events(store: Dictionary, required_events) -> bool:
	if not required_events is Array:
		return true
	for event_id in required_events:
		if not has_event_value(store, str(event_id)):
			return false
	return true


static func matches_forbidden_events(store: Dictionary, forbidden_events) -> bool:
	if not forbidden_events is Array:
		return true
	for event_id in forbidden_events:
		if has_event_value(store, str(event_id)):
			return false
	return true


static func matches_event_values(store: Dictionary, expected_values, should_match: bool) -> bool:
	if not expected_values is Dictionary:
		return true

	var expected_dict := expected_values as Dictionary
	for event_id in expected_dict.keys():
		var has_value := has_event_value(store, str(event_id))
		var matches_value: bool = has_value and get_event_value(store, str(event_id)) == expected_dict[event_id]
		if should_match:
			if not matches_value:
				return false
		else:
			if matches_value:
				return false
	return true


static func build_single_event_values(event_id: String, value) -> Dictionary:
	var result: Dictionary = {}
	set_event_value(result, event_id, value)
	return result
