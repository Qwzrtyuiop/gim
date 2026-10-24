extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "malasakit_epilogue",
		"chapter_title": "Malasakit — Epilogue",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STATION,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			{
				"text": "One day, while I was taking a break.",
			},
			# 1
			{
				"speaker": "Passenger",
				"text": "Hello there.",
			},
			# 2
			{
				"text": "A familiar passenger walked toward me.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "Hey there, did you forget your wallet today too?",
			},
			# 4
			{
				"text": "I said jokingly.",
			},
			# 5
			{
				"speaker": "Passenger",
				"text": "Fortunately, not today.",
			},
			# 6
			{
				"text": "The passenger brought out money.",
			},
			# 7
			{
				"speaker": "Passenger",
				"text": "Here, payment for the last time.",
			},
			# 8
			{
				"text": "I take the payment from the passenger.",
			},
			# 9
			{
				"text": "They thanked me once more before they left.",
				"actions": [
					{
						"type": "repay_malasakit_fare",
					},
				],
			},
		],
	})
