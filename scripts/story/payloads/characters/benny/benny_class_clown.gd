extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	var composition: Array[Dictionary] = [
		{
			"background": StoryConstants.BACKGROUND_STATION,
			"background_fade": 0.28,
			"pause_before": 0.14,
			"text": "The station hums with engines, footsteps, and the occasional clinking of bottles.",
			"camera": {
				"zoom": 1.0,
				"focus": "center",
				"duration": 0.4,
			},
		},
		{
			"text": "Benny gets off the tricycle and heads to work.",
		},
		{
			"text": "I rev the engine of my ride.",
		},
		{
			"speaker":"John Toda",
			"text": "Today's gonna be another long day.",
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
			"text": "Benny runs toward me before I could leave.",
		},
		{
			"text": "Did he forget something?",
		},
		{
			"speaker": "Benny",
			"text": "Hey, John. You free for a drink later tonight?",
		},
		{
			"text": "Huh!?",
		},
		{
			"speaker": "Benny",
			"text": "I'll call Arvin and Dylan too. It's been a while since we've seen you after all.",
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
		"text": "I'll try. I guess.",
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

	composition.append({
		"text": "...",
	})
	composition.append({
		"text": "I rev the engine of my ride once more.",
	})
	composition.append({
		"text": "But it seems like Benny isn't done yet.",
	})
	composition.append({
		"speaker": "Benny",
		"text": "Oh right. Can I ask you something?",
	})
	composition.append({
		"speaker": "John Toda",
		"text": "...",
	})
	composition.append({
		"speaker": "John Toda",
		"text": "Depends.",
	})

	composition.append({
		"speaker": "Benny",
		"text": "Weren't you working in the city?",
	})
	composition.append({
		"speaker": "Benny",
		"text": "What happened?",
	})
	composition.append({
		"speaker": "Benny",
		"text": "I never expected you to take over your father's job.",
	})
	composition.append({
		"speaker": "Benny",
		"text": "Doesn't seem like your thing.",
	})
	composition.append({
		"text": "I didn't think Benny would be the one to bring that up.",
	})
	composition.append({
		"speaker": "John Toda",
		"text": "I...",
	})
	var agree_answer_choice_index: int = composition.size()
	composition.append({
		"speaker": "John Toda",
		"text": "...",
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

	composition.append({
		"text": "...",
	})
	composition.append({
		"text": "I rev the engine of my ride once more.",
	})
	composition.append({
		"text": "But it seems like Benny isn't done yet.",
	})
	composition.append({
		"speaker": "Benny",
		"text": "Oh right. Can I ask you something?",
	})
	composition.append({
		"speaker": "John Toda",
		"text": "...",
	})
	composition.append({
		"speaker": "John Toda",
		"text": "Depends.",
	})


	composition.append({
		"speaker": "Benny",
		"text": "Fair enough.",
	})
	composition.append({
		"speaker": "Benny",
		"text": "Still... weren't you working in the city?",
	})
	composition.append({
		"speaker": "Benny",
		"text": "What happened?",
	})
	composition.append({
		"speaker": "Benny",
		"text": "I never expected you to take over your father's job.",
	})
	composition.append({
		"speaker": "Benny",
		"text": "Doesn't seem like your thing.",
	})
	composition.append({
		"text": "I didn't think Benny would be the one to bring that up.",
	})
	composition.append({
		"speaker": "John Toda",
		"text": "I...",
	})
	var dont_go_answer_choice_index: int = composition.size()
	composition.append({
		"speaker": "John Toda",
		"text": "...",
		"choices": [],
	})

	var truth_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "John Toda",
			"text": "..I lost my job.",
			"actions": [
				{
					"type": "set_event_value",
					"id": "benny_class_clown_city_answer",
					"value": "truth",
				},
			],
		},
		{
			"text": "...",
		},
		{
			"speaker": "John Toda",
			"text": "And when I came home, my father was gone.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "But the tricycle was still there. So I thought why not?",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "So I thought. Why not?",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "That's pretty much how I ended up driving.",
			"required_achievements": ["tapat"],
		},
		{
			"text": "Benny pauses for a while.",
		},
		{
			"speaker": "Benny",
			"text": "Damn. Sorry, John.",
		},
		{
			"text": "He pats my shoulder a few times.",
		},
		{
			"speaker": "Benny",
			"text": "Well...See you later if you can make it.",
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

	composition[agree_answer_choice_index]["choices"] = [
		{
			"text": "Tell the truth",
			"next_index": truth_index,
		},
		{
			"text": "Lie",
			"next_index": lie_index,
		},
	]

	composition[dont_go_answer_choice_index]["choices"] = [
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
		"speaker_portraits": true,
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
