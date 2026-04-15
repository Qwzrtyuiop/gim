extends Node2D

const BACKGROUND_LOOP_TEXTURE := preload("res://assets/background/bg1_loop.png")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const UI_FRAME_TEXTURE := preload("res://assets/ui/ui_frame.png")
const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const GAS_ICON := preload("res://assets/ui/icons/gas_pump.svg")
const TUTORIAL_IMAGE := preload("res://assets/tutorial/tutorial.png")
const SPEEDOMETER_GAUGE := preload("res://scripts/speedometer_gauge.gd")
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const BackgroundScroller := preload("res://scripts/game/background_scroller.gd")
const BusyTrafficBehavior := preload("res://scripts/game/busy_traffic_behavior.gd")
const GameAudioManager := preload("res://scripts/game/game_audio_manager.gd")
const GameEconomyManager := preload("res://scripts/game/game_economy_manager.gd")
const GameInput := preload("res://scripts/game/game_input.gd")
const GameRenderer := preload("res://scripts/game/game_renderer.gd")
const PlayerVehicleBehavior := preload("res://scripts/game/player_vehicle_behavior.gd")
const VehicleBehaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const StageProfiles := preload("res://scripts/game/stage_profiles.gd")
const PLAYER_TEXTURE := preload("res://assets/vehicles/player_tricycle.png")
const VEHICLE_TEXTURES := {
	"blue_truck": preload("res://assets/vehicles/blue_truck.png"),
	"gray_sedan": preload("res://assets/vehicles/gray_sedan.png"),
	"jeepney": preload("res://assets/vehicles/jeepney.png"),
	"motorcycle": preload("res://assets/vehicles/motorcycle.png"),
	"sedan": preload("res://assets/vehicles/sedan.png"),
	"truck": preload("res://assets/vehicles/truck.png"),
	"vendor_tricycle": preload("res://assets/vehicles/vendor_tricycle.png"),
}
const VEHICLE_REFERENCE_PATHS := {
	"player_tricycle": "EditorPreview/VehicleScaleReferences/PlayerTricycleReference",
	"blue_truck": "EditorPreview/VehicleScaleReferences/BlueTruckReference",
	"gray_sedan": "EditorPreview/VehicleScaleReferences/GraySedanReference",
	"jeepney": "EditorPreview/VehicleScaleReferences/JeepneyReference",
	"motorcycle": "EditorPreview/VehicleScaleReferences/MotorcycleReference",
	"sedan": "EditorPreview/VehicleScaleReferences/SedanReference",
	"truck": "EditorPreview/VehicleScaleReferences/TruckReference",
	"vendor_tricycle": "EditorPreview/VehicleScaleReferences/VendorTricycleReference",
}

const LANE_NAMES := ["INCOMING", "MAIN", "SHOULDER"]
const BASE_DISTANCE_SCALE := 0.07
const PLAYER_HITBOX_INSET := Vector4(0.08, 0.08, 0.08, 0.0)
const VEHICLE_HITBOX_INSET := Vector4(0.06, 0.08, 0.06, 0.0)
const NPC_LANE_CHANGE_WARNING_PULSES := 3
const NPC_LANE_CHANGE_WARNING_INTERVAL := 0.28
const POST_DAY_SEVEN_SPAWN_DELAY_X := 0.90
const POST_DAY_SEVEN_BUSY_CAR_CHANCE_MAIN := 0.10
const POST_DAY_SEVEN_BUSY_CAR_CHANCE_SHOULDER := 0.08
const POST_DAY_SEVEN_BUSY_CAR_LANE_CHANGE_CHANCE_PER_SECOND := 0.035
const PARKED_VEHICLE_KEYS := ["truck", "jeepney", "sedan"]
const PARKED_VEHICLE_Y_OFFSET := 26.0
const PARKED_COLLISION_MIN_KMH := 40
const PARKED_VEHICLE_Z_OFFSET := 4
const SPEEDER_PLAYER_LANE_CHANGE_BUFFER := 260.0
const SPAWN_ROOM_EDGE_BUFFER := 120.0
const SPAWN_MIN_OFFSET := 90.0
const SPAWN_MAX_OFFSET := 360.0
const FAST_SPEED_SPAWN_DELAY_X := 0.35
const BLOCKED_SPAWN_RETRY_MIN_DELAY := 0.18
const BLOCKED_SPAWN_RETRY_MAX_DELAY := 0.55
const FAST_SPAWN_ROOM_EXTRA := 260.0
const TIME_FILTER_Z_INDEX := 760
const NIGHT_MASK_Z_INDEX := 790
const HEADLIGHT_Z_INDEX := 820
const ROAD_ACTOR_Z_BASE := 10
const ROAD_ACTOR_Z_STEP := 10
const NIGHT_VISIBILITY_SHADER_CODE := "
shader_type canvas_item;

uniform vec2 focus_center = vec2(0.32, 0.68);
uniform vec2 outer_radius = vec2(0.36, 0.24);
uniform float inner_ratio = 0.42;
uniform vec4 shade_color : source_color = vec4(0.0, 0.0, 0.0, 0.78);

void fragment() {
	vec2 delta = SCREEN_UV - focus_center;
	vec2 normalized = delta / max(outer_radius, vec2(0.0001));
	float ellipse_distance = length(normalized);
	float shade = smoothstep(inner_ratio, 1.0, ellipse_distance);
	COLOR = vec4(shade_color.rgb, shade_color.a * shade);
}
"
const NOON_GLOW_SHADER_CODE := "
shader_type canvas_item;

uniform vec2 glow_center = vec2(0.5, 0.22);
uniform vec2 glow_radius = vec2(0.72, 0.54);
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.32, 0.18);

void fragment() {
	vec2 delta = SCREEN_UV - glow_center;
	vec2 normalized = delta / max(glow_radius, vec2(0.0001));
	float dist = length(normalized);
	float alpha = max(0.0, 1.0 - dist);
	alpha = alpha * alpha * 0.85;
	COLOR = vec4(glow_color.rgb, glow_color.a * alpha);
}
"
const SPEEDOMETER_MAX_KMH := 180
const SPEEDOMETER_REFERENCE_MAX_SPEED := 560.0
const SPEEDOMETER_BASE_MAX_KMH := 60.0

@export_group("Stage")
@export_enum(
	"short-morning-chill",
	"short-morning-normal",
	"short-morning-traffic-jam",
	"short-morning-busy",
	"short-morning-speeders",
	"short-noon-chill",
	"short-noon-normal",
	"short-noon-traffic-jam",
	"short-noon-busy",
	"short-noon-speeders",
	"short-night-chill",
	"short-night-normal",
	"short-night-traffic-jam",
	"short-night-busy",
	"short-night-speeders",
	"medium-morning-chill",
	"medium-morning-normal",
	"medium-morning-traffic-jam",
	"medium-morning-busy",
	"medium-morning-speeders",
	"medium-noon-chill",
	"medium-noon-normal",
	"medium-noon-traffic-jam",
	"medium-noon-busy",
	"medium-noon-speeders",
	"medium-night-chill",
	"medium-night-normal",
	"medium-night-traffic-jam",
	"medium-night-busy",
	"medium-night-speeders",
	"long-morning-chill",
	"long-morning-normal",
	"long-morning-traffic-jam",
	"long-morning-busy",
	"long-morning-speeders",
	"long-noon-chill",
	"long-noon-normal",
	"long-noon-traffic-jam",
	"long-noon-busy",
	"long-noon-speeders",
	"long-night-chill",
	"long-night-normal",
	"long-night-traffic-jam",
	"long-night-busy",
	"long-night-speeders"
) var stage_type := "short-morning-chill"
@export_enum("barangay-streets") var background_type := "barangay-streets"
@export var use_stage_profile := true
@export var use_player_state_stage_sequence := true
@export_range(1.0, 10000.0, 1.0) var target_distance := 1000.0
@export_range(1.0, 600.0, 0.5) var time_limit := 45.0

@export_group("Player Movement")
@export_range(0.0, 600.0, 1.0) var player_x := 220.0
@export_range(0.0, 900.0, 5.0) var player_start_speed := 320.0
@export_range(0.0, 900.0, 5.0) var player_min_cruise_speed := 180.0
@export_range(0.0, 1200.0, 5.0) var player_max_speed := 560.0
@export_range(0.0, 1200.0, 5.0) var player_acceleration := 230.0
@export_range(0.0, 5.0, 0.05) var player_acceleration_x := 1.0
@export_range(0.0, 5.0, 0.05) var bottom_lane_player_acceleration_x := 1.0
@export_range(0.0, 1200.0, 5.0) var player_brake_deceleration := 230.0
@export_range(0.0, 5.0, 0.05) var player_brake_x := 1.0
@export_range(0.0, 1200.0, 5.0) var player_coast_deceleration := 85.0
@export_range(0.0, 5.0, 0.05) var player_coast_x := 1.0
@export_range(0.0, 30.0, 0.25) var player_lane_lerp_speed := 9.0
@export_range(0.0, 5.0, 0.05) var player_lane_lerp_x := 1.0
@export_range(0.0, 5.0, 0.05) var player_distance_gain_x := 1.0
@export_range(0.0, 300.0, 1.0) var player_wiggle_stop_speed := 45.0
@export_range(0.0, 20.0, 0.25) var player_wiggle_x_pixels := 2.0
@export_range(0.0, 0.1, 0.001) var player_wiggle_x_frequency := 0.012
@export_range(0.0, 0.1, 0.001) var player_wiggle_rotation_radians := 0.012
@export_range(0.0, 0.1, 0.001) var player_wiggle_rotation_frequency := 0.018
@export_range(0.0, 4.0, 0.05) var player_wiggle_intensity_x := 1.0

@export_group("Spawn Frequency")
@export_range(0.15, 60.0, 0.05) var incoming_spawn_min_delay := 18.0
@export_range(0.15, 60.0, 0.05) var incoming_spawn_max_delay := 28.0
@export_range(0.15, 60.0, 0.05) var main_spawn_min_delay := 6.0
@export_range(0.15, 60.0, 0.05) var main_spawn_max_delay := 9.5
@export_range(0.15, 60.0, 0.05) var shoulder_spawn_min_delay := 18.0
@export_range(0.15, 60.0, 0.05) var shoulder_spawn_max_delay := 30.0
@export_range(0.0, 2.0, 0.05) var spawn_delay_progress_reduction := 0.35

@export_group("Vehicle Speeds")
@export_range(50.0, 900.0, 5.0) var incoming_vehicle_min_speed := 360.0
@export_range(50.0, 900.0, 5.0) var incoming_vehicle_max_speed := 610.0
@export_range(50.0, 900.0, 5.0) var main_vehicle_min_speed := 190.0
@export_range(50.0, 900.0, 5.0) var main_vehicle_max_speed := 280.0
@export_range(0.0, 300.0, 5.0) var shoulder_vehicle_min_speed := 35.0
@export_range(0.0, 300.0, 5.0) var shoulder_vehicle_max_speed := 95.0
@export_range(0.2, 12.0, 0.1) var vehicle_speed_change_min_delay := 1.2
@export_range(0.2, 12.0, 0.1) var vehicle_speed_change_max_delay := 3.8
@export_range(10.0, 600.0, 5.0) var vehicle_speed_acceleration := 120.0
@export_range(0.0, 1.0, 0.05) var shoulder_parked_chance := 0.55
@export_range(0.0, 240.0, 5.0) var npc_follow_gap := 46.0
@export_range(0.0, 4.0, 0.05) var npc_collision_lookahead := 1.1
@export var npc_random_lane_change_enabled := false
@export_range(0.0, 2.0, 0.01) var npc_lane_change_chance_per_second := 0.0
@export_range(1.0, 20.0, 0.5) var npc_lane_change_lerp_speed := 5.0
@export_range(0.0, 2.0, 0.01) var npc_overtake_chance_per_second := 0.45
@export_range(0.0, 500.0, 5.0) var npc_overtake_speed_boost := 170.0
@export_range(0.1, 5.0, 0.1) var npc_overtake_speed_boost_seconds := 1.6
@export_range(0.0, 600.0, 5.0) var stage_clear_min_exit_speed := 180.0
@export_range(0.0, 600.0, 5.0) var stage_clear_player_exit_speed := 120.0
@export_range(0.1, 5.0, 0.05) var stage_clear_fade_seconds := 0.9

