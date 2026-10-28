extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Append future sections to preserve saved indices.


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "celina_hospital_introduction",
		"chapter_title": "A Familiar Face",
		"speaker_portraits": true,
		"return_scene": "res://scenes/day_start_scene.tscn",
		"next_scene": "res://scenes/day_start_scene.tscn",
		"background": StoryConstants.hospital_background(PlayerState.get_current_time_of_day()),
		"music": {},
		"ambient_sfx": {
			"loop": true,
			"path": StoryConstants.SFX_HOSPITAL_AMBIENCE,
			"volume_db": -14.0,
		},
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
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 5
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 6
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 7
			{
				"text": "to be translated",
			},
			# 8
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 9
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 10
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 11
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 12
			{
				"text": "to be translated",
			},
			# 13
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 14
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 15
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 16
			{
				"text": "to be translated",
			},
			# 17
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
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
			},
			# 20
			{
				"text": "to be translated",
			},
			# 21
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 22
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 23
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 24
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 25
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 26
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 27
			{
				"text": "to be translated",
			},
			# 28
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 30
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 32
			{
				"text": "to be translated",
			},
			# 33
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
			},
			# 34 - NAME REVEAL
			{
				"speaker": "Celina",
				"speaker_display_name": "???",
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_name_revealed",
						"value": true,
					},
				],
			},
			# 35
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 36
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "to be translated",
			},
			# 37
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 38
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "to be translated",
			},
			# 39
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 40
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "to be translated",
			},
			# 41
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "to be translated",
			},
			# 42
			{
				"speaker": "John Toda",
				"text": "to be translated",
			},
			# 43
			{
				"speaker": "Celina",
				"speaker_display_name": "Celina",
				"text": "to be translated",
			},
			# 44 - COMPLETE
			{
				"text": "to be translated",
				"actions": [
					{
						"type": "set_event_value",
						"id": "celina_hospital_introduction_seen",
						"value": true,
					},
					{
						"type": "set_event_value",
						"id": "celina_hospital_shop_unlocked",
						"value": true,
					},
				],
			},
		],
	})

