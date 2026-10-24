extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Copy and register a localized pair to enable an actual event.
# This example is not registered and does not change normal gameplay.
const REST := 1
const SUPPLIES := 2
const LEAVE := 3
const STORY_END := 4


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "gameplay_event_template",
		"chapter_title": "Event Controls Example",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0 — Safe fallback when every conditional choice is locked.
			{
				"speaker": "John Toda",
				"text": "How should I spend this time?",
				"choices": [
					{
						"text": "Take a day to recover",
						"next_index": REST,
					},
					{
						"text": "Buy supplies (PhP 100)",
						"conditions": {
							"min_money": 100,
						},
						"show_locked": true,
						"locked_reason": "John needs at least PhP 100.",
						"next_index": SUPPLIES,
					},
					{
						"text": "Head to the station",
						"next_index": LEAVE,
					},
				],
				"next_index": LEAVE,
			},
			# 1 — REST: crossed dates still collect debt and update daily state.
			{
				"text": "A day passes. John feels rested.",
				"actions": [
					{
						"type": "advance_time",
						"days": 1,
						"restore_energy": true,
					},
					{
						"type": "increment_event_value",
						"id": "example_rest_days",
					},
				],
				"next_index": STORY_END,
			},
			# 2 — SUPPLIES: existing and new actions can be mixed in order.
			{
				"text": "John stocks up, then checks the shop.",
				"actions": [
					{
						"type": "spend_money",
						"amount": 100,
					},
					{
						"type": "add_gas",
						"amount": 10,
					},
					{
						"type": "restore_energy",
						"amount": 2,
					},
					{
						"type": "return_to",
						"destination": "store",
					},
				],
				"next_index": STORY_END,
			},
			# 3 — LEAVE: the current time slot is used at passenger selection.
			{
				"text": "There may still be passengers waiting.",
				"actions": [
					{
						"type": "return_to",
						"destination": "ride_selection",
					},
				],
				"next_index": STORY_END,
			},
		],
	})
