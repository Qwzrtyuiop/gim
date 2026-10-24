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
				"text": "Nagmamadaling bumaba ang pasahero mula sa aking tricycle.",
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
				"text": "Isang nakatuping 200 peso bill ang nahulog mula sa bulsa niya.",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Dalawang daang piso...",
			},
			# 3 — RETURN_CHOICE_1
			{
				"speaker": "John Toda",
				"text": "Ano ang aking gagawin?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": RETURN_REASON_1,
					},
					{
						"text": "Itago",
						"next_index": KEEP_CONFIRMATION_1,
					},
				],
			},
			# 4 — RETURN_REASON_1
			{
				"speaker": "John Toda",
				"text": "Pwede ko itong ibalik, pero...",
			},
			# 5 — RETURN_CHOICE_2
			{
				"speaker": "John Toda",
				"text": "Ano ang aking gagawin?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": RETURN_REASON_2,
					},
					{
						"text": "Itago",
						"next_index": KEEP_CONFIRMATION_2,
					},
				],
			},
			# 6 — RETURN_REASON_2
			{
				"speaker": "John Toda",
				"text": "Pero sayang naman pag isasauli ko lang.",
			},
			# 7 — RETURN_CHOICE_3
			{
				"speaker": "John Toda",
				"text": "Ano ang aking gagawin?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": RETURN_REASON_3,
					},
					{
						"text": "Itago",
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
				"text": "Ano ngayon?",
				"choices": [
					{
						"text": "Isauli",
						"next_index": RETURN_REASON_4,
					},
					{
						"text": "Itago",
						"next_index": KEEP_CONFIRMATION_4,
					},
				],
			},
			# 10 — RETURN_REASON_4
			{
				"speaker": "John Toda",
				"text": "Dalawang daan lang naman yan. Hindi sila mamamatay pag mawala sakanila yan.",
			},
			# 11
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
					},
				],
			},
			# 12 — RETURN_CHOICE_5
			{
				"speaker": "John Toda",
				"text": "Ano ngayon?",
				"hide_debt_overlay": {
					"fade_out": 0.18,
				},
				"choices": [
					{
						"text": "Isauli",
						"next_index": RETURN_MONEY,
					},
					{
						"text": "Itago",
						"next_index": KEEP_CONFIRMATION_5,
					},
				],
			},
			# 13 — KEEP_MONEY
			{
				"speaker": "John Toda",
				"text": "Sabi ko nga.",
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
				"text": "Bumaba ang iyong karma.",
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
				"text": "Teka lang Sir! May nahulog po kayo.",
			},
			# 17
			{
				"text": "Lumingon ang aking pasahero, at kinuha ang kanyang nahulog na pera.",
			},
			# 18
			{
				"text": "\"Salamat,\" ang kanyang wika bago siya umalis muli.",
				"actions": [
					{
						"type": "fade_to_black",
						"duration": 0.28,
					},
				],
			},
			# 19
			{
				"text": "Tumaas ang iyong karma.",
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
				"text": "Sigurado ba ako?",
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
				"text": "Sigurado ba ako?",
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
				"text": "Sigurado ba ako?",
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
				"text": "Sigurado ba ako?",
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
				"text": "Sigurado ba ako?",
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
