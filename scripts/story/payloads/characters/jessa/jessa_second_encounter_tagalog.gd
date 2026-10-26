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
		"chapter_title": "Pamilyar na Pasahero",
		"speaker_portraits": true,
		"return_scene": "res://scenes/ride_selection.tscn",
		"next_scene": "res://scenes/ride_selection.tscn",
		"background": StoryConstants.BACKGROUND_TERMINAL_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_TERMINAL,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"speaker": "John Toda",
				"text": "Uy, hindi ba ikaw 'yung—",
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
				"text": "Ay, lagot!",
			},
			# 3
			{
				"text": "Bago pa siya makatakas, nagmamadali akong lumapit at hinarangan siya.",
			},
			# 4
			{
				"text": "Sinubukan pa rin niyang tumakbo, kaya hinawakan ko siya sa pulsuhan.",
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
				"text": "Bitawan mo 'ko!",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "Basta mangako kang hindi ka tatakbo.",
			},
			# 8
			{
				"text": "Sinusubukan niyang tanggalin ang pagkakahawak ko, pero sumuko rin siya.",
			},
			# 9
			{
				"text": "Maya-maya, tumango siya.",
			},
			# 10
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Sige na.",
			},
			# 11
			{
				"text": "Binitawan ko ang pulsuhan niya. Ang nipis pala ng braso niya sa ilalim ng makakapal niyang manggas.",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "O...",
			},
			# 13
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "O, ano?",
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
				"text": "Bakit mo ginawa 'yon?",
			},
			# 15
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Ang alin?",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "Alam mo ang ibig kong sabihin.",
			},
			# 17
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Hindi nga.",
			},
			# 18
			{
				"text": "Napabuntong-hininga ako.",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "Yung pamasahe. Bakit ka tumakbo nang hindi nagbabayad?",
			},
			# 20
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Kulang kasi ang pera ko.",
			},
			# 21
			{
				"text": "Agad siyang sumagot, na para bang inaasahan na niya ang tanong na 'yon.",
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "O, may pambayad ka na ba ngayon?",
			},
			# 24
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Wala. Wala pa rin akong pera, eh...",
			},
			# 25
			{
				"text": "Inilabas niya ang pitaka niya at binuksan sa harap ko.",
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
				"text": "Ilang barya at isang balat ng kendi.",
				"speaker_portraits": false,
			},
			# 27
			{
				"text": "Yun lang.",
				"speaker_portraits": false,
			},
			# 28
			{
				"speaker": "John Toda",
				"text": "Eh, yung mga magulang mo?",
				"speaker_portraits": false,
			},
			# 29
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Wala akong mga magulang.",
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
				"text": "Ah...",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "May nag-aalaga ba sa 'yo?",
			},
			# 33
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Wala.",
			},
			# 34
			{
				"text": "Haaay...",
			},
			# 35
			{
				"text": "Wala na akong maisip.",
			},
			# 36
			{
				"text": "Nagsisinungaling lang siya, o wala talaga siyang ibang malalapitan.",
			},
			# 37 - DECISION
			{
				"text": "Ano na'ng gagawin ko sa kanya?",
				"choices": [
					{
						"text": "Takutin siyang dadalhin siya sa pulis.",
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
						"text": "Palampasin siya, pero bigyan ng babala.",
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
				"text": "Paano kung pumunta tayo sa presinto? Baka matulungan ka nila.",
			},
			# 39
			{
				"text": "Biglang dumilim ang ekspresyon niya.",
			},
			# 40
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 41
			{
				"text": "Bigla niya akong sinipa sa lulod.",
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
				"text": "ARAY!",
			},
			# 43
			{
				"text": "ANO BA—?!",
			},
			# 44
			{
				"text": "Sa sobrang sakit ng sipa, saglit kong naisip na baka may nabali.",
			},
			# 45
			{
				"speaker": "John Toda",
				"text": "Ikaw na bata ka—!",
			},
			# 46
			{
				"text": "Pero nang tumingala ako, tumatakbo na siya palayo.",
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
				"text": "HOY! BUMALIK KA RITO!",
			},
			# 48
			{
				"text": "Wala na siya.",
			},
			# 49
			{
				"text": "Na naman.",
			},
			# 50
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 51
			{
				"speaker": "John Toda",
				"text": "Na naman...",
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
				"text": "Sige na nga. Pero mangako kang hindi mo na uulitin 'yon. Sa akin man o sa ibang driver.",
			},
			# 53
			{
				"text": "Malamang uulitin niya pa rin, pero...",
			},
			# 54
			{
				"text": "Wala na akong maisip.",
			},
			# 55
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Ha?",
			},
			# 56
			{
				"speaker": "John Toda",
				"text": "Ano?",
			},
			# 57
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Yun na 'yon?",
			},
			# 58
			{
				"speaker": "John Toda",
				"text": "Anong ibig mong sabihing, 'yun na 'yon'?",
			},
			# 59
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Ang tanga naman. Puwede naman akong umoo tapos gawin ko ulit.",
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "Ikaw na bata ka—",
			},
			# 61
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Sasabihin ko na lang ang pangalan ko.",
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
				"text": "Ha?",
			},
			# 63 - REVEAL_NAME
			{
				"speaker": "Jessa",
				"speaker_display_name": "???",
				"text": "Jessa. Jessa lang.",
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
				"text": "May mga nakakakilala sa 'kin dito. Kaya kung mahuli mo ulit akong ginagawa 'yon, sabihin mo sa lahat na ako 'yon.",
			},
			# 66
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 67
			{
				"text": "Anong klaseng katwiran 'yon?",
			},
			# 68
			{
				"text": "Bago pa ako makapagsalita ulit, tumalikod na siya at tumakbo palayo. Kumaway pa siya, na para bang wala siyang ginawang masama.",
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
				"text": "Sige, paalam!",
			},
			# 70
			{
				"speaker": "John Toda",
				"text": "Uy, hindi ko sinabing puwede ka nang—",
			},
			# 71
			{
				"speaker": "Jessa",
				"speaker_display_name": "Jessa",
				"text": "Magbabayad na talaga ako sa susunod!",
			},
			# 72
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 73
			{
				"speaker": "John Toda",
				"text": "Ang weird naman ng batang 'yon.",
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
