extends Node

# Explicit player saves are separate from the internal recovery checkpoint.
signal slots_changed

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SaveResource := preload("res://scripts/save/game_save_resource.gd")
const SLOT_COUNT := 10
const AUTOSAVE_SLOT := 1
const SAVE_DIRECTORY := "user://saves"
const PREVIEW_DIRECTORY := "user://saves/previews"
const LEGACY_MIGRATION_MARKER := SAVE_DIRECTORY + "/.legacy_migration_complete"
const HOME_PREVIEW := "res://assets/story/backgrounds/locations/inhouse.png"

var _run_id := ""
var _last_daily_save_key := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_legacy_save()
	if _run_id.is_empty():
		_run_id = _new_run_id()


func begin_new_run() -> void:
	_run_id = _new_run_id()
	_last_daily_save_key = ""
	if PlayerState.has_meta("loaded_slot_runtime"):
		PlayerState.remove_meta("loaded_slot_runtime")


func run_id() -> String:
	if _run_id.is_empty():
		_run_id = _new_run_id()
	return _run_id


func slot_path(slot: int) -> String:
	return SAVE_DIRECTORY.path_join("slot_%02d.tres" % slot) if _valid_slot(slot) else ""


func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		var path := slot_path(slot)
		var snapshot := _read_slot(slot)
		var entry := {
			"slot": slot,
			"exists": FileAccess.file_exists(path),
			"valid": snapshot != null,
			"day": 0,
			"phase": "",
			"location": "",
			"saved_at": "",
			"timestamp": 0.0,
			"preview_path": "",
		}
		if snapshot != null:
			var metadata: Dictionary = snapshot.metadata
			entry.merge({
				"day": int(snapshot.data.get("current_day", 1)),
				"phase": str(metadata.get("phase", snapshot.data.get("current_phase", "morning"))),
				"location": str(metadata.get("location", "Saved game")),
				"saved_at": str(metadata.get("saved_at", "")),
				"timestamp": float(metadata.get("timestamp", 0.0)),
				"preview_path": str(metadata.get("preview_path", "")),
			}, true)
		slots.append(entry)
	return slots


func has_slots() -> bool:
	return most_recent_slot() > 0


func most_recent_slot() -> int:
	var selected := 0
	var newest := -INF
	for entry: Dictionary in list_slots():
		if bool(entry.valid) and float(entry.timestamp) > newest:
			selected = int(entry.slot)
			newest = float(entry.timestamp)
	return selected


func save_slot(slot: int, context: Dictionary = {}) -> Error:
	if not _valid_slot(slot) or slot == AUTOSAVE_SLOT:
		return ERR_INVALID_PARAMETER
	return _save(slot, context)


func delete_slot(slot: int) -> Error:
	if not _valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return ERR_DOES_NOT_EXIST
	# Removing the last slot must not make startup import the recovery checkpoint
	# again. Commit that distinction before destroying any selected save.
	var error := _mark_legacy_migration_complete()
	if error != OK:
		return error
	error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return error
	# Do not parse the deleted resource: damaged saves must be removable too.
	# Only this slot's generated preview names can be removed, never a path
	# supplied by save metadata or another slot's artwork.
	_remove_slot_previews(slot)
	# Retain the daily marker so deleting Slot 1 stays effective for this day.
	slots_changed.emit()
	return OK


func autosave_day(context: Dictionary = {}) -> Error:
	if _is_memory_viewing(context):
		return ERR_UNAUTHORIZED
	var active_run := str(context.get("run_id", run_id()))
	var key := _day_key(active_run, PlayerState.get_current_day())
	if key == _last_daily_save_key:
		return OK
	var options := context.duplicate(true)
	options["run_id"] = active_run
	var error := _save(AUTOSAVE_SLOT, options)
	if error == OK:
		_last_daily_save_key = key
	return error


