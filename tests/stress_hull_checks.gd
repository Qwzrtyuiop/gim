extends RefCounted

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Effects := preload("res://scripts/story/story_game_effects.gd")
const StoreItems := preload("res://scripts/store/store_items.gd")
const Tuning := preload("res://scripts/config/game_tuning.gd")
const Flow := preload("res://scripts/game/game_flow_controller.gd")
const DrivingSnapshot := preload("res://scripts/save/driving_save_snapshot.gd")


class StoryOwner extends RefCounted:
	var story_payload: Dictionary = {}


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_resources_and_rest()
	_test_save_migration()
	_test_special_entry()
	_test_story_effects()
	await _test_store(host)
	await _test_food_recovery(host)
	await _test_collisions(host)
	PlayerState.reset()
	print("PASS: independent energy/stress/hull caps, maximum-stress driving, once-only trip charge, rest and repair separation, v1/v4 migration and v5 roundtrip, energy/stress/mixed food recovery and purchase batching, partial mechanic repairs, live handling, collision grace and hull-zero repair, narrative actions and replay isolation")


static func _test_resources_and_rest() -> void:
	PlayerState.reset()
	assert(PlayerState.max_energy == 5 and PlayerState.energy == 5 and PlayerState.stress == 0 and PlayerState.hull == 10)
	PlayerState.stress = 999
	PlayerState.hull = -999
	PlayerState.max_stress = 99
	PlayerState.max_hull = 99
	PlayerState.max_energy = 99
	PlayerState.energy = 999
	assert(PlayerState.stress == 10 and PlayerState.hull == 0)
	assert(PlayerState.max_stress == 10 and PlayerState.max_hull == 10 and PlayerState.max_energy == 5)
	assert(PlayerState.energy == 5)
	assert(not PlayerState.get_stage_start_error().is_empty())
	PlayerState.repair_hull(999)
	assert(PlayerState.hull == 10 and PlayerState.get_stage_start_error().is_empty(), "Maximum stress cannot block a fueled, intact tricycle")
	assert(PlayerState.prepare_stage_start() and PlayerState.stress == 10 and PlayerState.energy == 4)
	PlayerState.confirm_stage_started()
	PlayerState.stress = 0
	PlayerState.energy = PlayerState.max_energy
	assert(PlayerState.prepare_stage_start() and PlayerState.stress == Tuning.TRIP_STRESS_GAIN and PlayerState.energy == 4)
	assert(PlayerState.prepare_stage_start() and PlayerState.stress == Tuning.TRIP_STRESS_GAIN and PlayerState.energy == 4, "Repeated entry preparation cannot charge twice")
	PlayerState.energy = 0
	assert(PlayerState.get_stage_start_error().is_empty() and PlayerState.prepare_stage_start(), "A paid pending trip remains admitted with its last energy point already spent")
	PlayerState.confirm_stage_started()
	assert(not PlayerState.get_stage_start_error().is_empty(), "An unpaid ride needs energy even at low stress")
	assert(PlayerState.get_stage_start_error_after_transition("", PlayerState.TRANSITION_REST_TO_NIGHT).is_empty())
	assert(PlayerState.prepare_stage_start_after_transition("", PlayerState.TRANSITION_REST_TO_NIGHT) and PlayerState.energy == 1)
	PlayerState.confirm_stage_started()
	PlayerState.energy = 0
	assert(PlayerState.get_stage_start_error_after_transition("", PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY).is_empty())
	assert(PlayerState.prepare_stage_start_after_transition("", PlayerState.TRANSITION_SLEEP_TO_NEXT_DAY) and PlayerState.energy == 4)
	PlayerState.confirm_stage_started()
	PlayerState.energy = 1
	PlayerState.stress = 8
	PlayerState.hull = 4
	assert(PlayerState.apply_transition_stress_relief(PlayerState.TRANSITION_REST_TO_NIGHT) == 2)
	assert(PlayerState.energy == 3 and PlayerState.stress == 6 and PlayerState.hull == 4)
	assert(PlayerState.apply_night_rest_bonus() == 4)
	assert(PlayerState.energy == 5 and PlayerState.stress == 2 and PlayerState.hull == 4, "Sleeping restores energy and relieves stress without repairing the tricycle")
	PlayerState.stress = 10
	var modifiers := PlayerState.get_stress_vehicle_modifiers()
	for pair in [
		["player_max_speed", 0.6],
		["player_acceleration_x", 0.5],
		["player_brake_x", 0.7],
		["player_lane_lerp_x", 0.4],
	]:
		assert(is_equal_approx(float(modifiers[pair[0]]), float(pair[1])))
	PlayerState.stress = 0
	PlayerState.unlock_achievement("maninigarilyo")
	assert(PlayerState.stress == 2 and PlayerState.max_stress == 10 and PlayerState.max_hull == 10)


