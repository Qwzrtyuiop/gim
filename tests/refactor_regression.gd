extends Node

const Payload := preload("res://scripts/story/story_payload.gd")
const PayloadCatalog := preload("res://scripts/story/story_payload_catalog.gd")
const Catalog := preload("res://scripts/story/story_catalog.gd")
const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Constants := preload("res://scripts/story/story_constants.gd")
const Geometry := preload("res://scripts/game/vehicle_geometry.gd")
const TrafficIndex := preload("res://scripts/game/vehicle_traffic_index.gd")
const Traffic := preload("res://scripts/game/vehicle_traffic_controller.gd")
const Behaviors := preload("res://scripts/game/vehicle_behaviors.gd")
const Economy := preload("res://scripts/game/game_economy_manager.gd")
const Triggers := preload("res://scripts/story/story_trigger_service.gd")

class TrafficOwner extends Node2D:
	var active_entities: Array = []
	var texture_hitbox_cache: Dictionary = {}
	const VEHICLE_HITBOX_INSET := Vector4(0.05, 0.2, 0.05, 0.05)
	var npc_collision_lookahead := 0.7
	var npc_follow_gap := 45.0

func _ready() -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false), "Use run_refactor_checks.py to protect real saves")
	get_tree().current_scene = null
	await get_tree().process_frame
	PlayerState.achievement_unlocked.disconnect(AchievementPopupManager._on_achievement_unlocked)
	PlayerState.reset()
	var selected_checks: Array = ProjectSettings.get_setting("testing/checks", [])
	if not selected_checks.is_empty():
		if await _run_selected_checks(selected_checks):
			print("PASS: selected refactor regression checks")
			get_tree().quit()
		else:
			get_tree().quit(1)
		return
	_test_payloads()
	_test_catalog()
	_test_jessa_first_ride()
	load("res://tests/jessa_daytime_checks.gd").run()
	await load("res://tests/jessa_absence_checks.gd").run(self)
	_test_traffic()
	_test_state_ownership()
	load("res://tests/character_progress_checks.gd").run()
	load("res://tests/save_bug_checks.gd").run()
	await load("res://tests/save_slot_checks.gd").run(self)
	await load("res://tests/save_slot_deletion_checks.gd").run(self)
	await load("res://tests/story_slot_save_checks.gd").run(self)
	load("res://tests/day_flow_bug_checks.gd").run()
	load("res://tests/traffic_bug_checks.gd").run(self)
	_test_trigger_contracts()
	await _test_scene_modules()
	await load("res://tests/house_select_checks.gd").run(self)
	await load("res://tests/store_select_checks.gd").run(self)
	await load("res://tests/station_navigation_checks.gd").run(self)
	await load("res://tests/terminal_spawn_checks.gd").run(self)
	await load("res://tests/passenger_pickup_checks.gd").run(self)
	await load("res://tests/terminal_object_checks.gd").run(self)
	await load("res://tests/passenger_count_checks.gd").run(self)
	await load("res://tests/passenger_confirmation_checks.gd").run(self)
	await load("res://tests/results_screen_checks.gd").run(self)
	await load("res://tests/hub_dialogue_checks.gd").run(self)
	await load("res://tests/post_ride_home_checks.gd").run(self)
	await load("res://tests/midnight_checks.gd").run(self)
	await load("res://tests/hub_ambience_checks.gd").run(self)
	await load("res://tests/station_idle_music_checks.gd").run(self)
	await load("res://tests/hub_weather_checks.gd").run(self)
	await load("res://tests/map_travel_checks.gd").run(self)
	await load("res://tests/story_weather_checks.gd").run(self)
	await load("res://tests/rain_audio_checks.gd").run(self)
	await load("res://tests/ambient_continuity_checks.gd").run(self)
	await load("res://tests/hub_music_checks.gd").run(self)
	await load("res://tests/magda_daytime_checks.gd").run(self)
	await load("res://tests/gardo_midnight_checks.gd").run(self)
	await _test_library_modules()
	await _test_driving_modules()
	await load("res://tests/top_lane_pressure_checks.gd").run(self)
	await load("res://tests/incoming_group_checks.gd").run(self)
	load("res://tests/horn_checks.gd").run(self)
	await load("res://tests/input_bindings_checks.gd").run(self)
	await load("res://tests/tutorial_controls_checks.gd").run(self)
	await _test_checkpoints()
	await _test_interrupted_step()
	await _test_choice_event_resume()
	await _test_authored_resume()
	await load("res://tests/story_bug_checks.gd").run(self)
	await load("res://tests/stress_hull_checks.gd").run(self)
	await load("res://tests/stress_ui_checks.gd").run(self)
	await load("res://tests/stress_travel_checks.gd").run(self)
	await load("res://tests/construction_work_checks.gd").run(self)
	await load("res://tests/location_visit_checks.gd").run(self)
	await load("res://tests/fishing_checks.gd").run(self)
	await load("res://tests/achievement_reward_checks.gd").run(self)
	await load("res://tests/generic_passenger_event_checks.gd").run(self)
	await load("res://tests/local_hub_audio_checks.gd").run(self)
	load("res://tests/story_time_controls_checks.gd").run()
	load("res://tests/story_game_effects_checks.gd").run(self)
	load("res://tests/story_branch_tools_checks.gd").run(self)
	await load("res://tests/story_game_flow_checks.gd").run(self)
	await load("res://tests/passenger_story_checks.gd").run(self)
	await load("res://tests/isidro_first_encounter_checks.gd").run(self)
	await load("res://tests/story_character_sprite_checks.gd").run(self)
	await load("res://tests/story_location_placement_checks.gd").run(self)
	await load("res://tests/story_camera_checks.gd").run(self)
	await load("res://tests/story_street_background_checks.gd").run(self)
	load("res://tests/story_dialogue_voice_checks.gd").run(self)
	await load("res://tests/story_dialogue_playback_checks.gd").run(self)
	print("PASS: all refactor regression checks")
	get_tree().quit()

