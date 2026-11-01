extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "basketball_empty",
		"chapter_title": "Empty Court",
		"speaker_portraits": false,
		"background": StoryConstants.BACKGROUND_BASKETBALL_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_BASKETBALL_DAY,
		"music": {},
		"basketball_players": false,
		"composition": [
			# 0
			{
				"text": "I went to the basketball court.",
			},
			# 1
			{
				"text": "There wasn't anyone playing today.",
			},
			# 2
			{
				"text": "Huh. That's rare.",
			},
			# 3
			{
				"text": "I found a place to sit and rested for a while.",
			},
			# 4
			{
				"text": "Not a bad place to spend some time.",
				"actions": [
					{
						"type": "relieve_stress",
						"amount": GameTuning.BASKETBALL_EMPTY_STRESS_RELIEF,
					},
				],
			},
		],
	})
