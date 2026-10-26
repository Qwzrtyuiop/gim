extends RefCounted

# Authored terminal placements. Regenerate the isolated sprite crops with
# tools/extract_terminal_spawns.py; regions retain their original canvas offsets.
const ART_SIZE := Vector2(1672, 941)
const DAY_BACKGROUND := preload("res://assets/story/backgrounds/locations/terminalday.png")
const NIGHT_BACKGROUND := preload("res://assets/story/backgrounds/locations/terminalnight.png")
const DAY_LAYOUT := preload("res://assets/story/backgrounds/locations/terminalspawns/dayspawns.png")
const NIGHT_LAYOUT := preload("res://assets/story/backgrounds/locations/terminalspawns/nightspawns.png")
const GENERIC_LAYOUT := preload("res://assets/story/backgrounds/locations/terminalspawns/genericspawns.png")
const GENERIC_ALTERNATE_LAYOUT := preload("res://assets/story/backgrounds/locations/terminalspawns/genericspawns2.png")
const GENERIC_IDS := [
	"generic_guy",
	"generic_vendor",
	"generic_student",
	"generic_worker",
	"generic_elder",
	"generic_parent_child",
]
# Each generic pose was authored as a replacement for this named waiting spot.
const GENERIC_SLOT_BY_CHARACTER := {
	# Dante's seated pose reaches into the first standing spot at night.
	"dante": 0,
	"ely": 0,
	"gardo": 1,
	"ito": 2,
	"cel": 3,
	"hana": 4,
	"benny": 5,
	"jessa": 6,
	"alma": 7,
}
const SPRITES := {
	"alma": preload("res://assets/characters/sprites/almasprite.png"),
	"benny": preload("res://assets/characters/sprites/bennysprite.png"),
	"cel": preload("res://assets/characters/sprites/celiasprite.png"),
	"dante": preload("res://assets/characters/sprites/dantesprite.png"),
	"ely": preload("res://assets/characters/sprites/elenasprite.png"),
	"faye": preload("res://assets/characters/sprites/magdasprite.png"),
	"gardo": preload("res://assets/characters/sprites/gardosprite.png"),
	"hana": preload("res://assets/characters/sprites/hanasprite.png"),
	"ito": preload("res://assets/characters/sprites/isidrosprite.png"),
	"jessa": preload("res://assets/characters/sprites/jessasprite.png"),
}
const DAY_ENTRIES := {
	"faye": {
		"region": Rect2(41, 277, 139, 345),
		"texture": preload("res://assets/characters/sprites/terminal/day/faye.tres"),
	},
	"ely": {
		"region": Rect2(249, 301, 107, 276),
		"texture": preload("res://assets/characters/sprites/terminal/day/ely.png"),
	},
	"gardo": {
		"region": Rect2(368, 353, 158, 207),
		"texture": preload("res://assets/characters/sprites/terminal/day/gardo.png"),
	},
	"ito": {
		"region": Rect2(612, 330, 234, 367),
		"texture": preload("res://assets/characters/sprites/terminal/day/ito.png"),
	},
	"cel": {
		"region": Rect2(808, 308, 93, 259),
		"texture": preload("res://assets/characters/sprites/terminal/day/cel.png"),
	},
	"hana": {
		"region": Rect2(899, 324, 117, 230),
		"texture": preload("res://assets/characters/sprites/terminal/day/hana.png"),
	},
	"benny": {
		"region": Rect2(1041, 301, 176, 383),
		"texture": preload("res://assets/characters/sprites/terminal/day/benny.png"),
	},
	"jessa": {
		"region": Rect2(1200, 329, 111, 235),
		"texture": preload("res://assets/characters/sprites/terminal/day/jessa.png"),
	},
	"alma": {
		"region": Rect2(1371, 285, 91, 308),
		"texture": preload("res://assets/characters/sprites/terminal/day/alma.png"),
	},
}
const NIGHT_ENTRIES := {
	"dante": {
		"region": Rect2(117, 513, 209, 302),
		"texture": preload("res://assets/characters/sprites/terminal/night/dante.png"),
	},
	"gardo": {
		"region": Rect2(355, 353, 171, 222),
		"texture": preload("res://assets/characters/sprites/terminal/night/gardo.png"),
	},
	"cel": {
		"region": Rect2(793, 308, 125, 268),
		"texture": preload("res://assets/characters/sprites/terminal/night/cel.png"),
	},
	"hana": {
		"region": Rect2(899, 324, 101, 233),
		"texture": preload("res://assets/characters/sprites/terminal/night/hana.png"),
	},
	"jessa": {
		"region": Rect2(1189, 329, 122, 236),
		"texture": preload("res://assets/characters/sprites/terminal/night/jessa.png"),
	},
	"alma": {
		"region": Rect2(1371, 285, 91, 308),
		"texture": preload("res://assets/characters/sprites/terminal/night/alma.png"),
	},
	"faye": {
		"region": Rect2(1546, 307, 114, 335),
		"texture": preload("res://assets/characters/sprites/terminal/night/faye.png"),
	},
}


