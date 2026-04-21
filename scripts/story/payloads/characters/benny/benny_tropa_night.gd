extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")
const BACKGROUND_BAR := "res://assets/story/backgrounds/bar.jpeg"


static func build() -> Dictionary:
	return {
		"story_id": "benny_tropa_night",
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
				"text": "At home, John checks the time on his phone.",
			},
			{
				"text": "He picks up his tricycle keys and heads out.",
			},
			{
				"background": StoryConstants.BACKGROUND_CITY,
				"background_fade": 0.28,
				"text": "At the agreed spot in the city, Benny is already there waiting for him.",
			},
			{
				"text": "The bar turns out to be the same one John used to go to.",
			},
			{
				"speaker": "Benny",
				"text": "You made it.",
			},
			{
				"text": "The two of them wait outside for a bit under the city lights.",
			},
			{
				"text": "Then Arvin and Dylan arrive, loud and familiar as ever.",
			},
			{
				"text": "All four of them head inside together.",
			},
			{
				"background": BACKGROUND_BAR,
				"background_fade": 0.28,
				"text": "Inside, they talk about how life has been treating them.",
			},
			{
				"text": "Work, old mistakes, money, and all the years in between.",
			},
			{
				"text": "Before long, they are laughing about school again like no time passed at all.",
			},
			{
				"speaker": "John Toda",
				"text": "Even after all those years...",
			},
			{
				"speaker": "John Toda",
				"text": "My friends will always be my friends.",
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
