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
				"text": "I went to the basketball court.",
			},
			# 1
			{
				"text": "A group of players was gathering near the court.",
			},
			# 2
			{
				"speaker": "Player",
				"text": "Hey! Wanna join? We need another guy.",
			},
			# 3
			{
				"speaker": "John Toda",
				"text": "Sure, I guess.",
			},
			# 4
			{
				"speaker": "Player",
				"text": "Oh, by the way, we've got a little bet going on.",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "A bet?",
			},
			# 6
			{
				"speaker": "Player",
				"text": "Yeah. Just a few pesos. Nothing serious.",
			},
			# 7
			{
				"text": "...",
			},
			# 8
			{
				"text": "Why am I only hearing about this now?",
			},
			# 9
			{
				"speaker": "Player",
				"text": "Don't worry! We've already put the money in. Just help us win!",
			},
			# 10
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
			# 11 — JOIN
			{
				"text": "I joined the game.",
				"next_index": WIN,
			},
			# 12 — WIN
			{
				"text": "We won.",
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
				"text": "YES! THAT'S WHAT I'M TALKING ABOUT!",
			},
			# 14
			{
				"text": "The others erupted into cheers.",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "Hah... Good game.",
			},
			# 16
			{
				"speaker": "Player",
				"text": "Here, man! Your share!",
			},
			# 17
			{
				"text": "He handed me a few bills.",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "Oh. Thanks.",
			},
			# 19
			{
				"text": "I wasn't expecting to get paid for that.",
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
				"text": "We lost.",
			},
			# 21
			{
				"text": "And judging by everyone's faces, they weren't particularly happy about it.",
			},
			# 22
			{
				"speaker": "Player",
				"text": "Aw, come on! We almost had them!",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "Sorry. That last shot was my fault.",
			},
			# 24
			{
				"speaker": "Player",
				"text": "Nah, don't worry about it.",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 26
			{
				"text": "He says that, but I did just cost them forty pesos.",
			},
			# 27
			{
				"text": "Maybe I should've stayed on the bench.",
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
				"text": "Sorry. I'll pass.",
			},
			# 29
			{
				"speaker": "Player",
				"text": "Aw, come on! Alright, next time.",
			},
			# 30
			{
				"text": "I think I'll leave this one to them.",
				"next_index": STORY_END,
			},
		],
	})
