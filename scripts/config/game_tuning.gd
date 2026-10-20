extends RefCounted

# First collection, then the weekly base payment. Unpaid first-week debt carries over.
const WEEKLY_DEBT_GOALS := [2500, 5000]

# Random ride stories: probability per eligible unnamed-passenger ride (0..1).
const MALASAKIT_EVENT_CHANCE := 0.10
const MALASAKIT_EPILOGUE_DELAY_DAYS := 1 # Guaranteed on the next eligible ride from this day onward.
# Permanent for the current run after waiving the fare; does not stack.
const MALASAKIT_FARE_BONUS := 0.05

# CENTRAL TRICYCLE / STORE / UPGRADE / MENU TRAFFIC TUNING
# Edit this file, then restart the running game. No autoload is needed.
# Speeds and acceleration are world units, durations are seconds, fuel is
# percentage points (10.0 = ten tank percentage points), and prices are PHP.
# Multipliers: 1.0 = unchanged; per-level bonuses: 0.20 = +20% per level.
# Existing saves retain owned upgrades, current resources and daily gas price.
# Starting resources and capacity defaults apply to new runs. Keep item IDs
# stable for saves. Existing upgrade levels use the new effects on the next ride.
# Scene lane guides/art, other NPC traffic settings, story modifiers and stage rewards
# remain in their existing files. Their modifiers still apply after these bases.

# Tricycle movement (non-negative; lane interpolation is a rate).
const PLAYER_X := 220.0
const PLAYER_START_SPEED := 320.0
const PLAYER_MIN_CRUISE_SPEED := 180.0
const PLAYER_MAX_SPEED := 560.0
const PLAYER_ACCELERATION := 280.0
const PLAYER_ACCELERATION_X := 1.0
const BOTTOM_LANE_PLAYER_ACCELERATION_X := 1.0
const PLAYER_BRAKE_DECELERATION := 280.0
const PLAYER_BRAKE_X := 1.0
const PLAYER_COAST_DECELERATION := 85.0
const PLAYER_COAST_X := 1.0
const PLAYER_LANE_LERP_SPEED := 9.0
const PLAYER_LANE_LERP_X := 1.0
const PLAYER_DISTANCE_GAIN_X := 1.0
const PLAYER_WIGGLE_STOP_SPEED := 45.0
const PLAYER_WIGGLE_X_PIXELS := 2.0
const PLAYER_WIGGLE_X_FREQUENCY := 0.012
const PLAYER_WIGGLE_ROTATION_RADIANS := 0.012
const PLAYER_WIGGLE_ROTATION_FREQUENCY := 0.018
const PLAYER_WIGGLE_INTENSITY_X := 1.0

# Boost (multipliers >= 1; fuel cost >= 0).
const PLAYER_BOOST_MAX_SPEED_X := 1.2
const PLAYER_BOOST_ACCELERATION_X := 1.4
const PLAYER_BOOST_RELEASE_DECAY_X := 0.45
const BOOST_GAS_CONSUMPTION_PERCENT_PER_SECOND := 0.75

# Crashes and lane-change clearance.
const PLAYER_LANE_CHANGE_FRONT_PADDING := 120.0
const PLAYER_LANE_CHANGE_BACK_PADDING := 150.0
const PLAYER_LANE_CHANGE_SIDE_PADDING := 36.0
const PLAYER_LANE_CHANGE_PREDICTION_SECONDS := 1.2
const CRASH_ENERGY_LOSS := 1
const CRASH_RECOVERY_SECONDS := 0.45
const CRASH_INVINCIBLE_SECONDS := 1.6
const CRASH_FLICKER_INTERVAL := 0.08
const CRASH_FLICKER_ALPHA := 0.35

# Trip-ending crashes: lose a percentage of cash, then spend days in repair.
# Bill = floor(cash * min(base + random(0..extra), cap) / 100).
const CRASH_REPAIR_BASE_PERCENT := 25
const CRASH_REPAIR_RANDOM_PERCENT := 25
const CRASH_REPAIR_MAX_PERCENT := 50
const CRASH_REPAIR_DAYS := 1
const CRASH_REPAIR_ENERGY_RECOVERY_RATIO := 1.0 # 1.0 restores full energy.
# Hold the crash frame until the sound finishes (at least this many seconds),
# then fade to black before opening the repair screen.
const CRASH_REPAIR_HOLD_SECONDS := 0.35
const CRASH_REPAIR_FADE_SECONDS := 1.2