func _run_selected_checks(selected_checks: Array) -> bool:
	for selected: Variant in selected_checks:
		if not selected is String or not str(selected).is_valid_identifier():
			push_error("Invalid regression check target: %s" % str(selected))
			return false
		var target: String = str(selected)
		var method_name: String = "_test_%s" % target
		var runner: Callable
		if has_method(method_name):
			runner = Callable(self, method_name)
		else:
			var path: String = "res://tests/%s_checks.gd" % target
			if not ResourceLoader.exists(path):
				push_error("Unknown regression check target: %s" % target)
				return false
			var check: Script = load(path)
			if check == null:
				push_error("Could not load regression check target: %s" % target)
				return false
			runner = Callable(check, "run")
		if not runner.is_valid():
			push_error("Regression check target has no callable run method: %s" % target)
			return false
		var argument_count: int = runner.get_argument_count()
		if argument_count < 0 or argument_count > 1:
			push_error("Regression check target must accept zero or one argument: %s" % target)
			return false
		print("RUN: %s" % target)
		var started_ms: int = Time.get_ticks_msec()
		if argument_count == 0:
			await runner.call()
		else:
			await runner.call(self)
		print("DONE: %s (%.2fs)" % [target, float(Time.get_ticks_msec() - started_ms) / 1000.0])
	return true

func _find_filter_trigger(trigger: Dictionary, context: Dictionary = {}, events: Dictionary = {}) -> Dictionary:
	return Triggers.find_story_trigger_for_phase([trigger], {}, events, "day_end", 4, null, context)

func _test_trigger_contracts() -> void:
	PlayerState.reset()
	var base := {"id": "filter_fixture", "phase": "day_end", "bypass_character_story_gate": true, "payload": {"story_id": "filter_fixture", "composition": [{"text": "Test"}]}}
	var fields := {
		"stage_type": "stage_types",
		"time_of_day": "times",
		"current_time_of_day": "current_times",
		"difficulty": "difficulties",
		"traffic": "traffic_types",
		"character_id": "character_ids",
		"story_stage_id": "story_stage_ids",
	}
	assert(not _find_filter_trigger(base).is_empty())
	for field: String in fields:
		var context := {field: "matching"}
		var trigger := base.duplicate(true)
		trigger[field] = "matching"
		assert(not _find_filter_trigger(trigger, context).is_empty(), field)
		assert(_find_filter_trigger(trigger).is_empty(), "%s requires actual context" % field)
		trigger[field] = "different"
		assert(_find_filter_trigger(trigger, context).is_empty())
		trigger.erase(field)
		trigger[fields[field]] = ["matching", "alternative"]
		assert(not _find_filter_trigger(trigger, context).is_empty())
		trigger[fields[field]] = ["different"]
		assert(_find_filter_trigger(trigger, context).is_empty())
		trigger[fields[field]] = []
		assert(not _find_filter_trigger(trigger).is_empty(), "Empty arrays impose no constraint")
	var normalized: Dictionary = Triggers.normalize_trigger(PlayerState, {"phase": "day_end", "time_of_day": "noon", "phase_of_day": "night", "times": ["morning", "bad", "morning"], "phases": ["night"]})
	assert(normalized.time_of_day == "noon" and not normalized.has("phase_of_day"))
	assert(normalized.times == ["morning", "night"] and not normalized.has("phases"))
	assert(Triggers.normalize_trigger(PlayerState, {"phase": "day_end", "times": []}).times.is_empty())
	var event_trigger := base.duplicate(true)
	event_trigger.required_events = ["known"]
	for value in [false, 0]:
		assert(not _find_filter_trigger(event_trigger, {}, {"known": value}).is_empty())
	assert(_find_filter_trigger(event_trigger).is_empty())
	event_trigger.erase("required_events")
	event_trigger.forbidden_events = ["known"]
	assert(_find_filter_trigger(event_trigger, {}, {"known": false}).is_empty())
	event_trigger.erase("forbidden_events")
	event_trigger.required_event_values = {"known": false}
	assert(not _find_filter_trigger(event_trigger, {}, {"known": false}).is_empty())
	assert(_find_filter_trigger(event_trigger, {}, {"known": true}).is_empty())
	var story_rules: Array = Triggers.build_default_story_triggers()
	var consumed: Dictionary = {}
	var rider_context := {"character_id": "hana", "character_progress": 2, "time_of_day": "morning"}
	var character_event := Triggers.find_story_trigger_for_phase(story_rules, consumed, {}, "stage_complete", 2, null, rider_context)
	assert(character_event.get("id") == "hana_first_encounter", "Eligible character scenes take priority over the Day 2 bill")
	Triggers.consume_story_trigger(consumed, character_event)
	assert(not consumed.has("day_2_station_bill"), "Deferring the bill must not consume it")
	assert(Triggers.find_story_trigger_for_phase(story_rules, consumed, {}, "stage_complete", 2, null, rider_context).get("id") == "day_2_station_bill")
	rider_context.character_progress = 1
	assert(Triggers.find_story_trigger_for_phase(story_rules, {}, {}, "stage_complete", 2, null, rider_context).get("id") == "day_2_station_bill", "The bill still runs when no character scene qualifies")
	print("PASS: trigger scalar/array filters, time aliases, and false/zero event-presence contracts")

