extends RefCounted

const CharacterSprites := preload("res://scripts/story/story_character_sprites.gd")
const TerminalSpawns := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")
const TERMINAL_DAY := "res://assets/story/backgrounds/locations/terminalday.png"
const TERMINAL_NIGHT := "res://assets/story/backgrounds/locations/terminalnight.png"

# Add measured background-image rectangles and optional cutout/sheet artwork here.
# Keys are exact full background paths, then stable character IDs (aliases work).
# "res://assets/story/backgrounds/locations/location.png": {
# 	"character_id": {
# 		"background_region": [x, y, width, height],
# 		"texture": "res://assets/characters/location_cutout.png",
# 	},
# },
const LAYOUTS := {}


static func entry(background_path: String, character_id: String) -> Dictionary:
	var path := _normalized_path(background_path)
	var character := CharacterSprites.canonical_character_id(character_id)
	if path.is_empty() or character.is_empty():
		return {}
	for layout_path in LAYOUTS:
		if _normalized_path(str(layout_path)) != path:
			continue
		var layout: Variant = LAYOUTS[layout_path]
		if not layout is Dictionary:
			return {}
		for layout_character in layout:
			if CharacterSprites.canonical_character_id(str(layout_character)) != character:
				continue
			var data: Variant = layout[layout_character]
			if data is Dictionary:
				return data.duplicate(true)
			if data is Rect2 or data is Array:
				return {"background_region": data.duplicate(true) if data is Array else data}
			return {}
		break
	# The terminal already has authored art and geometry; other locations stay empty.
	if path != TERMINAL_DAY and path != TERMINAL_NIGHT:
		return {}
	var terminal_entry := TerminalSpawns.entry(character, path == TERMINAL_NIGHT)
	if terminal_entry.is_empty():
		return {}
	terminal_entry["background_region"] = terminal_entry.get("region", Rect2())
	terminal_entry.erase("region")
	return terminal_entry


static func _normalized_path(value: String) -> String:
	return value.strip_edges().replace("\\", "/").to_lower()