# Perspective, headlights and stage-exit animation.
const INCOMING_LANE_SCALE := 0.78
const MAIN_LANE_SCALE := 1.0
const SHOULDER_LANE_SCALE := 1.18
const PLAYER_PERSPECTIVE_LERP_SPEED := 9.0
const STAGE_CLEAR_MIN_EXIT_SPEED := 180.0
const STAGE_CLEAR_PLAYER_EXIT_SPEED := 120.0
const STAGE_CLEAR_FADE_SECONDS := 0.9
const MORNING_HEADLIGHT_ALPHA := 0.0
const NOON_HEADLIGHT_ALPHA := 0.0
const NIGHT_HEADLIGHT_ALPHA := 0.84
const HEADLIGHT_CONE_LENGTH_X := 3.35
const HEADLIGHT_CONE_HEIGHT_X := 1.18

# Geometry and speed display. Calibration is independent of maximum speed.
const BASE_DISTANCE_SCALE := 0.0297619
const VISUAL_DISTANCE_SCALE := 2.35294
const PLAYER_HITBOX_INSET := Vector4(0.08, 0.08, 0.08, 0.0)
const PARKED_COLLISION_MIN_KMH := 40
const SPEEDER_PLAYER_LANE_CHANGE_BUFFER := 260.0
const SPEEDOMETER_MAX_KMH := 180
const SPEEDOMETER_REFERENCE_MAX_SPEED := 560.0
const SPEEDOMETER_BASE_MAX_KMH := 60.0
const PLAYER_START_LANE := 1 # 0 incoming, 1 main, 2 shoulder.
const PLAYER_FALLBACK_HEIGHT := 116.0 # Used if scene scale reference is missing.
const PLAYER_FALLBACK_HEIGHT_RATIO := 0.155
const BUSY_PLAYER_X_RATIO := 0.5

# Speeder traffic: visible bumper clearance and horizontal bob, in screen pixels.
# Bob frequency is full cycles per second; set amplitude to 0 to disable it.
const SPEEDER_FRONT_CLEARANCE_PIXELS := 10.0
const SPEEDER_BOB_X_PIXELS := 2.0
const SPEEDER_BOB_CYCLES_PER_SECOND := 1.5

# Wheel animation shared by gameplay and the main menu.
# Rotation follows road speed; cap revolutions/second to keep spokes readable.
const WHEEL_ANIMATION_ENABLED := true
const WHEEL_ROTATION_SPEED_X := 1.0
const WHEEL_MAX_REVOLUTIONS_PER_SECOND := 2.25
const WHEEL_TIRE_HIGHLIGHT_STRENGTH := 0.16

# Main-menu traffic. Speeds are pixels/second; gaps and wrap offsets are pixels.
# Lane 0 travels left, lane 1 travels right. x_ratio is the initial screen position.
# Scale is multiplied by INCOMING_LANE_SCALE / MAIN_LANE_SCALE above.
const MENU_TRAFFIC_GAP_PIXELS := 40.0
const MENU_TRAFFIC_WRAP_MIN_PIXELS := 120.0
const MENU_TRAFFIC_WRAP_MAX_PIXELS := 420.0
const MENU_TRAFFIC_HITBOX_INSET := Vector4(0.06, 0.08, 0.06, 0.0)
const MENU_TRAFFIC_FALLBACK_LANE_Y := [435.0, 535.0]
const MENU_TRAFFIC_VEHICLES := [
	{"vehicle": "blue_truck", "lane": 0, "x_ratio": 0.92, "speed": 210.0, "scale": 0.32},
	{"vehicle": "jeepney", "lane": 0, "x_ratio": 0.46, "speed": 160.0, "scale": 0.42},
	{"vehicle": "gray_sedan", "lane": 1, "x_ratio": 0.24, "speed": 125.0, "scale": 0.38},
	{"vehicle": "sedan", "lane": 1, "x_ratio": 0.72, "speed": 145.0, "scale": 0.38},
]

# Explicit environmental overrides of the base tricycle values above.
const NOON_PLAYER_COAST_DECELERATION := 96.0
const BARANGAY_BOTTOM_LANE_ACCELERATION_X := 0.65
const WEATHER_HANDLING_MULTIPLIERS := {
	"rain": {
		"player_brake_deceleration": 0.85,
		"player_brake_x": 0.85,
		"player_coast_deceleration": 0.86,
	},
	"heavy rain": {
		"player_brake_deceleration": 0.72,
		"player_brake_x": 0.75,
		"player_coast_deceleration": 0.72,
	},
}

