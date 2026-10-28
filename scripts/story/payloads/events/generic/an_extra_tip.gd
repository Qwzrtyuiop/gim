extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_an_extra_tip",
		"chapter_title": "An Extra Tip",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"text": "The passenger hands me a few extra coins.",
			},
			# 1
			{
				"speaker": "Passenger",
				"text": "Here. Buy yourself something to drink. It's hot out today.",
			},
			# 2
			{
				"text": "Received PhP 15. Stress -1.",
				"actions": [
					{
						"type": "add_money",
						"amount": 15,
					},
					{
						"type": "relieve_stress",
						"amount": 1,
					},
				],
			},
		],
	})
