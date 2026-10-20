extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")


# Shared presentation for all random ride events, matching Day 2.
static func build(story_id: String, title: String, opening: Array, collect: Array, waive: Array, choices: Array) -> Dictionary:
	var composition := opening.duplicate(true)
	var collect_index := composition.size()
	var waive_index := collect_index + collect.size()
	var end_index := waive_index + waive.size()
	composition[-1]["choices"] = [
		{"text": choices[0], "next_index": collect_index},
		{"text": choices[1], "next_index": waive_index},
	]
	composition.append_array(collect.duplicate(true))
	composition.append_array(waive.duplicate(true))
	composition[waive_index - 1]["next_index"] = end_index
	composition[end_index - 1]["next_index"] = end_index
	composition[waive_index - 1]["actions"] = [{"type": "resolve_random_ride_fare", "outcome": "collect"}]
	composition[end_index - 1]["actions"] = [{"type": "resolve_random_ride_fare", "outcome": "waive"}]
	return {
		"story_id": story_id,
		"chapter_title": title,
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": {
			"type": "play_music", "path": StoryConstants.MUSIC_CITY_AMBIENCE,
			"loop": true, "fade_in": 0.55, "volume_db": -9.0,
		},
		"composition": composition,
	}
