extends RefCounted

# Catch identities and lengths are independent of the five swimming silhouettes.
# Regions contain fish artwork only; captions remain outside the atlas crops.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const SOURCE_PATH := "res://assets/ui/fishingminigame/fishlist.png"
const MIN_LENGTH_CM := 4.0
const MAX_LENGTH_CM := 240.0
const MIN_SPRITE_WIDTH := 36.0
const MAX_SPRITE_WIDTH := 280.0
const SILHOUETTE_BASE_WIDTH := 100.0
const FISH := [
	{
		"id": "lapu_lapu",
		"name": "Lapu-lapu",
		"min_cm": 15.0,
		"max_cm": 50.0,
		"region": Rect2(16, 210, 293, 146),
	},
	{
		"id": "tamban",
		"name": "Tamban",
		"min_cm": 8.0,
		"max_cm": 23.0,
		"region": Rect2(333, 229, 281, 113),
	},
	{
		"id": "dilis",
		"name": "Dilis",
		"min_cm": 4.0,
		"max_cm": 16.0,
		"region": Rect2(652, 217, 247, 139),
	},
	{
		"id": "maya_maya",
		"name": "Maya-maya",
		"min_cm": 15.0,
		"max_cm": 100.0,
		"region": Rect2(943, 204, 288, 159),
	},
	{
		"id": "bangus",
		"name": "Bangus",
		"min_cm": 20.0,
		"max_cm": 150.0,
		"region": Rect2(20, 472, 291, 128),
	},
	{
		"id": "tilapia",
		"name": "Tilapia",
		"min_cm": 10.0,
		"max_cm": 60.0,
		"region": Rect2(336, 463, 269, 153),
	},
	{
		"id": "tambakol",
		"name": "Tambakol",
		"min_cm": 40.0,
		"max_cm": 240.0,
		"region": Rect2(636, 469, 282, 141),
	},
	{
		"id": "tulingan",
		"name": "Tulingan",
		"min_cm": 20.0,
		"max_cm": 65.0,
		"region": Rect2(943, 467, 293, 141),
	},
	{
		"id": "galunggong",
		"name": "Galunggong",
		"min_cm": 10.0,
		"max_cm": 35.0,
		"region": Rect2(20, 738, 287, 121),
	},
	{
		"id": "dalagang_bukid",
		"name": "Dalagang Bukid",
		"min_cm": 10.0,
		"max_cm": 60.0,
		"region": Rect2(332, 730, 288, 136),
	},
	{
		"id": "sapsap",
		"name": "Sapsap",
		"min_cm": 6.0,
		"max_cm": 28.0,
		"region": Rect2(647, 709, 256, 165),
	},
	{
		"id": "hasa_hasa",
		"name": "Hasa-hasa",
		"min_cm": 10.0,
		"max_cm": 42.0,
		"region": Rect2(941, 742, 298, 118),
	},
	{
		"id": "apahap",
		"name": "Apahap",
		"min_cm": 25.0,
		"max_cm": 200.0,
		"region": Rect2(12, 971, 299, 151),
	},
	{
		"id": "pompano",
		"name": "Pompano",
		"min_cm": 12.0,
		"max_cm": 110.0,
		"region": Rect2(341, 962, 260, 167),
	},
	{
		"id": "bisugo",
		"name": "Bisugo",
		"min_cm": 8.0,
		"max_cm": 34.0,
		"region": Rect2(631, 987, 289, 131),
	},
	{
		"id": "tanigue",
		"name": "Tanigue",
		"min_cm": 30.0,
		"max_cm": 240.0,
		"region": Rect2(940, 997, 301, 105),
	},
]

static var _source: Texture2D
static var _textures: Dictionary = {}


static func find(fish_id: String) -> Dictionary:
	for definition: Dictionary in FISH:
		if str(definition.id) == fish_id:
			return definition.duplicate()
	return {}


static func roll(rng: RandomNumberGenerator, max_length_cm: float = INF) -> Dictionary:
	if is_nan(max_length_cm) or max_length_cm < MIN_LENGTH_CM:
		return {}
	# Small-fish passages keep the same rarity curve within their allowed lengths.
	var eligible: Array[Dictionary] = []
	var total_weight := 0.0
	for definition: Dictionary in FISH:
		if float(definition.min_cm) > max_length_cm:
			continue
		eligible.append(definition)
		var eligible_maximum := minf(float(definition.max_cm), max_length_cm)
		total_weight += 1.0 / (1.0 + eligible_maximum / GameTuning.FISHING_SPECIES_WEIGHT_CM)
	if eligible.is_empty():
		return {}
	var remaining := rng.randf() * total_weight
	var selected: Dictionary = eligible[-1]
	for definition: Dictionary in eligible:
		var weighted_maximum := minf(float(definition.max_cm), max_length_cm)
		remaining -= 1.0 / (1.0 + weighted_maximum / GameTuning.FISHING_SPECIES_WEIGHT_CM)
		if remaining <= 0.0:
			selected = definition
			break
	# Most fish stay near their species minimum; record-sized catches remain possible.
	var minimum := float(selected.min_cm)
	var maximum := minf(float(selected.max_cm), max_length_cm)
	var fraction := pow(rng.randf(), GameTuning.FISHING_SIZE_ROLL_POWER)
	var length_cm := clampf(snappedf(lerpf(minimum, maximum, fraction), 0.1), minimum, maximum)
	return {
		"fish_id": str(selected.id),
		"length_cm": length_cm,
	}


static func texture_for(fish_id: String) -> Texture2D:
	var definition := find(fish_id)
	if definition.is_empty():
		return null
	if not _textures.has(fish_id):
		if _source == null:
			_source = load(SOURCE_PATH) as Texture2D
		if _source == null:
			return null
		var atlas := AtlasTexture.new()
		atlas.atlas = _source
		atlas.region = definition.region
		atlas.filter_clip = true
		_textures[fish_id] = atlas
	return _textures[fish_id] as Texture2D


static func visual_scale(length_cm: float) -> float:
	if not is_finite(length_cm):
		return MIN_SPRITE_WIDTH / SILHOUETTE_BASE_WIDTH
	var fraction := clampf(inverse_lerp(MIN_LENGTH_CM, MAX_LENGTH_CM, length_cm), 0.0, 1.0)
	return lerpf(MIN_SPRITE_WIDTH, MAX_SPRITE_WIDTH, fraction) / SILHOUETTE_BASE_WIDTH
