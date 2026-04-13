extends Node2D

const BG_TEXTURE := preload("res://assets/background/bg1_loop.png")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const SPEEDOMETER_GAUGE := preload("res://scripts/speedometer_gauge.gd")
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
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
const FIRST_STAGE_TYPE := "easy-morning-chill"
const DEFAULT_STAGE_PROFILE := {
	"target_distance": 1000.0,
	"time_limit": 45.0,
	"player_x": 220.0,
	"player_start_speed": 320.0,
	"player_min_cruise_speed": 180.0,
	"player_max_speed": 560.0,
	"player_acceleration": 230.0,
	"player_acceleration_x": 1.0,
	"bottom_lane_player_acceleration_x": 1.0,
	"player_brake_deceleration": 230.0,
	"player_brake_x": 1.0,
	"player_coast_deceleration": 85.0,
	"player_coast_x": 1.0,
	"player_lane_lerp_speed": 12.0,
	"player_lane_lerp_x": 1.0,
	"player_distance_gain_x": 1.0,
	"player_wiggle_stop_speed": 45.0,
	"player_wiggle_x_pixels": 2.0,
	"player_wiggle_x_frequency": 0.012,
	"player_wiggle_rotation_radians": 0.012,
	"player_wiggle_rotation_frequency": 0.018,
	"player_wiggle_intensity_x": 1.0,
	"incoming_spawn_min_delay": 18.0,
	"incoming_spawn_max_delay": 28.0,
	"main_spawn_min_delay": 6.0,
	"main_spawn_max_delay": 9.5,
	"shoulder_spawn_min_delay": 18.0,
	"shoulder_spawn_max_delay": 30.0,
	"spawn_delay_progress_reduction": 0.0,
	"incoming_vehicle_min_speed": 360.0,
	"incoming_vehicle_max_speed": 610.0,
	"main_vehicle_min_speed": 190.0,
	"main_vehicle_max_speed": 280.0,
	"shoulder_vehicle_min_speed": 35.0,
	"shoulder_vehicle_max_speed": 95.0,
	"shoulder_parked_chance": 0.55,
	"npc_follow_gap": 46.0,
	"npc_collision_lookahead": 1.1,
	"stage_clear_min_exit_speed": 180.0,
	"stage_clear_player_exit_speed": 120.0,
	"stage_clear_fade_seconds": 0.9,
	"fare_php_per_meter": 0.08,
	"time_bonus_php_per_second": 2.0,
	"incoming_lane_scale": 0.78,
	"main_lane_scale": 1.0,
	"shoulder_lane_scale": 1.18,
	"player_perspective_lerp_speed": 9.0,
	"npc_random_lane_change_enabled": false,
	"npc_lane_change_chance_per_second": 0.0,
	"npc_lane_change_lerp_speed": 5.0,
	"speeder_enabled": false,
	"speeder_spawn_min_delay": 9.0,
	"speeder_spawn_max_delay": 14.0,
	"speeder_vehicle_speed": 780.0,
	"speeder_lane_change_lerp_speed": 8.0,
	"speeder_avoid_lookahead": 360.0,
	"speeder_safe_gap": 150.0,
}
const DIFFICULTY_PROFILES := {
	"easy": {},
	"medium": {
		"target_distance": 1500.0,
		"time_limit": 58.0,
		"spawn_delay_progress_reduction": 0.15,
		"fare_php_per_meter": 0.10,
	},
	"long": {
		"target_distance": 2300.0,
		"time_limit": 82.0,
		"spawn_delay_progress_reduction": 0.25,
		"fare_php_per_meter": 0.12,
	},
}
const TIME_PROFILES := {
	"morning": {},
	"noon": {
		"player_coast_deceleration": 96.0,
		"incoming_vehicle_min_speed": 390.0,
		"incoming_vehicle_max_speed": 650.0,
	},
	"night": {
		"player_max_speed": 600.0,
		"incoming_vehicle_min_speed": 420.0,
		"incoming_vehicle_max_speed": 690.0,
		"time_bonus_php_per_second": 2.5,
	},
}
const TRAFFIC_PROFILES := {
	"chill": {},
	"normal": {
		"incoming_spawn_min_delay": 13.0,
		"incoming_spawn_max_delay": 20.0,
		"main_spawn_min_delay": 4.5,
		"main_spawn_max_delay": 7.0,
		"shoulder_spawn_min_delay": 14.0,
		"shoulder_spawn_max_delay": 22.0,
		"spawn_delay_progress_reduction": 0.15,
	},
	"traffic-jam": {
		"incoming_spawn_min_delay": 13.0,
		"incoming_spawn_max_delay": 20.0,
		"main_spawn_min_delay": 1.4,
		"main_spawn_max_delay": 2.4,
		"shoulder_spawn_min_delay": 11.0,
		"shoulder_spawn_max_delay": 18.0,
		"main_vehicle_min_speed": 105.0,
		"main_vehicle_max_speed": 180.0,
		"npc_follow_gap": 36.0,
		"shoulder_parked_chance": 0.65,
	},
	"busy": {
		"incoming_spawn_min_delay": 5.0,
		"incoming_spawn_max_delay": 8.0,
		"main_spawn_min_delay": 2.8,
		"main_spawn_max_delay": 4.6,
		"shoulder_spawn_min_delay": 5.5,
		"shoulder_spawn_max_delay": 9.0,
		"spawn_delay_progress_reduction": 0.25,
		"npc_random_lane_change_enabled": true,
		"npc_lane_change_chance_per_second": 0.12,
	},
	"speeders": {
		"incoming_spawn_min_delay": 11.0,
		"incoming_spawn_max_delay": 18.0,
		"main_spawn_min_delay": 5.0,
		"main_spawn_max_delay": 7.5,
		"shoulder_spawn_min_delay": 13.0,
		"shoulder_spawn_max_delay": 22.0,
		"speeder_enabled": true,
		"speeder_spawn_min_delay": 7.5,
		"speeder_spawn_max_delay": 12.0,
	},
}
const BACKGROUND_PROFILES := {
	"barangay-streets": {
		"bottom_lane_player_acceleration_x": 0.45,
	}
}

