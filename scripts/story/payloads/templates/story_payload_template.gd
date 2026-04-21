extends RefCounted

# Copy this file when creating a new story payload.
# build() returns the Dictionary consumed by story_scene.gd.

const StoryConstants := preload("res://scripts/story/story_constants.gd")


static func build() -> Dictionary:
	return {
		"story_id": "template_story_id",
		"chapter_title": "Template Story",

		# Optional scene defaults.
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"music": {
			"type": "play_music",
			"path": StoryConstants.MUSIC_CITY_AMBIENCE,
			"loop": true,
			"fade_in": 0.55,
			"volume_db": -9.0,
		},

		# StoryScene reads composition first, then sections, then lines.
		"composition": [
			{
				# Basic narration line with a background transition.
				"background": StoryConstants.BACKGROUND_INHOUSE,
				"background_fade": 0.28,
				"pause_before": 0.16,
				"text": "Narration line goes here.",
			},
			{
				# Speaker line.
				"speaker": "John Toda",
				"text": "Dialogue line goes here.",
			},
			{
				# Optional background camera motion.
				"text": "You can add camera motion to a line.",
				"camera": {
					"zoom": 1.05,
					"focus": "center",
					"duration": 0.4,
				},
			},
			{
				# Actions must be an Array of Dictionaries.
				"text": "...",
				"actions": [
					{
						"type": "play_sfx",
						"path": StoryConstants.MUSIC_RUNNING_SFX,
						"volume_db": -4.0,
					},
					{
						"type": "wait",
						"duration": 0.5,
					},
					{
						"type": "set_background",
						"background": StoryConstants.BACKGROUND_STORYDOOR,
					},
				],
			},
			{
				# choices must also be an Array of Dictionaries.
				"text": "What should John do?",
				"choices": [
					{
						"text": "Agree",
						"next_index": 6,
					},
					{
						"text": "Refuse",
						"next_index": 7,
					},
				],
			},
			{
				# Placeholder line so the sample next_index values above resolve cleanly.
				"text": "Unused filler line. Replace this while wiring your own branches.",
				"next_index": 8,
			},
			{
				# Branch A.
				"speaker": "John Toda",
				"text": "Alright, I'll go.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "template_choice",
						"value": "agree",
					},
				],
				"next_index": 8,
			},
			{
				# Branch B.
				"speaker": "John Toda",
				"text": "Not tonight.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "template_choice",
						"value": "refuse",
					},
				],
				"next_index": 8,
			},
			{
				# End line. If you omit next_index here, StoryScene finishes naturally.
				"text": "The scene ends here.",
			},
		],

		# Optional testing hooks.
		# Usually return_scene / next_scene are injected by trigger code instead.
		# "return_scene": "res://scenes/stage_results.tscn",
		# "next_scene": "res://scenes/stage_results.tscn",
	}
