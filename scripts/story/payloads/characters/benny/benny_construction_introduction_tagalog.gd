extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")

const HONEST := 10
const DENY := 17
const COMMON := 24


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "benny_construction_introduction",
		"chapter_title": "An Extra Pair of Hands",
		"speaker_portraits": true,
		"background": "res://assets/story/backgrounds/locations/constructionnight.png" if PlayerState.get_current_time_of_day() == "night" else "res://assets/story/backgrounds/locations/constructionday.png",
		"music": {},
		"ambient_sfx": {
			"loop": true,
			"path": "res://assets/audio/ambience/construction.mp3",
			"volume_db": -14.0,
		},
		"composition": [
			# 0
			{
				"text": "to be translated",
			},
			# 1
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 3
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 5
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 6
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 7
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 9
			{
				"text": "to be translated",
			},
			# 10 - HONEST
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"conditions": {
					"required_achievements": ["tapat"],
					"forbidden_achievements": ["sinungaling"],
				},
				"skip_index": DENY,
			},
			# 11
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 13
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 14
			{
				"text": "to be translated",
			},
			# 15
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"next_index": COMMON,
			},
			# 17 - DENY
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 18
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 20
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 21
			{
				"text": "to be translated",
			},
			# 22
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 24 - COMMON
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 25
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 26
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 27
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 28
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 29
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 30
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 31
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 33
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 34
			{
				"text": "to be translated",
			},
			# 35
			{
				"speaker": "Benny",
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
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 39
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 40
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 41
			{
				"text": "to be translated",
			},
			# 42
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 43
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 44
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 45
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 46
			{
				"speaker": "Benny",
				"text": "to be translated",
			},
			# 47
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 48
			{
				"text": "to be translated",
			},
			# 49
			{
				"text": "to be translated",
			},
			# 50
			{
				"text": "to be translated",
			},
			# 51
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "construction_work_unlocked",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "construction_work_pay",
						"value": GameTuning.CONSTRUCTION_WORK_PAY,
						"conditions": {
							"required_achievements": ["tropa"],
							"forbidden_events": ["construction_work_pay"],
						},
					},
					{
						"type": "set_event_value",
						"id": "construction_work_pay",
						"value": GameTuning.CONSTRUCTION_WORK_BASE_PAY,
						"conditions": {
							"forbidden_achievements": ["tropa"],
							"forbidden_events": ["construction_work_pay"],
						},
					},
				],
			},
		],
	})