const MIDNIGHT_ENTRIES := {
	"gardo": {
		"region": Rect2(214, 396, 133, 161),
		"texture": preload("res://assets/characters/sprites/terminal/midnight/gardo.tres"),
	},
}


const GENERIC_ENTRIES := [
	{
		"region": Rect2(259, 301, 67, 280),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_0.png"),
	},
	{
		"region": Rect2(390, 368, 128, 196),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_1.png"),
	},
	{
		"region": Rect2(654, 326, 141, 338),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_2.png"),
	},
	{
		"region": Rect2(819, 304, 68, 261),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_3.png"),
	},
	{
		"region": Rect2(906, 321, 82, 244),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_4.png"),
	},
	{
		"region": Rect2(1040, 299, 148, 363),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_5.png"),
	},
	{
		"region": Rect2(1211, 327, 82, 245),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_6.png"),
	},
	{
		"region": Rect2(1371, 311, 78, 277),
		"texture": preload("res://assets/characters/sprites/terminal/generic/slot_7.png"),
	},
]


const GENERIC_ALTERNATE_ENTRIES := {
	0: {
		"region": Rect2(247, 306, 118, 277),
		"texture": preload("res://assets/characters/sprites/terminal/generic2/slot_0.png"),
	},
	2: {
		"region": Rect2(641, 300, 102, 375),
		"texture": preload("res://assets/characters/sprites/terminal/generic2/slot_2.png"),
	},
	3: {
		"region": Rect2(816, 283, 91, 282),
		"texture": preload("res://assets/characters/sprites/terminal/generic2/slot_3.png"),
	},
	5: {
		"region": Rect2(1047, 314, 106, 349),
		"texture": preload("res://assets/characters/sprites/terminal/generic2/slot_5.png"),
	},
	6: {
		"region": Rect2(1224, 305, 87, 278),
		"texture": preload("res://assets/characters/sprites/terminal/generic2/slot_6.png"),
	},
	7: {
		"region": Rect2(1373, 291, 76, 296),
		"texture": preload("res://assets/characters/sprites/terminal/generic2/slot_7.png"),
	},
}


static func entry(character_id: String, night: bool) -> Dictionary:
	var entries: Dictionary = NIGHT_ENTRIES if night else DAY_ENTRIES
	var data: Dictionary = entries.get(character_id, {})
	return data.duplicate()


static func generic_entry(slot: int, alternate := false) -> Dictionary:
	if slot < 0 or slot >= GENERIC_ENTRIES.size():
		return {}
	if alternate and GENERIC_ALTERNATE_ENTRIES.has(slot):
		var presentation: Dictionary = GENERIC_ALTERNATE_ENTRIES[slot].duplicate()
		presentation["opacity"] = 0.7
		return presentation
	return GENERIC_ENTRIES[slot].duplicate()


static func midnight_entry(character_id: String) -> Dictionary:
	var data: Dictionary = MIDNIGHT_ENTRIES.get(character_id, {})
	return data.duplicate()
