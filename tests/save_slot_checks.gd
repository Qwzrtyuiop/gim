extends RefCounted

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const Context := preload("res://scripts/save/save_game_context.gd")
const SlotScreen := preload("res://scripts/ui/save_slot_screen.gd")
const Driving := preload("res://scripts/save/driving_save_snapshot.gd")
const Spawner := preload("res://scripts/game/vehicle_spawner.gd")
const HOME := "res://scenes/day_start_scene.tscn"
const MAIN := "res://scenes/main.tscn"


class MenuWithoutSceneTransition extends "res://scripts/main_menu.gd":
	var intro_started := false

	func _fade_to_intro_story() -> void:
		intro_started = true


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	for slot in range(1, 11):
		var path: String = SaveSlotManager.slot_path(slot)
		assert(path.begins_with("res://test_user/"), "Slots must use disposable fixture paths")
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	PlayerState.reset()
	SaveSlotManager.begin_new_run()
	PlayerState.current_day = 2
	PlayerState.money = 321
	PlayerState.set_resume_scene(HOME)
	var context := {"scene": HOME, "location": "Home", "preview_path": "res://assets/story/backgrounds/locations/inhouse.png"}
	assert(SaveSlotManager.list_slots().size() == 10)
	assert(SaveSlotManager.save_slot(1, context) == ERR_INVALID_PARAMETER)
	assert(SaveSlotManager.save_slot(0, context) == ERR_INVALID_PARAMETER)
	assert(SaveSlotManager.save_slot(2, context) == OK)
	var held: Resource = ResourceLoader.load(SaveSlotManager.slot_path(2))
	PlayerState.money = 654
	assert(SaveSlotManager.save_slot(10, context) == OK)
	assert(SaveSlotManager.autosave_day(context) == OK)
	PlayerState.money = 999
	assert(SaveSlotManager.autosave_day(context) == OK)
	assert(SaveSlotManager.load_slot(1) and PlayerState.money == 654)
	PlayerState.current_day = 3
	PlayerState.money = 777
	assert(SaveSlotManager.autosave_day(context) == OK)
	assert(SaveSlotManager.load_slot(2) and PlayerState.money == 321 and PlayerState.current_day == 2)
	PlayerState.current_day = 3
	PlayerState.money = 888
	assert(SaveSlotManager.autosave_day(context) == OK)
	assert(SaveSlotManager.load_slot(1) and PlayerState.money == 888, "Reaching a day again must replace the daily autosave")
	assert(held.data.money == 321, "Other slots and cached resources stay independent")
	assert(SaveSlotManager.load_slot(10) and PlayerState.money == 654)
	assert(Context.resume_scene() == HOME)
	var entries: Array[Dictionary] = SaveSlotManager.list_slots()
	assert(not str(entries[1].saved_at).is_empty() and entries[1].location == "Home")
	var damaged := Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	damaged.data.erase("money")
	assert(Codec.write_snapshot(damaged, SaveSlotManager.slot_path(3)) == OK)
	assert(not SaveSlotManager.load_slot(3) and PlayerState.money == 654)
	await _screen(host, entries)
	await _driving(host)
	await _story_handoff(host)
	await _menus_and_daily_hook(host)
	PlayerState.reset()
	assert(SaveSlotManager.has_slots(), "New-run reset must preserve manual slots")
	AmbientAudioManager.stop_all()
	HubMusicManager.stop_all()
	# These fixtures replace current_scene manually, bypassing scene_changed.
	await host.get_tree().create_timer(0.1).timeout
	print("PASS: ten slots, daily autosave/revisited days, independent snapshots, invalid-file isolation, calendar confirmation/scroll, driving restoration and story load batching")


static func _screen(host: Node, entries: Array[Dictionary]) -> void:
	var screen := SlotScreen.new()
	host.add_child(screen)
	screen.open("save", entries)
	await host.get_tree().process_frame
	assert(screen.slot_buttons.size() == 10 and screen.slot_buttons[1].disabled)
	assert(not screen.slot_buttons[10].disabled)
	assert(screen.slot_list.size.y > screen.scroll.size.y)
	screen._select_slot(2)
	assert(screen.confirmation.visible)
	screen.handle_cancel()
	assert(not screen.confirmation.visible and screen.visible)
	screen.open("load", entries, false)
	assert(not screen.slot_buttons[1].disabled and screen.slot_buttons[4].disabled)
	screen._select_slot(10)
	assert(screen.confirmation.visible)
	screen.handle_cancel()
	screen.handle_cancel()
	assert(not screen.visible)
	screen.free()


