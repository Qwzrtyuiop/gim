extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_keep_the_change",
		"chapter_title": "Keep the Change",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"speaker": "Passenger",
				"text": "Keep the change, driver. You got me here faster than I expected.",
			},
			# 1
			{
				"text": "Well, that's a nice surprise.",
			},
			# 2
			{
				"text": "Received PhP 20. Stress -1.",
				"actions": [
					{
						"type": "add_money",
						"amount": 20,
					},
					{
						"type": "relieve_stress",
						"amount": 1,
					},
				],
			},
		],
	})
