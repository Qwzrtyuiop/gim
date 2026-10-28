extends RefCounted

# Shared slot context and day-start scheduling; never writes the internal checkpoint.
const DrivingSnapshot := preload("res://scripts/save/driving_save_snapshot.gd")
const StoryCheckpoint := preload("res://scripts/story/story_checkpoint.gd")
const MAIN := "res://scenes/main.tscn"
const STORY := "res://scenes/story_scene.tscn"
const HOME := "res://scenes/day_start_scene.tscn"
const STATION := "res://scenes/ride_selection.tscn"
const STORE := "res://scenes/store.tscn"
const RESULTS := "res://scenes/stage_results.tscn"
const LOCATIONS := "res://assets/story/backgrounds/locations/"
const SAVABLE_SCENES := [MAIN, STORY, HOME, STATION, STORE, RESULTS]
const RESUME_SCENES := [MAIN, STORY, HOME, STATION, STORE, RESULTS, "res://scenes/day_start_transition.tscn", "res://scenes/sleep_transition.tscn", "res://scenes/repair_transition.tscn", "res://scenes/game_over.tscn"]

static var _daily_request := 0


static func save_block_reason(scene: Node = null) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if scene == null and tree != null:
		scene = tree.current_scene
	if scene == null or not is_instance_valid(scene):
		return "Wait until the current screen is ready."
	if not PlayerState.pending_memory_replay.is_empty():
		return "Return to your game before saving."
	if PlayerState._is_loading_save:
		return "Wait for the current action to finish."
	if PlayerState.is_run_failed():
		return "This run has ended. Load an earlier save to continue."
	if not SAVABLE_SCENES.has(scene.scene_file_path):
		return "Saving is available during play and story scenes."
	for property in ["is_transitioning", "is_departing", "stage_clear_transition_started", "crash_repair_transition_active"]:
		if _has_property(scene, property) and bool(scene.get(property)):
			return "Wait for the transition to finish."
	var hub_map := _hub_map(scene)
	if hub_map != null and _has_property(hub_map, "work_overlay"):
		var work_overlay: Variant = hub_map.get("work_overlay")
		if is_instance_valid(work_overlay) and bool(work_overlay.active):
			return "Wait for the work to finish."
	var reader := _story_reader(scene)
	if reader != null:
		if bool(reader.story_payload.get("replay", false)) or bool(reader.story_payload.get("memory_replay", false)):
			return "Return to your game before saving."
		if reader.is_finishing_story:
			return "Wait for the current story action to finish."
		if PlayerState._state_batch_depth > int(reader.checkpoint_batch_depth):
			return "Wait for the current action to finish."
	elif PlayerState._state_batch_depth > 0:
		return "Wait for the current action to finish."
	elif scene.scene_file_path == MAIN and str(scene.game_state) != "playing":
		return "Wait until driving resumes."
	return ""


static func capture(scene: Node = null, preview_image: Image = null) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if scene == null and tree != null:
		scene = tree.current_scene
	if scene == null:
		return {}
	var reader := _story_reader(scene)
	var path: String = STORY if reader != null else scene.scene_file_path
	var night: bool = PlayerState.get_current_time_of_day() == "night"
	var context: Dictionary = {
		"scene": path,
		"phase": PlayerState.get_hub_time_name(),
		"location": "Saved game",
		"preview_path": "",
		"runtime": {},
	}
	match path:
		HOME:
			context.location = "Home"
			context.preview_path = LOCATIONS + ("inhouse_night.png" if night else "inhouse.png")
		STATION:
			var at_terminal: bool = is_instance_valid(scene.passenger_overlay) and scene.passenger_overlay.visible
			context.location = "Terminal" if at_terminal else "Station"
			context.preview_path = LOCATIONS + (("terminalnight.png" if night else "terminalday.png") if at_terminal else ("Updated_night.png" if night else "Updated_day.png"))
			var pickup: String = PlayerState.get_pending_pickup_location()
			if pickup in ["market", "street"]:
				context.location = pickup.capitalize()
				context.preview_path = scene.terminal_view.get_background_texture().resource_path
		STORE:
			context.location = "Store"
			context.preview_path = LOCATIONS + ("storemidnight.png" if PlayerState.is_midnight() else ("storenight.png" if night else "store.png"))
		RESULTS:
			context.location = "Ride complete"
			context.preview_path = LOCATIONS + "city.png"
		STORY:
			context.location = str(reader.story_payload.get("chapter_title", "Story"))
			var background: Variant = reader.current_background_ref
			context.preview_path = background.resource_path if background is Texture2D else str(background)
			context["story_payload"] = StoryCheckpoint.capture_payload(reader)
			context["story_batch_depth"] = int(reader.checkpoint_batch_depth)
		MAIN:
			context.location = "Driving / %s" % str(scene.stage_traffic).capitalize()
			var driving: Dictionary = DrivingSnapshot.capture(scene)
			context.runtime = {"scene": MAIN, "driving": driving}
			context.preview_path = str(driving.get("background", ""))
	if preview_image != null and not preview_image.is_empty():
		context["preview_image"] = preview_image
	return context


