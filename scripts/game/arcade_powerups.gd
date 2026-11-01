extends Node2D

# Ride-local pickups keep their own RNG and live-save state, separate from traffic.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const ICONS := preload("res://assets/ui/powerups/icons.png")
const FONT := preload("res://assets/fonts/game_font.tres")
const OWNER_META := &"arcade_powerups"
const KINDS := ["speed", "shield", "time"]
const REGIONS := {
	"speed": Rect2(104, 211, 640, 373),
	"shield": Rect2(839, 123, 483, 530),
	"time": Rect2(1460, 115, 473, 537),
}
const COLORS := {
	"speed": Color("ffe28a"),
	"shield": Color("8edbff"),
	"time": Color("b8f097"),
}
const ROAD_SCROLL_PER_VISUAL_DISTANCE := 16.0

class PickupVisual:
	extends Node2D
	var icon: Texture2D
	var accent := Color.WHITE

	func _draw() -> void:
		var radius := GameTuning.ARCADE_POWERUP_RADIUS
		draw_circle(Vector2.ZERO, radius + 4.0, Color(0.02, 0.03, 0.04, 0.6))
		draw_circle(Vector2.ZERO, radius, Color(0.04, 0.06, 0.07, 0.94))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, accent, 2.0)
		if icon != null:
			var icon_size := icon.get_size()
			var fitted := icon_size * (40.0 / maxf(icon_size.x, icon_size.y))
			draw_texture_rect(icon, Rect2(-fitted * 0.5, fitted), false)

var enabled := false
var free_boost_seconds := 0.0
var shield_seconds := 0.0
var _owner
var _rng := RandomNumberGenerator.new()
var _items: Array[Dictionary] = []
var _textures: Dictionary = {}
var _spawn_left := 0.0
var _elapsed := 0.0
var _last_distance := 0.0
var _last_viewport := Vector2.ZERO
var _hud: HBoxContainer
var _effect_labels: Dictionary = {}
var _effect_panels: Dictionary = {}
var _message: Label
var _message_seconds := 0.0


static func for_owner(owner) -> Variant:
	if owner == null or not is_instance_valid(owner) or not owner.has_meta(OWNER_META):
		return null
	var controller: Variant = owner.get_meta(OWNER_META)
	return controller if is_instance_valid(controller) and controller.enabled else null


func setup(owner: Node2D) -> void:
	_owner = owner
	name = "ArcadePowerups"
	set_process(false)
	_owner.set_meta(OWNER_META, self)
	enabled = PlayerState.is_arcade_mode_enabled()
	_rng.randomize()
	_last_distance = _owner.distance
	_last_viewport = _owner.get_viewport_rect().size
	_spawn_left = _next_spawn_delay()
	if enabled:
		_build_hud()
		refresh_layout()


func tick_effects(delta: float) -> void:
	if not enabled or _owner.game_state != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	free_boost_seconds = maxf(0.0, free_boost_seconds - delta)
	shield_seconds = maxf(0.0, shield_seconds - delta)
	_message_seconds = maxf(0.0, _message_seconds - delta)
	_elapsed = fmod(_elapsed + delta, TAU * 10.0)
	_refresh_hud()


func update_pickups(delta: float) -> void:
	if not enabled or _owner.game_state != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	refresh_layout()
	var travelled := maxf(0.0, _owner.distance - _last_distance)
	_last_distance = _owner.distance
	var scroll: float = travelled * _owner.VISUAL_DISTANCE_SCALE * ROAD_SCROLL_PER_VISUAL_DISTANCE
	var player_rect := VehicleGeometry.collision_rect(_owner.player, _owner.PLAYER_HITBOX_INSET, _owner)
	for index in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[index]
		var visual: Node2D = item.visual
		var previous := visual.global_position
		visual.position.x -= scroll
		var at := visual.global_position
		var half := Vector2.ONE * GameTuning.ARCADE_POWERUP_RADIUS * visual.global_scale.abs()
		var swept := Rect2(Vector2(minf(previous.x, at.x) - half.x, at.y - half.y), Vector2(absf(previous.x - at.x) + half.x * 2.0, half.y * 2.0))
		if int(item.lane) == _owner.player_lane and swept.intersects(player_rect):
			_apply_pickup(str(item.kind))
			_remove_item(index)
		elif visual.position.x < -100.0:
			_remove_item(index)
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_left = _next_spawn_delay()
		if _items.size() < GameTuning.ARCADE_POWERUP_MAX_ACTIVE and _rng.randf() < GameTuning.ARCADE_POWERUP_SPAWN_CHANCE:
			var kind: String = KINDS[_rng.randi_range(0, KINDS.size() - 1)]
			_add_item(kind, _rng.randi_range(0, 2), _last_viewport.x + 80.0, _rng.randf_range(0.0, TAU))
	_refresh_hud()


