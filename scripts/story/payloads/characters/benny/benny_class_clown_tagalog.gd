extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	var composition: Array[Dictionary] = [
		{
			"background": StoryConstants.BACKGROUND_STATION,
			"background_fade": 0.28,
			"pause_before": 0.14,
			"text": "Bumaba si Benny mula sa tricycle at nagsimula siyang maglakad papunta sa kanyang trabaho.",
			"camera": {
				"zoom": 1.0,
				"focus": "center",
				"duration": 0.4,
			},
		},
		{
			"text": "Pinaandar ko ang makina ng aking tricycle.",
		},
		{
			"speaker":"John Toda",
			"text": "Mahaba-haba pa ang araw na to.",
		},
		{
			"text": "...",
			"actions": 
				[
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"volume_db": -4.0,
					},
				]
		},
		{
			"text": "Tumakbo pabalik si Benny.",
		},
		{
			"speaker": "Benny",
			"text": "Oy, John. May gagawin ka ba mamaya? Tara labas mamayang gabi.",
		},
		{
			"text": "Ha?",
		},
		{
			"speaker": "Benny",
			"text": "Tawagin ko din sina Arvin at Dylan. Naaalala mo pa sila diba?",
		},
		{
			"text": "...",
		},
	]

	var drink_choice_index: int = composition.size()
	composition.append({
		"text": "Warning: Agreeing will skip the night phase.",
		"choices": [],
	})

	var agree_index: int = composition.size()
	composition.append({
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
	})

	var agree_question_index: int = composition.size()
	composition.append({
		"speaker": "Benny",
		"text": "Oo nga pala. Hindi ba sa siyudad ka nagtatrabaho dati? Ano'ng nangyari?\nBa't ka nag-trirtricycle driver ngayon?",
		"choices": [],
	})

	var dont_go_index: int = composition.size()
	composition.append({
		"speaker": "John Toda",
		"text": "Pass muna. May aasikasuhin pa ako.",
		"actions": [
			{
				"type": "set_event_value",
				"id": "benny_class_clown_drink_choice",
				"value": "dont_go",
			},
		],
	})

	var dont_go_question_index: int = composition.size()
	composition.append({
		"speaker": "Benny",
		"text": "Sige. Pero... hindi ba sa siyudad ka nagtatrabaho dati? Ano'ng nangyari?\nBa't ka nag-trirtricycle driver ngayon?",
	})

	var truth_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "John Toda",
			"text": "Ayun, nawalan ako ng trabaho.",
			"actions": [
				{
					"type": "set_event_value",
					"id": "benny_class_clown_city_answer",
					"value": "truth",
				},
			],
		},
		{
			"speaker": "John Toda",
			"text": "Tapos pag-uwi ko, wala na si Tatay.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "Yung tricycle nalang ang naiwan.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "Doon ako nagsimula",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "Benny",
			"text": "Grabe. Pasensya na, John.",
		},
		{
			"text": "Tinapik ni Benny ang aking balikat",
		},
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
		},
	])
	var truth_end_index: int = composition.size() - 1

	var lie_index: int = composition.size()
	composition.append_array([
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
		{
			"speaker": "Benny",
			"text": "Pero mas maayos ang trabaho doon, 'di ba?",
		},
		{
			"speaker": "John Toda",
			"text": "Siguro.",
		},
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
		},
	])
	var story_end_index: int = composition.size()
	composition[truth_end_index]["next_index"] = story_end_index
	composition[story_end_index - 1]["next_index"] = story_end_index

	composition[drink_choice_index]["choices"] = [
		{
			"text": "Pumayag",
			"next_index": agree_index,
		},
		{
			"text": "Huwag",
			"next_index": dont_go_index,
		},
	]

	composition[agree_question_index]["choices"] = [
		{
			"text": "Sabihin ang totoo",
			"next_index": truth_index,
		},
		{
			"text": "Magsinungaling",
			"next_index": lie_index,
		},
	]

	composition[dont_go_question_index]["choices"] = [
		{
			"text": "Sabihin ang totoo",
			"next_index": truth_index,
		},
		{
			"text": "Magsinungaling",
			"next_index": lie_index,
		},
	]

	return {
		"story_id": "benny_class_clown",
		"chapter_title": "Class Clown",
		"background": StoryConstants.BACKGROUND_STATION,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_CITY_AMBIENCE,
			"loop": true,
			"fade_in": 0.55,
			"volume_db": -9.0,
		},
		"composition": composition,
	}
