extends RefCounted

# First collection, then the weekly base payment. Unpaid first-week debt carries over.
const WEEKLY_DEBT_GOALS := [2500, 5000]

# Completed rides with each named passenger before revealing their name.
const CHARACTER_NAME_UNLOCK_RIDES := 2

# Fresh terminal lineups vary from this minimum up to the available nine slots.
const TERMINAL_MIN_PASSENGERS := 2

# Temporary switch for incidental passenger chatter during driving.
const PASSENGER_MESSAGES_ENABLED := false

# Isidro's first event qualifies above this speed, or after a vehicle collision.
const ISIDRO_FIRST_EVENT_SPEED_KMH := 70.0

# Random ride stories: probability per eligible unnamed-passenger ride (0..1).
const MALASAKIT_EVENT_CHANCE := 0.10
const BAYANIHAN_EVENT_CHANCE := 0.10
const GENERIC_PASSENGER_EVENT_CHANCE := 0.25
const MALASAKIT_EPILOGUE_DELAY_DAYS := 1 # Guaranteed on the next eligible ride from this day onward.
# Permanent for the current run after waiving the fare; does not stack.
const MALASAKIT_FARE_BONUS := 0.05
const BAYANIHAN_FARE_BONUS := 0.05
const MASIPAG_MAX_ENERGY_BONUS := 1
const ACHIEVEMENT_MAX_STRESS_BONUS := 2

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
const CRASH_STRESS_GAIN := 1
const HEAD_ON_CRASH_STRESS_GAIN := 3
const CRASH_HULL_DAMAGE := 1
const HEAD_ON_CRASH_HULL_DAMAGE := 3
const HEAVY_CRASH_HULL_DAMAGE := 2
const HEAVY_CRASH_STRESS_GAIN := 2
const HEAVY_CRASH_MIN_RELATIVE_KMH := 45.0
# Compatibility names for old driving snapshots and authored actions.
const CRASH_ENERGY_LOSS := CRASH_STRESS_GAIN
const HEAD_ON_CRASH_ENERGY_LOSS := HEAD_ON_CRASH_STRESS_GAIN
const ONCOMING_WARNING_ENABLED := true
const ONCOMING_WARNING_FLASH_INTERVAL := 0.28 # Seconds per flash cycle.
const ONCOMING_WARNING_BEEPS := 3 # Spawn only after this many warning pulses.
const ONCOMING_SPAWN_EDGE_GAP := 20.0 # Pixels between the screen edge and the car's visible front.
const ONCOMING_GROUP_MIN_VEHICLES := 1
const ONCOMING_GROUP_MAX_VEHICLES := 4
const ONCOMING_GROUP_MIN_GAP := 120.0 # Visible bumper gap between cars in one group.
const ONCOMING_GROUP_MAX_GAP := 220.0
# Hidden per-ride top-lane pressure (0..1): builds faster than it fades.
# Pressure speeds up only the incoming-lane spawn clock, retaining warnings.
const TOP_LANE_PRESSURE_FILL_SECONDS := 8.0
const TOP_LANE_PRESSURE_DECAY_SECONDS := 90.0
const TOP_LANE_PRESSURE_MAX_SPAWN_RATE := 6.0
const CRASH_RECOVERY_SECONDS := 0.45
const CRASH_INVINCIBLE_SECONDS := 1.6
const CRASH_FLICKER_INTERVAL := 0.08
const CRASH_FLICKER_ALPHA := 0.35

# Mechanic and trip-ending crash repairs share the same per-hull rate.
const HULL_REPAIR_COST_PER_POINT := 50
const HULL_REPAIR_AMOUNT := 2
# Garage repairs: one energy buys a session of up to three timed clicks.
const GARAGE_REPAIR_ENERGY_COST := 1
const GARAGE_REPAIR_MAX_ATTEMPTS := 3
const GARAGE_REPAIR_HULL_PER_SUCCESS := 1
const GARAGE_REPAIR_SLIDER_SPEED := 0.75
const GARAGE_REPAIR_CLICK_COOLDOWN_SECONDS := 0.2
const GARAGE_REPAIR_FEEDBACK_SECONDS := 0.8
const GARAGE_REPAIR_SHAKE_PIXELS := 3.0
const GARAGE_REPAIR_SHAKE_SECONDS := 0.16
const CRASH_REPAIR_HULL_RESTORE := 4
const CRASH_REPAIR_FREE_HULL_RESTORE := 1
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

