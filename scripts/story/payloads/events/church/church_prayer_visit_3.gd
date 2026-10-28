extends RefCounted

const StoryPayload := preload("res://scripts/story/story_payload.gd")


static func build() -> Dictionary:
	return StoryPayload.normalize({
		"story_id": "church_prayer_visit_3",
		"chapter_title": "Prayer",
		"speaker_portraits": false,
		"background": "res://assets/story/backgrounds/churchday.png",
		"music": {},
		"ambient_sfx": {
			"loop": true,
			"path": "res://assets/audio/ambience/church.mp3",
			"volume_db": -8.0,
		},
		"composition": [
			# 0
			{
				"text": "I went inside the church.",
			},
			# 1
			{
				"text": "I prayed.",
			},
			# 2
			{
				"text": "There were quite a few things I wanted to ask for.",
			},
			# 3
			{
				"text": "Where do I even begin?",
			},
		],
	})
