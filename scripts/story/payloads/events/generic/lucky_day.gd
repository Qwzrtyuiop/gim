extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_lucky_day",
		"chapter_title": "Lucky Day",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"speaker": "Passenger",
				"text": "I got a little bonus at work today. Here, have some of it.",
			},
			# 1
			{
				"text": "Who am I to refuse?",
			},
			# 2
			{
				"text": "Received PhP 30. Stress -1.",
				"actions": [
					{
						"type": "add_money",
						"amount": 30,
					},
					{
						"type": "relieve_stress",
						"amount": 1,
					},
				],
			},
		],
	})
