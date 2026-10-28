extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_a_quiet_ride",
		"chapter_title": "A Quiet Ride",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"text": "My passenger spent the entire trip asleep.",
			},
			# 1
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