static func _test_save_migration() -> void:
	PlayerState.reset()
	var legacy := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	legacy.version = 4
	legacy.data["max_energy"] = 8
	legacy.data["energy"] = 2
	legacy.data["pending_stage_energy_cost"] = true
	legacy.data["current_trip_low_energy"] = true
	legacy.data["last_stage_result"] = {"energy": 2, "day": 1, "time_of_day": "morning"}
	for key in ["stress", "max_stress", "hull", "max_hull", "pending_stage_stress_applied", "current_trip_high_stress"]:
		legacy.data.erase(key)
	assert(Codec.snapshot_error(legacy, PlayerState.SAVE_VERSION, true).is_empty())
	assert(Codec.load_snapshot(PlayerState, legacy))
	assert(PlayerState.energy == 2 and PlayerState.stress == 8 and PlayerState.hull == 10, "Old energy remains independent while stress is normalized against the original capacity")
	assert(PlayerState.pending_stage_stress_applied and PlayerState.current_trip_high_stress)
	assert(PlayerState.get_last_stage_result().stress == 8 and PlayerState.get_last_stage_result().hull == 10)
	assert(PlayerState.prepare_stage_start() and PlayerState.stress == 8, "A migrated paid entry cannot add stress twice")
	legacy.data["max_energy"] = 10
	legacy.data["energy"] = 7
	assert(Codec.load_snapshot(PlayerState, legacy))
	assert(PlayerState.energy == 5 and PlayerState.stress == 3, "Legacy stress must use the original ten-energy ratio before energy is clamped to five")
	legacy.version = 1
	legacy.data["max_energy"] = 5
	legacy.data["energy"] = 2
	assert(Codec.load_snapshot(PlayerState, legacy) and PlayerState.stress == 6 and PlayerState.max_stress == 10)
	legacy.version = 4
	legacy.data["pending_crash_repair"] = {"target_day": 2, "recovery_applied": false}
	assert(Codec.load_snapshot(PlayerState, legacy) and PlayerState.hull == 0, "Old pending repairs remain broken until recovery")
	PlayerState.reset()
	PlayerState.money = 456
	PlayerState.energy = 3
	PlayerState.stress = 7
	PlayerState.hull = 3
	PlayerState.pending_stage_stress_applied = true
	var snapshot := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	assert(snapshot.version == 5 and snapshot.data.energy == 3 and snapshot.data.max_energy == 5)
	assert(Codec.snapshot_error(snapshot, PlayerState.SAVE_VERSION, true).is_empty())
	PlayerState.reset()
	assert(Codec.load_snapshot(PlayerState, snapshot))
	assert(PlayerState.money == 456 and PlayerState.energy == 3 and PlayerState.stress == 7 and PlayerState.hull == 3 and PlayerState.pending_stage_stress_applied)
	var previous_capacity := snapshot.duplicate(true)
	previous_capacity.data["max_energy"] = 10
	previous_capacity.data["energy"] = 10
	assert(Codec.snapshot_error(previous_capacity, PlayerState.SAVE_VERSION, true).is_empty())
	assert(Codec.load_snapshot(PlayerState, previous_capacity))
	assert(PlayerState.max_energy == 5 and PlayerState.energy == 5 and PlayerState.stress == 7 and PlayerState.hull == 3, "Existing v5 saves clamp energy to five without changing stress or hull")
	var invalid := snapshot.duplicate(true)
	invalid.data["stress"] = "bad"
	assert(not Codec.load_snapshot(PlayerState, invalid))
	assert(PlayerState.stress == 7 and PlayerState.hull == 3, "Rejected saves must leave the active resources intact")
	PlayerState.reset()
	PlayerState.money = 1000
	PlayerState.stress = 9
	PlayerState.begin_crash_repair()
	var repair := PlayerState.get_pending_crash_repair()
	assert(PlayerState.hull == 0 and PlayerState.money == 800)
	assert(int(repair.cost) == 200 and int(repair.hull_restore) == 4 and not bool(repair.free_repair), "An affordable crash repair charges the quoted four-hull package")
	PlayerState.begin_crash_repair()
	assert(PlayerState.get_pending_crash_repair() == repair and PlayerState.money == 800, "Re-entering a pending repair cannot charge or quote it again")
	PlayerState.prepare_crash_repair_day()
	assert(PlayerState.hull == 4 and PlayerState.stress == 5 and PlayerState.energy == 5 and PlayerState.get_current_day() == 2)
	var paid_cash: int = PlayerState.money
	PlayerState.prepare_crash_repair_day()
	assert(PlayerState.hull == 4 and PlayerState.stress == 5 and PlayerState.money == paid_cash, "Repair recovery and its bill must execute once")
	PlayerState.finish_crash_repair()


