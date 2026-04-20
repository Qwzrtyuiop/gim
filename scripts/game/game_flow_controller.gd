extends RefCounted

const GameEconomyManager := preload("res://scripts/game/game_economy_manager.gd")
const GameEnvironmentController := preload("res://scripts/game/game_environment_controller.gd")
const GameStageSetup := preload("res://scripts/game/game_stage_setup.gd")
const VehicleCollisionController := preload("res://scripts/game/vehicle_collision_controller.gd")
const VehicleTrafficController := preload("res://scripts/game/vehicle_traffic_controller.gd")

const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const GAS_SAVE_INTERVAL := 0.75


static func update_progress(owner, delta: float) -> void:
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
		roundi(owner.player_speed / owner.SPEEDOMETER_REFERENCE_MAX_SPEED * owner.SPEEDOMETER_BASE_MAX_KMH),
		0,
		owner.SPEEDOMETER_MAX_KMH
	)


static func end_game(owner, title: String, detail: String) -> void:
	if owner.game_state != "playing":
		return
	PlayerState.flush_deferred_save()
	if title == "CRASH":
		owner.audio_manager.play_crash_sfx()
	if title == "CRASH" or title == "TIME OUT":
		PlayerState.record_stage_failure()
	if (title == "CRASH" or title == "TIME OUT") and PlayerState.energy <= 0:
		owner.game_state = "GAME OVER"
		owner.end_message = "Out of energy. Press any key to return to menu."
	else:
		owner.game_state = title
		owner.end_message = detail
	if owner.speeder_warning_label:
		owner.speeder_warning_label.visible = false
	owner.speeder_warning_active = false
	if owner.game_state == "YOU MADE IT":
		owner.player_is_stage_clear_exiting = true
		store_stage_result(owner)
		VehicleCollisionController.remove_vehicles_behind_player(owner)


static func try_retry_stage(owner) -> void:
	if owner.use_player_state_stage_sequence and not PlayerState.spend_energy(1):
		owner.end_message = "No energy left. Visit the store or reset progress."
		return
	reset_game(owner)


static func reset_game(owner) -> void:
	GameStageSetup.apply_stage_profile(owner)
	GameStageSetup.apply_player_upgrades(owner)
	for entity in owner.active_entities:
		if entity.has("sprite") and entity["sprite"] != null and is_instance_valid(entity["sprite"]):
			entity["sprite"].queue_free()
	owner.active_entities.clear()
	VehicleTrafficController.clear_speeder_lane_change_warning(owner)
	owner.spawn_timers = [0.4, 0.8, 1.2]
	owner.player_lane = 1
	owner.player_speed = owner.player_start_speed
	owner.distance = 0.0
	owner.time_left = owner.time_limit
	owner.overtime_seconds = 0.0
	owner.game_state = "playing"
	owner.end_message = ""
	owner.player_is_stage_clear_exiting = false
	owner.passenger_rule_violation_count = 0
	owner.stage_clear_transition_started = false
	owner.stage_clear_fade_time = 0.0
	owner.boost_active = false
	owner.boost_speed_x = 1.0
	owner.boost_gas_save_timer = 0.0
	if owner.passenger_dialogue_controller != null:
		owner.passenger_dialogue_controller.clear()
	VehicleTrafficController.reset_speeder_timer(owner)
	if owner.fade_rect:
		owner.fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
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
		owner.distance,
		owner.target_distance,
		owner.fare_php_per_meter,
		owner.overtime_seconds,
		owner.overtime_fare_penalty_php_per_second,
		owner.time_left,
		owner.time_bonus_php_per_second,
		owner.passenger_rule_violation_count
	)
