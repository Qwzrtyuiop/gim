extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")

const GameEconomyManager := preload("res://scripts/game/game_economy_manager.gd")
const GameEnvironmentController := preload("res://scripts/game/game_environment_controller.gd")
const GameStageSetup := preload("res://scripts/game/game_stage_setup.gd")
const VehicleCollisionController := preload("res://scripts/game/vehicle_collision_controller.gd")
const VehicleTrafficController := preload("res://scripts/game/vehicle_traffic_controller.gd")
const PlayerHorn := preload("res://scripts/game/player_horn_controller.gd")

const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const REPAIR_SCENE := "res://scenes/repair_transition.tscn"
const GAS_SAVE_INTERVAL := 0.75


static func update_progress(owner, delta: float) -> void:
	if PlayerState.hull <= 0:
		end_game(owner, "CRASH", "The tricycle hull has failed.")
		return
	# Capture driving conditions before reaching the destination saves the result.
	owner.trip_peak_speed_kmh = maxf(owner.trip_peak_speed_kmh, current_speed_kmh_exact(owner))
	if owner.ride_story_interruption.try_start(owner):
		return
	var distance_delta: float = owner.player_speed * distance_scale(owner) * delta
	owner.distance += distance_delta
	_drain_distance_gas(owner, distance_delta, delta)
	if owner.time_left > 0.0:
		owner.time_left -= delta
		if owner.time_left < 0.0:
			owner.overtime_seconds += -owner.time_left
			owner.time_left = 0.0
	else:
		owner.overtime_seconds += delta

	if owner.distance >= owner.target_distance:
		end_game(owner, "YOU MADE IT", "Target distance reached. Space/R to profit screen.")


static func distance_scale(owner) -> float:
	return owner.BASE_DISTANCE_SCALE * owner.player_distance_gain_x


static func _drain_distance_gas(owner, distance_delta: float, delta: float) -> void:
	if not PlayerState.stage_uses_gas():
		return
	var gas_to_spend: float = PlayerState.get_distance_gas_cost(distance_delta)
	if gas_to_spend <= 0.0:
		return

	PlayerState.drain_gas(gas_to_spend, false)
	owner.boost_gas_save_timer += delta
	if owner.boost_gas_save_timer >= GAS_SAVE_INTERVAL:
		owner.boost_gas_save_timer = 0.0
		PlayerState.flush_deferred_save()


static func current_speed_kmh(owner) -> int:
	return clampi(
		roundi(current_speed_kmh_exact(owner)),
		0,
		owner.SPEEDOMETER_MAX_KMH
	)


static func current_speed_kmh_exact(owner) -> float:
	return maxf(0.0, owner.player_speed / owner.SPEEDOMETER_REFERENCE_MAX_SPEED * owner.SPEEDOMETER_BASE_MAX_KMH)


static func end_game(owner, title: String, detail: String) -> void:
	if owner.game_state != "playing":
		return
	PlayerHorn.stop(owner)
	VehicleTrafficController.clear_oncoming_warning(owner)
	PlayerState.flush_deferred_save()
	if title == "CRASH":
		PlayerState.add_stress(GameTuning.HEAD_ON_CRASH_STRESS_GAIN)
		owner.audio_manager.play_crash_sfx()
		send_to_crash_repair(owner, detail)
		return
	if title == "TIME OUT":
		PlayerState.record_stage_failure()
	owner.game_state = title
	owner.end_message = detail
	if owner.speeder_warning_label:
		owner.speeder_warning_label.visible = false
	owner.speeder_warning_active = false
	VehicleTrafficController.clear_speeder_lane_change_warning(owner)
	if owner.game_state == "YOU MADE IT":
		owner.player_is_stage_clear_exiting = true
		store_stage_result(owner)
		VehicleCollisionController.remove_vehicles_behind_player(owner)


