extends RefCounted

# Opt-in game effects for story lines and choices. All effects are persistent.
const PlayerResourceState := preload("res://scripts/state/player_resource_state.gd")
const PlayerUpgradeState := preload("res://scripts/state/player_upgrade_state.gd")
const PlayerDebtState := preload("res://scripts/state/player_debt_state.gd")
const PlayerWeatherState := preload("res://scripts/state/player_weather_state.gd")
const RESOURCES := ["money", "stress", "hull", "energy", "gas", "karma"]
const ACTIONS := [
	"set_resource", "change_resource", "add_gas", "spend_gas", "restore_energy",
	"add_stress", "relieve_stress", "damage_hull", "repair_hull",
	"set_upgrade_level", "add_upgrade_level", "increment_event_value",
	"pay_debt", "forgive_debt", "set_weather",
]
const MAX_INT := 9223372036854775807
const MIN_INT := -9223372036854775807 - 1


static func supports(action_type: String) -> bool:
	return action_type in ACTIONS


static func is_persistent(action_type: String) -> bool:
	return supports(action_type)


static func validate(action_data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var action_type := str(action_data.get("type", action_data.get("action", ""))).strip_edges().to_lower()
	if not supports(action_type):
		errors.append("Unknown game effect '%s'" % action_type)
		return errors
	match action_type:
		"set_resource", "change_resource":
			var resource := str(action_data.get("resource", "")).strip_edges().to_lower()
			if resource not in RESOURCES:
				errors.append("resource must be money, energy, stress, hull, gas, or karma")
			var key := "value" if action_type == "set_resource" else "amount"
			if not _is_number(action_data.get(key), resource != "gas"):
				errors.append("%s must be a finite %snumber" % [key, "whole " if resource != "gas" else ""])
		"set_upgrade_level", "add_upgrade_level":
			if PlayerUpgradeState.story_upgrade_definition(str(action_data.get("id", ""))).is_empty():
				errors.append("id must name a configured upgrade")
			var key := "level" if action_type == "set_upgrade_level" else "amount"
			if not _is_number(action_data.get(key), true):
				errors.append("%s must be a finite whole number" % key)
		"increment_event_value":
			if typeof(action_data.get("id")) not in [TYPE_STRING, TYPE_STRING_NAME] or str(action_data.get("id", "")).strip_edges().is_empty():
				errors.append("id is required")
			if not _is_number(action_data.get("amount", 1)):
				errors.append("amount must be a finite number")
		"set_weather":
			var weather := str(action_data.get("weather", "")).strip_edges().to_lower().replace("-", " ").replace("_", " ")
			if weather not in PlayerState.WEATHER_TYPES:
				errors.append("weather must be clear, cloudy, rain, or heavy rain")
		_:
			if action_type in ["restore_energy", "relieve_stress", "repair_hull"] and not action_data.has("amount"):
				return errors
			var whole := action_type in ["restore_energy", "add_stress", "relieve_stress", "damage_hull", "repair_hull", "pay_debt", "forgive_debt"]
			var amount = action_data.get("amount")
			if not _is_number(amount, whole) or (amount != null and _is_number(amount) and amount < 0):
				errors.append("amount must be a finite nonnegative %snumber" % ("whole " if whole else ""))
	return errors


static func run(owner, action_data: Dictionary) -> void:
	if bool(owner.story_payload.get("replay", false)) or bool(owner.story_payload.get("memory_replay", false)):
		return
	var errors := validate(action_data)
	if not errors.is_empty():
		push_warning("Story game effect rejected: %s" % "; ".join(errors))
		return
	var action_type := str(action_data.get("type", action_data.get("action", ""))).strip_edges().to_lower()
	match action_type:
		"set_resource", "change_resource":
			_apply_resource(action_type, action_data)
		"add_gas":
			PlayerState.add_gas(float(action_data.amount))
		"spend_gas":
			if not PlayerState.spend_gas(float(action_data.amount)):
				push_warning("Story spend_gas rejected: not enough fuel")
		"restore_energy":
			PlayerState.add_energy(int(action_data.get("amount", PlayerState.max_energy - PlayerState.energy)))
		"relieve_stress":
			PlayerState.relieve_stress(int(action_data.get("amount", PlayerState.stress)))
		"add_stress":
			PlayerState.add_stress(int(action_data.amount))
		"damage_hull":
			PlayerState.damage_hull(int(action_data.amount))
		"repair_hull":
			PlayerState.repair_hull(int(action_data.get("amount", PlayerState.max_hull - PlayerState.hull)))
		"set_upgrade_level", "add_upgrade_level":
			_apply_upgrade(action_type, action_data)
		"increment_event_value":
			_increment_event(action_data)
		"pay_debt":
			PlayerDebtState.pay_story_principal(PlayerState, int(action_data.amount))
		"forgive_debt":
			PlayerDebtState.forgive_story_principal(PlayerState, int(action_data.amount))
		"set_weather":
			PlayerWeatherState.set_story_weather(PlayerState, str(action_data.weather))


static func _apply_resource(action_type: String, action_data: Dictionary) -> void:
	var resource := str(action_data.resource).strip_edges().to_lower()
	var value = action_data.get("value")
	if action_type == "change_resource":
		var current = _resource_value(resource)
		var amount = action_data.amount if resource == "gas" else int(action_data.amount)
		value = _sum(current, amount)
		if value == null:
			push_warning("Story change_resource rejected: result exceeds numeric range")
			return
	PlayerResourceState.set_story_resource(PlayerState, resource, value)


static func _resource_value(resource: String):
	match resource:
		"money": return PlayerState.money
		"stress": return PlayerState.stress
		"hull": return PlayerState.hull
		"energy": return PlayerState.energy
		"gas": return PlayerState.gas
		"karma": return PlayerState.karma
	return null


static func _apply_upgrade(action_type: String, action_data: Dictionary) -> void:
	var definition := PlayerUpgradeState.story_upgrade_definition(str(action_data.id))
	var level = action_data.get("level")
	if action_type == "add_upgrade_level":
		level = _sum(PlayerState.get_upgrade_level(str(definition.id)), int(action_data.amount))
		if level == null:
			push_warning("Story add_upgrade_level rejected: result exceeds numeric range")
			return
	PlayerUpgradeState.set_story_upgrade_level(PlayerState, str(definition.id), int(level))


static func _increment_event(action_data: Dictionary) -> void:
	var id := str(action_data.id).strip_edges()
	var previous = PlayerState.get_event_value(id, 0)
	if not _is_number(previous):
		push_warning("Story increment_event_value rejected: existing event is not numeric")
		return
	var value = _sum(previous, action_data.get("amount", 1))
	if value == null:
		push_warning("Story increment_event_value rejected: result exceeds numeric range")
		return
	PlayerState.set_event_value(id, value)


static func _is_number(value, whole := false) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return false
	if whole and typeof(value) == TYPE_FLOAT:
		return floor(value) == value and value >= -9223372036854775808.0 and value < 9223372036854775808.0
	return true


static func _sum(left, right):
	if typeof(left) == TYPE_INT and typeof(right) == TYPE_INT:
		if (right > 0 and left > MAX_INT - right) or (right < 0 and left < MIN_INT - right):
			return null
		return left + right
	var result := float(left) + float(right)
	if not is_finite(result):
		return null
	return result
