extends RefCounted

# Keep the speaker API while sharing character identity and sprite variants.
const CharacterSprites := preload("res://scripts/story/story_character_sprites.gd")


static func for_speaker(speaker: String, sprite := "default") -> Array:
	return CharacterSprites.for_speaker(speaker, sprite)