@export_group("Stage")
@export_enum(
	"easy-morning-chill",
	"easy-morning-normal",
	"easy-morning-traffic-jam",
	"easy-morning-busy",
	"easy-morning-speeders",
	"easy-noon-chill",
	"easy-noon-normal",
	"easy-noon-traffic-jam",
	"easy-noon-busy",
	"easy-noon-speeders",
	"easy-night-chill",
	"easy-night-normal",
	"easy-night-traffic-jam",
	"easy-night-busy",
	"easy-night-speeders",
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
) var stage_type := "easy-morning-chill"
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
@export_range(0.0, 30.0, 0.25) var player_lane_lerp_speed := 12.0
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
@export_range(0.0, 1.0, 0.05) var shoulder_parked_chance := 0.55
@export_range(0.0, 240.0, 5.0) var npc_follow_gap := 46.0
@export_range(0.0, 4.0, 0.05) var npc_collision_lookahead := 1.1
@export var npc_random_lane_change_enabled := false
@export_range(0.0, 2.0, 0.01) var npc_lane_change_chance_per_second := 0.0
@export_range(1.0, 20.0, 0.5) var npc_lane_change_lerp_speed := 5.0
@export_range(0.0, 600.0, 5.0) var stage_clear_min_exit_speed := 180.0
@export_range(0.0, 600.0, 5.0) var stage_clear_player_exit_speed := 120.0
@export_range(0.1, 5.0, 0.05) var stage_clear_fade_seconds := 0.9

