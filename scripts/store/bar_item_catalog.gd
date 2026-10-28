extends RefCounted

const GameTuning := preload("res://scripts/config/game_tuning.gd")

# StoreItems uses the same catalog contract for every shop.
const ITEMS := GameTuning.BAR_ITEMS
const DISCOUNT_EVENT := "alma_bar_discount_unlocked"


static func discount_active() -> bool:
	return bool(PlayerState.get_event_value(DISCOUNT_EVENT, false))


static func item_cost(item: Dictionary) -> int:
	var base_cost := maxi(0, int(item.get("cost", 0)))
	if not discount_active():
		return base_cost
	return roundi(base_cost * (1.0 - GameTuning.BAR_DISCOUNT))
