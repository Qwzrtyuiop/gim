extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_a_generous_stranger",
		"chapter_title": "A Generous Stranger",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"speaker": "Passenger",
				"text": "You've been driving all day? Here. Get yourself a break.",
			},
			# 1
			{
				"text": "That's unusually generous.",
			},
			# 2
			{
				"text": "Received PhP 40. Stress -1.",
				"actions": [
					{
						"type": "add_money",
						"amount": 40,
					},
					{
						"type": "relieve_stress",
						"amount": 1,
					},
				],
			},
		],
	})
