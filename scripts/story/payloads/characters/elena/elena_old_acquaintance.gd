extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const TELL_TRUTH := 14
const LIE := 27
const STORY_END := 39


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "elena_old_acquaintance",
		"chapter_title": "An Old Acquaintance",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_ROAD_1,
		"music": StoryConstants.DRIVING_CHILL_MUSIC,
		"ambient_sfx": {
			"loop": true,
			"path": StoryConstants.SFX_ENGINE,
			"volume_db": -12.0,
		},
		"composition": [
			# 0
			{
				"text": "I was driving along my usual route when the elderly woman sitting behind me suddenly spoke.",
			},
			# 1
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Excuse me, young man.",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Yes?",
			},
			# 3
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Is that you, John?",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "Huh?",
			},
			# 5
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "John Toda, right?",
			},
			# 6
			{
				"speaker": "John Toda",
				"text": "Uh... Yes. Do I know you?",
			},
			# 7
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Oh, it really is you! My, you've grown so much.",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "Sorry, but...",
			},
			# 9
			{
				"speaker": "Elena",
				"speaker_display_name": "???",
				"text": "Ah, forgive me. I'm Elena. I used to be a teacher around here.",
				"introduces_speaker": true,
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "Oh...",
			},
			# 11
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "I knew your father, Juan. It's been quite a long time since I last saw him.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "I see.",
			},
			# 13
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "How is he doing these days? Is he well?",
				"choices": [
					{
						"text": "Tell the truth",
						"next_index": TELL_TRUTH,
					},
					{
						"text": "Lie",
						"next_index": LIE,
					},
				],
			},
			# 14 — TELL_TRUTH
			{
				"speaker": "John Toda",
				"text": "He's dead.",
				"actions": [
					{
						"type": "stop_music",
						"fade_out": 0.0,
					},
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_answer",
						"value": "truth",
					},
					{
						"type": "unlock_achievement",
						"id": "tapat",
					},
				],
			},
			# 15
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Oh...",
			},
			# 16
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "I... I didn't know. I'm so sorry.",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "It's fine.",
			},
			# 18
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "If you don't mind me asking, when did he...",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "A while ago.",
			},
			# 20
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "I see...",
			},
			# 21
			{
				"text": "The rest of the ride passes in silence.",
			},
			# 22
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Ah, this is my stop.",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "Alright.",
			},
			# 24
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Thank you for the ride, John.",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "You're welcome.",
			},
			# 26
			{
				"text": "She pays the fare and steps out of the tricycle.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 27 — LIE
			{
				"speaker": "John Toda",
				"text": "I don't know.",
				"actions": [
					StoryConstants.DRIVING_CHILL_MUSIC,
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_answer",
						"value": "lie",
					},
					{
						"type": "unlock_achievement",
						"id": "sinungaling",
					},
				],
			},
			# 28
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Oh? How come?",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "I haven't seen him in a long time either.",
			},
			# 30
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Oh, I see...",
			},
			# 31
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Well, I hope he's doing alright.",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "Yeah.",
			},
			# 33
			{
				"text": "The conversation ends there, and I continue driving.",
			},
			# 34
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Ah, this is my stop.",
			},
			# 35
			{
				"speaker": "John Toda",
				"text": "Alright.",
			},
			# 36
			{
				"speaker": "Elena",
				"speaker_display_name": "Elena",
				"text": "Thank you for the ride, John.",
			},
			# 37
			{
				"speaker": "John Toda",
				"text": "You're welcome.",
			},
			# 38
			{
				"text": "She pays the fare and steps out of the tricycle.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "elena_old_acquaintance_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
