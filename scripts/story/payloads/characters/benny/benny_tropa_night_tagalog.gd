extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")


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
				"text": "Bago ako umalis, binuksan ko ang aking pitaka.",
			},
			{
				"speaker": "John Toda",
				"text": "Kakasya pa ba to?",
			},
			{
				"text": "Binilang ko ang aking pera.",
			},
			{
				"speaker": "John Toda",
				"text": "...",
			},
			{
				"speaker": "John Toda",
				"text": "May utang pa ako na babayaran. Wala na akong oras magwalwal.",
			},
			{
				"speaker": "John Toda",
				"text": "Pero...",
			},
			{
				"text": "Si Benny, Arvin, at Dylan.",
			},
			{
				"text": "Matagal ko na silang hindi nakita",
			},
			{
				"text": "Mas mabuti nalang siguro na makausap ko sila bago mahuli ang lahat",
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
				"text": "Binuksan ko ang pintuan at ako'y lumabas.",
			},
			{
				"background": StoryConstants.BACKGROUND_CITY,
				"background_fade": 0.28,
				"text": "Sa napagkasunduang lugar sa siyudad, nauna nang naghihintay si Benny para sa kanya.",
			},
			{
				"text": "Nagkataon pa na iyon din ang parehong bar na dati ring pinupuntahan ni John.",
			},
			{
				"speaker": "Benny",
				"text": "Ayos, nakapunta ka.",
			},
			{
				"text": "Sandali silang naghintay sa labas sa ilalim ng ilaw ng siyudad.",
			},
			{
				"text": "Pagkatapos, dumating sina Arvin at Dylan, maingay at pamilyar pa rin gaya ng dati.",
			},
			{
				"text": "Sabay-sabay silang pumasok sa loob.",
			},
			{
				"background": StoryConstants.BACKGROUND_BAR,
				"background_fade": 0.28,
				"text": "Sa loob, nagkwentuhan sila tungkol sa buhay nila.",
			},
			{
				"text": "Trabaho, mga dating pagkakamali, pera, at lahat ng taon sa pagitan noon at ngayon.",
			},
			{
				"text": "Maya-maya, nagtatawanan na sila tungkol sa mga kalokohan nila noong school days.",
			},
			{
				"speaker": "John Toda",
				"text": "Kahit lumipas ang lahat ng taon na iyon...",
			},
			{
				"speaker": "John Toda",
				"text": "Kaibigan ko pa rin sila. At mananatili silang kaibigan ko.",
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
