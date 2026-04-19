extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return {
		"story_id": "day_02_station_bill",
		"chapter_title": "Day 2",
		"background": StoryConstants.BACKGROUND_STATION,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_CITY_AMBIENCE,
			"loop": true,
			"fade_in": 0.55,
			"volume_db": -9.0,
		},
		"composition": [
			{
				"background": StoryConstants.BACKGROUND_STATION,
				"background_fade": 0.28,
				"pause_before": 0.14,
				"text": "Sa terminal, may pasaherong nagmamadaling bumaba.",
				"camera": {
					"zoom": 1.0,
					"focus": "center",
					"duration": 0.4,
				},
			},
			{
				"text": "Isang nakatuping 200 peso bill ang nahulog mula sa bulsa niya at napadpad malapit sa paa ko.",
			},
			{
				"speaker": "John Toda",
				"text": "Dalawang daang piso. Nakalatag lang dito.",
			},
			{
				"speaker": "John Toda",
				"text": "Ano ngayon?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": 4,
					},
					{
						"text": "Itago",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "Gusto ko naman, pero...",
			},
			{
				"speaker": "John Toda",
				"text": "Ano ngayon?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": 6,
					},
					{
						"text": "Itago",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "Pero libreng pera ito.",
			},
			{
				"speaker": "John Toda",
				"text": "Ano ngayon?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": 8,
					},
					{
						"text": "Itago",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "...",
			},
			{
				"speaker": "John Toda",
				"text": "Ano ngayon?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": 10,
					},
					{
						"text": "Itago",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "Katangahan kung hindi ko kukunin. Dalawang daan lang naman. Hindi sila mamamatay sa ganitong halaga.",
			},
			{
				"speaker": "John Toda",
				"text": "Ako, sa kabilang banda...",
				"show_debt_overlay": {
					"fade_in": 0.24,
				},
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_DRUM,
						"loop": false,
						"fade_out": 0.25,
						"volume_db": -6.0,
					}
				],
			},
			{
				"speaker": "John Toda",
				"text": "Ano ngayon?",
				"hide_debt_overlay": {
					"fade_out": 0.18,
				},
				"choices": [
					{
						"text": "Isauli",
						"next_index": 16,
					},
					{
						"text": "Itago",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "Oo. Iyon nga.",
				"actions": [
					{
						"type": "fade_to_black",
						"duration": 0.28,
					}
				],
			},
			{
				"text": "+200 pesos",
				"actions": [
					{
						"type": "add_money",
						"amount": 200,
					}
				],
			},
			{
				"text": "Bumaba ang karma.",
				"pause_after": 1.4,
				"actions": [
					{
						"type": "set_event_value",
						"id": "day_2_station_bill",
						"value": 2,
					},
					{
						"type": "add_karma",
						"amount": -1,
					},
					{
						"type": "unlock_achievement",
						"id": "mapagsamantala",
					}
				],
			},
			{
				"speaker": "John Toda",
				"text": "Sandali. Sir! Nahulog ito sa inyo.",
			},
			{
				"text": "Lumingon ang pasahero, nagulat, at kinuha ang pera gamit ang dalawang kamay.",
			},
			{
				"text": "\"Salamat,\" sabi niya bago muling magmadaling umalis.",
				"actions": [
					{
						"type": "fade_to_black",
						"duration": 0.28,
					}
				],
			},
			{
				"text": "Tumaas ang karma.",
				"pause_after": 1.4,
				"actions": [
					{
						"type": "set_event_value",
						"id": "day_2_station_bill",
						"value": 1,
					},
					{
						"type": "add_karma",
						"amount": 1,
					},
					{
						"type": "unlock_achievement",
						"id": "tapat",
					}
				],
			},
		],
	}
