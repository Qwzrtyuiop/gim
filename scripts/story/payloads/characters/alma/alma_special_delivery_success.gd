extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

const ACCEPTED_INITIAL_OFFER := 10
const REFUSED_INITIAL_OFFER := 15
const STORY_END := 20


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "alma_special_delivery_success",
		"chapter_title": "Special Delivery",
		"speaker_portraits": true,
		"return_scene": "res://scenes/stage_results.tscn",
		"next_scene": "res://scenes/stage_results.tscn",
		"background": StoryConstants.BACKGROUND_BAR,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_BAR,
			"loop": true,
			"fade_in": 0.35,
			"volume_db": -9.0,
		},
		"ambient_sfx": {
			"path": StoryConstants.MUSIC_BAR_SFX,
			"loop": true,
			"volume_db": -14.0,
		},
		"composition": [
			# 0
			{
				"text": "When we returned to the bar, Alma hurriedly brought the case of beer.",
			},
			# 1
			{
				"speaker": "Alma",
				"text": "We made it!",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "And we didn't get caught by the police.",
			},
			# 3
			{
				"text": "Luckily the special guests havent arrived yet.",
			},
			# 4
			{
				"speaker": "Alma",
				"text": "Thank you, John! Seriously, you saved us!",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "Just make sure your manager doesn't forget the next delivery.",
			},
			# 6
			{
				"speaker": "Alma",
				"text": "Ahaha... I'll tell him.",
			},
			# 7
			{
				"text": "She hands me the payment.",
			},
			# 8
			{
				"speaker": "Alma",
				"text": "Here! As promised.",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "Thanks.",
				"next_index": ACCEPTED_INITIAL_OFFER,
			},
			# 10 - ACCEPTED_INITIAL_OFFER
			{
				"speaker": "Alma",
				"text": "Oh, and don't forget! Ten percent off whenever you buy something here!",
				"conditions": {
					"required_event_values": {
						"alma_delivery_initial_choice": "accept",
					},
				},
				"skip_index": REFUSED_INITIAL_OFFER,
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "You're actually going through with that?",
			},
			# 12
			{
				"speaker": "Alma",
				"text": "A promise is a promise!",
			},
			# 13
			{
				"speaker": "John Toda",
				"text": "Well, I won't complain.",
			},
			# 14
			{
				"text": "Unlocked: 10% Discount at Alma's Bar",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_bar_discount_unlocked",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "alma_special_delivery_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
			# 15 - REFUSED_INITIAL_OFFER
			{
				"speaker": "Alma",
				"text": "Sorry for dragging you into all this, by the way.",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "You really weren't going to let me leave, were you?",
			},
			# 17
			{
				"speaker": "Alma",
				"text": "Ehehe...",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 19
			{
				"text": "I'll take that as a no.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "alma_special_delivery_seen",
						"value": true,
					},
				],
			},
		],
	})