func _test_library_modules() -> void:
	PlayerState.reset()
	PlayerState.gallery_image_unlocks_initialized = true
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	var gallery = load("res://scenes/gallery_library.tscn").instantiate()
	get_tree().root.add_child(gallery)
	await get_tree().process_frame
	assert(gallery.empty_label.visible)
	gallery.memory_tab_button.pressed.emit()
	assert(gallery.empty_label.visible and gallery.selected_entry.is_empty())
	assert(PlayerState.get_meta("test_save_count", 0) == saves, "Browsing empty libraries must not save progress")
	gallery.free()
	var achievements = load("res://scenes/achievements_library.tscn").instantiate()
	get_tree().root.add_child(achievements)
	assert(achievements.empty_label.visible)
	achievements.free()

	PlayerState.set_last_seen_story_section("scene_01_intro", 0)
	PlayerState.unlock_gallery_image(Constants.BACKGROUND_INHOUSE)
	PlayerState.unlock_achievement("tapat")
	saves = PlayerState.get_meta("test_save_count", 0)
	gallery = load("res://scenes/gallery_library.tscn").instantiate()
	get_tree().root.add_child(gallery)
	await get_tree().process_frame
	assert(not gallery.empty_label.visible)
	var image_button := gallery.list_container.get_child(0).get_child(0) as Button
	image_button.pressed.emit()
	assert(gallery.image_overlay.visible and gallery.expanded_image.texture != null)
	gallery.close_image_button.pressed.emit()
	assert(not gallery.image_overlay.visible and gallery.expanded_image.texture == null)
	gallery.memory_tab_button.pressed.emit()
	assert(not gallery.selected_entry.is_empty() and not gallery.replay_button.disabled)
	assert(gallery.memory_bottom_spacer.custom_minimum_size.y >= 96.0)
	assert((gallery.list_container.get_child(0) as Button).button_pressed)
	var memory_catalog = load("res://scripts/story/story_memory_catalog.gd")
	var replay: Dictionary = memory_catalog.build_memory_payload(str(gallery.selected_entry.id), "res://scenes/gallery_library.tscn")
	assert(replay.replay and replay.memory_replay)
	assert(not replay.has("prepare_stage_start") and not replay.has("stage_descriptor"))
	gallery.free()
	achievements = load("res://scenes/achievements_library.tscn").instantiate()
	get_tree().root.add_child(achievements)
	assert(not achievements.empty_label.visible)
	(achievements.list_container.get_child(0) as Button).pressed.emit()
	assert(achievements.detail_overlay.visible and not achievements.detail_body.text.is_empty())
	achievements.close_button.pressed.emit()
	assert(not achievements.detail_overlay.visible)
	achievements.free()
	assert(PlayerState.get_meta("test_save_count", 0) == saves, "Library navigation must leave progress untouched")
	PlayerState.reset()
	print("PASS: empty/unlocked libraries, memory selection/replay, gallery overlay, achievement details, read-only browsing")

func _test_choice_event_resume() -> void:
	PlayerState.reset()
	var payload := Payload.normalize({"story_id": "choice_event_cursor", "composition": [
		{"text": "Choose", "choices": [{"text": "Continue", "next_index": 1, "event_values": {"test_choice_cursor": 1}, "actions": [
			{"type": "set_event_value", "id": "test_choice_cursor", "value": 2},
			{"type": "wait", "duration": 0.4},
			{"type": "add_money", "amount": 20},
		]}]},
		{"text": "Completed"},
	]})
	var reader = await _reader(payload)
	reader._choose_branch(reader.story_lines[0].choices[0])
	await get_tree().create_timer(0.1).timeout
	assert(PlayerState.get_event_value("test_choice_cursor") == 2)
	reader.free()
	assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
	reader = await _reader(PlayerState.get_pending_story())
	assert(PlayerState.get_event_value("test_choice_cursor") == 2, "Resume must not reapply older choice metadata")
	assert(PlayerState.money == 20 and reader.current_line_index == 1)
	reader.free()
	print("PASS: interrupted choice preserves completed event actions and pays remaining reward once")

