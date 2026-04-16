extends RefCounted

const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const GameLabelFactory := preload("res://scripts/game/game_label_factory.gd")
const VehicleBehaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleSpawner := preload("res://scripts/game/vehicle_spawner.gd")
const VehicleSpawnScheduler := preload("res://scripts/game/vehicle_spawn_scheduler.gd")

const SAME_DIRECTION_BEHIND_DESPAWN_X := -960.0
const INCOMING_BEHIND_DESPAWN_X := -260.0
const FRONT_DESPAWN_EXTRA_X := 520.0
const OVERTAKE_PASS_BUFFER_X := 12.0
const NPC_OVERLAP_SEPARATION_GAP := 8.0


static func update_speeder_warning(owner, delta: float) -> void:
	prune_invalid_entities(owner)
	if owner.speeder_warning_label:
		owner.speeder_warning_label.visible = owner.speeder_warning_flash_timer > 0.0
		owner.speeder_warning_flash_timer = maxf(0.0, owner.speeder_warning_flash_timer - delta)

	if not owner.speeder_enabled:
		return

	if owner.speeder_warning_active:
		owner.speeder_warning_timer -= delta
		if owner.speeder_warning_timer <= 0.0:
			if owner.speeder_warning_beeps_remaining > 0:
				pulse_speeder_warning(owner)
				owner.speeder_warning_beeps_remaining -= 1
				owner.speeder_warning_timer = 0.28
			else:
				owner.speeder_warning_active = false
				if owner.speeder_warning_label:
					owner.speeder_warning_label.visible = false
				VehicleSpawner.spawn_speeder(owner)
				reset_speeder_timer(owner)
		return

	owner.speeder_spawn_timer -= delta
	if owner.speeder_spawn_timer <= 0.0:
		owner.speeder_warning_active = true
		owner.speeder_warning_beeps_remaining = 3
		owner.speeder_warning_timer = 0.0


static func update_speeder_lane_change_warning(owner, delta: float) -> void:
	if owner.speeder_lane_change_warning_label:
		owner.speeder_lane_change_warning_label.visible = false

	if not owner.speeder_lane_change_warning_active:
		return

	if not is_instance_valid(owner.pending_speeder_lane_change_sprite):
		clear_speeder_lane_change_warning(owner)
		return

	var lane_to_warn: int = owner.speeder_lane_change_warning_target_lane if owner.speeder_lane_change_warning_target_lane >= 0 else owner.player_lane
	if owner.speeder_lane_change_warning_label:
		owner.speeder_lane_change_warning_label.position = Vector2(
			owner.player_x + 105.0,
			VehicleGeometry.lane_y(owner, lane_to_warn, owner.get_viewport_rect().size) - 92.0
		)
		owner.speeder_lane_change_warning_label.visible = owner.speeder_lane_change_warning_beeps_remaining >= 0

	owner.speeder_lane_change_warning_timer -= delta
	if owner.speeder_lane_change_warning_timer > 0.0:
		return

	if owner.speeder_lane_change_warning_beeps_remaining > 0:
		pulse_speeder_lane_change_warning(owner)
		owner.speeder_lane_change_warning_beeps_remaining -= 1
		owner.speeder_lane_change_warning_timer = 0.28
	else:
		complete_speeder_lane_change_warning(owner)


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


static func complete_speeder_lane_change_warning(owner) -> void:
	var entity := find_entity_by_sprite(owner, owner.pending_speeder_lane_change_sprite)
	if not entity.is_empty():
		var target_lane: int = owner.speeder_lane_change_warning_target_lane
		if speeder_target_lane_is_safe(owner, entity, target_lane):
			var previous_lane := int(entity.get("lane", target_lane))
			entity["lane"] = target_lane
			entity["target_lane"] = target_lane
			entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, target_lane, 2)
			mark_recent_lane_change(owner, entity, previous_lane)

	clear_speeder_lane_change_warning(owner)


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


static func update_random_lane_changes(owner, delta: float) -> void:
	var post_day_seven_traffic_ramp: bool = VehicleSpawnScheduler.is_post_day_seven_traffic_ramp(owner)
	if not owner.npc_random_lane_change_enabled and not post_day_seven_traffic_ramp:
		return

	for entity in owner.active_entities:
		if bool(entity.get("lane_change_warning_active", false)):
			continue
		if entity.get("kind", "traffic") != "traffic":
			continue
		if float(entity.get("world_speed", 0.0)) <= 0.0:
			continue

		var lane_index := int(entity["lane"])
		if lane_index < 0 or lane_index > 2:
			continue

		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		if float(entity["lane_change_cooldown"]) > 0.0:
			continue

		var is_busy_car := bool(entity.get("is_busy_car", false))
		if not owner.npc_random_lane_change_enabled and not is_busy_car:
			continue

		var lane_change_chance: float = owner.npc_lane_change_chance_per_second if owner.npc_random_lane_change_enabled else 0.0
		if is_busy_car:
			lane_change_chance = maxf(lane_change_chance, owner.POST_DAY_SEVEN_BUSY_CAR_LANE_CHANGE_CHANCE_PER_SECOND)
		if lane_index == 2:
			lane_change_chance *= owner.bottom_lane_lane_change_chance_x

		if owner.rng.randf() > lane_change_chance * delta:
			continue

		var target_lane := random_lane_change_target(entity, lane_index)
		if target_lane < 0:
			continue
		if target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
			start_lane_change_warning(owner, entity, target_lane)

		entity["lane_change_cooldown"] = owner.rng.randf_range(1.2, 3.5)


static func random_lane_change_target(entity: Dictionary, lane_index: int) -> int:
	match lane_index:
		0:
			return -1
		1:
			return 2
		2:
			return 1
	return -1


static func update_vehicle_speeds(owner, delta: float) -> void:
	VehicleBehaviors.update_speed_targets(
		owner.active_entities,
		delta,
		owner.rng,
		owner.vehicle_speed_change_min_delay,
		owner.vehicle_speed_change_max_delay,
		owner.vehicle_speed_acceleration
	)
	apply_bottom_lane_speed_cap(owner)


static func update_overtake_speed_boosts(owner, delta: float) -> void:
	VehicleBehaviors.update_overtake_speed_boosts(owner.active_entities, delta)
	for entity in owner.active_entities:
		var kind := str(entity.get("kind", "traffic"))
		if kind != "traffic" and kind != "speeder":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if _is_overtaking_or_lane_changing(entity):
			update_overtake_completion(owner, entity)
			if kind == "traffic":
				apply_forward_collision_detection(owner, entity)
	update_top_lane_overtake_returns(owner)
	apply_bottom_lane_speed_cap(owner)