@export_group("Speeders")
@export var speeder_enabled := false
@export_range(1.0, 60.0, 0.5) var speeder_spawn_min_delay := 9.0
@export_range(1.0, 60.0, 0.5) var speeder_spawn_max_delay := 14.0
@export_range(100.0, 1400.0, 10.0) var speeder_vehicle_min_speed := 700.0
@export_range(100.0, 1400.0, 10.0) var speeder_vehicle_max_speed := 860.0
@export_range(1.0, 20.0, 0.5) var speeder_lane_change_lerp_speed := 8.0
@export_range(80.0, 800.0, 10.0) var speeder_avoid_lookahead := 360.0
@export_range(40.0, 400.0, 10.0) var speeder_safe_gap := 150.0

@export_group("Stage Rewards")
@export_range(0.0, 10.0, 0.01) var fare_php_per_meter := 0.08
@export_range(0.0, 100.0, 0.5) var time_bonus_php_per_second := 2.0
@export_range(0.0, 20.0, 0.25) var overtime_fare_penalty_php_per_second := 1.25

@export_group("Perspective")
@export_range(0.2, 2.0, 0.01) var incoming_lane_scale := 0.78
@export_range(0.2, 2.0, 0.01) var main_lane_scale := 1.0
@export_range(0.2, 2.0, 0.01) var shoulder_lane_scale := 1.18
@export_range(1.0, 20.0, 0.5) var player_perspective_lerp_speed := 9.0

@export_group("Time Filters")
@export var morning_filter_color := Color(0.0, 0.0, 0.0, 0.0)
@export var noon_filter_color := Color(1.0, 0.84, 0.26, 0.26)
@export var night_filter_color := Color(0.0, 0.02, 0.10, 0.62)
@export_range(0.0, 1.0, 0.01) var morning_headlight_alpha := 0.0
@export_range(0.0, 1.0, 0.01) var noon_headlight_alpha := 0.0
@export_range(0.0, 1.0, 0.01) var night_headlight_alpha := 0.84
@export_range(0.2, 5.0, 0.05) var headlight_cone_length_x := 3.35
@export_range(0.1, 2.0, 0.05) var headlight_cone_height_x := 1.18
@export var noon_glow_color := Color(1.0, 0.86, 0.30, 0.22)
@export var noon_glow_center := Vector2(0.52, 0.22)
@export var noon_glow_radius := Vector2(0.72, 0.56)

@export_group("Night Visibility")
@export var night_visibility_shade_color := Color(0.0, 0.0, 0.0, 0.86)
@export var night_visibility_focus_offset := Vector2(170.0, -20.0)
@export var night_visibility_outer_radius := Vector2(0.34, 0.24)
@export_range(0.1, 0.95, 0.01) var night_visibility_inner_ratio := 0.34

var rng := RandomNumberGenerator.new()
var background_scroller
var time_filter_rect: ColorRect
var noon_glow_rect: ColorRect
var noon_glow_material: ShaderMaterial
var night_visibility_rect: ColorRect
var night_visibility_material: ShaderMaterial
var headlight_cone_texture: Texture2D
var player: Sprite2D
var player_lane := 1
var player_speed := 0.0
var distance := 0.0
var time_left := 0.0
var overtime_seconds := 0.0
var active_entities: Array = []
var spawn_timers := [0.4, 0.8, 1.2]
var game_state := "playing"
var end_message := ""
var player_is_stage_clear_exiting := false
var bottom_bar: ColorRect
var speedometer: Control
var time_label: Label
var help_label: Label
var distance_progress_bg: ColorRect
var distance_progress_fill: ColorRect
var distance_label: Label
var footer_stats_row: HBoxContainer
var footer_money_label: Label
var footer_energy_label: Label
var footer_gas_label: Label
var status_label: Label
var top_right_info_panel: TextureRect
var stage_label: Label
var weekly_goal_label: Label
var debt_goal_label: Label
var speeder_warning_label: Label
var audio_manager
var fade_rect: ColorRect
var tutorial_layer: CanvasLayer
var tutorial_overlay: Control
var tutorial_image_rect: TextureRect
var tutorial_hint_label: Label
var tutorial_arrow_up_label: Label
var tutorial_arrow_down_label: Label
var tutorial_arrow_left_label: Label
var tutorial_arrow_right_label: Label
var tutorial_phase := ""
var tutorial_active := false
var tutorial_timer_started := false
var tutorial_input_lock_active := false
var texture_hitbox_cache := {}
var stage_clear_transition_started := false
var stage_clear_fade_time := 0.0
var stage_difficulty := "short"
var stage_time_of_day := "morning"
var stage_traffic := "chill"
var speeder_spawn_timer := 0.0
var speeder_warning_timer := 0.0
var speeder_warning_flash_timer := 0.0
var speeder_warning_beeps_remaining := 0
var speeder_warning_active := false
var speeder_lane_change_warning_label: Label
var speeder_lane_change_warning_timer := 0.0
var speeder_lane_change_warning_beeps_remaining := 0
var speeder_lane_change_warning_active := false
var speeder_lane_change_warning_target_lane := -1
var pending_speeder_lane_change_sprite: Sprite2D
var special_mode_hidden_modifiers := {}
var gameplay_entry_fade_seconds := 0.0
var rolled_target_distance := 0.0
var rolled_target_stage_type := ""


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/main.tscn")
	_hide_editor_preview()
	rng.randomize()
	gameplay_entry_fade_seconds = PlayerState.consume_pending_gameplay_entry_fade() if use_player_state_stage_sequence else 0.0
	if use_player_state_stage_sequence:
		stage_type = PlayerState.get_current_stage_type()
	_apply_stage_profile()
	_apply_player_upgrades()
	_reset_speeder_timer()
	time_left = time_limit
	overtime_seconds = 0.0
	player_speed = player_start_speed
	headlight_cone_texture = _make_headlight_cone_texture()
	_create_audio_manager()
	_create_background()
	_create_player()
	_create_time_filter()
	_create_noon_glow()
	_create_night_visibility_mask()
	_create_ui()
	audio_manager.start_stage_bgm(stage_time_of_day, stage_traffic, rng)
	_layout_scene()
	_begin_gameplay_entry_fade()
	_schedule_stage_tutorial()
	if use_player_state_stage_sequence:
		PlayerState.confirm_stage_started()
	set_process(true)


func _apply_stage_profile() -> void:
	if not use_stage_profile:
		return

	var parts := _parse_stage_type(stage_type)
	stage_difficulty = parts["difficulty"]
	stage_time_of_day = parts["time"]
	stage_traffic = parts["traffic"]

	var profile: Dictionary = StageProfiles.DEFAULT_STAGE_PROFILE.duplicate()
	profile.merge(StageProfiles.DIFFICULTY_PROFILES.get(stage_difficulty, {}), true)
	profile.merge(StageProfiles.TIME_PROFILES.get(stage_time_of_day, {}), true)
	profile.merge(StageProfiles.TRAFFIC_PROFILES.get(stage_traffic, {}), true)
	profile.merge(StageProfiles.BACKGROUND_PROFILES.get(background_type, {}), true)

	for setting_name in profile.keys():
		set(setting_name, profile[setting_name])

	_apply_hidden_special_modifiers()
	_apply_target_distance_roll()


func _parse_stage_type(type_name: String) -> Dictionary:
	var parts := type_name.split("-")
	if parts.size() < 3:
		return {
			"difficulty": "short",
			"time": "morning",
			"traffic": "chill",
		}

	var traffic_name := ""
	for index in range(2, parts.size()):
		if not traffic_name.is_empty():
			traffic_name += "-"
		traffic_name += parts[index]

	if parts[0] == "easy":
		parts[0] = "short"
	if not StageProfiles.DIFFICULTY_PROFILES.has(parts[0]):
		parts[0] = "short"
	if not StageProfiles.TIME_PROFILES.has(parts[1]):
		parts[1] = "morning"
	if not StageProfiles.TRAFFIC_PROFILES.has(traffic_name):
		traffic_name = "chill"

	return {
		"difficulty": parts[0],
		"time": parts[1],
		"traffic": traffic_name,
	}


func _apply_target_distance_roll() -> void:
	if rolled_target_distance <= 0.0 or rolled_target_stage_type != stage_type:
		rolled_target_distance = PlayerState.roll_stage_target_distance(stage_difficulty)
		rolled_target_stage_type = stage_type
	target_distance = rolled_target_distance


func _apply_player_upgrades() -> void:
	var modifiers := GameEconomyManager.player_upgrade_modifiers()
	player_acceleration_x *= float(modifiers["player_acceleration_x"])
	player_max_speed *= float(modifiers["player_max_speed"])
	player_brake_x *= float(modifiers["player_brake_x"])
	player_lane_lerp_x *= float(modifiers["player_lane_lerp_x"])


func _apply_hidden_special_modifiers() -> void:
	special_mode_hidden_modifiers.clear()

	match stage_traffic:
		"traffic-jam":
			special_mode_hidden_modifiers = {
				"jam_density_x": rng.randf_range(0.88, 1.16),
				"jam_lock_x": rng.randf_range(0.90, 1.14),
				"shoulder_clutter_x": rng.randf_range(0.94, 1.10),
			}
			main_spawn_min_delay *= special_mode_hidden_modifiers["jam_density_x"]
			main_spawn_max_delay *= special_mode_hidden_modifiers["jam_density_x"]
			npc_follow_gap *= special_mode_hidden_modifiers["jam_lock_x"]
			shoulder_parked_chance = clampf(
				shoulder_parked_chance * special_mode_hidden_modifiers["shoulder_clutter_x"],
				0.0,
				1.0
			)
		"busy":
			special_mode_hidden_modifiers = {
				"busy_density_x": rng.randf_range(0.82, 1.10),
				"busy_speed_x": rng.randf_range(1.0, 1.18),
				"lane_weave_x": rng.randf_range(0.88, 1.35),
				"close_call_x": rng.randf_range(0.92, 1.20),
			}
			incoming_spawn_min_delay *= special_mode_hidden_modifiers["busy_density_x"]
			incoming_spawn_max_delay *= special_mode_hidden_modifiers["busy_density_x"]
			main_spawn_min_delay *= special_mode_hidden_modifiers["busy_density_x"]
			main_spawn_max_delay *= special_mode_hidden_modifiers["busy_density_x"]
			shoulder_spawn_min_delay *= special_mode_hidden_modifiers["busy_density_x"]
			shoulder_spawn_max_delay *= special_mode_hidden_modifiers["busy_density_x"]
			incoming_vehicle_min_speed *= special_mode_hidden_modifiers["busy_speed_x"]
			incoming_vehicle_max_speed *= special_mode_hidden_modifiers["busy_speed_x"]
			main_vehicle_min_speed *= special_mode_hidden_modifiers["busy_speed_x"]
			main_vehicle_max_speed *= special_mode_hidden_modifiers["busy_speed_x"]
			shoulder_vehicle_min_speed *= special_mode_hidden_modifiers["busy_speed_x"]
			shoulder_vehicle_max_speed *= special_mode_hidden_modifiers["busy_speed_x"]
			npc_lane_change_chance_per_second *= special_mode_hidden_modifiers["lane_weave_x"]
			npc_collision_lookahead *= special_mode_hidden_modifiers["close_call_x"]
		"speeders":
			special_mode_hidden_modifiers = {
				"speeder_rate_x": rng.randf_range(0.84, 1.12),
				"speeder_speed_x": rng.randf_range(0.92, 1.14),
				"speeder_hunt_x": rng.randf_range(0.88, 1.22),
			}
			speeder_spawn_min_delay *= special_mode_hidden_modifiers["speeder_rate_x"]
			speeder_spawn_max_delay *= special_mode_hidden_modifiers["speeder_rate_x"]
			speeder_vehicle_min_speed *= special_mode_hidden_modifiers["speeder_speed_x"]
			speeder_vehicle_max_speed *= special_mode_hidden_modifiers["speeder_speed_x"]
			speeder_avoid_lookahead *= special_mode_hidden_modifiers["speeder_hunt_x"]
			main_spawn_min_delay *= rng.randf_range(0.92, 1.10)
			main_spawn_max_delay *= rng.randf_range(0.92, 1.10)


