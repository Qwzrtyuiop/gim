extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const PAYMENT_AVAILABLE := 20
const INTEREST_AVAILABLE := 35
const INTEREST_UNPAID := 38
const PAYMENT_SHORT := 43
const PAID_DEPARTURE := 51
const VIOLENT_DEPARTURE := 54
const WEEK_END := 61

# Existing placeholder; the full Tagalog translation is still pending.


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "scene_03_day7_night",
		"chapter_title": "Scene 3",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_STORYDOOR,
		"music": {},
		"composition": [
			# 0
			{
				"text": "test",
				"background": StoryConstants.BACKGROUND_STORYDOOR,
				"background_fade": 0.28,
				"pause_before": 0.18,
			},
			# 1
			{
				"text": "test",
			},
			# 2
			{
				"text": "test",
			},
		],
	})
