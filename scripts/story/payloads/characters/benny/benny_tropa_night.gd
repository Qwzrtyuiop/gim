extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")
const BACKGROUND_BAR := "res://assets/story/backgrounds/locations/bar.jpeg"
const TROPA_CG := "res://assets/story/specialCG/tropaCg.png"


static func build() -> Dictionary:
	return {
		"story_id": "benny_tropa_night",
		"speaker_portraits": true,
		"chapter_title": "Tropa",
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_CITY_AMBIENCE,
			"loop": true,
			"fade_in": 0.55,
			"volume_db": -9.0,
		},
		"composition": [
			{
				"background": StoryConstants.BACKGROUND_INHOUSE,
				"background_fade": 0.28,
				"pause_before": 0.16,
				"text": "I check the time on my phone before heading out.",
			},
			{
				"speaker": "John Toda",
				"text": "Oh, right.",
			},
			{
				"text": "I pull my wallet out of my pocket.",
			},
			{
				"text": "I count the bills. A hundred, two hundred, three...",
			},
			{
				"text": "...",
			},
			{
				"speaker":"John Toda",
				"text": "Still got loans to pay but still going out huh.",
			},
			{
				"speaker":"John Toda",
				"text": "But...",
			},
			{
				"speaker":"John Toda",
				"text": "Benny, Arvin, and Dylan.",
			},
			{
				"speaker":"John Toda",
				"text": "It's been a long time since I last saw those three.",
			},
			{
				"speaker":"John Toda",
				"text": "Better now than too late.",
			},
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
			{
				"text": "I pick up my tricycle keys and head out.",
			},
			{
				"background": StoryConstants.BACKGROUND_CITY,
				"background_fade": 0.28,
				"text": "As I arrive, Benny is already standing at the entrance, waiting.",
			},
			{
				"text": "Turns out, the bar that he mentioned is the same one I used to go to.",
			},
			{
				"speaker":"John Toda",
				"text": "Small world.",
			},
			{
				"speaker": "Benny",
				"text": "Glad you made it.",
			},
			{
				"speaker": "Benny",
				"text": "Almost thought you'd bail out.",
			},
			{
				"speaker": "John Toda",
				"text": "Thought about it.",
			},
			{
				"speaker": "Benny",
				"text": "That sounds like you alright.",
			},
			{
				"text": "We wait outside for a bit. The dimming sun, eventually replaced by bright city lights.",
			},
			{
				"text": "Arvin and Dylan arrive together.",
			},
			{
				"speaker": "Arvin",
				"text": "No way! He's still alive!?",
			},
			{
				"speaker": "Dylan",
				"text": "That's fifty pesos for me.",
			},
			{
				"text": "Upon seeing us, they wave and run toward us.",
			},
			{
				"speaker": "John Toda",
				"text": "I can't believe that's how you guys greet me.",
			},
		
			{
				"text": "We head inside together.",
			},
			{
				"background": BACKGROUND_BAR,
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
				"text": "Inside, the first few minutes felt awkward.",
			},
			{
				"text": "Too many years. Too much catching up packed into small talk.",
			},
			{
				"speaker": "Dylan",
				"text": "So… what have you been up to these past few years?",
			},
			{
				"text": "...",
			},
			{
				"speaker": "John Toda",
				"text": "Working.",
			},
			{
				"speaker": "Arvin",
				"text": "Just working?",
			},
			{
				"speaker": "John Toda",
				"text": "More or less.",
			},
			{
				"text": "...",
			},
			{
				"text": "Nobody pushes it",
			},
			{
				"text": "Awkward silence fills the room.",
			},
			{
				"text": "until",
			},
			{
				"speaker": "Dylan",
				"text": "Oh c'mon don't be like that, just look at Ben Ten here. He looks like he has ten strands of hair left.",
			},
			{
				"speaker": "Dylan",
				"text": "Do you want him to lose more?.",
			},
			{
				"text": "And just like that, everyone laughed.",
			},
				{
					"background": TROPA_CG,
					"background_fade": 0.45,
					"text": "Soon enough they start talking about their life. How it's been for them.",
				},
			{
				"text": "Work, old mistakes, money, and all the years in between.",
			},
			{
				"text": "And then we were back. Laughing like we used to.",
			},
			{
				"text": "Like we were still in school.",
			},
			{
				"text": "Like no time passed at all.",
			},
			{
				"text": "....",
			},
			{
				"text": "Later, when we finally step outside, my face hurts a little from smiling.",
			},
			{
				"text": "In those few hours, it almost felt like nothing changed",
			},
			{
				"text": "But it did.",
			},
			{
				"text": "Achievement unlocked: Tropa",
				"actions": [
					{
						"type": "unlock_achievement",
						"id": "tropa",
					},
					{
						"type": "add_max_energy",
						"amount": 1,
					},
					{
						"type": "add_energy",
						"amount": 5,
					},
				],
			},
			{
				"text": "Energy +5\nMax Energy +1",
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
	}
