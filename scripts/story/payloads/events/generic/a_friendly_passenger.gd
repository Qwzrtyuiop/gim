extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_a_friendly_passenger",
		"chapter_title": "A Friendly Passenger",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"speaker": "Passenger",
				"text": "You know, driver, you look like you could use a vacation.",
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "You paying?",
			},
			# 2
			{
				"text": "The passenger laughs.",
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