func load_slot(slot: int) -> bool:
	var snapshot := _read_slot(slot)
	if snapshot == null or not Codec.load_snapshot(PlayerState, snapshot):
		return false
	var metadata: Dictionary = snapshot.metadata
	_run_id = str(metadata.get("run_id", run_id()))
	# Loading starts a new arrival history. Previously visited future days must
	# still replace the autosave when reached again from this snapshot.
	_last_daily_save_key = _day_key(_run_id, PlayerState.get_current_day())
	if PlayerState.has_meta("loaded_slot_runtime"):
		PlayerState.remove_meta("loaded_slot_runtime")
	var runtime: Variant = metadata.get("runtime", {})
	if runtime is Dictionary and not runtime.is_empty():
		PlayerState.set_meta("loaded_slot_runtime", runtime.duplicate(true))
	var scene := str(metadata.get("scene", ""))
	if _valid_scene(scene):
		PlayerState.set_resume_scene(scene)
	PlayerState.save_progress()
	return true


func _save(slot: int, context: Dictionary) -> Error:
	if _is_memory_viewing(context):
		return ERR_UNAUTHORIZED
	var story_payload: Variant = context.get("story_payload", null)
	var has_story_snapshot: bool = (
		str(context.get("scene", "")) == "res://scenes/story_scene.tscn"
		and story_payload is Dictionary
		and not str(story_payload.get("story_id", "")).is_empty()
		and not bool(story_payload.get("replay", false))
		and not bool(story_payload.get("memory_replay", false))
		and PlayerState._state_batch_depth <= int(context.get("story_batch_depth", -1))
	)
	if PlayerState._is_loading_save or (PlayerState._state_batch_depth > 0 and not has_story_snapshot):
		return ERR_BUSY
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	if error != OK:
		return error
	var snapshot: SaveResource = Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION)
	if has_story_snapshot:
		# Slot capture may interrupt typing/actions. Save the reached cursor without
		# flushing or closing the live reader's state batch or advancing its text.
		snapshot.data["pending_story"] = story_payload.duplicate(true)
		var story_id: String = str(story_payload.story_id)
		var checkpoint: Dictionary = story_payload.get("_checkpoint", {})
		if int(checkpoint.get("line_index", -1)) >= 0:
			snapshot.data.last_seen_story_sections[story_id] = int(checkpoint.line_index)
			snapshot.data["last_seen_story_id"] = story_id
	var scene := str(context.get("scene", ""))
	if not scene.is_empty():
		if not _valid_scene(scene):
			return ERR_INVALID_PARAMETER
		snapshot.data["resume_scene_path"] = scene
	var active_run := str(context.get("run_id", run_id()))
	var local_time := Time.get_datetime_dict_from_system()
	var timestamp := Time.get_unix_time_from_system()
	snapshot.metadata = {
		"slot_schema": 1,
		"run_id": active_run,
		"timestamp": timestamp,
		"saved_at": "%04d-%02d-%02d %02d:%02d" % [local_time.year, local_time.month, local_time.day, local_time.hour, local_time.minute],
		"phase": str(context.get("phase", PlayerState.get_hub_time_name())),
		"location": str(context.get("location", "Saved game")),
		"scene": str(context.get("scene", PlayerState.get_resume_scene())),
		"preview_path": str(context.get("preview_path", "")),
		"runtime": Dictionary(context.get("runtime", {})).duplicate(true),
	}
	var preview_path := ""
	var preview_image: Variant = context.get("preview_image", null)
	if preview_image is Image and not preview_image.is_empty():
		preview_path = PREVIEW_DIRECTORY.path_join("slot_%02d_%d.png" % [slot, int(timestamp * 1000000.0)])
		error = _write_preview(preview_image, preview_path)
		if error != OK:
			return error
		snapshot.metadata["preview_path"] = preview_path
	error = Codec.write_snapshot(snapshot, slot_path(slot))
	if error != OK:
		_remove_preview(preview_path)
		return error
	_run_id = active_run
	# Old metadata may point at another slot's preview. Clean only filenames
	# generated for this slot, preserving the newly committed active image.
	_remove_slot_previews(slot, str(snapshot.metadata.preview_path))
	slots_changed.emit()
	return OK


static func _is_memory_viewing(context: Dictionary) -> bool:
	if not PlayerState.pending_memory_replay.is_empty():
		return true
	var payload: Variant = context.get("story_payload", {})
	return payload is Dictionary and (bool(payload.get("replay", false)) or bool(payload.get("memory_replay", false)))


