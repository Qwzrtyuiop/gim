extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_an_unexpected_conversation",
		"chapter_title": "An Unexpected Conversation",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"speaker": "Passenger",
				"text": "You wouldn't believe what happened at work today!",
			},
			# 1
			{
				"text": "The passenger spends the rest of the trip telling me a ridiculous story about their boss.",
			},
			# 2
			{
				"text": "And I thought my life was a mess.",
			},
			# 3
			{
				"text": "Stress -2.",
				"actions": [
					{
						"type": "relieve_stress",
						"amount": 2,
					},
				],
			},
		],
	})
