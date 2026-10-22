extends RefCounted

# Register each authored story once. Events and the memory library share this list.
# Titles/previews fall back to the payload, so new entries need only both scripts.
const STORIES := {
	"scene_01_intro": {
		"english": preload("res://scripts/story/payloads/intro/scene_01_intro.gd"),
		"tagalog": preload("res://scripts/story/payloads/intro/scene_01_intro_tagalog.gd"),
		"title": "Prologue", "subtitle": "John's first morning as a tricycle driver.",
	},
	"day_02_station_bill": {
		"english": preload("res://scripts/story/payloads/events/day_02_station_bill.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/day_02_station_bill_tagalog.gd"),
		"title": "Day 2", "subtitle": "A folded bill lands at John's feet.",
	},
	"benny_class_clown": {
		"english": preload("res://scripts/story/payloads/characters/benny/benny_class_clown.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/benny/benny_class_clown_tagalog.gd"),
		"title": "Class Clown", "subtitle": "Benny asks John what happened in the city.",
	},
	"benny_tropa_night": {
		"english": preload("res://scripts/story/payloads/characters/benny/benny_tropa_night.gd"),
		"tagalog": preload("res://scripts/story/payloads/characters/benny/benny_tropa_night_tagalog.gd"),
		"title": "Tropa", "subtitle": "Old friends meet under city lights.",
		"preview_image": "res://assets/story/backgrounds/locations/bar.jpeg",
	},
	"scene_03_day7_night": {
		"english": preload("res://scripts/story/payloads/events/scene_03_day7_night.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/scene_03_day7_night_tagalog.gd"),
		"title": "Collection", "subtitle": "Debt collection day.",
	},
	"malasakit": {
		"english": preload("res://scripts/story/payloads/events/malasakit.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/malasakit_tagalog.gd"),
		"subtitle": "A passenger reaches the destination without their wallet.",
	},
	"bayanihan": {
		"english": preload("res://scripts/story/payloads/events/bayanihan.gd"),
		# English fallback until a Tagalog script is supplied.
		"tagalog": preload("res://scripts/story/payloads/events/bayanihan.gd"),
		"subtitle": "A stranded driver asks John for a helping hand.",
	},
	"malasakit_epilogue": {
		"english": preload("res://scripts/story/payloads/events/malasakit_epilogue.gd"),
		"tagalog": preload("res://scripts/story/payloads/events/malasakit_epilogue_tagalog.gd"),
		"subtitle": "A familiar passenger returns to settle an old fare.",
	},
}


static func build(story_id: String, next_scene := "", stage_descriptor := "") -> Dictionary:
	var safe_id := story_id.strip_edges().to_lower()
	match safe_id:
		"day_2_station_bill":
			safe_id = "day_02_station_bill"
		"day_7_night_scene_03":
			safe_id = "scene_03_day7_night"
	if not STORIES.has(safe_id):
		return {}
	var definition: Dictionary = STORIES[safe_id]
	var script: Script = definition["tagalog" if StoryLanguageManager.is_tagalog() else "english"]
	if safe_id == "scene_01_intro":
		return script.build(next_scene, stage_descriptor)
	return script.build()


static func memory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for story_id in STORIES:
		var definition: Dictionary = STORIES[story_id]
		var payload := build(story_id)
		if payload.is_empty():
			continue
		entries.append({
			"id": story_id,
			"title": definition.get("title", payload.get("chapter_title", story_id)),
			"subtitle": definition.get("subtitle", "A moment from John's journey."),
			"unlock_story_id": story_id,
			"preview_image": definition.get("preview_image", payload.get("background", "")),
		})
	return entries
