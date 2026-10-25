extends Node2D

const GameTuning := preload("res://scripts/config/game_tuning.gd")

# Gameplay scene coordinator.
# This file wires the stage together, while most driving logic lives in scripts/game/*.gd helpers.

const DEFAULT_BACKGROUND_POOL_TAG := "rural"
const BACKGROUND_POOL_TAGS_BY_TYPE := {
	"barangay-streets": DEFAULT_BACKGROUND_POOL_TAG,
}
const STAGE_BACKGROUND_POOLS := {
	"rural": [
		preload("res://assets/story/backgrounds/roads/bg1_loop.png"),
		preload("res://assets/story/backgrounds/roads/backgroundfishing.png"),
		preload("res://assets/story/backgrounds/roads/farmloop.png"),
	],
}
const RAIN_DIAGONAL_TEXTURE := preload("res://assets/weather/rain_diagonal.svg")
const RAIN_DROPS_TEXTURE := preload("res://assets/weather/rain_drops.svg")
const RAIN_FLOOR_DROPS_TEXTURE := preload("res://assets/weather/rain_floor_drops.svg")
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GameEnvironmentController := preload("res://scripts/game/game_environment_controller.gd")
const GameFlowController := preload("res://scripts/game/game_flow_controller.gd")
const GameInput := preload("res://scripts/game/game_input.gd")
const PlayerHorn := preload("res://scripts/game/player_horn_controller.gd")
const GameRenderer := preload("res://scripts/game/game_renderer.gd")
const GameStageSetup := preload("res://scripts/game/game_stage_setup.gd")
const PassengerDialogueController := preload("res://scripts/game/passenger_dialogue_controller.gd")
const PlayerVehicleController := preload("res://scripts/game/player_vehicle_controller.gd")
const StageTutorialController := preload("res://scripts/game/stage_tutorial_controller.gd")
const VehicleCollisionController := preload("res://scripts/game/vehicle_collision_controller.gd")
const VehicleGeometry := preload("res://scripts/game/vehicle_geometry.gd")
const VehicleSpawnScheduler := preload("res://scripts/game/vehicle_spawn_scheduler.gd")
const VehicleTrafficController := preload("res://scripts/game/vehicle_traffic_controller.gd")
const PLAYER_TEXTURE := preload("res://assets/vehicles/player_tricycle.png")
const VEHICLE_TEXTURES := {
	"beetle": preload("res://assets/vehicles/beetle.png"),
	"blue_truck": preload("res://assets/vehicles/blue_truck.png"),
	"bus": preload("res://assets/vehicles/bus.png"),
	"cargotruck": preload("res://assets/vehicles/cargotruck.png"),
	"gray_sedan": preload("res://assets/vehicles/gray_sedan.png"),
	"jeepney": preload("res://assets/vehicles/jeepney.png"),
	"motorcycle": preload("res://assets/vehicles/motorcycle.png"),
	"parkedmoped": preload("res://assets/vehicles/parkedmoped.png"),
	"parkedtruck": preload("res://assets/vehicles/parkedtruck.png"),
	"sedan": preload("res://assets/vehicles/sedan.png"),
	"truck": preload("res://assets/vehicles/truck.png"),
	"van": preload("res://assets/vehicles/van.png"),
	"vendor_tricycle": preload("res://assets/vehicles/vendor_tricycle.png"),
}