static func _test_story_effects() -> void:
	PlayerState.reset()
	var owner := StoryOwner.new()
	Effects.run(owner, {"type": "set_resource", "resource": "energy", "value": 4})
	Effects.run(owner, {"type": "set_resource", "resource": "stress", "value": 4})
	Effects.run(owner, {"type": "add_stress", "amount": 4})
	Effects.run(owner, {"type": "relieve_stress", "amount": 3})
	Effects.run(owner, {"type": "damage_hull", "amount": 3})
	Effects.run(owner, {"type": "repair_hull", "amount": 2})
	assert(PlayerState.energy == 4 and PlayerState.stress == 5 and PlayerState.hull == 9)
	Effects.run(owner, {"type": "restore_energy", "amount": 2})
	assert(PlayerState.energy == 5 and PlayerState.stress == 5, "Story energy restoration respects the five-point capacity")
	Effects.run(owner, {"type": "change_resource", "resource": "stress", "amount": 99})
	Effects.run(owner, {"type": "change_resource", "resource": "hull", "amount": -99})
	assert(PlayerState.stress == 10 and PlayerState.hull == 0)
	Effects.run(owner, {"type": "relieve_stress"})
	Effects.run(owner, {"type": "repair_hull"})
	assert(PlayerState.stress == 0 and PlayerState.hull == 10)
	assert(not Effects.validate({"type": "damage_hull", "amount": -1}).is_empty())
	assert(not Effects.validate({"type": "set_resource", "resource": "stress", "value": 1.5}).is_empty())
	for replay_key in ["replay", "memory_replay"]:
		owner.story_payload = {replay_key: true}
		Effects.run(owner, {"type": "add_stress", "amount": 4})
		Effects.run(owner, {"type": "damage_hull", "amount": 4})
		assert(PlayerState.stress == 0 and PlayerState.hull == 10, "Gallery replay cannot alter live stress or hull")


