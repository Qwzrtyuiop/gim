extends RefCounted

# Warning presentation and signal state; maneuver decisions live in TrafficManeuvers.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const GameLabelFactory := preload("res://scripts/game/game_label_factory.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")


static func pulse_speeder_lane_change_warning(owner) -> void:
	if owner.speeder_lane_change_warning_label:
		owner.speeder_lane_change_warning_label.visible = true
		owner.speeder_lane_change_warning_label.modulate = Color(1.0, 0.94, 0.2, 1.0)
		var tween: Tween = owner.create_tween()
		tween.tween_property(owner.speeder_lane_change_warning_label, "modulate", Color(1.0, 0.24, 0.12, 1.0), 0.09)
		tween.tween_property(owner.speeder_lane_change_warning_label, "modulate", Color(1.0, 0.94, 0.2, 1.0), 0.09)
	owner.audio_manager.play_speeder_beep()


static func start_speeder_lane_change_warning(owner, sprite: Sprite2D, target_lane: int) -> void:
	if owner.speeder_lane_change_warning_active and is_instance_valid(owner.pending_speeder_lane_change_sprite) and owner.pending_speeder_lane_change_sprite == sprite:
		return

	owner.speeder_lane_change_warning_active = true
	owner.speeder_lane_change_warning_timer = 0.0
	owner.speeder_lane_change_warning_beeps_remaining = 3
	owner.speeder_lane_change_warning_target_lane = target_lane
	owner.pending_speeder_lane_change_sprite = sprite


static func clear_speeder_lane_change_warning(owner) -> void:
	owner.speeder_lane_change_warning_active = false
	owner.speeder_lane_change_warning_timer = 0.0
	owner.speeder_lane_change_warning_beeps_remaining = 0
	owner.speeder_lane_change_warning_target_lane = -1
	owner.pending_speeder_lane_change_sprite = null
	if owner.speeder_lane_change_warning_label:
		owner.speeder_lane_change_warning_label.visible = false


static func pulse_speeder_warning(owner) -> void:
	owner.speeder_warning_flash_timer = 0.18
	if owner.speeder_warning_label:
		owner.speeder_warning_label.visible = true
		owner.speeder_warning_label.modulate = Color(1.0, 0.94, 0.2, 1.0)
		var tween: Tween = owner.create_tween()
		tween.tween_property(owner.speeder_warning_label, "modulate", Color(1.0, 0.24, 0.12, 1.0), 0.09)
		tween.tween_property(owner.speeder_warning_label, "modulate", Color(1.0, 0.94, 0.2, 1.0), 0.09)
	owner.audio_manager.play_speeder_beep()


static func reset_speeder_timer(owner) -> void:
	owner.speeder_warning_active = false
	owner.speeder_warning_beeps_remaining = 0
	owner.speeder_warning_timer = 0.0
	owner.speeder_warning_flash_timer = 0.0
	owner.speeder_spawn_timer = owner.rng.randf_range(owner.speeder_spawn_min_delay, owner.speeder_spawn_max_delay)
	if owner.speeder_warning_label:
		owner.speeder_warning_label.visible = false


static func pulse_entity_lane_warning(owner, entity: Dictionary) -> void:
	var warning_label := get_entity_lane_warning_label(owner, entity)
	position_entity_lane_warning(owner, entity, warning_label)
	warning_label.visible = true
	warning_label.modulate = Color(1.0, 0.94, 0.2, 1.0)

	var tween: Tween = owner.create_tween()
	tween.tween_property(warning_label, "modulate", Color(1.0, 0.2, 0.12, 1.0), 0.08)
	tween.tween_property(warning_label, "modulate", Color(1.0, 0.94, 0.2, 0.0), 0.1)
	tween.tween_callback(Callable(warning_label, "hide"))
	owner.audio_manager.play_speeder_beep()


static func get_entity_lane_warning_label(owner, entity: Dictionary) -> Label:
	var sprite: Sprite2D = entity["sprite"]
	var warning_label := sprite.get_node_or_null("LaneChangeWarning") as Label
	if warning_label:
		return warning_label

	warning_label = GameLabelFactory.make_label(42, Color(1.0, 0.94, 0.2, 1.0), 6)
	warning_label.name = "LaneChangeWarning"
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.text = "!"
	warning_label.size = Vector2(80.0, 70.0)
	warning_label.z_as_relative = false
	warning_label.z_index = owner.HEADLIGHT_Z_INDEX + 10
	warning_label.visible = false
	sprite.add_child(warning_label)
	position_entity_lane_warning(owner, entity, warning_label)
	return warning_label


static func update_oncoming_warning(owner, delta: float) -> bool:
	# Returns true only when the advance warning has finished and spawning may proceed.
	var interval := maxf(0.05, GameTuning.ONCOMING_WARNING_FLASH_INTERVAL)
	owner.oncoming_warning_elapsed += delta
	if owner.oncoming_warning_elapsed >= interval * maxi(1, GameTuning.ONCOMING_WARNING_BEEPS):
		clear_oncoming_warning(owner)
		return true
	if owner.oncoming_warning_label == null:
		var label := GameLabelFactory.make_label(48, Color.WHITE, 7)
		label.name = "OncomingLaneWarning"
		label.text = "!"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(90.0, 90.0)
		label.z_index = owner.HEADLIGHT_Z_INDEX + 10
		owner.add_child(label)
		owner.oncoming_warning_label = label
	var warning_label: Label = owner.oncoming_warning_label
	var viewport_size: Vector2 = owner.get_viewport_rect().size
	warning_label.position = Vector2(viewport_size.x - 120.0, VehicleGeometry.lane_y(owner, 0, viewport_size) - 92.0)
	var pulse := int(owner.oncoming_warning_elapsed / interval)
	if pulse != owner.oncoming_warning_beep_index:
		owner.oncoming_warning_beep_index = pulse
		owner.audio_manager.play_speeder_beep()
	var phase := fposmod(owner.oncoming_warning_elapsed, interval) / interval
	warning_label.visible = phase < 0.7
	warning_label.modulate = Color(1.0, 0.94, 0.2, 1.0) if phase < 0.35 else Color(1.0, 0.24, 0.12, 1.0)
	return false


static func clear_oncoming_warning(owner) -> void:
	owner.oncoming_warning_elapsed = -1.0
	owner.oncoming_warning_beep_index = -1
	if owner.oncoming_warning_label:
		owner.oncoming_warning_label.hide()


static func position_entity_lane_warning(owner, entity: Dictionary, warning_label: Label) -> void:
	var sprite: Sprite2D = entity["sprite"]
	var local_rect: Rect2 = VehicleGeometry.local_hitbox_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner)
	var safe_scale := Vector2(
		1.0 / maxf(0.001, absf(sprite.scale.x)),
		1.0 / maxf(0.001, absf(sprite.scale.y))
	)
	warning_label.scale = safe_scale
	warning_label.position = Vector2(
		-warning_label.size.x * 0.5 * safe_scale.x,
		local_rect.position.y - warning_label.size.y * safe_scale.y - 8.0
	)