const LANE_NAMES := ["INCOMING", "MAIN", "SHOULDER"]
const BASE_DISTANCE_SCALE := GameTuning.BASE_DISTANCE_SCALE
const VISUAL_DISTANCE_SCALE := GameTuning.VISUAL_DISTANCE_SCALE
const PLAYER_HITBOX_INSET := GameTuning.PLAYER_HITBOX_INSET
const VEHICLE_HITBOX_INSET := Vector4(0.06, 0.08, 0.06, 0.0)
const NPC_LANE_CHANGE_WARNING_PULSES := 3
const NPC_LANE_CHANGE_WARNING_INTERVAL := 0.28
const POST_DAY_SEVEN_SPAWN_DELAY_X := 0.90
const POST_DAY_SEVEN_BUSY_CAR_CHANCE_MAIN := 0.10
const POST_DAY_SEVEN_BUSY_CAR_CHANCE_SHOULDER := 0.08
const POST_DAY_SEVEN_BUSY_CAR_LANE_CHANGE_CHANCE_PER_SECOND := 0.035
const PARKED_VEHICLE_KEYS := ["truck", "jeepney", "sedan", "parkedmoped", "parkedtruck"]
const PARKED_VEHICLE_Y_OFFSET := 26.0
const PARKED_COLLISION_MIN_KMH := GameTuning.PARKED_COLLISION_MIN_KMH
const PARKED_VEHICLE_Z_OFFSET := 4
const SPEEDER_PLAYER_LANE_CHANGE_BUFFER := GameTuning.SPEEDER_PLAYER_LANE_CHANGE_BUFFER
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
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001);
	vec2 delta = SCREEN_UV - glow_center;
	delta.x *= aspect;
	float pulse = 1.0 + sin(TIME * 1.8) * 0.06 + sin(TIME * 3.2) * 0.025;
	float sphere_radius = max(0.0001, min(glow_radius.x, glow_radius.y) * pulse);
	float dist = length(delta) / sphere_radius;
	float sphere = pow(max(0.0, 1.0 - dist), 1.7);
	float halo = pow(max(0.0, 1.0 - dist * 1.55), 3.2);
	float alpha = (sphere * 0.82 + halo * 0.42) * (0.96 + sin(TIME * 2.1) * 0.04);
	COLOR = vec4(glow_color.rgb, glow_color.a * alpha);
}
"
const SPEEDOMETER_MAX_KMH := GameTuning.SPEEDOMETER_MAX_KMH
const SPEEDOMETER_REFERENCE_MAX_SPEED := GameTuning.SPEEDOMETER_REFERENCE_MAX_SPEED
const SPEEDOMETER_BASE_MAX_KMH := GameTuning.SPEEDOMETER_BASE_MAX_KMH

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
@export_range(1.0, 10000.0, 1.0) var target_distance := 525.0
@export_range(1.0, 600.0, 0.5) var time_limit := 58.0

# Player Movement: edit scripts/config/game_tuning.gd.
var player_x := GameTuning.PLAYER_X
var player_start_speed := GameTuning.PLAYER_START_SPEED
var player_min_cruise_speed := GameTuning.PLAYER_MIN_CRUISE_SPEED
var player_max_speed := GameTuning.PLAYER_MAX_SPEED
var player_acceleration := GameTuning.PLAYER_ACCELERATION
var player_acceleration_x := GameTuning.PLAYER_ACCELERATION_X
var bottom_lane_player_acceleration_x := GameTuning.BOTTOM_LANE_PLAYER_ACCELERATION_X
var player_brake_deceleration := GameTuning.PLAYER_BRAKE_DECELERATION
var player_brake_x := GameTuning.PLAYER_BRAKE_X
var player_coast_deceleration := GameTuning.PLAYER_COAST_DECELERATION
var player_coast_x := GameTuning.PLAYER_COAST_X
var player_lane_lerp_speed := GameTuning.PLAYER_LANE_LERP_SPEED
var player_lane_lerp_x := GameTuning.PLAYER_LANE_LERP_X
var player_distance_gain_x := GameTuning.PLAYER_DISTANCE_GAIN_X
var player_wiggle_stop_speed := GameTuning.PLAYER_WIGGLE_STOP_SPEED
var player_wiggle_x_pixels := GameTuning.PLAYER_WIGGLE_X_PIXELS
var player_wiggle_x_frequency := GameTuning.PLAYER_WIGGLE_X_FREQUENCY
var player_wiggle_rotation_radians := GameTuning.PLAYER_WIGGLE_ROTATION_RADIANS
var player_wiggle_rotation_frequency := GameTuning.PLAYER_WIGGLE_ROTATION_FREQUENCY
var player_wiggle_intensity_x := GameTuning.PLAYER_WIGGLE_INTENSITY_X

