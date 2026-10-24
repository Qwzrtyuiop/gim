extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const COLLECT_FARE := 9
const WAIVE_FARE := 15
const STORY_END := 21


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
				"text": "I stop at the destination.",
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "We're here.",
			},
			# 2
			{
				"speaker": "Passenger",
				"text": "Okay let me just get...",
			},
			# 3
			{
				"speaker": "Passenger",
				"text": "Huh.",
			},
			# 4
			{
				"speaker": "Passenger",
				"text": "My wallet... it's not here.",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "What?",
			},
			# 6
			{
				"speaker": "Passenger",
				"text": "I don't have my wallet. I must have left it at home.",
			},
			# 7
			{
				"text": "The passenger frantically searches their bag, but doesn't find anything.",
			},
			# 8
			{
				"speaker": "Passenger",
				"text": "What should I do...",
				"choices": [
					{
						"text": "\"Do something about it, then.\"",
						"next_index": COLLECT_FARE,
					},
					{
						"text": "Let him off without paying",
						"next_index": WAIVE_FARE,
					},
				],
			},
			# 9 — COLLECT_FARE
			{
				"speaker": "John Toda",
				"text": "Do something about it then.",
			},
			# 10
			{
				"speaker": "Passenger",
				"text": "But I don't have money.",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Maybe try borrowing from someone, I'll wait here.",
			},
			# 12
			{
				"speaker": "Passenger",
				"text": "Oh, ok.",
			},
			# 13
			{
				"text": "The passenger gets off and heads inside the building.",
			},
			# 14
			{
				"text": "After a few minutes they returned, bringing the fare.",
				"actions": [
					{
						"type": "resolve_random_ride_fare",
						"outcome": "collect",
					},
				],
				"next_index": STORY_END,
			},
			# 15 — WAIVE_FARE
			{
				"speaker": "John Toda",
				"text": "Ehh... It's fine.",
			},
			# 16
			{
				"speaker": "Passenger",
				"text": "What?",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "I said it's fine, there's nothing we can do about it.",
			},
			# 18
			{
				"speaker": "Passenger",
				"text": "Really?",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "Just pay me next time or something. It's just one ride anyway.",
			},
			# 20
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
