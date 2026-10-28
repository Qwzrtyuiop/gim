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
				"text": "Here to help?",
				"choice_details": "Pay: PhP %d\n2 energy  |  1 phase" % PlayerState.get_construction_work_pay(),
				"choices": [
					{
						"text": "Yes",
						"conditions": {
							"min_energy": 2,
							"forbidden_event_values": {
								"construction_work_last_day": PlayerState.get_current_day(),
							},
						},
						"show_locked": true,
						"locked_text": "Yes",
						"locked_reason": "Done for tonight." if PlayerState.is_midnight() else ("Already worked today." if int(PlayerState.get_event_value("construction_work_last_day", 0)) == PlayerState.get_current_day() else "Need 2 energy."),
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
						"text": "No",
						"next_index": STORY_END,
					},
				],
			},
		],
	})