# Boost: edit scripts/config/game_tuning.gd.
var player_boost_max_speed_x := GameTuning.PLAYER_BOOST_MAX_SPEED_X
var player_boost_acceleration_x := GameTuning.PLAYER_BOOST_ACCELERATION_X
var player_boost_release_decay_x := GameTuning.PLAYER_BOOST_RELEASE_DECAY_X
var boost_gas_consumption_percent_per_second := GameTuning.BOOST_GAS_CONSUMPTION_PERCENT_PER_SECOND

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
@export_range(0.0, 700.0, 5.0) var top_lane_overtake_speed_boost := 280.0
@export_range(0.1, 8.0, 0.1) var top_lane_overtake_speed_boost_seconds := 4.0
var stage_clear_min_exit_speed := GameTuning.STAGE_CLEAR_MIN_EXIT_SPEED
var stage_clear_player_exit_speed := GameTuning.STAGE_CLEAR_PLAYER_EXIT_SPEED
var stage_clear_fade_seconds := GameTuning.STAGE_CLEAR_FADE_SECONDS

@export_group("Speeders")
@export var speeder_enabled := false
@export_range(1.0, 60.0, 0.5) var speeder_spawn_min_delay := 9.0
@export_range(1.0, 60.0, 0.5) var speeder_spawn_max_delay := 14.0
@export_range(100.0, 1400.0, 10.0) var speeder_vehicle_min_speed := 700.0
@export_range(100.0, 1400.0, 10.0) var speeder_vehicle_max_speed := 860.0
@export_range(1.0, 20.0, 0.5) var speeder_lane_change_lerp_speed := 8.0
@export_range(80.0, 800.0, 10.0) var speeder_avoid_lookahead := 360.0
@export_range(40.0, 400.0, 10.0) var speeder_safe_gap := 150.0

@export_group("Fairness")
var player_lane_change_front_padding := GameTuning.PLAYER_LANE_CHANGE_FRONT_PADDING
var player_lane_change_back_padding := GameTuning.PLAYER_LANE_CHANGE_BACK_PADDING
var player_lane_change_side_padding := GameTuning.PLAYER_LANE_CHANGE_SIDE_PADDING
var player_lane_change_prediction_seconds := GameTuning.PLAYER_LANE_CHANGE_PREDICTION_SECONDS
@export_range(0.0, 220.0, 5.0) var npc_lane_change_planning_padding_x := 64.0
@export_range(0.0, 80.0, 2.0) var npc_lane_change_planning_padding_y := 18.0
@export_range(0.0, 2.0, 0.05) var npc_lane_change_fault_grace_seconds := 0.65
@export_range(0.0, 260.0, 5.0) var pin_pressure_front_gap := 115.0
@export_range(0.0, 260.0, 5.0) var pin_pressure_rear_gap := 155.0
@export_range(0.0, 360.0, 5.0) var pin_pressure_escape_lane_gap := 190.0
@export_range(0.0, 1.0, 0.05) var bottom_lane_lane_change_chance_x := 0.35

@export_group("Stage Rewards")
@export_range(0.0, 10.0, 0.01) var fare_php_per_meter := 0.15
@export_range(0.0, 100.0, 0.5) var time_bonus_php_per_second := 2.0
@export_range(0.0, 20.0, 0.25) var overtime_fare_penalty_php_per_second := 1.25

# Crash Recovery: edit scripts/config/game_tuning.gd.
var crash_energy_loss := GameTuning.CRASH_ENERGY_LOSS
var crash_recovery_seconds := GameTuning.CRASH_RECOVERY_SECONDS
var crash_invincible_seconds := GameTuning.CRASH_INVINCIBLE_SECONDS
var crash_flicker_interval := GameTuning.CRASH_FLICKER_INTERVAL
var crash_flicker_alpha := GameTuning.CRASH_FLICKER_ALPHA

# Perspective: edit scripts/config/game_tuning.gd.
var incoming_lane_scale := GameTuning.INCOMING_LANE_SCALE
var main_lane_scale := GameTuning.MAIN_LANE_SCALE
var shoulder_lane_scale := GameTuning.SHOULDER_LANE_SCALE
var player_perspective_lerp_speed := GameTuning.PLAYER_PERSPECTIVE_LERP_SPEED

