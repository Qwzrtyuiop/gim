extends RefCounted

# Builds terminal presentation from existing locked passenger pools.
const RIDE_SELECT_BGM_PATH := "res://assets/audio/music/driving/normalstage1.mp3"
const RAINY_NIGHT_BGM_PATH := "res://assets/audio/music/driving/night_station.mp3"
const CharacterAvailability := preload("res://scripts/story/character_availability.gd")
const RainAudioProfile := preload("res://scripts/audio/rain_audio_profile.gd")
const MidnightEncounters := preload("res://scripts/ride_selection/midnight_encounters.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const PickupAssignment := preload("res://scripts/ride_selection/passenger_pickup_assignment.gd")
const RISK_DISTANCE_SCORES := {"short": 1, "medium": 2, "long": 3}
const RISK_TIME_SCORES := {"morning": 1, "noon": 2, "night": 3}
const RISK_TRAFFIC_SCORES := {"chill": 1, "normal": 2, "traffic-jam": 2, "trafficjam": 2, "speeders": 3, "speeder": 3, "busy": 4}

var screen
var bgm_player: AudioStreamPlayer


func _init(selection_screen) -> void:
	screen = selection_screen


func offers(location_id := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not PlayerState.are_passengers_available():
		return MidnightEncounters.offers(PlayerState) if location_id in ["", "station"] else result
	var seen: Dictionary = {}
	var phase: String = PlayerState.get_next_stage_time(screen._transition_mode())
	if phase == "night" and location_id in ["market", "street"]:
		return result
	for distance: String in PlayerState.STAGE_DIFFICULTIES:
		if screen._is_forced_first_day_ride() and distance != "short":
			continue
		var pool: Array = screen.locked_character_pools.get(distance, [])
		for slot in range(pool.size()):
			if not pool[slot] is Dictionary:
				continue
			var character: Dictionary = pool[slot]
			var id := str(character.get("id", ""))
			if character.is_empty() or id.is_empty() or seen.has(id):
				continue
			if not location_id.is_empty() and PickupAssignment.location(character) != location_id:
				continue
			# Live schedules cover older locked saves and Jessa's intro gate.
			var live: Dictionary = PlayerState.get_character_by_id(id)
			if not CharacterAvailability.supports_time(live if not live.is_empty() else character, phase, screen._display_day()):
				continue
			seen[id] = true
			var locked := character.duplicate(true)
			locked["active_distance"] = distance
			result.append({
				"character": locked,
				"distance": distance,
				"slot": slot,
				"details": details(locked, distance),
				"summary": summary(locked, distance),
			})
	return result


func summary(character: Dictionary, distance: String) -> Dictionary:
	var id := str(character.get("id", ""))
	var phase: String = PlayerState.get_next_stage_time(screen._transition_mode())
	var traffic := str(character.get("stage_traffic", "chill"))
	var stage: String = PlayerState.build_stage_type(distance, phase, traffic)
	var score := int(RISK_DISTANCE_SCORES.get(distance, 1)) + int(RISK_TIME_SCORES.get(phase, 1)) + int(RISK_TRAFFIC_SCORES.get(traffic, 2))
	var risk := "LOW" if score <= 5 else ("MODERATE" if score <= 7 else "HIGH")
	var badge := ""
	match PlayerState.normalize_stage_special_type(str(character.get("stage_special_type", ""))):
		PlayerState.STAGE_SPECIAL_TYPE_URGENT:
			badge = "RUSH"
		PlayerState.STAGE_SPECIAL_TYPE_CAREFUL:
			badge = "CAREFUL"
		PlayerState.STAGE_SPECIAL_TYPE_SPECIAL:
			badge = "SPECIAL"
	return {
		"name": PlayerState.get_character_display_name(id),
		"distance": distance.capitalize(),
		"phase": phase.capitalize(),
		"traffic": traffic.capitalize(),
		"badge": badge,
		"fare": "PHP %d" % PlayerState.estimate_stage_earnings(stage, id),
		"fuel": "~%.1f%%" % PlayerState.estimate_stage_gas_usage(stage),
		"risk": risk,
		"energy_cost": GameTuning.TRIP_ENERGY_COST,
		"stress_gain": GameTuning.TRIP_STRESS_GAIN,
	}


func details(character: Dictionary, distance: String) -> String:
	var trip := summary(character, distance)
	return "%s\n%s / %s / %s%s\nEstimated fare: %s   Fuel: %s   Risk: %s\nEnergy -%d / Stress +%d" % [
		trip.name, trip.distance, trip.phase, trip.traffic,
		" / " + str(trip.badge) if not str(trip.badge).is_empty() else "",
		trip.fare, trip.fuel, trip.risk,
		trip.energy_cost, trip.stress_gain,
	]


func refresh_terminal() -> void:
	refresh_bgm()
	screen.terminal_view.set_pickup_location(screen.pickup_location)
	screen.terminal_view.set_offers(screen.terminal_offers, PlayerState.get_next_stage_time(screen._transition_mode()) == "night")
	if screen.passenger_overlay.visible:
		screen.status_header.set_display_time(screen._display_day(), PlayerState.get_next_stage_time(screen._transition_mode()))
	if PlayerState.are_passengers_available() and screen._needs_refuel():
		screen.status_label.text = "Not enough gas. Visit the store to refuel."
	else:
		screen.status_label.text = ""


func start_ride_select_bgm() -> void:
	if bgm_player != null and is_instance_valid(bgm_player):
		return
	bgm_player = HubMusicManager.player
	refresh_bgm()


func refresh_bgm() -> void:
	if bgm_player == null or not is_instance_valid(bgm_player):
		return
	var weather := PlayerState.get_current_weather()
	var bar_active: bool = screen.travel_map != null and screen.travel_map.bar_audio != null and screen.travel_map.bar_audio.active
	var blocked: bool = PlayerState.is_midnight() or bar_active or (screen.idle_music != null and screen.idle_music.active)
	bgm_player = HubMusicManager.request_track(HubMusicManager.background_path(), RainAudioProfile.music_duck_db(weather), blocked)
