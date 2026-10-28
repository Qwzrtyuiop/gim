extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Append future sections to preserve saved indices.


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "celina_hospital_introduction",
		"chapter_title": "A Familiar Face",
		"speaker_portraits": true,
		"return_scene": "res://scenes/day_start_scene.tscn",
		"next_scene": "res://scenes/day_start_scene.tscn",
		"background": StoryConstants.hospital_background(PlayerState.get_current_time_of_day()),
		"music": {},
		"ambient_sfx": {
			"loop": true,
			"path": StoryConstants.SFX_HOSPITAL_AMBIENCE,
			"volume_db": -14.0,
		},
		"composition": [
			# 0
			{
				"text": "I recognize a familiar face behind the hospital counter.",
			},
			# 1
			{
				"text": "Oh.",
			},
			# 2
			{
				"text": "It's the girl who gave me that bandage.",
			},
			# 3
			{
				"text": "She seems busy handling some paperwork. I approach the counter.",
			},
			# 4
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Hello. How can I help you?",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Hey, miss.",
			},
			# 6
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Hm?",
			},
			# 7
			{
				"text": "She recognizes me.",
			},
			# 8
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Oh, it's you. The tricycle driver.",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "Yeah. That's me.",
			},
			# 10
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "What brings you here? Do you need something?",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Well, actually...",
			},
			# 12
			{
				"text": "I glance at the papers scattered across the counter.",
			},
			# 13
			{
				"speaker": "John Toda",
				"text": "I thought you were a nurse. You work the counter too?",
			},
			# 14
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Oh, that. We're a little understaffed right now, so I help out wherever they need me.",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "Oh.",
			},
			# 16
			{
				"text": "Sounds like a lot of work.",
			},
			# 17
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Anyway, did you need anything?",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "I, uh...",
			},
			# 19
			{
				"text": "Right.",
			},
			# 20
			{
				"text": "Why did I come here again?",
			},
			# 21
			{
				"speaker": "John Toda",
				"text": "I don't know.",
			},
			# 22
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "You don't know?",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "Yeah. I guess I just felt like dropping by.",
			},
			# 24
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "For no particular reason.",
			},
			# 26
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Is that so?",
			},
			# 27
			{
				"text": "She lets out a quiet laugh.",
			},
			# 28
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "You're a funny guy.",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "Am I?",
			},
			# 30
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Mhm.",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 32
			{
				"text": "I wasn't trying to be.",
			},
			# 33
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Oh, I never introduced myself, did I?",
			},
			# 34 - NAME REVEAL
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "I'm Celina.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_name_revealed",
						"value": true,
					},
				],
			},
			# 35
			{
				"speaker": "John Toda",
				"text": "John. John Toda.",
			},
			# 36
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "Nice to meet you, John.",
			},
			# 37
			{
				"speaker": "John Toda",
				"text": "Nice to meet you too.",
			},
			# 38
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "Well, I'd love to chat some more, but I still have work to do.",
			},
			# 39
			{
				"speaker": "John Toda",
				"text": "Ah, right. Sorry for bothering you.",
			},
			# 40
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "It's alright.",
			},
			# 41
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "If you ever need to buy some medicine, feel free to visit again.",
			},
			# 42
			{
				"speaker": "John Toda",
				"text": "Sure. Thanks.",
			},
			# 43
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "Take care, John.",
			},
			# 44 - COMPLETE
			{
				"text": "I leave the counter and head for the exit.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_hospital_introduction_seen",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "celina_hospital_shop_unlocked",
						"value": true,
					},
				],
			},
		],
	})

