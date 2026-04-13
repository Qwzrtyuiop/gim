extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const DAY_START_SCENE := "res://scenes/day_start_transition.tscn"
const ACHIEVEMENTS_LIBRARY_SCENE := "res://scenes/achievements_library.tscn"
const RIDE_SELECTION_SCENE := "res://scenes/ride_selection.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const SLEEP_TRANSITION_SCENE := "res://scenes/sleep_transition.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const Scene01IntroPayload := preload("res://scripts/story/payloads/scene_01_intro.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const VEHICLE_TEXTURES := {
	"blue_truck": preload("res://assets/vehicles/blue_truck.png"),
	"gray_sedan": preload("res://assets/vehicles/gray_sedan.png"),
	"jeepney": preload("res://assets/vehicles/jeepney.png"),
	"sedan": preload("res://assets/vehicles/sedan.png"),
	"truck": preload("res://assets/vehicles/truck.png"),
}
const VEHICLE_HITBOX_INSET := Vector4(0.06, 0.08, 0.06, 0.0)
const ROAD_ACTOR_Z_BASE := 10
const ROAD_ACTOR_Z_STEP := 10
const INCOMING_LANE_SCALE := 0.78
const MAIN_LANE_SCALE := 1.0
const RESET_HOLD_SECONDS := 1.4
const LAST_ENERGY_WARNING := "Start the day with your last energy?\nIf this trip goes bad, the run ends."
const START_FADE_SECONDS := 0.35

@onready var start_button: BaseButton = $Menu/StartButton
@onready var quit_button: BaseButton = $Menu/QuitButton
@onready var achievements_button: BaseButton = $Menu/AchievementsButton
@onready var achievements_label: Label = $Menu/AchievementsButton/AchievementsLabel
@onready var background: TextureRect = $Background
@onready var traffic_layer: Node2D = $TrafficLayer
@onready var menu_trace_lines: Node2D = $MenuTraceLines
@onready var hint_label: Label = $Hint
@onready var fade_overlay: ColorRect = $FadeOverlay

var rng := RandomNumberGenerator.new()
var menu_vehicles: Array = []
var texture_hitbox_cache := {}
var reset_hold_time := 0.0
var reset_message_time := 0.0
var blocked_start_message_time := 0.0
var start_confirm_dialog: ConfirmationDialog
var is_start_transitioning := false


func _ready() -> void:
	rng.randomize()
	start_button.grab_focus()
	achievements_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.pressed.connect(_start_game)
	quit_button.pressed.connect(_quit_game)
	achievements_button.pressed.connect(_open_achievements_library)
	_apply_button_font(start_button)
	_apply_button_font(quit_button)
	_apply_button_font(achievements_button)
	ButtonGlow.attach(self, start_button)
	ButtonGlow.attach(self, quit_button)
	ButtonGlow.attach(self, achievements_button)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_trace_lines.visible = false
	_create_dialogs()
	_spawn_menu_traffic()
	hint_label.text = _default_hint_text()


