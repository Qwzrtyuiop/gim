extends RefCounted

# Slot-only live driving state. Normal cross-scene checkpoints retain their own flow.
const StageProfiles := preload("res://scripts/game/stage_profiles.gd")
const Visuals := preload("res://scripts/game/vehicle_visuals.gd")
const Wheels := preload("res://scripts/game/vehicle_wheel_animation.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const Signals := preload("res://scripts/game/vehicle_traffic_signals.gd")
const OWNER_FIELDS := [
	"stage_type", "stage_difficulty", "stage_time_of_day", "stage_traffic", "stage_weather",
	"stage_special_type", "special_stage_id", "special_stage_blueprint", "special_mode_hidden_modifiers",
	"distance", "target_distance", "rolled_target_distance", "rolled_target_stage_type",
	"time_left", "time_limit", "overtime_seconds", "overtime_fare_penalty_php_per_second",
	"player_lane", "player_speed", "player_x", "boost_active", "boost_speed_x", "boost_gas_save_timer",
	"player_hit_recovery_timer", "player_hit_invincible_timer", "player_hit_flicker_timer", "player_hit_flicker_visible",
	"passenger_rule_violation_count", "trip_peak_speed_kmh", "trip_vehicle_collision_count",
	"spawn_timers", "top_lane_pressure", "speeder_spawn_timer", "speeder_warning_active", "speeder_warning_timer",
	"speeder_warning_beeps_remaining", "speeder_warning_flash_timer", "oncoming_warning_elapsed", "oncoming_warning_beep_index",
	"speeder_lane_change_warning_active", "speeder_lane_change_warning_target_lane",
	"weather_effect_time", "rain_floor_drop_spawn_timer", "horn_press_cooldown",
]


static func capture(game) -> Dictionary:
	if game.game_state != "playing" or not is_instance_valid(game.player):
		return {}
	var values: Dictionary = {}
	for key: String in OWNER_FIELDS:
		values[key] = _copy_value(game.get(key))
	for key: String in StageProfiles.DEFAULT_STAGE_PROFILE:
		values[key] = _copy_value(game.get(key))
	var entities: Array[Dictionary] = []
	var indices: Dictionary = {}
	for entity: Dictionary in game.active_entities:
		if is_instance_valid(entity.get("sprite")):
			indices[entity.sprite.get_instance_id()] = entities.size()
			entities.append(entity)
	var saved_entities: Array[Dictionary] = []
	for entity: Dictionary in entities:
		var saved: Dictionary = {}
		var references: Dictionary = {}
		for key in entity:
			var value: Variant = entity[key]
			if value is Sprite2D:
				if key != "sprite" and is_instance_valid(value) and indices.has(value.get_instance_id()):
					references[key] = indices[value.get_instance_id()]
			elif not value is Object and not value is Callable and not value is Signal:
				saved[key] = _copy_value(value)
		saved["_references"] = references
		saved["_sprite"] = _sprite_state(entity.sprite)
		saved_entities.append(saved)
	var warning_index: int = -1
	if is_instance_valid(game.pending_speeder_lane_change_sprite):
		warning_index = int(indices.get(game.pending_speeder_lane_change_sprite.get_instance_id(), -1))
	var background_path: String = ""
	if game.background_scroller != null and not game.background_scroller.tiles.is_empty():
		var texture: Texture2D = game.background_scroller.tiles[0].get("texture")
		if texture != null:
			background_path = texture.resource_path
	return {
		"version": 1,
		"values": values,
		"player": _sprite_state(game.player),
		"entities": saved_entities,
		"viewport": game.get_viewport_rect().size,
		"rng_seed": str(game.rng.seed),
		"rng_state": str(game.rng.state),
		"background": background_path,
		"warning_entity": warning_index,
		"jam_count": int(game.traffic_jam_gaps.get("_convoy_count")),
		"jam_limit": int(game.traffic_jam_gaps.get("_convoy_limit")),
	}


static func restore(game, data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1 or not data.get("values") is Dictionary or not data.get("entities") is Array:
		return false
	var saved_entities: Array = data.entities
	for entry in saved_entities:
		if not entry is Dictionary or not game.VEHICLE_TEXTURES.has(str(entry.get("vehicle_key", ""))) or not entry.get("_sprite") is Dictionary:
			return false
	var values: Dictionary = data.values
	var pressure: Variant = values.get("top_lane_pressure", 0.0)
	if not (pressure is int or pressure is float) or not is_finite(float(pressure)):
		return false
	for key: String in OWNER_FIELDS:
		if values.has(key):
			game.set(key, _copy_value(values[key]))
	for key: String in StageProfiles.DEFAULT_STAGE_PROFILE:
		if values.has(key):
			game.set(key, _copy_value(values[key]))
	# Older live saves predate this ride-local field; do not retain a reused
	# scene's pressure when loading one. Valid numeric input stays bounded.
	game.top_lane_pressure = clampf(float(pressure), 0.0, 1.0)
	var viewport: Vector2 = game.get_viewport_rect().size
	var saved_viewport: Vector2 = data.get("viewport", viewport)
	var ratio := Vector2(viewport.x / maxf(1.0, saved_viewport.x), viewport.y / maxf(1.0, saved_viewport.y))
	game.player_x *= ratio.x
	_restore_sprite(game.player, data.get("player", {}), ratio)
	for entity: Dictionary in game.active_entities:
		if is_instance_valid(entity.get("sprite")):
			entity.sprite.free()
	game.active_entities.clear()
	for entry: Dictionary in saved_entities:
		var entity: Dictionary = entry.duplicate(true)
		var sprite := Sprite2D.new()
		sprite.texture = game.VEHICLE_TEXTURES[str(entity.vehicle_key)]
		sprite.centered = true
		game.add_child(sprite)
		_restore_sprite(sprite, entity._sprite, ratio)
		entity.erase("_sprite")
		entity["sprite"] = sprite
		game.active_entities.append(entity)
		Visuals.apply_shadow(game, sprite, game.VEHICLE_HITBOX_INSET)
		if not bool(entity.get("is_parked", false)):
			Visuals.apply_headlight(game, sprite, game.VEHICLE_HITBOX_INSET)
			Wheels.attach(sprite, str(entity.vehicle_key))
		if bool(entity.get("lane_change_warning_active", false)):
			entity["lane_change_warning_timer"] = 0.0
			entity["lane_change_warning_pulses_remaining"] = game.NPC_LANE_CHANGE_WARNING_PULSES
	for entity: Dictionary in game.active_entities:
		for key in entity.get("_references", {}):
			var index: int = int(entity._references[key])
			if index >= 0 and index < game.active_entities.size():
				entity[key] = game.active_entities[index].sprite
		entity.erase("_references")
	_restore_background(game, str(data.get("background", "")), viewport)
	game.traffic_jam_gaps.set("_convoy_count", int(data.get("jam_count", 0)))
	game.traffic_jam_gaps.set("_convoy_limit", int(data.get("jam_limit", 0)))
	_restart_warnings(game, int(data.get("warning_entity", -1)))
	game.game_state = "playing"
	game.horn_held = false
	game.stage_tutorial.end()
	game.stage_tutorial.timer_started = true
	game.passenger_dialogue_controller.clear()
	TrafficIndex.invalidate(game)
	# Reconstruction may allocate visual resources, but must not advance driving RNG.
	game.rng.seed = int(data.get("rng_seed", str(game.rng.seed)))
	game.rng.state = int(data.get("rng_state", str(game.rng.state)))
	return true


static func _restart_warnings(game, warning_index: int) -> void:
	# Loaded hazards always give the complete audible warning again.
	if game.oncoming_warning_elapsed >= 0.0:
		game.oncoming_warning_elapsed = 0.0
		game.oncoming_warning_beep_index = -1
		game.spawn_timers[0] = 0.0
	if game.speeder_warning_active:
		game.speeder_warning_timer = 0.0
		game.speeder_warning_beeps_remaining = 3
		game.speeder_warning_flash_timer = 0.0
	if game.speeder_lane_change_warning_active and warning_index >= 0 and warning_index < game.active_entities.size():
		game.pending_speeder_lane_change_sprite = game.active_entities[warning_index].sprite
		game.speeder_lane_change_warning_timer = 0.0
		game.speeder_lane_change_warning_beeps_remaining = 3
	else:
		Signals.clear_speeder_lane_change_warning(game)


static func _restore_background(game, path: String, viewport: Vector2) -> void:
	var texture: Texture2D = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	if texture != null and game.background_scroller != null:
		for tile: Dictionary in game.background_scroller.tiles:
			tile["texture"] = texture
			for sprite: Sprite2D in tile.sprites:
				sprite.texture = texture
		game.background_scroller.layout(viewport)
		game.background_scroller.update(game.distance)


static func _sprite_state(sprite: Sprite2D) -> Dictionary:
	return {"position": sprite.position, "scale": sprite.scale, "flip_h": sprite.flip_h, "flip_v": sprite.flip_v, "z_index": sprite.z_index, "rotation": sprite.rotation, "modulate": sprite.modulate}


static func _restore_sprite(sprite: Sprite2D, state: Dictionary, ratio: Vector2) -> void:
	for key in ["position", "scale", "flip_h", "flip_v", "z_index", "rotation", "modulate"]:
		if state.has(key):
			sprite.set(key, state[key])
	sprite.position *= ratio
	sprite.scale *= ratio.y


static func _copy_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if not value[key] is Object and not value[key] is Callable and not value[key] is Signal:
				result[key] = _copy_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			if not item is Object and not item is Callable and not item is Signal:
				result.append(_copy_value(item))
		return result
	return value