static func resume_scene() -> String:
	cancel_daily_autosave()
	# Gallery sessions and carried audio belong to the discarded live scene.
	PlayerState.pending_memory_replay.clear()
	PlayerState.pending_result_music.clear()
	if not PlayerState.pending_story.is_empty():
		return STORY
	if not PlayerState.active_event_special_stage.is_empty():
		return MAIN
	var path: String = PlayerState.get_resume_scene()
	if RESUME_SCENES.has(path):
		return path
	if PlayerState.is_run_failed():
		return "res://scenes/game_over.tscn"
	if not PlayerState.pending_crash_repair.is_empty():
		return "res://scenes/repair_transition.tscn"
	if not PlayerState.pending_sleep_transition_state.is_empty():
		return "res://scenes/sleep_transition.tscn"
	return HOME


static func prepare_scene_for_load(scene: Node = null) -> void:
	cancel_daily_autosave()
	var tree := Engine.get_main_loop() as SceneTree
	if scene == null and tree != null:
		scene = tree.current_scene
	if scene == null:
		return
	var reader := _story_reader(scene)
	if reader == null or reader.checkpoint_batch_depth <= 0:
		return
	# Close the old reader's action batch before replacing PlayerState. Otherwise
	# its exit handler could write an old cursor over a newly loaded story.
	# Preserve that cursor first so a failed load can still resume the live game.
	reader._save_checkpoint()
	while reader.checkpoint_batch_depth > 0:
		reader._end_checkpoint_batch()


static func cancel_daily_autosave() -> void:
	_daily_request += 1


static func request_daily_autosave(player_state) -> void:
	# Regression fixtures control their own saves and progression explicitly.
	if ProjectSettings.get_setting("testing/isolated", false) and not ProjectSettings.get_setting("testing/slot_autosave", false):
		return
	_daily_request += 1
	_wait_for_day_start.call_deferred(player_state, player_state.get_current_day(), _daily_request)


static func _wait_for_day_start(player_state, day: int, request: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	while is_instance_valid(player_state) and request == _daily_request:
		await tree.process_frame
		if request != _daily_request or player_state.get_current_day() != day or player_state.is_run_failed():
			return
		if tree.paused or player_state._state_batch_depth > 0 or not save_block_reason(tree.current_scene).is_empty():
			continue
		var manager := tree.root.get_node_or_null("SaveSlotManager")
		if manager != null:
			var error: Error = manager.autosave_day(capture(tree.current_scene))
			if error != OK:
				push_warning("Daily autosave failed: %s" % error_string(error))
		return


static func _story_reader(scene: Node) -> Node:
	if scene.scene_file_path == STORY:
		return scene
	if scene.scene_file_path == MAIN and str(scene.game_state) == "story" and scene.ride_story_interruption != null:
		var reader: Variant = scene.ride_story_interruption.reader
		return reader if is_instance_valid(reader) else null
	var hub_map := _hub_map(scene)
	if hub_map != null and _has_property(hub_map, "hub_story_overlay"):
		var helper: Variant = hub_map.get("hub_story_overlay")
		if is_instance_valid(helper) and bool(helper.active):
			var reader: Variant = helper.reader
			return reader if is_instance_valid(reader) else null
	return null


static func _hub_map(scene: Node) -> Node:
	if scene.scene_file_path not in [HOME, STATION, STORE]:
		return null
	for property: String in ["home_map", "travel_map"]:
		if _has_property(scene, property):
			var candidate: Variant = scene.get(property)
			if is_instance_valid(candidate):
				return candidate as Node
	return null


static func _has_property(object: Object, property: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if str(entry.name) == property:
			return true
	return false
