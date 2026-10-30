extends RefCounted

const Session := preload("res://scripts/home/fishing_session.gd")
const Overlay := preload("res://scripts/home/fishing_overlay.gd")
const Dock := preload("res://scripts/home/pier_dock_hotspot.gd")
const FishCatalog := preload("res://scripts/home/fishing_fish_catalog.gd")
const FishSpecies := preload("res://scripts/home/fishing_species_catalog.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const SaveContext := preload("res://scripts/save/save_game_context.gd")
const HOME := "res://scenes/day_start_scene.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	_test_session()
	_test_fish_passages()
	_test_fish_art()
	_test_species_and_inventory()
	await _test_pier_and_input(host)
	AmbientAudioManager.stop_all()
	HubMusicManager.stop_all()
	UIAudioManager.hover_player.stop()
	UIAudioManager.press_player.stop()
	await host.get_tree().create_timer(0.1).timeout
	PlayerState.reset()
	print("PASS: fishing physics/input, independent species/size rolls, persisted individual catches/records, end-session catch cards, pause/dock/save guards and unchanged resources")


static func _fish(id: int, at: Vector2, dimensions := Vector2(0.04, 0.04)) -> Dictionary:
	return {
		"id": id,
		"position": at,
		"size": dimensions,
		"velocity": Vector2.ZERO,
		"turn_timer": 1000.0,
		"mouth_offset": Vector2.ZERO,
		"facing": 1,
		"behavior": "biting",
	}


static func _test_session() -> void:
	seed(31872)
	var expected_global_roll := randi()
	seed(31872)
	var model := Session.new()
	model.reset(73)
	model.update(0.8)
	assert(randi() == expected_global_roll, "Fishing cannot consume the passenger/weather/traffic RNG")
	model.reset(73)
	var same := Session.new()
	same.reset(73)
	assert(model.fish == same.fish, "A seeded session is repeatable for isolated fixtures")
	model.fish.clear()
	var initial_length := model.line_length
	model.reel(1.0)
	assert(model.line_length > initial_length, "Clockwise pays out actual rope")
	var paid_out_length := model.line_length
	model.reel(-0.5)
	assert(model.line_length < paid_out_length, "Counterclockwise retrieves actual rope")
	model.reel(1000.0)
	assert(is_equal_approx(model.line_length, Session.MAX_LINE_LENGTH))
	model.reel(-1000.0)
	assert(is_equal_approx(model.line_length, Session.MIN_LINE_LENGTH))
	var still_x := model.hook_position.x
	var still_anchor := model.line_anchor_x
	model.update(2.0)
	assert(not is_equal_approx(model.hook_position.x, still_x), "Water current moves an unattended hook horizontally")
	assert(model.hook_position.x >= Session.MIN_X and model.hook_position.x <= Session.MAX_X)
	assert(not is_equal_approx(model.line_anchor_x, still_anchor), "Surface current independently drifts the top of the line")
	assert(model.line_anchor_x >= Session.MIN_X and model.line_anchor_x <= Session.MAX_X)
	_test_flexible_line(model)

	model.reset(41)
	model.hook_tip_offset = Vector2(-0.012, 0.045)
	model.line_anchor_x = 0.5
	model.hook_position = Vector2(0.5, 0.6)
	model.fish.assign([_fish(3, Vector2(0.5, 0.3))])
	model.update(0.001)
	assert(model.hooked_fish_id == -1, "A fish touching only the rope cannot be caught")
	model.fish[0].mouth_offset = Vector2(0.012, 0)
	model.fish[0].position = model.hook_tip_position() - model.fish[0].mouth_offset
	model.update(0.001)
	assert(model.hooked_fish_id == 3 and model.line_state == "hooked", "The actual hook tip latches onto a fish")
	assert(model.fish_mouth_position(model.fish[0]).is_equal_approx(model.hook_tip_position()), "The fish's mouth, rather than its center, attaches to the hook")

	model.reset(93)
	model.line_anchor_x = 0.5
	model.hook_position = Vector2(0.5, 0.1)
	model.fish.assign([
		_fish(8, Vector2(0.5, 0.65), Vector2(0.02, 0.02)),
		_fish(7, Vector2(0.5, 0.45), Vector2(0.02, 0.02)),
	])
	var hooked: Array[int] = []
	var landed: Array[int] = []
	model.fish_hooked.connect(func(id: int) -> void: hooked.append(id))
	model.fish_caught.connect(func(total: int) -> void: landed.append(total))
	model.reel(1000.0)
	assert(model.hooked_fish_id == 7 and hooked == [7], "A fast reel sweep catches the first fish crossed instead of tunneling through it")
	assert(model.hook_position.y < 0.46, "Remaining downward movement stops at the snag")
	assert(model.fight_phase == "pulling")
	assert(model.is_line_taut() and model.is_reel_in_blocked())
	var pulling_length := model.line_length
	assert(is_zero_approx(model.reel(-1000.0)) and is_equal_approx(model.line_length, pulling_length), "A pulling fish blocks counter-turns only once the line is taut")
	var hooked_length := model.line_length
	var fight_x := model.hook_position.x
	model.update(0.7)
	assert(model.line_length > hooked_length, "An attached fish pulls out more rope without counter-reeling")
	assert(not is_equal_approx(model.hook_position.x, fight_x), "A hooked fish fights laterally")
	for entry: Dictionary in model.fish:
		if int(entry.id) == 7:
			assert(model.fish_mouth_position(entry).is_equal_approx(model.hook_tip_position()), "An attached fish's mouth follows the hook during its fight")
	_wait_for_rest(model)
	var resting_length := model.line_length
	model.set_reel_held(false)
	var resting_interval := minf(0.02, model.fight_seconds_left * 0.25)
	model.update(resting_interval)
	var resting_payout := minf(Session.MAX_LINE_LENGTH, resting_length + GameTuning.FISHING_IDLE_PAYOUT_SPEED * resting_interval)
	assert(is_equal_approx(model.line_length, resting_payout), "A released reel only lowers slowly while the fish rests")
	assert(model.reel(-1000.0) < 0.0)
	assert(model.caught_count == 1 and landed == [1] and model.hooked_fish_id == -1)
	assert(model.line_state == "free" and model.last_event == "caught")
	model.reel(-1000.0)
	assert(model.caught_count == 1 and landed == [1], "An already-landed fish cannot award another catch")
	model.reset(93)
	assert(model.caught_count == 0 and model.hooked_fish_id == -1 and model.line_state == "free")
	assert(model.fish.size() == GameTuning.FISHING_FISH_COUNT and model.hook_tip_offset == Vector2.ZERO)
	assert(is_equal_approx(model.line_anchor_x, 0.57), "A new session resets the drifting line anchor")
	assert(model.fight_phase == "free")
	_test_reel_brake()
	_test_tension_slack()


static func _wait_for_rest(model) -> void:
	for _step in range(240):
		if model.fight_phase == "resting":
			return
		model.update(0.05)
	assert(false, "A hooked fish must alternate pulling and resting")


static func _latched_fixture(seed_value: int):
	var model := Session.new()
	model.reset(seed_value)
	model.line_anchor_x = 0.5
	model.teleport_hook(Vector2(0.5, 0.45))
	model.fish.assign([_fish(1, model.hook_tip_position())])
	model.update(0.001)
	assert(model.hooked_fish_id == 1 and model.fight_phase == "pulling")
	return model


static func _test_reel_brake() -> void:
	var loose = _latched_fixture(901)
	var braked = _latched_fixture(901)
	var initial: float = loose.line_length
	braked.set_reel_held(true)
	var interval: float = minf(0.2, loose.fight_seconds_left * 0.25)
	loose.update(interval)
	braked.update(interval)
	assert(loose.line_length > initial)
	assert(braked.line_length - initial < (loose.line_length - initial) * 0.5, "Holding the reel substantially brakes the fish's pull")
	assert(loose.automatic_reel_angle > 0.0 and braked.automatic_reel_angle < loose.automatic_reel_angle, "A pulling fish spins the reel clockwise, reduced by the brake")
	var catches := 0
	for _step in range(1600):
		if braked.caught_count > 0:
			catches = braked.caught_count
			break
		braked.set_reel_held(true)
		if braked.fight_phase == "resting":
			braked.reel(-1.0)
		braked.update(0.01)
	assert(catches == 1, "Braking during pulls and reeling during rests can eventually land the fish")


static func _test_tension_slack() -> void:
	var model = _latched_fixture(712)
	model.set_reel_held(true)
	assert(model.is_reel_in_blocked())
	var endpoint: Vector2 = model.hook_position
	var taut_length: float = model.line_length
	assert(model.reel(0.2 / GameTuning.FISHING_REEL_LINE_PER_RADIAN) > 0.0, "Clockwise payout remains available even while the fish pulls")
	assert(model.line_length > taut_length + 0.19 and not model.is_line_taut() and not model.is_reel_in_blocked(), "Lowering line creates slack and unlocks counterclockwise input")
	assert(model.hook_position.distance_to(endpoint) < 0.02, "Paying out slack cannot teleport a hooked fish downward")
	var slack_length: float = model.line_length
	assert(model.reel(-0.05 / GameTuning.FISHING_REEL_LINE_PER_RADIAN) < 0.0)
	assert(model.line_length < slack_length and not model.is_reel_in_blocked(), "Counter-turns can recover some slack during the same pulling phase")
	assert(model.hook_position.distance_to(endpoint) < 0.02, "Retrieving spare rope first consumes slack before pulling the fish")
	var held_length: float = model.line_length
	var became_taut := false
	for _step in range(1000):
		if model.is_reel_in_blocked():
			became_taut = true
			break
		model.update(0.01)
	assert(became_taut, "A fighting fish physically stretches the free end until the available line becomes taut")
	assert(model.line_length <= held_length + 0.03, "Taking up slack primarily stretches the free end rather than inventing more rope")
	var blocked_length: float = model.line_length
	assert(is_zero_approx(model.reel(-2.0)) and is_equal_approx(model.line_length, blocked_length))
	assert(model.reel(0.08 / GameTuning.FISHING_REEL_LINE_PER_RADIAN) > 0.0 and not model.is_reel_in_blocked(), "The player can always lower more line to release a taut lock")
	_wait_for_rest(model)
	assert(not model.is_reel_in_blocked() and model.reel(-0.5) < 0.0, "A resting fish permits retrieval regardless of tension")


static func _test_fish_passages() -> void:
	var model := Session.new()
	model.reset(441)
	assert(model.fish.size() == 3, "Only a small pool swims through the fishing view")
	var passage := _fish(4, Vector2(0.99, 0.75))
	passage.velocity = Vector2(0.12, 0)
	model.fish.assign([passage])
	model.update(0.3)
	assert(Vector2(model.fish[0].position).x > 1.0 and Vector2(model.fish[0].velocity).x > 0.0, "A fish swims beyond the water edge instead of bouncing offscreen")
	for _step in range(100):
		if float(model.fish[0].get("respawn_wait", 0.0)) > 0.0:
			break
		model.update(0.05)
	var next_pass: Dictionary = model.fish[0]
	assert(float(next_pass.get("respawn_wait", 0.0)) > 0.0 and Vector2(next_pass.position).x < 0.0 and Vector2(next_pass.velocity).x > 0.0, "After exiting fully, a fish waits beyond the opposite edge before its next passage")
	var hidden_at: Vector2 = next_pass.position
	model.update(minf(0.05, float(next_pass.respawn_wait) * 0.25))
	assert(Vector2(next_pass.position) == hidden_at, "A fish waiting offscreen remains hidden and stationary")
	var wait_left := float(next_pass.respawn_wait)
	model.update(wait_left + 0.1)
	assert(is_zero_approx(float(next_pass.respawn_wait)) and Vector2(next_pass.position).x > hidden_at.x, "The next passage resumes inward after the offscreen delay")

	model.reset(442)
	model.fish.assign([_fish(5, model.hook_tip_position())])
	model.fish[0]["respawn_wait"] = 1.0
	model.update(0.01)
	assert(model.hooked_fish_id == -1, "Offscreen-waiting fish cannot be snagged even if a stale rectangle overlaps the hook")


static func _test_fish_art() -> void:
	assert(FishCatalog.SPECIES.size() == 5)
	var image := FishCatalog.SOURCE.get_image()
	for species_index in range(FishCatalog.SPECIES.size()):
		for frame_index in range(3):
			var frame: Dictionary = FishCatalog.frame_for(species_index, frame_index)
			var region: Rect2 = frame.region
			var mouth: Vector2 = frame.mouth
			assert(Rect2(Vector2.ZERO, Vector2(image.get_size())).encloses(region))
			assert(Rect2(Vector2.ZERO, region.size).has_point(mouth), "Every swimming frame has an authored mouth inside its own crop")
			var pixel := Vector2i((region.position + mouth).floor())
			assert(image.get_pixelv(pixel).a >= 0.5, "The hook attaches to a visible mouth pixel")
			assert(FishCatalog.texture_for(species_index, frame_index).region == region)
			assert(FishCatalog.visual_size(species_index, frame_index).x > 0.0)
			assert(FishCatalog.mouth_offset(species_index, frame_index).x > 0.0, "Right-facing fish mouths stay at the leading edge across all fifteen frames")


static func _test_species_and_inventory() -> void:
	var expected_ranges := {
		"lapu_lapu": Vector2(15, 50),
		"tamban": Vector2(8, 23),
		"dilis": Vector2(4, 16),
		"maya_maya": Vector2(15, 100),
		"bangus": Vector2(20, 150),
		"tilapia": Vector2(10, 60),
		"tambakol": Vector2(40, 240),
		"tulingan": Vector2(20, 65),
		"galunggong": Vector2(10, 35),
		"dalagang_bukid": Vector2(10, 60),
		"sapsap": Vector2(6, 28),
		"hasa_hasa": Vector2(10, 42),
		"apahap": Vector2(25, 200),
		"pompano": Vector2(12, 110),
		"bisugo": Vector2(8, 34),
		"tanigue": Vector2(30, 240),
	}
	assert(FishSpecies.FISH.size() == expected_ranges.size())
	for fish_id: String in expected_ranges:
		var definition := FishSpecies.find(fish_id)
		var bounds: Vector2 = expected_ranges[fish_id]
		assert(Vector2(definition.min_cm, definition.max_cm) == bounds, "Catch species use the authored centimeter ranges")
		assert(FishSpecies.texture_for(fish_id) is AtlasTexture, "Every named catch has its own fishlist picture")
	var previous_scale := 0.0
	for length_cm in [4.0, 8.0, 16.0, 35.0, 60.0, 100.0, 150.0, 200.0, 240.0]:
		var visual_scale := FishSpecies.visual_scale(length_cm)
		assert(is_finite(visual_scale) and visual_scale > previous_scale, "Longer catches always receive larger silhouettes regardless of species or pose")
		previous_scale = visual_scale
	var catch_rng := RandomNumberGenerator.new()
	catch_rng.seed = 8712
	for _index in range(80):
		var rolled := FishSpecies.roll(catch_rng)
		var bounds: Vector2 = expected_ranges[rolled.fish_id]
		assert(float(rolled.length_cm) >= bounds.x and float(rolled.length_cm) <= bounds.y)

	PlayerState.reset()
	PlayerState.current_day = 8
	PlayerState.current_phase = "noon"
	var first := PlayerState.record_fish_catch({"fish_id": "lapu_lapu", "length_cm": 25.0})
	var larger := PlayerState.record_fish_catch({"fish_id": "lapu_lapu", "length_cm": 40.0})
	var tied := PlayerState.record_fish_catch({"fish_id": "lapu_lapu", "length_cm": 40.0})
	var smaller := PlayerState.record_fish_catch({"fish_id": "lapu_lapu", "length_cm": 15.0})
	var another_species := PlayerState.record_fish_catch({"fish_id": "dilis", "length_cm": 8.0})
	assert(first.first_catch and first.is_smallest and first.is_largest)
	assert(larger.is_largest and not larger.is_smallest and not larger.first_catch)
	assert(not tied.is_largest and not tied.is_smallest, "A tied length is stored individually without claiming a new record")
	assert(smaller.is_smallest and not smaller.is_largest)
	assert(another_species.first_catch and another_species.is_smallest and another_species.is_largest, "Size records are independent for each species")
	assert(PlayerState.get_fish_size_records("lapu_lapu") == {"smallest_cm": 15.0, "largest_cm": 40.0})
	var catches := PlayerState.get_fish_catches()
	var unique_ids: Dictionary = {}
	for caught: Dictionary in catches:
		assert(not unique_ids.has(caught.catch_id) and caught.day == 8 and caught.phase == "noon")
		unique_ids[caught.catch_id] = true
	assert(catches.size() == 5)
	first.length_cm = 49.0
	catches[0].length_cm = 48.0
	assert(PlayerState.get_fish_catches()[0].length_cm == 25.0, "Returned catch dictionaries cannot mutate the stored inventory")
	assert(PlayerState.record_fish_catch({"fish_id": "lapu_lapu", "length_cm": 10.0}).is_empty())
	var snapshot := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	PlayerState.record_fish_catch({"fish_id": "lapu_lapu", "length_cm": 50.0})
	assert(snapshot.data.fish_catches.size() == 5, "A held save snapshot cannot gain catches from later gameplay")
	assert(Codec.load_snapshot(PlayerState, snapshot) and PlayerState.get_fish_catches().size() == 5)
	snapshot.data.fish_catches[0].length_cm = 26.0
	assert(PlayerState.get_fish_catches()[0].length_cm == 25.0, "Loading also isolates nested catch records from the save Resource")
	var older_save := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	older_save.data.erase("fish_catches")
	assert(Codec.load_snapshot(PlayerState, older_save) and PlayerState.get_fish_catches().is_empty(), "Older version-5 saves start empty instead of inheriting the active run's fish")
	PlayerState.record_fish_catch({"fish_id": "dilis", "length_cm": 8.0})
	PlayerState.reset()
	assert(PlayerState.get_fish_catches().is_empty(), "A new run clears catches and personal fish records")


static func _test_flexible_line(model) -> void:
	model.reset(127)
	model.fish.clear()
	model.line_anchor_x = 0.2
	model.teleport_hook(Vector2(0.52, 0.6))
	var old_hook: Vector2 = model.hook_position
	var old_length: float = model.line_length
	model.reel(-5.0)
	model.update(0.001)
	assert(model.line_length < old_length)
	assert(model.hook_position.x < old_hook.x and model.hook_position.y < old_hook.y, "Retrieving a diagonal line pulls the whole hook toward its anchor, not only upward")
	model.reel(8.0)
	model.update(0.7)
	assert(model.line_points.size() > 3, "Flexible rope is represented by several connected points")
	var first: Vector2 = model.line_points[0]
	var last: Vector2 = model.line_points[-1]
	assert(first.is_equal_approx(Vector2(model.line_anchor_x, Session.ANCHOR_DEPTH)))
	assert(last.is_equal_approx(model.hook_position))
	var arc := 0.0
	var deviation := 0.0
	var chord := Vector2((last.x - first.x) * Session.WATER_ASPECT, last.y - first.y)
	for index in range(model.line_points.size()):
		var at: Vector2 = model.line_points[index]
		assert(is_finite(at.x) and is_finite(at.y) and Rect2(0, 0, 1, 1).grow(0.001).has_point(at), "Rope points remain finite and inside the water")
		var offset := Vector2((at.x - first.x) * Session.WATER_ASPECT, at.y - first.y)
		deviation = maxf(deviation, absf(chord.cross(offset)) / maxf(0.001, chord.length()))
		if index > 0:
			var previous: Vector2 = model.line_points[index - 1]
			arc += Vector2((at.x - previous.x) * Session.WATER_ASPECT, at.y - previous.y).length()
	assert(deviation > 0.00001, "Current and slack can bend the rope instead of rendering one rigid segment")
	assert(arc <= model.line_length * 1.15 + 0.02, "The rope cannot grow arbitrarily beyond the paid-out line")


static func _setup() -> void:
	AmbientAudioManager.stop_all()
	HubMusicManager.stop_all()
	PlayerState.reset()
	PlayerState.current_day = 8
	PlayerState.current_phase = "morning"
	PlayerState.current_stage_type = "short-morning-chill"
	PlayerState.stage_round = 4
	PlayerState.money = 500
	PlayerState.energy = 4
	PlayerState.stress = 3
	PlayerState.hull = 7
	PlayerState.gas = 65.0
	PlayerState.home_tutorial_shown = true
	PlayerState.ride_select_tutorial_shown = true
	PlayerState.store_tutorial_shown = true
	PlayerState.clear_story_triggers()
	PlayerState.set_event_value("north_road_open_announced", true)
	PlayerState.set_pending_trip_selection(HOME, PlayerState.TRANSITION_CURRENT_STAGE)


static func _resources() -> Array:
	return [PlayerState.money, PlayerState.energy, PlayerState.stress, PlayerState.hull, PlayerState.gas, PlayerState.current_day, PlayerState.current_phase, PlayerState.stage_round]


static func _test_pier_and_input(host: Node) -> void:
	_setup()
	var tree := host.get_tree()
	var home = load(HOME).instantiate()
	tree.root.add_child(home)
	tree.current_scene = home
	await _settle(host)
	var original := _resources()
	home._open_map()
	var world = home.home_map
	world.map_view.set_map_region("north")
	world._visit("pier")
	await _settle(host)
	var overlay = world.fishing_overlay
	assert(not overlay.active and not overlay.visible, "Entering Pier leaves the location available without automatically starting fishing")
	assert(world.current_location == "pier" and world.location_view.visible and not world.map_view.visible)
	assert(not world.map_button.disabled and not world.pier_dock.disabled and not world.pier_shop.disabled)
	var dock_point: Vector2 = world.pier_dock.get_global_transform_with_canvas() * (Vector2(445, 355) / Dock.ART_SIZE * world.pier_dock.size)
	await _click(host, dock_point)
	assert(world.fishing_confirmation.visible and world.fishing_confirmation.heading_label.text == "Start fishing?" and not overlay.active)
	world._show_map()
	world._close()
	assert(world.visible and world.location_view.visible and not world.map_view.visible, "The fishing prompt keeps location navigation behind the modal")
	await _click(host, world.fishing_confirmation.cancel_button.get_global_rect().get_center())
	assert(not world.fishing_confirmation.visible and not overlay.active and not world.map_button.disabled and not world.pier_shop.disabled, "Declining fishing returns to the pier without starting a session")
	var shop_point: Vector2 = world.pier_shop.get_global_transform_with_canvas() * (Vector2(1150, 680) / Dock.ART_SIZE * world.pier_shop.size)
	await _click(host, shop_point)
	assert(world.fishing_shop.visible and world.fishing_shop.heading_label.text == "FISHING SHOP" and not overlay.active, "The authored building opens the fishing shop placeholder")
	await _click(host, world.fishing_shop.cancel_button.get_global_rect().get_center())
	assert(not world.fishing_shop.visible and not world.map_button.disabled and not world.pier_dock.disabled)
	assert(_resources() == original, "Arriving, declining fishing and visiting the placeholder shop do not spend resources or time")
	await _click(host, dock_point)
	await _click(host, world.fishing_confirmation.confirm_button.get_global_rect().get_center())
	assert(overlay.active and overlay.is_visible_in_tree() and not world.fishing_confirmation.visible, "Accepting the tip-of-pier prompt starts fishing")
	assert(SaveContext.save_block_reason(home).to_lower().contains("fishing"))
	assert(world.map_button.disabled and world.pier_dock.disabled and world.pier_shop.disabled)
	world._show_map()
	world._close()
	assert(world.visible and world.location_view.visible and not world.map_view.visible, "Travel cannot close or replace an active fishing session")
	assert(_resources() == original, "Entering fishing does not charge resources or change time")

	overlay.session.fish.clear()
	for viewport_size in [Vector2(1280, 720), Vector2(640, 360), Vector2(900, 900)]:
		home.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		home.size = viewport_size
		await _settle(host)
		var art_at: Vector2 = overlay.source_to_global(Vector2.ZERO)
		var art_end: Vector2 = overlay.source_to_global(Overlay.ART_SIZE)
		assert(home.get_global_rect().grow(0.1).encloses(Rect2(art_at, art_end - art_at)), "The ocean and reel share a fitted canvas at every viewport shape")
		var reel_at: Vector2 = overlay.source_to_global(Overlay.REEL_PIVOT)
		assert(overlay.global_to_source(reel_at).is_equal_approx(Overlay.REEL_PIVOT))
		var before_length: float = overlay.session.line_length
		var hover_auto_before: float = overlay.session.automatic_reel_angle
		await _motion(host, _reel_point(overlay, 0.5))
		var hover_payout: float = (overlay.session.automatic_reel_angle - hover_auto_before) * GameTuning.FISHING_REEL_LINE_PER_RADIAN
		assert(is_equal_approx(overlay.session.line_length, before_length + hover_payout) and not overlay.dragging, "Mouse movement alone adds no reeling beyond automatic payout")
		await _drag(host, overlay, [0.0, 0.4, 0.8, 1.2])
		assert(overlay.session.line_length > before_length, "Real clockwise mouse dragging pays out rope after resizing")
		var length_after_clockwise: float = overlay.session.line_length
		await _drag(host, overlay, [0.0, -0.4, -0.8, -1.2])
		assert(overlay.session.line_length < length_after_clockwise, "Real counterclockwise mouse dragging retrieves rope")

	home.size = Vector2(1280, 720)
	await _settle(host)
	await _button(host, _reel_point(overlay, PI - 0.03), true)
	assert(overlay.dragging and overlay.cursor_locked, "Grabbing the reel captures the cursor onto its grip")
	var wrap_length: float = overlay.session.line_length
	await _reel_motion(host, overlay, 0.06)
	assert(overlay.session.line_length > wrap_length and overlay.session.line_length - wrap_length < 0.02, "Captured relative movement produces a small turn without screen-edge angle jumps")
	await _button(host, Vector2(2, 2), false)
	assert(not overlay.dragging and not overlay.cursor_locked, "Releasing away from the reel ends the drag and cursor capture")
	var released_length: float = overlay.session.line_length
	var released_auto_before: float = overlay.session.automatic_reel_angle
	await _motion(host, _reel_point(overlay, -PI + 0.6))
	var released_payout: float = (overlay.session.automatic_reel_angle - released_auto_before) * GameTuning.FISHING_REEL_LINE_PER_RADIAN
	assert(is_equal_approx(overlay.session.line_length, released_length + released_payout), "Moving the released mouse does not turn the reel")

	overlay.close()
	world._open_fishing(true)
	overlay.session.fish.clear()
	overlay.set_process(false)
	assert(overlay.ocean_frame_index == 0)
	overlay._process(GameTuning.FISHING_OCEAN_FRAME_SECONDS + 0.00001)
	assert(overlay.ocean_frame_index == 1)
	overlay._process(GameTuning.FISHING_OCEAN_FRAME_SECONDS)
	assert(overlay.ocean_frame_index == 2)
	overlay._process(GameTuning.FISHING_OCEAN_FRAME_SECONDS)
	assert(overlay.ocean_frame_index == 0, "The three authored ocean frames wrap in a loop")
	overlay.set_process(true)
	await _button(host, _reel_point(overlay, 0.0), true)
	assert(overlay.dragging and overlay.cursor_locked)
	await _key(host, KEY_ESCAPE)
	assert(tree.paused and PauseMenuManager.visible and overlay.active and not overlay.dragging and not overlay.cursor_locked, "Escape pauses fishing and releases its drag and captured cursor")
	assert(PauseMenuManager.save_button.disabled)
	var paused_hook: Vector2 = overlay.session.hook_position
	var paused_rope: Variant = overlay.session.line_points.duplicate()
	var paused_anchor: float = overlay.session.line_anchor_x
	var paused_frame: int = overlay.ocean_frame_index
	await _button(host, Vector2(2, 2), false)
	await tree.create_timer(0.22, true).timeout
	assert(overlay.session.hook_position == paused_hook and overlay.ocean_frame_index == paused_frame, "Pause freezes currents, fish and ocean animation")
	assert(overlay.session.line_anchor_x == paused_anchor)
	assert(overlay.session.line_points == paused_rope)
	await _key(host, KEY_ESCAPE)
	assert(not tree.paused and not PauseMenuManager.visible and overlay.active and not overlay.dragging)

	await _click(host, overlay.close_button.get_global_rect().get_center())
	assert(not overlay.active and not overlay.visible and world.location_view.visible)
	assert(not world.map_button.disabled and not world.pier_dock.disabled)
	assert(SaveContext.save_block_reason(home).is_empty(), "Closing fishing restores ordinary saving")
	dock_point = world.pier_dock.get_global_transform_with_canvas() * (Vector2(445, 355) / Dock.ART_SIZE * world.pier_dock.size)
	await _click(host, dock_point)
	assert(world.fishing_confirmation.visible and not overlay.active, "Re-entering fishing asks for confirmation again")
	await _click(host, world.fishing_confirmation.confirm_button.get_global_rect().get_center())
	assert(overlay.active, "The authored dock hotspot reopens fishing after confirmation")
	overlay.set_process(false)
	_land_named_fish(overlay.session, 91, "lapu_lapu", 25.0)
	_land_named_fish(overlay.session, 92, "lapu_lapu", 40.0)
	assert(PlayerState.get_fish_catches().size() == 2, "Landed fish are remembered individually before the result screen closes")
	overlay.close()
	await _settle(host)
	assert(overlay.active and overlay._catch_results.visible and world.map_button.disabled, "Finishing a session keeps its catch list modal until DONE")
	assert(overlay._catch_results._list.get_child_count() == 2)
	var shown: Array = overlay._catch_results._catches
	assert(shown[0].fish_id == "lapu_lapu" and shown[0].length_cm == 25.0 and shown[0].is_smallest and not shown[0].is_largest)
	assert(shown[1].length_cm == 40.0 and shown[1].is_largest and not shown[1].is_smallest, "Catch cards compare against final personal records, including later catches in the same session")
	assert(SaveContext.save_block_reason(home).to_lower().contains("fishing"))
	await _click(host, overlay._catch_results.done_button.get_global_rect().get_center())
	assert(not overlay.active and not overlay.visible and not world.map_button.disabled)
	assert(PlayerState.get_fish_catches().size() == 2, "Leaving the catch list retains the hidden fish inventory")
	world._show_map()
	assert(world.map_view.visible and not world.location_view.visible)
	assert(_resources() == original, "The prototype never pays cash, spends energy, damages condition or advances the calendar")
	tree.current_scene = null
	home.free()
	await _settle(host)


static func _land_named_fish(model, id: int, fish_id: String, length_cm: float) -> void:
	model.teleport_hook(Vector2(0.5, 0.4))
	var fish_entry := _fish(id, model.hook_tip_position())
	fish_entry.fish_id = fish_id
	fish_entry.length_cm = length_cm
	model.fish.assign([fish_entry])
	model.set_reel_held(true)
	model.update(0.001)
	assert(model.hooked_fish_id == id)
	model.fight_phase = "resting"
	model.fight_seconds_left = 10.0
	assert(model.reel(-1000.0) < 0.0 and model.hooked_fish_id == -1)


static func _reel_point(overlay, angle: float) -> Vector2:
	return overlay.source_to_global(Overlay.REEL_PIVOT + Vector2(cos(angle), sin(angle)) * 90.0)


static func _motion(host: Node, point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	host.get_viewport().push_input(event, true)
	await _settle(host)


static func _button(host: Node, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	if pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	# Input tracks the physical held state; the viewport routes GUI in headless runs.
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	host.get_viewport().push_input(event, true)
	await _settle(host)


static func _drag(host: Node, overlay, angles: Array) -> void:
	await _button(host, _reel_point(overlay, float(angles[0])), true)
	assert(overlay.dragging and overlay.cursor_locked)
	for index in range(1, angles.size()):
		await _reel_motion(host, overlay, float(angles[index]) - float(angles[index - 1]))
	await _button(host, overlay.source_to_global(overlay.grip_source_position()), false)
	assert(not overlay.dragging and not overlay.cursor_locked)


static func _reel_motion(host: Node, overlay, angle: float) -> void:
	var grip: Vector2 = overlay.grip_source_position()
	var radius := grip - Overlay.REEL_PIVOT
	var tangent := Vector2(-radius.y, radius.x).normalized()
	var source_delta := tangent * radius.length() * angle
	var global_delta: Vector2 = overlay.source_to_global(source_delta) - overlay.source_to_global(Vector2.ZERO)
	var event := InputEventMouseMotion.new()
	event.position = overlay.source_to_global(grip)
	event.global_position = event.position
	event.relative = global_delta
	event.screen_relative = global_delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	host.get_viewport().push_input(event, true)
	await _settle(host)


static func _click(host: Node, point: Vector2) -> void:
	await _motion(host, point)
	await _button(host, point, true)
	await _button(host, point, false)


static func _key(host: Node, key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		host.get_viewport().push_input(event, true)
		await _settle(host)


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
