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
				"text": "to be translated",
			},
			# 1
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 2
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 3
			{
				"text": "to be translated",
			},
			# 4
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 6
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 7
			{
				"text": "to be translated",
			},
			# 8
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"next_index": ACCEPTED_INITIAL_OFFER,
			},
			# 10 - ACCEPTED_INITIAL_OFFER
			{
				"speaker": "Alma",
				"text": "to be translated",
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
				"text": "to be translated",
			},
			# 12
			{
				"speaker": "Alma",
				"text": "to be translated",
			},
			# 13
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 14
			{
				"text": "to be translated",
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
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 17
			{
				"speaker": "Alma",
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
						"type": "set_event_value",
						"id": "alma_special_delivery_seen",
						"value": true,
					},
				],
			},
		],
	})
