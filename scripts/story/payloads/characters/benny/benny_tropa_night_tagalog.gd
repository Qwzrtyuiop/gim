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
				"text": "Bago ako umalis, binuksan ko ang aking pitaka.",
				"background": StoryConstants.BACKGROUND_INHOUSE,
				"background_fade": 0.28,
				"pause_before": 0.16,
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "Kakasya pa ba to?",
			},
			# 2
			{
				"text": "Binilang ko ang aking pera.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "May utang pa ako na babayaran. Wala na akong oras magwalwal.",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Pero...",
			},
			# 6
			{
				"text": "Si Benny, Arvin, at Dylan.",
			},
			# 7
			{
				"text": "Matagal ko na silang hindi nakita",
			},
			# 8
			{
				"text": "Mas mabuti nalang siguro na makausap ko sila bago mahuli ang lahat",
			},
			# 9
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
			# 10
			{
				"text": "Binuksan ko ang pintuan at ako'y lumabas.",
			},
			# 11
			{
				"text": "Naghihintay na si Benny sa may pintuan nang makarating ako.",
				"background": StoryConstants.BACKGROUND_BAR_EXTERIOR_NIGHT,
				"background_fade": 0.28,
			},
			# 12
			{
				"text": "Nagkataon din na dati akong suki sa bar na aming pinuntahan.",
			},
			# 13
			{
				"speaker": "Benny",
				"text": "Yun! Sabi ko na pupunta ka eh.",
			},
			# 14
			{
				"speaker": "Benny",
				"text": "Buti di nagbago isip mo.",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "Muntik na nga.",
			},
			# 16
			{
				"speaker": "Benny",
				"text": "Sabi ko nga.",
			},
			# 17
			{
				"text": "Ilang saglit pa ang aming hinintay sa labas, at ang sinag ng araw ay unti-unting napalitan ng ilaw ng siyudad.",
			},
			# 18
			{
				"text": "Sabay na dumating sina Arvin at Dylan.",
			},
			# 19
			{
				"speaker": "Arvin",
				"text": "Aba, buhay ka pa pala.",
			},
			# 20
			{
				"speaker": "Dylan",
				"text": "Uy si idol! Nagbabalik.",
			},
			# 21
			{
				"text": "Napatakbo sila na parang mga batang nang makita nila ako.",
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "Di parin nga nagbago ang mga bonjing.",
			},
			# 23
			{
				"text": "Sabay-sabay kaming pumasok sa loob.",
			},
			# 24
			{
				"text": "Sa loob, nagkwentuhan kami tungkol sa buhay.",
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
			# 25
			{
				"text": "dapat.",
			},
			# 26
			{
				"text": "Nanatiling tahimik ang aming lamesa na para bang hindi namin alam ang sasabihin sa isa't isa.",
			},
			# 27
			{
				"speaker": "Dylan",
				"text": "Nga pala John.",
			},
			# 28
			{
				"text": "Si Dylan ang unang nagsalita.",
			},
			# 29
			{
				"speaker": "Dylan",
				"text": "Anong ginawa mo sa siyudad ng ilang taon?",
			},
			# 30
			{
				"text": "...",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "Trabaho.",
			},
			# 32
			{
				"speaker": "Arvin",
				"text": "Yun lang?",
			},
			# 33
			{
				"speaker": "John Toda",
				"text": "Medyo.",
			},
			# 34
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 35
			{
				"text": "Di na sila nagtanong muli.",
			},
			# 36
			{
				"text": "Nanahimik nanaman ang aming lamesa.",
			},
			# 37
			{
				"text": "hanggang...",
			},
			# 38
			{
				"speaker": "Dylan",
				"text": "Bat kayo ganyan. Magkakalbo nanaman si Ben sa ginagawa niyo.",
			},
			# 39
			{
				"speaker": "Ben",
				"text": "Gag-.",
			},
			# 40
			{
				"text": "At parang ganun lang, nagsitawanan kaming lahat.",
				"background": StoryConstants.CG_TROPA,
				"background_fade": 0.45,
			},
			# 41
			{
				"text": "Di nagtagal, at nagsimula silang magkwento tungkol sakanilang buhay.",
			},
			# 42
			{
				"text": "Sa trabaho, mga dating pagkakamali, pera, at lahat ng mga pangyayari sa pagitan ng noon at ngayon.",
			},
			# 43
			{
				"text": "Hindi nagtagal at kami'y nagtatawanan na para bang mga bata.",
			},
			# 44
			{
				"text": "Na parang nasa eskwelahan pa kami.",
			},
			# 45
			{
				"text": "At hindi gumalaw ang oras para saamin.",
			},
			# 46
			{
				"text": "...",
			},
			# 47
			{
				"text": "Mayamaya, nang kami'y papaalis na, pinisil ko ang aking pisngi",
				"background": StoryConstants.BACKGROUND_BAR_EXTERIOR_NIGHT,
				"background_fade": 0.28,
			},
			# 48
			{
				"text": "Medyo nangawit sa kakatawa.",
			},
			# 49
			{
				"text": "Sa ilang oras na lumipas, parang nagbalik kami sa nakaraan.",
			},
			# 50
			{
				"text": "Ngunit ang nakaraan ay hindi na maibabalik.",
			},
			# 51
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
			# 52
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
	})