static func _test_store(host: Node) -> void:
	PlayerState.reset()
	PlayerState.store_tutorial_shown = true
	PlayerState.money = 1000
	PlayerState.stress = 5
	PlayerState.hull = 7
	var store = load("res://scenes/store.tscn").instantiate()
	host.get_tree().root.add_child(store)
	store.set_process(false)
	await host.get_tree().process_frame
	var food := _item_index("turon")
	var repair := _item_index("hull_repair")
	store._open_shop("food")
	store.hub_dialogue.clear()
	await _buy(store, food)
	assert(PlayerState.energy == 5 and PlayerState.stress == 4 and PlayerState.money == 970 and PlayerState.hull == 7, "Shopping does not spend energy")
	await _buy(store, repair)
	assert(PlayerState.money == 970 and PlayerState.hull == 7, "The food counter cannot sell mechanic repairs")
	PlayerState.stress = 0
	await _buy(store, food)
	assert(PlayerState.money == 940 and PlayerState.stress == 0 and PlayerState.energy == 5, "Calm players can still buy food without exceeding resource caps")
	assert(store.status_label.text == "Bought Turon.")
	store._close_shop()
	store._open_shop("tricycle")
	store.hub_dialogue.clear()
	var item: Dictionary = Tuning.STORE_ITEMS[repair]
	assert(StoreItems.item_cost(store, item) == 100)
	await _buy(store, repair)
	assert(PlayerState.hull == 9 and PlayerState.money == 840 and PlayerState.stress == 0)
	assert(StoreItems.item_cost(store, item) == 50, "One missing hull costs half the two-point repair")
	await _buy(store, repair)
	assert(PlayerState.energy == 5 and PlayerState.hull == 10 and PlayerState.money == 790)
	await _buy(store, repair)
	assert(PlayerState.hull == 10 and PlayerState.money == 790, "Full hull rejects another purchase")
	PlayerState.hull = 8
	PlayerState.money = 0
	await _buy(store, repair)
	assert(PlayerState.hull == 8 and PlayerState.money == 0, "Unaffordable repairs cannot change hull")
	store.hub_dialogue.clear()
	store.bgm_player.stop()
	store.free()
	AmbientAudioManager.stop_all()
	_stop_ui_audio()
	await host.get_tree().create_timer(0.1).timeout


static func _test_food_recovery(host: Node) -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_phase = "noon"
	PlayerState.stage_round = 4
	PlayerState.store_tutorial_shown = true
	PlayerState.hull = 7
	PlayerState.gas = 61.5
	var store = load("res://scenes/store.tscn").instantiate()
	host.get_tree().root.add_child(store)
	store.set_process(false)
	await host.get_tree().process_frame
	store._open_shop("food")
	store.hub_dialogue.clear()
	var snack: Dictionary = Tuning.STORE_ITEMS[_item_index("energy_snack")]
	var turon: Dictionary = Tuning.STORE_ITEMS[_item_index("turon")]
	var pancit: Dictionary = Tuning.STORE_ITEMS[_item_index("pancit")]
	var lomi: Dictionary = Tuning.STORE_ITEMS[_item_index("lomi")]
	# Energy-only food remains purchasable at full energy without changing stress.
	await _assert_food_purchase(store, snack, 0, 0, 1, 0, true)
	await _assert_food_purchase(store, snack, 5, 6, 5, 6, true)
	# Stress-only food cannot secretly refill the activity budget.
	await _assert_food_purchase(store, turon, 4, 3, 4, 2, true)
	await _assert_food_purchase(store, turon, 4, 0, 4, 0, true)
	# Mixed food remains useful if only one of its two effects is needed.
	await _assert_food_purchase(store, pancit, 2, 0, 3, 0, true)
	await _assert_food_purchase(store, pancit, 5, 3, 5, 1, true)
	await _assert_food_purchase(store, lomi, 4, 1, 5, 0, true)
	assert(store.status_label.text.contains("restored 1 energy") and store.status_label.text.contains("reduced stress by 1"), "Food feedback must report actual clamped recovery")
	await _assert_food_purchase(store, lomi, 5, 0, 5, 0, true)
	# An oversized authored value still uses the runtime two-energy ceiling.
	var oversized: Dictionary = Tuning.STORE_ITEMS[_item_index("full_meal")].duplicate(true)
	oversized["energy_restore"] = 99
	assert(StoreItems.food_energy_restore(oversized) == 2)
	assert(StoreItems.item_text(store, oversized).contains("Restore 2 energy"), "The description must use the same cap as purchase effects")
	await _assert_food_purchase(store, oversized, 0, 0, 2, 0, true)
	assert(int(Tuning.STORE_ITEMS[_item_index("full_meal")].energy_restore) == 2, "Synthetic cap coverage must leave the real catalog unchanged")
	await _assert_food_purchase(store, pancit, 4, 5, 4, 5, false, false)
	assert(store.status_label.text == "Not enough money.")
	store.hub_dialogue.clear()
	store.bgm_player.stop()
	store.free()
	AmbientAudioManager.stop_all()
	_stop_ui_audio()
	await host.get_tree().create_timer(0.1).timeout


