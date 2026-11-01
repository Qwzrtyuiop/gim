extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")

const ArcadePowerups := preload("res://scripts/game/arcade_powerups.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const GameInput := preload("res://scripts/game/game_input.gd")
const PlayerVehicleBehavior := preload("res://scripts/game/player_vehicle_behavior.gd")
const PlayerPassing := preload("res://scripts/game/player_passing_controller.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleVisuals := preload("res://scripts/game/vehicle_visuals.gd")
const VehicleWheelAnimation := preload("res://scripts/game/vehicle_wheel_animation.gd")

const BOOST_GAS_SAVE_INTERVAL := 0.75


static func update_hit_state(owner, delta: float) -> void:
	owner.player_hit_recovery_timer = maxf(0.0, owner.player_hit_recovery_timer - delta)
	if owner.player_hit_invincible_timer <= 0.0:
		owner.player_hit_flicker_timer = 0.0
		owner.player_hit_flicker_visible = true
		return

	owner.player_hit_invincible_timer = maxf(0.0, owner.player_hit_invincible_timer - delta)
	owner.player_hit_flicker_timer -= delta
	if owner.player_hit_flicker_timer <= 0.0:
		owner.player_hit_flicker_timer = owner.crash_flicker_interval
		owner.player_hit_flicker_visible = not owner.player_hit_flicker_visible


static func apply_hit_visuals(owner) -> void:
	if owner.player == null:
		return

	if owner.game_state != "playing" or owner.player_hit_invincible_timer <= 0.0:
		owner.player.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	var flicker_alpha: float = 1.0 if owner.player_hit_flicker_visible else owner.crash_flicker_alpha
	owner.player.modulate = Color(1.0, 1.0, 1.0, flicker_alpha)


static func create_player(owner) -> void:
	owner.player = Sprite2D.new()
	owner.player.texture = owner.PLAYER_TEXTURE
	owner.player.centered = true
	VehicleWheelAnimation.attach(owner.player, "player_tricycle")
	owner.player.z_index = VehicleGeometry.z_for_lane(owner, owner.player_lane, 1)
	owner.add_child(owner.player)
	VehicleVisuals.apply_headlight(owner, owner.player, owner.PLAYER_HITBOX_INSET)


static func layout_player(owner, size: Vector2) -> void:
	if owner.stage_traffic == "busy":
		owner.player_x = BusyTrafficBehavior.player_x(size)

	owner.player.scale = _target_scale(owner, size)
	_update_draw_order(owner)
	VehicleVisuals.apply_shadow(owner, owner.player, owner.PLAYER_HITBOX_INSET)
	VehicleVisuals.apply_headlight(owner, owner.player, owner.PLAYER_HITBOX_INSET)
	owner.player.position = Vector2(
		owner.player_x,
		VehicleGeometry.sprite_y_for_hitbox_bottom(
			owner.player,
			_target_guide_y(owner, size),
			owner.PLAYER_HITBOX_INSET,
			owner
		)
	)


static func handle_speed(owner, delta: float) -> void:
	var powerups: Variant = ArcadePowerups.for_owner(owner)
	var free_boost: bool = powerups != null and powerups.free_boost_seconds > 0.0
	owner.boost_active = free_boost or (GameInput.is_boosting() and PlayerState.boost_gas_is_available())
	if owner.boost_active:
		owner.boost_speed_x = owner.player_boost_max_speed_x
		if not free_boost:
			consume_boost_gas(owner, delta)
	else:
		owner.boost_speed_x = move_toward(
			owner.boost_speed_x,
			1.0,
			owner.player_boost_release_decay_x * delta
		)

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
		owner.player_max_speed,
		owner.boost_active,
		owner.boost_speed_x,
		owner.player_boost_acceleration_x
	)


static func consume_boost_gas(owner, delta: float) -> void:
	if not PlayerState.stage_uses_gas():
		return
	var gas_to_spend: float = owner.boost_gas_consumption_percent_per_second * PlayerState.get_boost_gas_consumption_multiplier() * delta
	var gas_spent: float = PlayerState.drain_gas(gas_to_spend, false)
	if gas_spent < gas_to_spend:
		owner.boost_active = false

	owner.boost_gas_save_timer += delta
	if owner.boost_gas_save_timer >= BOOST_GAS_SAVE_INTERVAL:
		owner.boost_gas_save_timer = 0.0
		PlayerState.flush_deferred_save()


static func update_player(owner, delta: float, move_forward := false) -> void:
	var wheel_speed := 0.0
	if owner.game_state == "playing":
		wheel_speed = owner.player_speed
	elif owner.player_is_stage_clear_exiting:
		wheel_speed = owner.stage_clear_player_exit_speed
	VehicleWheelAnimation.update(owner.player, wheel_speed, delta)
	var target_scale := _target_scale(owner, owner.get_viewport_rect().size)
	owner.player.scale = owner.player.scale.lerp(target_scale, minf(1.0, delta * owner.player_perspective_lerp_speed))
	_update_draw_order(owner)
	VehicleVisuals.apply_shadow(owner, owner.player, owner.PLAYER_HITBOX_INSET)
	VehicleVisuals.apply_headlight(owner, owner.player, owner.PLAYER_HITBOX_INSET)

	var target_y: float = VehicleGeometry.sprite_y_for_hitbox_bottom(
		owner.player,
		_target_guide_y(owner, owner.get_viewport_rect().size),
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
	if owner.player_hit_recovery_timer > 0.0:
		return
	if PlayerPassing.is_active(owner):
		return
	owner.player_lane = PlayerVehicleBehavior.changed_lane(owner.player_lane, direction)
	owner.player.z_index = VehicleGeometry.z_for_lane(owner, owner.player_lane, 1)


static func _target_guide_y(owner, size: Vector2) -> float:
	var guide: float = VehicleGeometry.lane_y(owner, owner.player_lane, size)
	if PlayerPassing.is_active(owner):
		var adjacent: float = VehicleGeometry.lane_y(owner, PlayerPassing.adjacent_lane(owner), size)
		guide = lerpf(guide, adjacent, 0.5 * PlayerPassing.blend(owner))
	return guide


static func _target_scale(owner, size: Vector2) -> Vector2:
	var fallback := VehicleGeometry.scale_for_height(owner.PLAYER_TEXTURE, min(GameTuning.PLAYER_FALLBACK_HEIGHT, size.y * GameTuning.PLAYER_FALLBACK_HEIGHT_RATIO))
	var scale: Vector2 = VehicleGeometry.scale_for_vehicle_in_lane(owner, "player_tricycle", fallback, owner.player_lane)
	if PlayerPassing.is_active(owner):
		var adjacent: Vector2 = VehicleGeometry.scale_for_vehicle_in_lane(owner, "player_tricycle", fallback, PlayerPassing.adjacent_lane(owner))
		scale = scale.lerp(adjacent, 0.5 * PlayerPassing.blend(owner))
	return scale


static func _update_draw_order(owner) -> void:
	var depth := VehicleGeometry.z_for_lane(owner, owner.player_lane, 1)
	if PlayerPassing.is_active(owner):
		var adjacent := VehicleGeometry.z_for_lane(owner, PlayerPassing.adjacent_lane(owner), 1)
		depth = roundi(lerpf(float(depth), float(adjacent), 0.5 * PlayerPassing.blend(owner)))
	owner.player.z_index = depth