static func _driving(host: Node) -> void:
	PlayerState.reset()
	PlayerState.current_day = 3
	PlayerState.current_stage_type = "short-morning-chill"
	var game = load(MAIN).instantiate()
	game.use_player_state_stage_sequence = false
	host.get_tree().root.add_child(game)
	game.set_process(false)
	assert(Spawner.spawn_traffic(game, 1))
	game.distance = 123.0
	game.time_left = 42.0
	game.player_speed = 189.0
	game.rng.seed = 20261026
	var captured: Dictionary = Driving.capture(game)
	var expected_rng: int = game.rng.state
	assert(SaveSlotManager.save_slot(4, {"scene": MAIN, "runtime": {"scene": MAIN, "driving": captured}}) == OK)
	game.distance = 0.0
	game.time_left = 0.0
	assert(SaveSlotManager.load_slot(4))
	var loaded: Dictionary = PlayerState.get_meta("loaded_slot_runtime")
	assert(Driving.restore(game, loaded.driving))
	assert(game.distance == 123.0 and game.time_left == 42.0 and game.player_speed == 189.0)
	assert(game.active_entities.size() == captured.entities.size() and game.rng.state == expected_rng)
	game.free()
	var resumed = load(MAIN).instantiate()
	host.get_tree().root.add_child(resumed)
	resumed.set_process(false)
	assert(resumed.distance == 123.0 and resumed.time_left == 42.0)
	assert(not PlayerState.has_meta("loaded_slot_runtime"), "Driving scene must consume the loaded snapshot")
	resumed.free()
	await host.get_tree().process_frame


static func _story_handoff(host: Node) -> void:
	PlayerState.reset()
	PlayerState.pending_story = {
		"story_id": "slot_story_fixture",
		"composition": [{"speaker": "John", "text": "Checkpoint."}],
	}
	var reader = load("res://scenes/story_scene.tscn").instantiate()
	host.get_tree().root.add_child(reader)
	# Finish the asynchronous intro before freeing this reader during handoff.
	# A node-bound fade killed mid-await leaves its static coroutine suspended.
	for _frame in range(120):
		if reader.body_label.text == "Checkpoint.":
			break
		await host.get_tree().process_frame
	assert(reader.body_label.text == "Checkpoint.", "Story fixture must finish opening before checkpoint handoff")
	assert(reader.checkpoint_batch_depth == 0)
	assert(SaveSlotManager.save_slot(5, Context.capture(reader)) == OK)
	reader._begin_checkpoint_batch()
	reader.body_label.text = "Old unsaved line"
	Context.prepare_scene_for_load(reader)
	assert(PlayerState._state_batch_depth == 0 and reader.checkpoint_batch_depth == 0)
	assert(SaveSlotManager.load_slot(5))
	var expected: Dictionary = PlayerState.pending_story.duplicate(true)
	reader.free()
	assert(PlayerState.pending_story == expected, "Old story exit must not overwrite loaded checkpoint")


static func _menus_and_daily_hook(host: Node) -> void:
	PlayerState.reset()
	PlayerState.current_day = 2
	PlayerState.home_tutorial_shown = true
	PlayerState.money = 1199
	var tree := host.get_tree()
	var home = load(HOME).instantiate()
	tree.root.add_child(home)
	tree.current_scene = home
	PauseMenuManager.show_pause_menu()
	assert(tree.paused and not PauseMenuManager.save_button.disabled)
	PauseMenuManager._show_save_screen("save")
	PauseMenuManager._save_requested(6)
	assert(ResourceLoader.load(SaveSlotManager.slot_path(6), "", ResourceLoader.CACHE_MODE_IGNORE).data.money == 1199)
	assert(PauseMenuManager.request_toggle() and not PauseMenuManager.save_screen.visible and tree.paused)
	PlayerState.money = 1
	PauseMenuManager._load_requested(6)
	for frame in range(5):
		await tree.process_frame
	assert(not tree.paused and not PauseMenuManager.visible and PlayerState.money == 1199)
	home = tree.current_scene
	assert(home != null and home.scene_file_path == HOME)
	ProjectSettings.set_setting("testing/slot_autosave", true)
	home.is_transitioning = true
	PlayerState.prepare_day_start(3)
	await tree.process_frame
	await tree.process_frame
	assert(ResourceLoader.load(SaveSlotManager.slot_path(1), "", ResourceLoader.CACHE_MODE_IGNORE).data.money == 888, "Day autosave waits for a stable scene")
	home.is_transitioning = false
	for frame in range(3):
		await tree.process_frame
	var daily: Resource = ResourceLoader.load(SaveSlotManager.slot_path(1), "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(daily.data.current_day == 3 and daily.data.money == 1199)
	PlayerState.money = 1200
	await tree.process_frame
	assert(ResourceLoader.load(SaveSlotManager.slot_path(1), "", ResourceLoader.CACHE_MODE_IGNORE).data.money == 1199, "Ordinary changes must not overwrite Slot 1")
	ProjectSettings.set_setting("testing/slot_autosave", false)
	tree.current_scene = null
	home.free()
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	menu.set_script(MenuWithoutSceneTransition)
	tree.root.add_child(menu)
	menu._open_load_slots()
	assert(menu.save_slot_screen.visible and menu.save_slot_screen.mode == "load")
	menu.save_slot_screen.close()
	assert(not menu.save_slot_screen.visible and not menu.start_button.disabled)
	menu._start_game()
	assert(PlayerState.current_day == 1 and PlayerState.money == 0)
	assert(not PlayerState.pending_story.is_empty() and not menu.save_slot_screen.visible)
	assert(menu.intro_started)
	assert(SaveSlotManager.has_slots(), "Start Ride must preserve existing save slots")
	menu.free()
	# Let the audio mixer release the just-freed menu's music stream.
	await tree.create_timer(0.1).timeout