static func update_lane_change_warnings(owner, delta: float) -> void:
	for entity in owner.active_entities:
		if not bool(entity.get("lane_change_warning_active", false)):
			continue

		entity["lane_change_warning_timer"] = float(entity.get("lane_change_warning_timer", 0.0)) - delta
		if float(entity["lane_change_warning_timer"]) > 0.0:
			continue

		var pulses_remaining := int(entity.get("lane_change_warning_pulses_remaining", 0))
		if pulses_remaining > 0:
			pulse_entity_lane_warning(owner, entity)
			entity["lane_change_warning_pulses_remaining"] = pulses_remaining - 1
			entity["lane_change_warning_timer"] = owner.NPC_LANE_CHANGE_WARNING_INTERVAL
		else:
			finish_warned_lane_change(owner, entity)


static func start_lane_change_warning(owner, entity: Dictionary, target_lane: int) -> void:
	entity["lane_change_warning_active"] = true
	entity["lane_change_warning_target_lane"] = target_lane
	entity["lane_change_previous_lane"] = int(entity.get("lane", target_lane))
	entity["lane_change_warning_pulses_remaining"] = owner.NPC_LANE_CHANGE_WARNING_PULSES
	entity["lane_change_warning_timer"] = 0.0
	var warning_label := get_entity_lane_warning_label(owner, entity)
	warning_label.visible = false


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


static func finish_warned_lane_change(owner, entity: Dictionary) -> void:
	var target_lane := int(entity.get("lane_change_warning_target_lane", entity["lane"]))
	var warning_label := get_entity_lane_warning_label(owner, entity)
	warning_label.visible = false
	entity["lane_change_warning_active"] = false

	if lane_change_allowed(entity, target_lane) and target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
		var previous_lane := int(entity.get("lane_change_previous_lane", entity["lane"]))
		entity["lane"] = target_lane
		entity["target_lane"] = target_lane
		entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, target_lane)
		mark_recent_lane_change(owner, entity, previous_lane)
		if bool(entity.get("returning_from_top_lane_overtake", false)):
			clear_top_lane_overtake_return(entity)
		if bool(entity.get("pending_overtake_speed_boost", false)):
			boost_vehicle_for_overtake(owner, entity)
	else:
		if target_lane == 0:
			clear_top_lane_overtake_return(entity)
		entity.erase("lane_change_previous_lane")
		entity.erase("returning_from_top_lane_overtake")

	entity["pending_overtake_speed_boost"] = false
	entity["lane_change_cooldown"] = owner.rng.randf_range(1.2, 3.5)


static func get_entity_lane_warning_label(owner, entity: Dictionary) -> Label:
	var sprite: Sprite2D = entity["sprite"]
	var warning_label := sprite.get_node_or_null("LaneChangeWarning") as Label
	if warning_label:
		return warning_label

	warning_label = GameLabelFactory.make_label(42, Color(1.0, 0.94, 0.2, 1.0), 6)
	warning_label.name = "LaneChangeWarning"
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


static func update_speeder_ai(owner) -> void:
	for entity in owner.active_entities:
		if entity.get("kind", "traffic") != "speeder":
			continue

		var lane_index := int(entity["lane"])
		if speeder_needs_lane_change(owner, entity, lane_index):
			var changed_lane := false
			for avoid_target_lane in VehicleBehaviors.speeder_overtake_lane_order(lane_index):
				if try_set_speeder_target_lane(owner, entity, avoid_target_lane):
					set_overtake_target(owner, entity, lane_index)
					changed_lane = true
					break
			if not changed_lane:
				slow_speeder_near_player(owner, entity)
			continue

		if lane_index != 1:
			try_set_speeder_target_lane(owner, entity, 1)


static func update_busy_vehicle_ai(owner, delta: float) -> void:
	if owner.stage_traffic != "busy":
		return

	for entity in owner.active_entities:
		if entity.get("kind", "traffic") != "traffic":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			apply_forward_collision_detection(owner, entity)
			continue

		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		var lane_index := int(entity["lane"])

		if not vehicle_needs_lane_change(owner, entity, lane_index):
			continue

		var changed_lane := false
		for target_lane in BusyTrafficBehavior.overtake_lane_order(lane_index):
			if try_warn_vehicle_lane_change(owner, entity, target_lane):
				set_overtake_target(owner, entity, lane_index)
				entity["pending_overtake_speed_boost"] = true
				changed_lane = true
				break
		if not changed_lane:
			slow_vehicle_for_front_car(owner, entity, lane_index)


static func update_vehicle_overtake_ai(owner, delta: float) -> void:
	for entity in owner.active_entities:
		if entity.get("kind", "traffic") != "traffic":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			apply_forward_collision_detection(owner, entity)
			continue
		if float(entity.get("world_speed", 0.0)) <= 0.0:
			continue

		var lane_index := int(entity["lane"])
		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		if float(entity["lane_change_cooldown"]) > 0.0:
			continue

		if lane_index == 0:
			continue
		if lane_index != 1 and lane_index != 2:
			continue
		if not vehicle_needs_lane_change(owner, entity, lane_index):
			continue

		if lane_index == 1 and try_warn_overtake_lane_change(owner, entity, 0):
			continue

		var overtake_chance: float = owner.npc_overtake_chance_per_second
		if lane_index == 2:
			overtake_chance *= owner.bottom_lane_lane_change_chance_x

		if owner.rng.randf() > overtake_chance * delta:
			continue

		for target_lane in VehicleBehaviors.overtake_lane_order(lane_index):
			if target_lane == 0:
				continue
			if try_warn_overtake_lane_change(owner, entity, target_lane):
				break


static func vehicle_needs_lane_change(owner, vehicle: Dictionary, lane_index: int) -> bool:
	return VehicleBehaviors.vehicle_needs_lane_change(
		vehicle,
		lane_index,
		active_collision_entities(owner, vehicle),
		owner.npc_collision_lookahead,
		owner.npc_follow_gap,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)


static func try_warn_overtake_lane_change(owner, entity: Dictionary, target_lane: int) -> bool:
	if not lane_change_allowed(entity, target_lane):
		return false
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
		return false

	entity["pending_overtake_speed_boost"] = true
	set_overtake_target(owner, entity, int(entity.get("lane", target_lane)))
	set_top_lane_overtake_return(entity, target_lane)
	start_lane_change_warning(owner, entity, target_lane)
	return true


static func try_warn_vehicle_lane_change(owner, entity: Dictionary, target_lane: int) -> bool:
	if not lane_change_allowed(entity, target_lane):
		return false
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not target_lane_is_safe_for_entity(owner, entity, target_lane, owner.speeder_safe_gap):
		return false

	set_top_lane_overtake_return(entity, target_lane)
	start_lane_change_warning(owner, entity, target_lane)
	return true


