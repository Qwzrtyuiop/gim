extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Sections 0/1 retain the scaffold entry/completion indices for existing saves.
# New encounters jump over the legacy completion and append the full scene.
const CONFRONTATION := 2
const DECISION := 37
const POLICE := 38
const WARNING := 52
const REVEAL_NAME := 63
const STORY_END := 74


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "jessa_second_encounter",
		"chapter_title": "A Familiar Passenger",
		"speaker_portraits": true,
		"return_scene": "res://scenes/ride_selection.tscn",
		"next_scene": "res://scenes/ride_selection.tscn",
		"background": StoryConstants.BACKGROUND_TERMINAL_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_TERMINAL,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"speaker": "John Toda",
				"text": "Hey, aren't you—",
				"next_index": CONFRONTATION,
			},
			# 1 - Legacy completion; new branches finish on their own final dialogue.
			{
				"speaker": "Jessa",
				"text": "...",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_second_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 2 - CONFRONTATION
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Oh, crap!",
			},
			# 3
			{
				"text": "Before she can get away, I rush over and cut her off.",
			},
			# 4
			{
				"text": "She tries to run anyway, so I grab her by the wrist.",
			},
			# 5
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Ungh!",
			},
			# 6
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Let go!",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "Only if you promise not to run away.",
			},
			# 8
			{
				"text": "She tries to pry my hand off, but eventually gives up.",
			},
			# 9
			{
				"text": "After a moment, she nods.",
			},
			# 10
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Fine.",
			},
			# 11
			{
				"text": "I let go of her wrist. Her arm is surprisingly thin beneath those thick sleeves.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "So...",
			},
			# 13
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "So what?",
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
			# 14
			{
				"speaker": "John Toda",
				"text": "Why did you do it?",
			},
			# 15
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Do what?",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "You know what I mean.",
			},
			# 17
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "No, I don't.",
			},
			# 18
			{
				"text": "I let out a sigh.",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "The fare. Why did you run away without paying?",
			},
			# 20
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "I was short on cash.",
			},
			# 21
			{
				"text": "She answers immediately, almost as if she'd been expecting that question.",
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "Well, do you have the money now?",
			},
			# 24
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Nope. Still broke, you see...",
			},
			# 25
			{
				"text": "She pulls out her wallet and opens it in front of me.",
				"portraits": [
					{
						"id": "jessa_wallet",
						"texture": StoryConstants.ITEM_JESSA_WALLET,
						"position": "center",
						"height": 360,
					},
				],
			},
			# 26
			{
				"text": "A few coins and a candy wrapper.",
				"speaker_portraits": false,
			},
			# 27
			{
				"text": "That's all.",
				"speaker_portraits": false,
			},
			# 28
			{
				"speaker": "John Toda",
				"text": "Then what about your parents?",
				"speaker_portraits": false,
			},
			# 29
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "I don't have parents.",
				"speaker_portraits": true,
				"actions": [
					{
						"type": "stop_music",
						"fade_out": 0.0,
					},
				],
			},
			# 30
			{
				"speaker": "John Toda",
				"text": "Oh...",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "Any guardians, then?",
			},
			# 33
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Nope.",
			},
			# 34
			{
				"text": "Haaah...",
			},
			# 35
			{
				"text": "I'm out of ideas.",
			},
			# 36
			{
				"text": "She's either lying, or she really doesn't have anyone.",
			},
			# 37 - DECISION
			{
				"text": "What am I supposed to do with her?",
				"choices": [
					{
						"text": "Threaten to take her to the police.",
						"next_index": POLICE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "jessa_second_encounter_choice",
								"value": "police",
							},
						],
					},
					{
						"text": "Let her off with a warning.",
						"next_index": WARNING,
						"actions": [
							{
								"type": "set_event_value",
								"id": "jessa_second_encounter_choice",
								"value": "warning",
							},
						],
					},
				],
			},
			# 38 - POLICE
			{
				"speaker": "John Toda",
				"text": "Then how about we go to the police station? Maybe they can help you.",
			},
			# 39
			{
				"text": "Her expression immediately darkens.",
			},
			# 40
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 41
			{
				"text": "Without warning, she kicks me straight in the shin.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.SFX_HIT,
						"volume_db": -8.0,
					},
				],
			},
			# 42
			{
				"speaker": "John Toda",
				"text": "OW!",
			},
			# 43
			{
				"text": "WHAT THE—?!",
			},
			# 44
			{
				"text": "The kick hurts so much that, for a moment, I genuinely think she broke something.",
			},
			# 45
			{
				"speaker": "John Toda",
				"text": "You little—!",
			},
			# 46
			{
				"text": "But by the time I look up, she's already running away.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"loop": false,
						"volume_db": -4.0,
					},
				],
			},
			# 47
			{
				"speaker": "John Toda",
				"text": "HEY! GET BACK HERE!",
			},
			# 48
			{
				"text": "She's gone.",
			},
			# 49
			{
				"text": "Again.",
			},
			# 50
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 51
			{
				"speaker": "John Toda",
				"text": "Not again...",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_second_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 52 - WARNING
			{
				"speaker": "John Toda",
				"text": "Fine. But promise me you won't do that again. Not to me, not to any other driver.",
			},
			# 53
			{
				"text": "She'll probably do it again anyway, but...",
			},
			# 54
			{
				"text": "I'm out of ideas.",
			},
			# 55
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Huh?",
			},
			# 56
			{
				"speaker": "John Toda",
				"text": "What?",
			},
			# 57
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "That's it?",
			},
			# 58
			{
				"speaker": "John Toda",
				"text": "What do you mean, 'that's it'?",
			},
			# 59
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "That's so stupid. I could just say yes and do it again.",
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "You little—",
			},
			# 61
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Then I'll give you my name.",
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_FUNNY,
						"loop": true,
						"restart": true,
						"fade_in": 0.0,
						"fade_out": 0.0,
						"volume_db": -9.0,
					},
				],
			},
			# 62
			{
				"speaker": "John Toda",
				"text": "Huh?",
			},
			# 63 - REVEAL_NAME
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Jessa. Just Jessa.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_name_revealed",
						"value": true,
					},
				],
			},
			# 64
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 65
			{
				"speaker": "Jessa",
				"speaker_display_name": "Jessa",
				"text": "Some people around here know me. So if you ever catch me doing it again, you can tell everyone it was me.",
			},
			# 66
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 67
			{
				"text": "What kind of logic is that?",
			},
			# 68
			{
				"text": "She turns around and runs off, waving goodbye as though she hadn't done anything wrong in the first place.",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"loop": false,
						"volume_db": -4.0,
					},
				],
			},
			# 69
			{
				"speaker": "Jessa",
				"speaker_display_name": "Jessa",
				"text": "Bye now!",
			},
			# 70
			{
				"speaker": "John Toda",
				"text": "Hey, I didn't say you could—",
			},
			# 71
			{
				"speaker": "Jessa",
				"speaker_display_name": "Jessa",
				"text": "I'll pay properly next time!",
			},
			# 72
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 73
			{
				"speaker": "John Toda",
				"text": "What a weird kid.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "jessa_second_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
