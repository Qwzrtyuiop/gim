extends RefCounted

const Economy := preload("res://scripts/game/game_economy_manager.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Service := preload("res://scripts/achievement_service.gd")


static func run(_host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_fare_rewards()
	_test_capacity_combinations()
	_test_capacity_saves_and_reset()
	PlayerState.reset()
	print("PASS: achievement fare bonuses stack to 10% without boosting time bonuses; earned resource caps survive saves, do not refill or stack repeatedly, reset cleanly, and ride entry adds one stress")


static func _test_fare_rewards() -> void:
	PlayerState.reset()
	PlayerState.set_current_mock_character("generic_guy")
	_assert_payout(100, 20)
	PlayerState.unlock_achievement("bayanihan")
	_assert_payout(105, 20)
	PlayerState.unlock_achievement("malasakit")
	_assert_payout(110, 20)
	PlayerState.unlock_achievement("bayanihan")
	PlayerState.unlock_achievement("malasakit")
	_assert_payout(110, 20)
	var before: int = PlayerState.money
	assert(PlayerState.claim_last_stage_total() == 130)
	assert(PlayerState.claim_last_stage_total() == 0 and PlayerState.money == before + 130)
	PlayerState.reset()
	PlayerState.unlock_achievement("malasakit")
	_assert_payout(105, 20)


static func _assert_payout(fare: int, bonus: int) -> void:
	# A real completed 500m trip: 100 pesos distance fare and 10 seconds left.
	Economy.store_stage_result("short-morning-normal", "short", "morning", "normal", "", "", 500.0, 500.0, 0.2, 0.0, 1.25, 10.0, 2.0, 0)
	var result := PlayerState.get_last_stage_result()
	assert(result.fare == fare and result.bonus == bonus and result.total == fare + bonus, "Fare achievements must apply before the receipt, without touching the time bonus")


static func _test_capacity_combinations() -> void:
	var stress_rewards := ["maparaan", "matiyaga", "maingat"]
	for combination in range(8):
		PlayerState.reset()
		PlayerState.energy = 2
		PlayerState.stress = 7
		PlayerState.hull = 3
		var expected_stress := 10
		for index in range(stress_rewards.size()):
			if (combination & (1 << index)) == 0:
				continue
			var id: String = stress_rewards[index]
			PlayerState.unlock_achievement(id)
			expected_stress += 2
			assert(PlayerState.max_stress == expected_stress)
			PlayerState.unlock_achievement(id)
			Service.apply_achievement_effects(PlayerState, id)
			assert(PlayerState.max_stress == expected_stress, "Reapplying an earned reward cannot accumulate capacity")
		PlayerState.unlock_achievement("masipag")
		PlayerState.unlock_achievement("masipag")
		Service.apply_achievement_effects(PlayerState, "masipag")
		assert(PlayerState.max_energy == 6 and PlayerState.max_stress == expected_stress)
		assert(PlayerState.energy == 2 and PlayerState.stress == 7 and PlayerState.hull == 3, "Capacity rewards must preserve current resources instead of healing or refilling")


static func _test_capacity_saves_and_reset() -> void:
	PlayerState.reset()
	for id: String in ["masipag", "maparaan", "matiyaga", "maingat", "bayanihan", "malasakit"]:
		PlayerState.unlock_achievement(id)
	PlayerState.energy = 6
	PlayerState.stress = 15
	PlayerState.hull = 4
	var snapshot := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	PlayerState.reset()
	assert(Codec.load_snapshot(PlayerState, snapshot))
	assert(PlayerState.max_energy == 6 and PlayerState.energy == 6 and PlayerState.max_stress == 16 and PlayerState.stress == 15 and PlayerState.hull == 4, "Achievements must load before current resource values are clamped")
	assert(Codec.load_snapshot(PlayerState, snapshot) and PlayerState.max_energy == 6 and PlayerState.max_stress == 16)
	# A pre-reward v5 save can already own the achievements but store old caps.
	snapshot.data["max_energy"] = 5
	snapshot.data["max_stress"] = 10
	snapshot.data["energy"] = 3
	snapshot.data["stress"] = 8
	assert(Codec.load_snapshot(PlayerState, snapshot))
	assert(PlayerState.max_energy == 6 and PlayerState.max_stress == 16 and PlayerState.energy == 3 and PlayerState.stress == 8)
	PlayerState.stress = 8
	var half := PlayerState.get_stress_vehicle_modifiers()
	assert(is_equal_approx(float(half.player_max_speed), 0.8), "Stress penalties scale against the earned capacity")
	PlayerState.reset()
	assert(PlayerState.max_energy == 5 and PlayerState.energy == 5 and PlayerState.max_stress == 10 and PlayerState.stress == 0 and PlayerState.hull == 10)
	assert(PlayerState.prepare_stage_start() and PlayerState.energy == 4 and PlayerState.stress == 1)
	assert(PlayerState.prepare_stage_start() and PlayerState.energy == 4 and PlayerState.stress == 1, "Preparing the same ride twice must not charge stress or energy twice")
