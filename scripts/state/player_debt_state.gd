extends RefCounted


static func current_weekly_goal(player_state) -> int:
	if player_state.remaining_debt <= 0:
		return 0
	if player_state.WEEKLY_DEBT_GOALS.is_empty():
		return 0

	var goal_index: int = clampi(player_state.debt_goal_index, 0, player_state.WEEKLY_DEBT_GOALS.size() - 1)
	return mini(int(player_state.WEEKLY_DEBT_GOALS[goal_index]), player_state.remaining_debt)


static func days_until_debt_collection(player_state, day_number: int = -1) -> int:
	var effective_day: int = int(day_number) if int(day_number) > 0 else player_state.get_current_day()
	var cycle_day: int = ((effective_day - 1) % player_state.DEBT_COLLECTION_INTERVAL_DAYS) + 1
	return player_state.DEBT_COLLECTION_INTERVAL_DAYS - cycle_day + 1


static func week_number(player_state, day_number: int = -1) -> int:
	var effective_day: int = int(day_number) if int(day_number) > 0 else player_state.get_current_day()
	return maxi(1, int(floor(float(maxi(1, effective_day) - 1) / float(player_state.DEBT_COLLECTION_INTERVAL_DAYS))) + 1)


static func debt_status_text(player_state, day_number: int = -1) -> String:
	return "WEEKLY GOAL: PhP %d\nDebt Remaining: PhP %d     %s" % [
		current_weekly_goal(player_state),
		player_state.get_total_debt_goal(),
		debt_due_text(player_state, day_number),
	]


static func debt_due_text(player_state, day_number: int = -1) -> String:
	var days_left: int = days_until_debt_collection(player_state, day_number)
	if days_left <= 0:
		return "Collection Day."
	var day_label: String = "day" if days_left == 1 else "days"
	return "Debt due in %d %s" % [
		days_left,
		day_label,
	]


static func should_collect_for_day(player_state, day_number: int) -> bool:
	return day_number > 1 and ((day_number - 1) % player_state.DEBT_COLLECTION_INTERVAL_DAYS) == 0


static func resolve_collection_for_day(player_state, day_number: int) -> bool:
	if player_state.last_debt_collection_day == day_number:
		return not player_state.run_failed
	if not should_collect_for_day(player_state, day_number):
		return true

	player_state.last_debt_collection_day = day_number
	var goal_amount: int = current_weekly_goal(player_state)
	if goal_amount <= 0:
		return true
	if player_state.money < goal_amount:
		player_state.run_failed = true
		player_state.run_fail_reason = "Debt collector came for PhP %d on Day %d. Hold R to reset progress." % [
			goal_amount,
			day_number,
		]
		player_state.save_progress()
		return false

	player_state.spend_money(goal_amount)
	if player_state.debt_goal_index == 0 and player_state.non_gas_store_purchases_this_week == 0:
		player_state.unlock_achievement("matipid")
	player_state.remaining_debt = maxi(0, player_state.remaining_debt - goal_amount)
	player_state.non_gas_store_purchases_this_week = 0
	if player_state.debt_goal_index < player_state.WEEKLY_DEBT_GOALS.size() - 1:
		player_state.debt_goal_index += 1
	player_state.save_progress()
	return true


static func reset_debt_and_failure_state(player_state) -> void:
	player_state.debt_goal_index = 0
	player_state.last_debt_collection_day = 0
	player_state.remaining_debt = player_state.TOTAL_DEBT_GOAL
	player_state.run_failed = false
	player_state.run_fail_reason = ""
