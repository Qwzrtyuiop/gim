extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")

const WIN := 1
const LOSE := 2
const STORY_END := 3


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "basketball_wager_short",
		"chapter_title": "A Friendly Wager",
		"speaker_portraits": false,
		"background": StoryConstants.BACKGROUND_BASKETBALL_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_BASKETBALL_DAY,
		"music": {},
		"basketball_players": true,
		"composition": [
			# 0
			{
				"text": "Join the game with bets?",
				"choices": [
					{
						"text": "Join",
						"next_index": WIN,
					},
					{
						"text": "Decline",
						"next_index": STORY_END,
					},
				],
			},
			# 1 — WIN
			{
				"text": "We won. They gave me forty pesos.",
				"conditions": {
					"required_event_values": {
						"basketball_game_won": true,
					},
				},
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
				"skip_index": LOSE,
				"next_index": STORY_END,
			},
			# 2 — LOSE
			{
				"text": "We lost. Maybe I should've stayed on the bench.",
				"actions": [
					{
						"type": "add_stress",
						"amount": GameTuning.BASKETBALL_WAGER_LOSS_STRESS,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