static func handle_player_hit(owner, detail: String, damage: int, stress_gain := -1) -> void:
	if owner.game_state != "playing" or owner.player_hit_invincible_timer > 0.0:
		return

	owner.trip_vehicle_collision_count += 1
	if owner.passenger_dialogue_controller != null:
		owner.passenger_dialogue_controller.react_to_delivery(owner, "collision")
	PlayerState.record_stage_crash()
	owner.audio_manager.play_crash_sfx()
	owner.player_speed = 0.0
	owner.boost_active = false
	owner.boost_speed_x = 1.0
	owner.player_hit_recovery_timer = owner.crash_recovery_seconds
	owner.player_hit_invincible_timer = maxf(owner.crash_recovery_seconds, owner.crash_invincible_seconds)
	owner.player_hit_flicker_timer = owner.crash_flicker_interval
	owner.player_hit_flicker_visible = false

	PlayerState._begin_state_batch()
	PlayerState.add_stress(damage if stress_gain < 0 else stress_gain)
	PlayerState.damage_hull(damage)
	PlayerState._end_state_batch()

	if PlayerState.hull <= 0:
		send_to_crash_repair(owner, detail)
		return
	owner.ride_story_interruption.try_start(owner)


static func send_to_crash_repair(owner, detail: String) -> void:
	if owner.game_state != "playing":
		return
	PlayerHorn.stop(owner)
	owner.game_state = "CRASH"
	VehicleTrafficController.clear_oncoming_warning(owner)
	PlayerState.flush_deferred_save()
	PlayerState._begin_state_batch()
	PlayerState.damage_hull(PlayerState.hull)
	PlayerState.record_stage_failure()
	GameEconomyManager.store_failed_stage_result(
		owner.stage_type,
		owner.stage_difficulty,
		owner.stage_time_of_day,
		owner.stage_traffic,
		owner.stage_special_type,
		owner.special_stage_id,
		owner.distance,
		owner.target_distance,
		detail
	)
	var failed_result := PlayerState.get_last_stage_result()
	failed_result["peak_speed_kmh"] = owner.trip_peak_speed_kmh
	failed_result["vehicle_collision_count"] = owner.trip_vehicle_collision_count
	PlayerState.set_last_stage_result(failed_result)
	# A fatal crash abandons the event interruption and follows normal repairs.
	PlayerState.active_event_special_stage.clear()
	PlayerState.begin_crash_repair()
	PlayerState._end_state_batch()
	# Save the bill now, but keep this scene (and its crash audio player) alive.
	owner.player_speed = 0.0
	owner.boost_active = false
	owner.crash_repair_transition_active = true
	owner.crash_repair_hold_remaining = maxf(0.0, GameTuning.CRASH_REPAIR_HOLD_SECONDS)
	owner.crash_repair_fade_time = 0.0
	if owner.game_hud != null:
		owner.game_hud.cancel_gameplay_entry_fade()
	if owner.fade_rect != null:
		# Dialogue bubbles are added after the HUD; fade over them as well.
		owner.fade_rect.z_index = 100
		owner.fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)


static func update_crash_repair_transition(owner, delta: float) -> void:
	if not owner.crash_repair_transition_active:
		return
	owner.crash_repair_hold_remaining = maxf(0.0, owner.crash_repair_hold_remaining - delta)
	if owner.crash_repair_hold_remaining > 0.0 or owner.audio_manager.is_crash_sfx_playing():
		return
	var fade_seconds := maxf(0.001, GameTuning.CRASH_REPAIR_FADE_SECONDS)
	# Leave a fully black frame on screen before changing scenes.
	if owner.crash_repair_fade_time >= fade_seconds:
		owner.crash_repair_transition_active = false
		owner.get_tree().change_scene_to_file(REPAIR_SCENE)
		return
	owner.crash_repair_fade_time += delta
	var alpha := smoothstep(0.0, fade_seconds, owner.crash_repair_fade_time)
	if owner.fade_rect != null:
		owner.fade_rect.color = Color(0.0, 0.0, 0.0, alpha)


static func try_retry_stage(owner) -> void:
	if owner.crash_repair_transition_active:
		return
	if owner.use_player_state_stage_sequence:
		var error: String = PlayerState.get_stage_start_error(owner.stage_type)
		if not error.is_empty():
			owner.end_message = error
			return
		if not PlayerState.spend_energy(GameTuning.TRIP_ENERGY_COST):
			owner.end_message = "Not enough energy. Head home to rest."
			return
		PlayerState.finish_ride_stress_shield()
		PlayerState.add_stress(GameTuning.TRIP_STRESS_GAIN)
	reset_game(owner)


