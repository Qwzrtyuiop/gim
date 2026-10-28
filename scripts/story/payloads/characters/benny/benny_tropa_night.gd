extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "benny_tropa_night",
		"chapter_title": "Tropa",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "I check the time on my phone before heading out.",
				"background": StoryConstants.BACKGROUND_INHOUSE,
				"background_fade": 0.28,
				"pause_before": 0.16,
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "Oh, right.",
			},
			# 2
			{
				"text": "I pull my wallet out of my pocket.",
			},
			# 3
			{
				"text": "I count the bills. A hundred, two hundred, three...",
			},
			# 4
			{
				"text": "...",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Still got loans to pay but still going out huh.",
			},
			# 6
			{
				"speaker": "John Toda",
				"text": "But...",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "Benny, Arvin, and Dylan.",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "It's been a long time since I last saw those three.",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "Better now than too late.",
			},
			# 10
			{
				"text": "...",
				"actions": [
					{
						"type": "set_background",
						"background": StoryConstants.BACKGROUND_STORYDOOR,
					},
					{
						"type": "wait",
						"duration": 0.5,
					},
					{
						"type": "fade_to_black",
						"duration": 0.15,
					},
					{
						"type": "set_background",
						"background": StoryConstants.BACKGROUND_INHOUSE,
					},
					{
						"type": "fade_from_black",
						"duration": 0.15,
					},
				],
			},
			# 11
			{
				"text": "I pick up my tricycle keys and head out.",
			},
			# 12
			{
				"text": "As I arrive, Benny is already standing at the entrance, waiting.",
				"background": StoryConstants.BACKGROUND_BAR_EXTERIOR_NIGHT,
				"background_fade": 0.28,
			},
			# 13
			{
				"text": "Turns out, the bar that he mentioned is the same one I used to go to.",
			},
			# 14
			{
				"speaker": "John Toda",
				"text": "Small world.",
			},
			# 15
			{
				"speaker": "Benny",
				"text": "Glad you made it.",
			},
			# 16
			{
				"speaker": "Benny",
				"text": "Almost thought you'd bail out.",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "Thought about it.",
			},
			# 18
			{
				"speaker": "Benny",
				"text": "That sounds like you alright.",
			},
			# 19
			{
				"text": "We wait outside for a bit. The dimming sun, eventually replaced by bright city lights.",
			},
			# 20
			{
				"text": "Arvin and Dylan arrive together.",
			},
			# 21
			{
				"speaker": "Arvin",
				"text": "No way! He's still alive!?",
			},
			# 22
			{
				"speaker": "Dylan",
				"text": "That's fifty pesos for me.",
			},
			# 23
			{
				"text": "Upon seeing us, they wave and run toward us.",
			},
			# 24
			{
				"speaker": "John Toda",
				"text": "I can't believe that's how you guys greet me.",
			},
			# 25
			{
				"text": "We head inside together.",
			},
			# 26
			{
				"text": "Inside, the first few minutes felt awkward.",
				"background": StoryConstants.BACKGROUND_BAR,
				"background_fade": 0.28,
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_BAR,
						"loop": true,
						"fade_in": 0.24,
						"volume_db": -9.0,
					},
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_BAR_SFX,
						"volume_db": -5.0,
					},
				],
			},
			# 27
			{
				"text": "Too many years. Too much catching up packed into small talk.",
			},
			# 28
			{
				"speaker": "Dylan",
				"text": "So… what have you been up to these past few years?",
			},
			# 29
			{
				"text": "...",
			},
			# 30
			{
				"speaker": "John Toda",
				"text": "Working.",
			},
			# 31
			{
				"speaker": "Arvin",
				"text": "Just working?",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "More or less.",
			},
			# 33
			{
				"text": "...",
			},
			# 34
			{
				"text": "Nobody pushes it",
			},
			# 35
			{
				"text": "Awkward silence fills the room.",
			},
			# 36
			{
				"text": "until",
			},
			# 37
			{
				"speaker": "Dylan",
				"text": "Oh c'mon don't be like that, just look at Ben Ten here. He looks like he has ten strands of hair left.",
			},
			# 38
			{
				"speaker": "Dylan",
				"text": "Do you want him to lose more?.",
			},
			# 39
			{
				"text": "And just like that, everyone laughed.",
			},
			# 40
			{
				"text": "Soon enough they start talking about their life. How it's been for them.",
				"background": StoryConstants.CG_TROPA,
				"background_fade": 0.45,
			},
			# 41
			{
				"text": "Work, old mistakes, money, and all the years in between.",
			},
			# 42
			{
				"text": "And then we were back. Laughing like we used to.",
			},
			# 43
			{
				"text": "Like we were still in school.",
			},
			# 44
			{
				"text": "Like no time passed at all.",
			},
			# 45
			{
				"text": "....",
			},
			# 46
			{
				"text": "Later, when we finally step outside, my face hurts a little from smiling.",
				"background": StoryConstants.BACKGROUND_BAR_EXTERIOR_NIGHT,
				"background_fade": 0.28,
			},
			# 47
			{
				"text": "In those few hours, it almost felt like nothing changed",
			},
			# 48
			{
				"text": "But it did.",
			},
			# 49
			{
				"text": "Achievement unlocked: Tropa",
				"actions": [
					{
						"type": "unlock_achievement",
						"id": "tropa",
					},
					{
						"type": "relieve_stress",
						"amount": 1,
					},
					{
						"type": "relieve_stress",
						"amount": 5,
					},
				],
			},
			# 50
			{
				"text": "Stress -6",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_tropa_seen",
						"value": 1,
					},
					{
						"type": "clear_pending_night_skip",
					},
				],
			},
		],
	})