@export_group("Time Filters")
@export var morning_filter_color := Color(0.0, 0.0, 0.0, 0.0)
@export var noon_filter_color := Color(1.0, 0.84, 0.26, 0.26)
@export var night_filter_color := Color(0.0, 0.02, 0.10, 0.62)
var morning_headlight_alpha := GameTuning.MORNING_HEADLIGHT_ALPHA
var noon_headlight_alpha := GameTuning.NOON_HEADLIGHT_ALPHA
var night_headlight_alpha := GameTuning.NIGHT_HEADLIGHT_ALPHA
var headlight_cone_length_x := GameTuning.HEADLIGHT_CONE_LENGTH_X
var headlight_cone_height_x := GameTuning.HEADLIGHT_CONE_HEIGHT_X
@export var noon_glow_color := Color(1.0, 0.86, 0.30, 0.22)
@export var noon_glow_center := Vector2(0.52, 0.22)
@export var noon_glow_radius := Vector2(0.72, 0.56)

@export_group("Weather")
@export var cloudy_filter_color := Color(0.36, 0.39, 0.38, 0.20)
@export var rain_filter_color := Color(0.16, 0.22, 0.27, 0.28)
@export var heavy_rain_filter_color := Color(0.10, 0.14, 0.20, 0.38)
@export_range(-1800.0, 1800.0, 1.0) var rain_scroll_x := -312.0
@export_range(0.0, 2400.0, 1.0) var rain_scroll_y := 1440.0
@export_range(0.0, 1.0, 0.01) var rain_lines_alpha := 0.72
@export_range(0.0, 1.0, 0.01) var heavy_rain_lines_alpha := 0.92
@export_range(0.0, 1.0, 0.01) var rain_drops_alpha := 0.22
@export_range(0.0, 1.0, 0.01) var rain_floor_drops_alpha := 0.34
@export_range(0.02, 2.0, 0.01) var rain_floor_drop_min_delay := 0.12
@export_range(0.02, 2.0, 0.01) var rain_floor_drop_max_delay := 0.34
@export_range(0.1, 3.0, 0.05) var rain_floor_drop_lifetime := 0.55
@export_range(1.0, 6.0, 0.1) var rain_floor_drop_max_scale := 2.4
@export_range(1, 60, 1) var rain_floor_drop_max_active := 12

@export_group("Night Visibility")
@export var night_visibility_shade_color := Color(0.0, 0.0, 0.0, 0.86)
@export var night_visibility_focus_offset := Vector2(170.0, -20.0)
@export var night_visibility_outer_radius := Vector2(0.34, 0.24)
@export_range(0.1, 0.95, 0.01) var night_visibility_inner_ratio := 0.34

var rng := RandomNumberGenerator.new()
var background_scroller
var time_filter_rect: ColorRect
var weather_filter_rect: ColorRect
var rain_lines_rect: TextureRect
var rain_drops_rect: TextureRect
var rain_floor_drops_rect: Control
var rain_floor_drop_texture: Texture2D
var noon_glow_rect: ColorRect
var noon_glow_material: ShaderMaterial
var night_visibility_rect: ColorRect
var night_visibility_material: ShaderMaterial
var headlight_cone_texture: Texture2D
var player: Sprite2D
var player_lane := GameTuning.PLAYER_START_LANE
var player_speed := 0.0
var distance := 0.0
var time_left := 0.0
var overtime_seconds := 0.0
var active_entities: Array = []
var spawn_timers := [0.4, 0.8, 1.2]
var oncoming_warning_elapsed := -1.0
var oncoming_warning_beep_index := -1
var oncoming_warning_label: Label
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
var game_hud
var audio_manager
var horn_held := false
var horn_press_cooldown := 0.0
var fade_rect: ColorRect
var stage_tutorial
var passenger_dialogue_controller
var passenger_rule_violation_count := 0
var texture_hitbox_cache := {}
var stage_clear_transition_started := false
var stage_clear_fade_time := 0.0
var crash_repair_transition_active := false
var crash_repair_hold_remaining := 0.0
var crash_repair_fade_time := 0.0
var stage_difficulty := "short"
var stage_time_of_day := "morning"
var stage_traffic := "chill"
var stage_weather := "clear"
var stage_special_type := ""
var special_stage_id := ""
var special_stage_blueprint: Dictionary = {}
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
var pending_speeder_lane_change_sprite = null
var special_mode_hidden_modifiers := {}
var gameplay_entry_fade_seconds := 0.0
var rolled_target_distance := 0.0
var rolled_target_stage_type := ""
var boost_active := false
var boost_speed_x := 1.0
var boost_gas_save_timer := 0.0
var weather_effect_time := 0.0
var rain_floor_drop_spawn_timer := 0.0
var player_hit_recovery_timer := 0.0
var player_hit_invincible_timer := 0.0
var player_hit_flicker_timer := 0.0
var player_hit_flicker_visible := true


