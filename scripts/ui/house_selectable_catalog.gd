extends RefCounted

# One authored canvas and one cached alpha mask per object for both phases.
# Regenerate textures with tools/extract_house_selectables.py after art changes.
const ART_SIZE := Vector2(1698, 926)
const LAYOUT := preload("res://assets/story/backgrounds/locations/houseselect.png")
const ENTRIES := {
	"radio": {
		"region": Rect2(79, 474, 138, 137),
		"mask": preload("res://assets/story/backgrounds/locations/houseselectables/masks/radio.png"),
		"day": preload("res://assets/story/backgrounds/locations/houseselectables/day/radio.png"),
		"night": preload("res://assets/story/backgrounds/locations/houseselectables/night/radio.png"),
	},
	"calendar": {
		"region": Rect2(799, 392, 65, 114),
		"mask": preload("res://assets/story/backgrounds/locations/houseselectables/masks/calendar.png"),
		"day": preload("res://assets/story/backgrounds/locations/houseselectables/day/calendar.png"),
		"night": preload("res://assets/story/backgrounds/locations/houseselectables/night/calendar.png"),
	},
	"rest": {
		"region": Rect2(1488, 228, 107, 545),
		"mask": preload("res://assets/story/backgrounds/locations/houseselectables/masks/rest.png"),
		"day": preload("res://assets/story/backgrounds/locations/houseselectables/day/rest.png"),
		"night": preload("res://assets/story/backgrounds/locations/houseselectables/night/rest.png"),
	},
}
const REGIONS := {
	"radio": Rect2(Vector2(79, 474) / ART_SIZE, Vector2(138, 137) / ART_SIZE),
	"calendar": Rect2(Vector2(799, 392) / ART_SIZE, Vector2(65, 114) / ART_SIZE),
	"rest": Rect2(Vector2(1488, 228) / ART_SIZE, Vector2(107, 545) / ART_SIZE),
	# No exit sprite is present in the selector sheet. Retain the existing floor
	# hotspot and its polygon independently of the three authored item masks.
	"ride": Rect2(0.778, 0.865, 0.222, 0.135),
}

static var _alpha_images: Dictionary = {}


static func alpha_image(action: String) -> Image:
	if not ENTRIES.has(action):
		return null
	if not _alpha_images.has(action):
		_alpha_images[action] = ENTRIES[action].mask.get_image()
	return _alpha_images[action] as Image


static func texture_for(action: String, night: bool) -> Texture2D:
	if not ENTRIES.has(action):
		return null
	return ENTRIES[action]["night" if night else "day"] as Texture2D
