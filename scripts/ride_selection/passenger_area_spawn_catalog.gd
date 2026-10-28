extends RefCounted

# Each crop retains its placement in the authored full-canvas day sheet.
# Regenerate with tools/extract_terminal_spawns.py --layout market --layout street.
const ART_SIZE := Vector2(1672, 941)
const BACKGROUNDS := {
	"market": {
		"day": preload("res://assets/story/backgrounds/locations/market.png"),
		"night": preload("res://assets/story/backgrounds/locations/marketnight.png"),
	},
	"street": {
		"day": preload("res://assets/story/backgrounds/locations/passengerstreetday.png"),
		"night": preload("res://assets/story/backgrounds/locations/passengerstreetnight.png"),
		"midnight": preload("res://assets/story/backgrounds/locations/passengerstreetmidnight.png"),
	},
}
const NAMED_VARIANTS := {
	"market": {
		"ely": ["default"],
		"benny": ["default"],
	},
	"street": {
		"jessa": ["left", "right"],
		"hana": ["arms_crossed", "reading"],
		"cel": ["front", "back"],
		"ito": ["default"],
	},
}
const MARKET_ENTRIES := {
	"slot_0": {
		"region": Rect2(69, 389, 170, 365),
		"texture": preload("res://assets/characters/sprites/terminal/market/slot_0.png"),
	},
	"ely": {
		"region": Rect2(285, 370, 244, 499),
		"texture": preload("res://assets/characters/sprites/terminal/market/ely.png"),
	},
	"slot_1": {
		"region": Rect2(504, 370, 155, 339),
		"texture": preload("res://assets/characters/sprites/terminal/market/slot_1.png"),
	},
	"benny": {
		"region": Rect2(1207, 353, 213, 365),
		"texture": preload("res://assets/characters/sprites/terminal/market/benny.png"),
	},
	"slot_2": {
		"region": Rect2(1496, 416, 126, 372),
		"texture": preload("res://assets/characters/sprites/terminal/market/slot_2.png"),
	},
}
const STREET_ENTRIES := {
	"jessa_left": {
		"region": Rect2(56, 438, 45, 130),
		"texture": preload("res://assets/characters/sprites/terminal/street/jessa_left.png"),
	},
	"hana_arms_crossed": {
		"region": Rect2(318, 408, 93, 174),
		"texture": preload("res://assets/characters/sprites/terminal/street/hana_arms_crossed.png"),
	},
	"cel_front": {
		"region": Rect2(512, 400, 86, 183),
		"texture": preload("res://assets/characters/sprites/terminal/street/cel_front.png"),
	},
	"cel_back": {
		"region": Rect2(640, 403, 49, 159),
		"texture": preload("res://assets/characters/sprites/terminal/street/cel_back.png"),
	},
	"hana_reading": {
		"region": Rect2(1017, 418, 73, 159),
		"texture": preload("res://assets/characters/sprites/terminal/street/hana_reading.png"),
	},
	"ito": {
		"region": Rect2(1362, 400, 118, 177),
		"texture": preload("res://assets/characters/sprites/terminal/street/ito.png"),
	},
	"jessa_right": {
		"region": Rect2(1531, 438, 51, 144),
		"texture": preload("res://assets/characters/sprites/terminal/street/jessa_right.png"),
	},
}


static func background(area_id: String, night: bool, midnight := false) -> Texture2D:
	var area: Dictionary = BACKGROUNDS.get(area_id, {})
	if midnight and area.has("midnight"):
		return area["midnight"] as Texture2D
	return area.get("night" if night else "day") as Texture2D


# Night backgrounds remain available, but neither day sheet supplies night riders.
static func named_ids(area_id: String, night := false) -> Array[String]:
	var result: Array[String] = []
	if night:
		return result
	var characters: Dictionary = NAMED_VARIANTS.get(area_id, {})
	for character_id: String in characters:
		result.append(character_id)
	return result


static func variant_ids(area_id: String, character_id: String) -> Array[String]:
	var characters: Dictionary = NAMED_VARIANTS.get(area_id, {})
	var result: Array[String] = []
	for variant: String in characters.get(character_id, []):
		result.append(variant)
	return result


static func entry(area_id: String, character_id: String, night: bool, variant := "") -> Dictionary:
	if night:
		return {}
	var variants := variant_ids(area_id, character_id)
	if variants.is_empty():
		return {}
	var selected: String = variants[0] if variant.is_empty() else variant
	if not variants.has(selected):
		return {}
	var key := character_id if selected == "default" else "%s_%s" % [character_id, selected]
	var entries: Dictionary = MARKET_ENTRIES if area_id == "market" else STREET_ENTRIES
	var data: Dictionary = entries.get(key, {})
	var presentation := data.duplicate()
	presentation["variant"] = selected
	return presentation


static func generic_count(area_id: String, night := false) -> int:
	return 3 if area_id == "market" and not night else 0


# The three market silhouettes are independent authored waiting spots.
# The street sheet supplies named alternates only, so it has no generic slots.
static func generic_entry(area_id: String, slot: int, night := false) -> Dictionary:
	if slot < 0 or slot >= generic_count(area_id, night):
		return {}
	var data: Dictionary = MARKET_ENTRIES.get("slot_%d" % slot, {})
	var presentation := data.duplicate()
	presentation["slot"] = slot
	return presentation
