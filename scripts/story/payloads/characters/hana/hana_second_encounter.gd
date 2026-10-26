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
				"text": "I spot a familiar girl standing near the station.",
			},
			# 1
			{
				"text": "Oh, it's her.",
			},
			# 2
			{
				"text": "I almost forgot.",
			},
			# 3
			{
				"text": "I approach her.",
			},
			# 4
			{
				"speaker": "John Toda",
				"text": "Hey, miss.",
			},
			# 5
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Hm?",
			},
			# 6
			{
				"text": "She looks up at me, then lowers her gaze.",
			},
			# 7
			{
				"speaker": "John Toda",
				"text": "You're Hana, right?",
			},
			# 8
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Huh? How did you—",
			},
			# 9
			{
				"text": "I pull out the ID card from my pocket.",
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
				"text": "You dropped this in my tricycle the other day.",
				"speaker_portraits": false,
			},
			# 11
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "AH!",
				"speaker_portraits": false,
			},
			# 12
			{
				"text": "Her face immediately brightens.",
				"speaker_portraits": false,
			},
			# 13
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "You found it!",
				"speaker_portraits": false,
			},
			# 14
			{
				"text": "She practically snatches it from my hand.",
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
				"text": "Oh, thank goodness! I thought I'd lost it forever!",
			},
			# 16
			{
				"speaker": "John Toda",
				"text": "Uh... You're welcome.",
			},
			# 17
			{
				"text": "Is she really that happy over an ID?",
			},
			# 18
			{
				"speaker": "John Toda",
				"text": "You know, you could've just gotten a new one.",
			},
			# 19
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Hm? Oh, it's not the ID.",
			},
			# 20
			{
				"text": "She holds up the little keychain attached to it.",
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
				"text": "It's this!",
				"speaker_portraits": false,
			},
			# 22
			{
				"speaker": "John Toda",
				"text": "A keychain?",
				"speaker_portraits": false,
			},
			# 23
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Yeah! My sister gave it to me.",
				"speaker_portraits": false,
			},
			# 24
			{
				"speaker": "John Toda",
				"text": "Oh.",
				"speaker_portraits": false,
			},
			# 25
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "I've had it for years, so I was really upset when I lost it.",
				"speaker_portraits": false,
			},
			# 26
			{
				"speaker": "John Toda",
				"text": "I see.",
				"speaker_portraits": false,
			},
			# 27
			{
				"text": "She looks at the keychain for a moment before turning back to me.",
				"speaker_portraits": true,
				"portraits": [],
			},
			# 28
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Anyway, thank you so much, mister!",
			},
			# 29
			{
				"speaker": "John Toda",
				"text": "It's nothing.",
			},
			# 30
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Oh, right! What's your name?",
			},
			# 31
			{
				"speaker": "John Toda",
				"text": "John. John Toda.",
			},
			# 32
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "John Toda...",
			},
			# 33
			{
				"text": "She repeats my name quietly under her breath.",
			},
			# 34
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Got it! Thanks again, Mr. Toda!",
			},
			# 35
			{
				"speaker": "John Toda",
				"text": "Sure.",
			},
			# 36
			{
				"speaker": "Hana",
				"speaker_display_name": "Hana",
				"text": "Well, see you around!",
			},
			# 37
			{
				"text": "She waves goodbye before hurrying off.",
			},
			# 38
			{
				"speaker": "John Toda",
				"text": "...",
			},
			# 39
			{
				"text": "She sure is energetic.",
			},
			# 40
			{
				"text": "As I turn to head back to my tricycle, I notice something lying on the ground.",
			},
			# 41
			{
				"speaker": "John Toda",
				"text": "Hm?",
			},
			# 42
			{
				"text": "It's a notebook.",
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
				"text": "I pick it up and glance toward the direction she went.",
				"speaker_portraits": false,
			},
			# 44
			{
				"text": "She's already gone.",
				"speaker_portraits": false,
			},
			# 45
			{
				"speaker": "John Toda",
				"text": "...",
				"speaker_portraits": false,
			},
			# 46
			{
				"speaker": "John Toda",
				"text": "You've got to be kidding me.",
				"speaker_portraits": false,
			},
			# 47
			{
				"text": "Does this girl have a habit of dropping things?",
				"speaker_portraits": false,
			},
			# 48
			{
				"text": "I let out a sigh and slip the notebook into my bag.",
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
				"text": "Guess I'll have to return this one too.",
			},
			# 50
			{
				"text": "I return to my tricycle.",
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