static func _assert_food_purchase(store, item: Dictionary, energy: int, stress: int, expected_energy: int, expected_stress: int, succeeds: bool, affordable := true) -> void:
	PlayerState.energy = energy
	PlayerState.stress = stress
	PlayerState.money = 10000 if affordable else 0
	var unchanged := [PlayerState.get_current_day(), PlayerState.get_current_time_of_day(), PlayerState.stage_round, PlayerState.hull, PlayerState.gas]
	var money: int = PlayerState.money
	var purchases: int = PlayerState.non_gas_store_purchases_this_week
	var saves := int(PlayerState.get_meta("test_save_count", 0))
	var index := _item_index(str(item.id))
	var button: Button = store.store_buy_buttons[index]
	StoreItems.refresh_buy_button(store, item, button)
	assert(not button.disabled and button.text == "BUY", "Food remains buyable even when its recovery cannot improve the current resources")
	var tier := HBoxContainer.new()
	await StoreItems.buy_item(store, item, store.store_item_labels[index], tier, button)
	tier.free()
	assert(PlayerState.energy == expected_energy and PlayerState.stress == expected_stress, "Food effects mismatch for " + str(item.id))
	assert(PlayerState.money == money - (StoreItems.item_cost(store, item) if succeeds else 0), "Affordable food purchases charge even when recovery is already capped")
	var expected_purchases := 1 if succeeds else 0
	assert(PlayerState.non_gas_store_purchases_this_week == purchases + expected_purchases, "Food purchases must count once; rejected food must not count")
	assert(int(PlayerState.get_meta("test_save_count", 0)) == saves + expected_purchases, "Each successful food purchase must save once as a complete batch; rejected purchases must not save")
	if succeeds and energy == expected_energy and stress == expected_stress:
		assert(store.status_label.text == "Bought %s." % str(item.name), "A purchase with no recovery still reports the bought item")
	assert(PlayerState._state_batch_depth == 0 and not PlayerState._suppress_auto_save, "Food purchase must close its state batch")
	assert([PlayerState.get_current_day(), PlayerState.get_current_time_of_day(), PlayerState.stage_round, PlayerState.hull, PlayerState.gas] == unchanged, "Food purchases must not change time, hull or fuel")


static func _buy(store, index: int) -> void:
	var tier := HBoxContainer.new()
	await StoreItems.buy_item(store, Tuning.STORE_ITEMS[index], store.store_item_labels[index], tier, store.store_buy_buttons[index])
	tier.free()


static func _item_index(id: String) -> int:
	for index in range(Tuning.STORE_ITEMS.size()):
		if str(Tuning.STORE_ITEMS[index].id) == id:
			return index
	assert(false, "Configured store item is missing: " + id)
	return -1