# Player horn: separate taps persuade nearby bottom-lane drivers once per car.
const HORN_PRESS_COOLDOWN := 0.15
const ALMA_TRUCK_HORN_COOLDOWN := 5.0
const ALMA_TRUCK_HORN_TOP_OFFSET := 32.0 # Upward shoulder offset at 720p.
const ALMA_TRUCK_HORN_WAVE_SPEED := 1000.0 # Radius growth in pixels/second at 720p.
const HORN_REPEAT_WINDOW := 2.5
const HORN_MIN_PRESSES := 2
const HORN_MAX_PRESSES := 5
const HORN_RANGE := 350.0
const HORN_IGNORE_CHANCE := 0.30
const HORN_SPEED_CHANCE := 0.35
const HORN_SPEED_BOOST := 160.0
const HORN_MAX_RESPONSE_SPEED := 650.0
const HORN_SPEED_SECONDS := 3.0
const HORN_PULL_OVER_GAP := 18.0
const HORN_YIELD_CLEAR_DISTANCE := 2.0

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

# Stress starts with a 10-point cap; achievements expand it. Hull stays at 10.
# Stress never prevents a ride.
const DEFAULT_STARTING_STRESS := 0
const DEFAULT_MAX_STRESS := 10
const DEFAULT_STARTING_HULL := 10
const DEFAULT_MAX_HULL := 10
const TRIP_STRESS_GAIN := 1
const BETA_BLOCKER_STRESS_SHIELD_POINTS := 3
const REST_STRESS_RELIEF := 2
const NIGHT_SLEEP_STRESS_RELIEF := 4
const STRESS_WARNING_THRESHOLD := 7
const HIGH_STRESS_THRESHOLD := 7
const STRESS_MODIFIER_DELTAS := {
	"player_acceleration_x": -0.50,
	"player_max_speed": -0.40,
	"player_brake_x": -0.30,
	"player_lane_lerp_x": -0.60,
	"player_coast_x": 0.40,
	"player_wiggle_intensity_x": 0.60,
}
const DEFAULT_STARTING_GAS_PERCENT := 100.0
const DEFAULT_MAX_GAS_PERCENT := 100.0
const LOW_GAS_PERCENT_THRESHOLD := 20.0
const MIN_BOOST_GAS_PERCENT := 0.05
const GAS_DRAIN_PERCENT_PER_1000_UNITS := 5.0
# Energy is an independent action budget; stress alone affects handling.
const DEFAULT_STARTING_ENERGY := 5
const DEFAULT_MAX_ENERGY := 5
const TRIP_ENERGY_COST := 1
const MAP_TRAVEL_ENERGY_COST := 1
const CONSTRUCTION_WORK_ENERGY_COST := 2
const CONSTRUCTION_WORK_BASE_PAY := 500
# Tropa's higher rate is captured when construction work is unlocked.
const CONSTRUCTION_WORK_PAY := 750
const CONSTRUCTION_WORK_PRESENTATION_SECONDS := 3.0
const PARK_STRESS_RELIEF := 2
const CHURCH_STRESS_RELIEF := 2
const MAKADIYOS_CHURCH_STRESS_RELIEF := 3
const CHARACTER_INTERACTION_STRESS_RELIEF := 1
const CHARACTER_INTERACTION_STRESS_RELIEF_BY_LOCATION := {
	"hospital": 2,
	"bar": 2,
}
const REST_ENERGY_RESTORE := 2
const FOOD_MAX_ENERGY_RESTORE := 2
const CRITICAL_ENERGY_WARNING_THRESHOLD := 2

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
const YOSI_STRESS_RELIEF := 1
const SMOKER_YOSI_STRESS_RELIEF := 3
const YOSI_ENERGY_RESTORE := YOSI_STRESS_RELIEF
const SMOKER_YOSI_ENERGY_RESTORE := SMOKER_YOSI_STRESS_RELIEF
const SMOKER_YOSI_GOAL := 10 # Purchases in one day to unlock smoker.
const SMOKER_STRESS_PENALTY := 2
const SMOKER_MAX_ENERGY_PENALTY := SMOKER_STRESS_PENALTY
const SMOKER_DANGER_YOSI_TOTAL := 50 # Lifetime purchases causing run failure.

# Optional owner portraits. Use a res:// image path; empty paths leave the
# reserved portrait panel blank. Each image keeps its proportions.
const STORE_OWNER_PORTRAITS := {
	"tricycle": {"path": "res://assets/characters/mechanic_store.png", "flip_h": false},
	"food": {"path": "res://assets/characters/Karen_lady.png", "flip_h": false},
	"bar": {"path": "res://assets/characters/almashop.png", "flip_h": false},
	"hospital": {"path": "res://assets/characters/celinashop.png", "flip_h": false},
}

