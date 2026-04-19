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
				"text": "Nagmamadaling bumaba ang pasahero mula sa aking tricycle.",
				"camera": {
					"zoom": 1.0,
					"focus": "center",
					"duration": 0.4,
				},
			},
			{
				"text": "Isang nakatuping 200 peso bill ang nahulog mula sa bulsa niya.",
			},
			{
				"speaker": "John Toda",
				"text": "Dalawang daang piso...",
			},
			{
				"speaker": "John Toda",
				"text": "Ano ang aking gagawin?",
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
				"text": "Pwede ko itong ibalik, pero...",
			},
			{
				"speaker": "John Toda",
				"text": "Ano ang aking gagawin?",
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
				"text": "Pero sayang naman pag isasauli ko lang.",
			},
			{
				"speaker": "John Toda",
				"text": "Ano ang aking gagawin?",
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
				"text": "Dalawang daan lang naman yan. Hindi sila mamamatay pag mawala sakanila yan.",
			},
			{
				"speaker": "John Toda",
				"text": "Pero ako....",
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
				"text": "Sabi ko nga.",
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
				"text": "Bumaba ang iyong karma.",
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
				"text": "Teka lang Sir! May nahulog po kayo.",
			},
			{
				"text": "Lumingon ang aking pasahero, at kinuha ang kanyang nahulog na pera.",
			},
			{
				"text": "\"Salamat,\" ang kanyang wika bago siya umalis muli.",
				"actions": [
					{
						"type": "fade_to_black",
						"duration": 0.28,
					}
				],
			},
			{
				"text": "Tumaas ang iyong karma.",
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
