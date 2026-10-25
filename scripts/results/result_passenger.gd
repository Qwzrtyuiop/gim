extends RefCounted

const CharacterSprites := preload("res://scripts/story/story_character_sprites.gd")
const PLACEHOLDER := preload("res://assets/characters/placeholder.png")


static func resolve(result: Dictionary, current_character: Dictionary = {}) -> Dictionary:
	# Completed rides retain their own identity even if a subsequent event changes
	# the selected passenger. Only older results without that field use the current
	# character supplied by the coordinator.
	var character_id := str(result.get("character_id", current_character.get("id", ""))).strip_edges().to_lower()
	var canonical_id := CharacterSprites.canonical_character_id(character_id)
	if not canonical_id.is_empty():
		character_id = canonical_id
	var character: Dictionary = PlayerState.get_character_by_id(character_id)
	var is_generic := bool(character.get("is_generic", false))
	var texture: Texture2D = PLACEHOLDER
	var is_placeholder := true
	if not character.is_empty() and not is_generic:
		var path := CharacterSprites.texture_path(character_id)
		if not path.is_empty():
			texture = load(path) as Texture2D
			is_placeholder = texture == null
			if is_placeholder:
				texture = PLACEHOLDER
	return {
		"character_id": character_id,
		"name": PlayerState.get_character_display_name(character_id) if not character.is_empty() else "Passenger",
		"texture": texture,
		"is_generic": is_generic,
		"is_placeholder": is_placeholder,
	}
