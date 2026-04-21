extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	var composition: Array[Dictionary] = [
		{
			"background": StoryConstants.BACKGROUND_STATION,
			"background_fade": 0.28,
			"pause_before": 0.14,
			"text": "The station hums with engines, footsteps, and tired voices.",
			"camera": {
				"zoom": 1.0,
				"focus": "center",
				"duration": 0.4,
			},
		},
		{
			"speaker": "Benny",
			"text": "Hey, John. You free for a drink later tonight?",
		},
		{
			"speaker": "Benny",
			"text": "Arvin and Dylan are coming too. I still talk to those idiots somehow.",
		},
	]

	var drink_choice_index: int = composition.size()
	composition.append({
		"speaker": "Benny",
		"text": "Warning: Agreeing will skip the night phase.\n\nSo, what do you say?",
		"choices": [],
	})

	var agree_index: int = composition.size()
	composition.append({
		"speaker": "John Toda",
		"text": "Maybe. It's been a while.",
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
		"text": "Right. Weren't you working in the city? What happened?\nI never expected you to take over your father's job. You don't seem like the type to.",
		"choices": [],
	})

	var dont_go_index: int = composition.size()
	composition.append({
		"speaker": "John Toda",
		"text": "Not tonight. I've still got things to deal with.",
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
		"text": "Fair enough. Still... weren't you working in the city? What happened?\nI never expected you to take over your father's job. You don't seem like the type to.",
		"choices": [],
	})

	var truth_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "John Toda",
			"text": "I lost the job in the city.",
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
			"text": "When I came home, my father was gone. The tricycle was still there.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "That's how I ended up driving.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "Benny",
			"text": "Damn. Sorry, John.",
		},
		{
			"speaker": "Benny",
			"text": "See you later if you can make it.",
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
			"text": "I couldn't take the city anymore. It felt too cramped in there.",
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
			"text": "At least the work's better there, right?",
		},
		{
			"speaker": "John Toda",
			"text": "I guess.",
		},
		{
			"speaker": "Benny",
			"text": "See you later if you can make it.",
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
			"text": "Agree",
			"next_index": agree_index,
		},
		{
			"text": "Don't go",
			"next_index": dont_go_index,
		},
	]

	composition[agree_question_index]["choices"] = [
		{
			"text": "Tell the truth",
			"next_index": truth_index,
		},
		{
			"text": "Lie",
			"next_index": lie_index,
		},
	]

	composition[dont_go_question_index]["choices"] = [
		{
			"text": "Tell the truth",
			"next_index": truth_index,
		},
		{
			"text": "Lie",
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