static func _test_collisions(host: Node) -> void:
	PlayerState.reset()
	var game = load("res://scenes/main.tscn").instantiate()
	game.use_player_state_stage_sequence = false
	game.stage_type = "short-morning-normal"
	host.get_tree().root.add_child(game)
	game.set_process(false)
	var calm_speed: float = game.player_max_speed
	var calm_steering: float = game.player_lane_lerp_x
	var energy_before: int = PlayerState.energy
	_test_driving_snapshot(game, calm_speed)
	PlayerState.stress = 10
	assert(is_equal_approx(game.player_max_speed, calm_speed * 0.6))
	assert(is_equal_approx(game.player_lane_lerp_x, calm_steering * 0.4), "Stress changes must affect the active drive immediately")
	Flow.handle_player_hit(game, "Light collision", 1, 1)
	assert(PlayerState.energy == energy_before and PlayerState.hull == 9 and PlayerState.stress == 10 and game.game_state == "playing", "Crashes do not consume the action energy budget")
	assert(PlayerState.pending_crash_repair.is_empty(), "Maximum stress alone cannot send the tricycle for repairs")
	Flow.handle_player_hit(game, "Same contact", 1, 1)
	assert(PlayerState.hull == 9, "One contact cannot repeatedly damage hull during collision grace")
	game.player_hit_invincible_timer = 0.0
	Flow.handle_player_hit(game, "Heavy collision", 2, 2)
	assert(PlayerState.hull == 7 and game.game_state == "playing")
	PlayerState.hull = 1
	game.player_hit_invincible_timer = 0.0
	Flow.handle_player_hit(game, "Last hull point", 1, 1)
	assert(PlayerState.hull == 0 and game.game_state == "CRASH" and game.crash_repair_transition_active)
	assert(PlayerState.energy == energy_before)
	assert(not PlayerState.pending_crash_repair.is_empty() and not PlayerState.get_last_stage_result().get("completed", true))
	var repair := PlayerState.get_pending_crash_repair()
	assert(PlayerState.money == 0 and int(repair.cost) == 0 and int(repair.hull_restore) == 1 and bool(repair.free_repair), "An unaffordable crash repair grants one hull for free instead of taking remaining cash")
	game.audio_manager.crash_sfx_player.stop()
	game.audio_manager.stage_bgm_player.stop()
	game.free()
	AmbientAudioManager.stop_all()
	_stop_ui_audio()
	await host.get_tree().create_timer(0.1).timeout


static func _stop_ui_audio() -> void:
	UIAudioManager.hover_player.stop()
	UIAudioManager.press_player.stop()


static func _test_driving_snapshot(game, calm_speed: float) -> void:
	PlayerState.stress = 6
	var saved := DrivingSnapshot.capture(game)
	assert(saved.has("stress_modifiers"))
	PlayerState.stress = 10
	assert(DrivingSnapshot.restore(game, saved))
	assert(is_equal_approx(game.player_max_speed, calm_speed * 0.6), "Live loads must apply current stress without stacking saved stress penalties")
	PlayerState.stress = 0
	assert(is_equal_approx(game.player_max_speed, calm_speed), "Restored base factors must support subsequent live stress changes")
	var legacy := saved.duplicate(true)
	legacy.erase("stress_modifiers")
	var old_modifiers := DrivingSnapshot._saved_handling_modifiers(legacy)
	for key in saved.stress_modifiers:
		legacy.values[key] = float(saved.values[key]) / float(saved.stress_modifiers[key]) * float(old_modifiers[key])
	PlayerState.stress = 5
	assert(DrivingSnapshot.restore(game, legacy))
	assert(is_equal_approx(game.player_max_speed, calm_speed * 0.8), "Pre-stress driving slots remove old energy handling before applying stress")
	var invalid := saved.duplicate(true)
	invalid.stress_modifiers.player_max_speed = NAN
	var distance: float = game.distance
	assert(not DrivingSnapshot.restore(game, invalid) and game.distance == distance, "Invalid saved factors must be rejected before changing the drive")
	PlayerState.stress = 0


static func _test_special_entry() -> void:
	PlayerState.reset()
	PlayerState.current_phase = "night"
	PlayerState.set_current_mock_character("gardo")
	PlayerState.set_last_stage_result({
		"completed": true,
		"day": 1,
		"time_of_day": "night",
		"character_id": "gardo",
		"stage_type": "short-night-chill",
		"target_distance": 500.0,
		"total": 0,
	})
	PlayerState.energy = 0
	assert(not PlayerState.begin_event_special_stage("gardo_extra_lap", "res://scenes/stage_results.tscn"))
	assert(PlayerState.active_event_special_stage.is_empty())
	PlayerState.energy = 2
	PlayerState.stress = 9
	assert(PlayerState.begin_event_special_stage("gardo_extra_lap", "res://scenes/stage_results.tscn"))
	assert(PlayerState.energy == 1 and PlayerState.stress == 10 and PlayerState.pending_stage_stress_applied)
	assert(PlayerState.begin_event_special_stage("gardo_extra_lap", "res://scenes/stage_results.tscn"))
	assert(PlayerState.energy == 1, "Reloading a scripted driving leg cannot charge its entry again")
