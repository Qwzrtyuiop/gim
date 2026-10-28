extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

const DECISION := 48
const ACCEPT := 49
const REFUSE := 65
const COMMON := 84
const STORY_END := 118


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "alma_special_delivery",
		"chapter_title": "Special Delivery",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.BACKGROUND_BAR,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_BAR,
			"loop": true,
			"fade_in": 0.35,
			"volume_db": -9.0,
		},
		"ambient_sfx": {
			"path": StoryConstants.MUSIC_BAR_SFX,
			"loop": true,
			"volume_db": -14.0,
		},
		"composition": [
			# 0
			{
				"text": "I enter the bar and head toward the counter, as usual.",
			},
			# 1
			{
				"speaker": "Alma",
				"text": "...",
			},
			# 2
			{
				"speaker": "Alma",
				"text": ".....",
			},
			# 3
			{
				"text": "She's busy staring at her phone.",
			},
			# 4
			{
				"speaker": "Alma",
				"text": "Ugh. This is a problem.",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Hey, Alma.",
			},
			# 6
			{
				"speaker": "Alma",
				"text": "...",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "Alma?",
			},
			# 8
			{
				"speaker": "Alma",
				"text": "What am I supposed to do now...",
			},
			# 9
			{
				"text": "Is she ignoring me?",
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "Hello?",
			},
			# 11
			{
				"speaker": "Alma",
				"text": "Wah!",
			},
			# 12
			{
				"text": "She nearly drops her phone.",
			},
			# 13
			{
				"speaker": "Alma",
				"text": "Oh, John! You scared me!",
			},
			# 14
			{
				"speaker": "John Toda",
				"text": "I've been standing here for a while.",
			},
			# 15
			{
				"speaker": "Alma",
				"text": "Sorry, sorry. I was distracted.",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "I noticed.",
			},
			# 17
			{
				"speaker": "Alma",
				"text": "Ugh. Seriously, what am I going to do?",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "What's wrong?",
			},
			# 19
			{
				"speaker": "Alma",
				"text": "Well, you see...",
			},
			# 20
			{
				"text": "She puts her phone down on the counter.",
			},
			# 21
			{
				"speaker": "Alma",
				"text": "Our manager forgot to pick up a delivery earlier.",
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "A delivery?",
			},
			# 23
			{
				"speaker": "Alma",
				"text": "Yeah. A whole case of special beer. Apparently, some workers from a big company reserved it for tonight.",
			},
			# 24
			{
				"speaker": "Alma",
				"text": "They ordered a bunch of other stuff too, but that particular beer was supposed to be the highlight.",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "So?",
			},
			# 26
			{
				"speaker": "Alma",
				"text": "So they're coming here any minute now, and we don't have the beer!",
			},
			# 27
			{
				"speaker": "John Toda",
				"text": "Oh.",
			},
			# 28
			{
				"speaker": "Alma",
				"text": "And the delivery trucks have already left for the night. We called the distributor, but they said we'll have to pick it up ourselves.",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "Can't your manager go get it?",
			},
			# 30
			{
				"speaker": "Alma",
				"text": "He's busy getting everything ready for the customers. Besides, it's his fault we're in this mess in the first place.",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "I see.",
			},
			# 32
			{
				"text": "Sounds like a management problem.",
			},
			# 33
			{
				"speaker": "Alma",
				"text": "...",
			},
			# 34
			{
				"speaker": "Alma",
				"text": "Wait.",
			},
			# 35
			{
				"text": "She stares at me.",
			},
			# 36
			{
				"text": "I don't like where this is going.",
			},
			# 37
			{
				"speaker": "Alma",
				"text": "John.",
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_FUNNY_2,
						"loop": true,
						"fade_in": 0.0,
						"fade_out": 0.0,
						"volume_db": -9.0,
					},
				],
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "What?",
			},
			# 39
			{
				"speaker": "Alma",
				"text": "You drive fast, right?",
			},
			# 40
			{
				"speaker": "John Toda",
				"text": "Only within the speed limit.",
			},
			# 41
			{
				"speaker": "Alma",
				"text": "Great!",
			},
			# 42
			{
				"text": "She didn't even listen.",
			},
			# 43
			{
				"speaker": "Alma",
				"text": "Can you do me a favor? I need someone to pick up that beer from the distribution hub and bring it back here.",
			},
			# 44
			{
				"speaker": "John Toda",
				"text": "Me?",
			},
			# 45
			{
				"speaker": "Alma",
				"text": "Well, you're a tricycle driver, aren't you?",
			},
			# 46
			{
				"speaker": "John Toda",
				"text": "That doesn't mean I'm a delivery service.",
			},
			# 47
			{
				"speaker": "Alma",
				"text": "Please? It's not that far! We just need to get there before they close up.",
			},
			# 48 - DECISION
			{
				"speaker": "John Toda",
				"text": "...",
				"choices": [
					{
						"text": "Accept",
						"next_index": ACCEPT,
						"actions": [
							{
								"type": "set_event_value",
								"id": "alma_delivery_initial_choice",
								"value": "accept",
							},
						],
					},
					{
						"text": "Refuse",
						"next_index": REFUSE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "alma_delivery_initial_choice",
								"value": "refuse",
							},
						],
					},
				],
			},
			# 49 - ACCEPT
			{
				"speaker": "John Toda",
				"text": "Alright, fine. I'll do it.",
			},
			# 50
			{
				"speaker": "Alma",
				"text": "Really!?",
			},
			# 51
			{
				"speaker": "John Toda",
				"text": "As long as you're paying.",
			},
			# 52
			{
				"speaker": "Alma",
				"text": "Of course! I'll pay you double the usual fare!",
			},
			# 53
			{
				"speaker": "John Toda",
				"text": "Double, huh...",
			},
			# 54
			{
				"text": "That's not a bad deal.",
			},
			# 55
			{
				"speaker": "Alma",
				"text": "Oh, and I'll throw in something extra, too!",
			},
			# 56
			{
				"speaker": "John Toda",
				"text": "Extra?",
			},
			# 57
			{
				"speaker": "Alma",
				"text": "A ten percent discount on anything you buy here! How's that?",
			},
			# 58
			{
				"speaker": "John Toda",
				"text": "Are you even allowed to do that?",
			},
			# 59
			{
				"speaker": "Alma",
				"text": "I'll figure something out.",
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 61
			{
				"text": "That's reassuring.",
			},
			# 62
			{
				"speaker": "Alma",
				"text": "Anyway, thank you so much, John! You're a lifesaver!",
			},
			# 63
			{
				"speaker": "John Toda",
				"text": "Don't thank me yet. We haven't even gotten the beer.",
			},
			# 64
			{
				"speaker": "Alma",
				"text": "Right! Then we'd better hurry!",
				"next_index": COMMON,
			},
			# 65 - REFUSE
			{
				"speaker": "John Toda",
				"text": "Sorry, Alma. I don't think I can.",
			},
			# 66
			{
				"speaker": "Alma",
				"text": "Eh? Why not?",
			},
			# 67
			{
				"speaker": "John Toda",
				"text": "I'm not really interested in doing deliveries.",
			},
			# 68
			{
				"speaker": "Alma",
				"text": "Come on! Just this once!",
			},
			# 69
			{
				"speaker": "John Toda",
				"text": "I don't know...",
			},
			# 70
			{
				"speaker": "Alma",
				"text": "I'll pay you!",
			},
			# 71
			{
				"speaker": "John Toda",
				"text": "That's not really—",
			},
			# 72
			{
				"speaker": "Alma",
				"text": "Double!",
			},
			# 73
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 74
			{
				"speaker": "Alma",
				"text": "Double the usual fare! How about that?",
			},
			# 75
			{
				"speaker": "John Toda",
				"text": "You're really not giving me a choice, are you?",
			},
			# 76
			{
				"speaker": "Alma",
				"text": "Please, John! I'm begging you!",
			},
			# 77
			{
				"text": "...",
			},
			# 78
			{
				"text": "Well, I could use the money.",
			},
			# 79
			{
				"speaker": "John Toda",
				"text": "Alright, alright. I'll do it.",
			},
			# 80
			{
				"speaker": "Alma",
				"text": "Yes! Thank you!",
			},
			# 81
			{
				"speaker": "John Toda",
				"text": "But just this once, okay?",
			},
			# 82
			{
				"speaker": "Alma",
				"text": "Of course!",
			},
			# 83
			{
				"text": "Somehow, I doubt that.",
				"next_index": COMMON,
			},
			# 84 - COMMON
			{
				"speaker": "Alma",
				"text": "Oh, right! Before we go...",
			},
			# 85
			{
				"text": "She reaches beneath the counter and pulls out a can of energy drink.",
			},
			# 86
			{
				"speaker": "Alma",
				"text": "Here, take this. It'll help you out.",
			},
			# 87
			{
				"speaker": "John Toda",
				"text": "An energy drink?",
			},
			# 88
			{
				"speaker": "Alma",
				"text": "Mhm! You're going to need it.",
			},
			# 89
			{
				"speaker": "John Toda",
				"text": "Are we really that short on time?",
			},
			# 90
			{
				"speaker": "Alma",
				"text": "Well...",
			},
			# 91
			{
				"text": "She checks her phone.",
			},
			# 92
			{
				"speaker": "Alma",
				"text": "Very.",
			},
			# 93
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 94
			{
				"text": "Great.",
			},
			# 95
			{
				"text": "I take the can and drink it.",
				"actions": [
					{
						"type": "relieve_stress",
						"amount": 10,
					},
				],
			},
			# 96
			{
				"speaker": "Alma",
				"text": "Alright! Let's get going!",
			},
			# 97
			{
				"speaker": "John Toda",
				"text": "Wait, you're coming too?",
			},
			# 98
			{
				"speaker": "Alma",
				"text": "Of course! Someone has to make sure they give us the right beer.",
			},
			# 99
			{
				"speaker": "John Toda",
				"text": "And what about the bar?",
			},
			# 100
			{
				"speaker": "Alma",
				"text": "The others can handle it until we get back.",
			},
			# 101
			{
				"speaker": "John Toda",
				"text": "I see.",
			},
			# 102
			{
				"text": "Well, at least I won't have to carry everything myself.",
			},
			# 103
			{
				"speaker": "Alma",
				"text": "Oh, wait! One more thing.",
			},
			# 104
			{
				"text": "She stops and pulls something out from behind the counter.",
				"background": StoryConstants.CG_ALMA_HORN,
				"background_fade": 0.28,
			},
			# 105
			{
				"speaker": "John Toda",
				"text": "What's that?",
			},
			# 106
			{
				"speaker": "Alma",
				"text": "A truck horn.",
			},
			# 107
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 108
			{
				"speaker": "John Toda",
				"text": "Why are you bringing a truck horn?",
			},
			# 109
			{
				"speaker": "Alma",
				"text": "Trust me. We'll need it.",
			},
			# 110
			{
				"speaker": "John Toda",
				"text": "Isn't that illegal?",
			},
			# 111
			{
				"speaker": "Alma",
				"text": "Missing an important order is more illegal.",
			},
			# 112
			{
				"speaker": "John Toda",
				"text": "Uh...",
			},
			# 113
			{
				"text": "That's not how the law works.",
			},
			# 114
			{
				"text": "She takes the horn with her and heads toward the exit.",
				"background": StoryConstants.BACKGROUND_BAR,
				"background_fade": 0.28,
			},
			# 115
			{
				"speaker": "Alma",
				"text": "Come on, John! We don't have all night!",
			},
			# 116
			{
				"speaker": "John Toda",
				"text": "Right...",
			},
			# 117
			{
				"text": "I hope we don't get caught for this.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_special_delivery_started",
						"value": true,
					},
					{
						"type": "start_special_stage",
						"id": "alma_special_delivery",
					},
				],
			},
		],
	})