static func boost_vehicle_for_overtake(owner, entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) == 0 and entity.has("overtake_return_lane"):
		boost_vehicle_for_top_lane_overtake(owner, entity)
		return

	VehicleBehaviors.boost_for_overtake(entity, owner.npc_overtake_speed_boost, owner.npc_overtake_speed_boost_seconds)


static func boost_vehicle_for_top_lane_overtake(owner, entity: Dictionary) -> void:
	var current_speed := float(entity.get("world_speed", 0.0))
	var max_speed := float(entity.get("max_world_speed", current_speed))
	var boosted_speed: float = maxf(
		maxf(current_speed, max_speed) + owner.top_lane_overtake_speed_boost,
		owner.player_speed + owner.top_lane_overtake_speed_boost
	)
	entity["overtake_target_speed"] = boosted_speed
	entity["overtake_speed_timer"] = owner.top_lane_overtake_speed_boost_seconds
	entity["desired_world_speed"] = boosted_speed
	entity["world_speed"] = maxf(current_speed, boosted_speed)


static func set_overtake_target(owner, entity: Dictionary, lane_index: int) -> void:
	var target: Dictionary = find_front_collision_entity(owner, entity, lane_index)
	if target.is_empty():
		entity.erase("overtake_target_sprite")
		return
	entity["overtake_target_sprite"] = target["sprite"]


static func set_top_lane_overtake_return(entity: Dictionary, target_lane: int) -> void:
	if target_lane != 0:
		return

	var current_lane := int(entity.get("lane", -1))
	if current_lane != 1:
		return
	if not entity_moves_with_player(entity, current_lane):
		return

	entity["overtake_return_lane"] = current_lane
	entity["top_lane_overtake_return_ready"] = false


static func find_front_collision_entity(owner, entity: Dictionary, lane_index: int) -> Dictionary:
	var vehicle_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var vehicle_speed := float(entity.get("world_speed", 0.0))
	var vehicle_moves_with_player := entity_moves_with_player(entity, lane_index)
	var nearest_gap := INF
	var nearest_entity: Dictionary = {}
	for other_entity in owner.active_entities:
		if not is_entity_sprite_valid(other_entity):
			continue
		if entity_collision_disabled(other_entity):
			continue
		if same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != lane_index:
			continue

		var other_rect: Rect2 = VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if not VehicleBehaviors.rect_is_ahead(vehicle_rect, other_rect, vehicle_moves_with_player):
			continue

		var other_speed := float(other_entity.get("world_speed", 0.0))
		var gap := VehicleBehaviors.front_gap(vehicle_rect, other_rect, vehicle_moves_with_player)
		var closing_speed := VehicleBehaviors.closing_speed_between(entity, other_entity, lane_index, vehicle_speed, other_speed)
		var predicted_close_distance: float = closing_speed * owner.npc_collision_lookahead
		if gap < nearest_gap and (gap <= owner.npc_follow_gap or gap <= predicted_close_distance):
			nearest_gap = gap
			nearest_entity = other_entity
	return nearest_entity


static func update_overtake_completion(owner, entity: Dictionary) -> void:
	if not entity.has("overtake_target_sprite"):
		return
	if not is_entity_sprite_valid(entity):
		clear_overtake_state(entity)
		return

	var target_sprite = entity.get("overtake_target_sprite")
	if target_sprite == null or not is_instance_valid(target_sprite):
		finish_top_lane_overtake_or_clear(entity)
		return
	if not target_sprite is Sprite2D:
		finish_top_lane_overtake_or_clear(entity)
		return

	var target_sprite_node: Sprite2D = target_sprite
	var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var target_rect: Rect2 = VehicleGeometry.collision_rect(target_sprite_node, owner.VEHICLE_HITBOX_INSET, owner)
	var entity_rear_x := entity_rect.position.x
	var target_front_x := target_rect.position.x + target_rect.size.x
	if entity_rear_x > target_front_x + OVERTAKE_PASS_BUFFER_X:
		finish_top_lane_overtake_or_clear(entity)


static func finish_top_lane_overtake_or_clear(entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) == 0 and entity.has("overtake_return_lane"):
		entity["pending_overtake_speed_boost"] = false
		entity.erase("overtake_target_sprite")
		entity["top_lane_overtake_return_ready"] = true
	else:
		clear_overtake_state(entity)


static func clear_overtake_state(entity: Dictionary) -> void:
	entity["pending_overtake_speed_boost"] = false
	entity["overtake_speed_timer"] = 0.0
	entity.erase("overtake_target_speed")
	entity.erase("overtake_target_sprite")
	clear_top_lane_overtake_return(entity)