func _read_slot(slot: int) -> SaveResource:
	if not _valid_slot(slot) or not FileAccess.file_exists(slot_path(slot)):
		return null
	var loaded: Resource = ResourceLoader.load(slot_path(slot), "", ResourceLoader.CACHE_MODE_IGNORE)
	if not Codec.snapshot_error(loaded, PlayerState.SAVE_VERSION, true).is_empty():
		return null
	var snapshot := loaded as SaveResource
	if snapshot.metadata.has("timestamp") and not (snapshot.metadata.timestamp is int or snapshot.metadata.timestamp is float):
		return null
	if not is_finite(float(snapshot.metadata.get("timestamp", 0.0))):
		return null
	if snapshot.metadata.has("runtime") and not snapshot.metadata.runtime is Dictionary:
		return null
	if not snapshot.metadata.get("slot_schema", 1) is int or int(snapshot.metadata.get("slot_schema", 1)) != 1:
		return null
	var scene := str(snapshot.metadata.get("scene", snapshot.data.get("resume_scene_path", "")))
	if not scene.is_empty() and not _valid_scene(scene):
		return null
	return snapshot


func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(LEGACY_MIGRATION_MARKER):
		return
	for slot in range(1, SLOT_COUNT + 1):
		if FileAccess.file_exists(slot_path(slot)):
			return
	if not FileAccess.file_exists(PlayerState.SAVE_PATH):
		return
	var legacy: Resource = ResourceLoader.load(PlayerState.SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not Codec.snapshot_error(legacy, PlayerState.SAVE_VERSION).is_empty():
		return
	_run_id = "legacy_%d" % FileAccess.get_modified_time(PlayerState.SAVE_PATH)
	var context := {
		"run_id": _run_id,
		"location": "Previous progress",
		"scene": PlayerState.get_resume_scene(),
		"preview_path": HOME_PREVIEW,
	}
	var error := _save(2, context)
	if error != OK:
		push_warning("Could not import previous progress into Slot 2: %s" % error_string(error))
	else:
		_mark_legacy_migration_complete()


static func _mark_legacy_migration_complete() -> Error:
	if FileAccess.file_exists(LEGACY_MIGRATION_MARKER):
		return OK
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	if error != OK:
		return error
	var marker := FileAccess.open(LEGACY_MIGRATION_MARKER, FileAccess.WRITE)
	if marker == null:
		return FileAccess.get_open_error()
	marker.store_string("1\n")
	marker.flush()
	error = marker.get_error()
	marker.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_MIGRATION_MARKER))
	return error


static func _write_preview(source: Image, path: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIRECTORY))
	if error != OK:
		return error
	var image: Image = source.duplicate()
	if image.get_width() > 640:
		image.resize(640, maxi(1, roundi(640.0 * image.get_height() / image.get_width())), Image.INTERPOLATE_LANCZOS)
	var temporary := path.get_basename() + ".tmp.png"
	error = image.save_png(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	_remove_preview(temporary)
	return error


static func _remove_preview(path: String) -> void:
	var safe_path := path.simplify_path()
	if safe_path.begins_with(PREVIEW_DIRECTORY + "/") and safe_path.get_extension() == "png" and FileAccess.file_exists(safe_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(safe_path))


static func _remove_slot_previews(slot: int, keep_path := "") -> void:
	var directory := DirAccess.open(PREVIEW_DIRECTORY)
	if directory == null:
		return
	var generated_name := RegEx.new()
	generated_name.compile("^slot_%02d_[0-9]+\\.png$" % slot)
	for filename: String in directory.get_files():
		if generated_name.search(filename) != null:
			var path := PREVIEW_DIRECTORY.path_join(filename)
			if path != keep_path.simplify_path():
				_remove_preview(path)


static func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


static func _valid_scene(path: String) -> bool:
	return path.begins_with("res://scenes/") and path.ends_with(".tscn") and ResourceLoader.exists(path)


static func _day_key(active_run: String, day: int) -> String:
	return "%s:%d" % [active_run, day]


static func _new_run_id() -> String:
	return "%d_%d" % [int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec()]
