extends RefCounted

const Benny := preload("res://scripts/home/construction_benny_spawn.gd")
const ChurchAudio := preload("res://scripts/home/church_audio.gd")
const ConstructionAudio := preload("res://scripts/home/construction_audio.gd")
const BackgroundWeather := preload("res://scripts/story/story_background_weather.gd")
const StoryCatalog := preload("res://scripts/story/story_payload_catalog.gd")


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	await _test_benny_replacement(host)
	await _test_location_audio(host)
	print("PASS: replacement Benny extraction/mask/placement, local church/construction SFX loops and ownership, church prayer audio in both languages")


static func _test_benny_replacement(host: Node) -> void:
	var background := TextureRect.new()
	background.texture = Benny.DAY_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.get_tree().root.add_child(background)
	var benny := Benny.new()
	background.add_child(benny)
	benny.set_active(true)
	var texture_id := benny.texture_normal.get_instance_id()
	var mask_id := benny.texture_click_mask.get_instance_id()
	var image: Image = benny.texture_normal.get_image()
	assert(image.get_size() == Vector2i(Benny.REGION.size))
	assert(image.detect_alpha() != Image.ALPHA_NONE, "The opaque export must not leave a daylight background rectangle at night")
	assert(image.get_pixel(0, 0).a == 0.0 and not benny.texture_click_mask.get_bit(0, 0), "Background-only pixels cannot draw or intercept clicks")
	assert(benny.texture_click_mask.get_true_bit_count() > 8000 and benny.texture_click_mask.get_true_bit_count() < 16000, "The click mask follows Benny instead of his whole canvas or crop rectangle")
	var clicks: Array[String] = []
	benny.can_interact = func() -> bool: return true
	benny.interacted.connect(func(id: String) -> void: clicks.append(id))
	benny.pressed.emit()
	assert(clicks == ["benny"])
	benny.set_interaction_enabled(false)
	benny.pressed.emit()
	assert(clicks.size() == 1)
	for viewport_size in [Vector2(1280, 720), Vector2(640, 360), Vector2(900, 900)]:
		background.size = viewport_size
		await host.get_tree().process_frame
		var fit := minf(viewport_size.x / Benny.ART_SIZE.x, viewport_size.y / Benny.ART_SIZE.y)
		assert(benny.position.is_equal_approx((viewport_size - Benny.ART_SIZE * fit) * 0.5 + Benny.REGION.position * fit))
		assert(benny.size.is_equal_approx(Benny.REGION.size * fit))
	background.self_modulate = Color(0.3, 0.4, 0.6)
	await host.get_tree().process_frame
	assert(benny.self_modulate == background.self_modulate)
	benny.set_active(false)
	benny.set_active(true)
	assert(benny.texture_normal.get_instance_id() == texture_id and benny.texture_click_mask.get_instance_id() == mask_id, "Revisits reuse prepared art rather than repeating pixel extraction")
	background.free()


static func _test_location_audio(host: Node) -> void:
	for audio_script: Script in [ChurchAudio, ConstructionAudio]:
		var audio: Node = audio_script.new()
		host.get_tree().root.add_child(audio)
		assert(not audio.active and not audio.ambience_player.playing)
		assert(audio.ambience_player.get_meta("audio_category") == "sfx")
		assert(AudioSettingsManager.get_player_base_db(audio.ambience_player) == -8.0)
		assert(audio.ambience_player.stream.loop and not audio_script.AMBIENCE.loop)
		audio.set_active(true)
		audio.ambience_player.seek(1.25)
		var position: float = audio.ambience_player.get_playback_position()
		audio.set_active(true)
		assert(audio.ambience_player.playing and is_equal_approx(audio.ambience_player.get_playback_position(), position), "Refreshing a local loop cannot restart it")
		audio.set_active(false)
		assert(not audio.ambience_player.playing)
		var reference: WeakRef = weakref(audio.ambience_player)
		audio.free()
		assert(reference.get_ref() == null, "Location-owned players must be freed with their owner")
	assert(BackgroundWeather.is_indoor_background(load("res://assets/story/backgrounds/churchday.png")))
	var language: String = StoryLanguageManager.get_language()
	for selected in ["english", "tagalog"]:
		StoryLanguageManager.set_language(selected)
		for prefix in ["church_prayer_visit_", "church_prayer_short_"]:
			for number in range(1, 6):
				var payload := StoryCatalog.build(prefix + str(number))
				assert(payload.ambient_sfx.path == "res://assets/audio/ambience/church.mp3" and payload.ambient_sfx.loop)
	StoryLanguageManager.set_language(language)
