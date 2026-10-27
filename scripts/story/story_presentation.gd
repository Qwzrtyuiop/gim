extends RefCounted

# Backgrounds, camera transforms, portraits, and screen transitions.

const StoryGalleryUnlocker := preload("res://scripts/story/story_gallery_unlocker.gd")
const StoryPortraitOutline := preload("res://scripts/story/story_portrait_outline.gd")
const CharacterSpriteRuntime := preload("res://scripts/story/story_character_sprite_runtime.gd")
const StoryInterface := preload("res://scripts/story/story_interface.gd")
const StoryBackgroundWeather := preload("res://scripts/story/story_background_weather.gd")
const INTRO_FADE_SECONDS := 0.35
const OUTRO_FADE_SECONDS := 0.35
const DEFAULT_SCREEN_FADE_SECONDS := 0.24
const DEFAULT_BG_CAMERA_DURATION := 0.0
const MIN_BG_ZOOM := 0.7
const DEFAULT_BG_FIT_SCALE := 0.94
const ACTIVE_PORTRAIT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const INACTIVE_PORTRAIT_MODULATE := Color(0.56, 0.56, 0.60, 0.82)


static func apply_line_visuals(owner, line: Dictionary) -> void:
	CharacterSpriteRuntime.apply_line(owner, line)
	if line.has("portraits"):
		owner.portrait_layer.replace_portraits(CharacterSpriteRuntime.resolve_portraits(owner, line["portraits"]))
	var background_changed := false
	var next_background_ref = owner.current_background_ref
	if line.has("background"):
		next_background_ref = line.get("background", null)
		background_changed = next_background_ref != owner.current_background_ref
	if line.has("left_portrait"):
		owner.current_left_portrait_ref = line.get("left_portrait", null)
	if line.has("right_portrait"):
		owner.current_right_portrait_ref = line.get("right_portrait", null)

	var background_fade_duration := float(line.get("background_fade", line.get("bg_fade", 0.0)))
	if line.has("background") and background_fade_duration > 0.0:
		await transition_background_with_fade(owner, next_background_ref, background_changed, line, background_fade_duration)
	else:
		if line.has("background"):
			owner.current_background_ref = next_background_ref
			set_background_texture(owner, owner.current_background_ref, background_changed)
		apply_line_background_camera(owner, line)
	if line.has("show_debt_overlay"):
		await StoryInterface.show_debt_overlay(owner, line.get("show_debt_overlay", {}))
	if line.has("hide_debt_overlay"):
		await StoryInterface.hide_debt_overlay(owner, line.get("hide_debt_overlay", {}))
	set_portrait(owner, owner.left_portrait_frame, owner.left_portrait, owner.current_left_portrait_ref)
	set_portrait(owner, owner.right_portrait_frame, owner.right_portrait, owner.current_right_portrait_ref)
	apply_portrait_focus_from_side(owner, str(line.get("focus", line.get("speaker_side", "none"))))
	if bool(line.get("speaker_portraits", owner.story_payload.get("speaker_portraits", false))) and not line.has("portraits"):
		var placement: String = str(line.get("speaker_placement", owner.story_payload.get("speaker_placement", "portrait")))
		owner.portrait_layer.replace_portraits(CharacterSpriteRuntime.for_speaker(owner, str(line.get("speaker", "")), placement))
	save_portrait_state(owner)


static func apply_portrait_focus_from_side(owner, focus_side: String) -> void:
	owner.current_focus_side = str(focus_side).to_lower()
	var left_visible: bool = owner.left_portrait_frame.visible
	var right_visible: bool = owner.right_portrait_frame.visible

	if owner.current_focus_side.is_empty() or owner.current_focus_side == "none":
		if left_visible and not right_visible:
			owner.current_focus_side = "left"
		elif right_visible and not left_visible:
			owner.current_focus_side = "right"

	if left_visible:
		owner.left_portrait_frame.modulate = ACTIVE_PORTRAIT_MODULATE if owner.current_focus_side == "left" else INACTIVE_PORTRAIT_MODULATE
	if right_visible:
		owner.right_portrait_frame.modulate = ACTIVE_PORTRAIT_MODULATE if owner.current_focus_side == "right" else INACTIVE_PORTRAIT_MODULATE