func _hide_editor_preview() -> void:
	var editor_preview := get_node_or_null("EditorPreview")
	if editor_preview:
		editor_preview.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_scene()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameInput.is_any_press(event) and game_state == "GAME OVER":
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	if tutorial_input_lock_active:
		return

	if tutorial_active:
		if tutorial_phase == "image" and GameInput.is_any_press(event):
			_set_tutorial_phase("move")
		elif tutorial_phase == "move" and GameInput.is_up_down_input(event):
			_set_tutorial_phase("speed")
		elif tutorial_phase == "speed" and GameInput.is_left_right_input(event):
			_end_stage_tutorial()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				_change_lane(-1)
			KEY_DOWN, KEY_S:
				_change_lane(1)
			KEY_SPACE, KEY_R:
				if game_state == "YOU MADE IT":
					_go_to_profit_screen()
				elif game_state != "playing":
					_try_retry_stage()


func _process(delta: float) -> void:
	if tutorial_active:
		_update_tutorial_overlay_positions()
		_update_ui()
		return
	if tutorial_input_lock_active:
		_update_background()
		_update_night_visibility_mask()
		_update_ui()
		queue_redraw()
		return

	if game_state == "playing":
		_handle_speed(delta)
		_update_progress(delta)
		_update_spawns(delta)
		_update_speeder_warning(delta)
		_update_speeder_lane_change_warning(delta)
		_update_lane_change_warnings(delta)
		_update_random_lane_changes(delta)
		_update_vehicle_speeds(delta)
		if stage_traffic != "busy":
			_update_vehicle_overtake_ai(delta)
		_update_busy_vehicle_ai(delta)
		_update_speeder_ai()
		_update_npc_following()
		VehicleBehaviors.update_overtake_speed_boosts(active_entities, delta)
		_update_entities(delta)
		_update_player(delta)
		_check_collisions()
	elif game_state == "YOU MADE IT":
		_update_stage_clear_entities(delta)
		_update_player(delta, true)
		_update_stage_clear_transition(delta)
	else:
		_update_player(delta)

	_update_background()
	_update_night_visibility_mask()
	_update_ui()
	queue_redraw()


func _draw() -> void:
	GameRenderer.draw(self, distance)


func _create_background() -> void:
	background_scroller = BackgroundScroller.new()
	background_scroller.setup(self, BACKGROUND_LOOP_TEXTURE)


func _create_audio_manager() -> void:
	audio_manager = GameAudioManager.new()
	audio_manager.setup(self)


func _create_player() -> void:
	player = Sprite2D.new()
	player.texture = PLAYER_TEXTURE
	player.centered = true
	player.z_index = _z_for_lane(player_lane, 1)
	add_child(player)
	_apply_vehicle_headlight(player, PLAYER_HITBOX_INSET)


func _create_time_filter() -> void:
	time_filter_rect = ColorRect.new()
	time_filter_rect.z_index = TIME_FILTER_Z_INDEX
	time_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_filter_rect.color = _current_time_filter_color()
	add_child(time_filter_rect)


func _create_noon_glow() -> void:
	noon_glow_rect = ColorRect.new()
	noon_glow_rect.z_index = TIME_FILTER_Z_INDEX + 4
	noon_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	noon_glow_rect.color = Color.WHITE

	var shader := Shader.new()
	shader.code = NOON_GLOW_SHADER_CODE
	noon_glow_material = ShaderMaterial.new()
	noon_glow_material.shader = shader
	noon_glow_rect.material = noon_glow_material
	add_child(noon_glow_rect)
	_update_noon_glow()


func _create_night_visibility_mask() -> void:
	night_visibility_rect = ColorRect.new()
	night_visibility_rect.z_index = NIGHT_MASK_Z_INDEX
	night_visibility_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_visibility_rect.color = Color.WHITE

	var shader := Shader.new()
	shader.code = NIGHT_VISIBILITY_SHADER_CODE
	night_visibility_material = ShaderMaterial.new()
	night_visibility_material.shader = shader
	night_visibility_rect.material = night_visibility_material
	add_child(night_visibility_rect)
	_update_night_visibility_mask()


func _create_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	speedometer = SPEEDOMETER_GAUGE.new()
	speedometer.position = Vector2(954.0, 510.0)
	speedometer.size = Vector2(320.0, 150.0)
	ui.add_child(speedometer)

	time_label = _make_label(16, Color(0.78, 0.92, 0.94, 1.0), 4)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(time_label)

	bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0.06, 0.07, 0.08, 0.90)
	ui.add_child(bottom_bar)

	help_label = _make_label(13, Color(0.95, 0.96, 0.88, 1.0), 4)
	ui.add_child(help_label)

	distance_progress_bg = ColorRect.new()
	distance_progress_bg.color = Color(0.12, 0.14, 0.16, 0.92)
	ui.add_child(distance_progress_bg)

	distance_progress_fill = ColorRect.new()
	distance_progress_fill.color = Color(0.32, 0.92, 0.66, 1.0)
	ui.add_child(distance_progress_fill)

	distance_label = _make_label(14, Color(0.60, 0.95, 0.80, 1.0), 4)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(distance_label)

	footer_stats_row = HBoxContainer.new()
	footer_stats_row.alignment = BoxContainer.ALIGNMENT_END
	footer_stats_row.add_theme_constant_override("separation", 14)
	ui.add_child(footer_stats_row)

	footer_money_label = _make_label(14, Color(1.0, 0.97, 0.82, 1.0), 4)
	footer_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_stats_row.add_child(footer_money_label)

	footer_stats_row.add_child(_make_stat_icon(ENERGY_ICON, 22.0))
	footer_energy_label = _make_label(15, Color(1.0, 0.97, 0.82, 1.0), 4)
	footer_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_stats_row.add_child(footer_energy_label)

	footer_stats_row.add_child(_make_stat_icon(GAS_ICON, 22.0))
	footer_gas_label = _make_label(15, Color(1.0, 0.97, 0.82, 1.0), 4)
	footer_gas_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_stats_row.add_child(footer_gas_label)

	status_label = _make_label(22, Color(1.0, 0.97, 0.82, 1.0), 6)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(status_label)

	top_right_info_panel = TextureRect.new()
	top_right_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right_info_panel.texture = UI_FRAME_TEXTURE
	top_right_info_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_right_info_panel.stretch_mode = TextureRect.STRETCH_SCALE
	ui.add_child(top_right_info_panel)

	stage_label = _make_label(11, Color(0.92, 0.95, 0.88, 1.0), 4)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_label.text = "DAY %d\n%s" % [PlayerState.get_current_day(), stage_type.to_upper()]
	ui.add_child(stage_label)

	weekly_goal_label = _make_label(12, Color(1.0, 0.95, 0.78, 1.0), 4)
	weekly_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weekly_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(weekly_goal_label)

	debt_goal_label = _make_label(9, Color(0.92, 0.88, 0.74, 1.0), 3)
	debt_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debt_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debt_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(debt_goal_label)

	speeder_warning_label = _make_label(48, Color(1.0, 0.92, 0.2, 1.0), 7)
	speeder_warning_label.text = "!"
	speeder_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speeder_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speeder_warning_label.visible = false
	ui.add_child(speeder_warning_label)

	speeder_lane_change_warning_label = _make_label(48, Color(1.0, 0.92, 0.2, 1.0), 7)
	speeder_lane_change_warning_label.text = "!"
	speeder_lane_change_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speeder_lane_change_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speeder_lane_change_warning_label.visible = false
	ui.add_child(speeder_lane_change_warning_label)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0 if gameplay_entry_fade_seconds > 0.0 else 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade_rect)



func _begin_gameplay_entry_fade() -> void:
	if fade_rect == null:
		return
	if gameplay_entry_fade_seconds <= 0.0:
		fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		return

	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, gameplay_entry_fade_seconds)


func _schedule_stage_tutorial() -> void:
	if tutorial_timer_started:
		return
	if not _should_show_stage_tutorial():
		return
	tutorial_timer_started = true
	_show_stage_tutorial()


func _should_show_stage_tutorial() -> bool:
	if not use_player_state_stage_sequence:
		return false
	if PlayerState.get_current_day() > 1:
		return false
	if int(PlayerState.stage_round) > 1:
		return false
	return true


func _show_stage_tutorial() -> void:
	if tutorial_active:
		return
	if game_state != "playing":
		return
	if not _should_show_stage_tutorial():
		return
	if tutorial_overlay == null:
		_build_tutorial_overlay()
	tutorial_active = true
	tutorial_input_lock_active = false
	_set_tutorial_phase("image")


func _end_stage_tutorial() -> void:
	tutorial_active = false
	tutorial_phase = ""
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	tutorial_input_lock_active = false


func _set_tutorial_phase(phase: String) -> void:
	tutorial_phase = phase
	if tutorial_overlay == null:
		return
	tutorial_overlay.visible = true
	if tutorial_image_rect != null:
		tutorial_image_rect.visible = phase == "image"
	if tutorial_arrow_up_label != null:
		tutorial_arrow_up_label.visible = phase == "move"
	if tutorial_arrow_down_label != null:
		tutorial_arrow_down_label.visible = phase == "move"
	if tutorial_arrow_left_label != null:
		tutorial_arrow_left_label.visible = phase == "speed"
	if tutorial_arrow_right_label != null:
		tutorial_arrow_right_label.visible = phase == "speed"
	if tutorial_hint_label != null:
		match phase:
			"image":
				tutorial_hint_label.text = "Press any key to close tutorial"
			"move":
				tutorial_hint_label.text = "Press UP or DOWN to continue"
			"speed":
				tutorial_hint_label.text = "Press LEFT or RIGHT to continue"
			_:
				tutorial_hint_label.text = ""
		tutorial_hint_label.visible = not tutorial_hint_label.text.is_empty()
	_update_tutorial_overlay_positions()


