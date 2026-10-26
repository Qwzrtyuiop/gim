extends RefCounted

const StoryPayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const JessaFareEvent := preload("res://scripts/story/jessa_fare_event.gd")
const StoryGalleryUnlocker := preload("res://scripts/story/story_gallery_unlocker.gd")
const BACKGROUND_INHOUSE := "res://assets/story/backgrounds/locations/inhouse.png"
const BACKGROUND_STATION := "res://assets/story/backgrounds/locations/Updated_day.png"
const BACKGROUND_BAR := "res://assets/story/backgrounds/locations/bar.png"
const BACKGROUND_CITY := "res://assets/story/backgrounds/locations/city.png"
const TROPA_CG := "res://assets/story/specialCG/tropaCg.png"

const GALLERY_ENTRIES := [
	{
		"id": "first_morning",
		"title": "First Morning",
		"subtitle": "The house at the beginning of John's run.",
		"unlock_story_id": "scene_01_intro",
		"image": BACKGROUND_INHOUSE,
	},
	{
		"id": "station_bill",
		"title": "Station Bill",
		"subtitle": "The station where the first choice follows John.",
		"unlock_story_id": "day_02_station_bill",
		"image": BACKGROUND_STATION,
	},
	{
		"id": "tropa_city",
		"title": "City Lights",
		"subtitle": "The city outside Benny's meeting place.",
		"unlock_story_id": "benny_tropa_night",
		"image": BACKGROUND_CITY,
	},
	{
		"id": "tropa_bar",
		"title": "Tropa Night",
		"subtitle": "A few hours where the years feel smaller.",
		"unlock_story_id": "benny_tropa_night",
		"image": BACKGROUND_BAR,
	},
	{
		"id": "tropa_bar_exterior",
		"title": "Outside the Bar",
		"subtitle": "Waiting for old friends under the bar's lights.",
		"unlock_story_id": "benny_tropa_night",
		"image": "res://assets/story/backgrounds/locations/barnight.png",
	},
	{
		"id": "tropa_cg",
		"title": "Tropa",
		"subtitle": "Old friends laugh like the years never moved.",
		"unlock_story_id": "benny_tropa_night",
		"image": TROPA_CG,
	},
	{
		"id": "day_7_house",
		"title": "Day 7 Night",
		"subtitle": "A quiet house before tomorrow's knock.",
		"unlock_story_id": "scene_03_day7_night",
		"image": BACKGROUND_INHOUSE,
	},
]


static func get_unlocked_gallery_entries(player_state) -> Array[Dictionary]:
	_migrate_seen_story_gallery_images(player_state)
	var unlocked_entries: Array[Dictionary] = []
	var image_paths: Array[String] = player_state.get_unlocked_gallery_image_paths()
	for image_path in image_paths:
		var entry: Dictionary = StoryGalleryUnlocker.build_gallery_entry(image_path, _gallery_metadata_for_image(image_path))
		if entry.is_empty():
			continue
		unlocked_entries.append(entry)
	return unlocked_entries


static func get_unlocked_memory_entries(player_state) -> Array[Dictionary]:
	return _unlocked_entries(player_state, StoryPayloadCatalog.memory_entries())


static func get_memory_entry(memory_id: String) -> Dictionary:
	var safe_id: String = str(memory_id).strip_edges().to_lower()
	for entry_variant in StoryPayloadCatalog.memory_entries():
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant as Dictionary
		if str(entry.get("id", "")).strip_edges().to_lower() == safe_id:
			return entry.duplicate(true)
	return {}


static func build_memory_payload(memory_id: String, return_scene: String) -> Dictionary:
	var payload: Dictionary = StoryPayloadCatalog.build(memory_id, return_scene)

	if payload.is_empty():
		return {}

	payload["return_scene"] = return_scene
	payload["next_scene"] = return_scene
	payload["replay"] = true
	payload["memory_replay"] = true
	JessaFareEvent.apply_saved_fare(PlayerState, payload)
	payload.erase("prepare_stage_start")
	payload.erase("stage_descriptor")
	return payload


