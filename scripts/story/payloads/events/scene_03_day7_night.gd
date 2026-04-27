extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")

static func build() -> Dictionary:
	var composition: Array[Dictionary] = [
		{
			"background": StoryConstants.BACKGROUND_INHOUSE,
			"background_fade": 0.28,
			"pause_before": 0.18,
			"text": "The house is quiet when I get back.",
			"camera": {
				"zoom": 1.0,
				"focus": "center",
				"duration": 0.45,
			},
		},
		{
			"text": "Even the road outside sounds tired.",
		},
		{
			"text": "I sit near the table and empty my pockets.",
		},
		{
			"text": "Coins first. Then the folded bills.",
		},
		{
			"speaker": "John Toda",
			"text": "One hundred. Two. Three...",
		},
		{
			"speaker": "John Toda",
			"text": "Come on.",
		},
		{
			"text": "I count everything again, slower this time, like the numbers might change if I treat them gently.",
			"show_debt_overlay": {
				"remaining_text": "First payment: PhP 2500",
				"due_text": "Collection tomorrow.",
				"fade_in": 0.24,
			},
			"actions": [
				{
					"type": "play_music",
					"path": StoryConstants.MUSIC_DRUM,
					"loop": false,
					"fade_out": 0.2,
					"volume_db": -8.0,
				}
			],
		},
		{
			"speaker": "John Toda",
			"text": "Tomorrow.",
		},
		{
			"speaker": "John Toda",
			"text": "That's the part that keeps getting louder.",
		},
		{
			"text": "I think about every passenger who told me to hurry, every meter of gas, every peso that left faster than it came in.",
		},
		{
			"text": "The bill I returned on my second day comes back to me for a moment.",
			"required_achievements": ["tapat"],
		},
		{
			"speaker": "John Toda",
			"text": "Doing the right thing still has a cost.",
			"required_achievements": ["tapat"],
		},
		{
			"text": "The bill I kept on my second day comes back to me for a moment.",
			"required_achievements": ["mapagsamantala"],
		},
		{
			"speaker": "John Toda",
			"text": "Even the easy money didn't feel easy for long.",
			"required_achievements": ["mapagsamantala"],
		},
		{
			"text": "I press my thumb against the edge of the table until it hurts a little.",
		},
	]

	var choice_index: int = composition.size()
	composition.append({
		"speaker": "John Toda",
		"text": "So what now?",
		"hide_debt_overlay": {
			"fade_out": 0.18,
		},
		"choices": [],
	})

	var count_again_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "John Toda",
			"text": "Again.",
			"actions": [
				{
					"type": "set_event_value",
					"id": "scene_03_day7_night_choice",
					"value": "count_again",
				}
			],
		},
		{
			"text": "I line the bills up by size, smooth the corners, and count them one more time.",
		},
		{
			"text": "The total stays the same.",
		},
		{
			"speaker": "John Toda",
			"text": "Of course it does.",
		},
	])
	var count_again_end_index: int = composition.size() - 1

	var put_away_index: int = composition.size()
	composition.append_array([
		{
			"speaker": "John Toda",
			"text": "Enough.",
			"actions": [
				{
					"type": "set_event_value",
					"id": "scene_03_day7_night_choice",
					"value": "put_away",
				}
			],
		},
		{
			"text": "I fold the money and place it under the old cup near the sink.",
		},
		{
			"text": "If I keep looking at it, I will start bargaining with myself.",
		},
		{
			"speaker": "John Toda",
			"text": "Not tonight.",
		},
	])
	var put_away_end_index: int = composition.size() - 1

	var rejoin_index: int = composition.size()
	composition.append_array([
		{
			"text": "The house settles around me again.",
		},
		{
			"text": "Somewhere outside, a motorcycle passes, then fades into the next street.",
		},
		{
			"speaker": "John Toda",
			"text": "Dad made this look easier.",
		},
		{
			"text": "I stare at the tricycle keys on the table.",
		},
		{
			"speaker": "John Toda",
			"text": "No. He just never let me see this part.",
		},
		{
			"text": "I turn off the light.",
			"actions": [
				{
					"type": "fade_to_black",
					"duration": 0.35,
				}
			],
		},
		{
			"text": "Tomorrow, someone will knock.",
			"pause_after": 0.8,
			"actions": [
				{
					"type": "set_event_value",
					"id": "scene_03_day7_night_seen",
					"value": 1,
				}
			],
		},
	])

	composition[count_again_end_index]["next_index"] = rejoin_index
	composition[put_away_end_index]["next_index"] = rejoin_index
	composition[choice_index]["choices"] = [
		{
			"text": "Count it again",
			"next_index": count_again_index,
		},
		{
			"text": "Put it away",
			"next_index": put_away_index,
		},
	]

	return {
		"story_id": "scene_03_day7_night",
		"chapter_title": "Scene 3",
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_CITY_AMBIENCE,
			"loop": true,
			"fade_in": 0.55,
			"volume_db": -10.0,
		},
		"composition": composition,
	}