func _ready() -> void:
	if use_player_state_stage_sequence and bool(PlayerState.active_event_special_stage.get("completed", false)):
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred(PlayerState.finish_event_special_stage())
		return
	PlayerState.set_resume_scene("res://scenes/main.tscn")
	GameEnvironmentController.hide_editor_preview(self)
	rng.randomize()
	gameplay_entry_fade_seconds = PlayerState.consume_pending_gameplay_entry_fade() if use_player_state_stage_sequence else 0.0
	if use_player_state_stage_sequence:
		stage_type = PlayerState.get_current_stage_type()
	GameStageSetup.apply_stage_profile(self)
	if use_player_state_stage_sequence:
		stage_weather = PlayerState.get_stage_weather(stage_time_of_day)
		stage_special_type = PlayerState.get_current_stage_special_type()
		special_stage_id = PlayerState.get_current_special_stage_id()
	GameStageSetup.apply_weather_modifiers(self)
	GameStageSetup.apply_player_upgrades(self)
	GameStageSetup.apply_character_modifiers(self)
	GameStageSetup.apply_special_stage_blueprint(self)
	VehicleTrafficController.reset_speeder_timer(self)
	time_left = time_limit
	overtime_seconds = 0.0
	player_speed = player_start_speed
	headlight_cone_texture = GameEnvironmentController.make_headlight_cone_texture()
	GameEnvironmentController.create_audio_manager(self)
	GameEnvironmentController.create_background(self, _pick_stage_background())
	PlayerVehicleController.create_player(self)
	GameEnvironmentController.create_time_filter(self)
	GameEnvironmentController.create_weather_effects(self, RAIN_DIAGONAL_TEXTURE, RAIN_DROPS_TEXTURE, RAIN_FLOOR_DROPS_TEXTURE)
	GameEnvironmentController.create_noon_glow(self, NOON_GLOW_SHADER_CODE)
	GameEnvironmentController.create_night_visibility_mask(self, NIGHT_VISIBILITY_SHADER_CODE)
	GameEnvironmentController.create_ui(self, gameplay_entry_fade_seconds)
	passenger_rule_violation_count = 0
	passenger_dialogue_controller = PassengerDialogueController.new()
	passenger_dialogue_controller.setup(self, game_hud.get_ui_root())
	stage_tutorial = StageTutorialController.new()
	audio_manager.start_stage_bgm(stage_time_of_day, stage_traffic, rng)
	audio_manager.start_rain_loop_bgm(stage_weather)
	GameEnvironmentController.layout_scene(self)
	GameEnvironmentController.begin_gameplay_entry_fade(self)
	StageTutorialController.schedule(self)
	if use_player_state_stage_sequence:
		PlayerState.confirm_stage_started()
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		PlayerHorn.stop(self)
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		GameEnvironmentController.layout_scene(self)
		queue_redraw()


func _exit_tree() -> void:
	PlayerHorn.stop(self)


func _pick_stage_background() -> Texture2D:
	return GameEnvironmentController.pick_stage_background(self)


func _background_pool_tag() -> String:
	return GameEnvironmentController.background_pool_tag(self)


func _unhandled_input(event: InputEvent) -> void:
	if crash_repair_transition_active:
		return
	if GameInput.is_any_press(event) and game_state == "GAME OVER":
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	if PlayerHorn.handle_input(self, event):
		get_viewport().set_input_as_handled()
		return

	if game_state == "playing" and GameInput.is_stage_complete_debug_shortcut(event):
		GameFlowController.end_game(self, "YOU MADE IT", "Debug stage complete.")
		return

	if stage_tutorial != null and stage_tutorial.input_lock_active:
		return

	if stage_tutorial != null and stage_tutorial.handle_input(event):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				PlayerVehicleController.change_lane(self, -1)
			KEY_DOWN, KEY_S:
				PlayerVehicleController.change_lane(self, 1)
			KEY_SPACE, KEY_R:
				if game_state == "YOU MADE IT":
					GameFlowController.go_to_profit_screen(self)
				elif game_state != "playing":
					GameFlowController.try_retry_stage(self)


