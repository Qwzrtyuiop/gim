extends RefCounted


static func pay_story_principal(player_state, amount: int) -> int:
	# Voluntary payments reduce principal, not the calendar collection history.
	var paid: int = mini(maxi(0, amount), mini(maxi(0, player_state.money), maxi(0, player_state.remaining_debt)))
	if paid <= 0:
		return 0
	player_state._begin_state_batch()
	player_state.spend_money(paid)
	player_state.remaining_debt -= paid
	player_state.save_progress()
	player_state._end_state_batch()
	return paid


static func forgive_story_principal(player_state, amount: int) -> int:
	var forgiven: int = mini(maxi(0, amount), maxi(0, player_state.remaining_debt))
	if forgiven <= 0:
		return 0
	player_state.remaining_debt -= forgiven
	player_state.save_progress()
	return forgiven


static func current_weekly_goal(player_state) -> int:
	if player_state.remaining_debt <= 0:
		return 0
	if player_state.WEEKLY_DEBT_GOALS.is_empty():
		return 0

	var goal_index: int = clampi(player_state.debt_goal_index, 0, player_state.WEEKLY_DEBT_GOALS.size() - 1)
	return mini(int(player_state.WEEKLY_DEBT_GOALS[goal_index]) + player_state.debt_carryover, player_state.remaining_debt)


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

	var goal_amount: int = current_weekly_goal(player_state)
	if goal_amount <= 0:
		player_state.last_debt_collection_day = day_number
		player_state.save_progress()
		return true
	var is_first_collection: bool = day_number == player_state.DEBT_COLLECTION_INTERVAL_DAYS + 1
	if player_state.money < goal_amount and not is_first_collection:
		player_state.last_debt_collection_day = day_number
		player_state.run_failed = true
		player_state.run_fail_reason = "Debt collector came for PhP %d on Day %d. Hold R to reset progress." % [
			goal_amount,
			day_number,
		]
		player_state.save_progress()
		return false

	player_state._begin_state_batch()
	player_state.last_debt_collection_day = day_number
	var paid: int = mini(maxi(0, player_state.money), goal_amount)
	player_state.spend_money(paid)
	if paid == goal_amount and player_state.debt_goal_index == 0 and player_state.non_gas_store_purchases_this_week == 0:
		player_state.unlock_achievement("matipid")
	player_state.remaining_debt = maxi(0, player_state.remaining_debt - paid)
	player_state.debt_carryover = goal_amount - paid
	player_state.non_gas_store_purchases_this_week = 0
	if player_state.debt_goal_index < player_state.WEEKLY_DEBT_GOALS.size() - 1:
		player_state.debt_goal_index += 1
	player_state.last_debt_collection = {
		"day": day_number, "previous_goal": goal_amount, "paid": paid,
		"carryover": player_state.debt_carryover,
		"next_goal": current_weekly_goal(player_state),
	}
	if is_first_collection:
		player_state.set_event_value("week_1_debt_transition", player_state.last_debt_collection.duplicate(true))
	player_state.save_progress()
	player_state._end_state_batch()
	return true


static func collect_first_week_interest(player_state, amount: int) -> void:
	var report: Dictionary = player_state.last_debt_collection
	if int(report.get("day", 0)) != player_state.DEBT_COLLECTION_INTERVAL_DAYS + 1 or report.has("interest_paid"):
		return
	player_state._begin_state_batch()
	var paid: int = mini(maxi(0, amount), maxi(0, player_state.money))
	player_state.spend_money(paid)
	report["interest_paid"] = paid
	player_state.save_progress()
	player_state._end_state_batch()


static func first_week_transition_report(player_state) -> Dictionary:
	var saved_report: Dictionary = player_state.event_values.get("week_1_debt_transition", {})
	if not saved_report.is_empty():
		return saved_report.duplicate(true)
	# Unseen memory previews may show an outcome without collecting real money.
	var old_goal: int = int(player_state.WEEKLY_DEBT_GOALS[0])
	var paid: int = mini(maxi(0, player_state.money), old_goal)
	return {
		"previous_goal": old_goal, "paid": paid, "carryover": old_goal - paid,
		"next_goal": int(player_state.WEEKLY_DEBT_GOALS[1]) + old_goal - paid,
	}


static func reset_debt_and_failure_state(player_state) -> void:
	player_state.debt_goal_index = 0
	player_state.debt_carryover = 0
	player_state.last_debt_collection.clear()
	player_state.last_debt_collection_day = 0
	player_state.remaining_debt = player_state.TOTAL_DEBT_GOAL
	player_state.run_failed = false
	player_state.run_fail_reason = ""