static func update_top_lane_overtake_returns(owner) -> void:
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue
		if entity.get("kind", "traffic") != "traffic":
			continue
		if int(entity.get("lane", -1)) != 0:
			continue
		if not bool(entity.get("top_lane_overtake_return_ready", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			maintain_top_lane_overtake_boost(owner, entity)
			continue

		var return_lane := int(entity.get("overtake_return_lane", 1))
		if return_lane < 1 or return_lane > 2:
			clear_top_lane_overtake_return(entity)
			continue
		if not lane_change_allowed(entity, return_lane):
			maintain_top_lane_overtake_boost(owner, entity)
			continue
		if not target_lane_is_safe_for_entity(owner, entity, return_lane, owner.speeder_safe_gap):
			maintain_top_lane_overtake_boost(owner, entity)
			continue

		entity["returning_from_top_lane_overtake"] = true
		maintain_top_lane_overtake_boost(owner, entity)
		start_lane_change_warning(owner, entity, return_lane)


static func maintain_top_lane_overtake_boost(owner, entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) != 0:
		return
	if not entity.has("overtake_return_lane"):
		return

	var target_speed: float = maxf(
		float(entity.get("overtake_target_speed", 0.0)),
		owner.player_speed + owner.top_lane_overtake_speed_boost
	)
	entity["overtake_target_speed"] = target_speed
	entity["overtake_speed_timer"] = maxf(
		float(entity.get("overtake_speed_timer", 0.0)),
		owner.top_lane_overtake_speed_boost_seconds * 0.5
	)
	entity["desired_world_speed"] = maxf(float(entity.get("desired_world_speed", 0.0)), target_speed)
	entity["world_speed"] = maxf(float(entity.get("world_speed", 0.0)), target_speed)


static func clear_top_lane_overtake_return(entity: Dictionary) -> void:
	entity.erase("overtake_return_lane")
	entity.erase("top_lane_overtake_return_ready")
	entity.erase("returning_from_top_lane_overtake")
	entity.erase("top_lane_evasive_offset_active")


static func update_top_lane_evasive_offsets(owner) -> void:
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue
		if not top_lane_evasion_candidate(entity):
			entity.erase("top_lane_evasive_offset_active")
			continue

		if top_lane_incoming_collision_is_inevitable(owner, entity):
			entity["top_lane_evasive_offset_active"] = true
		else:
			entity.erase("top_lane_evasive_offset_active")


static func top_lane_evasion_candidate(entity: Dictionary) -> bool:
	var kind := str(entity.get("kind", "traffic"))
	return (
		(kind == "traffic" or kind == "speeder")
		and int(entity.get("lane", -1)) == 0
		and entity_moves_with_player(entity, 0)
		and (entity.has("overtake_return_lane") or kind == "speeder")
	)


static func top_lane_incoming_collision_is_inevitable(owner, entity: Dictionary) -> bool:
	var lookahead: float = maxf(owner.npc_collision_lookahead, owner.player_lane_change_prediction_seconds) + 0.45
	var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var entity_future_rect: Rect2 = entity_rect
	entity_future_rect.position.x += predicted_screen_velocity(owner, entity, 0) * lookahead
	var entity_swept_rect: Rect2 = padded_rect(
		entity_rect.merge(entity_future_rect),
		owner.npc_lane_change_planning_padding_x,
		owner.npc_lane_change_planning_padding_y
	)

	for other_entity in owner.active_entities:
		if not is_entity_sprite_valid(other_entity):
			continue
		if same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != 0:
			continue
		if entity_moves_with_player(other_entity, 0):
			continue

		var other_rect: Rect2 = VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var other_future_rect: Rect2 = other_rect
		other_future_rect.position.x += predicted_screen_velocity(owner, other_entity, 0) * lookahead
		var other_swept_rect: Rect2 = padded_rect(
			other_rect.merge(other_future_rect),
			owner.npc_lane_change_planning_padding_x,
			owner.npc_lane_change_planning_padding_y
		)
		if entity_swept_rect.intersects(other_swept_rect):
			return true
	return false


static func mark_recent_lane_change(owner, entity: Dictionary, previous_lane: int) -> void:
	entity["lane_change_previous_lane"] = previous_lane
	entity["lane_change_fault_grace_timer"] = owner.npc_lane_change_fault_grace_seconds


static func update_lane_change_fault_grace(entity: Dictionary, delta: float) -> void:
	if not entity.has("lane_change_fault_grace_timer"):
		return

	var grace_timer := maxf(0.0, float(entity.get("lane_change_fault_grace_timer", 0.0)) - delta)
	entity["lane_change_fault_grace_timer"] = grace_timer
	if grace_timer <= 0.0:
		entity.erase("lane_change_fault_grace_timer")
		entity.erase("lane_change_previous_lane")


static func _is_overtaking_or_lane_changing(entity: Dictionary) -> bool:
	return (
		bool(entity.get("lane_change_warning_active", false))
		or bool(entity.get("pending_overtake_speed_boost", false))
		or float(entity.get("overtake_speed_timer", 0.0)) > 0.0
	)


static func is_overtake_speed_exempt(entity: Dictionary) -> bool:
	return (
		entity.get("kind", "traffic") == "speeder"
		or bool(entity.get("pending_overtake_speed_boost", false))
		or float(entity.get("overtake_speed_timer", 0.0)) > 0.0
		or entity.has("overtake_target_sprite")
	)


static func apply_bottom_lane_speed_cap(owner) -> void:
	var cap := float(owner.bottom_lane_vehicle_max_speed)
	if cap <= 0.0:
		return

	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue
		if int(entity.get("lane", -1)) != 2:
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if is_overtake_speed_exempt(entity):
			continue

		entity["desired_world_speed"] = minf(float(entity.get("desired_world_speed", cap)), cap)
		entity["world_speed"] = minf(float(entity.get("world_speed", cap)), cap)


static func apply_forward_collision_detection(owner, entity: Dictionary) -> void:
	if float(entity.get("world_speed", 0.0)) <= 0.0:
		return
	slow_vehicle_for_front_car(owner, entity, int(entity.get("lane", -1)))


static func slow_vehicle_for_front_car(owner, entity: Dictionary, lane_index: int) -> void:
	var front_speed := VehicleBehaviors.front_vehicle_collision_speed(
		entity,
		lane_index,
		active_collision_entities(owner, entity),
		owner.npc_follow_gap,
		owner.npc_collision_lookahead,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)
	if front_speed >= 0.0:
		entity["world_speed"] = minf(float(entity.get("world_speed", front_speed)), front_speed)


static func speeder_needs_lane_change(owner, speeder: Dictionary, lane_index: int) -> bool:
	return VehicleBehaviors.speeder_needs_lane_change(
		speeder,
		lane_index,
		active_collision_entities(owner, speeder),
		owner.speeder_vehicle_max_speed,
		owner.speeder_safe_gap,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)


static func lane_is_safe_for_entity(owner, moving_entity: Dictionary, target_lane: int, safe_gap: float) -> bool:
	return (
		VehicleBehaviors.is_lane_safe(
			moving_entity,
			target_lane,
			safe_gap,
			active_collision_entities(owner, moving_entity),
			owner.VEHICLE_HITBOX_INSET,
			Callable(VehicleGeometry, "collision_rect").bind(owner)
		)
		and target_lane_hitboxes_clear(owner, moving_entity, target_lane)
	)


static func target_lane_is_safe_for_entity(owner, moving_entity: Dictionary, target_lane: int, safe_gap: float) -> bool:
	return (
		lane_is_safe_for_entity(owner, moving_entity, target_lane, safe_gap)
		and target_lane_hitboxes_clear(owner, moving_entity, target_lane)
		and top_lane_overtake_is_safe(owner, moving_entity, target_lane)
		and player_lane_is_safe_for_entity(owner, moving_entity, target_lane)
	)


static func target_lane_hitboxes_clear(owner, entity: Dictionary, target_lane: int) -> bool:
	var moving_rect := padded_rect(
		projected_entity_collision_rect(owner, entity, target_lane),
		owner.npc_lane_change_planning_padding_x,
		owner.npc_lane_change_planning_padding_y
	)
	for other_entity in owner.active_entities:
		if not is_entity_sprite_valid(other_entity):
			continue
		if entity_collision_disabled(other_entity):
			continue
		if same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != target_lane:
			continue

		var other_rect: Rect2 = padded_rect(
			VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner),
			owner.npc_lane_change_planning_padding_x,
			owner.npc_lane_change_planning_padding_y
		)
		if moving_rect.intersects(other_rect):
			return false
	return true


static func top_lane_overtake_is_safe(owner, entity: Dictionary, target_lane: int) -> bool:
	if target_lane != 0:
		return true
	if not is_entity_sprite_valid(entity):
		return false
	if not entity_moves_with_player(entity, int(entity.get("lane", target_lane))):
		return false

	var lookahead: float = maxf(owner.npc_collision_lookahead, owner.player_lane_change_prediction_seconds) + 0.75
	var entity_rect := projected_entity_collision_rect(owner, entity, target_lane)
	var entity_future_rect := entity_rect
	entity_future_rect.position.x += predicted_screen_velocity(owner, entity, target_lane) * lookahead
	var entity_swept_rect := padded_rect(
		entity_rect.merge(entity_future_rect),
		owner.npc_lane_change_planning_padding_x,
		owner.npc_lane_change_planning_padding_y
	)

	for other_entity in owner.active_entities:
		if not is_entity_sprite_valid(other_entity):
			continue
		if same_entity_sprite(other_entity, entity):
			continue
		if int(other_entity.get("lane", -1)) != 0:
			continue
		if entity_moves_with_player(other_entity, 0):
			continue

		var other_rect: Rect2 = VehicleGeometry.collision_rect(other_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var other_future_rect := other_rect
		other_future_rect.position.x += predicted_screen_velocity(owner, other_entity, 0) * lookahead
		var other_swept_rect := padded_rect(
			other_rect.merge(other_future_rect),
			owner.npc_lane_change_planning_padding_x,
			owner.npc_lane_change_planning_padding_y
		)
		if entity_swept_rect.intersects(other_swept_rect):
			return false
	return true


static func player_lane_is_safe_for_entity(owner, entity: Dictionary, target_lane: int) -> bool:
	if owner.player == null or not is_instance_valid(owner.player):
		return true
	if not is_entity_sprite_valid(entity):
		return false

	var entity_swept_rect := predicted_entity_swept_rect(owner, entity, target_lane)
	var player_safety_rect := player_lane_change_safety_rect(owner)
	if target_lane == owner.player_lane:
		return not entity_swept_rect.intersects(player_safety_rect)

	if absi(target_lane - owner.player_lane) == 1:
		return not rect_x_ranges_overlap(entity_swept_rect, player_safety_rect)

	return true


static func predicted_entity_swept_rect(owner, entity: Dictionary, target_lane: int) -> Rect2:
	var current_rect := projected_entity_collision_rect(owner, entity, target_lane)
	var future_rect := current_rect
	future_rect.position.x += predicted_screen_velocity(owner, entity, target_lane) * owner.player_lane_change_prediction_seconds
	return current_rect.merge(future_rect)


static func predicted_screen_velocity(owner, entity: Dictionary, target_lane: int) -> float:
	var movement_side := BusyTrafficBehavior.LEFT_SPAWN_SIDE if entity_moves_with_player(entity, target_lane) else BusyTrafficBehavior.RIGHT_SPAWN_SIDE
	return VehicleBehaviors.screen_velocity_for_spawn_side(
		target_lane,
		str(entity.get("kind", "traffic")),
		movement_side,
		float(entity.get("world_speed", 0.0)),
		owner.player_speed
	)


static func player_lane_change_safety_rect(owner) -> Rect2:
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	return Rect2(
		player_rect.position - Vector2(owner.player_lane_change_back_padding, owner.player_lane_change_side_padding),
		player_rect.size + Vector2(
			owner.player_lane_change_back_padding + owner.player_lane_change_front_padding,
			owner.player_lane_change_side_padding * 2.0
		)
	)


static func padded_rect(rect: Rect2, padding_x: float, padding_y: float) -> Rect2:
	return Rect2(
		rect.position - Vector2(padding_x, padding_y),
		rect.size + Vector2(padding_x * 2.0, padding_y * 2.0)
	)


static func rect_x_ranges_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x <= b.position.x + b.size.x and b.position.x <= a.position.x + a.size.x


static func try_set_speeder_target_lane(owner, entity: Dictionary, target_lane: int) -> bool:
	if not lane_change_allowed(entity, target_lane):
		return false
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not speeder_target_lane_is_safe(owner, entity, target_lane):
		return false

	if target_lane == owner.player_lane:
		start_speeder_lane_change_warning(owner, entity["sprite"], target_lane)
		return true

	if speeder_lane_change_warning_belongs_to_other(owner, entity):
		return false

	var previous_lane := int(entity.get("lane", target_lane))
	entity["lane"] = target_lane
	entity["target_lane"] = target_lane
	entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, target_lane, 2)
	mark_recent_lane_change(owner, entity, previous_lane)
	return true


static func speeder_lane_change_safe_gap(owner, target_lane: int) -> float:
	return VehicleBehaviors.speeder_lane_change_safe_gap(target_lane, owner.speeder_safe_gap, owner.speeder_avoid_lookahead)


static func speeder_target_lane_is_safe(owner, entity: Dictionary, target_lane: int) -> bool:
	return (
		speeder_lane_is_safe_for_entity(owner, entity, target_lane)
		and speeder_has_player_lane_change_clearance(owner, entity, target_lane)
	)


static func speeder_lane_is_safe_for_entity(owner, entity: Dictionary, target_lane: int) -> bool:
	if not lane_is_safe_for_entity(owner, entity, target_lane, speeder_lane_change_safe_gap(owner, target_lane)):
		return false
	if not target_lane_hitboxes_clear(owner, entity, target_lane):
		return false
	if not top_lane_overtake_is_safe(owner, entity, target_lane):
		return false

	var current_lane := int(entity.get("lane", target_lane))
	if target_lane == owner.player_lane:
		return player_lane_is_safe_for_entity(owner, entity, target_lane)
	if current_lane == owner.player_lane:
		return true
	return player_lane_is_safe_for_entity(owner, entity, target_lane)


static func speeder_lane_change_warning_belongs_to_other(owner, entity: Dictionary) -> bool:
	if not owner.speeder_lane_change_warning_active:
		return false
	if not is_instance_valid(owner.pending_speeder_lane_change_sprite):
		clear_speeder_lane_change_warning(owner)
		return false
	if not is_entity_sprite_valid(entity):
		return false
	return owner.pending_speeder_lane_change_sprite != entity["sprite"]


static func lane_change_allowed(entity: Dictionary, target_lane: int) -> bool:
	var current_lane := int(entity.get("lane", target_lane))
	if entity.get("kind", "traffic") == "speeder":
		return current_lane >= 0 and current_lane <= 2 and target_lane >= 0 and target_lane <= 2
	if current_lane == 0:
		return (
			entity_moves_with_player(entity, current_lane)
			and target_lane == int(entity.get("overtake_return_lane", -1))
		)
	if target_lane == 0:
		return current_lane == 1 and entity_moves_with_player(entity, current_lane)
	return current_lane >= 1 and current_lane <= 2 and target_lane >= 1 and target_lane <= 2


static func projected_entity_collision_rect(owner, entity: Dictionary, lane_index: int) -> Rect2:
	var sprite: Sprite2D = entity["sprite"]
	var original_position := sprite.position
	var original_scale := sprite.scale
	sprite.scale = target_scale_for_entity(owner, entity, lane_index)
	sprite.position.y = VehicleGeometry.sprite_y_for_hitbox_bottom(
		sprite,
		VehicleGeometry.entity_lane_y(owner, lane_index, owner.get_viewport_rect().size, bool(entity.get("is_parked", false))),
		owner.VEHICLE_HITBOX_INSET,
		owner
	)
	var projected_rect: Rect2 = VehicleGeometry.collision_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner)
	sprite.position = original_position
	sprite.scale = original_scale
	return projected_rect