# Store inventory, in display order.
# Upgrade price = cost + current_level * cost_step. max_level controls purchase
# limits and the tier display. Consumables can restore energy, relieve stress,
# or do both. Energy-restoring food costs more than the stress-only snacks;
# FOOD_MAX_ENERGY_RESTORE caps each purchase. Warlboro remains risky stress relief.
const STORE_ITEMS := [
	{
		"id": "gas_can",
		"name": "Gas Can",
		"description": "Add {gas}% gas",
		"type": "gas",
		"gas": GAS_CAN_PERCENT,
	},
	{
		"id": "hull_repair",
		"name": "Tricycle Repairs",
		"description": "Restore {hull} hull",
		"cost": HULL_REPAIR_COST_PER_POINT * HULL_REPAIR_AMOUNT,
		"type": "repair",
		"hull": HULL_REPAIR_AMOUNT,
	},
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
		"description": "Reduce stress. May cause negative effects",
		"cost": 15,
		"type": "stress_relief",
		"stress_relief": YOSI_STRESS_RELIEF,
	},

	{
		"id": "turon",
		"name": "Turon",
		"description": "Sweet banana snack. Reduce {stress_relief} stress",
		"cost": 30,
		"type": "stress_relief",
		"stress_relief": 1,
	},
	{
		"id": "energy_snack",
		"name": "Snack Bar",
		"description": "A quick energy boost. Restore {energy_restore} energy",
		"cost": 80,
		"type": "stress_relief",
		"energy_restore": 1,
		"stress_relief": 0,
	},
	{
		"id": "lugaw",
		"name": "Lugaw",
		"description": "Warm rice porridge. Reduce {stress_relief} stress",
		"cost": 75,
		"type": "stress_relief",
		"stress_relief": 3,
	},
	{
		"id": "pancit",
		"name": "Pancit",
		"description": "Stir-fried noodles. Restore {energy_restore} energy and reduce {stress_relief} stress",
		"cost": 120,
		"type": "stress_relief",
		"energy_restore": 1,
		"stress_relief": 2,
	},
	{
		"id": "full_meal",
		"name": "Budget Meal",
		"description": "A filling rice meal. Restore {energy_restore} energy",
		"cost": 150,
		"type": "stress_relief",
		"energy_restore": 2,
		"stress_relief": 0,
	},
	{
		"id": "lomi",
		"name": "Lomi",
		"description": "Hearty noodle soup. Restore {energy_restore} energy and reduce {stress_relief} stress",
		"cost": 180,
		"type": "stress_relief",
		"energy_restore": 2,
		"stress_relief": 4,
	},
]

# Nighttime bar drinks cost more than food, with better value for larger relief.
# They are consumed immediately and restore stress only, never action energy.
const BAR_DISCOUNT := 0.10
const BAR_ITEMS := [
	{
		"id": "bar_beer",
		"name": "San Mig Right",
		"description": "A legally distinct brand. Reduce up to {stress_relief} stress",
		"cost": 120,
		"type": "liquor",
		"stress_relief": 3,
	},
	{
		"id": "bar_rum",
		"name": "Lead Horse",
		"description": "Stronger than your average beer. Reduce up to {stress_relief} stress",
		"cost": 220,
		"type": "liquor",
		"stress_relief": 6,
	},
	{
		"id": "bar_whiskey",
		"name": "Antonov Vodka",
		"description": "Forget all your problems. Reduce up to {stress_relief} stress",
		"cost": 350,
		"type": "liquor",
		"stress_relief": 10,
	},
]

# First aid shares the action-resource caps; its daily claim is per calendar day.
# Beta blockers protect the next ride only and cannot stack with an existing dose.
const HOSPITAL_ITEMS := [
	{
		"id": "hospital_first_aid",
		"name": "Basic First Aid",
		"description": "Restore {energy_restore} energy and reduce {stress_relief} stress. Once per day",
		"cost": 150,
		"type": "first_aid",
		"energy_restore": 1,
		"stress_relief": 3,
	},
	{
		"id": "hospital_beta_blockers",
		"name": "Beta Blockers",
		"description": "Block the next {stress_shield} stress gained during your next ride only. Applies immediately; does not stack",
		"cost": 180,
		"type": "stress_shield",
		"stress_shield": BETA_BLOCKER_STRESS_SHIELD_POINTS,
	},
]