func _update_tutorial_overlay_positions() -> void:
	if not tutorial_active:
		return
	if player == null:
		return
	var viewport_size := get_viewport_rect().size
	var lane_center := Vector2(
		clampf(player_x + 360.0, 260.0, viewport_size.x - 280.0),
		_lane_y(1, viewport_size) - 72.0
	)
	if tutorial_arrow_up_label != null and tutorial_arrow_up_label.visible:
		tutorial_arrow_up_label.position = lane_center + Vector2(-230.0, -32.0)
	if tutorial_arrow_down_label != null and tutorial_arrow_down_label.visible:
		tutorial_arrow_down_label.position = lane_center + Vector2(10.0, -32.0)
	if tutorial_arrow_left_label != null and tutorial_arrow_left_label.visible:
		tutorial_arrow_left_label.position = lane_center + Vector2(-250.0, -32.0)
	if tutorial_arrow_right_label != null and tutorial_arrow_right_label.visible:
		tutorial_arrow_right_label.position = lane_center + Vector2(10.0, -32.0)


func _build_tutorial_overlay() -> void:
	tutorial_layer = CanvasLayer.new()
	tutorial_layer.layer = 950
	add_child(tutorial_layer)

	tutorial_overlay = Control.new()
	tutorial_overlay.anchor_right = 1.0
	tutorial_overlay.anchor_bottom = 1.0
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.visible = false
	tutorial_layer.add_child(tutorial_overlay)

	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.add_child(backdrop)

	tutorial_image_rect = TextureRect.new()
	tutorial_image_rect.texture = TUTORIAL_IMAGE
	tutorial_image_rect.anchor_left = 0.5
	tutorial_image_rect.anchor_top = 0.5
	tutorial_image_rect.anchor_right = 0.5
	tutorial_image_rect.anchor_bottom = 0.5
	tutorial_image_rect.offset_left = -401.5
	tutorial_image_rect.offset_top = -253.0
	tutorial_image_rect.offset_right = 401.5
	tutorial_image_rect.offset_bottom = 193.0
	tutorial_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tutorial_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tutorial_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay.add_child(tutorial_image_rect)

	tutorial_hint_label = _make_label(14, Color(0.98, 0.96, 0.88, 1.0), 3)
	tutorial_hint_label.anchor_left = 0.5
	tutorial_hint_label.anchor_right = 0.5
	tutorial_hint_label.anchor_top = 0.5
	tutorial_hint_label.anchor_bottom = 0.5
	tutorial_hint_label.offset_left = -260.0
	tutorial_hint_label.offset_top = 210.0
	tutorial_hint_label.offset_right = 260.0
	tutorial_hint_label.offset_bottom = 250.0
	tutorial_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_overlay.add_child(tutorial_hint_label)

	tutorial_arrow_up_label = _make_label(13, Color(0.98, 0.96, 0.88, 1.0), 3)
	tutorial_arrow_up_label.text = "UP ARROW\nMOVE UP"
	tutorial_arrow_up_label.size = Vector2(220.0, 52.0)
	tutorial_arrow_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_arrow_up_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_arrow_up_label.visible = false
	tutorial_overlay.add_child(tutorial_arrow_up_label)

	tutorial_arrow_down_label = _make_label(13, Color(0.98, 0.96, 0.88, 1.0), 3)
	tutorial_arrow_down_label.text = "DOWN ARROW\nMOVE DOWN"
	tutorial_arrow_down_label.size = Vector2(220.0, 52.0)
	tutorial_arrow_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_arrow_down_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_arrow_down_label.visible = false
	tutorial_overlay.add_child(tutorial_arrow_down_label)

	tutorial_arrow_left_label = _make_label(13, Color(0.98, 0.96, 0.88, 1.0), 3)
	tutorial_arrow_left_label.text = "LEFT ARROW\nDECELERATE"
	tutorial_arrow_left_label.size = Vector2(240.0, 52.0)
	tutorial_arrow_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_arrow_left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_arrow_left_label.visible = false
	tutorial_overlay.add_child(tutorial_arrow_left_label)

	tutorial_arrow_right_label = _make_label(13, Color(0.98, 0.96, 0.88, 1.0), 3)
	tutorial_arrow_right_label.text = "RIGHT ARROW\nACCELERATE"
	tutorial_arrow_right_label.size = Vector2(240.0, 52.0)
	tutorial_arrow_right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_arrow_right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_arrow_right_label.visible = false
	tutorial_overlay.add_child(tutorial_arrow_right_label)


func _make_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func _make_stat_icon(texture: Texture2D, size_value: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size_value, size_value)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _current_time_filter_color() -> Color:
	match stage_time_of_day:
		"night":
			return night_filter_color
	return morning_filter_color


func _current_headlight_alpha() -> float:
	match stage_time_of_day:
		"noon":
			return noon_headlight_alpha
		"night":
			return night_headlight_alpha
	return morning_headlight_alpha


func _make_headlight_cone_texture() -> Texture2D:
	var width := 256
	var height := 96
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var warm_color := Color(1.0, 0.95, 0.78, 0.0)

	for y in range(height):
		for x in range(width):
			var x_ratio := float(x) / float(width - 1)
			var center_y := (height - 1) * 0.5
			var half_height := lerpf(3.0, height * 0.46, x_ratio)
			var y_offset := absf(float(y) - center_y) / maxf(1.0, half_height)
			if y_offset > 1.0:
				continue

			var longitudinal_falloff := pow(1.0 - x_ratio, 1.35)
			var lateral_falloff := pow(1.0 - y_offset, 1.8)
			var core_glow := exp(-pow((x_ratio - 0.18) / 0.24, 2.0)) * 0.42
			var alpha := clampf(longitudinal_falloff * lateral_falloff + core_glow * lateral_falloff, 0.0, 1.0)
			image.set_pixel(x, y, Color(warm_color.r, warm_color.g, warm_color.b, alpha))

	return ImageTexture.create_from_image(image)


func _update_noon_glow() -> void:
	if noon_glow_rect == null or noon_glow_material == null:
		return

	noon_glow_rect.visible = stage_time_of_day == "noon"
	if not noon_glow_rect.visible:
		return

	noon_glow_material.set_shader_parameter("glow_center", noon_glow_center)
	noon_glow_material.set_shader_parameter("glow_radius", noon_glow_radius)
	noon_glow_material.set_shader_parameter("glow_color", noon_glow_color)


func _update_night_visibility_mask() -> void:
	if night_visibility_rect == null or night_visibility_material == null or player == null:
		return

	var is_night := stage_time_of_day == "night"
	night_visibility_rect.visible = is_night
	if not is_night:
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var focus_position := player.global_position + night_visibility_focus_offset
	var focus_center := Vector2(
		clampf(focus_position.x / viewport_size.x, 0.0, 1.0),
		clampf(focus_position.y / viewport_size.y, 0.0, 1.0)
	)
	night_visibility_material.set_shader_parameter("focus_center", focus_center)
	night_visibility_material.set_shader_parameter("outer_radius", night_visibility_outer_radius)
	night_visibility_material.set_shader_parameter("inner_ratio", night_visibility_inner_ratio)
	night_visibility_material.set_shader_parameter("shade_color", night_visibility_shade_color)


func _layout_scene() -> void:
	if background_scroller == null or not background_scroller.is_ready() or player == null:
		return

	var size := get_viewport_rect().size
	if stage_traffic == "busy":
		player_x = BusyTrafficBehavior.player_x(size)
	background_scroller.layout(size)

	player.scale = _scale_for_vehicle_in_lane(
		"player_tricycle",
		_scale_for_height(PLAYER_TEXTURE, min(116.0, size.y * 0.155)),
		player_lane
	)
	_apply_vehicle_shadow(player, PLAYER_HITBOX_INSET)
	_apply_vehicle_headlight(player, PLAYER_HITBOX_INSET)
	player.position = Vector2(player_x, _sprite_y_for_hitbox_bottom(player, _lane_y(player_lane, size), PLAYER_HITBOX_INSET))

	if speedometer:
		speedometer.position = Vector2(size.x - 320.0 - 6.0, size.y - 180.0)
		speedometer.size = Vector2(320.0, 150.0)

	if bottom_bar:
		bottom_bar.position = Vector2(0.0, size.y - 58.0)
		bottom_bar.size = Vector2(size.x, 58.0)

	if help_label:
		help_label.text = "UP/DOWN switch lane    LEFT/RIGHT adjust speed    SPACE/R action"
		help_label.position = Vector2(28.0, size.y - 45.0)
		help_label.size = Vector2(size.x * 0.34, 34.0)

	if time_label:
		time_label.position = Vector2(size.x * 0.5 - 120.0, 18.0)
		time_label.size = Vector2(240.0, 32.0)

	if distance_progress_bg:
		distance_progress_bg.position = Vector2(size.x * 0.5 - 160.0, size.y - 86.0)
		distance_progress_bg.size = Vector2(320.0, 10.0)

	if distance_progress_fill:
		distance_progress_fill.position = Vector2(size.x * 0.5 - 160.0, size.y - 86.0)
		distance_progress_fill.size = Vector2.ZERO

	if distance_label:
		distance_label.position = Vector2(size.x * 0.5 - 180.0, size.y - 70.0)
		distance_label.size = Vector2(360.0, 30.0)

	if footer_stats_row:
		footer_stats_row.position = Vector2(size.x * 0.64, size.y - 50.0)
		footer_stats_row.size = Vector2(size.x * 0.34 - 24.0, 40.0)

	if status_label:
		status_label.position = Vector2(0.0, size.y * 0.37)
		status_label.size = Vector2(size.x, 120.0)

	if top_right_info_panel:
		top_right_info_panel.position = Vector2(18.0, 10.0)
		top_right_info_panel.size = Vector2(312.0, 128.0)

		if stage_label:
			stage_label.text = "DAY %d\n%s" % [PlayerState.get_current_day(), stage_type.to_upper()]
			stage_label.position = Vector2(40.0, 26.0)
			stage_label.size = Vector2(268.0, 42.0)

		if weekly_goal_label:
			weekly_goal_label.position = Vector2(40.0, 70.0)
			weekly_goal_label.size = Vector2(268.0, 22.0)

		if debt_goal_label:
			debt_goal_label.position = Vector2(40.0, 92.0)
			debt_goal_label.size = Vector2(268.0, 24.0)

	if speeder_warning_label:
		speeder_warning_label.position = Vector2(player_x + 105.0, _lane_y(1, size) - 92.0)
		speeder_warning_label.size = Vector2(90.0, 90.0)

	if speeder_lane_change_warning_label:
		speeder_lane_change_warning_label.position = Vector2(player_x + 105.0, _lane_y(max(player_lane, 1), size) - 92.0)
		speeder_lane_change_warning_label.size = Vector2(90.0, 90.0)

	if fade_rect:
		fade_rect.position = Vector2.ZERO
		fade_rect.size = size

	if time_filter_rect:
		time_filter_rect.position = Vector2.ZERO
		time_filter_rect.size = size
		time_filter_rect.color = _current_time_filter_color()

	if noon_glow_rect:
		noon_glow_rect.position = Vector2.ZERO
		noon_glow_rect.size = size
		_update_noon_glow()

	if night_visibility_rect:
		night_visibility_rect.position = Vector2.ZERO
		night_visibility_rect.size = size
		_update_night_visibility_mask()


func _handle_speed(delta: float) -> void:
	player_speed = PlayerVehicleBehavior.next_speed(
		player_speed,
		delta,
		GameInput.is_accelerating(),
		GameInput.is_braking(),
		player_lane,
		background_type,
		player_acceleration,
		player_acceleration_x,
		bottom_lane_player_acceleration_x,
		player_brake_deceleration,
		player_brake_x,
		player_min_cruise_speed,
		player_coast_deceleration,
		player_coast_x,
		player_max_speed
	)


