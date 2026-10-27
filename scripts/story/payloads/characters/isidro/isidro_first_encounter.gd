extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based branch targets; append future branches to preserve saved indices.
const NAME_REVEAL := 21
const DECISION := 28
const PAY_BRIBE := 29
const BRIBE_COUNTS_MONEY := 35
const PAY_FINE := 50
const LOW_CASH := 83
const STORY_END := 84


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "isidro_first_encounter",
		"chapter_title": "First Warning",
		"speaker_portraits": true,
		"return_scene": "res://scenes/main.tscn",
		"next_scene": "res://scenes/main.tscn",
		"driving_outcome": "end_without_fare",
		"background": StoryConstants.street_background(PlayerState.get_current_time_of_day()),
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "As I'm driving, the passenger suddenly leans forward and speaks.",
			},
			# 1
			{
				"speaker": "Isidro",
				"speaker_display_name": "???",
				"text": "Stop the vehicle. Right now.",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Huh? But we're not at your destination yet.",
			},
			# 3
			{
				"speaker": "Isidro",
				"speaker_display_name": "???",
				"text": "I said stop right here.",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "Uh... Okay.",
			},
			# 5
			{
				"text": "I pull over and park my tricycle at the side of the road.",
			},
			# 6
			{
				"speaker": "John Toda",
				"text": "That'll be—",
			},
			# 7
			{
				"speaker": "Isidro",
				"speaker_display_name": "???",
				"text": "You're quite the reckless driver, aren't you?",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "What?",
			},
			# 9
			{
				"text": "Now that I look at him more closely, he seems to be wearing a police uniform.",
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_MURDER,
						"loop": true,
						"fade_in": 0.0,
						"fade_out": 0.0,
						"volume_db": -9.0,
					},
				],
			},
			# 10
			{
				"text": "No, wait.",
			},
			# 11
			{
				"text": "He IS a policeman.",
			},
			# 12
			{
				"speaker": "Isidro",
				"speaker_display_name": "???",
				"text": "I said your driving is irresponsible.",
			},
			# 13
			{
				"speaker": "John Toda",
				"text": "Oh... Sorry about that.",
			},
			# 14
			{
				"text": "He pulls a badge from his pocket and flashes it in front of me.",
			},
			# 15
			{
				"speaker": "Isidro",
				"speaker_display_name": "???",
				"text": "Sorry isn't gonna cut it, kid. I could give you a fine right now.",
			},
			# 16
			{
				"text": "This is bad.",
			},
			# 17
			{
				"text": "I've already got my debt to worry about, and now this?",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "Please don't.",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "Sir.",
			},
			# 20
			{
				"text": "I glance at the name patch on his chest.",
			},
			# 21 - NAME_REVEAL
			{
				"text": "Isidro.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "isidro_name_revealed",
						"value": true,
					},
				],
			},
			# 22
			{
				"text": "The policeman lets out a rough sigh.",
			},
			# 23
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Listen, kid. I'm only gonna let you off this once.",
				"actions": [
					{
						"type": "stop_music",
						"fade_out": 0.0,
					},
				],
			},
			# 24
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "BUT...",
			},
			# 25
			{
				"text": "He holds out his hand, palm facing upward.",
			},
			# 26
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Instead of paying thousands for a fine, why don't you just give me a few hundred?",
			},
			# 27
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Saves us both the time and trouble.",
			},
			# 28 - DECISION
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "What do you think?",
				"choices": [
					{
						"text": "Pay Isidro ₱200.",
						"next_index": PAY_BRIBE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "isidro_first_encounter_choice",
								"value": "bribe",
							},
						],
					},
					{
						"text": "Pay the fine instead. (Requires ₱2,000)",
						"conditions": {
							"min_money": 2000,
						},
						"show_locked": true,
						"locked_reason": "Requires ₱2,000.",
						"next_index": PAY_FINE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "isidro_first_encounter_choice",
								"value": "fine",
							},
						],
					},
				],
			},
			# 29 - PAY_BRIBE
			{
				"text": "I can't afford the fine.",
			},
			# 30
			{
				"text": "I might as well give him the money and get this over with.",
			},
			# 31
			{
				"text": "What a corrupt cop.",
			},
			# 32
			{
				"text": "Then again, it's not like I'm a model citizen either.",
			},
			# 33
			{
				"speaker": "John Toda",
				"text": "Here's your money, sir.",
			},
			# 34
			{
				"text": "I hand him two hundred pesos.",
				"conditions": {
					"min_money": 200,
				},
				"actions": [
					{
						"type": "change_resource",
						"resource": "money",
						"amount": -200,
					},
				],
				"skip_index": LOW_CASH,
			},
			# 35 - BRIBE_COUNTS_MONEY
			{
				"text": "Isidro takes the money and counts it.",
			},
			# 36
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Hm. Good enough.",
			},
			# 37
			{
				"text": "He slips the money into his pocket.",
			},
			# 38
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Now, I'll be keeping a close eye on you, alright?",
			},
			# 39
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 40
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "If I catch you again, you'd better have more than this.",
			},
			# 41
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Or else...",
			},
			# 42
			{
				"text": "He pulls out a traffic violation ticket and waves it in front of my face.",
			},
			# 43
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "You know how it goes.",
			},
			# 44
			{
				"text": "He gives me a pat on the shoulder before walking away.",
			},
			# 45
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "See you around, kid.",
			},
			# 46
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Oh, and safe driving!",
			},
			# 47
			{
				"text": "I watch him disappear down the street.",
			},
			# 48
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 49
			{
				"text": "What a pain.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "isidro_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 50 - PAY_FINE
			{
				"speaker": "John Toda",
				"text": "Then I'll just pay the fine.",
			},
			# 51
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "What?",
			},
			# 52
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "You'll take the fine?",
			},
			# 53
			{
				"speaker": "John Toda",
				"text": "I broke the law, didn't I?",
			},
			# 54
			{
				"text": "Isidro takes a step back, seemingly surprised by my answer.",
			},
			# 55
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Now, hold on a second, kid.",
			},
			# 56
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "That's a lot of money we're talking about.",
			},
			# 57
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Why throw away two thousand pesos when you can settle this with just two hundred?",
			},
			# 58
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "No fines. No violations.",
			},
			# 59
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 60
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Come on. I'm trying to help you here.",
			},
			# 61
			{
				"text": "Two thousand pesos...",
			},
			# 62
			{
				"text": "I still have my debts to pay.",
			},
			# 63
			{
				"text": "And it's not like paying the fine would make my situation any better.",
			},
			# 64
			{
				"text": "Maybe he's right.",
			},
			# 65
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 66
			{
				"speaker": "John Toda",
				"text": "Fine. Two hundred, then.",
			},
			# 67
			{
				"text": "I hand him the money.",
				"actions": [
					{
						"type": "change_resource",
						"resource": "money",
						"amount": -200,
					},
				],
			},
			# 68
			{
				"text": "Isidro takes it and counts the bills.",
			},
			# 69
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "See? Now isn't that easier than paying thousands?",
			},
			# 70
			{
				"text": "He slips the money into his pocket, followed by his badge.",
			},
			# 71
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Now, I'll be keeping a close eye on you, alright?",
			},
			# 72
			{
				"speaker": "John Toda",
				"text": "Yes, sir.",
			},
			# 73
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "You know, if some other cop caught you driving like that, you'd get a ticket immediately.",
			},
			# 74
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "Not me, though.",
			},
			# 75
			{
				"text": "He grins.",
			},
			# 76
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "I'm a much kinder cop than the rest of them, you see.",
			},
			# 77
			{
				"text": "He lets out a hearty laugh as he walks away.",
			},
			# 78
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "See you around, kid!",
			},
			# 79
			{
				"speaker": "Isidro",
				"speaker_display_name": "Isidro",
				"text": "And safe driving!",
			},
			# 80
			{
				"text": "I watch him walk away.",
			},
			# 81
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 82
			{
				"text": "Somehow, I don't feel particularly lucky.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "isidro_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 83 - LOW_CASH
			{
				"text": "I hand over what money I have left.",
				"actions": [
					{
						"type": "change_resource",
						"resource": "money",
						"amount": -200,
					},
				],
				"next_index": BRIBE_COUNTS_MONEY,
			},
		],
	})
