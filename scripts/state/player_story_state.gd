extends RefCounted

const StoryEventHandler := preload("res://scripts/story/story_event_handler.gd")
const StoryTriggerRuntime := preload("res://scripts/story/story_trigger_runtime.gd")
const StoryTriggerService := preload("res://scripts/story/story_trigger_service.gd")
const StoryGalleryUnlocker := preload("res://scripts/story/story_gallery_unlocker.gd")


static func set_last_seen_story_section(player_state, story_id: String, section_index: int) -> void:
	var safe_story_id: String = str(story_id).strip_edges()
	if safe_story_id.is_empty():
		return
	player_state.last_seen_story_id = safe_story_id
	player_state.last_seen_story_sections[safe_story_id] = max(-1, section_index)
	player_state.save_progress()


static func get_last_seen_story_section(player_state, story_id: String) -> int:
	var safe_story_id: String = str(story_id).strip_edges()
	if safe_story_id.is_empty():
		return -1
	return int(player_state.last_seen_story_sections.get(safe_story_id, -1))


static func get_last_seen_story_id(player_state) -> String:
	return player_state.last_seen_story_id


static func has_seen_story(player_state, story_id: String) -> bool:
	var safe_story_id: String = str(story_id).strip_edges()
	if safe_story_id.is_empty():
		return false
	return int(player_state.last_seen_story_sections.get(safe_story_id, -1)) >= 0


static func get_seen_story_ids(player_state) -> Array[String]:
	var seen_story_ids: Array[String] = []
	for story_id_variant in player_state.last_seen_story_sections.keys():
		var story_id: String = str(story_id_variant).strip_edges()
		if story_id.is_empty():
			continue
		if int(player_state.last_seen_story_sections.get(story_id_variant, -1)) < 0:
			continue
		seen_story_ids.append(story_id)
	seen_story_ids.sort()
	return seen_story_ids


static func unlock_gallery_image(player_state, image_path: String) -> bool:
	var safe_image_path: String = _normalize_gallery_image_path(image_path)
	if safe_image_path.is_empty():
		return false
	if player_state.unlocked_gallery_images.has(safe_image_path):
		return false
	player_state.unlocked_gallery_images[safe_image_path] = true
	player_state.save_progress()
	return true


static func unlock_gallery_images(player_state, image_paths: Array) -> int:
	var unlock_count: int = 0
	for image_path_variant in image_paths:
		var safe_image_path: String = _normalize_gallery_image_path(str(image_path_variant))
		if safe_image_path.is_empty() or player_state.unlocked_gallery_images.has(safe_image_path):
			continue
		player_state.unlocked_gallery_images[safe_image_path] = true
		unlock_count += 1
	if unlock_count > 0:
		player_state.save_progress()
	return unlock_count


static func get_unlocked_gallery_image_paths(player_state) -> Array[String]:
	var image_paths: Array[String] = []
	for image_path_variant in player_state.unlocked_gallery_images.keys():
		var safe_image_path: String = _normalize_gallery_image_path(str(image_path_variant))
		if safe_image_path.is_empty():
			continue
		image_paths.append(safe_image_path)
	return image_paths


static func set_event_value(player_state, event_id: String, value) -> void:
	if not StoryEventHandler.set_event_value(player_state.event_values, event_id, value):
		return
	player_state.save_progress()


static func set_event_values(player_state, values: Dictionary) -> void:
	if not StoryEventHandler.set_event_values(player_state.event_values, values):
		return
	player_state.save_progress()


static func get_event_value(player_state, event_id: String, default_value = null):
	return StoryEventHandler.get_event_value(player_state.event_values, event_id, default_value)


static func has_event_value(player_state, event_id: String) -> bool:
	return StoryEventHandler.has_event_value(player_state.event_values, event_id)


static func clear_event_value(player_state, event_id: String) -> void:
	if not StoryEventHandler.clear_event_value(player_state.event_values, event_id):
		return
	player_state.save_progress()