@export_group("Speeders")
@export var speeder_enabled := false
@export_range(1.0, 60.0, 0.5) var speeder_spawn_min_delay := 9.0
@export_range(1.0, 60.0, 0.5) var speeder_spawn_max_delay := 14.0
@export_range(100.0, 1400.0, 10.0) var speeder_vehicle_speed := 780.0
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
var background_layer: Node2D
var bg_a: Sprite2D
var bg_b: Sprite2D
var bg_width := 1280.0
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
var help_label: Label
var footer_stats_label: Label
var status_label: Label
var stage_label: Label
var speeder_warning_label: Label
var speeder_beep_player: AudioStreamPlayer
var fade_rect: ColorRect
var texture_hitbox_cache := {}
var stage_clear_transition_started := false
var stage_clear_fade_time := 0.0
var stage_difficulty := "easy"
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


func _ready() -> void:
	_hide_editor_preview()
	rng.randomize()
	if use_player_state_stage_sequence:
		stage_type = PlayerState.get_current_stage_type()
	_apply_stage_profile()
	_apply_player_upgrades()
	_reset_speeder_timer()
	time_left = time_limit
	overtime_seconds = 0.0
	player_speed = player_start_speed
	headlight_cone_texture = _make_headlight_cone_texture()
	_create_background()
	_create_player()
	_create_time_filter()
	_create_noon_glow()
	_create_night_visibility_mask()
	_create_ui()
	_layout_scene()
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

	var profile: Dictionary = DEFAULT_STAGE_PROFILE.duplicate()
	profile.merge(DIFFICULTY_PROFILES.get(stage_difficulty, {}), true)
	profile.merge(TIME_PROFILES.get(stage_time_of_day, {}), true)
	profile.merge(TRAFFIC_PROFILES.get(stage_traffic, {}), true)
	profile.merge(BACKGROUND_PROFILES.get(background_type, {}), true)

	for setting_name in profile.keys():
		set(setting_name, profile[setting_name])

	_apply_hidden_special_modifiers()


func _parse_stage_type(type_name: String) -> Dictionary:
	var parts := type_name.split("-")
	if parts.size() < 3:
		return {
			"difficulty": "easy",
			"time": "morning",
			"traffic": "chill",
		}

	var traffic_name := ""
	for index in range(2, parts.size()):
		if not traffic_name.is_empty():
			traffic_name += "-"
		traffic_name += parts[index]

	if not DIFFICULTY_PROFILES.has(parts[0]):
		parts[0] = "easy"
	if not TIME_PROFILES.has(parts[1]):
		parts[1] = "morning"
	if not TRAFFIC_PROFILES.has(traffic_name):
		traffic_name = "chill"

	return {
		"difficulty": parts[0],
		"time": parts[1],
		"traffic": traffic_name,
	}


func _apply_player_upgrades() -> void:
	var engine_level := PlayerState.get_upgrade_level("engine_tune")
	var brakes_level := PlayerState.get_upgrade_level("brake_kit")
	var tires_level := PlayerState.get_upgrade_level("tire_grip")

	player_acceleration_x *= 1.0 + engine_level * 0.08
	player_max_speed *= 1.0 + engine_level * 0.04
	player_brake_x *= 1.0 + brakes_level * 0.10
	player_lane_lerp_x *= 1.0 + tires_level * 0.08


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
				"lane_weave_x": rng.randf_range(0.88, 1.35),
				"close_call_x": rng.randf_range(0.92, 1.20),
			}
			incoming_spawn_min_delay *= special_mode_hidden_modifiers["busy_density_x"]
			incoming_spawn_max_delay *= special_mode_hidden_modifiers["busy_density_x"]
			main_spawn_min_delay *= special_mode_hidden_modifiers["busy_density_x"]
			main_spawn_max_delay *= special_mode_hidden_modifiers["busy_density_x"]
			shoulder_spawn_min_delay *= special_mode_hidden_modifiers["busy_density_x"]
			shoulder_spawn_max_delay *= special_mode_hidden_modifiers["busy_density_x"]
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
			speeder_vehicle_speed *= special_mode_hidden_modifiers["speeder_speed_x"]
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
	if _is_any_press(event) and game_state == "GAME OVER":
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
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
	if game_state == "playing":
		_handle_speed(delta)
		_update_progress(delta)
		_update_spawns(delta)
		_update_speeder_warning(delta)
		_update_speeder_lane_change_warning(delta)
		_update_lane_change_warnings(delta)
		_update_random_lane_changes(delta)
		_update_speeder_ai()
		_update_npc_following()
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
	pass


