extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")
const TROPA_CG := "res://assets/specialCG/tropaCg.png"


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
				"text": "Naghihintay na si Benny sa may pintuan nang makarating ako.",
			},
			{
				"text": "Nagkataon din na dati akong suki sa bar na aming pinuntahan.",
			},
			{
				"speaker": "Benny",
				"text": "Yun! Sabi ko na pupunta ka eh.",
			},
			{
				"speaker": "Benny",
				"text": "Buti di nagbago isip mo.",
			},
			{
				"speaker": "John Toda",
				"text": "Muntik na nga.",
			},
			{
				"speaker": "Benny",
				"text": "Sabi ko nga.",
			},
			{
				"text": "Ilang saglit pa ang aming hinintay sa labas, at ang sinag ng araw ay unti-unting napalitan ng ilaw ng siyudad.",
			},
			{
				"text": "Sabay na dumating sina Arvin at Dylan.",
			},
			{
				"speaker": "Arvin",
				"text": "Aba, buhay ka pa pala.",
			},
			{
				"speaker": "Dylan",
				"text": "Uy si idol! Nagbabalik.",
			},
			{
				"text": "Napatakbo sila na parang mga batang nang makita nila ako.",
			},
			{
				"speaker": "John Toda",
				"text": "Di parin nga nagbago ang mga bonjing.",
			},
			{
				"text": "Sabay-sabay kaming pumasok sa loob.",
			},
			{
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
				"text": "Sa loob, nagkwentuhan kami tungkol sa buhay.",
			},
			{
				"text": "dapat.",
			},
			{
				"text": "Nanatiling tahimik ang aming lamesa na para bang hindi namin alam ang sasabihin sa isa't isa.",
			},
			{
				"speaker": "Dylan",
				"text": "Nga pala John.",
			},
			{
				"text": "Si Dylan ang unang nagsalita.",
			},
			{
				"speaker": "Dylan",
				"text": "Anong ginawa mo sa siyudad ng ilang taon?",
			},
			{
				"text": "...",
			},
			{
				"speaker": "John Toda",
				"text": "Trabaho.",
			},
			{
				"speaker": "Arvin",
				"text": "Yun lang?",
			},
			{
				"speaker": "John Toda",
				"text": "Medyo.",
			},
			{
				"speaker": "John Toda",
				"text": "...",
			},
			{
				"text": "Di na sila nagtanong muli.",
			},
			{
				"text": "Nanahimik nanaman ang aming lamesa.",
			},
			{
				"text": "hanggang...",
			},
			{
				"speaker": "Dylan",
				"text": "Bat kayo ganyan. Magkakalbo nanaman si Ben sa ginagawa niyo.",
			},
			{
				"speaker": "Ben",
				"text": "Gag-.",
			},
				{
					"background": TROPA_CG,
					"background_fade": 0.45,
					"text": "At parang ganun lang, nagsitawanan kaming lahat.",
				},
			{
				"text": "Di nagtagal, at nagsimula silang magkwento tungkol sakanilang buhay.",
			},
			{
				"text": "Sa trabaho, mga dating pagkakamali, pera, at lahat ng mga pangyayari sa pagitan ng noon at ngayon.",
			},
			{
				"text": "Hindi nagtagal at kami'y nagtatawanan na para bang mga bata.",
			},
			{
				"text": "Na parang nasa eskwelahan pa kami.",
			},
			{
				"text": "At hindi gumalaw ang oras para saamin.",
			},
			{
				"text": "...",
			},
			{
				"text": "Mayamaya, nang kami'y papaalis na, pinisil ko ang aking pisngi",
			},
			{
				"text": "Medyo nangawit sa kakatawa.",
			},
			{
				"text": "Sa ilang oras na lumipas, parang nagbalik kami sa nakaraan.",
			},
			{
				"text": "Ngunit ang nakaraan ay hindi na maibabalik.",
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
