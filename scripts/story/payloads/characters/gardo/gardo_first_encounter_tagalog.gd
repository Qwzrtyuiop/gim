extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based branch targets; append future branches to preserve saved indices.
const DECISION := 28
const ACCEPT := 29
const REFUSE := 43
const STORY_END := 68


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "gardo_first_encounter",
		"chapter_title": "to be translated",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.BACKGROUND_TERMINAL_NIGHT,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "to be translated",
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 2
			{
				"speaker": "John Toda",
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
				"speaker": "John Toda",
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
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 10
			{
				"text": "to be translated",
			},
			# 11
			{
				"speaker": "Gardo",
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
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 15
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 18
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 19
			{
				"text": "to be translated",
			},
			# 20
			{
				"text": "to be translated",
			},
			# 21
			{
				"text": "to be translated",
			},
			# 22
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 24
			{
				"speaker": "Gardo",
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
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 27
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 28 - DECISION
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
				"choices": [
					{
						"text": "Accept his offer.",
						"next_index": ACCEPT,
						"actions": [
							{
								"type": "set_event_value",
								"id": "gardo_first_encounter_choice",
								"value": "accept",
							},
						],
					},
					{
						"text": "Refuse.",
						"next_index": REFUSE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "gardo_first_encounter_choice",
								"value": "refuse",
							},
						],
					},
				],
			},
			# 29 - ACCEPT
			{
				"text": "to be translated",
			},
			# 30
			{
				"text": "to be translated",
			},
			# 31
			{
				"text": "to be translated",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 33
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 34
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 35
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 36
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 37
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 39
			{
				"text": "to be translated",
			},
			# 40
			{
				"text": "to be translated",
			},
			# 41
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 42
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "gardo_first_encounter_seen",
						"value": true,
					},
					{
						"type": "start_special_stage",
						"id": "gardo_extra_lap",
					},
				],
				"next_index": STORY_END,
			},
			# 43 - REFUSE
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 44
			{
				"text": "to be translated",
			},
			# 45
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 46
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 47
			{
				"text": "to be translated",
			},
			# 48
			{
				"text": "to be translated",
			},
			# 49
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 50
			{
				"text": "to be translated",
			},
			# 51
			{
				"speaker": "Gardo",
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
				"text": "to be translated",
			},
			# 54
			{
				"text": "to be translated",
			},
			# 55
			{
				"text": "to be translated",
			},
			# 56
			{
				"text": "to be translated",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "gardo_seated",
						"texture": StoryConstants.SPRITE_GARDO_MIDNIGHT,
						"background_region": [214, 396, 133, 161],
					},
				],
			},
			# 57
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 58
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 59
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 61
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 62
			{
				"text": "to be translated",
				"background": StoryConstants.BACKGROUND_STREET_NIGHT,
				"background_fade": 0.28,
				"speaker_portraits": false,
				"portraits": [],
			},
			# 63
			{
				"text": "to be translated",
			},
			# 64
			{
				"text": "to be translated",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.28,
			},
			# 65
			{
				"text": "to be translated",
			},
			# 66
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 67
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "gardo_first_encounter_seen",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "gardo_midnight_encounter_boost",
						"value": true,
					},
					{
						"type": "return_to",
						"destination": "home",
					},
				],
				"next_index": STORY_END,
			},
		],
	})