func _draw_dashed_lane_line(y: float, width: float) -> void:
	var dash_w := 54.0
	var gap_w := 36.0
	var phase := fmod(distance * 3.2, dash_w + gap_w)
	var x := -dash_w - phase
	while x < width + dash_w:
		draw_rect(Rect2(x, y - 3.0, dash_w, 6.0), Color(1.0, 1.0, 1.0, 0.68))
		x += dash_w + gap_w


func _create_background() -> void:
	background_layer = Node2D.new()
	background_layer.z_index = -100
	add_child(background_layer)

	bg_a = Sprite2D.new()
	bg_a.texture = BG_TEXTURE
	bg_a.centered = false
	background_layer.add_child(bg_a)

	bg_b = Sprite2D.new()
	bg_b.texture = BG_TEXTURE
	bg_b.centered = false
	background_layer.add_child(bg_b)


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
	speedometer.position = Vector2(12.0, 12.0)
	speedometer.size = Vector2(310.0, 190.0)
	ui.add_child(speedometer)

	bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0.06, 0.07, 0.08, 0.90)
	ui.add_child(bottom_bar)

	help_label = _make_label(13, Color(0.95, 0.96, 0.88, 1.0), 4)
	ui.add_child(help_label)

	footer_stats_label = _make_label(13, Color(1.0, 0.97, 0.82, 1.0), 4)
	footer_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(footer_stats_label)

	status_label = _make_label(22, Color(1.0, 0.97, 0.82, 1.0), 6)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(status_label)

	stage_label = _make_label(12, Color(0.92, 0.95, 0.88, 1.0), 4)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage_label.text = "DAY %d   %s" % [PlayerState.get_current_day(), stage_type.to_upper()]
	ui.add_child(stage_label)

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

	speeder_beep_player = AudioStreamPlayer.new()
	var beep_stream := AudioStreamGenerator.new()
	beep_stream.mix_rate = 22050.0
	beep_stream.buffer_length = 0.12
	speeder_beep_player.stream = beep_stream
	add_child(speeder_beep_player)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade_rect)