func _process(delta: float) -> void:
	_update_reset_progress(delta)
	for vehicle in menu_vehicles:
		var sprite: Sprite2D = vehicle["sprite"]
		var lane_index: int = vehicle["lane"]
		var world_speed: float = vehicle["world_speed"]
		var screen_velocity := world_speed
		if lane_index == 0:
			screen_velocity = -world_speed

		sprite.position.x += screen_velocity * delta
		if sprite.position.x < -260.0:
			sprite.position.x = get_viewport_rect().size.x + rng.randf_range(120.0, 420.0)
		elif sprite.position.x > get_viewport_rect().size.x + 360.0:
			sprite.position.x = -rng.randf_range(120.0, 420.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if achievements_button.has_focus():
			_open_achievements_library()
		elif quit_button.has_focus():
			_quit_game()
		else:
			_start_game()
	elif event.is_action_pressed("ui_cancel"):
		_quit_game()


func _start_game() -> void:
	if is_start_transitioning:
		return
	if PlayerState.is_run_failed():
		blocked_start_message_time = 1.8
		hint_label.text = _default_hint_text()
		return

	if PlayerState.has_save_data():
		_continue_saved_game()
		return

	PlayerState.begin_stage_sequence()
	if PlayerState.energy == 1:
		start_confirm_dialog.popup_centered()
		return

	_confirm_start_game()


func _confirm_start_game() -> void:
	if not PlayerState.get_stage_start_error().is_empty():
		blocked_start_message_time = 1.8
		hint_label.text = "%s Hold R to reset progress" % PlayerState.get_stage_start_error()
		return

	is_start_transitioning = true
	start_button.disabled = true
	quit_button.disabled = true
	PlayerState.set_pending_story(Scene01IntroPayload.build(
		DAY_START_SCENE,
		PlayerState.get_current_stage_type()
	))
	_fade_to_intro_story()


func _continue_saved_game() -> void:
	is_start_transitioning = true
	start_button.disabled = true
	quit_button.disabled = true
	achievements_button.disabled = true
	_fade_to_scene(_saved_resume_scene())


func _quit_game() -> void:
	if is_start_transitioning:
		return
	get_tree().quit()


func _open_achievements_library() -> void:
	if is_start_transitioning:
		return
	get_tree().change_scene_to_file(ACHIEVEMENTS_LIBRARY_SCENE)


func _create_dialogs() -> void:
	start_confirm_dialog = ConfirmationDialog.new()
	start_confirm_dialog.title = "Last Energy"
	start_confirm_dialog.dialog_text = LAST_ENERGY_WARNING
	start_confirm_dialog.get_ok_button().text = "START"
	start_confirm_dialog.get_cancel_button().text = "BACK"
	start_confirm_dialog.confirmed.connect(_confirm_start_game)
	add_child(start_confirm_dialog)


func _apply_button_font(button: BaseButton) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.74, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.18, 0.08, 0.05, 1.0))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)

func _fade_to_intro_story() -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, START_FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file(STORY_SCENE)


func _fade_to_scene(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, START_FADE_SECONDS)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


func _saved_resume_scene() -> String:
	var saved_scene := PlayerState.get_resume_scene()
	match saved_scene:
		GAME_SCENE, STORY_SCENE, DAY_START_SCENE, RIDE_SELECTION_SCENE, STORE_SCENE, STAGE_RESULTS_SCENE, SLEEP_TRANSITION_SCENE:
			return saved_scene

	if not PlayerState.get_pending_story().is_empty():
		return STORY_SCENE
	if not PlayerState.get_pending_sleep_transition_state().is_empty():
		return SLEEP_TRANSITION_SCENE
	if not PlayerState.get_pending_trip_selection().is_empty():
		return RIDE_SELECTION_SCENE
	return GAME_SCENE


