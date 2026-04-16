extends RefCounted

const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const GameInput := preload("res://scripts/game/game_input.gd")
const PlayerVehicleBehavior := preload("res://scripts/game/player_vehicle_behavior.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleVisuals := preload("res://scripts/game/vehicle_visuals.gd")


static func create_player(owner) -> void:
	owner.player = Sprite2D.new()
	owner.player.texture = owner.PLAYER_TEXTURE
	owner.player.centered = true
	owner.player.z_index = VehicleGeometry.z_for_lane(owner, owner.player_lane, 1)
	owner.add_child(owner.player)
	VehicleVisuals.apply_headlight(owner, owner.player, owner.PLAYER_HITBOX_INSET)


static func layout_player(owner, size: Vector2) -> void:
	if owner.stage_traffic == "busy":
		owner.player_x = BusyTrafficBehavior.player_x(size)

	owner.player.scale = VehicleGeometry.scale_for_vehicle_in_lane(
		owner,
		"player_tricycle",
		VehicleGeometry.scale_for_height(owner.PLAYER_TEXTURE, min(116.0, size.y * 0.155)),
		owner.player_lane
	)
	VehicleVisuals.apply_shadow(owner, owner.player, owner.PLAYER_HITBOX_INSET)
	VehicleVisuals.apply_headlight(owner, owner.player, owner.PLAYER_HITBOX_INSET)
	owner.player.position = Vector2(
		owner.player_x,
		VehicleGeometry.sprite_y_for_hitbox_bottom(
			owner.player,
			VehicleGeometry.lane_y(owner, owner.player_lane, size),
			owner.PLAYER_HITBOX_INSET,
			owner
		)
	)


static func handle_speed(owner, delta: float) -> void:
	owner.player_speed = PlayerVehicleBehavior.next_speed(
		owner.player_speed,
		delta,
		GameInput.is_accelerating(),
		GameInput.is_braking(),
		owner.player_lane,
		owner.background_type,
		owner.player_acceleration,
		owner.player_acceleration_x,
		owner.bottom_lane_player_acceleration_x,
		owner.player_brake_deceleration,
		owner.player_brake_x,
		owner.player_min_cruise_speed,
		owner.player_coast_deceleration,
		owner.player_coast_x,
		owner.player_max_speed
	)


static func update_player(owner, delta: float, move_forward := false) -> void:
	var target_scale: Vector2 = VehicleGeometry.scale_for_vehicle_in_lane(
		owner,
		"player_tricycle",
		VehicleGeometry.scale_for_height(owner.PLAYER_TEXTURE, min(116.0, owner.get_viewport_rect().size.y * 0.155)),
		owner.player_lane
	)
	owner.player.scale = owner.player.scale.lerp(target_scale, minf(1.0, delta * owner.player_perspective_lerp_speed))
	VehicleVisuals.apply_shadow(owner, owner.player, owner.PLAYER_HITBOX_INSET)
	VehicleVisuals.apply_headlight(owner, owner.player, owner.PLAYER_HITBOX_INSET)

	var target_y: float = VehicleGeometry.sprite_y_for_hitbox_bottom(
		owner.player,
		VehicleGeometry.lane_y(owner, owner.player_lane, owner.get_viewport_rect().size),
		owner.PLAYER_HITBOX_INSET,
		owner
	)
	var wiggle_amount := PlayerVehicleBehavior.wiggle_amount(
		owner.game_state,
		owner.player_is_stage_clear_exiting,
		owner.player_wiggle_stop_speed,
		owner.stage_clear_player_exit_speed,
		owner.player_speed,
		owner.player_wiggle_intensity_x
	)
	PlayerVehicleBehavior.apply_motion(
		owner.player,
		delta,
		move_forward,
		owner.player_x,
		target_y,
		owner.stage_clear_player_exit_speed,
		owner.player_lane_lerp_speed,
		owner.player_lane_lerp_x,
		owner.player_wiggle_x_frequency,
		owner.player_wiggle_x_pixels,
		owner.player_wiggle_rotation_frequency,
		owner.player_wiggle_rotation_radians,
		wiggle_amount
	)


static func change_lane(owner, direction: int) -> void:
	if owner.game_state != "playing":
		return
	owner.player_lane = PlayerVehicleBehavior.changed_lane(owner.player_lane, direction)
	owner.player.z_index = VehicleGeometry.z_for_lane(owner, owner.player_lane, 1)