static func unlock_all(player_state) -> void:
	var unlock_entries: Array = StoryPayloadCatalog.memory_entries()
	var image_paths: Array[String] = []

	for entry_variant in unlock_entries:
		if not entry_variant is Dictionary:
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var story_id: String = str(entry.get("unlock_story_id", "")).strip_edges()
		if not story_id.is_empty():
			var section_index: int = maxi(0, player_state.get_last_seen_story_section(story_id))
			player_state.set_last_seen_story_section(story_id, section_index)
			var payload: Dictionary = _build_payload_for_story_id(story_id)
			_append_unique_image_paths(image_paths, StoryGalleryUnlocker.collect_payload_gallery_image_paths(payload))

		var event_id: String = str(entry.get("unlock_event_id", "")).strip_edges()
		if not event_id.is_empty():
			player_state.set_event_value(event_id, 1)

		var achievement_id: String = str(entry.get("unlock_achievement_id", "")).strip_edges()
		if not achievement_id.is_empty():
			player_state.unlock_achievement(achievement_id)

	player_state.unlock_gallery_images(image_paths)
	player_state.gallery_image_unlocks_initialized = true
	player_state.save_progress()


static func unlock_gallery_and_memories_only(player_state) -> void:
	var unlock_entries: Array = StoryPayloadCatalog.memory_entries()
	var image_paths: Array[String] = []

	for entry_variant in unlock_entries:
		if not entry_variant is Dictionary:
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var story_id: String = str(entry.get("unlock_story_id", "")).strip_edges()
		if story_id.is_empty():
			continue

		var section_index: int = maxi(0, player_state.get_last_seen_story_section(story_id))
		player_state.set_last_seen_story_section(story_id, section_index)
		var payload: Dictionary = _build_payload_for_story_id(story_id)
		_append_unique_image_paths(image_paths, StoryGalleryUnlocker.collect_payload_gallery_image_paths(payload))

	player_state.unlock_gallery_images(image_paths)
	player_state.gallery_image_unlocks_initialized = true
	player_state.save_progress()


static func _migrate_seen_story_gallery_images(player_state) -> void:
	if bool(player_state.gallery_image_unlocks_initialized):
		return

	var image_paths: Array[String] = []
	for story_id in player_state.get_seen_story_ids():
		var payload: Dictionary = _build_payload_for_story_id(story_id)
		_append_unique_image_paths(image_paths, StoryGalleryUnlocker.collect_payload_gallery_image_paths(payload))

	player_state.unlock_gallery_images(image_paths)
	player_state.gallery_image_unlocks_initialized = true
	player_state.save_progress()


static func _gallery_metadata_for_image(image_path: String) -> Dictionary:
	var safe_image_path: String = StoryGalleryUnlocker.normalize_image_path(image_path)
	if safe_image_path.is_empty():
		return {}

	for entry_variant in GALLERY_ENTRIES:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant as Dictionary
		if str(entry.get("image", "")) == safe_image_path:
			return entry.duplicate(true)
	return {}


static func _append_unique_image_paths(target_paths: Array[String], image_paths: Array[String]) -> void:
	for image_path in image_paths:
		var safe_image_path: String = StoryGalleryUnlocker.normalize_image_path(image_path)
		if safe_image_path.is_empty() or target_paths.has(safe_image_path):
			continue
		target_paths.append(safe_image_path)


static func _unlocked_entries(player_state, source_entries: Array) -> Array[Dictionary]:
	var unlocked_entries: Array[Dictionary] = []
	for entry_variant in source_entries:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		if not _is_entry_unlocked(player_state, entry):
			continue
		entry["unlocked"] = true
		unlocked_entries.append(entry)
	return unlocked_entries


static func _is_entry_unlocked(player_state, entry: Dictionary) -> bool:
	var story_id: String = str(entry.get("unlock_story_id", "")).strip_edges()
	if not story_id.is_empty() and player_state.has_seen_story(story_id):
		return true

	var event_id: String = str(entry.get("unlock_event_id", "")).strip_edges()
	if not event_id.is_empty() and player_state.has_event_value(event_id):
		return true

	var achievement_id: String = str(entry.get("unlock_achievement_id", "")).strip_edges()
	if not achievement_id.is_empty() and player_state.has_achievement(achievement_id):
		return true

	return false


static func _build_payload_for_story_id(story_id: String) -> Dictionary:
	return StoryPayloadCatalog.build(story_id)
