extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")

const JOIN := 8
const WIN := 10
const LOSE := 15
const DECLINE := 20
const STORY_END := 24


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "basketball_pickup",
		"chapter_title": "Pickup Game",
		"speaker_portraits": false,
		"background": StoryConstants.BACKGROUND_BASKETBALL_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_BASKETBALL_DAY,
		"music": {},
		"basketball_players": true,
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
				"speaker": "Player",
				"text": "to be translated",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 5
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 6
			{
				"text": "to be translated",
			},
			# 7
			{
				"text": "to be translated",
				"choices": [
					{
						"text": "to be translated",
						"next_index": JOIN,
					},
					{
						"text": "to be translated",
						"next_index": DECLINE,
					},
				],
			},
			# 8 — JOIN
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 9
			{
				"text": "to be translated",
				"next_index": WIN,
			},
			# 10 — WIN
			{
				"text": "to be translated",
				"conditions": {
					"required_event_values": {
						"basketball_game_won": true,
					},
				},
				"skip_index": LOSE,
			},
			# 11
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 13
			{
				"text": "to be translated",
			},
			# 14
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "relieve_stress",
						"amount": GameTuning.BASKETBALL_WIN_STRESS_RELIEF,
					},
				],
				"next_index": STORY_END,
			},
			# 15 — LOSE
			{
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 18
			{
				"text": "to be translated",
			},
			# 19
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "relieve_stress",
						"amount": GameTuning.BASKETBALL_LOSS_STRESS_RELIEF,
					},
				],
				"next_index": STORY_END,
			},
			# 20 — DECLINE
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 21
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 22
			{
				"text": "to be translated",
			},
			# 23
			{
				"text": "to be translated",
				"next_index": STORY_END,
			},
		],
	})