static func set_portrait(owner, frame: Panel, portrait_rect: TextureRect, texture_ref) -> void:
	var options: Dictionary = texture_ref if texture_ref is Dictionary else {}
	if texture_ref is Dictionary:
		texture_ref = options.get("texture", options.get("path", null))
	var portrait_texture := resolve_texture(texture_ref)
	portrait_rect.flip_h = bool(options.get("flip_h", false))
	portrait_rect.flip_v = bool(options.get("flip_v", false))
	frame.visible = portrait_texture != null
	portrait_rect.texture = portrait_texture
	StoryPortraitOutline.apply_to(portrait_rect)
	if frame.visible:
		frame.modulate = INACTIVE_PORTRAIT_MODULATE
		# Legacy left/right portraits also sit above the dialogue box.
		frame.position.y = maxf(0.0, owner.dialogue_panel.position.y - 350.0)
		frame.size.y = owner.dialogue_panel.position.y - frame.position.y
	refresh_portrait_visibility(owner)


static func set_background_texture(owner, texture_ref, reset_camera := false) -> void:
	owner.current_background_ref = texture_ref
	var resolved_texture := resolve_texture(texture_ref)
	owner.background.texture = resolved_texture
	owner.background.visible = resolved_texture != null
	StoryBackgroundWeather.apply(owner.background)
	AmbientAudioManager.set_rain_indoors(StoryBackgroundWeather.is_indoor_background(resolved_texture))
	if resolved_texture != null:
		remember_gallery_image(owner, texture_ref)
	if reset_camera:
		owner.background_zoom = 1.0
		owner.background_pan = Vector2.ZERO
	refresh_background_transform(owner)
	# A new texture can keep identical geometry, so it may emit no rect-change signal.
	if is_instance_valid(owner.portrait_layer):
		owner.portrait_layer.layout_portraits()
	refresh_portrait_visibility(owner)
	save_portrait_state(owner)


static func refresh_portrait_visibility(owner) -> void:
	var path := ""
	if owner.background.texture != null:
		path = owner.background.texture.resource_path
	if path.is_empty() and owner.current_background_ref is String:
		path = owner.current_background_ref
	var hide_portraits := "/specialcg/" in path.replace("\\", "/").to_lower()
	if is_instance_valid(owner.portrait_layer):
		owner.portrait_layer.visible = not hide_portraits
	owner.left_portrait_frame.visible = owner.left_portrait.texture != null and not hide_portraits
	owner.right_portrait_frame.visible = owner.right_portrait.texture != null and not hide_portraits


static func remember_gallery_image(owner, texture_ref) -> void:
	var image_path: String = StoryGalleryUnlocker.normalize_image_path(texture_ref)
	if image_path.is_empty():
		return
	owner.shown_gallery_images[image_path] = true


static func unlock_gallery_images(owner) -> void:
	StoryGalleryUnlocker.unlock_gallery_images(PlayerState, shown_gallery_image_paths(owner))


static func shown_gallery_image_paths(owner) -> Array:
	var image_paths: Array = []
	for image_path_variant in owner.shown_gallery_images.keys():
		var image_path: String = str(image_path_variant)
		if image_path.is_empty():
			continue
		image_paths.append(image_path)
	return image_paths


static func resolve_texture(texture_ref) -> Texture2D:
	if texture_ref is Texture2D:
		return texture_ref as Texture2D

	var texture_path := str(texture_ref)
	if texture_path.is_empty():
		return null
	if not ResourceLoader.exists(texture_path):
		return null

	var resource := load(texture_path)
	if resource is Texture2D:
		return resource as Texture2D
	return null


static func play_intro_fade(owner) -> void:
	await fade_screen_overlay(owner, 0.0, INTRO_FADE_SECONDS)


static func play_outro_fade(owner) -> void:
	await fade_screen_overlay(owner, 1.0, OUTRO_FADE_SECONDS)


static func apply_portrait_action(owner, action_data: Dictionary) -> void:
	if action_data.has("id"):
		owner.portrait_layer.set_portrait(CharacterSpriteRuntime.resolve_portrait_update(owner, action_data))
		save_portrait_state(owner)
		return
	var side := str(action_data.get("side", "left")).to_lower()
	var texture_ref = action_data.get("texture", action_data.get("portrait", action_data.get("path", null)))
	if action_data.has("flip_h") or action_data.has("flip_v"):
		texture_ref = {"texture": texture_ref, "flip_h": action_data.get("flip_h", false), "flip_v": action_data.get("flip_v", false)}
	match side:
		"right":
			owner.current_right_portrait_ref = texture_ref
		_:
			owner.current_left_portrait_ref = texture_ref
	refresh_portrait_state(owner)