static func speeder_has_player_lane_change_clearance(owner, entity: Dictionary, target_lane: int) -> bool:
	if owner.player == null or not is_instance_valid(owner.player):
		return true

	if target_lane != owner.player_lane:
		return true

	var speeder_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var center_gap := absf(speeder_rect.get_center().x - player_rect.get_center().x)
	return center_gap >= owner.SPEEDER_PLAYER_LANE_CHANGE_BUFFER


static func slow_speeder_near_player(owner, entity: Dictionary) -> void:
	if owner.player == null or not is_instance_valid(owner.player):
		return
	if int(entity.get("lane", -1)) != owner.player_lane:
		return

	var speeder_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var speeder_is_behind_player := speeder_rect.get_center().x < player_rect.get_center().x
	var center_gap := absf(speeder_rect.get_center().x - player_rect.get_center().x)
	if speeder_is_behind_player and center_gap < owner.SPEEDER_PLAYER_LANE_CHANGE_BUFFER:
		entity["world_speed"] = minf(float(entity.get("world_speed", owner.speeder_vehicle_max_speed)), owner.player_speed)


static func find_entity_by_sprite(owner, sprite) -> Dictionary:
	if sprite == null or not is_instance_valid(sprite):
		return {}

	for entity in owner.active_entities:
		if is_entity_sprite_valid(entity) and entity.get("sprite") == sprite:
			return entity
	return {}