static func reset_game(owner) -> void:
	GameStageSetup.apply_stage_profile(owner)
	GameStageSetup.apply_weather_modifiers(owner)
	GameStageSetup.apply_player_upgrades(owner)
	GameStageSetup.apply_character_modifiers(owner)
	GameStageSetup.apply_special_stage_blueprint(owner)
	GameStageSetup.apply_stress_modifiers(owner)
	for entity in owner.active_entities:
		if entity.has("sprite") and entity["sprite"] != null and is_instance_valid(entity["sprite"]):
			entity["sprite"].queue_free()
	owner.active_entities.clear()
	TrafficIndex.invalidate(owner)
	VehicleTrafficController.clear_speeder_lane_change_warning(owner)
	owner.spawn_timers = [0.4, 0.8, 1.2]
	owner.top_lane_pressure = 0.0
	owner.truck_horn_cooldown = 0.0
	owner.truck_horn_wave = {}
	owner.horn_held = false
	owner.traffic_jam_gaps.reset()
	VehicleTrafficController.clear_oncoming_warning(owner)
	owner.player_lane = GameTuning.PLAYER_START_LANE
	owner.player_speed = owner.player_start_speed
	owner.distance = 0.0
	owner.time_left = owner.time_limit
	owner.overtime_seconds = 0.0
	owner.game_state = "playing"
	owner.end_message = ""
	owner.player_is_stage_clear_exiting = false
	owner.passenger_rule_violation_count = 0
	owner.trip_peak_speed_kmh = 0.0
	owner.trip_vehicle_collision_count = 0
	owner.stage_clear_transition_started = false
	owner.stage_clear_fade_time = 0.0
	owner.crash_repair_transition_active = false
	owner.crash_repair_hold_remaining = 0.0
	owner.crash_repair_fade_time = 0.0
	owner.boost_active = false
	owner.boost_speed_x = 1.0
	owner.boost_gas_save_timer = 0.0
	owner.player_hit_recovery_timer = 0.0
	owner.player_hit_invincible_timer = 0.0
	owner.player_hit_flicker_timer = 0.0
	owner.player_hit_flicker_visible = true
	if owner.passenger_dialogue_controller != null:
		owner.passenger_dialogue_controller.clear()
	VehicleTrafficController.reset_speeder_timer(owner)
	if owner.fade_rect:
		owner.fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	if owner.player:
		owner.player.modulate = Color(1.0, 1.0, 1.0, 1.0)
	GameEnvironmentController.layout_scene(owner)


static func update_stage_clear_transition(owner, delta: float) -> void:
	if not owner.stage_clear_transition_started and owner.player.position.x > owner.get_viewport_rect().size.x + 160.0:
		owner.stage_clear_transition_started = true
		owner.stage_clear_fade_time = 0.0

	if not owner.stage_clear_transition_started:
		return

	owner.stage_clear_fade_time += delta
	var fade_ratio: float = clampf(owner.stage_clear_fade_time / owner.stage_clear_fade_seconds, 0.0, 1.0)
	owner.fade_rect.color = Color(0.0, 0.0, 0.0, fade_ratio)

	if fade_ratio >= 1.0:
		go_to_profit_screen(owner)


static func go_to_profit_screen(owner) -> void:
	if not PlayerState.active_event_special_stage.is_empty():
		owner.get_tree().change_scene_to_file(PlayerState.finish_event_special_stage())
		return
	var story_payload: Dictionary = GameEconomyManager.stage_complete_story_payload(
		owner.stage_type,
		owner.stage_difficulty,
		owner.stage_time_of_day,
		owner.stage_traffic
	)
	if not story_payload.is_empty():
		PlayerState.clear_pending_result_music()
		owner.get_tree().change_scene_to_file(STORY_SCENE)
		return

	PlayerState.set_pending_result_music(owner.audio_manager.get_result_music_carry_state())
	owner.get_tree().change_scene_to_file(STAGE_RESULTS_SCENE)


static func store_stage_result(owner) -> void:
	GameEconomyManager.store_stage_result(
		owner.stage_type,
		owner.stage_difficulty,
		owner.stage_time_of_day,
		owner.stage_traffic,
		owner.stage_special_type,
		owner.special_stage_id,
		owner.distance,
		owner.target_distance,
		owner.fare_php_per_meter,
		owner.overtime_seconds,
		owner.overtime_fare_penalty_php_per_second,
		owner.time_left,
		owner.time_bonus_php_per_second,
		owner.passenger_rule_violation_count,
		{
			"peak_speed_kmh": owner.trip_peak_speed_kmh,
			"vehicle_collision_count": owner.trip_vehicle_collision_count,
		}
	)