func _test_state_ownership() -> void:
	PlayerState.reset()
	PlayerState.seed_rider_for_stage("benny", 2, "morning", "short", 0, "traffic-jam")
	var rules: Array = PlayerState.get_seeded_rider_rules()
	assert(rules.size() == 1 and rules[0].character_id == "benny")
	assert(rules[0].forced_traffic == "traffic-jam")
	var rule_id: String = rules[0].id
	rules[0].character_id = "changed copy"
	assert(PlayerState.get_seeded_rider_rules()[0].character_id == "benny")
	PlayerState.consume_seeded_rider_rules([rule_id])
	assert(PlayerState.consumed_seeded_rider_rules.get(rule_id, false))
	PlayerState.clear_seeded_rider_rules()
	assert(PlayerState.get_seeded_rider_rules().is_empty())
	PlayerState.set_last_stage_result({"total": 125})
	var result: Dictionary = PlayerState.get_last_stage_result()
	result.total = 999
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	assert(PlayerState.claim_last_stage_total() == 125)
	assert(PlayerState.money == 125 and PlayerState.claim_last_stage_total() == 0)
	assert(PlayerState.get_meta("test_save_count", 0) - saves == 1)
	PlayerState.set_last_stage_result({"total": 100, "random_ride_event": "malasakit"})
	assert(PlayerState.claim_last_stage_total() == 0 and PlayerState.money == 125)
	print("PASS: seeded rider mutation/copy isolation and one-time batched payout")

func _test_scene_modules() -> void:
	PlayerState.reset()
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	assert(not menu._is_debug_unlock_panel_open())
	menu._open_debug_unlock_panel()
	assert(menu._is_debug_unlock_panel_open())
	menu._close_debug_unlock_panel()
	assert(not menu._is_debug_unlock_panel_open())
	var language: String = StoryLanguageManager.get_language()
	menu._toggle_story_language()
	assert(StoryLanguageManager.get_language() != language)
	menu._toggle_story_language()
	assert(StoryLanguageManager.get_language() == language)
	menu._toggle_audio_panel()
	assert(menu.audio_panel_refs.panel.visible)
	menu._toggle_audio_panel()
	assert(not menu.audio_panel_refs.panel.visible)
	menu.free()

	PlayerState.reset()
	PlayerState.prepare_day_start(2)
	PlayerState.stage_round = 0
	var home = load("res://scenes/day_start_scene.tscn").instantiate()
	get_tree().root.add_child(home)
	await get_tree().process_frame
	assert(home.tutorial_active and home.tutorial_steps.size() == 5)
	for step in range(16):
		if not home.tutorial_active:
			break
		home._advance_tutorial()
	assert(not home.tutorial_active)
	for action in ["calendar", "radio", "rest"]:
		home._show_info(action)
		assert(home.info_overlay.visible and home.info_action == action)
		home._close_info()
		assert(not home.info_overlay.visible)
	home.free()

	PlayerState.reset()
	PlayerState.money = 10000
	PlayerState.gas = 50.0
	var store = load("res://scenes/store.tscn").instantiate()
	get_tree().root.add_child(store)
	await get_tree().process_frame
	assert(store.tutorial_active)
	for step in range(16):
		if not store.tutorial_active:
			break
		store._advance_tutorial()
	assert(not store.tutorial_active)
	store._open_shop("tricycle")
	var items: Array = load("res://scripts/store/store_item_catalog.gd").ITEMS
	assert(store.store_buy_buttons.size() == items.size())
	for i in range(items.size()):
		var item: Dictionary = items[i]
		if item.type != "gas" and item.type != "upgrade":
			continue
		var cost: int = store._item_cost(item)
		var money_before: int = PlayerState.money
		store.store_buy_buttons[i].pressed.emit()
		assert(PlayerState.money == money_before - cost)
		if item.type == "upgrade":
			assert(PlayerState.get_upgrade_level(item.id) == 1)
			assert(store._item_cost(item) == cost + int(item.get("cost_step", 0)))
		else:
			assert(PlayerState.gas == 50.0 + float(item.gas))
	store._close_shop()
	assert(not store.shop_overlay.visible)
	store.free()

	PlayerState.reset()
	PlayerState.set_pending_trip_selection("res://scenes/main_menu.tscn", PlayerState.TRANSITION_CURRENT_STAGE, false)
	var selection = load("res://scenes/ride_selection.tscn").instantiate()
	get_tree().root.add_child(selection)
	await get_tree().process_frame
	assert(not selection.passenger_overlay.visible and selection.station_tutorial.active, "The opening ride begins with the station-front tutorial")
	for step in range(16):
		if not selection.station_tutorial.active:
			break
		selection.station_tutorial.advance()
	assert(not selection.station_tutorial.active and selection.passenger_overlay.visible and selection.tutorial.active, "Completing the station tutorial opens passenger onboarding")
	selection._close_passengers()
	assert(selection.passenger_overlay.visible and selection.tutorial.active, "The active tutorial keeps its targets visible")
	for step in range(16):
		if not selection.tutorial.active:
			break
		selection.tutorial.advance()
	assert(not selection.tutorial.active)
	selection._set_distance("long")
	assert(selection.selected_distance == "short", "The first ride remains locked to short")
	var pools: Dictionary = selection.locked_character_pools.duplicate(true)
	selection._set_distance("medium")
	assert(selection.locked_character_pools == pools, "Changing distance must not reroll offers")
	selection.free()
	PlayerState.prepare_day_start(2)
	PlayerState.set_pending_trip_selection("res://scenes/day_start_scene.tscn")
	selection = load("res://scenes/ride_selection.tscn").instantiate()
	get_tree().root.add_child(selection)
	await get_tree().process_frame
	pools = selection.locked_character_pools.duplicate(true)
	for distance in ["short", "medium", "long"]:
		selection._set_distance(distance)
		assert(selection.selected_distance == distance)
		assert(selection.locked_character_pools == pools)
		assert(selection.displayed_characters.size() == 3)
	selection.free()
	PlayerState.reset()
	print("PASS: menu settings/debug callbacks, home panels, store purchases, tutorials and locked passenger offers")

