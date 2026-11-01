extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")

const JOIN := 11
const WIN := 12
const LOSE := 20
const DECLINE := 28
const STORY_END := 31


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "basketball_wager",
		"chapter_title": "A Friendly Wager",
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
				"speaker": "Player",
				"text": "to be translated",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 4
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 6
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 7
			{
				"text": "to be translated",
			},
			# 8
			{
				"text": "to be translated",
			},
			# 9
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 10
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
			# 11 — JOIN
			{
				"text": "to be translated",
				"next_index": WIN,
			},
			# 12 — WIN
			{
				"text": "to be translated",
				"conditions": {
					"required_event_values": {
						"basketball_game_won": true,
					},
				},
				"skip_index": LOSE,
			},
			# 13
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 14
			{
				"text": "to be translated",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 17
			{
				"text": "to be translated",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 19
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "add_money",
						"amount": GameTuning.BASKETBALL_WAGER_WIN_REWARD,
					},
					{
						"type": "relieve_stress",
						"amount": GameTuning.BASKETBALL_WIN_STRESS_RELIEF,
					},
				],
				"next_index": STORY_END,
			},
			# 20 — LOSE
			{
				"text": "to be translated",
			},
			# 21
			{
				"text": "to be translated",
			},
			# 22
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 24
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 26
			{
				"text": "to be translated",
			},
			# 27
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "add_stress",
						"amount": GameTuning.BASKETBALL_WAGER_LOSS_STRESS,
					},
				],
				"next_index": STORY_END,
			},
			# 28 — DECLINE
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 29
			{
				"speaker": "Player",
				"text": "to be translated",
			},
			# 30
			{
				"text": "to be translated",
				"next_index": STORY_END,
			},
		],
	})
