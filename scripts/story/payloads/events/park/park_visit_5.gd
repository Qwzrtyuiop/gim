extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "park_visit_5",
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
				"text": "I've been coming here quite often lately.",
			},
			# 2
			{
				"text": "Not that there's anything special about the place.",
			},
			# 3
			{
				"text": "It's just nice to have somewhere to sit without anyone expecting anything from me.",
			},
		],
	})