func _update_reset_progress(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_hold_time += delta
		var percent := clampf(reset_hold_time / RESET_HOLD_SECONDS, 0.0, 1.0)
		hint_label.text = "HOLD R reset progress  %d%%" % roundi(percent * 100.0)
		if reset_hold_time >= RESET_HOLD_SECONDS:
			PlayerState.reset()
			reset_hold_time = 0.0
			reset_message_time = 1.8
	else:
		reset_hold_time = 0.0
		if reset_message_time > 0.0:
			reset_message_time -= delta
			hint_label.text = "Progress reset"
		elif blocked_start_message_time > 0.0:
			blocked_start_message_time -= delta
			hint_label.text = _default_hint_text() if PlayerState.is_run_failed() else "No energy left. Hold R to reset progress"
		else:
			hint_label.text = _default_hint_text()


func _default_hint_text() -> String:
	if PlayerState.is_run_failed():
		return "%s" % PlayerState.get_run_fail_reason()
	return "ENTER start     ESC quit     HOLD R reset progress"


func _spawn_menu_traffic() -> void:
	var viewport_width := get_viewport_rect().size.x
	var top_y := _trace_line_y("TopTraceLine", 415.0)
	var main_y := _trace_line_y("MainTraceLine", 492.0)
	_add_menu_vehicle("blue_truck", 0, Vector2(viewport_width * 0.92, top_y), 210.0, 0.32, true)
	_add_menu_vehicle("jeepney", 0, Vector2(viewport_width * 0.46, top_y), 160.0, 0.42, true)
	_add_menu_vehicle("gray_sedan", 1, Vector2(viewport_width * 0.24, main_y), 125.0, 0.38, false)
	_add_menu_vehicle("sedan", 1, Vector2(viewport_width * 0.72, main_y), 145.0, 0.38, false)


func _add_menu_vehicle(vehicle_key: String, lane_index: int, position: Vector2, world_speed: float, scale_value: float, flip_h: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = VEHICLE_TEXTURES[vehicle_key]
	sprite.centered = true
	sprite.scale = Vector2(scale_value, scale_value) * _perspective_scale_for_lane(lane_index)
	sprite.flip_h = flip_h
	sprite.position = Vector2(
		position.x,
		_sprite_y_for_hitbox_bottom(sprite, position.y, VEHICLE_HITBOX_INSET)
	)
	sprite.z_index = _z_for_lane(lane_index)
	_apply_vehicle_shadow(sprite, VEHICLE_HITBOX_INSET)
	traffic_layer.add_child(sprite)

	menu_vehicles.append({
		"sprite": sprite,
		"lane": lane_index,
		"world_speed": world_speed,
	})


func _trace_line_y(line_name: String, fallback: float) -> float:
	var line := get_node_or_null("MenuTraceLines/%s" % line_name)
	if line:
		return line.position.y
	return fallback


func _sprite_y_for_hitbox_bottom(sprite: Sprite2D, guide_y: float, inset: Vector4) -> float:
	var local_rect := _local_hitbox_rect(sprite, inset)
	var local_bottom := local_rect.position.y + local_rect.size.y
	return guide_y - local_bottom * sprite.scale.y


func _local_hitbox_rect(sprite: Sprite2D, inset: Vector4) -> Rect2:
	var texture_size := sprite.texture.get_size()
	var visible_rect := _visible_texture_rect(sprite.texture)

	var left := visible_rect.position.x + visible_rect.size.x * inset.x
	var top := visible_rect.position.y + visible_rect.size.y * inset.y
	var right := visible_rect.position.x + visible_rect.size.x * (1.0 - inset.z)
	var bottom := visible_rect.position.y + visible_rect.size.y * (1.0 - inset.w)

	if sprite.flip_h:
		var mirrored_left := texture_size.x - right
		right = texture_size.x - left
		left = mirrored_left

	return Rect2(
		Vector2(left, top) - texture_size * 0.5,
		Vector2(maxf(1.0, right - left), maxf(1.0, bottom - top))
	)


func _visible_texture_rect(texture: Texture2D) -> Rect2:
	var cache_key := texture.resource_path
	if texture_hitbox_cache.has(cache_key):
		return texture_hitbox_cache[cache_key]

	var image := texture.get_image()
	if image == null or image.is_empty():
		var fallback_rect := Rect2(Vector2.ZERO, texture.get_size())
		texture_hitbox_cache[cache_key] = fallback_rect
		return fallback_rect

	var used_rect_i := image.get_used_rect()
	var used_rect := Rect2(Vector2(used_rect_i.position), Vector2(used_rect_i.size))
	if used_rect.size.x <= 0.0 or used_rect.size.y <= 0.0:
		used_rect = Rect2(Vector2.ZERO, texture.get_size())

	texture_hitbox_cache[cache_key] = used_rect
	return used_rect


func _apply_vehicle_shadow(sprite: Sprite2D, inset: Vector4) -> void:
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.z_index = -1
	shadow.color = Color(0.0, 0.0, 0.0, 0.34)
	sprite.add_child(shadow)

	var local_rect := _local_hitbox_rect(sprite, inset)
	var shadow_width := local_rect.size.x * 0.92
	var shadow_height := maxf(20.0, local_rect.size.y * 0.20)
	var center_x := local_rect.position.x + local_rect.size.x * 0.5
	var center_y := local_rect.position.y + local_rect.size.y - shadow_height * 0.28
	var half_width := shadow_width * 0.5
	var half_height := shadow_height * 0.5

	shadow.polygon = PackedVector2Array([
		Vector2(center_x - half_width, center_y),
		Vector2(center_x - half_width * 0.72, center_y - half_height),
		Vector2(center_x, center_y - half_height * 0.86),
		Vector2(center_x + half_width * 0.72, center_y - half_height),
		Vector2(center_x + half_width, center_y),
		Vector2(center_x + half_width * 0.72, center_y + half_height),
		Vector2(center_x, center_y + half_height * 0.86),
		Vector2(center_x - half_width * 0.72, center_y + half_height),
	])


func _perspective_scale_for_lane(lane_index: int) -> float:
	if lane_index == 0:
		return INCOMING_LANE_SCALE
	return MAIN_LANE_SCALE


func _z_for_lane(lane_index: int, offset := 0) -> int:
	return ROAD_ACTOR_Z_BASE + lane_index * ROAD_ACTOR_Z_STEP + offset
