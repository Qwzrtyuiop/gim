extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

const SETTLE := 1
const STORY_END := 2


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "isidro_first_encounter",
		"chapter_title": "to be translated",
		"speaker_portraits": true,
		"return_scene": "res://scenes/main.tscn",
		"next_scene": "res://scenes/main.tscn",
		"driving_outcome": "end_without_fare",
		"background": StoryConstants.street_background(PlayerState.get_current_time_of_day()),
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"speaker": "Isidro",
				"speaker_display_name": "???",
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "isidro_name_revealed",
						"value": true,
					},
				],
				"choices": [
					{
						"text": "Pay Isidro ₱200.",
						"next_index": SETTLE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "isidro_first_encounter_choice",
								"value": "bribe",
							},
						],
					},
					{
						"text": "Pay the fine instead. (Requires ₱2,000)",
						"next_index": SETTLE,
						"min_money": 2000,
						"show_locked": true,
						"locked_reason": "Requires ₱2,000.",
						"actions": [
							{
								"type": "set_event_value",
								"id": "isidro_first_encounter_choice",
								"value": "fine",
							},
						],
					},
				],
			},
			# 1 - SETTLE
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "change_resource",
						"resource": "money",
						"amount": -200,
					},
					{
						"type": "set_event_value",
						"id": "isidro_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