static func is_entity_sprite_valid(entity: Dictionary) -> bool:
	return entity.has("sprite") and entity["sprite"] != null and is_instance_valid(entity["sprite"])


static func same_entity_sprite(a: Dictionary, b: Dictionary) -> bool:
	if not is_entity_sprite_valid(a) or not is_entity_sprite_valid(b):
		return false
	return a.get("sprite") == b.get("sprite")


static func entity_collision_disabled(entity: Dictionary) -> bool:
	return bool(entity.get("top_lane_evasive_offset_active", false))


static func active_collision_entities(owner, include_entity: Dictionary = {}) -> Array:
	var entities: Array = []
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue
		if not include_entity.is_empty() and same_entity_sprite(entity, include_entity):
			entities.append(entity)
			continue
		if entity_collision_disabled(entity):
			continue
		entities.append(entity)
	return entities


static func lane_change_fault_is_active(entity: Dictionary) -> bool:
	return (
		bool(entity.get("lane_change_warning_active", false))
		or float(entity.get("lane_change_fault_grace_timer", 0.0)) > 0.0
	)


static func deflect_lane_change_fault(owner, entity: Dictionary) -> void:
	cancel_entity_lane_change_warning(entity)
	clear_overtake_state(entity)

	var previous_lane := int(entity.get("lane_change_previous_lane", -1))
	if previous_lane >= 0 and previous_lane <= 2 and previous_lane != owner.player_lane:
		entity["lane"] = previous_lane
		entity["target_lane"] = previous_lane
		entity["sprite"].z_index = VehicleGeometry.z_for_lane(owner, previous_lane)
	else:
		entity["world_speed"] = minf(float(entity.get("world_speed", owner.player_speed)), maxf(0.0, owner.player_speed - 60.0))
		entity["desired_world_speed"] = minf(float(entity.get("desired_world_speed", owner.player_speed)), float(entity["world_speed"]))

	entity["lane_change_cooldown"] = maxf(float(entity.get("lane_change_cooldown", 0.0)), 3.0)
	entity["lane_change_fault_grace_timer"] = maxf(float(entity.get("lane_change_fault_grace_timer", 0.0)), 0.25)


static func cancel_entity_lane_change_warning(entity: Dictionary) -> void:
	entity["lane_change_warning_active"] = false
	entity["lane_change_warning_pulses_remaining"] = 0
	entity["lane_change_warning_timer"] = 0.0
	entity["pending_overtake_speed_boost"] = false

	if not is_entity_sprite_valid(entity):
		return

	var warning_label := entity["sprite"].get_node_or_null("LaneChangeWarning") as Label
	if warning_label:
		warning_label.visible = false


static func relieve_player_pin_pressure(owner) -> void:
	if not player_is_pinned(owner):
		return

	var protected_lanes := player_protected_lanes(owner)
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue

		if bool(entity.get("lane_change_warning_active", false)):
			var target_lane := int(entity.get("lane_change_warning_target_lane", entity.get("lane", -1)))
			if protected_lanes.has(target_lane):
				cancel_entity_lane_change_warning(entity)
				entity["lane_change_cooldown"] = maxf(float(entity.get("lane_change_cooldown", 0.0)), 2.5)

		slow_rear_pressure_vehicle(owner, entity)


static func player_is_pinned(owner) -> bool:
	if owner.player == null or not is_instance_valid(owner.player):
		return false

	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var front_gap := nearest_player_lane_gap(owner, player_rect, true)
	var rear_gap := nearest_player_lane_gap(owner, player_rect, false)
	var front_blocked: bool = front_gap <= owner.pin_pressure_front_gap
	var rear_blocked: bool = rear_gap <= owner.pin_pressure_rear_gap
	var escape_blocked: bool = player_escape_lanes_blocked(owner, player_rect)
	return front_blocked and (rear_blocked or escape_blocked)


static func nearest_player_lane_gap(owner, player_rect: Rect2, ahead: bool) -> float:
	var nearest_gap := INF
	var player_center_x := player_rect.get_center().x
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue
		if entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != owner.player_lane:
			continue

		var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var entity_center_x := entity_rect.get_center().x
		if ahead and entity_center_x <= player_center_x:
			continue
		if not ahead and entity_center_x >= player_center_x:
			continue

		var gap := entity_rect.position.x - (player_rect.position.x + player_rect.size.x) if ahead else player_rect.position.x - (entity_rect.position.x + entity_rect.size.x)
		nearest_gap = minf(nearest_gap, maxf(0.0, gap))
	return nearest_gap


