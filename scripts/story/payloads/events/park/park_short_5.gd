extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "park_short_5",
		"chapter_title": "A Quiet Moment",
		"speaker_portraits": false,
		"background": StoryConstants.BACKGROUND_PARK_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_PARK_DAY,
		"music": {},
		"composition": [
			# 0
			{
				"text": "I went to the park.",
			},
			# 1
			{
				"text": "I leaned back against the bench.",
			},
			# 2
			{
				"text": "I could fall asleep here.",
			},
			# 3
			{
				"text": "...",
			},
			# 4
			{
				"text": "Better not.",
			},
		],
	})