func _make_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("outline_size", outline_size)
	return label


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
	if bg_a == null or bg_b == null or player == null:
		return

	var size := get_viewport_rect().size
	var bg_scale := _background_cover_scale(size)
	bg_width = BG_TEXTURE.get_width() * bg_scale
	for bg in [bg_a, bg_b]:
		bg.scale = Vector2(bg_scale, bg_scale)
		bg.position.y = _background_y(bg_scale, size)

	player.scale = _scale_for_vehicle_in_lane(
		"player_tricycle",
		_scale_for_height(PLAYER_TEXTURE, min(116.0, size.y * 0.155)),
		player_lane
	)
	_apply_vehicle_shadow(player, PLAYER_HITBOX_INSET)
	_apply_vehicle_headlight(player, PLAYER_HITBOX_INSET)
	player.position = Vector2(player_x, _sprite_y_for_hitbox_bottom(player, _lane_y(player_lane, size), PLAYER_HITBOX_INSET))

	if speedometer:
		speedometer.position = Vector2(12.0, 12.0)
		speedometer.size = Vector2(310.0, 190.0)

	if bottom_bar:
		bottom_bar.position = Vector2(0.0, size.y - 58.0)
		bottom_bar.size = Vector2(size.x, 58.0)

	if help_label:
		help_label.text = "UP/DOWN switch lane    LEFT/RIGHT adjust speed    SPACE/R action"
		help_label.position = Vector2(28.0, size.y - 45.0)
		help_label.size = Vector2(size.x * 0.56, 34.0)

	if footer_stats_label:
		footer_stats_label.position = Vector2(size.x * 0.56, size.y - 45.0)
		footer_stats_label.size = Vector2(size.x * 0.40 - 28.0, 34.0)

	if status_label:
		status_label.position = Vector2(0.0, size.y * 0.37)
		status_label.size = Vector2(size.x, 120.0)

	if stage_label:
		stage_label.text = "DAY %d   %s" % [PlayerState.get_current_day(), stage_type.to_upper()]
		stage_label.position = Vector2(size.x - 560.0, 18.0)
		stage_label.size = Vector2(530.0, 28.0)

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
	var accelerating := Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var braking := Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)

	if accelerating and not braking:
		player_speed += player_acceleration * player_acceleration_x * _player_lane_acceleration_x() * delta
	elif braking and not accelerating:
		player_speed -= player_brake_deceleration * player_brake_x * delta
	else:
		player_speed = move_toward(player_speed, player_min_cruise_speed, player_coast_deceleration * player_coast_x * delta)

	player_speed = clampf(player_speed, 0.0, player_max_speed)


func _player_lane_acceleration_x() -> float:
	if background_type == "barangay-streets" and player_lane == 2:
		return bottom_lane_player_acceleration_x
	return 1.0


func _is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _update_progress(delta: float) -> void:
	distance += player_speed * _distance_scale() * delta
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
			if _lane_has_spawn_room(lane_index):
				_spawn_entity(lane_index)
			spawn_timers[lane_index] = _next_spawn_delay(lane_index, progress)


func _next_spawn_delay(lane_index: int, progress: float) -> float:
	var delay_range := _spawn_delay_range_for_lane(lane_index)
	var min_delay := maxf(0.05, delay_range.x - progress * spawn_delay_progress_reduction)
	var max_delay := maxf(min_delay, delay_range.y - progress * spawn_delay_progress_reduction)
	return rng.randf_range(min_delay, max_delay)


func _spawn_delay_range_for_lane(lane_index: int) -> Vector2:
	match lane_index:
		0:
			return Vector2(incoming_spawn_min_delay, incoming_spawn_max_delay)
		1:
			return Vector2(main_spawn_min_delay, main_spawn_max_delay)
		2:
			return Vector2(shoulder_spawn_min_delay, shoulder_spawn_max_delay)
	return Vector2(1.0, 2.0)


func _lane_has_spawn_room(lane_index: int) -> bool:
	var right_edge := get_viewport_rect().size.x - 240.0
	for entity in active_entities:
		if entity["lane"] == lane_index and entity["sprite"].position.x > right_edge:
			return false
	return true


