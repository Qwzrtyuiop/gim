extends RefCounted

# Job progress uses the existing event ledger: reset, slots and older-save
# defaults are handled by the same version-5 codec as other local activities.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const UNLOCK_EVENT := "construction_work_unlocked"
const PAY_EVENT := "construction_work_pay"
const LAST_WORK_DAY := "construction_work_last_day"
const ACCEPTED_EVENT := "construction_work_accepted"
const PENDING_EVENT := "construction_work_pending"
const RETURN_EVENT := "hub_story_return"


static func work_pay(state) -> int:
	var saved_pay := int(state.get_event_value(PAY_EVENT, 0))
	if saved_pay > 0:
		return saved_pay
	if bool(state.get_event_value(UNLOCK_EVENT, false)):
		# Older unlocked jobs already promised 750 and have no achievement-at-
		# unlock history. Keep that agreement instead of guessing from Tropa now.
		return GameTuning.CONSTRUCTION_WORK_PAY
	return GameTuning.CONSTRUCTION_WORK_PAY if state.has_achievement("tropa") else GameTuning.CONSTRUCTION_WORK_BASE_PAY


static func can_work(state) -> bool:
	return (
		bool(state.get_event_value(UNLOCK_EVENT, false))
		and int(state.get_event_value(LAST_WORK_DAY, 0)) != state.get_current_day()
		and state.energy >= GameTuning.CONSTRUCTION_WORK_ENERGY_COST
		and not state.is_midnight()
		and not state.is_run_failed()
		and state.pending_story.is_empty()
		and state.pending_memory_replay.is_empty()
		and state.pending_crash_repair.is_empty()
		and state.active_event_special_stage.is_empty()
	)


static func begin_work(state) -> Dictionary:
	var pending: Variant = state.get_event_value(PENDING_EVENT, {})
	if pending is Dictionary and not pending.is_empty():
		return pending.duplicate(true)
	if not bool(state.get_event_value(ACCEPTED_EVENT, false)) or not can_work(state):
		state.set_event_value(ACCEPTED_EVENT, false)
		return {}
	var day: int = state.get_current_day()
	var phase: String = state.get_current_time_of_day()
	state._begin_state_batch()
	if not state.spend_energy(GameTuning.CONSTRUCTION_WORK_ENERGY_COST):
		state._end_state_batch()
		return {}
	state.set_event_value(ACCEPTED_EVENT, false)
	state.set_event_value(LAST_WORK_DAY, day)
	var pay := work_pay(state)
	state.set_event_value(PAY_EVENT, pay)
	state.add_money(pay)
	state.increment_unique_character_progress("benny", 1)
	if phase == "night":
		# Non-driving activities can consume the evening without fabricating a
		# completed ride or overwriting the player's last fare/result.
		state.set_event_value("night_phase_consumed_day", day)
	else:
		state.advance_phase_after_stage_result(phase)
	state.clear_pending_trip_selection()
	state.set_pending_trip_selection("res://scenes/day_start_scene.tscn", state.TRANSITION_CURRENT_STAGE)
	state.stage_round += 1
	var receipt := {
		"day": day,
		"phase_before": phase,
		"phase_after": state.get_hub_time_name(),
		"pay": pay,
		"energy_cost": GameTuning.CONSTRUCTION_WORK_ENERGY_COST,
	}
	state.set_event_value(PENDING_EVENT, receipt)
	state.set_resume_scene("res://scenes/day_start_scene.tscn")
	state._end_state_batch()
	return receipt


static func finish_presentation(state) -> void:
	state._begin_state_batch()
	state.set_event_value(PENDING_EVENT, {})
	state.set_event_value(RETURN_EVENT, {})
	state._end_state_batch()
