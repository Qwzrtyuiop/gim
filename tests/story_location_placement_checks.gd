extends RefCounted

const Placements := preload("res://scripts/story/story_portrait_placements.gd")
const PortraitLayer := preload("res://scripts/story/story_portrait_layer.gd")
const Presentation := preload("res://scripts/story/story_presentation.gd")
const Spawns := preload("res://scripts/ride_selection/terminal_spawn_catalog.gd")
const DAY := "res://assets/story/backgrounds/locations/terminalday.png"
const NIGHT := "res://assets/story/backgrounds/locations/terminalnight.png"
const PARK := "res://assets/story/backgrounds/locations/park.png"
const JESSA := "res://assets/characters/Jessa.png"
const JESSA_ALT := "res://assets/characters/Jessa_alt.png"
const JOHN := "res://assets/characters/John.png"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_resolver()
	await _test_location_switches(host)
	print("PASS: per-location portraits retain authored crops, variants and background transforms; missing layouts hide safely and foreground portraits keep their size")


static func _test_resolver() -> void:
	var day: Texture2D = load(DAY)
	var source := {
		"id": "jessa_scene",
		"texture": JESSA,
		"background_placements": {
			DAY.to_upper(): {
				"sheet": Spawns.DAY_LAYOUT,
				"source_region": [1200, 329, 111, 235],
				"background_region": [1200, 329, 111, 235],
				"variants": {
					"alt": {
						"path": JESSA_ALT,
						"background_region": [1100, 300, 160, 270],
					},
				},
			},
		},
	}
	var authored := source.duplicate(true)
	var result := Placements.resolve(source, day)
	assert(result.sheet == Spawns.DAY_LAYOUT and result.source_region == Rect2(1200, 329, 111, 235))
	source["sprite"] = "alt"
	result = Placements.resolve(source, day)
	assert(result.texture == JESSA_ALT and not result.has("sheet") and not result.has("source_region"), "A variant cutout must replace the old sheet and crop")
	assert(result.background_region == Rect2(1100, 300, 160, 270))
	source.erase("sprite")
	assert(source == authored, "Resolving layouts and variants cannot overwrite authored data")
	assert(Placements.resolve(source, load(PARK)).is_empty())
	assert(Placements.resolve(source, null).is_empty())
	for invalid in [null, [], [0, 0, -1, 3], [0, 0, 1, 0], [0, NAN, 1, 1], [0, 0, "bad", 1]]:
		assert(not Placements.region(invalid).has_area(), "Malformed placements must not fall back to old coordinates")
	var automatic := Placements.resolve({"id": "speaker", "character_id": "jessa", "placement": "background"}, day)
	assert(automatic.background_region == Spawns.entry("jessa", false).region)
	assert(automatic.texture == Spawns.entry("jessa", false).texture)
	assert(Placements.resolve({"id": "speaker", "character_id": "jessa", "placement": "background"}, load(PARK)).is_empty())
	var foreground := {"id": "john", "texture": JOHN, "height": 260}
	assert(Placements.resolve(foreground, day) == foreground, "Foreground portraits keep the legacy placement contract")


static func _test_location_switches(host: Node) -> void:
	var canvas := Control.new()
	canvas.size = Vector2(1280, 720)
	host.add_child(canvas)
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.texture = load(DAY)
	canvas.add_child(background)
	background.size = canvas.size
	var panel := Control.new()
	canvas.add_child(panel)
	panel.position = Vector2(20, 482)
	panel.size = Vector2(1240, 204)
	var layer := PortraitLayer.new()
	canvas.add_child(layer)
	layer.setup(panel, Presentation.resolve_texture, background)
	var authored := {
		"id": "scene_jessa",
		"character_id": "jessa",
		"background_placements": {
			DAY: {"sheet": Spawns.DAY_LAYOUT, "background_region": [1200, 329, 111, 235]},
			NIGHT: {"texture": Spawns.entry("jessa", true).texture, "background_region": [1189, 329, 122, 236]},
		},
	}
	layer.set_portrait(authored)
	layer.set_portrait({"id": "foreground_john", "texture": JOHN, "height": 260})
	var original_entries := layer.entries.duplicate(true)
	var scene: TextureRect = layer.images.scene_jessa
	var foreground: TextureRect = layer.images.foreground_john
	var foreground_rect := foreground.get_rect()
	assert(scene.visible and scene.texture is AtlasTexture and scene.material == null)
	assert(scene.texture.region == Rect2(1200, 329, 111, 235))
	var fit := 720.0 / 941.0
	var padding := Vector2((1280.0 - 1672.0 * fit) * 0.5, 0)
	assert(scene.get_rect().is_equal_approx(Rect2(Vector2(1200, 329) * fit + padding, Vector2(111, 235) * fit)))
	background.texture = load(NIGHT)
	layer.layout_portraits()
	assert(scene.texture == Spawns.entry("jessa", true).texture, "Same-size background swaps must select the new location's art")
	assert(scene.get_rect().is_equal_approx(Rect2(Vector2(1189, 329) * fit + padding, Vector2(122, 236) * fit)))
	assert(foreground.get_rect() == foreground_rect)
	background.texture = load(PARK)
	layer.layout_portraits()
	assert(not scene.visible and foreground.visible, "Missing world layouts hide without hiding dialogue portraits")
	background.texture = load(DAY)
	background.size = Vector2(1672, 941)
	background.position = Vector2(-200, -110)
	background.scale = Vector2(1.5, 1.5)
	layer.layout_portraits()
	assert(scene.visible and scene.texture is AtlasTexture)
	assert(scene.get_rect().is_equal_approx(Rect2(Vector2(-200, -110) + Vector2(1200, 329) * 1.5, Vector2(111, 235) * 1.5)), "World portraits follow background zoom and pan")
	panel.position += Vector2(40, 70)
	layer.layout_portraits()
	assert(scene.get_rect().is_equal_approx(Rect2(Vector2(-200, -110) + Vector2(1200, 329) * 1.5, Vector2(111, 235) * 1.5)))
	assert(layer.entries == original_entries, "Background switches must never persist resolved coordinates over authored placements")
	canvas.free()
	await host.get_tree().process_frame