func _spawn_entity(lane_index: int) -> void:
	var size := get_viewport_rect().size
	var sprite := Sprite2D.new()
	var vehicle_key := ""
	var world_speed := 0.0
	var fallback_height := 80.0

	match lane_index:
		0:
			vehicle_key = _choose(["blue_truck", "jeepney", "sedan", "truck"])
			world_speed = rng.randf_range(incoming_vehicle_min_speed, incoming_vehicle_max_speed)
			fallback_height = 96.0
			sprite.flip_h = true
		1:
			vehicle_key = _choose(["gray_sedan", "jeepney", "sedan", "motorcycle"])
			world_speed = rng.randf_range(main_vehicle_min_speed, main_vehicle_max_speed)
			fallback_height = 96.0
		2:
			vehicle_key = _choose_weighted({
				"vendor_tricycle": 46.0,
				"motorcycle": 46.0,
				"jeepney": 4.0,
				"sedan": 4.0,
			})
			if rng.randf() < shoulder_parked_chance:
				world_speed = 0.0
			else:
				world_speed = rng.randf_range(shoulder_vehicle_min_speed, shoulder_vehicle_max_speed)
			fallback_height = 90.0

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
		size.x + rng.randf_range(90.0, 360.0),
		_sprite_y_for_hitbox_bottom(sprite, _lane_y(lane_index, size), VEHICLE_HITBOX_INSET)
	)
	sprite.z_index = _z_for_lane(lane_index)
	add_child(sprite)

	active_entities.append({
		"sprite": sprite,
		"lane": lane_index,
		"target_lane": lane_index,
		"vehicle_key": vehicle_key,
		"kind": "traffic",
		"desired_world_speed": world_speed,
		"world_speed": world_speed,
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
		if _lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
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
	if speeder_beep_player == null:
		return

	speeder_beep_player.play()
	var playback := speeder_beep_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	playback.clear_buffer()
	var sample_rate := 22050.0
	var frequency := 880.0
	var frames := int(sample_rate * 0.08)
	for frame_index in range(frames):
		var fade := 1.0 - float(frame_index) / float(frames)
		var sample := sin(TAU * frequency * float(frame_index) / sample_rate) * 0.18 * fade
		playback.push_frame(Vector2(sample, sample))


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
		"kind": "speeder",
		"desired_world_speed": speeder_vehicle_speed,
		"world_speed": speeder_vehicle_speed,
		"lane_change_cooldown": 0.0,
	})


func _update_random_lane_changes(delta: float) -> void:
	if not npc_random_lane_change_enabled:
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
		if rng.randf() > npc_lane_change_chance_per_second * delta:
			continue

		var target_lane := 2 if lane_index == 1 else 1
		if _lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
			_start_lane_change_warning(entity, target_lane)

		entity["lane_change_cooldown"] = rng.randf_range(1.2, 3.5)


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


func _finish_warned_lane_change(entity: Dictionary) -> void:
	var target_lane := int(entity.get("lane_change_warning_target_lane", entity["lane"]))
	var warning_label := _get_entity_lane_warning_label(entity)
	warning_label.visible = false
	entity["lane_change_warning_active"] = false

	if _lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
		entity["lane"] = target_lane
		entity["target_lane"] = target_lane
		entity["sprite"].z_index = _z_for_lane(target_lane)

	entity["lane_change_cooldown"] = rng.randf_range(1.2, 3.5)


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
			var target_lane := 2 if lane_index == 1 else 1
			if _lane_is_safe_for_entity(entity, target_lane, speeder_safe_gap):
				if target_lane == player_lane:
					_start_speeder_lane_change_warning(entity["sprite"], target_lane)
				elif not speeder_lane_change_warning_active or pending_speeder_lane_change_sprite != entity["sprite"]:
					entity["lane"] = target_lane
					entity["target_lane"] = target_lane
					entity["sprite"].z_index = _z_for_lane(target_lane, 2)


func _speeder_needs_lane_change(speeder: Dictionary, lane_index: int) -> bool:
	var speeder_rect := _collision_rect(speeder["sprite"], VEHICLE_HITBOX_INSET)
	var speeder_speed := float(speeder.get("world_speed", speeder_vehicle_speed))
	for entity in active_entities:
		if entity == speeder or entity.get("kind", "traffic") == "speeder":
			continue
		if int(entity["lane"]) != lane_index:
			continue

		var entity_rect := _collision_rect(entity["sprite"], VEHICLE_HITBOX_INSET)
		var entity_speed := float(entity.get("world_speed", 0.0))
		var gap := entity_rect.position.x - (speeder_rect.position.x + speeder_rect.size.x)
		var closing_speed := maxf(0.0, speeder_speed - entity_speed)
		var predicted_close_distance := closing_speed * 0.42
		var emergency_gap := maxf(speeder_safe_gap * 0.82, predicted_close_distance)
		if gap > 0.0 and gap <= emergency_gap:
			return true
	return false


