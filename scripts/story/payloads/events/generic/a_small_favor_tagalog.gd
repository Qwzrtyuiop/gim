extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "generic_a_small_favor",
		"chapter_title": "A Small Favor",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": {},
		"composition": [
			# 0
			{
				"text": "to be translated",
			},
			# 1
			{
				"speaker": "Passenger",
				"text": "to be translated",
			},
			# 2
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "add_money",
						"amount": 25,
					},
					{
						"type": "relieve_stress",
						"amount": 1,
					},
				],
			},
		],
	})
