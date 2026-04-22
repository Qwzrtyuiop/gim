extends RefCounted
class_name PlayerStageFlow


static func normalize_transition_mode(player_state, transition_mode: String) -> String:
	match transition_mode:
		player_state.TRANSITION_CURRENT_STAGE, player_state.TRANSITION_REST_TO_NIGHT, player_state.TRANSITION_REST_TO_NEXT_DAY, player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
			return transition_mode
	return player_state.TRANSITION_RIDE


static func next_stage_time(player_state, transition_mode: String) -> String:
	var safe_transition_mode := normalize_transition_mode(player_state, str(transition_mode))
	var current_time: String = player_state.get_current_time_of_day()

	if safe_transition_mode == player_state.TRANSITION_CURRENT_STAGE:
		return current_time
	if player_state._should_skip_night_phase_transition(safe_transition_mode, current_time):
		return "morning"
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NIGHT and current_time == "morning":
		return "night"
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY and current_time == "noon":
		return "morning"
	if safe_transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		return "morning"

	match current_time:
		"morning":
			return "noon"
		"noon":
			return "night"
	return "morning"


static func will_advance_day(player_state, transition_mode: String) -> bool:
	var safe_transition_mode := normalize_transition_mode(player_state, str(transition_mode))
	if player_state._should_skip_night_phase_transition(safe_transition_mode, player_state.get_current_time_of_day()):
		return true
	if safe_transition_mode == player_state.TRANSITION_REST_TO_NEXT_DAY or safe_transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		return true
	return safe_transition_mode == player_state.TRANSITION_RIDE and player_state.get_current_time_of_day() == "night"


static func transition_energy_bonus(player_state, transition_mode: String) -> int:
	var safe_transition_mode := normalize_transition_mode(player_state, str(transition_mode))
	if safe_transition_mode == player_state.TRANSITION_SLEEP_TO_NEXT_DAY:
		return 0
	var energy_bonus := int(player_state.REST_ENERGY_BONUSES.get(safe_transition_mode, 0))
	if will_advance_day(player_state, safe_transition_mode):
		energy_bonus += player_state.END_OF_DAY_ENERGY_BONUS
	return energy_bonus
