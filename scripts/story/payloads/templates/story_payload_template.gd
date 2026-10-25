extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryConstants := preload("res://scripts/story/story_constants.gd")

# Zero-based section targets. Keep these aligned with the composition below.
const AGREE := 6
const DECLINE := 7
const FINISH := 8

# Copy this file for a new story. See ../../story_payloads_guide.md.
# Sprite variants: a Magda line can use "sprite": "alt"; use "default" to reset.
# Choices can run {"type": "set_character_sprite", "character_id": "magda", "sprite": "alt"}.


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "template_story_id",
		"chapter_title": "Template Story",
		"speaker_portraits": true,
		"background": StoryConstants.BACKGROUND_INHOUSE,
		"music": StoryConstants.STATION_MUSIC,
		"composition": [
			# 0
			# Narration with a background transition.
			{
				"text": "Narration line goes here.",
				"background": StoryConstants.BACKGROUND_INHOUSE,
				"background_fade": 0.28,
				"pause_before": 0.16,
			},
			# 1
			# Explicit portraits persist until replaced; [] clears them. Special CGs hide portraits.
			{
				"speaker": "John Toda",
				"text": "Dialogue line goes here.",
				"portraits": [
					{
						"id": "john",
						"texture": "res://assets/characters/John.png",
						"position": "left",
						"height": 300,
					},
					{
						"id": "benny",
						"texture": "res://assets/characters/Benny.png",
						"position": "right",
						"height": 300,
						"flip_h": true,
					},
				],
			},
			# 2
			# Optional camera movement.
			{
				"text": "You can add camera motion to a line.",
				"camera": {
					"zoom": 1.05,
					"focus": "center",
					"duration": 0.4,
				},
			},
			# 3
			# Actions run in order.
			{
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
			# 4
			# Choices jump to the named sections above.
			{
				"text": "What should John do?",
				"choices": [
					{
						"text": "Agree",
						"next_index": AGREE,
					},
					{
						"text": "Refuse",
						"next_index": DECLINE,
					},
				],
			},
			# 5
			# Unused filler retained so saved section indices stay stable.
			{
				"text": "Unused filler line. Replace this while wiring your own branches.",
				"next_index": FINISH,
			},
			# 6 — AGREE
			# Agree branch; its final jump skips the decline branch.
			{
				"speaker": "John Toda",
				"text": "Alright, I'll go.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "template_choice",
						"value": "agree",
					},
				],
				"next_index": FINISH,
			},
			# 7 — DECLINE
			# Decline branch.
			{
				"speaker": "John Toda",
				"text": "Not tonight.",
				"actions": [
					{
						"type": "set_event_value",
						"id": "template_choice",
						"value": "refuse",
					},
				],
				"next_index": FINISH,
			},
			# 8 — FINISH
			# The scene finishes naturally after the final line.
			{
				"text": "The scene ends here.",
			},
		],
	})