static func apply_character_sprite_action(owner, action_data: Dictionary) -> void:
	if CharacterSpriteRuntime.set_sprite(owner, str(action_data.get("character_id", "")), str(action_data.get("sprite", ""))):
		save_portrait_state(owner)


static func clear_portrait_action(owner, action_data: Dictionary) -> void:
	if action_data.has("id"):
		owner.portrait_layer.remove_portrait(str(action_data["id"]))
		save_portrait_state(owner)
		return
	var side := str(action_data.get("side", "left")).to_lower()
	match side:
		"right":
			owner.current_right_portrait_ref = null
		_:
			owner.current_left_portrait_ref = null
	refresh_portrait_state(owner)


static func refresh_portrait_state(owner) -> void:
	set_portrait(owner, owner.left_portrait_frame, owner.left_portrait, owner.current_left_portrait_ref)
	set_portrait(owner, owner.right_portrait_frame, owner.right_portrait, owner.current_right_portrait_ref)
	apply_portrait_focus_from_side(owner, owner.current_focus_side)
	save_portrait_state(owner)


static func replace_portraits(owner, entries: Array) -> void:
	owner.portrait_layer.replace_portraits(CharacterSpriteRuntime.resolve_portraits(owner, entries))
	save_portrait_state(owner)


static func save_portrait_state(owner) -> void:
	if owner._is_replay_mode():
		return
	var state := {
		"portraits": owner.portrait_layer.entries.duplicate(true),
		"character_sprites": owner.character_sprites.duplicate(true),
		"left": owner.current_left_portrait_ref,
		"right": owner.current_right_portrait_ref,
		"background": owner.current_background_ref,
	}
	if state == owner.story_payload.get("_portrait_state", {"portraits": [], "left": null, "right": null}):
		return
	owner.story_payload["_portrait_state"] = state
	if owner.checkpoint_batch_depth == 0:
		PlayerState.set_pending_story(owner.story_payload)


static func apply_line_background_camera(owner, line: Dictionary) -> void:
	if not has_background_camera_data(line):
		return
	apply_background_camera_action(owner, line)


static func transition_background_with_fade(owner, next_background_ref, background_changed: bool, line: Dictionary, duration: float) -> void:
	var fade_duration := maxf(0.0, duration)
	if fade_duration <= 0.0:
		owner.current_background_ref = next_background_ref
		set_background_texture(owner, owner.current_background_ref, background_changed)
		apply_line_background_camera(owner, line)
		return

	var half_duration := fade_duration * 0.5
	await fade_background_overlay(owner, 1.0, half_duration)
	owner.current_background_ref = next_background_ref
	set_background_texture(owner, owner.current_background_ref, background_changed)
	apply_line_background_camera(owner, line)
	await fade_background_overlay(owner, 0.0, half_duration)


static func has_background_camera_data(data: Dictionary) -> bool:
	return data.has("camera") or data.has("zoom") or data.has("bg_zoom") or data.has("pan") or data.has("bg_pan") or data.has("focus")


static func apply_background_camera_action(owner, action_data: Dictionary) -> void:
	var camera_data: Variant = action_data.get("camera", action_data)
	var zoom: float = owner.background_zoom
	var pan: Vector2 = owner.background_pan
	var duration := float(action_data.get("duration", DEFAULT_BG_CAMERA_DURATION))

	if camera_data is Dictionary:
		var camera_dict := camera_data as Dictionary
		if camera_dict.has("zoom"):
			zoom = maxf(MIN_BG_ZOOM, float(camera_dict.get("zoom", owner.background_zoom)))
		elif camera_dict.has("bg_zoom"):
			zoom = maxf(MIN_BG_ZOOM, float(camera_dict.get("bg_zoom", owner.background_zoom)))

		if camera_dict.has("pan"):
			pan = parse_background_pan(owner, camera_dict.get("pan", owner.background_pan))
		elif camera_dict.has("bg_pan"):
			pan = parse_background_pan(owner, camera_dict.get("bg_pan", owner.background_pan))
		elif camera_dict.has("focus"):
			pan = parse_background_pan(owner, camera_dict.get("focus", owner.background_pan))

		if camera_dict.has("duration"):
			duration = float(camera_dict.get("duration", duration))
	else:
		pan = parse_background_pan(owner, camera_data)

	set_background_camera(owner, zoom, pan, duration)


