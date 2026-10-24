extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const AGREE := 10
const DECLINE := 18
const TELL_TRUTH := 26
const LIE := 34
const STORY_END := 38


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "benny_class_clown",
		"chapter_title": "Class Clown",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "Bumaba si Benny mula sa tricycle at nagsimula siyang maglakad papunta sa kanyang trabaho.",
				"background": StoryConstants.BACKGROUND_STATION,
				"background_fade": 0.28,
				"pause_before": 0.14,
				"camera": {
					"zoom": 1.0,
					"focus": "center",
					"duration": 0.4,
				},
			},
			# 1
			{
				"text": "Pinaandar ko ang makina ng aking tricycle.",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Mahaba-haba pa ang araw na to.",
			},
			# 3
			{
				"text": "...",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"volume_db": -4.0,
					},
				],
			},
			# 4
			{
				"text": "Tumakbo pabalik si Benny.",
			},
			# 5
			{
				"speaker": "Benny",
				"text": "Oy, John. May gagawin ka ba mamaya? Tara labas mamayang gabi.",
			},
			# 6
			{
				"text": "Ha?",
			},
			# 7
			{
				"speaker": "Benny",
				"text": "Tawagin ko din sina Arvin at Dylan. Naaalala mo pa sila diba?",
			},
			# 8
			{
				"text": "...",
			},
			# 9
			{
				"text": "Warning: Agreeing will skip the night phase.",
				"choices": [
					{
						"text": "Pumayag",
						"next_index": AGREE,
					},
					{
						"text": "Huwag",
						"next_index": DECLINE,
					},
				],
			},
			# 10 — AGREE
			{
				"speaker": "John Toda",
				"text": "Sige, baka makahabol ako.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_class_clown_drink_choice",
						"value": "agree",
					},
					{
						"type": "set_pending_night_skip",
						"enabled": true,
					},
				],
			},
			# 11
			{
				"text": "...",
			},
			# 12
			{
				"text": "Pinaandar ko muli ang makina ng aking motor.",
			},
			# 13
			{
				"text": "Pero mukhang hindi pa tapos magtanong si Benny.",
			},
			# 14
			{
				"speaker": "Benny",
				"text": "Teka lang. May tanong lang ako bago ka umalis.",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "Ano yun?",
			},
			# 17
			{
				"speaker": "Benny",
				"text": "Hindi ba sa siyudad ka nagtatrabaho dati? Ano'ng nangyari?\nBa't ka nag-trirtricycle driver ngayon?",
				"choices": [
					{
						"text": "Sabihin ang totoo",
						"next_index": TELL_TRUTH,
					},
					{
						"text": "Magsinungaling",
						"next_index": LIE,
					},
				],
			},
			# 18 — DECLINE
			{
				"speaker": "John Toda",
				"text": "Pass muna. May aasikasuhin pa ako.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_class_clown_drink_choice",
						"value": "dont_go",
					},
				],
			},
			# 19
			{
				"text": "...",
			},
			# 20
			{
				"text": "Pinaandar ko muli ang makina ng aking motor.",
			},
			# 21
			{
				"text": "Pero mukhang hindi pa tapos magtanong si Benny.",
			},
			# 22
			{
				"speaker": "Benny",
				"text": "Teka lang. May tanong lang ako bago ka umalis.",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 24
			{
				"speaker": "John Toda",
				"text": "Ano yun?",
			},
			# 25
			{
				"speaker": "Benny",
				"text": "Hindi ba sa siyudad ka nagtatrabaho dati? Ano'ng nangyari?\nBa't ka nag-trirtricycle driver ngayon?",
				"choices": [
					{
						"text": "Sabihin ang totoo",
						"next_index": TELL_TRUTH,
					},
					{
						"text": "Magsinungaling",
						"next_index": LIE,
					},
				],
			},
			# 26 — TELL_TRUTH
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 27
			{
				"speaker": "John Toda",
				"text": "Nawalan ako ng trabaho. Tapos masyadong mahal rin manirahan sa siyudad kaya yun, umalis ako.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_class_clown_city_answer",
						"value": "truth",
					},
				],
			},
			# 28
			{
				"speaker": "John Toda",
				"text": "Tapos pag-uwi ko, wala na si Tatay.",
				"required_achievements": ["tapat"],
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "Yung tricycle nalang ang naiwan.",
				"required_achievements": ["tapat"],
			},
			# 30
			{
				"speaker": "John Toda",
				"text": "Doon ako nagsimula",
				"required_achievements": ["tapat"],
			},
			# 31
			{
				"speaker": "Benny",
				"text": "Grabe. Pasensya na, John.",
			},
			# 32
			{
				"text": "Tinapik ni Benny ang aking balikat",
			},
			# 33
			{
				"speaker": "Benny",
				"text": "Sige, kita tayo mamaya kung makakahabol ka.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_class_clown_seen",
						"value": 1,
					},
				],
				"next_index": STORY_END,
			},
			# 34 — LIE
			{
				"speaker": "John Toda",
				"text": "Hindi ko na kinaya ang siyudad. Masyadong maingay. Magulo.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_class_clown_city_answer",
						"value": "lie",
					},
					{
						"type": "unlock_achievement",
						"id": "sinungaling",
					},
					{
						"type": "set_character_story_lock",
						"character_id": "benny",
						"locked": true,
						"required_event_values": {
							"benny_class_clown_drink_choice": "dont_go",
						},
					},
				],
			},
			# 35
			{
				"speaker": "Benny",
				"text": "Pero mas maayos ang trabaho doon, 'di ba?",
			},
			# 36
			{
				"speaker": "John Toda",
				"text": "Siguro.",
			},
			# 37
			{
				"speaker": "Benny",
				"text": "Sige, kita tayo mamaya kung makakahabol ka.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_class_clown_seen",
						"value": 1,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