static func player_escape_lanes_blocked(owner, player_rect: Rect2) -> bool:
	var checked_lanes := 0
	var blocked_lanes := 0
	for lane_index in [owner.player_lane - 1, owner.player_lane + 1]:
		if lane_index < 0 or lane_index > 2:
			continue
		checked_lanes += 1
		if not player_escape_lane_is_clear(owner, lane_index, player_rect):
			blocked_lanes += 1

	return checked_lanes > 0 and blocked_lanes >= checked_lanes


static func player_escape_lane_is_clear(owner, lane_index: int, player_rect: Rect2) -> bool:
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue
		if entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		if absf(entity_rect.get_center().x - player_rect.get_center().x) < owner.pin_pressure_escape_lane_gap:
			return false
	return true


static func player_protected_lanes(owner) -> Array:
	var protected_lanes: Array = [owner.player_lane]
	for lane_index in [owner.player_lane - 1, owner.player_lane + 1]:
		if lane_index >= 0 and lane_index <= 2:
			protected_lanes.append(lane_index)
	return protected_lanes


static func slow_rear_pressure_vehicle(owner, entity: Dictionary) -> void:
	if int(entity.get("lane", -1)) != owner.player_lane:
		return
	if entity_collision_disabled(entity):
		return

	var player_rect: Rect2 = VehicleGeometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var entity_rect: Rect2 = VehicleGeometry.collision_rect(entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
	if entity_rect.get_center().x >= player_rect.get_center().x:
		return

	var rear_gap := player_rect.position.x - (entity_rect.position.x + entity_rect.size.x)
	if rear_gap > owner.pin_pressure_rear_gap:
		return

	var pressure_speed := maxf(0.0, owner.player_speed - 60.0)
	entity["world_speed"] = minf(float(entity.get("world_speed", pressure_speed)), pressure_speed)
	entity["desired_world_speed"] = minf(float(entity.get("desired_world_speed", pressure_speed)), pressure_speed)


static func update_npc_following(owner) -> void:
	VehicleBehaviors.update_npc_following(
		active_collision_entities(owner),
		owner.npc_follow_gap,
		owner.npc_collision_lookahead,
		owner.VEHICLE_HITBOX_INSET,
		Callable(VehicleGeometry, "collision_rect").bind(owner)
	)


static func update_entities(owner, delta: float) -> void:
	prune_invalid_entities(owner)
	remove_invalid_top_lane_direction_entities(owner)
	relieve_player_pin_pressure(owner)
	update_top_lane_evasive_offsets(owner)
	for entity in owner.active_entities:
		update_lane_change_fault_grace(entity, delta)
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var world_speed: float = entity["world_speed"]
		var movement_side := BusyTrafficBehavior.LEFT_SPAWN_SIDE if entity_moves_with_player(entity, lane_index) else BusyTrafficBehavior.RIGHT_SPAWN_SIDE
		var screen_velocity := VehicleBehaviors.screen_velocity_for_spawn_side(
			lane_index,
			str(entity.get("kind", "traffic")),
			movement_side,
			world_speed,
			owner.player_speed
		)

		sprite.position.x += screen_velocity * delta
		update_entity_lane_position(owner, entity, delta)

	resolve_vehicle_overlaps(owner)

	var dead_entities := []
	for entity in owner.active_entities:
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var left_despawn_x := SAME_DIRECTION_BEHIND_DESPAWN_X if entity_moves_with_player(entity, lane_index) else INCOMING_BEHIND_DESPAWN_X
		if sprite.position.x < left_despawn_x or sprite.position.x > owner.get_viewport_rect().size.x + FRONT_DESPAWN_EXTRA_X:
			dead_entities.append(entity)

	for entity in dead_entities:
		remove_entity(owner, entity)


static func prune_invalid_entities(owner) -> void:
	if owner.speeder_lane_change_warning_active and not is_instance_valid(owner.pending_speeder_lane_change_sprite):
		clear_speeder_lane_change_warning(owner)

	var invalid_entities: Array = []
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			invalid_entities.append(entity)
			continue

		var target_sprite = entity.get("overtake_target_sprite")
		if target_sprite != null and not is_instance_valid(target_sprite):
			finish_top_lane_overtake_or_clear(entity)

	for entity in invalid_entities:
		remove_entity(owner, entity)


static func remove_invalid_top_lane_direction_entities(owner) -> void:
	var invalid_entities: Array = []
	for entity in owner.active_entities:
		if not is_entity_sprite_valid(entity):
			continue
		if entity.get("kind", "traffic") == "speeder":
			continue
		if int(entity.get("lane", -1)) != 0:
			continue
		if entity_moves_with_player(entity, 0):
			if not entity.has("overtake_return_lane"):
				invalid_entities.append(entity)

	for entity in invalid_entities:
		remove_entity(owner, entity)


static func remove_entity(owner, entity: Dictionary) -> void:
	var sprite = entity.get("sprite")
	var removed := false
	for index in range(owner.active_entities.size() - 1, -1, -1):
		var active_entity: Dictionary = owner.active_entities[index]
		if sprite != null and is_instance_valid(sprite):
			if is_entity_sprite_valid(active_entity) and active_entity.get("sprite") == sprite:
				owner.active_entities.remove_at(index)
				removed = true
				break
		elif not is_entity_sprite_valid(active_entity):
			owner.active_entities.remove_at(index)
			removed = true
			break

	if not removed:
		return

	clear_removed_sprite_references(owner, sprite)
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()


static func clear_removed_sprite_references(owner, sprite) -> void:
	if sprite == null:
		return
	if is_instance_valid(owner.pending_speeder_lane_change_sprite) and owner.pending_speeder_lane_change_sprite == sprite:
		clear_speeder_lane_change_warning(owner)

	for entity in owner.active_entities:
		var target_sprite = entity.get("overtake_target_sprite")
		if target_sprite == null:
			continue
		if not is_instance_valid(target_sprite):
			finish_top_lane_overtake_or_clear(entity)
			continue
		if target_sprite == sprite:
			finish_top_lane_overtake_or_clear(entity)


static func resolve_vehicle_overlaps(owner) -> void:
	for lane_index in range(3):
		resolve_direction_overlaps(owner, lane_index, true)
		resolve_direction_overlaps(owner, lane_index, false)
		resolve_opposing_direction_overlaps(owner, lane_index)


static func resolve_direction_overlaps(owner, lane_index: int, moves_with_player: bool) -> void:
	var lane_entities: Array = []
	for entity in owner.active_entities:
		var kind := str(entity.get("kind", "traffic"))
		if kind != "traffic" and kind != "speeder":
			continue
		if entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue
		if entity_moves_with_player(entity, lane_index) != moves_with_player:
			continue

		lane_entities.append(entity)

	if lane_entities.size() < 2:
		return

	if moves_with_player:
		lane_entities.sort_custom(_sort_entities_front_to_back)
	else:
		lane_entities.sort_custom(_sort_entities_left_front_to_back)

	for index in range(1, lane_entities.size()):
		var front_entity: Dictionary = lane_entities[index - 1]
		var rear_entity: Dictionary = lane_entities[index]
		var front_rect: Rect2 = VehicleGeometry.collision_rect(front_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
		var rear_rect: Rect2 = VehicleGeometry.collision_rect(rear_entity["sprite"], owner.VEHICLE_HITBOX_INSET, owner)

		if moves_with_player:
			var rear_right: float = rear_rect.position.x + rear_rect.size.x
			var desired_rear_right: float = front_rect.position.x - NPC_OVERLAP_SEPARATION_GAP
			if rear_right > desired_rear_right:
				rear_entity["sprite"].position.x += desired_rear_right - rear_right
				rear_entity["world_speed"] = minf(float(rear_entity.get("world_speed", 0.0)), float(front_entity.get("world_speed", 0.0)))
		else:
			var front_right: float = front_rect.position.x + front_rect.size.x
			var desired_rear_left: float = front_right + NPC_OVERLAP_SEPARATION_GAP
			if rear_rect.position.x < desired_rear_left:
				rear_entity["sprite"].position.x += desired_rear_left - rear_rect.position.x
				rear_entity["world_speed"] = minf(float(rear_entity.get("world_speed", 0.0)), float(front_entity.get("world_speed", 0.0)))


static func resolve_opposing_direction_overlaps(owner, lane_index: int) -> void:
	var right_movers: Array = []
	var left_movers: Array = []
	for entity in owner.active_entities:
		var kind := str(entity.get("kind", "traffic"))
		if kind != "traffic" and kind != "speeder":
			continue
		if entity_collision_disabled(entity):
			continue
		if int(entity.get("lane", -1)) != lane_index:
			continue

		if entity_moves_with_player(entity, lane_index):
			right_movers.append(entity)
		else:
			left_movers.append(entity)

	if right_movers.is_empty() or left_movers.is_empty():
		return

	for right_mover in right_movers:
		for left_mover in left_movers:
			var right_mover_rect: Rect2 = VehicleGeometry.collision_rect(right_mover["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
			var left_mover_rect: Rect2 = VehicleGeometry.collision_rect(left_mover["sprite"], owner.VEHICLE_HITBOX_INSET, owner)
			if not right_mover_rect.intersects(left_mover_rect):
				continue

			var left_entity: Dictionary = right_mover
			var left_rect: Rect2 = right_mover_rect
			var right_entity: Dictionary = left_mover
			var right_rect: Rect2 = left_mover_rect
			if left_mover_rect.get_center().x < right_mover_rect.get_center().x:
				left_entity = left_mover
				left_rect = left_mover_rect
				right_entity = right_mover
				right_rect = right_mover_rect

			var overlap_amount: float = (left_rect.position.x + left_rect.size.x) - right_rect.position.x + NPC_OVERLAP_SEPARATION_GAP
			if overlap_amount <= 0.0:
				continue

			var half_shift: float = overlap_amount * 0.5
			left_entity["sprite"].position.x -= half_shift
			right_entity["sprite"].position.x += half_shift


static func entity_moves_with_player(entity: Dictionary, lane_index: int) -> bool:
	if entity.has("moves_with_player"):
		return bool(entity["moves_with_player"])
	if lane_index == 0:
		return BusyTrafficBehavior.is_left_car(entity)
	return true


static func _sort_entities_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x > b["sprite"].position.x


static func _sort_entities_left_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x < b["sprite"].position.x


static func update_entity_lane_position(owner, entity: Dictionary, delta: float) -> void:
	var target_lane := int(entity.get("target_lane", entity["lane"]))
	var sprite: Sprite2D = entity["sprite"]
	if bool(entity.get("is_parked", false)):
		sprite.z_index = VehicleGeometry.z_for_lane(owner, target_lane, owner.PARKED_VEHICLE_Z_OFFSET)
	elif bool(entity.get("top_lane_evasive_offset_active", false)):
		sprite.z_index = VehicleGeometry.z_for_lane(owner, 0, int(owner.ROAD_ACTOR_Z_STEP * 0.5))
	else:
		var z_offset := 2 if entity.get("kind", "traffic") == "speeder" else 0
		sprite.z_index = VehicleGeometry.z_for_lane(owner, target_lane, z_offset)
	var target_y: float = VehicleGeometry.sprite_y_for_hitbox_bottom(
		sprite,
		target_guide_y_for_entity(owner, entity, target_lane),
		owner.VEHICLE_HITBOX_INSET,
		owner
	)
	var lerp_speed: float = owner.speeder_lane_change_lerp_speed if entity.get("kind", "traffic") == "speeder" else owner.npc_lane_change_lerp_speed
	sprite.position.y = lerpf(sprite.position.y, target_y, minf(1.0, delta * lerp_speed))
	sprite.scale = sprite.scale.lerp(target_scale_for_entity(owner, entity, target_lane), minf(1.0, delta * lerp_speed))


static func target_guide_y_for_entity(owner, entity: Dictionary, target_lane: int) -> float:
	var size: Vector2 = owner.get_viewport_rect().size
	if bool(entity.get("top_lane_evasive_offset_active", false)) and int(entity.get("lane", -1)) == 0 and target_lane == 0:
		var top_lane_y: float = VehicleGeometry.entity_lane_y(owner, 0, size, false)
		var middle_lane_y: float = VehicleGeometry.entity_lane_y(owner, 1, size, false)
		return lerpf(top_lane_y, middle_lane_y, 0.5)

	return VehicleGeometry.entity_lane_y(owner, target_lane, size, bool(entity.get("is_parked", false)))


static func target_scale_for_entity(owner, entity: Dictionary, lane_index: int) -> Vector2:
	var sprite: Sprite2D = entity["sprite"]
	var vehicle_key := str(entity.get("vehicle_key", ""))
	var fallback_height := float(entity.get("fallback_height", 92.0))
	var lane_scale: Vector2 = VehicleGeometry.scale_for_vehicle_in_lane(
		owner,
		vehicle_key,
		VehicleGeometry.scale_for_height(sprite.texture, fallback_height),
		lane_index
	)
	if bool(entity.get("top_lane_evasive_offset_active", false)) and int(entity.get("lane", -1)) == 0 and lane_index == 0:
		var middle_scale: Vector2 = VehicleGeometry.scale_for_vehicle_in_lane(
			owner,
			vehicle_key,
			VehicleGeometry.scale_for_height(sprite.texture, fallback_height),
			1
		)
		return lane_scale.lerp(middle_scale, 0.5)
	return lane_scale