static func set_background_camera(owner, zoom: float, pan: Vector2, duration := DEFAULT_BG_CAMERA_DURATION) -> void:
	owner.background_zoom = maxf(MIN_BG_ZOOM, zoom)
	owner.background_pan = Vector2(
		clampf(pan.x, -1.0, 1.0),
		clampf(pan.y, -1.0, 1.0)
	)
	refresh_background_transform(owner, duration)


static func parse_background_pan(owner, pan_data) -> Vector2:
	if pan_data is Vector2:
		return pan_data as Vector2
	if pan_data is Array:
		var pan_array := pan_data as Array
		if pan_array.size() >= 2:
			return Vector2(float(pan_array[0]), float(pan_array[1]))
	if pan_data is Dictionary:
		var pan_dict := pan_data as Dictionary
		return Vector2(
			float(pan_dict.get("x", 0.0)),
			float(pan_dict.get("y", 0.0))
		)

	var pan_preset := str(pan_data).to_lower().strip_edges()
	match pan_preset:
		"left":
			return Vector2(-1.0, 0.0)
		"right":
			return Vector2(1.0, 0.0)
		"top", "up":
			return Vector2(0.0, -1.0)
		"bottom", "down":
			return Vector2(0.0, 1.0)
		"top_left", "left_top":
			return Vector2(-1.0, -1.0)
		"top_right", "right_top":
			return Vector2(1.0, -1.0)
		"bottom_left", "left_bottom":
			return Vector2(-1.0, 1.0)
		"bottom_right", "right_bottom":
			return Vector2(1.0, 1.0)
		"center", "middle", "":
			return Vector2.ZERO
	return owner.background_pan


static func refresh_background_transform(owner, duration := 0.0) -> void:
	if owner.background == null or not is_instance_valid(owner.background):
		return

	if owner.background_motion_tween != null:
		owner.background_motion_tween.kill()
		owner.background_motion_tween = null

	if owner.background.texture == null:
		owner.background.visible = false
		return

	owner.background.visible = true
	var viewport_size: Vector2 = owner.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = owner.get_viewport_rect().size

	var texture_size: Vector2 = owner.background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		owner.background.position = Vector2.ZERO
		owner.background.size = viewport_size
		return

	var fit_scale := minf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	var target_size: Vector2 = texture_size * fit_scale * DEFAULT_BG_FIT_SCALE * owner.background_zoom
	# Keep the computed image size even when it fits. Refitting a viewport-sized
	# TextureRect discarded every zoom-out and caused a jump at the fit boundary.
	owner.background.stretch_mode = TextureRect.STRETCH_SCALE
	var target_position := Vector2.ZERO
	var x_space := viewport_size.x - target_size.x
	var y_space := viewport_size.y - target_size.y

	if target_size.x <= viewport_size.x:
		target_position.x = x_space * 0.5
	else:
		target_position.x = -(target_size.x - viewport_size.x) * ((owner.background_pan.x + 1.0) * 0.5)

	if target_size.y <= viewport_size.y:
		target_position.y = y_space * 0.5
	else:
		target_position.y = -(target_size.y - viewport_size.y) * ((owner.background_pan.y + 1.0) * 0.5)

	if duration <= 0.0:
		owner.background.position = target_position
		owner.background.size = target_size
		return

	owner.background_motion_tween = owner.create_tween()
	owner.background_motion_tween.set_parallel(true)
	owner.background_motion_tween.tween_property(owner.background, "position", target_position, duration)
	owner.background_motion_tween.tween_property(owner.background, "size", target_size, duration)


static func pause_for_seconds(owner, duration: float) -> void:
	if duration <= 0.0:
		return
	await owner.get_tree().create_timer(duration, false).timeout


static func fade_background_overlay(owner, target_alpha: float, duration: float) -> void:
	if duration <= 0.0:
		owner.background_fade_overlay.color.a = target_alpha
		return

	var tween: Tween = owner.create_tween()
	tween.tween_property(owner.background_fade_overlay, "color:a", target_alpha, duration)
	await tween.finished


static func fade_screen_overlay(owner, target_alpha: float, duration: float) -> void:
	if duration <= 0.0:
		owner.fade_overlay.color.a = target_alpha
		return

	var tween: Tween = owner.create_tween()
	tween.tween_property(owner.fade_overlay, "color:a", target_alpha, duration)
	await tween.finished