# Fuel and energy. Trip cost must be at least 1; defaults <= capacities.
const DEFAULT_STARTING_ENERGY := 10
const DEFAULT_MAX_ENERGY := 10
const DEFAULT_STARTING_GAS_PERCENT := 100.0
const DEFAULT_MAX_GAS_PERCENT := 100.0
const TRIP_ENERGY_COST := 1
const LOW_GAS_PERCENT_THRESHOLD := 20.0
const MIN_BOOST_GAS_PERCENT := 0.05
const GAS_DRAIN_PERCENT_PER_1000_UNITS := 5.0
const CRITICAL_ENERGY_WARNING_THRESHOLD := 2
const HIGH_ENERGY_THRESHOLD := 7
const FATIGUE_ENERGY_BOUNDARY := 6
const FATIGUE_REFERENCE_POINTS := 6.0 # Positive denominator for fatigue strength.
const HIGH_ENERGY_BASE_MODIFIERS := {
	"player_acceleration_x": 1.0,
	"player_max_speed": 1.0,
	"player_brake_x": 1.0,
	"player_lane_lerp_x": 1.0,
	"player_coast_x": 1.0,
	"player_wiggle_intensity_x": 0.92,
}
const HIGH_ENERGY_BONUS_PER_POINT := {
	"player_acceleration_x": 0.05,
	"player_max_speed": 0.035,
	"player_brake_x": 0.04,
	"player_lane_lerp_x": 0.04,
}
const FATIGUE_MODIFIER_DELTAS := {
	"player_acceleration_x": -0.45,
	"player_max_speed": -0.30,
	"player_brake_x": -0.35,
	"player_lane_lerp_x": -0.40,
	"player_coast_x": 0.35,
	"player_wiggle_intensity_x": 0.45,
}

# Upgrade effects. Price / price step / maximum level are in STORE_ITEMS.
# Engine speed preserves the existing +90% PER LEVEL (5.5x at level 5).
const ENGINE_ACCELERATION_BONUS_PER_LEVEL := 0.20
const ENGINE_SPEED_BONUS_PER_LEVEL := 0.9
const BRAKE_POWER_BONUS_PER_LEVEL := 0.20
const FUEL_EFFICIENCY_GAS_REDUCTION_PER_LEVEL := 0.04
const FUEL_EFFICIENCY_BOOST_REDUCTION_PER_LEVEL := 0.025
const MIN_DISTANCE_FUEL_MULTIPLIER := 0.45
const MIN_BOOST_FUEL_MULTIPLIER := 0.60

# Store fuel pricing / refills and cigarette effects.
# Gas price varies daily from the saved price; it is not a fixed item price.
const GAS_CAN_PERCENT := 10.0
const DEFAULT_GAS_PRICE := 70
const DAILY_GAS_PRICE_MAX_PERCENT_CHANGE := 30.0
const YOSI_ENERGY_RESTORE := 2
const SMOKER_YOSI_ENERGY_RESTORE := 3
const SMOKER_YOSI_GOAL := 10 # Purchases in one day to unlock smoker.
const SMOKER_MAX_ENERGY_PENALTY := 2
const SMOKER_DANGER_YOSI_TOTAL := 50 # Lifetime purchases causing run failure.

# Store inventory, in display order.
# Upgrade price = cost + current_level * cost_step. max_level controls purchase
# limits and the tier display. Energy and gas descriptions interpolate their
# values, so changing an amount also changes its displayed effect.
const STORE_ITEMS := [
	{
		"id": "engine_tune",
		"name": "Engine Tune",
		"description": "increase top speed and acceleration",
		"cost": 750,
		"cost_step": 70,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "brake_kit",
		"name": "Brake Kit",
		"description": "improve braking power",
		"cost": 700,
		"cost_step": 55,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "fuel_efficiency",
		"name": "Fuel Efficiency",
		"description": "less gas consumption and slightly cheaper boost",
		"cost": 650,
		"cost_step": 60,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "yosi",
		"name": "Warlboro Blue",
		"description": "Restore energy. May cause negative effects",
		"cost": 25,
		"type": "energy",
		"energy": YOSI_ENERGY_RESTORE,
	},

	{
		"id": "energy_snack",
		"name": "Energy Bar",
		"description": "Restore {energy} energy",
		"cost": 50,
		"type": "energy",
		"energy": 2,
	},
	{
		"id": "full_meal",
		"name": "Budget Meal",
		"description": "Restore {energy} energy",
		"cost": 120,
		"type": "energy",
		"energy": 5,
	},
	{
		"id": "gas_can",
		"name": "Gas Can",
		"description": "Add {gas}% gas",
		"type": "gas",
		"gas": GAS_CAN_PERCENT,
	},
]
