extends RefCounted

# Sprite choices belong to the active story and its saved presentation state.
const Sprites := preload("res://scripts/story/story_character_sprites.gd")


static func initialize(owner, saved_state: Dictionary) -> void:
	owner.character_sprites = normalize_choices(owner.story_payload.get("character_sprites", {}))
	owner.character_sprites.merge(normalize_choices(saved_state.get("character_sprites", {})), true)


static func normalize_choices(raw_choices) -> Dictionary:
	var choices: Dictionary = {}
	if not raw_choices is Dictionary:
		return choices
	for character in raw_choices:
		var key := Sprites.canonical_character_id(str(character))
		var sprite := str(raw_choices[character]).strip_edges().to_lower()
		if Sprites.is_valid(key, sprite):
			choices[key] = sprite
	return choices


static func for_speaker(owner, speaker: String, placement := "portrait") -> Array:
	var key := Sprites.canonical_character_id(speaker)
	var entries: Array = Sprites.for_speaker(speaker, str(owner.character_sprites.get(key, "default")))
	if placement == "background":
		for entry: Dictionary in entries:
			entry["placement"] = "background"
			entry.erase("height")
	return entries


static func apply_line(owner, line: Dictionary) -> void:
	if line.has("sprite") and line.sprite is String:
		set_sprite(owner, str(line.get("speaker", "")), line.sprite)


static func set_sprite(owner, character: String, sprite: String) -> bool:
	var key := Sprites.canonical_character_id(character)
	var variant := sprite.strip_edges().to_lower()
	if not Sprites.is_valid(key, variant):
		return false
	owner.character_sprites[key] = variant
	# Update every visible instance of this character without rebuilding the cast.
	for entry: Dictionary in owner.portrait_layer.entries.duplicate(true):
		var entry_key := Sprites.canonical_character_id(str(entry.get("character_id", entry.get("id", ""))))
		if entry_key != key:
			continue
		owner.portrait_layer.set_portrait({
			"id": entry["id"],
			"character_id": key,
			"sprite": variant,
		})
	return true


static func resolve_portraits(owner, raw_entries: Array) -> Array:
	var entries: Array = []
	for raw in raw_entries:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw.duplicate(true)
		var key := Sprites.canonical_character_id(str(entry.get("character_id", entry.get("id", ""))))
		if not key.is_empty() and not _has_texture(entry):
			entry["character_id"] = key
			if not entry.has("sprite"):
				entry["sprite"] = str(owner.character_sprites.get(key, "default"))
		entries.append(entry)
	return entries


static func resolve_portrait_update(owner, data: Dictionary) -> Dictionary:
	var id := str(data.get("id", ""))
	for entry: Dictionary in owner.portrait_layer.entries:
		if str(entry.get("id", "")) != id:
			continue
		var previous_key := Sprites.canonical_character_id(str(entry.get("character_id", id)))
		var next_key := Sprites.canonical_character_id(str(data.get("character_id", entry.get("character_id", id))))
		if previous_key == next_key:
			return data
		break
	return resolve_portraits(owner, [data])[0]


static func _has_texture(entry: Dictionary) -> bool:
	return entry.has("texture") or entry.has("path") or entry.has("portrait")
