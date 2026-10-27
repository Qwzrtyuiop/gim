extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Keep the old completion index at 1 for saved placeholder encounters.
const INTRODUCTION := 2
const ACCEPT := 33
const REFUSE := 48
const STORY_END := 78


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "celina_first_encounter",
		"chapter_title": "Just a Scratch",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0 - Entry; skip the legacy completion section.
			{
				"text": "to be translated",
				"next_index": INTRODUCTION,
			},
			# 1 - Legacy completion for saved placeholder encounters.
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 2 - INTRODUCTION
			{
				"text": "to be translated",
			},
			# 3
			{
				"text": "to be translated",
			},
			# 4
			{
				"text": "to be translated",
			},
			# 5
			{
				"text": "to be translated",
			},
			# 6
			{
				"text": "to be translated",
			},
			# 7
			{
				"text": "to be translated",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 9
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 11
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 13
			{
				"text": "to be translated",
			},
			# 14
			{
				"text": "to be translated",
			},
			# 15
			{
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 17
			{
				"text": "to be translated",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 19
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 20
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 21
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 22
			{
				"text": "to be translated",
			},
			# 23
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 24
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 26
			{
				"text": "to be translated",
			},
			# 27
			{
				"text": "to be translated",
			},
			# 28
			{
				"text": "to be translated",
			},
			# 29
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 30
			{
				"text": "to be translated",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 32 - DECISION
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
				"choices": [
					{
						"text": "to be translated",
						"next_index": ACCEPT,
					},
					{
						"text": "to be translated",
						"next_index": REFUSE,
					},
				],
			},
			# 33 - ACCEPT
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 34
			{
				"text": "to be translated",
			},
			# 35
			{
				"text": "to be translated",
			},
			# 36
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 37
			{
				"text": "to be translated",
			},
			# 38
			{
				"text": "to be translated",
			},
			# 39
			{
				"text": "to be translated",
			},
			# 40 - Bandage close-up.
			{
				"text": "to be translated",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "rabbit_bandaid",
						"texture": StoryConstants.ITEM_RABBIT_BANDAID,
						"position": "center",
						"height": 420,
					},
				],
			},
			# 41
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 42
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": true,
			},
			# 43
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 44
			{
				"text": "to be translated",
			},
			# 45
			{
				"text": "to be translated",
			},
			# 46
			{
				"text": "to be translated",
			},
			# 47 - ACCEPT COMPLETE
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 48 - REFUSE
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 49
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 50
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 51
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 52
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 53
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 54
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 55
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 56
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 57
			{
				"text": "to be translated",
			},
			# 58
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 59
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 61
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 62
			{
				"text": "to be translated",
			},
			# 63 - Bandage close-up.
			{
				"text": "to be translated",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "rabbit_bandaid",
						"texture": StoryConstants.ITEM_RABBIT_BANDAID,
						"position": "center",
						"height": 420,
					},
				],
			},
			# 64
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 65
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 66
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
				"speaker_portraits": true,
			},
			# 67
			{
				"text": "to be translated",
			},
			# 68
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 69
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 70
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 71
			{
				"text": "to be translated",
			},
			# 72
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 73
			{
				"text": "to be translated",
			},
			# 74
			{
				"text": "to be translated",
			},
			# 75
			{
				"text": "to be translated",
			},
			# 76
			{
				"text": "to be translated",
			},
			# 77 - REFUSE COMPLETE
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
