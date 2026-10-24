extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const RETURN_CHOICE_1 := 3
const RETURN_REASON_1 := 4
const RETURN_CHOICE_2 := 5
const RETURN_REASON_2 := 6
const RETURN_CHOICE_3 := 7
const RETURN_REASON_3 := 8
const RETURN_CHOICE_4 := 9
const RETURN_REASON_4 := 10
const RETURN_CHOICE_5 := 12
const KEEP_MONEY := 13
const RETURN_MONEY := 16
const KEEP_CONFIRMATION_1 := 20
const KEEP_CONFIRMATION_2 := 21
const KEEP_CONFIRMATION_3 := 22
const KEEP_CONFIRMATION_4 := 23
const KEEP_CONFIRMATION_5 := 24
const STORY_END := 25


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "day_02_station_bill",
		"chapter_title": "Day 2",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "At the station, one passenger steps off in a hurry.",
				"background": StoryConstants.BACKGROUND_STATION,
				"background_fade": 0.28,
				"pause_before": 0.14,
				"camera": {
					"zoom": 1.0,
					"focus": "center",
					"duration": 0.4,
				},
			},
			# 1
			{
				"text": "A folded 200 peso bill slips from their pocket and lands near my foot.",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Two hundred pesos. Just lying there.",
			},
			# 3 — RETURN_CHOICE_1
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": RETURN_REASON_1,
					},
					{
						"text": "Keep",
						"next_index": KEEP_CONFIRMATION_1,
					},
				],
			},
			# 4 — RETURN_REASON_1
			{
				"speaker": "John Toda",
				"text": "I would but...",
			},
			# 5 — RETURN_CHOICE_2
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": RETURN_REASON_2,
					},
					{
						"text": "Keep",
						"next_index": KEEP_CONFIRMATION_2,
					},
				],
			},
			# 6 — RETURN_REASON_2
			{
				"speaker": "John Toda",
				"text": "But it's free money.",
			},
			# 7 — RETURN_CHOICE_3
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": RETURN_REASON_3,
					},
					{
						"text": "Keep",
						"next_index": KEEP_CONFIRMATION_3,
					},
				],
			},
			# 8 — RETURN_REASON_3
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 9 — RETURN_CHOICE_4
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"choices": [
					{
						"text": "Return",
						"next_index": RETURN_REASON_4,
					},
					{
						"text": "Keep",
						"next_index": KEEP_CONFIRMATION_4,
					},
				],
			},
			# 10 — RETURN_REASON_4
			{
				"speaker": "John Toda",
				"text": "I would be stupid not to take it. It's just 200 pesos anyway. They won't die losing that much.",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Me, however...",
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
					},
				],
			},
			# 12 — RETURN_CHOICE_5
			{
				"speaker": "John Toda",
				"text": "So what now?",
				"hide_debt_overlay": {
					"fade_out": 0.18,
				},
				"choices": [
					{
						"text": "Return",
						"next_index": RETURN_MONEY,
					},
					{
						"text": "Keep",
						"next_index": KEEP_CONFIRMATION_5,
					},
				],
			},
			# 13 — KEEP_MONEY
			{
				"speaker": "John Toda",
				"text": "Yeah. That's what I thought.",
				"actions": [
					{
						"type": "fade_to_black",
						"duration": 0.28,
					},
				],
			},
			# 14
			{
				"text": "+200 pesos",
				"actions": [
					{
						"type": "add_money",
						"amount": 200,
					},
				],
			},
			# 15
			{
				"text": "Karma went down.",
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
					},
				],
				"pause_after": 1.4,
				"next_index": STORY_END,
			},
			# 16 — RETURN_MONEY
			{
				"speaker": "John Toda",
				"text": "Wait. Sir! You dropped this.",
			},
			# 17
			{
				"text": "The passenger turns back, startled, then takes the bill with both hands.",
			},
			# 18
			{
				"text": "\"Thank you,\" they say before hurrying off again.",
				"actions": [
					{
						"type": "fade_to_black",
						"duration": 0.28,
					},
				],
			},
			# 19
			{
				"text": "Karma went up.",
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
					},
				],
				"pause_after": 1.4,
				"next_index": STORY_END,
			},
			# 20 — KEEP_CONFIRMATION_1
			{
				"speaker": "John Toda",
				"text": "Should I?",
				"choices": [
					{
						"text": "Yes",
						"next_index": KEEP_MONEY,
					},
					{
						"text": "No",
						"next_index": RETURN_CHOICE_1,
					},
				],
			},
			# 21 — KEEP_CONFIRMATION_2
			{
				"speaker": "John Toda",
				"text": "Should I?",
				"choices": [
					{
						"text": "Yes",
						"next_index": KEEP_MONEY,
					},
					{
						"text": "No",
						"next_index": RETURN_CHOICE_2,
					},
				],
			},
			# 22 — KEEP_CONFIRMATION_3
			{
				"speaker": "John Toda",
				"text": "Should I?",
				"choices": [
					{
						"text": "Yes",
						"next_index": KEEP_MONEY,
					},
					{
						"text": "No",
						"next_index": RETURN_CHOICE_3,
					},
				],
			},
			# 23 — KEEP_CONFIRMATION_4
			{
				"speaker": "John Toda",
				"text": "Should I?",
				"choices": [
					{
						"text": "Yes",
						"next_index": KEEP_MONEY,
					},
					{
						"text": "No",
						"next_index": RETURN_CHOICE_4,
					},
				],
			},
			# 24 — KEEP_CONFIRMATION_5
			{
				"speaker": "John Toda",
				"text": "Should I?",
				"choices": [
					{
						"text": "Yes",
						"next_index": KEEP_MONEY,
					},
					{
						"text": "No",
						"next_index": RETURN_CHOICE_5,
					},
				],
			},
		],
	})
