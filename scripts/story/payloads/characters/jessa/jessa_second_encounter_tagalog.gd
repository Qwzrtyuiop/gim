extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "jessa_second_encounter",
		"chapter_title": "Pamilyar na Pasahero",
		"speaker_portraits": true,
		"return_scene": "res://scenes/ride_selection.tscn",
		"next_scene": "res://scenes/ride_selection.tscn",
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			# Entry scaffold: author Jessa's second encounter here.
			{
				"speaker": "John Toda",
				"text": "Sandali... Naalala kita.",
			},
			# 1
			# Keep completion effects on the final reached section when expanding.
			{
				"speaker": "Jessa",
				"text": "...",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_second_encounter_seen",
						"value": true,
					},
				],
			},
		],
	})
