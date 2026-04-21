extends RefCounted

const StoryConstants := preload("res://scripts/story/story_constants.gd")

static func build() -> Dictionary:
	return {
		"story_id": "scene_03_day7_night",
		"chapter_title": "Scene 3",
		"background": StoryConstants.BACKGROUND_STORYDOOR,
		"composition": [
			{
				"background": StoryConstants.BACKGROUND_STORYDOOR,
				"background_fade": 0.28,
				"pause_before": 0.18,
				"text": "test.",
			},
			{
				"text": "test.",
			},
			{
				"text": "test.",
			},
		],
	}
