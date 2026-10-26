extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Append future sections to preserve saved indices.
const STORY_END := 51


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "hana_second_encounter",
		"chapter_title": "Lost ID 2",
		"speaker_portraits": true,
		"return_scene": "res://scenes/ride_selection.tscn",
		"next_scene": "res://scenes/ride_selection.tscn",
		"background": StoryConstants.BACKGROUND_TERMINAL_NIGHT if PlayerState.get_current_time_of_day() == "night" else StoryConstants.BACKGROUND_TERMINAL,
		"music": StoryConstants.STATION_MUSIC,
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
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 5
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 6
			{
				"text": "to be translated",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 8
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 9
			{
				"text": "to be translated",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "hana_id",
						"texture": StoryConstants.ITEM_HANA_ID,
						"position": "center",
						"height": 300,
					},
				],
			},
			# 10
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 11
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 12
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 13
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 14
			{
				"text": "to be translated",
				"speaker_portraits": true,
				"portraits": [],
				"actions": [
					{
						"type": "set_event_value",
						"id": "hana_has_id_card",
						"value": false,
					},
					{
						"type": "set_event_value",
						"id": "hana_id_card_returned",
						"value": true,
					},
				],
			},
			# 15
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 16
			{
				"speaker": "John Toda",
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
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 20
			{
				"text": "to be translated",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "hana_id",
						"texture": StoryConstants.ITEM_HANA_ID,
						"position": "center",
						"height": 300,
					},
				],
			},
			# 21
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 23
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 24
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 25
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 26
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 27
			{
				"text": "to be translated",
				"speaker_portraits": true,
				"portraits": [],
			},
			# 28
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 30
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 32
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 33
			{
				"text": "to be translated",
			},
			# 34
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 35
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 36
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "to be translated",
			},
			# 37
			{
				"text": "to be translated",
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 39
			{
				"text": "to be translated",
			},
			# 40
			{
				"text": "to be translated",
			},
			# 41
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 42
			{
				"text": "to be translated",
				"speaker_portraits": false,
				"portraits": [
					{
						"id": "hana_notebook",
						"texture": StoryConstants.ITEM_HANA_NOTEBOOK,
						"position": "center",
						"height": 300,
					},
				],
				"actions": [
					{
						"type": "play_music",
						"path": StoryConstants.MUSIC_FUNNY,
						"loop": true,
						"fade_in": 0,
						"fade_out": 0,
						"volume_db": -9,
					},
				],
			},
			# 43
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 44
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 45
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 46
			{
				"speaker": "John Toda",
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 47
			{
				"text": "to be translated",
				"speaker_portraits": false,
			},
			# 48
			{
				"text": "to be translated",
				"speaker_portraits": true,
				"portraits": [],
				"actions": [
					{
						"type": "set_event_value",
						"id": "hana_has_notebook",
						"value": true,
					},
				],
			},
			# 49
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 50
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "hana_second_encounter_seen",
						"value": true,
					},
				],
				"next_index": STORY_END,
			},
		],
	})