func _update_progress(delta: float) -> void:
	distance += PlayerVehicleBehavior.distance_delta(player_speed, _distance_scale(), delta)
	if time_left > 0.0:
		time_left -= delta
		if time_left < 0.0:
			overtime_seconds += -time_left
			time_left = 0.0
	else:
		overtime_seconds += delta

	if distance >= target_distance:
		_end_game("YOU MADE IT", "Target distance reached. Space/R to profit screen.")


func _update_spawns(delta: float) -> void:
	var progress := clampf(distance / maxf(1.0, target_distance), 0.0, 1.0)
	for lane_index in range(3):
		spawn_timers[lane_index] -= delta
		if spawn_timers[lane_index] <= 0.0:
			var spawn_side := _vehicle_spawn_side()
			if _lane_has_spawn_room(lane_index, spawn_side):
				_spawn_entity(lane_index, spawn_side)
				spawn_timers[lane_index] = _next_spawn_delay(lane_index, progress)
			else:
				spawn_timers[lane_index] = _blocked_spawn_retry_delay()


func _next_spawn_delay(lane_index: int, progress: float) -> float:
	var delay_range := _spawn_delay_range_for_lane(lane_index)
	var speed_spawn_x := lerpf(1.0, FAST_SPEED_SPAWN_DELAY_X, _player_speed_ratio())
	var min_delay := maxf(0.05, (delay_range.x - progress * spawn_delay_progress_reduction) * speed_spawn_x)
	var max_delay := maxf(min_delay, (delay_range.y - progress * spawn_delay_progress_reduction) * speed_spawn_x)
	return rng.randf_range(min_delay, max_delay)


func _blocked_spawn_retry_delay() -> float:
	var speed_spawn_x := lerpf(1.0, FAST_SPEED_SPAWN_DELAY_X, _player_speed_ratio())
	return rng.randf_range(BLOCKED_SPAWN_RETRY_MIN_DELAY, BLOCKED_SPAWN_RETRY_MAX_DELAY) * speed_spawn_x


func _spawn_delay_range_for_lane(lane_index: int) -> Vector2:
	var delay_range := Vector2(1.0, 2.0)
	match lane_index:
		0:
			delay_range = Vector2(incoming_spawn_min_delay, incoming_spawn_max_delay)
		1:
			delay_range = Vector2(main_spawn_min_delay, main_spawn_max_delay)
		2:
			delay_range = Vector2(shoulder_spawn_min_delay, shoulder_spawn_max_delay)

	if _is_post_day_seven_traffic_ramp():
		delay_range *= POST_DAY_SEVEN_SPAWN_DELAY_X

	return delay_range


func _vehicle_spawn_side() -> String:
	if stage_traffic == "busy":
		return BusyTrafficBehavior.spawn_side(rng, player_speed, player_max_speed)
	return BusyTrafficBehavior.RIGHT_SPAWN_SIDE


func _lane_has_spawn_room(lane_index: int, spawn_side := BusyTrafficBehavior.RIGHT_SPAWN_SIDE) -> bool:
	if stage_traffic == "busy":
		return BusyTrafficBehavior.lane_has_spawn_room(
			active_entities,
			lane_index,
			get_viewport_rect().size,
			spawn_side,
			player_speed,
			player_max_speed
		)

	var right_edge := get_viewport_rect().size.x - SPAWN_ROOM_EDGE_BUFFER + FAST_SPAWN_ROOM_EXTRA * _player_speed_ratio()
	for entity in active_entities:
		if entity["lane"] == lane_index and entity["sprite"].position.x > right_edge:
			return false
	return true


func _spawn_entity(lane_index: int, spawn_side := BusyTrafficBehavior.RIGHT_SPAWN_SIDE) -> void:
	var size := get_viewport_rect().size
	var sprite := Sprite2D.new()
	var vehicle_key := ""
	var world_speed := 0.0
	var min_world_speed := 0.0
	var max_world_speed := 0.0
	var fallback_height := 80.0
	var is_busy_car := false
	var is_parked := false

	match lane_index:
		0:
			vehicle_key = _choose(["blue_truck", "jeepney", "sedan", "truck"])
			min_world_speed = minf(incoming_vehicle_min_speed, incoming_vehicle_max_speed)
			max_world_speed = maxf(incoming_vehicle_min_speed, incoming_vehicle_max_speed)
			fallback_height = 96.0
			sprite.flip_h = spawn_side == BusyTrafficBehavior.RIGHT_SPAWN_SIDE
		1:
			vehicle_key = _choose(["gray_sedan", "jeepney", "sedan", "motorcycle"])
			min_world_speed = minf(main_vehicle_min_speed, main_vehicle_max_speed)
			max_world_speed = maxf(main_vehicle_min_speed, main_vehicle_max_speed)
			fallback_height = 96.0
		2:
			var can_spawn_parked := stage_traffic != "busy" or spawn_side != BusyTrafficBehavior.LEFT_SPAWN_SIDE
			if can_spawn_parked and rng.randf() < shoulder_parked_chance:
				is_parked = true
				vehicle_key = _choose(PARKED_VEHICLE_KEYS)
				world_speed = 0.0
				fallback_height = 96.0
			else:
				vehicle_key = _choose_weighted({
					"vendor_tricycle": 46.0,
					"motorcycle": 46.0,
					"jeepney": 4.0,
					"sedan": 4.0,
				})
				min_world_speed = minf(shoulder_vehicle_min_speed, shoulder_vehicle_max_speed)
				max_world_speed = maxf(shoulder_vehicle_min_speed, shoulder_vehicle_max_speed)
				fallback_height = 90.0

	if not is_parked:
		var speed_range := _vehicle_speed_range_for_spawn_side(min_world_speed, max_world_speed, spawn_side)
		min_world_speed = speed_range.x
		max_world_speed = speed_range.y
		world_speed = rng.randf_range(min_world_speed, max_world_speed)

	if world_speed > 0.0 and lane_index in [1, 2]:
		is_busy_car = _is_post_day_seven_traffic_ramp() and rng.randf() < _get_post_day_busy_car_chance(lane_index)

	sprite.texture = VEHICLE_TEXTURES[vehicle_key]
	sprite.centered = true
	sprite.scale = _scale_for_vehicle_in_lane(
		vehicle_key,
		_scale_for_height(sprite.texture, fallback_height),
		lane_index
	)
	_apply_vehicle_shadow(sprite, VEHICLE_HITBOX_INSET)
	_apply_vehicle_headlight(sprite, VEHICLE_HITBOX_INSET)
	sprite.position = Vector2(
		_vehicle_spawn_x(size, spawn_side),
		_sprite_y_for_hitbox_bottom(sprite, _entity_lane_y(lane_index, size, is_parked), VEHICLE_HITBOX_INSET)
	)
	sprite.z_index = _z_for_lane(lane_index, PARKED_VEHICLE_Z_OFFSET if is_parked else 0)
	add_child(sprite)

	active_entities.append({
		"sprite": sprite,
		"lane": lane_index,
		"target_lane": lane_index,
		"vehicle_key": vehicle_key,
		"fallback_height": fallback_height,
		"kind": "traffic",
		"spawn_side": spawn_side,
		"desired_world_speed": world_speed,
		"world_speed": world_speed,
		"min_world_speed": min_world_speed,
		"max_world_speed": max_world_speed,
		"speed_change_timer": _next_vehicle_speed_change_delay(),
		"is_parked": is_parked,
		"is_busy_car": is_busy_car,
		"overtake_speed_timer": 0.0,
		"pending_overtake_speed_boost": false,
		"lane_change_cooldown": rng.randf_range(0.6, 2.0),
		"lane_change_warning_active": false,
	})


func _update_speeder_warning(delta: float) -> void:
	if speeder_warning_label:
		speeder_warning_label.visible = speeder_warning_flash_timer > 0.0
		speeder_warning_flash_timer = maxf(0.0, speeder_warning_flash_timer - delta)

	if not speeder_enabled:
		return

	if speeder_warning_active:
		speeder_warning_timer -= delta
		if speeder_warning_timer <= 0.0:
			if speeder_warning_beeps_remaining > 0:
				_pulse_speeder_warning()
				speeder_warning_beeps_remaining -= 1
				speeder_warning_timer = 0.28
			else:
				speeder_warning_active = false
				if speeder_warning_label:
					speeder_warning_label.visible = false
				_spawn_speeder()
				_reset_speeder_timer()
		return

	speeder_spawn_timer -= delta
	if speeder_spawn_timer <= 0.0:
		speeder_warning_active = true
		speeder_warning_beeps_remaining = 3
		speeder_warning_timer = 0.0


func _update_speeder_lane_change_warning(delta: float) -> void:
	if speeder_lane_change_warning_label:
		speeder_lane_change_warning_label.visible = false

	if not speeder_lane_change_warning_active:
		return

	var lane_to_warn := speeder_lane_change_warning_target_lane if speeder_lane_change_warning_target_lane >= 0 else player_lane
	if speeder_lane_change_warning_label:
		speeder_lane_change_warning_label.position = Vector2(
			player_x + 105.0,
			_lane_y(lane_to_warn, get_viewport_rect().size) - 92.0
		)
		speeder_lane_change_warning_label.visible = speeder_lane_change_warning_beeps_remaining >= 0

	speeder_lane_change_warning_timer -= delta
	if speeder_lane_change_warning_timer > 0.0:
		return

	if speeder_lane_change_warning_beeps_remaining > 0:
		_pulse_speeder_lane_change_warning()
		speeder_lane_change_warning_beeps_remaining -= 1
		speeder_lane_change_warning_timer = 0.28
	else:
		_complete_speeder_lane_change_warning()


func _pulse_speeder_lane_change_warning() -> void:
	if speeder_lane_change_warning_label:
		speeder_lane_change_warning_label.visible = true
		speeder_lane_change_warning_label.modulate = Color(1.0, 0.94, 0.2, 1.0)
		var tween := create_tween()
		tween.tween_property(speeder_lane_change_warning_label, "modulate", Color(1.0, 0.24, 0.12, 1.0), 0.09)
		tween.tween_property(speeder_lane_change_warning_label, "modulate", Color(1.0, 0.94, 0.2, 1.0), 0.09)
	_play_speeder_beep()


func _start_speeder_lane_change_warning(sprite: Sprite2D, target_lane: int) -> void:
	if speeder_lane_change_warning_active and pending_speeder_lane_change_sprite == sprite:
		return

	speeder_lane_change_warning_active = true
	speeder_lane_change_warning_timer = 0.0
	speeder_lane_change_warning_beeps_remaining = 3
	speeder_lane_change_warning_target_lane = target_lane
	pending_speeder_lane_change_sprite = sprite


func _complete_speeder_lane_change_warning() -> void:
	var entity := _find_entity_by_sprite(pending_speeder_lane_change_sprite)
	if not entity.is_empty():
		var target_lane := speeder_lane_change_warning_target_lane
		if _speeder_target_lane_is_safe(entity, target_lane):
			entity["lane"] = target_lane
			entity["target_lane"] = target_lane
			entity["sprite"].z_index = _z_for_lane(target_lane, 2)

	speeder_lane_change_warning_active = false
	speeder_lane_change_warning_timer = 0.0
	speeder_lane_change_warning_beeps_remaining = 0
	speeder_lane_change_warning_target_lane = -1
	pending_speeder_lane_change_sprite = null
	if speeder_lane_change_warning_label:
		speeder_lane_change_warning_label.visible = false


