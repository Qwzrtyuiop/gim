extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const HELP := 6
const DECLINE := 17
const STORY_END := 25


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "bayanihan",
		"chapter_title": "Bayanihan",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "While driving down the road, I notice a tricycle parked by the roadside. Its driver is standing beside it, looking troubled.",
			},
			# 1
			{
				"speaker": "Driver",
				"text": "Hey! Boss! Hold on a second!",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "Hm? What's wrong?",
			},
			# 3
			{
				"speaker": "Driver",
				"text": "I ran out of gas. The gas station isn't that far, but this thing's too heavy to push alone.",
			},
			# 4
			{
				"speaker": "Driver",
				"text": "Mind giving me a hand?",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Ah...",
				"choices": [
					{
						"text": "\"Sure, I'll help.\"\nWarning: You will lose one turn.",
						"next_index": HELP,
					},
					{
						"text": "\"Sorry, I'm busy.\"",
						"next_index": DECLINE,
					},
				],
			},
			# 6 — HELP
			{
				"speaker": "John Toda",
				"text": "Alright, I'll help you.",
			},
			# 7
			{
				"speaker": "Driver",
				"text": "Great! Thanks, boss!",
			},
			# 8
			{
				"text": "I park my tricycle somewhere safe and help him push his toward the gas station.",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "Man, this thing's heavy...",
			},
			# 10
			{
				"speaker": "Driver",
				"text": "Sorry about that. I thought I had enough gas to make it.",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "Next time, check your tank.",
			},
			# 12
			{
				"speaker": "Driver",
				"text": "Yeah, I really should. Haha!",
			},
			# 13
			{
				"text": "After a few minutes of pushing, we finally reach the gas station.",
			},
			# 14
			{
				"speaker": "Driver",
				"text": "Thanks a lot, boss. You really saved me there!",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "Don't mention it. Take care.",
			},
			# 16
			{
				"text": "I return to my tricycle and continue driving.",
				"actions": [
					{
						"type": "resolve_bayanihan",
						"outcome": "help",
					},
				],
				"next_index": STORY_END,
			},
			# 17 — DECLINE
			{
				"speaker": "John Toda",
				"text": "Sorry, boss. I've got somewhere to be.",
			},
			# 18
			{
				"speaker": "Driver",
				"text": "Oh, is that so? Alright, no problem.",
			},
			# 19
			{
				"speaker": "John Toda",
				"text": "The gas station's pretty close, right?",
			},
			# 20
			{
				"speaker": "Driver",
				"text": "Yeah. I think I can manage.",
			},
			# 21
			{
				"speaker": "John Toda",
				"text": "Alright. Take care.",
			},
			# 22
			{
				"text": "I drive past him. In my side mirror, I can see the driver slowly pushing his tricycle along the roadside.",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 24
			{
				"text": "I continue on my way.",
				"actions": [
					{
						"type": "resolve_bayanihan",
						"outcome": "decline",
					},
				],
				"next_index": STORY_END,
			},
		],
	})