func _lane_is_safe_for_entity(moving_entity: Dictionary, target_lane: int, safe_gap: float) -> bool:
	var moving_rect := _collision_rect(moving_entity["sprite"], VEHICLE_HITBOX_INSET)
	for entity in active_entities:
		if entity == moving_entity:
			continue
		if int(entity["lane"]) != target_lane:
			continue

		var entity_rect := _collision_rect(entity["sprite"], VEHICLE_HITBOX_INSET)
		if absf(entity_rect.get_center().x - moving_rect.get_center().x) < safe_gap:
			return false
	return true


func _find_entity_by_sprite(sprite: Sprite2D) -> Dictionary:
	if sprite == null:
		return {}

	for entity in active_entities:
		if entity.get("sprite") == sprite:
			return entity
	return {}


func _update_npc_following() -> void:
	for entity in active_entities:
		if not entity.has("desired_world_speed"):
			entity["desired_world_speed"] = entity["world_speed"]
		entity["world_speed"] = entity["desired_world_speed"]

	for lane_index in [1, 2]:
		var lane_entities := []
		for entity in active_entities:
			if entity.get("kind", "traffic") == "traffic" and entity["lane"] == lane_index:
				lane_entities.append(entity)

		lane_entities.sort_custom(_sort_entities_front_to_back)

		for index in range(1, lane_entities.size()):
			var front_entity = lane_entities[index - 1]
			var rear_entity = lane_entities[index]
			var rear_desired_speed: float = rear_entity["desired_world_speed"]
			var front_speed: float = front_entity["world_speed"]
			var closing_speed := rear_desired_speed - front_speed
			if closing_speed <= 0.0:
				continue

			var front_rect := _collision_rect(front_entity["sprite"], VEHICLE_HITBOX_INSET)
			var rear_rect := _collision_rect(rear_entity["sprite"], VEHICLE_HITBOX_INSET)
			var gap := front_rect.position.x - (rear_rect.position.x + rear_rect.size.x)
			var predicted_closing_distance := closing_speed * npc_collision_lookahead

			if gap <= npc_follow_gap or gap <= predicted_closing_distance:
				rear_entity["world_speed"] = front_speed


func _sort_entities_front_to_back(a: Dictionary, b: Dictionary) -> bool:
	return a["sprite"].position.x > b["sprite"].position.x


func _update_entities(delta: float) -> void:
	var dead_entities := []
	for entity in active_entities:
		var sprite: Sprite2D = entity["sprite"]
		var lane_index: int = entity["lane"]
		var world_speed: float = entity["world_speed"]
		var screen_velocity := 0.0

		if lane_index == 0:
			screen_velocity = -(player_speed + world_speed)
		else:
			screen_velocity = world_speed - player_speed

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
	var target_y := _sprite_y_for_hitbox_bottom(
		sprite,
		_lane_y(target_lane, get_viewport_rect().size),
		VEHICLE_HITBOX_INSET
	)
	var lerp_speed := speeder_lane_change_lerp_speed if entity.get("kind", "traffic") == "speeder" else npc_lane_change_lerp_speed
	sprite.position.y = lerpf(sprite.position.y, target_y, minf(1.0, delta * lerp_speed))


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
	var wiggle_amount := _player_wiggle_amount()
	if move_forward:
		player.position.x += stage_clear_player_exit_speed * delta
	else:
		player.position.x = player_x + sin(Time.get_ticks_msec() * player_wiggle_x_frequency) * player_wiggle_x_pixels * wiggle_amount
	player.position.y = lerpf(player.position.y, target_y, minf(1.0, delta * player_lane_lerp_speed * player_lane_lerp_x))
	player.rotation = sin(Time.get_ticks_msec() * player_wiggle_rotation_frequency) * player_wiggle_rotation_radians * wiggle_amount