func _test_driving_modules() -> void:
	for profile in ["short-morning-normal", "long-night-busy", "medium-noon-speeders"]:
		PlayerState.reset()
		var game = load("res://scenes/main.tscn").instantiate()
		game.use_player_state_stage_sequence = false
		game.stage_type = profile
		get_tree().root.add_child(game)
		await get_tree().process_frame
		game.set_process(false)
		game.rng.seed = 20261024
		game.target_distance = 1000000.0
		game.time_left = 10000.0
		game.player_hit_invincible_timer = 10000.0
		var saw_traffic := false
		for frame in range(300):
			game._process(0.1)
			saw_traffic = saw_traffic or not game.active_entities.is_empty()
		assert(game.game_state == "playing")
		assert(game.background_scroller != null and game.player != null)
		assert(saw_traffic, "%s must spawn traffic during the simulation" % profile)
		game.player_hit_recovery_timer = 0.2
		game._update_player_hit_state(0.1)
		assert(is_equal_approx(game.player_hit_recovery_timer, 0.1))
		game.player_hit_invincible_timer = 0.0
		game._apply_player_hit_visuals()
		assert(game.player.modulate == Color.WHITE)
		game.free()
	PlayerState.reset()
	print("PASS: driving initialization, traffic updates and hit visuals in normal/busy/speeders profiles")

func _test_payloads() -> void:
	var count := 0
	for language in ["english", "tagalog"]:
		StoryLanguageManager.set_language(language)
		for id: String in PayloadCatalog.STORIES:
			var payload := PayloadCatalog.build(id)
			assert(payload.schema_version == Payload.VERSION)
			assert(Payload.validate(payload).is_empty(), "%s/%s: %s" % [id, language, Payload.validate(payload)])
			assert(payload == Payload.normalize(payload), "Normalization must be idempotent")
			for line: Dictionary in payload.composition:
				assert(line.has("speaker") and line.has("text") and line.has("actions") and line.has("choices"))
				assert(not line.has("triggers"))
				for choice: Dictionary in line.choices:
					assert(choice.has("actions") and not choice.has("effects"))
			count += 1
	var legacy := {"story_id": "old", "bgm": "music.mp3", "sections": [{"triggers": [{"action": "add_money", "amount": 1}], "choices": [{"effects": [{"action": "add_energy"}], "next_index": 1}]}]}
	var normalized := Payload.normalize(legacy)
	assert(legacy.has("sections") and not normalized.has("sections"))
	assert(normalized.composition[0].actions[0].type == "add_money")
	assert(normalized.composition[0].choices[0].actions[0].type == "add_energy")
	var template: Dictionary = load("res://scripts/story/payloads/templates/story_payload_template.gd").build()
	assert(Payload.validate(template).is_empty())
	var station_story := PayloadCatalog.build("malasakit")
	station_story.music.volume_db = -99.0
	station_story.composition[0].text = "Changed copy"
	var fresh_story := PayloadCatalog.build("malasakit")
	assert(fresh_story.music.volume_db == -9.0, "Shared audio defaults must remain isolated from runtime changes")
	assert(fresh_story.composition[0].text != "Changed copy")
	print("PASS: %d localized payloads, jumps, canonical schema, legacy conversion" % count)

func _test_catalog() -> void:
	for progress in [0, 1, 2, 5]:
		PlayerState.character_completed_rides["ely"] = progress
		PlayerState.unique_character_progress["ely"] = progress
		for expected: Dictionary in Catalog.get_mock_characters(PlayerState):
			assert(Catalog.get_character_by_id(PlayerState, expected.id) == expected)
		assert(Catalog.get_character_display_name(PlayerState, "ely") == ("???" if progress < 2 else "Elena"))
		assert(Catalog.get_character_display_name(PlayerState, "jessa") == "???")
	var character := Catalog.get_character_by_id(PlayerState, "ely")
	character.name = "mutated"
	assert(Catalog.get_character_by_id(PlayerState, "ely").name == "Elena")
	PlayerState.event_values["jessa_name_revealed"] = true
	assert(Catalog.get_speaker_display_name(PlayerState, "Jessa") == "Jessa")
	assert(Catalog.get_character_by_id(PlayerState, "missing").is_empty())
	var start := Time.get_ticks_usec()
	for i in range(1000):
		for candidate: Dictionary in Catalog.get_mock_characters(PlayerState):
			if candidate.id == "ely":
				break
	var full_catalog_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for i in range(1000):
		Catalog.get_character_by_id(PlayerState, "ely")
	print("PASS: catalog identity/progress/name rules; 1000 lookups full catalog=%dus indexed=%dus" % [full_catalog_us, Time.get_ticks_usec() - start])

