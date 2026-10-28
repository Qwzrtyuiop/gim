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
				"text": "I spotted Benny near the construction site, talking to one of the workers.",
			},
			# 1
			{
				"speaker": "Benny",
				"text": "Oh, John! What brings you here?",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Nothing much. Just passing by.",
			},
			# 3
			{
				"speaker": "Benny",
				"text": "Passing by, huh? Well, good timing. I was actually hoping to run into you.",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "Hm? Why?",
			},
			# 5
			{
				"speaker": "Benny",
				"text": "Well, I heard something from the guys back home.",
			},
			# 6
			{
				"speaker": "John Toda",
				"text": "About?",
			},
			# 7
			{
				"speaker": "Benny",
				"text": "That you're in debt. Is that true?",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 9
			{
				"text": "So the rumors have already reached him.",
			},
			# 10 - HONEST
			{
				"speaker": "John Toda",
				"text": "Yeah. It's true.",
				"conditions": {
					"required_achievements": ["tapat"],
					"forbidden_achievements": ["sinungaling"],
				},
				"skip_index": DENY,
			},
			# 11
			{
				"speaker": "Benny",
				"text": "I see...",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "It's a long story.",
			},
			# 13
			{
				"speaker": "Benny",
				"text": "Well, you don't have to tell me if you don't want to.",
			},
			# 14
			{
				"text": "He scratched his head.",
			},
			# 15
			{
				"speaker": "Benny",
				"text": "Actually, this might work out pretty well.",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "What do you mean?",
				"next_index": COMMON,
			},
			# 17 - DENY
			{
				"speaker": "John Toda",
				"text": "No, nothing like that. Things have just been a little rough lately.",
			},
			# 18
			{
				"speaker": "Benny",
				"text": "Is that so...",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "Yeah. You know how it is.",
			},
			# 20
			{
				"speaker": "Benny",
				"text": "Well, I guess everyone's got their own problems.",
			},
			# 21
			{
				"text": "And I certainly had mine.",
			},
			# 22
			{
				"speaker": "Benny",
				"text": "Anyway, since you're here, there's something I wanted to ask you.",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "What is it?",
			},
			# 24 - COMMON
			{
				"speaker": "Benny",
				"text": "One of our workers got injured recently, so we're a little short-handed.",
			},
			# 25
			{
				"speaker": "Benny",
				"text": "I could use an extra pair of hands around here. Nothing too complicated, just helping out with the construction.",
			},
			# 26
			{
				"speaker": "John Toda",
				"text": "Me?",
			},
			# 27
			{
				"speaker": "Benny",
				"text": "Who else?",
			},
			# 28
			{
				"speaker": "John Toda",
				"text": "I don't exactly have any experience with construction.",
			},
			# 29
			{
				"speaker": "Benny",
				"text": "It's fine. I'll show you what to do. Besides, we could always use someone to carry things around.",
			},
			# 30
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 31
			{
				"speaker": "Benny",
				"text": "Of course, I'll pay you for the work. I'll even throw in a little extra.",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "Extra?",
			},
			# 33
			{
				"speaker": "Benny",
				"text": "Yeah. Well, it's probably a little unfair to the other workers...",
			},
			# 34
			{
				"text": "He gave a small laugh.",
			},
			# 35
			{
				"speaker": "Benny",
				"text": "But we've known each other since we were kids, haven't we? I think helping an old friend this much should be fine.",
			},
			# 36
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 37
			{
				"text": "He really just offered me a job.",
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "Are you sure about that?",
			},
			# 39
			{
				"speaker": "Benny",
				"text": "Of course. I'm the foreman here, remember?",
			},
			# 40
			{
				"speaker": "John Toda",
				"text": "Right...",
			},
			# 41
			{
				"text": "I wasn't expecting this when I came here.",
			},
			# 42
			{
				"speaker": "John Toda",
				"text": "Well, I'll think about it.",
			},
			# 43
			{
				"speaker": "Benny",
				"text": "Sure. No rush.",
			},
			# 44
			{
				"speaker": "Benny",
				"text": "Just come by whenever you've got some free time. I'll find something for you to do.",
			},
			# 45
			{
				"speaker": "John Toda",
				"text": "Alright. Thanks, Benny.",
			},
			# 46
			{
				"speaker": "Benny",
				"text": "Don't mention it. That's what friends are for, right?",
			},
			# 47
			{
				"speaker": "John Toda",
				"text": "Yeah.",
			},
			# 48
			{
				"text": "Friends, huh.",
			},
			# 49
			{
				"text": "It's been a while since anyone's offered me work.",
			},
			# 50
			{
				"text": "And here I was, just passing by.",
			},
			# 51
			{
				"text": "Unlocked: Construction Work.",
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
