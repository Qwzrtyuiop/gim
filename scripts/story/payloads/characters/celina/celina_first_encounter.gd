extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Keep the old completion index at 1 for saved placeholder encounters.
const INTRODUCTION := 2
const ACCEPT := 33
const REFUSE := 48
const STORY_END := 78


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "celina_first_encounter",
		"chapter_title": "Just a Scratch",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0 - Entry; skip the legacy completion section.
			{
				"text": "Throughout the ride, I noticed my passenger taking occasional glances at me.",
				"next_index": INTRODUCTION,
			},
			# 1 - Legacy completion for saved placeholder encounters.
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "...",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 2 - INTRODUCTION
			{
				"text": "At first, I thought nothing of it. But after catching her looking my way for the third time, I began to wonder.",
			},
			# 3
			{
				"text": "Is there something on my face?",
			},
			# 4
			{
				"text": "I checked the rearview mirror.",
			},
			# 5
			{
				"text": "I don't think there's a problem with my face.",
			},
			# 6
			{
				"text": "I think...",
			},
			# 7
			{
				"text": "Eventually, we arrived at her destination.",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "Here we are, miss.",
			},
			# 9
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Umm...",
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "Hm? What is it?",
			},
			# 11
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "What happened to your hand?",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "My hand?",
			},
			# 13
			{
				"text": "I looked down at the hand resting on the handlebar.",
			},
			# 14
			{
				"text": "There was a small cut across my knuckles, with a thin trail of dried blood running toward my wrist.",
			},
			# 15
			{
				"text": "Huh. When did that happen?",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "Oh, this?",
			},
			# 17
			{
				"text": "I rubbed the back of my hand with my thumb.",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "Didn't even notice it. It's just a scratch.",
			},
			# 19
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "That doesn't look like a scratch.",
			},
			# 20
			{
				"speaker": "John Toda",
				"text": "Well, it's not like I'm dying.",
			},
			# 21
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 22
			{
				"text": "She frowned.",
			},
			# 23
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "It could still get infected, you know?",
			},
			# 24
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Dirt and bacteria can get inside if you leave it like that. Especially when you're driving around all day.",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "Uh-huh...",
			},
			# 26
			{
				"text": "Why is she so concerned?",
			},
			# 27
			{
				"text": "Do I know her?",
			},
			# 28
			{
				"text": "I tried remembering whether I'd driven her somewhere before. Her face was somewhat familiar, but that was about it.",
			},
			# 29
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Anyway, just take this for now.",
			},
			# 30
			{
				"text": "She opened her bag and took out a small adhesive bandage.",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "Oh.",
			},
			# 32 - DECISION
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Here.",
				"choices": [
					{
						"text": "Accept the bandage",
						"next_index": ACCEPT,
					},
					{
						"text": "Refuse politely",
						"next_index": REFUSE,
					},
				],
			},
			# 33 - ACCEPT
			{
				"speaker": "John Toda",
				"text": "Ah... Thanks.",
			},
			# 34
			{
				"text": "I took the bandage from her.",
			},
			# 35
			{
				"text": "Peeling the wrapper open, I found myself staring at a tiny pink bandage decorated with cartoon rabbits.",
			},
			# 36
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 37
			{
				"text": "Cute.",
			},
			# 38
			{
				"text": "I wasn't sure what I was expecting, but it certainly wasn't this.",
			},
			# 39
			{
				"text": "I stuck it over the cut and flexed my fingers a few times.",
			},
			# 40 - Bandage close-up.
			{
				"text": "...",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "rabbit_bandaid",
						"texture": StoryConstants.ITEM_RABBIT_BANDAID,
						"position": "center",
						"height": 420,
					},
				],
			},
			# 41
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "There. That's better.",
				"speaker_portraits": false,
			},
			# 42
			{
				"speaker": "John Toda",
				"text": "Yeah. Thanks again, miss.",
				"speaker_portraits": true,
			},
			# 43
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "You're welcome.",
			},
			# 44
			{
				"text": "She paid her fare and got off the tricycle.",
			},
			# 45
			{
				"text": "I took another look at my hand.",
			},
			# 46
			{
				"text": "Well, at least the rabbits seem happy about it.",
			},
			# 47 - ACCEPT COMPLETE
			{
				"text": "I started the engine and headed back to the station.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 48 - REFUSE
			{
				"speaker": "John Toda",
				"text": "Ah, no. It's fine, miss.",
			},
			# 49
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Are you sure?",
			},
			# 50
			{
				"speaker": "John Toda",
				"text": "Yeah. Really. It's just a little cut.",
			},
			# 51
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 52
			{
				"speaker": "John Toda",
				"text": "Besides, it'd be a waste of your bandage.",
			},
			# 53
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "It's one bandage.",
			},
			# 54
			{
				"speaker": "John Toda",
				"text": "Well, still—",
			},
			# 55
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Give me your hand.",
			},
			# 56
			{
				"speaker": "John Toda",
				"text": "Huh?",
			},
			# 57
			{
				"text": "Out of nowhere, she took my hand and began sticking the bandage.",
			},
			# 58
			{
				"speaker": "John Toda",
				"text": "Wait, miss. I said I'm fine—",
			},
			# 59
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "I've had patients more stubborn than you.",
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "Patients?",
			},
			# 61
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Hold still.",
			},
			# 62
			{
				"text": "She pressed the bandage firmly over my knuckles.",
			},
			# 63 - Bandage close-up.
			{
				"text": "...",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "rabbit_bandaid",
						"texture": StoryConstants.ITEM_RABBIT_BANDAID,
						"position": "center",
						"height": 420,
					},
				],
			},
			# 64
			{
				"speaker": "John Toda",
				"text": "...",
				"speaker_portraits": false,
			},
			# 65
			{
				"text": "Rabbits?",
				"speaker_portraits": false,
			},
			# 66
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "There. All done.",
				"speaker_portraits": true,
			},
			# 67
			{
				"text": "She released my hand and reached for her fare.",
			},
			# 68
			{
				"speaker": "John Toda",
				"text": "You know, I could've done that myself.",
			},
			# 69
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "You would've just put it in your pocket and forgotten about it.",
			},
			# 70
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 71
			{
				"text": "Fair enough.",
			},
			# 72
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "Anyway, thank you for the ride.",
			},
			# 73
			{
				"text": "She handed me the fare and left.",
			},
			# 74
			{
				"text": "I examined the bandage on my hand.",
			},
			# 75
			{
				"text": "She didn't even give me a chance to argue.",
			},
			# 76
			{
				"text": "And what's with the rabbits?",
			},
			# 77 - REFUSE COMPLETE
			{
				"text": "I started the engine and headed back to the station.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_first_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
