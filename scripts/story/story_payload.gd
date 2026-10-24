extends RefCounted

# Single contract for authored payloads and legacy save adapters. Never changes
# section ordering: existing numeric jumps and saved section indices stay valid.
const VERSION := 1
const StoryActionCatalog := preload("res://scripts/story/story_action_catalog.gd")


static func normalize(source: Dictionary) -> Dictionary:
	var payload := source.duplicate(true)
	payload["schema_version"] = VERSION
	payload["story_id"] = str(payload.get("story_id", ""))
	payload["chapter_title"] = str(payload.get("chapter_title", "STORY"))
	payload["speaker_portraits"] = bool(payload.get("speaker_portraits", false))
	var lines: Array = payload.get("composition", payload.get("sections", payload.get("lines", [])))
	payload.erase("sections")
	payload.erase("lines")
	payload["composition"] = []
	for raw_line: Dictionary in lines:
		var line := raw_line.duplicate(true)
		line["text"] = str(line.get("text", ""))
		line["speaker"] = str(line.get("speaker", ""))
		line["actions"] = normalize_actions(line.get("actions", line.get("triggers", [])))
		line.erase("triggers")
		var choices: Array = []
		for raw_choice: Dictionary in line.get("choices", []):
			var choice := raw_choice.duplicate(true)
			choice["actions"] = normalize_actions(choice.get("actions", choice.get("effects", [])))
			choice.erase("effects")
			choices.append(choice)
		line["choices"] = choices
		payload["composition"].append(line)
	var music: Variant = payload.get("music", payload.get("bgm", {}))
	if music is String:
		music = {"type": "play_music", "path": music, "loop": payload.get("music_loop", payload.get("bgm_loop", true)), "fade_in": payload.get("music_fade_in", payload.get("bgm_fade_in", 0.35)), "volume_db": payload.get("music_volume_db", payload.get("bgm_volume_db", 0.0))}
	payload["music"] = Dictionary(music).duplicate(true) if music is Dictionary else {}
	payload.erase("bgm")
	payload["ambient_sfx"] = Dictionary(payload.get("ambient_sfx", {})).duplicate(true)
	return payload


static func normalize_actions(raw_actions: Array) -> Array:
	var actions: Array = []
	for raw_action: Dictionary in raw_actions:
		var action := raw_action.duplicate(true)
		action["type"] = str(action.get("type", action.get("action", ""))).to_lower()
		action.erase("action")
		actions.append(action)
	return actions


static func validate(payload: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if str(payload.get("story_id", "")).is_empty():
		errors.append("Missing story_id")
	var lines: Array = payload.get("composition", [])
	if lines.is_empty():
		errors.append("Empty composition")
	for i in range(lines.size()):
		var line: Dictionary = lines[i]
		var targets: Array = [line]
		targets.append_array(line.get("choices", []))
		for target: Dictionary in targets:
			for key in ["next_index", "skip_index", "next_index_if_skipped"]:
				if target.has(key) and (int(target[key]) < 0 or int(target[key]) > lines.size()):
					errors.append("Section %d: invalid %s" % [i, key])
			for action: Dictionary in target.get("actions", []):
				for error: String in StoryActionCatalog.validate_action(action):
					errors.append("Section %d: %s" % [i, error])
	return errors
