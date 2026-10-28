extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_rounding_up",
		"chapter_title": "Rounding Up",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"speaker": "Passenger",
				"text": "I don't have exact change. Just keep the rest.",
			},
			# 1
			{
				"text": "An extra twenty pesos. I'll take it.",
			},
			# 2
			{
				"text": "Received PhP 20.",
				"actions": [
					{
						"type": "add_money",
						"amount": 20,
					},
				],
			},
		],
	})