func _player_wiggle_amount() -> float:
	if game_state != "playing" and not player_is_stage_clear_exiting:
		return 0.0
	var stop_speed := maxf(0.001, player_wiggle_stop_speed)
	var wiggle_speed := stage_clear_player_exit_speed if player_is_stage_clear_exiting else player_speed
	return clampf(wiggle_speed / stop_speed, 0.0, 1.0) * player_wiggle_intensity_x


func _distance_scale() -> float:
	return BASE_DISTANCE_SCALE * player_distance_gain_x


func _background_cover_scale(size: Vector2) -> float:
	return maxf(size.x / BG_TEXTURE.get_width(), size.y / BG_TEXTURE.get_height())


func _background_y(bg_scale: float, size: Vector2) -> float:
	return (size.y - BG_TEXTURE.get_height() * bg_scale) * 0.5


func _update_background() -> void:
	var bg_x := -fmod(distance * 16.0, bg_width)
	var bg_y := _background_y(bg_a.scale.y, get_viewport_rect().size)
	bg_a.position = Vector2(bg_x, bg_y)
	bg_b.position = Vector2(bg_x + bg_width, bg_y)


func _update_ui() -> void:
	var speed_kmh := roundi(player_speed * _distance_scale() * 3.6)
	var max_speed_kmh := maxf(1.0, player_max_speed * _distance_scale() * 3.6)
	speedometer.set_values(speed_kmh, speed_kmh / max_speed_kmh, floori(distance), floori(target_distance), time_left)

	if game_state == "playing":
		status_label.text = ""
	else:
		status_label.text = "%s\n%s" % [game_state, end_message]

	if footer_stats_label:
		footer_stats_label.text = "Money PhP %d     Energy %d/%d" % [
			PlayerState.money,
			PlayerState.energy,
			PlayerState.max_energy,
		]

	if stage_label:
		stage_label.text = "DAY %d   %s" % [PlayerState.get_current_day(), stage_type.to_upper()]


func _check_collisions() -> void:
	var player_rect := _collision_rect(player, PLAYER_HITBOX_INSET)
	for entity in active_entities:
		if entity["lane"] != player_lane:
			continue

		var entity_rect := _collision_rect(entity["sprite"], VEHICLE_HITBOX_INSET)
		if player_rect.intersects(entity_rect):
			_end_game("CRASH", "Collision in the %s lane. Space/R to retry." % LANE_NAMES[entity["lane"]])
			return


func _end_game(title: String, detail: String) -> void:
	if game_state != "playing":
		return
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
	get_tree().change_scene_to_file(STAGE_RESULTS_SCENE)


func _store_stage_result() -> void:
	var completed_distance: int = floori(minf(distance, target_distance))
	var base_fare: int = roundi(completed_distance * fare_php_per_meter)
	var fare_penalty: int = roundi(overtime_seconds * overtime_fare_penalty_php_per_second)
	var fare: int = maxi(0, base_fare - fare_penalty)
	var bonus: int = roundi(maxf(0.0, time_left) * time_bonus_php_per_second)
	var total: int = fare + bonus

	PlayerState.set_last_stage_result({
		"day": PlayerState.get_current_day(),
		"stage_type": stage_type,
		"difficulty": stage_difficulty,
		"time_of_day": stage_time_of_day,
		"traffic": stage_traffic,
		"distance": completed_distance,
		"base_fare": base_fare,
		"fare_penalty": fare_penalty,
		"fare": fare,
		"bonus": bonus,
		"total": total,
		"time_left": time_left,
		"overtime": overtime_seconds,
	})


func _change_lane(direction: int) -> void:
	if game_state != "playing":
		return
	player_lane = clampi(player_lane + direction, 0, 2)
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


func _z_for_lane(lane_index: int, offset := 0) -> int:
	return ROAD_ACTOR_Z_BASE + lane_index * ROAD_ACTOR_Z_STEP + offset
