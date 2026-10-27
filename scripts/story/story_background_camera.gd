extends RefCounted

# VN pan/zoom commands and fitted background geometry. Runtime state remains
# on the story reader so checkpoints and tween ownership keep their contracts.
const DEFAULT_BG_CAMERA_DURATION := 0.0
const MIN_BG_ZOOM := 0.7
const DEFAULT_BG_FIT_SCALE := 0.94


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
