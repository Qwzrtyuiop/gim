extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

const DECISION := 48
const ACCEPT := 49
const REFUSE := 65
const COMMON := 84
const STORY_END := 118


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "alma_special_delivery",
		"chapter_title": "Special Delivery",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.BACKGROUND_BAR,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_BAR,
			"loop": true,
			"fade_in": 0.35,
			"volume_db": -9.0,
		},
		"ambient_sfx": {
			"path": StoryConstants.MUSIC_BAR_SFX,
			"loop": true,
			"volume_db": -14.0,
		},
		"composition": [
			# 0
			{
				"text": "to be translated",
			},
			# 1
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 2
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 3
			{
				"text": "to be translated",
			},
			# 4
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 6
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 8
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 9
			{
				"text": "to be translated",
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 11
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 12
			{
				"text": "to be translated",
			},
			# 13
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 14
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 15
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 17
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 19
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 20
			{
				"text": "to be translated",
			},
			# 21
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 23
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 24
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 26
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 27
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 28
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 30
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 32
			{
				"text": "to be translated",
			},
			# 33
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 34
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 35
			{
				"text": "to be translated",
			},
			# 36
			{
				"text": "to be translated",
			},
			# 37
			{
				"speaker": "Alma",
				"text": "to be translated",
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_FUNNY_2,
						"loop": true,
						"fade_in": 0.0,
						"fade_out": 0.0,
						"volume_db": -9.0,
					},
				],
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 39
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 40
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 41
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 42
			{
				"text": "to be translated",
			},
			# 43
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 44
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 45
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 46
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 47
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 48 - DECISION
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"choices": [
					{
						"text": "to be translated",
						"next_index": ACCEPT,
						"actions": [
							{
								"type": "set_event_value",
								"id": "alma_delivery_initial_choice",
								"value": "accept",
							},
						],
					},
					{
						"text": "to be translated",
						"next_index": REFUSE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "alma_delivery_initial_choice",
								"value": "refuse",
							},
						],
					},
				],
			},
			# 49 - ACCEPT
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 50
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 51
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 52
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 53
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 54
			{
				"text": "to be translated",
			},
			# 55
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 56
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 57
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 58
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 59
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 61
			{
				"text": "to be translated",
			},
			# 62
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 63
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 64
			{
				"speaker": "Alma",
				"text": "to be translated",
				"next_index": COMMON,
			},
			# 65 - REFUSE
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 66
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 67
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 68
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 69
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 70
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 71
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 72
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 73
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 74
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 75
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 76
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 77
			{
				"text": "to be translated",
			},
			# 78
			{
				"text": "to be translated",
			},
			# 79
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 80
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 81
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 82
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 83
			{
				"text": "to be translated",
				"next_index": COMMON,
			},
			# 84 - COMMON
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 85
			{
				"text": "to be translated",
			},
			# 86
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 87
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 88
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 89
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 90
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 91
			{
				"text": "to be translated",
			},
			# 92
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 93
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 94
			{
				"text": "to be translated",
			},
			# 95
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "relieve_stress",
						"amount": 10,
					},
				],
			},
			# 96
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 97
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 98
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 99
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 100
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 101
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 102
			{
				"text": "to be translated",
			},
			# 103
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 104
			{
				"text": "to be translated",
				"background": StoryConstants.CG_ALMA_HORN,
				"background_fade": 0.28,
			},
			# 105
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 106
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 107
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 108
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 109
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 110
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 111
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 112
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 113
			{
				"text": "to be translated",
			},
			# 114
			{
				"text": "to be translated",
				"background": StoryConstants.BACKGROUND_BAR,
				"background_fade": 0.28,
			},
			# 115
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 116
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 117
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_special_delivery_started",
						"value": true,
					},
					{
						"type": "start_special_stage",
						"id": "alma_special_delivery",
					},
				],
			},
		],
	})
