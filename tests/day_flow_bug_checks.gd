extends RefCounted


static func run() -> void:
	# The rollover decision must use the phase before mutating the clock.
	for mode in [PlayerState.TRANSITION_RIDE, PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY, PlayerState.TRANSITION_REST_TO_NEXT_DAY]:
		PlayerState.reset()
		PlayerState.current_day = 7
		PlayerState.current_phase = "noon" if mode == PlayerState.TRANSITION_REST_TO_NEXT_DAY else "night"
		PlayerState.money = 6000
		var saves: int = PlayerState.get_meta("test_save_count", 0)
		PlayerState.advance_to_next_stage(mode, "long", "traffic-jam")
		assert(PlayerState.get_current_day() == 8 and PlayerState.get_current_time_of_day() == "morning")
		assert(PlayerState.last_debt_collection_day == 8, "%s must collect debt when entering Day 8" % mode)
		assert(PlayerState.money == 3500 and PlayerState.remaining_debt == 47500)
		assert(PlayerState.current_stage_type == "long-morning-traffic-jam")
		assert(PlayerState.get_meta("test_save_count", 0) - saves == 1, "Day, weather and debt must persist in one snapshot")
		PlayerState.advance_to_next_stage(PlayerState.TRANSITION_CURRENT_STAGE)
		assert(PlayerState.money == 3500, "Collection cannot repeat within the same day")

	PlayerState.reset()
	PlayerState.current_day = 7
	PlayerState.current_phase = "noon"
	PlayerState.pending_skip_night_phase = true
	PlayerState.money = 6000
	PlayerState.advance_to_next_stage(PlayerState.TRANSITION_RIDE)
	assert(PlayerState.get_current_day() == 8 and PlayerState.last_debt_collection_day == 8)
	assert(not PlayerState.pending_skip_night_phase and PlayerState.money == 3500)

	PlayerState.reset()
	PlayerState.current_day = 14
	PlayerState.current_phase = "night"
	PlayerState.debt_goal_index = 1
	PlayerState.money = 100
	PlayerState.advance_to_next_stage(PlayerState.TRANSITION_RIDE)
	assert(PlayerState.get_current_day() == 15 and PlayerState.is_run_failed(), "Unpaid later collections must end the run at rollover")
	PlayerState.reset()
	PlayerState.energy = 3
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	assert(PlayerState.prepare_stage_start("short-morning-chill"))
	assert(PlayerState.energy == 2 and PlayerState.pending_stage_energy_cost)
	assert(PlayerState.get_meta("test_save_count", 0) - saves == 1, "Trip charge and its paid flag must save together")
	assert(PlayerState.prepare_stage_start("short-morning-chill"))
	assert(PlayerState.energy == 2 and PlayerState.get_meta("test_save_count", 0) - saves == 1)
	PlayerState.reset()
	PlayerState.energy = 0
	saves = PlayerState.get_meta("test_save_count", 0)
	var bonus: int = PlayerState.get_transition_energy_bonus(PlayerState.TRANSITION_REST_TO_NIGHT)
	assert(PlayerState.prepare_stage_start_after_transition("short-night-chill", PlayerState.TRANSITION_REST_TO_NIGHT))
	assert(PlayerState.energy == bonus - 1 and PlayerState.pending_stage_energy_cost)
	assert(PlayerState.get_meta("test_save_count", 0) - saves == 1, "Rest recovery and trip entry must form one resumable snapshot")
	PlayerState.reset()
	print("PASS: day rollover collects debt exactly once, respects night skips, and saves the completed transition together")