func _process(delta: float) -> void:
	PlayerHorn.update(self, delta)
	if crash_repair_transition_active:
		GameFlowController.update_crash_repair_transition(self, delta)
		return
	if stage_tutorial != null and stage_tutorial.active:
		stage_tutorial.update_positions(
			player,
			player_x,
			get_viewport_rect().size,
			func(lane_index: int, size: Vector2) -> float:
				return VehicleGeometry.lane_y(self, lane_index, size)
		)
		GameEnvironmentController.update_background(self)
		GameEnvironmentController.update_weather_effects(self, delta)
		GameEnvironmentController.update_ui(self, GameFlowController.current_speed_kmh(self), SPEEDOMETER_MAX_KMH)
		return
	if stage_tutorial != null and stage_tutorial.input_lock_active:
		GameEnvironmentController.update_background(self)
		GameEnvironmentController.update_weather_effects(self, delta)
		GameEnvironmentController.update_night_visibility_mask(self)
		GameEnvironmentController.update_ui(self, GameFlowController.current_speed_kmh(self), SPEEDOMETER_MAX_KMH)
		queue_redraw()
		return

	if game_state == "playing":
		_update_player_hit_state(delta)
		if player_hit_recovery_timer > 0.0:
			player_speed = 0.0
			boost_active = false
			boost_speed_x = 1.0
		else:
			PlayerVehicleController.handle_speed(self, delta)
		GameFlowController.update_progress(self, delta)
		VehicleTrafficController.prune_invalid_entities(self)
		VehicleSpawnScheduler.update_spawns(self, delta)
		VehicleTrafficController.update_speeder_warning(self, delta)
		VehicleTrafficController.update_speeder_lane_change_warning(self, delta)
		VehicleTrafficController.update_lane_change_warnings(self, delta)
		VehicleTrafficController.update_random_lane_changes(self, delta)
		VehicleTrafficController.update_vehicle_speeds(self, delta)
		if stage_traffic != "busy":
			VehicleTrafficController.update_vehicle_overtake_ai(self, delta)
		VehicleTrafficController.update_busy_vehicle_ai(self, delta)
		VehicleTrafficController.update_speeder_ai(self)
		VehicleTrafficController.update_npc_following(self)
		VehicleTrafficController.update_overtake_speed_boosts(self, delta)
		VehicleTrafficController.update_entities(self, delta)
		PlayerVehicleController.update_player(self, delta)
		if passenger_dialogue_controller != null:
			passenger_dialogue_controller.update(self, delta)
		var collision: Dictionary = VehicleCollisionController.collision_data(self)
		if not collision.is_empty():
			GameFlowController.handle_player_hit(self, collision["detail"], collision["energy_loss"])
	elif game_state == "YOU MADE IT":
		VehicleCollisionController.update_stage_clear_entities(self, delta)
		PlayerVehicleController.update_player(self, delta, true)
		if passenger_dialogue_controller != null:
			passenger_dialogue_controller.update(self, delta)
		GameFlowController.update_stage_clear_transition(self, delta)
	else:
		PlayerVehicleController.update_player(self, delta)
		if passenger_dialogue_controller != null:
			passenger_dialogue_controller.update(self, delta)

	_apply_player_hit_visuals()
	GameEnvironmentController.update_background(self)
	GameEnvironmentController.update_weather_effects(self, delta)
	GameEnvironmentController.update_night_visibility_mask(self)
	GameEnvironmentController.update_ui(self, GameFlowController.current_speed_kmh(self), SPEEDOMETER_MAX_KMH)
	queue_redraw()


func _draw() -> void:
	GameRenderer.draw(self, distance * VISUAL_DISTANCE_SCALE)


func _update_player_hit_state(delta: float) -> void:
	PlayerVehicleController.update_hit_state(self, delta)


func _apply_player_hit_visuals() -> void:
	PlayerVehicleController.apply_hit_visuals(self)
