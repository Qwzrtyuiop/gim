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
				"text": "I pull over at the station and let my passenger off.",
			},
			# 1
			{
				"text": "Without saying a word, the girl hands me the fare.",
			},
			# 2
			{
				"text": "I take the money and watch as she walks away.",
			},
			# 3
			{
				"text": "As I prepare to leave, I notice something lying on the passenger seat.",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "Hm?",
			},
			# 5
			{
				"text": "It's an ID card.",
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
				"text": "I pick it up and examine it.",
				"speaker_portraits": false,
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "Hana Olivera...",
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
				"text": "Must've fallen out of her bag.",
				"speaker_portraits": false,
			},
			# 9
			{
				"text": "I look toward the direction she went, but she's already gone.",
				"speaker_portraits": true,
				"portraits": [],
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Guess I'll give it back next time I see her.",
			},
			# 12
			{
				"text": "I slip the ID into my pocket and return to work.",
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
