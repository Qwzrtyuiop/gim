extends RefCounted

# Narrative time uses calendar rules, not ride advancement or its entry costs.
const MAX_DAYS := 365
const MAX_PHASES := MAX_DAYS * 3


static func advance(player_state, options: Dictionary) -> bool:
	if not validation_error(options).is_empty() or player_state.is_run_failed():
		return false
	if not player_state.pending_crash_repair.is_empty() or not player_state.active_event_special_stage.is_empty():
		return false
	var result: Dictionary = player_state.last_stage_result
	if (
		not bool(result.get("paid_out", false))
		and not str(result.get("random_ride_event", "")).is_empty()
		and str(result.get("random_ride_outcome", "")).is_empty()
	):
		# The author must resolve the fare choice before replacing its results flow.
		return false

	player_state._begin_state_batch()
	player_state.claim_last_stage_total()
	player_state.pending_trip_selection.clear()
	player_state.pending_sleep_transition_state.clear()
	player_state.pending_stage_energy_cost = false
	player_state.pending_skip_night_phase = false
	player_state.pending_result_music.clear()
	player_state.pending_gameplay_entry_fade_duration = 0.0
	player_state.current_stage_special_type = player_state.STAGE_SPECIAL_TYPE_NONE
	player_state.current_special_stage_id = ""

	if options.has("days"):
		var days: int = int(options.days)
		for day_offset in range(days):
			player_state.prepare_day_start(player_state.get_current_day() + 1)
			if player_state.is_run_failed():
				break
	else:
		var phases: int = int(options.phases)
		for phase_offset in range(phases):
			var phase_index: int = player_state.STAGE_TIMES.find(player_state.get_current_time_of_day())
			if phase_index == player_state.STAGE_TIMES.size() - 1:
				player_state.prepare_day_start(player_state.get_current_day() + 1)
			else:
				player_state.set_current_stage_time(player_state.STAGE_TIMES[phase_index + 1])
			if player_state.is_run_failed():
				break

	# Conditions and story text read this snapshot without calling weather getters.
	# Refresh it for the reached phase, including phase-only skips on the same date.
	player_state.current_weather = player_state.get_stage_weather(player_state.get_current_time_of_day())
	if not player_state.is_run_failed():
		if bool(options.get("restore_energy", false)):
			player_state.energy = player_state.max_energy
		elif int(options.get("recover_energy", 0)) > 0:
			player_state.add_energy(int(options.recover_energy))
	player_state.save_progress()
	player_state._end_state_batch()
	# A crossed collection can fail the run; the time still advanced and must route out.
	return true


static func validation_error(options: Dictionary) -> String:
	if options.has("days") == options.has("phases"):
		return "advance_time needs exactly one of days or phases."
	var count_key := "days" if options.has("days") else "phases"
	var maximum := MAX_DAYS if count_key == "days" else MAX_PHASES
	if not _is_whole_number(options[count_key], 1, maximum):
		return "advance_time %s must be an integer between 1 and %d." % [count_key, maximum]
	if options.has("recover_energy") and not _is_whole_number(options.recover_energy, 0, 2147483647):
		return "advance_time recover_energy must be a nonnegative integer."
	if options.has("restore_energy") and not options.restore_energy is bool:
		return "advance_time restore_energy must be true or false."
	if bool(options.get("restore_energy", false)) and int(options.get("recover_energy", 0)) > 0:
		return "advance_time uses either recover_energy or restore_energy, not both."
	return ""


static func _is_whole_number(value, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum and floor(number) == number
