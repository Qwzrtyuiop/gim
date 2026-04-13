extends RefCounted

const STATION_BACKGROUND := "res://assets/story/backgrounds/station.png"


static func build() -> Dictionary:
	return {
		"story_id": "day_02_station_bill",
		"chapter_title": "Day 2",
		"background": STATION_BACKGROUND,
		"composition": [
			{
				"background": STATION_BACKGROUND,
				"background_fade": 0.28,
				"pause_before": 0.14,
				"text": "At the station, one passenger steps off in a hurry.",
				"camera": {
					"zoom": 1.0,
					"focus": "center",
					"duration": 0.4,
				},
			},
			{
				"text": "A folded 200 peso bill slips from their pocket and lands near my foot.",
			},
			{
				"speaker": "John Toda",
				"text": "Two hundred pesos. Just lying there.",
			},
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": 4,
					},
					{
						"text": "Keep",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "I would but...",
			},
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": 6,
					},
					{
						"text": "Keep",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "But it's free money.",
			},
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": 8,
					},
					{
						"text": "Keep",
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
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": 10,
					},
					{
						"text": "Keep",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "I would be stupid not to take it. It's just 200 pesos anyway. They won't die losing that much.",
			},
			{
				"speaker": "John Toda",
				"text": "Me, however...",
			},
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Keep",
						"next_index": 13,
					},
				],
			},
			{
				"speaker": "John Toda",
				"text": "Yeah. That's what I thought.",
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
				"text": "Karma went down.",
				"pause_after": 1.4,
				"actions": [
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
		],
	}