func _pulse_speeder_warning() -> void:
	speeder_warning_flash_timer = 0.18
	if speeder_warning_label:
		speeder_warning_label.visible = true
		speeder_warning_label.modulate = Color(1.0, 0.94, 0.2, 1.0)
		var tween := create_tween()
		tween.tween_property(speeder_warning_label, "modulate", Color(1.0, 0.24, 0.12, 1.0), 0.09)
		tween.tween_property(speeder_warning_label, "modulate", Color(1.0, 0.94, 0.2, 1.0), 0.09)
	_play_speeder_beep()


func _play_speeder_beep() -> void:
	audio_manager.play_speeder_beep()


func _reset_speeder_timer() -> void:
	speeder_warning_active = false
	speeder_warning_beeps_remaining = 0
	speeder_warning_timer = 0.0
	speeder_warning_flash_timer = 0.0
	speeder_spawn_timer = rng.randf_range(speeder_spawn_min_delay, speeder_spawn_max_delay)
	if speeder_warning_label:
		speeder_warning_label.visible = false


func _spawn_speeder() -> void:
	var size := get_viewport_rect().size
	var lane_index := 1
	var vehicle_key := _choose(["sedan", "gray_sedan"])
	var min_world_speed := minf(speeder_vehicle_min_speed, speeder_vehicle_max_speed)
	var max_world_speed := maxf(speeder_vehicle_min_speed, speeder_vehicle_max_speed)
	var world_speed := rng.randf_range(min_world_speed, max_world_speed)
	var sprite := Sprite2D.new()
	sprite.texture = VEHICLE_TEXTURES[vehicle_key]
	sprite.centered = true
	sprite.scale = _scale_for_vehicle_in_lane(
		vehicle_key,
		_scale_for_height(sprite.texture, 92.0),
		lane_index
	)
	_apply_vehicle_shadow(sprite, VEHICLE_HITBOX_INSET)
	_apply_vehicle_headlight(sprite, VEHICLE_HITBOX_INSET)
	sprite.position = Vector2(
		-220.0,
		_sprite_y_for_hitbox_bottom(sprite, _lane_y(lane_index, size), VEHICLE_HITBOX_INSET)
	)
	sprite.z_index = _z_for_lane(lane_index, 2)
	add_child(sprite)

	active_entities.append({
		"sprite": sprite,
		"lane": lane_index,
		"target_lane": lane_index,
		"vehicle_key": vehicle_key,
		"fallback_height": 92.0,
		"kind": "speeder",
		"desired_world_speed": world_speed,
		"world_speed": world_speed,
		"min_world_speed": min_world_speed,
		"max_world_speed": max_world_speed,
		"speed_change_timer": _next_vehicle_speed_change_delay(),
		"lane_change_cooldown": 0.0,
	})


func _update_random_lane_changes(delta: float) -> void:
	var post_day_seven_traffic_ramp := _is_post_day_seven_traffic_ramp()
	if not npc_random_lane_change_enabled and not post_day_seven_traffic_ramp:
		return

	for entity in active_entities:
		if bool(entity.get("lane_change_warning_active", false)):
			continue
		if entity.get("kind", "traffic") != "traffic":
			continue
		if float(entity.get("world_speed", 0.0)) <= 0.0:
			continue

		var lane_index := int(entity["lane"])
		if lane_index != 1 and lane_index != 2:
			continue

		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		if float(entity["lane_change_cooldown"]) > 0.0:
			continue

		var is_busy_car := bool(entity.get("is_busy_car", false))
		if not npc_random_lane_change_enabled and not is_busy_car:
			continue

		var lane_change_chance := npc_lane_change_chance_per_second if npc_random_lane_change_enabled else 0.0
		if is_busy_car:
			lane_change_chance = maxf(lane_change_chance, POST_DAY_SEVEN_BUSY_CAR_LANE_CHANGE_CHANCE_PER_SECOND)

		if rng.randf() > lane_change_chance * delta:
			continue

		var target_lane := 2 if lane_index == 1 else 1
		if _lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
			_start_lane_change_warning(entity, target_lane)

		entity["lane_change_cooldown"] = rng.randf_range(1.2, 3.5)


func _update_vehicle_speeds(delta: float) -> void:
	VehicleBehaviors.update_speed_targets(
		active_entities,
		delta,
		rng,
		vehicle_speed_change_min_delay,
		vehicle_speed_change_max_delay,
		vehicle_speed_acceleration
	)


func _next_vehicle_speed_change_delay() -> float:
	return rng.randf_range(
		minf(vehicle_speed_change_min_delay, vehicle_speed_change_max_delay),
		maxf(vehicle_speed_change_min_delay, vehicle_speed_change_max_delay)
	)


func _vehicle_spawn_x(size: Vector2, spawn_side: String) -> float:
	if stage_traffic == "busy":
		return BusyTrafficBehavior.spawn_x(size, spawn_side, rng, player_speed, player_max_speed)

	return size.x + rng.randf_range(SPAWN_MIN_OFFSET, SPAWN_MAX_OFFSET)


func _player_speed_ratio() -> float:
	return clampf(player_speed / maxf(1.0, player_max_speed), 0.0, 1.0)


func _vehicle_speed_range_for_spawn_side(min_speed: float, max_speed: float, spawn_side: String) -> Vector2:
	if stage_traffic == "busy":
		return BusyTrafficBehavior.speed_range_for_spawn_side(min_speed, max_speed, spawn_side, player_speed)
	return Vector2(min_speed, max_speed)


func _update_lane_change_warnings(delta: float) -> void:
	for entity in active_entities:
		if not bool(entity.get("lane_change_warning_active", false)):
			continue

		entity["lane_change_warning_timer"] = float(entity.get("lane_change_warning_timer", 0.0)) - delta
		if float(entity["lane_change_warning_timer"]) > 0.0:
			continue

		var pulses_remaining := int(entity.get("lane_change_warning_pulses_remaining", 0))
		if pulses_remaining > 0:
			_pulse_entity_lane_warning(entity)
			entity["lane_change_warning_pulses_remaining"] = pulses_remaining - 1
			entity["lane_change_warning_timer"] = NPC_LANE_CHANGE_WARNING_INTERVAL
		else:
			_finish_warned_lane_change(entity)


func _start_lane_change_warning(entity: Dictionary, target_lane: int) -> void:
	entity["lane_change_warning_active"] = true
	entity["lane_change_warning_target_lane"] = target_lane
	entity["lane_change_warning_pulses_remaining"] = NPC_LANE_CHANGE_WARNING_PULSES
	entity["lane_change_warning_timer"] = 0.0
	var warning_label := _get_entity_lane_warning_label(entity)
	warning_label.visible = false


func _pulse_entity_lane_warning(entity: Dictionary) -> void:
	var warning_label := _get_entity_lane_warning_label(entity)
	_position_entity_lane_warning(entity, warning_label)
	warning_label.visible = true
	warning_label.modulate = Color(1.0, 0.94, 0.2, 1.0)

	var tween := create_tween()
	tween.tween_property(warning_label, "modulate", Color(1.0, 0.2, 0.12, 1.0), 0.08)
	tween.tween_property(warning_label, "modulate", Color(1.0, 0.94, 0.2, 0.0), 0.1)
	tween.tween_callback(Callable(warning_label, "hide"))
	_play_speeder_beep()


func _finish_warned_lane_change(entity: Dictionary) -> void:
	var target_lane := int(entity.get("lane_change_warning_target_lane", entity["lane"]))
	var warning_label := _get_entity_lane_warning_label(entity)
	warning_label.visible = false
	entity["lane_change_warning_active"] = false

	if _target_lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
		entity["lane"] = target_lane
		entity["target_lane"] = target_lane
		entity["sprite"].z_index = _z_for_lane(target_lane)
		if bool(entity.get("pending_overtake_speed_boost", false)):
			_boost_vehicle_for_overtake(entity)

	entity["pending_overtake_speed_boost"] = false
	entity["lane_change_cooldown"] = rng.randf_range(1.2, 3.5)


func _is_post_day_seven_traffic_ramp() -> bool:
	return use_player_state_stage_sequence and PlayerState.get_current_day() > 7


func _get_post_day_busy_car_chance(lane_index: int) -> float:
	match lane_index:
		1:
			return POST_DAY_SEVEN_BUSY_CAR_CHANCE_MAIN
		2:
			return POST_DAY_SEVEN_BUSY_CAR_CHANCE_SHOULDER
	return 0.0


func _get_entity_lane_warning_label(entity: Dictionary) -> Label:
	var sprite: Sprite2D = entity["sprite"]
	var warning_label := sprite.get_node_or_null("LaneChangeWarning") as Label
	if warning_label:
		return warning_label

	warning_label = _make_label(42, Color(1.0, 0.94, 0.2, 1.0), 6)
	warning_label.name = "LaneChangeWarning"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.text = "!"
	warning_label.size = Vector2(80.0, 70.0)
	warning_label.z_as_relative = false
	warning_label.z_index = HEADLIGHT_Z_INDEX + 10
	warning_label.visible = false
	sprite.add_child(warning_label)
	_position_entity_lane_warning(entity, warning_label)
	return warning_label


func _position_entity_lane_warning(entity: Dictionary, warning_label: Label) -> void:
	var sprite: Sprite2D = entity["sprite"]
	var local_rect := _local_hitbox_rect(sprite, VEHICLE_HITBOX_INSET)
	var safe_scale := Vector2(
		1.0 / maxf(0.001, absf(sprite.scale.x)),
		1.0 / maxf(0.001, absf(sprite.scale.y))
	)
	warning_label.scale = safe_scale
	warning_label.position = Vector2(
		-warning_label.size.x * 0.5 * safe_scale.x,
		local_rect.position.y - warning_label.size.y * safe_scale.y - 8.0
	)


func _update_speeder_ai() -> void:
	for entity in active_entities:
		if entity.get("kind", "traffic") != "speeder":
			continue

		var lane_index := int(entity["lane"])
		if _speeder_needs_lane_change(entity, lane_index):
			var changed_lane := false
			for avoid_target_lane in VehicleBehaviors.speeder_overtake_lane_order(lane_index):
				if _try_set_speeder_target_lane(entity, avoid_target_lane):
					changed_lane = true
					break
			if not changed_lane:
				_slow_speeder_near_player(entity)
			continue

		if lane_index != 1:
			_try_set_speeder_target_lane(entity, 1)


func _update_busy_vehicle_ai(delta: float) -> void:
	if stage_traffic != "busy":
		return

	for entity in active_entities:
		if entity.get("kind", "traffic") != "traffic":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			continue

		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		var lane_index := int(entity["lane"])
		var cooldown_ready := float(entity["lane_change_cooldown"]) <= 0.0
		if cooldown_ready and BusyTrafficBehavior.is_left_car(entity) and lane_index == 0:
			if _try_warn_vehicle_lane_change(entity, 1):
				continue

		if not _vehicle_needs_lane_change(entity, lane_index):
			continue

		var changed_lane := false
		for target_lane in BusyTrafficBehavior.overtake_lane_order(lane_index):
			if _try_warn_vehicle_lane_change(entity, target_lane):
				entity["pending_overtake_speed_boost"] = true
				changed_lane = true
				break
		if not changed_lane:
			_slow_vehicle_for_front_car(entity, lane_index)


