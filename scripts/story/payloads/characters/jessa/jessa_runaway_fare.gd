extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const CHASE := 17
const LET_GO := 25
const STORY_END := 31


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "jessa_runaway_fare",
		"chapter_title": "Runaway Fare",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "I finally arrive at the passenger's destination.",
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "Alright, we're here.",
			},
			# 2
			{
				"speaker": "Jessa",
				"text": "Oh, okay. Thanks.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "That'll be the fare, miss.",
				"ride_fare_line": true,
			},
			# 4
			{
				"speaker": "Jessa",
				"text": "Right, just a second...",
			},
			# 5
			{
				"text": "The girl reaches into her pocket and pulls out a small wallet.",
			},
			# 6
			{
				"speaker": "Jessa",
				"text": "Let's see...",
			},
			# 7
			{
				"speaker": "Jessa",
				"text": "Oh...",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "Hm?",
			},
			# 9
			{
				"speaker": "Jessa",
				"text": "...",
			},
			# 10
			{
				"speaker": "Jessa",
				"text": "Hey! What's that?!",
			},
			# 11
			{
				"text": "She suddenly points at something behind me.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "Huh? What?",
			},
			# 13
			{
				"text": "I turn around, but there's nothing there.",
			},
			# 14
			{
				"speaker": "John Toda",
				"text": "What are you—",
			},
			# 15
			{
				"text": "By the time I look back, the girl is already running down the street.",
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_FUNNY,
						"loop": true,
						"fade_in": 0.0,
						"fade_out": 0.0,
						"volume_db": -9.0,
					},
				],
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "HEY!",
				"choices": [
					{
						"text": "Chase her.",
						"next_index": CHASE,
					},
					{
						"text": "Let her go.",
						"next_index": LET_GO,
					},
				],
			},
			# 17 — CHASE
			{
				"speaker": "John Toda",
				"text": "Get back here!",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_choice",
						"value": "chase",
					},
				],
			},
			# 18
			{
				"text": "I jump out of the tricycle and run after her.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"loop": false,
						"volume_db": -4.0,
					},
				],
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "HEY! YOU HAVEN'T PAID YET!",
			},
			# 20
			{
				"speaker": "Jessa",
				"text": "SORRY!",
			},
			# 21
			{
				"text": "The girl turns into a narrow alley. By the time I reach it, she's nowhere to be seen.",
				"background": StoryConstants.BACKGROUND_ALLEY,
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "Hah... Hah...",
				"actions": [
					{
						"type": "stop_sfx",
					},
				],
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "You've got to be kidding me...",
			},
			# 24
			{
				"text": "After catching my breath, I walk back to my tricycle. I have a feeling this isn't the last time I'll see her.",
				"background": StoryConstants.BACKGROUND_STATION,
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 25 — LET_GO
			{
				"text": "I watch the girl disappear around the corner.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_choice",
						"value": "let_go",
					},
				],
			},
			# 26
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 27
			{
				"speaker": "John Toda",
				"text": "Haaah...",
			},
			# 28
			{
				"text": "I let out a long sigh, then turn back toward my tricycle.",
				"background": StoryConstants.BACKGROUND_STATION,
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "There goes my fare.",
			},
			# 30
			{
				"text": "I get back in and continue driving. I have a feeling this isn't the last time I'll see her.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_runaway_fare_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
