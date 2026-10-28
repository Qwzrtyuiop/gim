extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Keep section 1 as the completion target for saved placeholder encounters.
const INTRODUCTION := 2
const NOT_VISITED_BAR := 28
const VISITED_BAR := 31
const COMMON := 36
const STORY_END := 57


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "alma_first_encounter",
		"chapter_title": "Small World",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.street_background(str(PlayerState.get_last_stage_result().get("time_of_day", PlayerState.get_current_time_of_day()))),
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0 - Entry; skip the legacy completion section.
			{
				"text": "We were about halfway to our destination when my passenger suddenly spoke.",
				"next_index": INTRODUCTION,
			},
			# 1 - Legacy completion for saved placeholder encounters.
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "...",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_first_encounter_seen",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "alma_name_revealed",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 2 - INTRODUCTION
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Hey, Mr. Tricycle Driver.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "Hm? What is it?",
			},
			# 4
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Have I seen you somewhere before?",
			},
			# 5
			{
				"text": "What?",
			},
			# 6
			{
				"text": "Is this some sort of scam?",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "No, I don't think so. I only moved back here recently.",
			},
			# 8
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Oh? So you came from the city?",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "Huh? How did you know?",
			},
			# 10
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Aha! I knew it!",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Knew what?",
			},
			# 12
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "I've seen you before! I never forget a customer's face, you see.",
			},
			# 13
			{
				"speaker": "John Toda",
				"text": "A customer?",
			},
			# 14
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Yeah. I used to work as a bartender in the city, too.",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "Oh.",
			},
			# 16
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Didn't last very long, though. And now I'm here.",
			},
			# 17
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "So I guess we're in the same boat, huh?",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "I guess...",
			},
			# 19
			{
				"text": "So she worked in the city too.",
			},
			# 20
			{
				"text": "Small world, huh.",
			},
			# 21
			{
				"text": "I tried remembering whether I'd seen her before. But I had visited quite a few bars back then, and I couldn't exactly say I remembered every bartender I'd met.",
			},
			# 22
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Oh, right. Speaking of which...",
			},
			# 23
			{
				"text": "She pulled a folded flyer from her pocket.",
			},
			# 24
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Here. This is where I'm working now.",
			},
			# 25
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Oh, right. You're driving.",
			},
			# 26
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "I'll just leave it here, then.",
			},
			# 27
			{
				"text": "She tucked the flyer into the corner of the passenger seat.",
				"next_index": NOT_VISITED_BAR,
			},
			# 28 - NOT_VISITED_BAR
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "You should drop by sometime! It's a nice place.",
				"conditions": {
					"forbidden_event_values": {
						"bar_visited": true,
					},
				},
				"skip_index": VISITED_BAR,
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "Ah. Sure. I'll think about it.",
			},
			# 30
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "You better!",
				"next_index": COMMON,
			},
			# 31 - VISITED_BAR
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Though, now that I think about it, I've already seen you there before, haven't I?",
				"conditions": {
					"required_event_values": {
						"bar_visited": true,
					},
				},
				"skip_index": COMMON,
			},
			# 32
			{
				"speaker": "John Toda",
				"text": "You have?",
			},
			# 33
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Mhm! I'm pretty sure.",
			},
			# 34
			{
				"speaker": "John Toda",
				"text": "You really don't forget faces, huh?",
			},
			# 35
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Told you!",
			},
			# 36 - COMMON
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "Anyway, I don't think we've properly introduced ourselves.",
			},
			# 37
			{
				"speaker": "Alma",
				"speaker_display_name": "???",
				"text": "My name's Alma.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_name_revealed",
						"value": true,
					},
				],
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "John. John Toda.",
			},
			# 39
			{
				"speaker": "Alma",
				"text": "John Toda, huh?",
			},
			# 40
			{
				"speaker": "Alma",
				"text": "Nice to meet you, John!",
			},
			# 41
			{
				"speaker": "John Toda",
				"text": "Nice to meet you too.",
			},
			# 42
			{
				"speaker": "Alma",
				"text": "It's nice seeing a familiar face around here. Makes the place feel a little less strange, you know?",
			},
			# 43
			{
				"speaker": "John Toda",
				"text": "I suppose.",
			},
			# 44
			{
				"text": "We're not that close, though.",
			},
			# 45
			{
				"text": "We eventually arrived at her destination.",
			},
			# 46
			{
				"speaker": "Alma",
				"text": "Well, thanks for the ride!",
			},
			# 47
			{
				"text": "She handed me the fare before getting off.",
			},
			# 48
			{
				"speaker": "Alma",
				"text": "See you around, John!",
			},
			# 49
			{
				"speaker": "John Toda",
				"text": "Yeah. Take care.",
			},
			# 50
			{
				"text": "I watched her leave before picking up the flyer she'd tucked beside the seat.",
			},
			# 51
			{
				"text": "Alma, huh.",
			},
			# 52
			{
				"text": "I still couldn't remember seeing her in the city.",
			},
			# 53
			{
				"text": "Then again, I suppose that's not surprising.",
			},
			# 54
			{
				"text": "I folded the flyer and slipped it into my pocket.",
			},
			# 55
			{
				"text": "Well, at least now I know where she works.",
			},
			# 56
			{
				"text": "I started the engine and returned to work.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_first_encounter_seen",
						"value": true,
					},
				],
			},
		],
	})