func _update_vehicle_overtake_ai(delta: float) -> void:
	for entity in active_entities:
		if entity.get("kind", "traffic") != "traffic":
			continue
		if bool(entity.get("is_parked", false)):
			continue
		if bool(entity.get("lane_change_warning_active", false)):
			continue
		if float(entity.get("world_speed", 0.0)) <= 0.0:
			continue

		var lane_index := int(entity["lane"])
		entity["lane_change_cooldown"] = maxf(0.0, float(entity.get("lane_change_cooldown", 0.0)) - delta)
		if float(entity["lane_change_cooldown"]) > 0.0:
			continue

		if lane_index == 0:
			_try_warn_vehicle_lane_change(entity, 1)
			continue
		if lane_index != 1 and lane_index != 2:
			continue
		if not _vehicle_needs_lane_change(entity, lane_index):
			continue

		if rng.randf() > npc_overtake_chance_per_second * delta:
			continue

		for target_lane in VehicleBehaviors.overtake_lane_order(lane_index):
			if _try_warn_overtake_lane_change(entity, target_lane):
				break


func _vehicle_needs_lane_change(vehicle: Dictionary, lane_index: int) -> bool:
	return VehicleBehaviors.vehicle_needs_lane_change(
		vehicle,
		lane_index,
		active_entities,
		npc_collision_lookahead,
		npc_follow_gap,
		VEHICLE_HITBOX_INSET,
		Callable(self, "_collision_rect")
	)


func _try_warn_overtake_lane_change(entity: Dictionary, target_lane: int) -> bool:
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not _target_lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
		return false

	entity["pending_overtake_speed_boost"] = true
	_start_lane_change_warning(entity, target_lane)
	return true


func _try_warn_vehicle_lane_change(entity: Dictionary, target_lane: int) -> bool:
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not _target_lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
		return false

	_start_lane_change_warning(entity, target_lane)
	return true


func _boost_vehicle_for_overtake(entity: Dictionary) -> void:
	VehicleBehaviors.boost_for_overtake(entity, npc_overtake_speed_boost, npc_overtake_speed_boost_seconds)


func _slow_vehicle_for_front_car(entity: Dictionary, lane_index: int) -> void:
	var front_speed := VehicleBehaviors.front_vehicle_speed(
		entity,
		lane_index,
		active_entities,
		npc_follow_gap,
		VEHICLE_HITBOX_INSET,
		Callable(self, "_collision_rect")
	)
	if front_speed >= 0.0:
		entity["world_speed"] = minf(float(entity.get("world_speed", front_speed)), front_speed)


func _speeder_needs_lane_change(speeder: Dictionary, lane_index: int) -> bool:
	return VehicleBehaviors.speeder_needs_lane_change(
		speeder,
		lane_index,
		active_entities,
		speeder_vehicle_max_speed,
		speeder_safe_gap,
		VEHICLE_HITBOX_INSET,
		Callable(self, "_collision_rect")
	)


func _lane_is_safe_for_entity(moving_entity: Dictionary, target_lane: int, safe_gap: float) -> bool:
	return (
		VehicleBehaviors.is_lane_safe(
			moving_entity,
			target_lane,
			safe_gap,
			active_entities,
			VEHICLE_HITBOX_INSET,
			Callable(self, "_collision_rect")
		)
		and _target_lane_hitboxes_clear(moving_entity, target_lane)
	)


func _target_lane_is_safe_for_entity(moving_entity: Dictionary, target_lane: int, safe_gap: float) -> bool:
	return _lane_is_safe_for_entity(moving_entity, target_lane, safe_gap)


func _target_lane_hitboxes_clear(entity: Dictionary, target_lane: int) -> bool:
	var moving_rect := _projected_entity_collision_rect(entity, target_lane)
	for other_entity in active_entities:
		if other_entity == entity:
			continue
		if int(other_entity.get("lane", -1)) != target_lane:
			continue

		var other_rect := _collision_rect(other_entity["sprite"], VEHICLE_HITBOX_INSET)
		if moving_rect.intersects(other_rect):
			return false
	return true


func _try_set_speeder_target_lane(entity: Dictionary, target_lane: int) -> bool:
	if int(entity.get("lane", target_lane)) == target_lane:
		return false
	if not _speeder_target_lane_is_safe(entity, target_lane):
		return false

	if target_lane == player_lane:
		_start_speeder_lane_change_warning(entity["sprite"], target_lane)
		return true

	if speeder_lane_change_warning_active and pending_speeder_lane_change_sprite != entity["sprite"]:
		return false

	entity["lane"] = target_lane
	entity["target_lane"] = target_lane
	entity["sprite"].z_index = _z_for_lane(target_lane, 2)
	return true


func _speeder_lane_change_safe_gap(target_lane: int) -> float:
	return VehicleBehaviors.speeder_lane_change_safe_gap(target_lane, speeder_safe_gap, speeder_avoid_lookahead)


func _speeder_target_lane_is_safe(entity: Dictionary, target_lane: int) -> bool:
	return (
		_lane_is_safe_for_entity(entity, target_lane, _speeder_lane_change_safe_gap(target_lane))
		and _speeder_has_player_lane_change_clearance(entity, target_lane)
	)


func _projected_entity_collision_rect(entity: Dictionary, lane_index: int) -> Rect2:
	var sprite: Sprite2D = entity["sprite"]
	var original_position := sprite.position
	var original_scale := sprite.scale
	sprite.scale = _target_scale_for_entity(entity, lane_index)
	sprite.position.y = _sprite_y_for_hitbox_bottom(
		sprite,
		_entity_lane_y(lane_index, get_viewport_rect().size, bool(entity.get("is_parked", false))),
		VEHICLE_HITBOX_INSET
	)
	var projected_rect := _collision_rect(sprite, VEHICLE_HITBOX_INSET)
	sprite.position = original_position
	sprite.scale = original_scale
	return projected_rect


func _speeder_has_player_lane_change_clearance(entity: Dictionary, target_lane: int) -> bool:
	if player == null or not is_instance_valid(player):
		return true

	var current_lane := int(entity.get("lane", target_lane))
	if current_lane != player_lane and target_lane != player_lane:
		return true

	var speeder_rect := _collision_rect(entity["sprite"], VEHICLE_HITBOX_INSET)
	var player_rect := _collision_rect(player, PLAYER_HITBOX_INSET)
	var center_gap := absf(speeder_rect.get_center().x - player_rect.get_center().x)
	return center_gap >= SPEEDER_PLAYER_LANE_CHANGE_BUFFER