func _test_jessa_first_ride() -> void:
	for language in ["english", "tagalog"]:
		for daytime in ["morning", "noon"]:
			PlayerState.reset()
			StoryLanguageManager.set_language(language)
			PlayerState.money = 500
			PlayerState.current_day = 1
			PlayerState.set_current_mock_character("jessa")
			PlayerState.set_current_stage_time(daytime)
			assert(PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": daytime}).is_empty(), "No event before her first completed ride")
			var stage := "short-%s-normal" % daytime
			Economy.store_stage_result(stage, "short", daytime, "normal", "", "", 200, 200, 1, 0, 0, 10, 2, 0)
			assert(PlayerState.get_unique_character_progress("jessa") == 1)
			assert(not PlayerState.event_values.has("day_2_station_bill"))
			var original_total: int = PlayerState.last_stage_result.total
			var payload := Economy.stage_complete_story_payload(stage, "short", daytime, "normal")
			assert(payload.get("story_id") == "jessa_runaway_fare", "A daytime first ride queues Jessa's event, including a noon result whose live clock is already night")
			assert(payload.original_ride_earnings.total == original_total and original_total > 0)
			assert(PlayerState.last_stage_result.total == 0 and PlayerState.last_stage_result.fare == 0 and PlayerState.last_stage_result.bonus == 0)
			assert(PlayerState.get_character_display_name("jessa") == "???")
			assert(PlayerState.claim_last_stage_total() == 0 and PlayerState.money == 500)
			assert(PlayerState.find_story_trigger_for_phase("stage_complete", 2, {"character_id": "jessa", "time_of_day": daytime}).get("id") != "jessa_runaway_fare", "Consumed Jessa events cannot repeat; other daytime events remain eligible")
		# An older locked nighttime offer must not consume the encounter or fare.
		PlayerState.reset()
		PlayerState.set_current_mock_character("jessa")
		PlayerState.set_current_stage_time("night")
		Economy.store_stage_result("short-night-normal", "short", "night", "normal", "", "", 200, 200, 1, 0, 0, 10, 2, 0)
		var night_total: int = PlayerState.last_stage_result.total
		assert(Economy.stage_complete_story_payload("short-night-normal", "short", "night", "normal").is_empty())
		assert(PlayerState.pending_story.is_empty() and not bool(PlayerState.consumed_story_triggers.get("jessa_runaway_fare", false)))
		assert(PlayerState.last_stage_result.total == night_total and PlayerState.claim_last_stage_total() == night_total)
		assert(PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": "morning"}).get("id") == "jessa_runaway_fare", "A blocked nighttime encounter remains eligible next daytime")
	# Existing saves keep their old rule; loading must migrate it, preserving
	# already consumed events and custom rules with different requirements.
	PlayerState.reset()
	for trigger: Dictionary in PlayerState.story_triggers:
		if trigger.id == "jessa_runaway_fare":
			trigger.min_character_progress = 2
			trigger.required_events = ["day_2_station_bill"]
			trigger.erase("bypass_character_story_gate")
			trigger.erase("times")
	Codec.save_to_path(PlayerState, "res://test_user/jessa_old_trigger.tres", PlayerState.SAVE_VERSION)
	assert(Codec.load_from_path(PlayerState, "res://test_user/jessa_old_trigger.tres"))
	var migrated := PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": "morning"})
	assert(migrated.is_empty())
	PlayerState.set_unique_character_progress("jessa", 1)
	assert(PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": "night"}).is_empty())
	migrated = PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": "morning"})
	assert(migrated.get("id") == "jessa_runaway_fare")
	assert(not Triggers.ensure_required_story_triggers(PlayerState.story_triggers), "Migration must be idempotent")
	PlayerState.consume_story_trigger(migrated)
	Codec.save_to_path(PlayerState, "res://test_user/jessa_consumed_trigger.tres", PlayerState.SAVE_VERSION)
	assert(Codec.load_from_path(PlayerState, "res://test_user/jessa_consumed_trigger.tres"))
	assert(PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": "morning"}).is_empty())
	# Current-version saves may contain the unrestricted, already upgraded rule.
	PlayerState.reset()
	for trigger: Dictionary in PlayerState.story_triggers:
		if trigger.id == "jessa_runaway_fare":
			trigger.erase("times")
	Codec.save_to_path(PlayerState, "res://test_user/jessa_unrestricted_trigger.tres", PlayerState.SAVE_VERSION)
	assert(Codec.load_from_path(PlayerState, "res://test_user/jessa_unrestricted_trigger.tres"))
	PlayerState.set_unique_character_progress("jessa", 1)
	assert(PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": "night"}).is_empty())
	assert(PlayerState.find_story_trigger_for_phase("stage_complete", 1, {"character_id": "jessa", "time_of_day": "noon"}).get("id") == "jessa_runaway_fare")
	var custom_rules := Triggers.build_default_story_triggers()
	for trigger: Dictionary in custom_rules:
		if trigger.id == "jessa_runaway_fare":
			trigger.min_character_progress = 3
			trigger.required_events = ["custom_event"]
			trigger.erase("times")
	var custom_before := custom_rules.duplicate(true)
	assert(not Triggers.ensure_required_story_triggers(custom_rules) and custom_rules == custom_before)
	for character_id in ["benny", "ely"]:
		assert(Triggers.find_story_trigger_for_phase(Triggers.build_default_story_triggers(), {}, {}, "stage_complete", 1, null, {"character_id": character_id, "character_progress": 2, "time_of_day": "night"}).is_empty(), "Other characters keep their Day 2 gate")
	PlayerState.reset()
	print("PASS: Jessa daytime first encounter in both languages, nighttime fare preservation, hidden name, saved-rule migrations and once-per-run behavior")

func _test_traffic() -> void:
	var owner := TrafficOwner.new()
	add_child(owner)
	var texture: Texture2D = load("res://assets/characters/John.png")
	for i in range(48):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = Vector2((i / 3) * 34.0, (i % 3) * 120.0)
		sprite.scale = Vector2(0.12, 0.12)
		owner.add_child(sprite)
		owner.active_entities.append({"sprite": sprite, "lane": i % 3, "kind": "speeder" if i % 7 == 0 else "traffic", "spawn_side": "left" if i % 2 == 0 else "right", "world_speed": 100.0 + i * 3, "is_parked": i % 11 == 0})
	for lane in range(3):
		var expected := owner.active_entities.filter(func(e): return e.lane == lane)
		assert(TrafficIndex.in_lane(owner, lane) == expected)
	var sprite: Sprite2D = owner.active_entities[0].sprite
	for flip in [false, true]:
		sprite.flip_h = flip
		sprite.flip_v = flip
		for scale_value in [0.12, 0.3]:
			sprite.scale = Vector2.ONE * scale_value
			for x in [0.0, 50.0, 300.0]:
				sprite.position.x = x
				var expected := Geometry.collision_rect_for_transform(sprite, sprite.global_position, sprite.scale, Geometry.local_hitbox_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner))
				assert(Geometry.collision_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner) == expected)
				assert(Geometry.collision_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner) == expected)
	owner.active_entities[0].lane = 2
	TrafficIndex.invalidate(owner)
	assert(not TrafficIndex.in_lane(owner, 0).has(owner.active_entities[0]))
	assert(TrafficIndex.in_lane(owner, 2).has(owner.active_entities[0]))
	var removed: Dictionary = owner.active_entities.pop_back()
	assert(not TrafficIndex.in_lane(owner, removed.lane).has(removed))
	owner.active_entities.append(removed)
	assert(TrafficIndex.in_lane(owner, removed.lane).has(removed))
	owner.active_entities = owner.active_entities.duplicate(true)
	assert(is_same(TrafficIndex.in_lane(owner, owner.active_entities[0].lane)[0], owner.active_entities[0]))
	# Reference following pass: same algorithm, original full-list inputs.
	var reference := owner.active_entities.duplicate(true)
	for entity: Dictionary in reference:
		entity.desired_world_speed = entity.world_speed
	for lane in range(3):
		for direction in [true, false]:
			Behaviors.update_npc_following_for_direction(reference, lane, direction, 45.0, 0.7, owner.VEHICLE_HITBOX_INSET, func(s, inset): return Geometry.collision_rect(s, inset, owner))
	Behaviors.update_npc_following(owner.active_entities, 45.0, 0.7, owner.VEHICLE_HITBOX_INSET, func(s, inset): return Geometry.collision_rect(s, inset, owner))
	assert(owner.active_entities == reference)
	var geometry_start := Time.get_ticks_usec()
	for repeat in range(10000):
		Geometry.collision_rect_for_transform(sprite, sprite.global_position, sprite.scale, Geometry.local_hitbox_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner))
	var uncached_time := Time.get_ticks_usec() - geometry_start
	geometry_start = Time.get_ticks_usec()
	for repeat in range(10000):
		Geometry.collision_rect(sprite, owner.VEHICLE_HITBOX_INSET, owner)
	print("Collision geometry, 10000 repeated queries: uncached=%dus cached=%dus" % [uncached_time, Time.get_ticks_usec() - geometry_start])
	# Optional old implementations supplied by the local comparison run.
	if FileAccess.file_exists("res://traffic_baseline.gd"):
		var baseline: Script = load("res://traffic_baseline.gd")
		for entity: Dictionary in owner.active_entities:
			for lane in range(3):
				assert(Traffic.find_front_collision_entity(owner, entity, lane) == baseline.find_front_collision_entity(owner, entity, lane))
		var started := Time.get_ticks_usec()
		for repeat in range(30):
			for entity: Dictionary in owner.active_entities:
				baseline.find_front_collision_entity(owner, entity, entity.lane)
		var old_time := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		for repeat in range(30):
			for entity: Dictionary in owner.active_entities:
				Traffic.find_front_collision_entity(owner, entity, entity.lane)
		print("Traffic scan comparison, 48 vehicles: full-list=%dus lanes=%dus" % [old_time, Time.get_ticks_usec() - started])
	owner.free()
	print("PASS: lane membership/order, same-frame geometry invalidation, following behavior")

func _reader(payload: Dictionary):
	PlayerState.set_pending_story(payload)
	var reader = load("res://scenes/story_scene.tscn").instantiate()
	get_tree().root.add_child(reader)
	await get_tree().create_timer(1.1).timeout
	assert(not reader.is_input_locked)
	return reader

func _resume(reader):
	Codec.save_to_path(PlayerState, "res://test_user/checkpoint.tres", PlayerState.SAVE_VERSION)
	reader.free()
	PlayerState.reset()
	assert(Codec.load_from_path(PlayerState, "res://test_user/checkpoint.tres"))
	return await _reader(PlayerState.get_pending_story())

func _test_checkpoints() -> void:
	PlayerState.reset()
	PlayerState.money = 500
	var payload := Payload.normalize({"story_id": "test_branch_checkpoint", "background": Constants.BACKGROUND_STATION, "music": {"path": Constants.MUSIC_CITY_AMBIENCE, "fade_in": 0.0}, "composition": [
		{"text": "Choose", "choices": [{"text": "Skip the silence", "next_index": 2, "actions": [{"type": "add_money", "amount": 25}]}]},
		{"text": "Unchosen", "actions": [{"type": "stop_music", "fade": 0.0}]},
		{"speaker": "John Toda", "text": "Chosen", "background": Constants.BACKGROUND_INHOUSE, "actions": [{"type": "add_money", "amount": 10}, {"type": "add_karma", "amount": 1}, {"type": "set_event_value", "id": "test_branch", "value": true}]},
		{"text": "Quiet", "actions": [{"type": "stop_music", "fade": 0.0}]},
	]})
	var reader = await _reader(payload)
	var saves: int = PlayerState.get_meta("test_save_count", 0)
	await reader._choose_branch(reader.story_lines[0].choices[0])
	assert(PlayerState.money == 535 and PlayerState.event_values.test_branch)
	assert(PlayerState.get_meta("test_save_count", 0) - saves == 1, "Choice and next line must flush one save")
	reader = await _resume(reader)
	assert(reader.current_line_index == 2 and reader.body_label.text == "Chosen")
	assert(PlayerState.money == 535, "Resume must not repeat money actions")
	assert(reader.bgm_player.playing, "Unchosen stop_music must not silence this branch")
	assert(reader.current_background_ref == Constants.BACKGROUND_INHOUSE)
	await reader._show_line(3)
	reader = await _resume(reader)
	assert(not reader.bgm_player.playing)
	assert(PlayerState.money == 535 and PlayerState._state_batch_depth == 0)
	reader.free()
	print("PASS: one save per step, real save/load, branch-correct music/background, no repeated rewards")

func _test_authored_resume() -> void:
	for language in ["english", "tagalog"]:
		for branch in [0, 1]:
			PlayerState.reset()
			StoryLanguageManager.set_language(language)
			var payload := PayloadCatalog.build("elena_old_acquaintance")
			var reader = await _reader(payload)
			await reader._show_line(13)
			await reader._choose_branch(reader.story_lines[13].choices[branch])
			var text_before: String = reader.body_label.text
			reader = await _resume(reader)
			assert(reader.body_label.text == text_before)
			assert(reader.bgm_player.playing == (branch == 1))
			assert(reader.sfx_player.playing, "Engine loop must resume")
			reader.free()
		PlayerState.reset()
		StoryLanguageManager.set_language(language)
		var reader = await _reader(PayloadCatalog.build("jessa_runaway_fare"))
		await reader._show_line(15)
		await reader._show_line(21)
		reader = await _resume(reader)
		assert(reader.current_background_ref == Constants.BACKGROUND_ALLEY)
		assert(reader.bgm_player.playing and str(reader.bgm_player.get_meta("music_ref")).ends_with("funny.mp3"))
		assert(reader.shown_gallery_images.has(Constants.BACKGROUND_STATION))
		reader.free()
	print("PASS: Elena truth/lie and Jessa alley/audio checkpoints in both languages")

func _test_interrupted_step() -> void:
	for interrupt_choice in [false, true]:
		PlayerState.reset()
		PlayerState.money = 500
		var actions := [{"type": "add_money", "amount": 10}, {"type": "wait", "duration": 0.4}, {"type": "add_money", "amount": 20}]
		var payload := Payload.normalize({"story_id": "interrupt_%s" % interrupt_choice, "composition": [
			{"text": "Start", "choices": [{"text": "Continue", "next_index": 1, "actions": actions if interrupt_choice else []}]},
			{"text": "End", "actions": [] if interrupt_choice else actions},
		]})
		var reader = await _reader(payload)
		reader._choose_branch(reader.story_lines[0].choices[0])
		await get_tree().create_timer(0.1).timeout
		assert(PlayerState.money == 510)
		reader.free()
		assert(PlayerState._state_batch_depth == 0)
		assert(PlayerState.pending_story._checkpoint.continuation.action_index == 1)
		assert(Codec.load_from_path(PlayerState, PlayerState.SAVE_PATH))
		reader = await _reader(PlayerState.get_pending_story())
		assert(PlayerState.money == 530, "Interrupted step must resume remaining actions exactly once")
		assert(reader.current_line_index == 1 and reader.checkpoint_continuation.is_empty())
		reader = await _resume(reader)
		assert(PlayerState.money == 530)
		reader.free()
	print("PASS: exiting during line/choice waits resumes remaining actions exactly once")
