extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")

const STORY_END := 1


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "benny_construction_work_offer",
		"chapter_title": "Construction Work",
		"speaker_portraits": true,
		"background": "res://assets/story/backgrounds/locations/constructionnight.png" if PlayerState.get_current_time_of_day() == "night" else "res://assets/story/backgrounds/locations/constructionday.png",
		"music": {},
		"ambient_sfx": {
			"loop": true,
			"path": "res://assets/audio/ambience/construction.mp3",
			"volume_db": -14.0,
		},
		"composition": [
			# 0
			{
				"speaker": "Benny",
				"text": "to be translated",
				"choice_details": "to be translated",
				"choices": [
					{
						"text": "to be translated",
						"conditions": {
							"min_energy": 2,
							"forbidden_event_values": {
								"construction_work_last_day": PlayerState.get_current_day(),
							},
						},
						"show_locked": true,
						"locked_text": "to be translated",
						"locked_reason": "to be translated",
						"disabled": PlayerState.is_midnight(),
						"next_index": STORY_END,
						"actions": [
							{
								"type": "set_event_value",
								"id": "construction_work_accepted",
								"value": true,
							},
						],
					},
					{
						"text": "to be translated",
						"next_index": STORY_END,
					},
				],
			},
		],
	})
