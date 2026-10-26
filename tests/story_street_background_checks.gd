extends RefCounted

const Catalog := preload("res://scripts/story/story_payload_catalog.gd")
const Constants := preload("res://scripts/story/story_constants.gd")
const PortraitLayer := preload("res://scripts/story/story_portrait_layer.gd")
const Presentation := preload("res://scripts/story/story_presentation.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	var language := StoryLanguageManager.get_language()
	for selected_language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(selected_language)
		_test_street_selection()
		_test_gardo_sections()
	await _test_seated_sprite(host)
	StoryLanguageManager.set_language(language)
	PlayerState.reset()
	print("PASS: bilingual street backgrounds use ride time, Gardo stays seated until departure, atlas material and bench placement survive resizing")


static func _test_street_selection() -> void:
	PlayerState.reset()
	assert(load(Constants.BACKGROUND_STREET_DAY) is Texture2D)
	assert(load(Constants.BACKGROUND_STREET_NIGHT) is Texture2D)
	for phase in ["morning", "noon", "night"]:
		PlayerState.set_current_stage_time(phase)
		var expected: String = Constants.BACKGROUND_STREET_NIGHT if phase == "night" else Constants.BACKGROUND_STREET_DAY
		assert(Catalog.build("isidro_first_encounter").background == expected)
	# A noon ride has already advanced the live clock to night before its story.
	PlayerState.set_current_stage_time("night")
	PlayerState.set_last_stage_result({"time_of_day": "noon"})
	assert(Catalog.build("elena_old_acquaintance").background == Constants.BACKGROUND_STREET_DAY)
	PlayerState.set_last_stage_result({"time_of_day": "night"})
	assert(Catalog.build("elena_old_acquaintance").background == Constants.BACKGROUND_STREET_NIGHT)
	assert(Constants.street_background("midnight") == Constants.BACKGROUND_STREET_NIGHT)


static func _test_gardo_sections() -> void:
	var lines: Array = Catalog.build("gardo_first_encounter").composition
	var seated: Dictionary = lines[56]
	assert(seated.portraits.size() == 1)
	assert(seated.portraits[0].texture == Constants.SPRITE_GARDO_MIDNIGHT)
	assert(seated.portraits[0].background_region == [214, 396, 133, 161])
	for index in range(56, 62):
		assert(not lines[index].speaker_portraits, "Automatic portraits cannot replace the seated cutout")
	assert(lines[62].background == Constants.BACKGROUND_STREET_NIGHT)
	assert(lines[62].portraits.is_empty(), "The seated sprite leaves when the background changes")


static func _test_seated_sprite(host: Node) -> void:
	var canvas := Control.new()
	canvas.size = Vector2(1280, 720)
	host.add_child(canvas)
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.texture = load(Constants.BACKGROUND_TERMINAL_NIGHT)
	canvas.add_child(background)
	background.size = canvas.size
	assert(background.texture.get_size() == Vector2(1672, 941))
	var panel := Control.new()
	canvas.add_child(panel)
	panel.position = Vector2(20, 482)
	panel.size = Vector2(1240, 204)
	var layer := PortraitLayer.new()
	canvas.add_child(layer)
	layer.setup(panel, Presentation.resolve_texture, background)
	var seated: Dictionary = Catalog.build("gardo_first_encounter").composition[56].portraits[0]
	layer.set_portrait(seated)
	var image: TextureRect = layer.images.gardo_seated
	assert(image.texture is AtlasTexture)
	assert(image.texture.get_size() == Vector2(133, 161))
	assert(image.material == null, "Scene atlases must not use the portrait shader that blacked out Gardo")
	# The current terminal fits by height at 16:9, then by width at 4:3.
	var source_scale := 720.0 / 941.0
	var expected := Rect2(Vector2(214, 396) * source_scale + Vector2((1280.0 - 1672.0 * source_scale) * 0.5, 0), Vector2(133, 161) * source_scale)
	assert(image.get_rect().is_equal_approx(expected))
	background.size = Vector2(640, 360)
	await host.get_tree().process_frame
	assert(image.get_rect().is_equal_approx(Rect2(expected.position * 0.5, expected.size * 0.5)))
	background.size = Vector2(640, 480)
	await host.get_tree().process_frame
	var narrow_scale := 640.0 / 1672.0
	var narrow_expected := Rect2(Vector2(214, 396) * narrow_scale + Vector2(0, (480.0 - 941.0 * narrow_scale) * 0.5), Vector2(133, 161) * narrow_scale)
	assert(image.get_rect().is_equal_approx(narrow_expected))
	# Changing the speaker panel must not drag a seated character off the bench.
	panel.position += Vector2(50, 80)
	await host.get_tree().process_frame
	assert(image.get_rect().is_equal_approx(narrow_expected))
	assert(image.material == null)
	canvas.free()
