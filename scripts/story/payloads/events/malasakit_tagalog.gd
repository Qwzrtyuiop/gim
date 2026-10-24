extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const COLLECT_FARE := 10
const WAIVE_FARE := 16
const STORY_END := 22


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "malasakit",
		"chapter_title": "Malasakit",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"speaker": "Passenger",
				"text": "Kuya para dito.",
			},
			# 1
			{
				"text": "Tinigil ko ang aking tricycle.",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Andito na tayo.",
			},
			# 3
			{
				"speaker": "Passenger",
				"text": "Eto pamasahe ko.",
			},
			# 4
			{
				"speaker": "Passenger",
				"text": "Huh.",
			},
			# 5
			{
				"speaker": "Passenger",
				"text": "Teka, yung wallet ko.",
			},
			# 6
			{
				"speaker": "John Toda",
				"text": "Ano?",
			},
			# 7
			{
				"speaker": "Passenger",
				"text": "Yung wallet ko kuya, naiwan ko sa bahay.",
			},
			# 8
			{
				"text": "Hinalungkat ng pasahero ang kanyang bag, pero wala siyang nahanap.",
			},
			# 9
			{
				"speaker": "Passenger",
				"text": "Lagot, pano na to...",
				"choices": [
					{
						"text": "\"Edi gawahan mo nang paraan.\"",
						"next_index": COLLECT_FARE,
					},
					{
						"text": "Palampasin nang walang bayad",
						"next_index": WAIVE_FARE,
					},
				],
			},
			# 10 — COLLECT_FARE
			{
				"speaker": "John Toda",
				"text": "Edi gawahan mo nang paraan.",
			},
			# 11
			{
				"speaker": "Passenger",
				"text": "Pero wala akong pera.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "Edi maghanap ka, Maghihintay ako dito.",
			},
			# 13
			{
				"speaker": "Passenger",
				"text": "Sige po...",
			},
			# 14
			{
				"text": "Bumaba ang pasahero at pumasok siya sa building.",
			},
			# 15
			{
				"text": "Makalipas ang ilang minuto siya ay lumabas at binigay ang kanyang bayad.",
				"actions": [
					{
						"type": "resolve_random_ride_fare",
						"outcome": "collect",
					},
				],
				"next_index": STORY_END,
			},
			# 16 — WAIVE_FARE
			{
				"speaker": "John Toda",
				"text": "Hay... Sige na nga.",
			},
			# 17
			{
				"speaker": "Passenger",
				"text": "Bakit?",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "Bumaba ka na, libre na eto.",
			},
			# 19
			{
				"speaker": "Passenger",
				"text": "Talaga?",
			},
			# 20
			{
				"speaker": "John Toda",
				"text": "Bayaran mo nalang sa susunod kung maalala mo. Isang biyahe lang naman to e.",
			},
			# 21
			{
				"speaker": "Passenger",
				"text": "Thank you.",
				"actions": [
					{
						"type": "resolve_random_ride_fare",
						"outcome": "waive",
					},
				],
				"next_index": STORY_END,
			},
		],
	})