func _slow_speeder_near_player(entity: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	if int(entity.get("lane", -1)) != player_lane:
		return

	var speeder_rect := _collision_rect(entity["sprite"], VEHICLE_HITBOX_INSET)
	var player_rect := _collision_rect(player, PLAYER_HITBOX_INSET)
	var speeder_is_behind_player := speeder_rect.get_center().x < player_rect.get_center().x
	var center_gap := absf(speeder_rect.get_center().x - player_rect.get_center().x)
	if speeder_is_behind_player and center_gap < SPEEDER_PLAYER_LANE_CHANGE_BUFFER:
		entity["world_speed"] = minf(float(entity.get("world_speed", speeder_vehicle_max_speed)), player_speed)


func _find_entity_by_sprite(sprite: Sprite2D) -> Dictionary:
	if sprite == null:
		return {}

	for entity in active_entities:
		if entity.get("sprite") == sprite:
			return entity
	return {}


func _update_npc_following() -> void:
	VehicleBehaviors.update_npc_following(
		active_entities,
		npc_follow_gap,
		npc_collision_lookahead,
		VEHICLE_HITBOX_INSET,
		Callable(self, "_collision_rect")
	)


func _update_entities(delta: float) -> void:
	var dead_entities := []
	for entity in active_entities:
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var world_speed: float = entity["world_speed"]
		var screen_velocity := 0.0

		screen_velocity = VehicleBehaviors.screen_velocity_for_spawn_side(
			lane_index,
			str(entity.get("kind", "traffic")),
			str(entity.get("spawn_side", "")),
			world_speed,
			player_speed
		)

		sprite.position.x += screen_velocity * delta
		_update_entity_lane_position(entity, delta)
		if sprite.position.x < -260.0 or sprite.position.x > get_viewport_rect().size.x + 520.0:
			dead_entities.append(entity)

	for entity in dead_entities:
		active_entities.erase(entity)
		entity["sprite"].queue_free()


func _update_entity_lane_position(entity: Dictionary, delta: float) -> void:
	var target_lane := int(entity.get("target_lane", entity["lane"]))
	var sprite: Sprite2D = entity["sprite"]
	if bool(entity.get("is_parked", false)):
		sprite.z_index = _z_for_lane(target_lane, PARKED_VEHICLE_Z_OFFSET)
	var target_y := _sprite_y_for_hitbox_bottom(
		sprite,
		_entity_lane_y(target_lane, get_viewport_rect().size, bool(entity.get("is_parked", false))),
		VEHICLE_HITBOX_INSET
	)
	var lerp_speed := speeder_lane_change_lerp_speed if entity.get("kind", "traffic") == "speeder" else npc_lane_change_lerp_speed
	sprite.position.y = lerpf(sprite.position.y, target_y, minf(1.0, delta * lerp_speed))
	sprite.scale = sprite.scale.lerp(_target_scale_for_entity(entity, target_lane), minf(1.0, delta * lerp_speed))


func _target_scale_for_entity(entity: Dictionary, lane_index: int) -> Vector2:
	var sprite: Sprite2D = entity["sprite"]
	var vehicle_key := str(entity.get("vehicle_key", ""))
	var fallback_height := float(entity.get("fallback_height", 92.0))
	return _scale_for_vehicle_in_lane(
		vehicle_key,
		_scale_for_height(sprite.texture, fallback_height),
		lane_index
	)


func _update_player(delta: float, move_forward := false) -> void:
	var target_scale := _scale_for_vehicle_in_lane(
		"player_tricycle",
		_scale_for_height(PLAYER_TEXTURE, min(116.0, get_viewport_rect().size.y * 0.155)),
		player_lane
	)
	player.scale = player.scale.lerp(target_scale, minf(1.0, delta * player_perspective_lerp_speed))
	_apply_vehicle_shadow(player, PLAYER_HITBOX_INSET)
	_apply_vehicle_headlight(player, PLAYER_HITBOX_INSET)

	var target_y := _sprite_y_for_hitbox_bottom(player, _lane_y(player_lane, get_viewport_rect().size), PLAYER_HITBOX_INSET)
	var wiggle_amount := PlayerVehicleBehavior.wiggle_amount(
		game_state,
		player_is_stage_clear_exiting,
		player_wiggle_stop_speed,
		stage_clear_player_exit_speed,
		player_speed,
		player_wiggle_intensity_x
	)
	PlayerVehicleBehavior.apply_motion(
		player,
		delta,
		move_forward,
		player_x,
		target_y,
		stage_clear_player_exit_speed,
		player_lane_lerp_speed,
		player_lane_lerp_x,
		player_wiggle_x_frequency,
		player_wiggle_x_pixels,
		player_wiggle_rotation_frequency,
		player_wiggle_rotation_radians,
		wiggle_amount
	)


func _distance_scale() -> float:
	return BASE_DISTANCE_SCALE * player_distance_gain_x


func _update_background() -> void:
	if background_scroller:
		background_scroller.update(distance)


func _update_ui() -> void:
	var speed_kmh := _current_speed_kmh()
	var speed_ratio := float(speed_kmh) / float(SPEEDOMETER_MAX_KMH)
	speedometer.set_values(speed_kmh, speed_ratio, floori(distance), floori(target_distance), time_left)

	if game_state == "playing":
		status_label.text = ""
	else:
		status_label.text = "%s\n%s" % [game_state, end_message]

	if footer_money_label:
		footer_money_label.text = "PhP %d" % PlayerState.money
	if footer_energy_label:
		footer_energy_label.text = "%d/%d" % [PlayerState.energy, PlayerState.max_energy]
	if footer_gas_label:
		footer_gas_label.text = "%d/%d" % [PlayerState.gas, PlayerState.max_gas]
	if time_label:
		time_label.text = "TIME  %04.1f SEC" % time_left
	if distance_progress_fill and distance_progress_bg:
		var distance_ratio := clampf(distance / maxf(1.0, target_distance), 0.0, 1.0)
		distance_progress_fill.position = distance_progress_bg.position
		distance_progress_fill.size = Vector2(distance_progress_bg.size.x * distance_ratio, distance_progress_bg.size.y)
	if distance_label:
		distance_label.text = "DISTANCE  %04dM / %04dM" % [floori(distance), floori(target_distance)]

	if stage_label:
		stage_label.text = "DAY %d\n%s" % [PlayerState.get_current_day(), stage_type.to_upper()]

	if weekly_goal_label:
		weekly_goal_label.text = "WEEKLY GOAL: PhP %d" % PlayerState.get_current_weekly_goal()

	if debt_goal_label:
		debt_goal_label.text = "Debt Remaining: PhP %d\n%s" % [
			PlayerState.get_total_debt_goal(),
			PlayerState.get_debt_due_text(),
		]


func _current_speed_kmh() -> int:
	return clampi(roundi(player_speed / SPEEDOMETER_REFERENCE_MAX_SPEED * SPEEDOMETER_BASE_MAX_KMH), 0, SPEEDOMETER_MAX_KMH)


func _check_collisions() -> void:
	var player_rect := _collision_rect(player, PLAYER_HITBOX_INSET)
	for entity in active_entities:
		if entity["lane"] != player_lane:
			continue
		if _is_safe_low_speed_parked_contact(entity):
			continue

		var entity_rect := _collision_rect(entity["sprite"], VEHICLE_HITBOX_INSET)
		if player_rect.intersects(entity_rect):
			_end_game("CRASH", "Collision in the %s lane. Space/R to retry." % LANE_NAMES[entity["lane"]])
			return


func _is_safe_low_speed_parked_contact(entity: Dictionary) -> bool:
	return bool(entity.get("is_parked", false)) and _current_speed_kmh() < PARKED_COLLISION_MIN_KMH


func _end_game(title: String, detail: String) -> void:
	if game_state != "playing":
		return
	if title == "CRASH":
		_play_crash_sfx()
	if title == "CRASH" or title == "TIME OUT":
		PlayerState.record_stage_failure()
	if (title == "CRASH" or title == "TIME OUT") and PlayerState.energy <= 0:
		game_state = "GAME OVER"
		end_message = "Out of energy. Press any key to return to menu."
	else:
		game_state = title
		end_message = detail
	if speeder_warning_label:
		speeder_warning_label.visible = false
	speeder_warning_active = false
	if game_state == "YOU MADE IT":
		player_is_stage_clear_exiting = true
		_store_stage_result()
		_remove_vehicles_behind_player()


func _play_crash_sfx() -> void:
	audio_manager.play_crash_sfx()


func _try_retry_stage() -> void:
	if use_player_state_stage_sequence and not PlayerState.spend_energy(1):
		end_message = "No energy left. Visit the store or reset progress."
		return
	_reset_game()


func _reset_game() -> void:
	_apply_stage_profile()
	_apply_player_upgrades()
	for entity in active_entities:
		entity["sprite"].queue_free()
	active_entities.clear()
	spawn_timers = [0.4, 0.8, 1.2]
	player_lane = 1
	player_speed = player_start_speed
	distance = 0.0
	time_left = time_limit
	overtime_seconds = 0.0
	game_state = "playing"
	end_message = ""
	player_is_stage_clear_exiting = false
	stage_clear_transition_started = false
	stage_clear_fade_time = 0.0
	_reset_speeder_timer()
	if fade_rect:
		fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_layout_scene()


func _remove_vehicles_behind_player() -> void:
	var player_rect := _collision_rect(player, PLAYER_HITBOX_INSET)
	var dead_entities := []
	for entity in active_entities:
		var entity_rect := _collision_rect(entity["sprite"], VEHICLE_HITBOX_INSET)
		if entity_rect.position.x + entity_rect.size.x < player_rect.position.x:
			dead_entities.append(entity)

	for entity in dead_entities:
		active_entities.erase(entity)
		entity["sprite"].queue_free()


func _update_stage_clear_entities(delta: float) -> void:
	var dead_entities := []
	var viewport_width := get_viewport_rect().size.x

	for entity in active_entities:
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var world_speed: float = maxf(stage_clear_min_exit_speed, absf(entity["world_speed"]))
		var screen_velocity := world_speed

		if lane_index == 0:
			screen_velocity = -world_speed

		sprite.position.x += screen_velocity * delta

		if lane_index == 0 and sprite.position.x < -260.0:
			dead_entities.append(entity)
		elif lane_index != 0 and sprite.position.x > viewport_width + 520.0:
			dead_entities.append(entity)

	for entity in dead_entities:
		active_entities.erase(entity)
		entity["sprite"].queue_free()


func _update_stage_clear_transition(delta: float) -> void:
	if not stage_clear_transition_started and player.position.x > get_viewport_rect().size.x + 160.0:
		stage_clear_transition_started = true
		stage_clear_fade_time = 0.0

	if not stage_clear_transition_started:
		return

	stage_clear_fade_time += delta
	var fade_ratio := clampf(stage_clear_fade_time / stage_clear_fade_seconds, 0.0, 1.0)
	fade_rect.color = Color(0.0, 0.0, 0.0, fade_ratio)

	if fade_ratio >= 1.0:
		_go_to_profit_screen()


func _go_to_profit_screen() -> void:
	var story_payload := GameEconomyManager.stage_complete_story_payload(stage_type, stage_difficulty, stage_time_of_day, stage_traffic)
	if not story_payload.is_empty():
		get_tree().change_scene_to_file(STORY_SCENE)
		return

	get_tree().change_scene_to_file(STAGE_RESULTS_SCENE)


func _store_stage_result() -> void:
	GameEconomyManager.store_stage_result(
		stage_type,
		stage_difficulty,
		stage_time_of_day,
		stage_traffic,
		distance,
		target_distance,
		fare_php_per_meter,
		overtime_seconds,
		overtime_fare_penalty_php_per_second,
		time_left,
		time_bonus_php_per_second
	)


func _change_lane(direction: int) -> void:
	if game_state != "playing":
		return
	player_lane = PlayerVehicleBehavior.changed_lane(player_lane, direction)
	player.z_index = _z_for_lane(player_lane, 1)


func _collision_rect(sprite: Sprite2D, inset: Vector4) -> Rect2:
	var local_rect := _local_hitbox_rect(sprite, inset)
	var scaled_position := Vector2(
		local_rect.position.x * sprite.scale.x,
		local_rect.position.y * sprite.scale.y
	)
	var scaled_size := Vector2(
		local_rect.size.x * absf(sprite.scale.x),
		local_rect.size.y * absf(sprite.scale.y)
	)
	return Rect2(sprite.global_position + scaled_position, scaled_size)


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

	if sprite.flip_v:
		var mirrored_top := texture_size.y - bottom
		bottom = texture_size.y - top
		top = mirrored_top

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
	var shadow := sprite.get_node_or_null("Shadow") as Polygon2D
	if shadow == null:
		shadow = Polygon2D.new()
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


func _apply_vehicle_headlight(sprite: Sprite2D, inset: Vector4) -> void:
	var cone := sprite.get_node_or_null("HeadlightCone") as Sprite2D
	if cone == null:
		cone = Sprite2D.new()
		cone.name = "HeadlightCone"
		cone.texture = headlight_cone_texture
		cone.centered = false
		cone.z_as_relative = false
		cone.z_index = HEADLIGHT_Z_INDEX
		var headlight_material := CanvasItemMaterial.new()
		headlight_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		cone.material = headlight_material
		sprite.add_child(cone)

	if headlight_cone_texture == null:
		return

	var alpha := _current_headlight_alpha()
	cone.visible = stage_time_of_day == "night" and alpha > 0.0 and game_state != "CRASH" and game_state != "TIME OUT" and game_state != "GAME OVER"
	if not cone.visible:
		return

	var local_rect := _local_hitbox_rect(sprite, inset)
	var cone_width := maxf(74.0, local_rect.size.x * headlight_cone_length_x)
	var cone_height := maxf(26.0, local_rect.size.y * headlight_cone_height_x)
	var scale_x := cone_width / headlight_cone_texture.get_width()
	var scale_y := cone_height / headlight_cone_texture.get_height()
	var front_x := local_rect.position.x + local_rect.size.x if not sprite.flip_h else local_rect.position.x
	var cone_y := local_rect.position.y + local_rect.size.y * 0.46 - cone_height * 0.5

	cone.modulate = Color(1.0, 0.96, 0.82, alpha)
	cone.position = Vector2(front_x, cone_y)
	cone.scale = Vector2(scale_x if not sprite.flip_h else -scale_x, scale_y)


func _scale_for_height(texture: Texture2D, target_height: float) -> Vector2:
	var scale_value := target_height / texture.get_height()
	return Vector2(scale_value, scale_value)


func _reference_scale_for_vehicle(vehicle_key: String, fallback: Vector2) -> Vector2:
	var path: String = VEHICLE_REFERENCE_PATHS.get(vehicle_key, "")
	if path.is_empty():
		return fallback

	var reference := get_node_or_null(path)
	if reference == null:
		return fallback

	var viewport_height_ratio := get_viewport_rect().size.y / 720.0
	return reference.scale * viewport_height_ratio


func _scale_for_vehicle_in_lane(vehicle_key: String, fallback: Vector2, lane_index: int) -> Vector2:
	return _reference_scale_for_vehicle(vehicle_key, fallback) * _perspective_scale_for_lane(lane_index)


func _perspective_scale_for_lane(lane_index: int) -> float:
	match lane_index:
		0:
			return incoming_lane_scale
		1:
			return main_lane_scale
		2:
			return shoulder_lane_scale
	return 1.0


func _choose(options: Array) -> String:
	return options[rng.randi_range(0, options.size() - 1)]


func _choose_weighted(weights: Dictionary) -> String:
	var total_weight := 0.0
	for weight in weights.values():
		total_weight += float(weight)

	var roll := rng.randf_range(0.0, total_weight)
	var running_total := 0.0
	for key in weights.keys():
		running_total += float(weights[key])
		if roll <= running_total:
			return key

	return weights.keys()[0]


func _road_top(size: Vector2) -> float:
	return size.y * 0.54


func _lane_height(size: Vector2) -> float:
	return size.y * 0.09


func _lane_gap() -> float:
	return 0.0


func _lane_y(lane_index: int, size: Vector2) -> float:
	var guide_names := ["IncomingSnapLine", "MainSnapLine", "ShoulderSnapLine"]
	var guide := get_node_or_null("EditorPreview/LaneSnapLines/%s" % guide_names[lane_index])
	if guide:
		return guide.position.y * size.y / 720.0

	var fallback_lane_positions := [0.585, 0.675, 0.805]
	return size.y * fallback_lane_positions[lane_index]


func _entity_lane_y(lane_index: int, size: Vector2, is_parked := false) -> float:
	var lane_y := _lane_y(lane_index, size)
	if is_parked and lane_index == 2:
		lane_y += PARKED_VEHICLE_Y_OFFSET
	return lane_y


func _z_for_lane(lane_index: int, offset := 0) -> int:
	return ROAD_ACTOR_Z_BASE + lane_index * ROAD_ACTOR_Z_STEP + offset
