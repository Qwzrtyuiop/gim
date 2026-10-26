extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based branch targets; append future branches to preserve saved indices.
const DECISION := 28
const ACCEPT := 29
const REFUSE := 43
const STORY_END := 68


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "gardo_first_encounter",
		"chapter_title": "Not Yet",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.BACKGROUND_TERMINAL_NIGHT,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "I stop at the passenger's destination.",
			},
			# 1
			{
				"speaker": "John Toda",
				"text": "Huh?",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "We're back at the station?",
			},
			# 3
			{
				"text": "The passenger had been giving me directions throughout the ride, leading me from one street to another.",
			},
			# 4
			{
				"text": "And somehow, we've ended up right where we started.",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Sir?",
			},
			# 6
			{
				"text": "I turn around to check on him.",
			},
			# 7
			{
				"text": "He's fast asleep.",
			},
			# 8
			{
				"speaker": "John Toda",
				"text": "Sir, we're here.",
			},
			# 9
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Huh? What?",
			},
			# 10
			{
				"text": "He stirs awake and looks around.",
			},
			# 11
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "We're here already?",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "We're back at the station, sir.",
			},
			# 13
			{
				"text": "Without asking why, he pulls back his sleeve and checks his wristwatch.",
			},
			# 14
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 15
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Not yet.",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "Huh?",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "Um... Sir? Are you getting off?",
			},
			# 18
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "I said not yet.",
			},
			# 19
			{
				"text": "He looks at his watch again.",
			},
			# 20
			{
				"text": "There's something strange about his expression. He looks irritated, almost as though he's waiting for something.",
			},
			# 21
			{
				"text": "Or dreading it.",
			},
			# 22
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Hey, kid.",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "Yes?",
			},
			# 24
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Can you drive around a little longer?",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "What? Why?",
			},
			# 26
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Just do it. I'll pay you double.",
			},
			# 27
			{
				"speaker": "John Toda",
				"text": "Double?",
			},
			# 28 - DECISION
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Yeah. So, how about it?",
				"choices": [
					{
						"text": "Accept his offer.",
						"next_index": ACCEPT,
						"actions": [
							{
								"type": "set_event_value",
								"id": "gardo_first_encounter_choice",
								"value": "accept",
							},
						],
					},
					{
						"text": "Refuse.",
						"next_index": REFUSE,
						"actions": [
							{
								"type": "set_event_value",
								"id": "gardo_first_encounter_choice",
								"value": "refuse",
							},
						],
					},
				],
			},
			# 29 - ACCEPT
			{
				"text": "Double the fare, huh?",
			},
			# 30
			{
				"text": "Well, I can't think of a good reason to refuse.",
			},
			# 31
			{
				"text": "Anything that gets me closer to paying off my debt.",
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "Alright, sir.",
			},
			# 33
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Good.",
			},
			# 34
			{
				"speaker": "John Toda",
				"text": "So, where are we headed this time?",
			},
			# 35
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "I don't know.",
			},
			# 36
			{
				"speaker": "John Toda",
				"text": "You don't know?",
			},
			# 37
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Just drive around town again. Anywhere's fine.",
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "Uh... Alright.",
			},
			# 39
			{
				"text": "I start the engine and pull away from the station.",
			},
			# 40
			{
				"text": "The passenger leans back into his seat.",
			},
			# 41
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 42
			{
				"text": "Well, as long as he's paying...",
				"actions": [
					{
						"type": "set_event_value",
						"id": "gardo_first_encounter_seen",
						"value": true,
					},
					{
						"type": "start_special_stage",
						"id": "gardo_extra_lap",
					},
				],
				"next_index": STORY_END,
			},
			# 43 - REFUSE
			{
				"speaker": "John Toda",
				"text": "Sorry, sir. I can't do that. It's already pretty late.",
			},
			# 44
			{
				"text": "The passenger clicks his tongue.",
			},
			# 45
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Tch.",
			},
			# 46
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "...",
			},
			# 47
			{
				"text": "For a moment, he looks like he's about to argue.",
			},
			# 48
			{
				"text": "But instead, he lets out a sigh.",
			},
			# 49
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "I see.",
			},
			# 50
			{
				"text": "He reaches into his pocket, takes out his wallet, and hands me the fare.",
			},
			# 51
			{
				"speaker": "Gardo",
				"speaker_display_name": "???",
				"text": "Here.",
			},
			# 52
			{
				"speaker": "John Toda",
				"text": "Thank you, sir.",
			},
			# 53
			{
				"text": "He steps out of the tricycle without another word.",
			},
			# 54
			{
				"text": "I prepare to leave, but something catches my eye.",
			},
			# 55
			{
				"text": "The man hasn't gone anywhere.",
			},
			# 56
			{
				"text": "Instead, he walks over to one of the empty benches at the station and takes a seat.",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "gardo_seated",
						"texture": StoryConstants.SPRITE_GARDO_MIDNIGHT,
						"background_region": [214, 396, 133, 161],
					},
				],
			},
			# 57
			{
				"text": "He checks his watch again.",
				"speaker_portraits": false,
			},
			# 58
			{
				"text": "Then he just sits there, staring at nothing in particular.",
				"speaker_portraits": false,
			},
			# 59
			{
				"speaker": "John Toda",
				"text": "...",
				"speaker_portraits": false,
			},
			# 60
			{
				"speaker": "John Toda",
				"text": "What's with him?",
				"speaker_portraits": false,
			},
			# 61
			{
				"text": "Well, not really my business.",
				"speaker_portraits": false,
			},
			# 62
			{
				"text": "I start the engine and head home.",
				"background": StoryConstants.BACKGROUND_STREET_NIGHT,
				"background_fade": 0.28,
				"speaker_portraits": false,
				"portraits": [],
			},
			# 63
			{
				"text": "The roads are quieter now. Most of the shops have already closed, and only a handful of streetlights illuminate the way.",
			},
			# 64
			{
				"text": "By the time I reach home, I can barely keep my eyes open.",
				"background": StoryConstants.BACKGROUND_INHOUSE_NIGHT,
				"background_fade": 0.28,
			},
			# 65
			{
				"text": "Still, for some reason, I find myself thinking about that passenger.",
			},
			# 66
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 67
			{
				"text": "What was he waiting for, anyway?",
				"actions": [
					{
						"type": "set_event_value",
						"id": "gardo_first_encounter_seen",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "gardo_midnight_encounter_boost",
						"value": true,
					},
					{
						"type": "return_to",
						"destination": "home",
					},
				],
				"next_index": STORY_END,
			},
		],
	})