static func get_event_values(player_state) -> Dictionary:
	return StoryEventHandler.get_event_values(player_state.event_values)


static func clear_event_values(player_state) -> void:
	if not StoryEventHandler.clear_event_values(player_state.event_values):
		return
	player_state.save_progress()


static func set_resume_scene(player_state, scene_path: String) -> void:
	var safe_scene_path: String = str(scene_path).strip_edges()
	if safe_scene_path.is_empty() or player_state.resume_scene_path == safe_scene_path:
		return
	player_state.resume_scene_path = safe_scene_path
	player_state.save_progress()


static func get_resume_scene(player_state) -> String:
	return player_state.resume_scene_path


static func has_ride_select_tutorial_shown(player_state) -> bool:
	return player_state.ride_select_tutorial_shown


static func mark_ride_select_tutorial_shown(player_state) -> void:
	if player_state.ride_select_tutorial_shown:
		return
	player_state.ride_select_tutorial_shown = true
	player_state.save_progress()


static func has_store_tutorial_shown(player_state) -> bool:
	return player_state.store_tutorial_shown


static func mark_store_tutorial_shown(player_state) -> void:
	if player_state.store_tutorial_shown:
		return
	player_state.store_tutorial_shown = true
	player_state.save_progress()


static func has_home_tutorial_shown(player_state) -> bool:
	return player_state.home_tutorial_shown


static func mark_home_tutorial_shown(player_state) -> void:
	if player_state.home_tutorial_shown:
		return
	player_state.home_tutorial_shown = true
	player_state.save_progress()


static func add_story_trigger(player_state, trigger_data: Dictionary) -> void:
	if trigger_data.is_empty():
		return

	var normalized_trigger: Dictionary = StoryTriggerService.normalize_trigger(player_state, trigger_data)
	if normalized_trigger.is_empty():
		return

	player_state.story_triggers.append(normalized_trigger)
	player_state.save_progress()


static func clear_story_triggers(player_state) -> void:
	player_state.story_triggers.clear()
	player_state.consumed_story_triggers.clear()
	player_state.save_progress()


static func get_story_triggers(player_state) -> Array:
	return player_state.story_triggers.duplicate(true)


static func normalize_story_trigger_phase(phase: String) -> String:
	return StoryTriggerService.normalize_story_trigger_phase(phase)


static func find_story_trigger_for_phase(player_state, phase: String, day_number: int = -1, context: Dictionary = {}) -> Dictionary:
	return StoryTriggerRuntime.find_story_trigger_for_phase(player_state, phase, day_number, context)


static func has_story_trigger_for_phase(player_state, phase: String, day_number: int = -1, context: Dictionary = {}) -> bool:
	return not find_story_trigger_for_phase(player_state, phase, day_number, context).is_empty()


static func get_story_payload_for_trigger(trigger_data: Dictionary) -> Dictionary:
	return StoryTriggerService.get_story_payload_for_trigger(trigger_data)


static func consume_story_trigger(player_state, trigger_data: Dictionary) -> void:
	if not StoryTriggerService.consume_story_trigger(player_state.consumed_story_triggers, trigger_data):
		return
	player_state.save_progress()


static func reset_story_triggers(player_state) -> void:
	player_state.story_triggers = StoryTriggerService.build_default_story_triggers()
	player_state.consumed_story_triggers.clear()


static func reset_story_progress_state(player_state) -> void:
	player_state.last_seen_story_sections.clear()
	player_state.last_seen_story_id = ""
	player_state.event_values.clear()
	player_state.unlocked_gallery_images.clear()
	player_state.gallery_image_unlocks_initialized = true
	reset_story_triggers(player_state)


static func reset_tutorial_state(player_state) -> void:
	player_state.ride_select_tutorial_shown = false
	player_state.store_tutorial_shown = false
	player_state.home_tutorial_shown = false


static func _normalize_gallery_image_path(image_path: String) -> String:
	return StoryGalleryUnlocker.normalize_image_path(image_path)
