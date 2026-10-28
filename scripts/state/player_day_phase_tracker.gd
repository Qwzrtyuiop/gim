extends RefCounted

const DEFAULT_PHASE := "morning"


static func normalize_phase(player_state, phase: String) -> String:
	var safe_phase: String = str(phase).strip_edges().to_lower()
	if player_state.STAGE_TIMES.has(safe_phase):
		return safe_phase
	return DEFAULT_PHASE


static func phase_from_stage_type(player_state, stage_type: String) -> String:
	var parts: PackedStringArray = str(stage_type).split("-")
	if parts.size() >= 2:
		return normalize_phase(player_state, parts[1])
	return DEFAULT_PHASE


static func get_current_phase(player_state) -> String:
	var safe_phase: String = normalize_phase(player_state, str(player_state.current_phase))
	if player_state.current_phase != safe_phase:
		player_state.current_phase = safe_phase
	return safe_phase


static func get_current_day(player_state) -> int:
	return maxi(1, int(player_state.current_day))


static func is_midnight(player_state) -> bool:
	# Midnight is the spent night slot, not another drivable phase. The dated
	# saved result also applies this rule to existing saves without a new field.
	if get_current_phase(player_state) != "night":
		return false
	if int(player_state.get_event_value("night_phase_consumed_day", 0)) == get_current_day(player_state):
		return true
	var result: Dictionary = player_state.last_stage_result
	if int(result.get("day", 0)) != get_current_day(player_state):
		return false
	return str(result.get("time_of_day", "")) == "night" or str(result.get("bayanihan_skipped_phase", "")) == "night"


static func passengers_available(player_state) -> bool:
	if is_midnight(player_state):
		return false
	# Walking through home cannot bypass an evening already reserved by a story.
	return not (get_current_phase(player_state) == "night" and player_state.pending_skip_night_phase)


static func hub_time_name(player_state, day := -1, phase := "") -> String:
	var display_day: int = get_current_day(player_state) if day < 1 else day
	var display_phase: String = get_current_phase(player_state) if phase.is_empty() else phase
	if display_day == get_current_day(player_state) and display_phase == "night" and is_midnight(player_state):
		return "Midnight"
	return display_phase.capitalize()


static func stage_type_for_phase(player_state, stage_type: String, phase: String) -> String:
	var stage_parts: Dictionary = player_state._parse_stage_type(stage_type)
	return player_state.build_stage_type(
		str(stage_parts.get("difficulty", "short")),
		normalize_phase(player_state, phase),
		str(stage_parts.get("traffic", "chill"))
	)


static func sync_stage_type_to_phase(player_state) -> void:
	player_state.current_phase = get_current_phase(player_state)
	player_state.current_stage_type = stage_type_for_phase(
		player_state,
		player_state.current_stage_type,
		player_state.current_phase
	)


static func set_phase(player_state, phase: String) -> void:
	player_state.current_phase = normalize_phase(player_state, phase)
	sync_stage_type_to_phase(player_state)


static func next_phase(player_state, transition_mode: String) -> String:
	var safe_transition_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	var current_phase: String = get_current_phase(player_state)

	if safe_transition_mode == player_state.TRANSITION_CURRENT_STAGE:
		return current_phase
	if player_state._should_skip_night_phase_transition(safe_transition_mode, current_phase):
		return DEFAULT_PHASE
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NIGHT and current_phase == "morning":
		return "night"
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY and current_phase == "noon":
		return DEFAULT_PHASE
	if safe_transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		return DEFAULT_PHASE

	match current_phase:
		"morning":
			return "noon"
		"noon":
			return "night"
	return DEFAULT_PHASE


static func will_advance_day(player_state, transition_mode: String) -> bool:
	var safe_transition_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	var current_phase: String = get_current_phase(player_state)
	if player_state._should_skip_night_phase_transition(safe_transition_mode, current_phase):
		return true
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY or safe_transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		return true
	return safe_transition_mode == player_state.TRANSITION_RIDE and current_phase == "night"


static func transition_display_day(player_state, transition_mode: String) -> int:
	var display_day: int = get_current_day(player_state)
	if will_advance_day(player_state, transition_mode):
		display_day += 1
	return maxi(1, display_day)


static func transition_stress_relief(player_state, transition_mode: String) -> int:
	var safe_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	# Sleep applies its four-point relief once at the existing sleep midpoint.
	return int(player_state.REST_STRESS_RELIEF.get(safe_mode, 0))


static func transition_energy_bonus(player_state, transition_mode: String) -> int:
	var safe_mode: String = player_state.normalize_transition_mode(str(transition_mode))
	return int(player_state.REST_ENERGY_BONUSES.get(safe_mode, 0))


static func home_ride_transition_mode(player_state) -> String:
	return player_state.TRANSITION_CURRENT_STAGE


static func advance_after_stage_result(player_state, completed_phase: String) -> bool:
	var safe_completed_phase: String = normalize_phase(player_state, completed_phase)
	if get_current_phase(player_state) != safe_completed_phase:
		return false

	var next_phase: String = ""
	match safe_completed_phase:
		"morning":
			next_phase = "noon"
		"noon":
			next_phase = "night"
		_:
			return false

	set_phase(player_state, next_phase)
	return true