func _apply_pickup(kind: String) -> void:
	match kind:
		"speed":
			free_boost_seconds = GameTuning.ARCADE_POWERUP_DURATION_SECONDS
			_show_message("Free boost: 10s", COLORS.speed)
		"shield":
			shield_seconds = GameTuning.ARCADE_POWERUP_DURATION_SECONDS
			_owner.player_hit_recovery_timer = 0.0
			_show_message("Shield: 10s", COLORS.shield)
		"time":
			_owner.time_left += GameTuning.ARCADE_POWERUP_TIME_BONUS_SECONDS
			_show_message("Time +10s", COLORS.time)


func clear() -> void:
	free_boost_seconds = 0.0
	shield_seconds = 0.0
	_message_seconds = 0.0
	for index in range(_items.size() - 1, -1, -1):
		_remove_item(index)
	_spawn_left = _next_spawn_delay()
	if is_instance_valid(_owner):
		_last_distance = _owner.distance
	_refresh_hud()


func snapshot() -> Dictionary:
	var pickups: Array[Dictionary] = []
	for item: Dictionary in _items:
		pickups.append({
			"kind": str(item.kind),
			"lane": int(item.lane),
			"x": float(item.visual.position.x),
			"phase": float(item.phase),
		})
	return {
		"free_boost_seconds": free_boost_seconds,
		"shield_seconds": shield_seconds,
		"spawn_left": _spawn_left,
		"elapsed": _elapsed,
		"rng_seed": str(_rng.seed),
		"rng_state": str(_rng.state),
		"pickups": pickups,
	}


func restore(data: Dictionary, viewport_ratio: Vector2) -> void:
	clear()
	if not enabled:
		return
	free_boost_seconds = _bounded_number(data.get("free_boost_seconds"), 0.0, GameTuning.ARCADE_POWERUP_DURATION_SECONDS)
	shield_seconds = _bounded_number(data.get("shield_seconds"), 0.0, GameTuning.ARCADE_POWERUP_DURATION_SECONDS)
	_spawn_left = _bounded_number(data.get("spawn_left"), _spawn_left, GameTuning.ARCADE_POWERUP_SPAWN_MAX_SECONDS)
	_elapsed = _bounded_number(data.get("elapsed"), 0.0, TAU * 10.0)
	_last_viewport = _owner.get_viewport_rect().size
	_last_distance = _owner.distance
	var pickups: Variant = data.get("pickups", [])
	if pickups is Array:
		for saved: Variant in pickups:
			if _items.size() >= GameTuning.ARCADE_POWERUP_MAX_ACTIVE:
				break
			if not saved is Dictionary or str(saved.get("kind", "")) not in KINDS:
				continue
			var lane: Variant = saved.get("lane")
			var x: Variant = saved.get("x")
			if not lane is int or int(lane) < 0 or int(lane) > 2 or not (x is int or x is float) or not is_finite(float(x)):
				continue
			var phase := _bounded_number(saved.get("phase"), 0.0, TAU)
			_add_item(str(saved.kind), int(lane), clampf(float(x) * viewport_ratio.x, -100.0, _last_viewport.x + 200.0), phase)
	if data.has("rng_seed") and str(data.rng_seed).is_valid_int():
		_rng.seed = int(data.rng_seed)
	if data.has("rng_state") and str(data.rng_state).is_valid_int():
		_rng.state = int(data.rng_state)
	_refresh_hud()


