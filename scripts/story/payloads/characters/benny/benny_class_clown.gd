extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const AGREE := 12
const DECLINE := 26
const TELL_TRUTH := 41
const LIE := 51
const STORY_END := 55


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
				"text": "The station hums with engines, footsteps, and the occasional clinking of bottles.",
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
				"text": "Benny gets off the tricycle and heads to work.",
			},
			# 2
			{
				"text": "I rev the engine of my ride.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "Today's gonna be another long day.",
			},
			# 4
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
			# 5
			{
				"text": "Benny runs toward me before I could leave.",
			},
			# 6
			{
				"text": "Did he forget something?",
			},
			# 7
			{
				"speaker": "Benny",
				"text": "Hey, John. You free for a drink later tonight?",
			},
			# 8
			{
				"text": "Huh!?",
			},
			# 9
			{
				"speaker": "Benny",
				"text": "I'll call Arvin and Dylan too. It's been a while since we've seen you after all.",
			},
			# 10
			{
				"text": "...",
			},
			# 11
			{
				"text": "Warning: Agreeing will skip the night phase.",
				"choices": [
					{
						"text": "Agree",
						"next_index": AGREE,
					},
					{
						"text": "Don't go",
						"next_index": DECLINE,
					},
				],
			},
			# 12 — AGREE
			{
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
			},
			# 13
			{
				"text": "...",
			},
			# 14
			{
				"text": "I rev the engine of my ride once more.",
			},
			# 15
			{
				"text": "But it seems like Benny isn't done yet.",
			},
			# 16
			{
				"speaker": "Benny",
				"text": "Oh right. Can I ask you something?",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "Depends.",
			},
			# 19
			{
				"speaker": "Benny",
				"text": "Weren't you working in the city?",
			},
			# 20
			{
				"speaker": "Benny",
				"text": "What happened?",
			},
			# 21
			{
				"speaker": "Benny",
				"text": "I never expected you to take over your father's job.",
			},
			# 22
			{
				"speaker": "Benny",
				"text": "Doesn't seem like your thing.",
			},
			# 23
			{
				"text": "I didn't think Benny would be the one to bring that up.",
			},
			# 24
			{
				"speaker": "John Toda",
				"text": "I...",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "...",
				"choices": [
					{
						"text": "Tell the truth",
						"next_index": TELL_TRUTH,
					},
					{
						"text": "Lie",
						"next_index": LIE,
					},
				],
			},
			# 26 — DECLINE
			{
				"speaker": "John Toda",
				"text": "Not tonight. I've still got things to deal with.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "benny_class_clown_drink_choice",
						"value": "dont_go",
					},
				],
			},
			# 27
			{
				"text": "...",
			},
			# 28
			{
				"text": "I rev the engine of my ride once more.",
			},
			# 29
			{
				"text": "But it seems like Benny isn't done yet.",
			},
			# 30
			{
				"speaker": "Benny",
				"text": "Oh right. Can I ask you something?",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "Depends.",
			},
			# 33
			{
				"speaker": "Benny",
				"text": "Fair enough.",
			},
			# 34
			{
				"speaker": "Benny",
				"text": "Still... weren't you working in the city?",
			},
			# 35
			{
				"speaker": "Benny",
				"text": "What happened?",
			},
			# 36
			{
				"speaker": "Benny",
				"text": "I never expected you to take over your father's job.",
			},
			# 37
			{
				"speaker": "Benny",
				"text": "Doesn't seem like your thing.",
			},
			# 38
			{
				"text": "I didn't think Benny would be the one to bring that up.",
			},
			# 39
			{
				"speaker": "John Toda",
				"text": "I...",
			},
			# 40
			{
				"speaker": "John Toda",
				"text": "...",
				"choices": [
					{
						"text": "Tell the truth",
						"next_index": TELL_TRUTH,
					},
					{
						"text": "Lie",
						"next_index": LIE,
					},
				],
			},
			# 41 — TELL_TRUTH
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
			# 42
			{
				"text": "...",
			},
			# 43
			{
				"speaker": "John Toda",
				"text": "And when I came home, my father was gone.",
				"required_achievements": ["tapat"],
			},
			# 44
			{
				"speaker": "John Toda",
				"text": "But the tricycle was still there. So I thought why not?",
				"required_achievements": ["tapat"],
			},
			# 45
			{
				"speaker": "John Toda",
				"text": "So I thought. Why not?",
				"required_achievements": ["tapat"],
			},
			# 46
			{
				"speaker": "John Toda",
				"text": "That's pretty much how I ended up driving.",
				"required_achievements": ["tapat"],
			},
			# 47
			{
				"text": "Benny pauses for a while.",
			},
			# 48
			{
				"speaker": "Benny",
				"text": "Damn. Sorry, John.",
			},
			# 49
			{
				"text": "He pats my shoulder a few times.",
			},
			# 50
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
				"next_index": STORY_END,
			},
			# 51 — LIE
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
			# 52
			{
				"speaker": "Benny",
				"text": "At least the work's better there, right?",
			},
			# 53
			{
				"speaker": "John Toda",
				"text": "I guess.",
			},
			# 54
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
				"next_index": STORY_END,
			},
		],
	})
