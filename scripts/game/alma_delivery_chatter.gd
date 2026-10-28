extends RefCounted

const Geometry := preload("res://scripts/game/vehicle_geometry.gd")
const Entities := preload("res://scripts/game/vehicle_traffic_entities.gd")

# English chatter authored specifically for Alma's Special Delivery ride.
const STAGE_ID := "alma_special_delivery"
const RANDOM_LINES: Array[String] = [
	"C'mon, step on it!",
	"Faster, John! Faster!",
	"We're running out of time!",
	"Move it, people! We've got beer to deliver!",
	"Hey! Watch out for that car!",
	"You're doing great! I think!",
	"Can't this thing go any faster?!",
	"Oh, come on! Why is there so much traffic?!",
	"Honk! Honk! HONK!",
	"Ahahaha! It actually works!",
	"See?! Told you we'd need that horn!",
	"Out of the way! Coming through!",
	"WOOHOO! That's what I'm talking about!",
	"Wait! Not THAT fast!",
	"I know I said hurry, but I'd like to live!",
	"Was that a police car?!",
	"Ah! I think I dropped something!",
	"John! The road! THE ROAD!",
	"We're almost there! Don't slow down now!",
	"If we survive this, drinks are on me!",
]
const REACTIONS := {
	"collision": "JOHN! THE BEER ISN'T WORTH DYING FOR!",
	"dodge": "Nice one!",
	"timer_low": "Oh, we're SO getting fired!",
	"destination": "There! That's the place!",
}
const PRIORITIES := {
	"collision": 100,
	"destination": 60,
	"timer_low": 50,
	"dodge": 30,
}

var _rng := RandomNumberGenerator.new()
var _bag: Array[String] = []
var _last_random_line := ""
var _pending: Array[String] = []
var _reaction_cooldowns: Dictionary = {}
var _active_reaction := ""
var _active_text := ""
var _timer_low_seen := false
var _destination_seen := false
var _dodge_candidates: Dictionary = {}


func _init() -> void:
	_rng.randomize()


static func is_stage(owner) -> bool:
	return owner.special_stage_id == STAGE_ID


func update(owner, controller, delta: float) -> void:
	if not is_stage(owner) or owner.game_state != "playing":
		return
	for key: String in _reaction_cooldowns.keys():
		_reaction_cooldowns[key] = maxf(0.0, float(_reaction_cooldowns[key]) - delta)
	if controller.time_remaining <= 0.0 or controller.current_text != _active_text:
		_active_reaction = ""
	if not _timer_low_seen and owner.time_left <= maxf(10.0, owner.time_limit * 0.15):
		_timer_low_seen = true
		react(owner, controller, "timer_low")
	if not _destination_seen and owner.target_distance > 0.0 and owner.distance >= owner.target_distance * 0.9:
		_destination_seen = true
		react(owner, controller, "destination")
	_update_dodges(owner, controller)
	_flush_reactions(owner, controller)
	if controller.time_remaining <= 0.0 and controller.cooldown_remaining <= 0.0 and _pending.is_empty():
		_active_reaction = ""
		controller._show_line(owner, "alma_delivery", {
			"text": _next_random_line(),
			"cooldown": _rng.randf_range(5.0, 8.0),
		})
		_active_text = controller.current_text


func react(owner, controller, trigger: String) -> void:
	if not is_stage(owner) or owner.game_state != "playing" or not REACTIONS.has(trigger):
		return
	if float(_reaction_cooldowns.get(trigger, 0.0)) > 0.0 or _pending.has(trigger):
		return
	_reaction_cooldowns[trigger] = 6.0 if trigger == "dodge" else 1.5
	_pending.append(trigger)
	_flush_reactions(owner, controller)


func reset() -> void:
	_bag.clear()
	_last_random_line = ""
	_pending.clear()
	_reaction_cooldowns.clear()
	_active_reaction = ""
	_active_text = ""
	_timer_low_seen = false
	_destination_seen = false
	_dodge_candidates.clear()


func _flush_reactions(owner, controller) -> void:
	if _pending.is_empty():
		return
	var next_index := 0
	for index in range(1, _pending.size()):
		if int(PRIORITIES[_pending[index]]) > int(PRIORITIES[_pending[next_index]]):
			next_index = index
	var trigger: String = _pending[next_index]
	if controller.time_remaining > 0.0 and not _active_reaction.is_empty():
		if int(PRIORITIES[trigger]) <= int(PRIORITIES[_active_reaction]):
			return
		# Milestones must still be heard if a collision/horn interrupts them.
		if _active_reaction in ["timer_low", "destination"] and not _pending.has(_active_reaction):
			_pending.append(_active_reaction)
	_pending.remove_at(next_index)
	controller._show_line(owner, "alma_delivery", {
		"text": str(REACTIONS[trigger]),
		"cooldown": _rng.randf_range(5.0, 8.0),
	})
	_active_reaction = trigger
	_active_text = controller.current_text


func _next_random_line() -> String:
	if _bag.is_empty():
		_bag.assign(RANDOM_LINES)
		for index in range(_bag.size() - 1, 0, -1):
			var swap_index := _rng.randi_range(0, index)
			var previous: String = _bag[index]
			_bag[index] = _bag[swap_index]
			_bag[swap_index] = previous
		if _bag.size() > 1 and _bag.back() == _last_random_line:
			var previous: String = _bag[0]
			_bag[0] = _bag.back()
			_bag[_bag.size() - 1] = previous
	_last_random_line = _bag.pop_back()
	return _last_random_line


func _update_dodges(owner, controller) -> void:
	if not is_instance_valid(owner.player):
		return
	var player_rect := Geometry.collision_rect(owner.player, owner.PLAYER_HITBOX_INSET, owner)
	var range_pixels: float = 220.0 * owner.get_viewport_rect().size.y / 720.0
	var live_candidates: Dictionary = {}
	for entity: Dictionary in owner.active_entities:
		if not Entities.is_entity_sprite_valid(entity):
			continue
		if bool(entity.get("is_parked", false)) or bool(entity.get("horn_yielding", false)) or Entities.entity_collision_disabled(entity):
			continue
		var sprite: Sprite2D = entity.sprite
		var id := sprite.get_instance_id()
		live_candidates[id] = true
		var bounds := Geometry.collision_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner)
		if _dodge_candidates.has(id):
			var candidate: Dictionary = _dodge_candidates[id]
			if int(candidate.collisions) != owner.trip_vehicle_collision_count:
				_dodge_candidates.erase(id)
				continue
			candidate.changed_lane = bool(candidate.changed_lane) or owner.player_lane != int(candidate.lane)
			if bounds.end.x < player_rect.position.x:
				if bool(candidate.changed_lane):
					react(owner, controller, "dodge")
				_dodge_candidates.erase(id)
		elif int(entity.get("lane", -1)) == owner.player_lane:
			var gap := bounds.position.x - player_rect.end.x
			if gap >= 0.0 and gap <= range_pixels:
				_dodge_candidates[id] = {
					"lane": owner.player_lane,
					"collisions": owner.trip_vehicle_collision_count,
					"changed_lane": false,
				}
	for id in _dodge_candidates.keys():
		if not live_candidates.has(id):
			_dodge_candidates.erase(id)
