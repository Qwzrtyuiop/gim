extends RefCounted


static func next_speed(
	current_speed: float,
	delta: float,
	accelerating: bool,
	braking: bool,
	player_lane: int,
	background_type: String,
	player_acceleration: float,
	player_acceleration_x: float,
	bottom_lane_player_acceleration_x: float,
	player_brake_deceleration: float,
	player_brake_x: float,
	player_min_cruise_speed: float,
	player_coast_deceleration: float,
	player_coast_x: float,
	player_max_speed: float,
	boosting: bool,
	boost_speed_x: float,
	boost_acceleration_x: float
) -> float:
	var effective_max_speed: float = player_max_speed * maxf(1.0, boost_speed_x)
	var effective_acceleration_x: float = player_acceleration_x
	if boosting:
		effective_acceleration_x *= boost_acceleration_x
	var speed := current_speed
	if accelerating and not braking:
		speed += player_acceleration * effective_acceleration_x * lane_acceleration_multiplier(
			background_type,
			player_lane,
			bottom_lane_player_acceleration_x
		) * delta
	elif braking and not accelerating:
		speed -= player_brake_deceleration * player_brake_x * delta
	else:
		speed = move_toward(speed, player_min_cruise_speed, player_coast_deceleration * player_coast_x * delta)

	return clampf(speed, 0.0, effective_max_speed)


static func lane_acceleration_multiplier(background_type: String, player_lane: int, bottom_lane_player_acceleration_x: float) -> float:
	if background_type == "barangay-streets" and player_lane == 2:
		return bottom_lane_player_acceleration_x
	return 1.0


static func changed_lane(current_lane: int, direction: int, min_lane := 0, max_lane := 2) -> int:
	return clampi(current_lane + direction, min_lane, max_lane)


static func distance_delta(player_speed: float, distance_scale: float, delta: float) -> float:
	return player_speed * distance_scale * delta


static func wiggle_amount(
	game_state: String,
	stage_clear_exiting: bool,
	player_wiggle_stop_speed: float,
	stage_clear_player_exit_speed: float,
	player_speed: float,
	player_wiggle_intensity_x: float
) -> float:
	if game_state != "playing" and not stage_clear_exiting:
		return 0.0

	var stop_speed := maxf(0.001, player_wiggle_stop_speed)
	var wiggle_speed := stage_clear_player_exit_speed if stage_clear_exiting else player_speed
	return clampf(wiggle_speed / stop_speed, 0.0, 1.0) * player_wiggle_intensity_x


static func apply_motion(
	player: Sprite2D,
	delta: float,
	move_forward: bool,
	player_x: float,
	target_y: float,
	stage_clear_player_exit_speed: float,
	player_lane_lerp_speed: float,
	player_lane_lerp_x: float,
	player_wiggle_x_frequency: float,
	player_wiggle_x_pixels: float,
	player_wiggle_rotation_frequency: float,
	player_wiggle_rotation_radians: float,
	wiggle_strength: float
) -> void:
	if move_forward:
		player.position.x += stage_clear_player_exit_speed * delta
	else:
		player.position.x = player_x + sin(Time.get_ticks_msec() * player_wiggle_x_frequency) * player_wiggle_x_pixels * wiggle_strength

	player.position.y = lerpf(player.position.y, target_y, minf(1.0, delta * player_lane_lerp_speed * player_lane_lerp_x))
	player.rotation = sin(Time.get_ticks_msec() * player_wiggle_rotation_frequency) * player_wiggle_rotation_radians * wiggle_strength
