extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "park_visit_2",
		"chapter_title": "A Quiet Moment",
		"speaker_portraits": false,
		"background": StoryConstants.BACKGROUND_PARK_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_PARK_DAY,
		"music": {},
		"composition": [
			# 0
			{
				"text": "to be translated",
			},
			# 1
			{
				"text": "to be translated",
			},
			# 2
			{
				"text": "to be translated",
			},
			# 3
			{
				"text": "to be translated",
			},
			# 4
			{
				"text": "to be translated",
			},
		],
	})
