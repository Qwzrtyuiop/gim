extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Append future sections to preserve saved indices.
const STORY_END := 13


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "hana_first_encounter",
		"chapter_title": "Lost ID 1",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.BACKGROUND_TERMINAL_NIGHT if str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day())) == "night" else StoryConstants.BACKGROUND_TERMINAL,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "to be translated",
			},
			# 1
			{
				"text": "to be translated",
			},
			# 2
			{
				"text": "to be translated",
			},
			# 3
			{
				"text": "to be translated",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 5
			{
				"text": "to be translated",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "hana_id",
						"texture": StoryConstants.ITEM_HANA_ID,
						"position": "center",
						"height": 300,
					},
				],
			},
			# 6
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
				"actions": [
					{
						"type": "set_event_value",
						"id": "hana_name_revealed",
						"value": true,
					},
				],
			},
			# 8
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 9
			{
				"text": "to be translated",
				"speaker_portraits": true,
				"portraits": [],
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 12
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "hana_has_id_card",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "hana_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
