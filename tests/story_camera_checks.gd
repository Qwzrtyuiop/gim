extends RefCounted

const Presentation := preload("res://scripts/story/story_presentation.gd")
const BACKGROUND := preload("res://assets/story/backgrounds/locations/terminalday.png")

class CameraHost:
	extends Control
	var background: TextureRect
	var background_motion_tween: Tween
	var background_zoom := 1.0
	var background_pan := Vector2.ZERO


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	var camera := CameraHost.new()
	host.get_tree().root.add_child(camera)
	camera.background = TextureRect.new()
	camera.background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camera.background.texture = BACKGROUND
	camera.add_child(camera.background)
	for viewport_size in [Vector2(1280, 720), Vector2(900, 900), Vector2(640, 360)]:
		camera.size = viewport_size
		for zoom in [0.7, 1.0, 1.05, 1.3]:
			for pan in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, 1)]:
				Presentation.set_background_camera(camera, zoom, pan)
				_assert_transform(camera)
	Presentation.set_background_camera(camera, 1.3, Vector2.ONE, 0.04)
	await host.get_tree().create_timer(0.09).timeout
	_assert_transform(camera)
	camera.free()
	await host.get_tree().process_frame
	print("PASS: story camera zoom-out/zoom-in, centered letterboxing, bounded pan and animated targets across three viewport shapes")


static func _assert_transform(camera: CameraHost) -> void:
	var source_size := BACKGROUND.get_size()
	var fit := minf(camera.size.x / source_size.x, camera.size.y / source_size.y)
	var expected_size := source_size * fit * Presentation.DEFAULT_BG_FIT_SCALE * camera.background_zoom
	var actual := Rect2(camera.background.position, camera.background.size)
	if camera.background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		var image_fit := minf(actual.size.x / source_size.x, actual.size.y / source_size.y)
		var drawn := source_size * image_fit
		actual.position += (actual.size - drawn) * 0.5
		actual.size = drawn
	assert(actual.size.is_equal_approx(expected_size), "Camera zoom must affect the drawn image even when it fits inside the viewport")
	var spare := camera.size - expected_size
	var expected_position := Vector2(
		spare.x * (0.5 if spare.x >= 0 else (camera.background_pan.x + 1) * 0.5),
		spare.y * (0.5 if spare.y >= 0 else (camera.background_pan.y + 1) * 0.5),
	)
	assert(actual.position.is_equal_approx(expected_position), "Fitting axes center while oversized axes follow bounded camera pan")
