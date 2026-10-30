extends RefCounted

# Five interchangeable silhouette shapes, each with three frames facing right.
# Mouth points are source-pixel centers measured at the visible snout (alpha >= 128).
const SOURCE := preload("res://assets/ui/fishingminigame/fishes.png")
const NATIVE_FACING := 1
const BODY_WIDTH := 100.0
const SPECIES := [
	{
		"frames": [
			{
				"region": Rect2(37, 17, 108, 68),
				"mouth": Vector2(107.5, 38.0),
			},
			{
				"region": Rect2(177, 17, 112, 68),
				"mouth": Vector2(111.5, 38.0),
			},
			{
				"region": Rect2(323, 17, 111, 68),
				"mouth": Vector2(110.5, 38.0),
			},
		],
	},
	{
		"frames": [
			{
				"region": Rect2(27, 100, 123, 40),
				"mouth": Vector2(122.5, 19.5),
			},
			{
				"region": Rect2(171, 100, 129, 40),
				"mouth": Vector2(128.5, 19.5),
			},
			{
				"region": Rect2(314, 100, 128, 40),
				"mouth": Vector2(127.5, 19.0),
			},
		],
	},
	{
		"frames": [
			{
				"region": Rect2(32, 146, 107, 76),
				"mouth": Vector2(106.5, 45.5),
			},
			{
				"region": Rect2(176, 146, 111, 76),
				"mouth": Vector2(110.5, 46.0),
			},
			{
				"region": Rect2(324, 146, 113, 76),
				"mouth": Vector2(112.5, 45.0),
			},
		],
	},
	{
		"frames": [
			{
				"region": Rect2(28, 228, 117, 67),
				"mouth": Vector2(116.5, 38.5),
			},
			{
				"region": Rect2(173, 228, 119, 67),
				"mouth": Vector2(118.5, 39.0),
			},
			{
				"region": Rect2(320, 228, 120, 67),
				"mouth": Vector2(119.5, 38.5),
			},
		],
	},
	{
		"frames": [
			{
				"region": Rect2(55, 299, 79, 40),
				"mouth": Vector2(78.5, 20.0),
			},
			{
				"region": Rect2(196, 300, 80, 40),
				"mouth": Vector2(79.5, 21.0),
			},
			{
				"region": Rect2(346, 300, 78, 39),
				"mouth": Vector2(77.5, 20.0),
			},
		],
	},
]

static var _textures: Dictionary = {}


static func frame_for(species_index: int, frame_index: int) -> Dictionary:
	var species: Dictionary = SPECIES[posmod(species_index, SPECIES.size())]
	var frames: Array = species.frames
	return frames[posmod(frame_index, frames.size())]


static func texture_for(species_index: int, frame_index: int) -> AtlasTexture:
	var key := Vector2i(posmod(species_index, SPECIES.size()), posmod(frame_index, 3))
	if not _textures.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = SOURCE
		atlas.region = frame_for(key.x, key.y).region
		atlas.filter_clip = true
		_textures[key] = atlas
	return _textures[key] as AtlasTexture


static func visual_size(species_index: int, frame_index: int, size_scale: float = 1.0) -> Vector2:
	var first: Rect2 = frame_for(species_index, 0).region
	var region: Rect2 = frame_for(species_index, frame_index).region
	return region.size * (BODY_WIDTH / first.size.x) * size_scale


static func mouth_offset(species_index: int, frame_index: int, size_scale: float = 1.0) -> Vector2:
	var first: Rect2 = frame_for(species_index, 0).region
	var frame := frame_for(species_index, frame_index)
	var region: Rect2 = frame.region
	var mouth: Vector2 = frame.mouth
	return (mouth - region.size * 0.5) * (BODY_WIDTH / first.size.x) * size_scale
