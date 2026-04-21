extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	var composition: Array[Dictionary] = [
		{
			"background": StoryConstants.BACKGROUND_STATION,
			"background_fade": 0.28,
			"pause_before": 0.14,
			"text": "Maingay ang terminal. Halo-halo ang makina, yabag, at usapan ng mga pagod na tao.",
			"camera": {
				"zoom": 1.0,
				"focus": "center",
				"duration": 0.4,
			},
		},
		{
			"speaker": "Benny",
			"text": "Oy, John. Libre ka ba mamaya? Tara inom tayo mamayang gabi.",
		},
		{
			"speaker": "Benny",
			"text": "Sasama rin sina Arvin at Dylan. Nakakausap ko pa rin 'yang dalawang loko na 'yan.",
		},
	]

	var drink_choice_index: int = composition.size()
	composition.append({
		"speaker": "Benny",
		"text": "Babala: Kapag pumayag ka, malalaktawan ang night phase.\n\nAno, game ka ba?",
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
		"text": "Oo nga pala. Hindi ba sa siyudad ka nagtatrabaho dati? Ano'ng nangyari?\nHindi kita inasahang papalit sa trabaho ng tatay mo. Hindi ka mukhang gano'n.",
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
		"text": "Sige. Pero... hindi ba sa siyudad ka nagtatrabaho dati? Ano'ng nangyari?\nHindi kita inasahang papalit sa trabaho ng tatay mo. Hindi ka mukhang gano'n.",
		"choices": [],
	})

	var truth_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "John Toda",
			"text": "Natanggal ako sa trabaho sa siyudad.",
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
			"text": "Pag-uwi ko, wala na si Tatay. Pero nandoon pa rin ang traysikel.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "Doon nagsimula lahat.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "Benny",
			"text": "Grabe. Pasensya na, John.",
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
			"text": "Hindi ko na kinaya ang siyudad. Parang masyadong masikip para sa akin.",
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
			"text": "Huwag na",
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
