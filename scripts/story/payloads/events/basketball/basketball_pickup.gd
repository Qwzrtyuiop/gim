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
				"text": "I went to the basketball court.",
			},
			# 1
			{
				"text": "There was a game going on.",
			},
			# 2
			{
				"text": "As I approached, one of the players called out to me.",
			},
			# 3
			{
				"speaker": "Player",
				"text": "Hey, you! Wanna join? We're short one.",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "Me?",
			},
			# 5
			{
				"speaker": "Player",
				"text": "Yeah! Come on!",
			},
			# 6
			{
				"text": "It's been a while since I last played.",
			},
			# 7
			{
				"text": "Join the game?",
				"choices": [
					{
						"text": "Join",
						"next_index": JOIN,
					},
					{
						"text": "Decline",
						"next_index": DECLINE,
					},
				],
			},
			# 8 — JOIN
			{
				"speaker": "John Toda",
				"text": "Sure. Why not?",
			},
			# 9
			{
				"text": "I joined the game.",
				"next_index": WIN,
			},
			# 10 — WIN
			{
				"text": "We won.",
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
				"text": "Nice game, man!",
			},
			# 12
			{
				"speaker": "John Toda",
				"text": "Yeah. You too.",
			},
			# 13
			{
				"text": "Huh.",
			},
			# 14
			{
				"text": "I guess I haven't gotten that rusty after all.",
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
				"text": "We lost.",
			},
			# 16
			{
				"speaker": "Player",
				"text": "Ah, man. So close!",
			},
			# 17
			{
				"speaker": "John Toda",
				"text": "Yeah. Too bad.",
			},
			# 18
			{
				"text": "Well, that was fun.",
			},
			# 19
			{
				"text": "Even if we lost.",
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
				"text": "Sorry, maybe next time.",
			},
			# 21
			{
				"speaker": "Player",
				"text": "Alright, suit yourself!",
			},
			# 22
			{
				"text": "I sat nearby and watched the game instead.",
			},
			# 23
			{
				"text": "Maybe some other time.",
				"next_index": STORY_END,
			},
		],
	})
