extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "north_road_open",
		"chapter_title": "The Road North",
		"speaker_portraits": false,
		"music": {},
		"composition": [
			# 0
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "north_road_open_announced",
						"value": true,
					},
				],
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
		],
	})