func refresh_layout() -> void:
	if not enabled:
		return
	var viewport: Vector2 = _owner.get_viewport_rect().size
	var ratio := viewport.x / maxf(1.0, _last_viewport.x)
	for item: Dictionary in _items:
		var visual: Node2D = item.visual
		visual.position.x *= ratio
		_layout_item(item, viewport)
	_last_viewport = viewport
	_refresh_hud()


func _add_item(kind: String, lane: int, x: float, phase: float) -> void:
	var visual := PickupVisual.new()
	visual.icon = _texture(kind)
	visual.accent = COLORS[kind]
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(visual)
	visual.position.x = x
	var item := {
		"kind": kind,
		"lane": lane,
		"phase": phase,
		"visual": visual,
	}
	_items.append(item)
	_layout_item(item, _owner.get_viewport_rect().size)


func _layout_item(item: Dictionary, viewport: Vector2) -> void:
	var visual: Node2D = item.visual
	var lane := int(item.lane)
	var fit := viewport.y / 720.0 * VehicleGeometry.perspective_scale_for_lane(_owner, lane)
	visual.scale = Vector2.ONE * fit
	visual.z_index = VehicleGeometry.z_for_lane(_owner, lane, 2)
	visual.position.y = VehicleGeometry.lane_y(_owner, lane, viewport) - GameTuning.ARCADE_POWERUP_LANE_HEIGHT * fit + sin(_elapsed * 3.0 + float(item.phase)) * 4.0 * fit


func _remove_item(index: int) -> void:
	var visual: Node2D = _items[index].visual
	visual.hide()
	visual.queue_free()
	_items.remove_at(index)


func _next_spawn_delay() -> float:
	return _rng.randf_range(GameTuning.ARCADE_POWERUP_SPAWN_MIN_SECONDS, GameTuning.ARCADE_POWERUP_SPAWN_MAX_SECONDS)


func _texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var texture := AtlasTexture.new()
		texture.atlas = ICONS
		texture.region = REGIONS[kind]
		texture.filter_clip = true
		_textures[kind] = texture
	return _textures[kind]


func _build_hud() -> void:
	_hud = HBoxContainer.new()
	_hud.name = "ArcadePowerupEffects"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_constant_override("separation", 12)
	_owner.game_hud.get_ui_root().add_child(_hud)
	for kind: String in ["speed", "shield"]:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.03, 0.04, 0.82)
		style.border_color = COLORS[kind]
		style.set_border_width_all(1)
		style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", style)
		_hud.add_child(panel)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		panel.add_child(row)
		var icon := TextureRect.new()
		icon.texture = _texture(kind)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 26)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := _label()
		row.add_child(label)
		_effect_labels[kind] = label
		_effect_panels[kind] = panel
	_message = _label()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owner.game_hud.get_ui_root().add_child(_message)
	_refresh_hud()


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	return label


func _show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.modulate = color
	_message_seconds = 1.5


func _refresh_hud() -> void:
	if not is_instance_valid(_hud):
		return
	var times := {"speed": free_boost_seconds, "shield": shield_seconds}
	for kind: String in times:
		_effect_panels[kind].visible = float(times[kind]) > 0.0
		_effect_labels[kind].text = "%s %ds" % ["Boost" if kind == "speed" else "Shield", ceili(float(times[kind]))]
	_hud.visible = free_boost_seconds > 0.0 or shield_seconds > 0.0
	_hud.size = _hud.get_combined_minimum_size()
	var viewport: Vector2 = _owner.get_viewport_rect().size
	var compact := viewport.x < 800.0
	_hud.position = Vector2(maxf(8.0, (viewport.x - _hud.size.x) * 0.5), 118.0 if compact else 58.0)
	_message.visible = _message_seconds > 0.0
	_message.position = Vector2(maxf(4.0, viewport.x * 0.5 - 150.0), 164.0 if compact else 106.0)
	_message.size = Vector2(minf(300.0, viewport.x - 8.0), 30.0)


func _bounded_number(value: Variant, fallback: float, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), 0.0, maximum)


func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()
	if is_instance_valid(_message):
		_message.queue_free()
	if is_instance_valid(_owner) and _owner.has_meta(OWNER_META) and _owner.get_meta(OWNER_META) == self:
		_owner.remove_meta(OWNER_META)
