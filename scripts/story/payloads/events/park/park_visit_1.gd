extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "park_visit_1",
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
				"text": "It's been a while since I last came here.",
			},
			# 2
			{
				"text": "I found an empty bench and sat down.",
			},
			# 3
			{
				"text": "There wasn't anything in particular I wanted to do.",
			},
			# 4
			{
				"text": "Well, I guess that's the point.",
			},
			# 5
			{
				"text": "I decided to stay for a bit.",
			},
		],
	})
