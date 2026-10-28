extends RefCounted

# Source-pixel bounds from mapguide.png. The guide stays authoring-only;
# these same rectangles follow the aspect-fitted map at every screen size.
const BACKGROUND := preload("res://assets/map/topdownmap.png")
const NIGHT_BACKGROUND := preload("res://assets/map/topdownmapnight.png")
const NORTH_BACKGROUND := preload("res://assets/map/northmap.png")
const NORTH_NIGHT_BACKGROUND := preload("res://assets/map/northmapnight.png")
const ART_SIZE := Vector2(1672, 941)
const NORTH_ART_SIZE := Vector2(1671, 941)
const REGIONS := {
	"home": Rect2(0, 536, 55, 61),
	"station": Rect2(81, 204, 320, 193),
	"market": Rect2(529, 114, 366, 253),
	"street": Rect2(531, 514, 398, 152),
	"park": Rect2(939, 103, 237, 262),
	"hospital": Rect2(1281, 0, 284, 258),
	"bar": Rect2(1308, 406, 249, 133),
	"north": Rect2(437, 2, 80, 120),
	"locked_east": Rect2(1575, 542, 90, 57),
	"locked_south_east": Rect2(1199, 726, 105, 145),
	"locked_south_west": Rect2(411, 801, 76, 88),
}
# Measured lime guide boxes include transparent authoring marks. The unnamed
# flag-building box remains unused until a destination is assigned to it.
const NORTH_REGIONS := {
	"pier": Rect2(120, 19, 171, 118),
	"school": Rect2(637, 74, 452, 205),
	"construction_site": Rect2(586, 337, 242, 172),
	"big_station": Rect2(1158, 339, 279, 203),
	"church": Rect2(897, 342, 206, 191),
	"basketball_court": Rect2(264, 428, 178, 141),
	"abandoned_building": Rect2(83, 778, 80, 74),
	"town": Rect2(1105, 838, 98, 100),
}
const NAMES := {
	"home": "Home",
	"station": "Station",
	"market": "Market",
	"street": "Street",
	"park": "Park",
	"hospital": "Hospital",
	"bar": "Bar",
	"north": "North Road",
	"town": "Back to South",
	"pier": "Pier",
	"school": "School",
	"construction_site": "Construction Site",
	"big_station": "Big Station",
	"church": "Church",
	"basketball_court": "Basketball Court",
	"abandoned_building": "Abandoned Building",
	"locked_east": "Not yet unlocked",
	"locked_south_east": "Not yet unlocked",
	"locked_south_west": "Not yet unlocked",
}


static func is_locked(location_id: String) -> bool:
	if location_id == "hospital":
		return not bool(PlayerState.get_event_value("celina_first_encounter_seen", false))
	return location_id.begins_with("locked_")
