extends RefCounted

const Codec := preload("res://scripts/save/player_state_save_codec.gd")
const SlotScreen := preload("res://scripts/ui/save_slot_screen.gd")
const HOME := "res://scenes/day_start_scene.tscn"


static func run(host: Node) -> void:
	assert(ProjectSettings.get_setting("testing/isolated", false))
	assert(SaveSlotManager.slot_path(1).begins_with("res://test_user/"), "Deletion checks must use disposable fixture saves")
	assert(SaveSlotManager.LEGACY_MIGRATION_MARKER.begins_with("res://test_user/"))
	for slot in range(1, 11):
		if FileAccess.file_exists(SaveSlotManager.slot_path(slot)):
			assert(SaveSlotManager.delete_slot(slot) == OK)
	PlayerState.reset()
	SaveSlotManager.begin_new_run()
	PlayerState.current_day = 3
	PlayerState.money = 432
	PlayerState.set_resume_scene(HOME)
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORNFLOWER_BLUE)
	var context := {"scene": HOME, "location": "Home", "preview_image": image}
	assert(SaveSlotManager.save_slot(6, context) == OK)
	assert(SaveSlotManager.save_slot(7, context) == OK)
	var first: Resource = ResourceLoader.load(SaveSlotManager.slot_path(6), "", ResourceLoader.CACHE_MODE_IGNORE)
	var other: Resource = ResourceLoader.load(SaveSlotManager.slot_path(7), "", ResourceLoader.CACHE_MODE_IGNORE)
	var own_preview: String = first.metadata.preview_path
	var other_preview: String = other.metadata.preview_path
	var other_bytes := FileAccess.get_file_as_bytes(SaveSlotManager.slot_path(7))
	# Overwriting copied/damaged metadata must not remove another slot's image.
	first.metadata.preview_path = other_preview
	assert(Codec.write_snapshot(first, SaveSlotManager.slot_path(6)) == OK)
	assert(SaveSlotManager.save_slot(6, context) == OK)
	assert(FileAccess.file_exists(other_preview), "Overwriting Slot 6 must preserve Slot 7's preview even when old metadata references it")
	assert(FileAccess.get_file_as_bytes(SaveSlotManager.slot_path(7)) == other_bytes)
	assert(not FileAccess.file_exists(own_preview), "An overwrite cleans only this slot's old generated previews")
	first = ResourceLoader.load(SaveSlotManager.slot_path(6), "", ResourceLoader.CACHE_MODE_IGNORE)
	own_preview = first.metadata.preview_path
	assert(FileAccess.file_exists(own_preview), "Overwrite cleanup must retain its new active preview")
	# Normal overwrites also remove their prior image and retain the replacement.
	assert(SaveSlotManager.save_slot(6, context) == OK)
	assert(not FileAccess.file_exists(own_preview))
	first = ResourceLoader.load(SaveSlotManager.slot_path(6), "", ResourceLoader.CACHE_MODE_IGNORE)
	own_preview = first.metadata.preview_path
	assert(FileAccess.file_exists(own_preview) and FileAccess.file_exists(other_preview))
	var orphan_preview := SaveSlotManager.PREVIEW_DIRECTORY.path_join("slot_06_123.png")
	var custom_preview := SaveSlotManager.PREVIEW_DIRECTORY.path_join("slot_06_keep.png")
	var outside_preview := "res://test_user/keep_deletion_preview.png"
	for path in [orphan_preview, custom_preview, outside_preview]:
		assert(image.save_png(path) == OK)
	# Malicious metadata cannot cause deletion outside this slot's generated art.
	first.metadata.preview_path = outside_preview
	assert(Codec.write_snapshot(first, SaveSlotManager.slot_path(6)) == OK)
	var unchanged := _snapshot()
	var changes := [0]
	var listener := func() -> void: changes[0] += 1
	SaveSlotManager.slots_changed.connect(listener)
	for invalid in [-1, 0, 11, 100]:
		assert(SaveSlotManager.delete_slot(invalid) == ERR_INVALID_PARAMETER)
	assert(SaveSlotManager.delete_slot(5) == ERR_DOES_NOT_EXIST and changes[0] == 0)
	assert(SaveSlotManager.delete_slot(6) == OK and changes[0] == 1)
	assert(not FileAccess.file_exists(SaveSlotManager.slot_path(6)))
	assert(not FileAccess.file_exists(own_preview) and not FileAccess.file_exists(orphan_preview))
	assert(FileAccess.file_exists(custom_preview) and FileAccess.file_exists(outside_preview))
	assert(FileAccess.file_exists(other_preview) and FileAccess.get_file_as_bytes(SaveSlotManager.slot_path(7)) == other_bytes)
	assert(_snapshot() == unchanged, "Deleting a slot cannot change live state, recovery progress or save counts")
	assert(SaveSlotManager.delete_slot(6) == ERR_DOES_NOT_EXIST and changes[0] == 1)
	# A genuinely unreadable resource must be removable without loading it.
	var damaged := FileAccess.open(SaveSlotManager.slot_path(8), FileAccess.WRITE)
	damaged.store_string("not a Godot resource\n")
	damaged.close()
	assert(SaveSlotManager.delete_slot(8) == OK and changes[0] == 2)
	assert(not FileAccess.file_exists(SaveSlotManager.slot_path(8)))
	assert(_snapshot() == unchanged)
	# Deleting autosave is effective until the next normal day arrival.
	assert(SaveSlotManager.autosave_day({"scene": HOME}) == OK)
	var daily_key: String = SaveSlotManager._last_daily_save_key
	assert(SaveSlotManager.delete_slot(1) == OK)
	assert(SaveSlotManager._last_daily_save_key == daily_key)
	assert(SaveSlotManager.autosave_day({"scene": HOME}) == OK)
	assert(not FileAccess.file_exists(SaveSlotManager.slot_path(1)))
	PlayerState.current_day += 1
	assert(SaveSlotManager.autosave_day({"scene": HOME}) == OK)
	assert(FileAccess.file_exists(SaveSlotManager.slot_path(1)))
	SaveSlotManager.slots_changed.disconnect(listener)
	assert(SaveSlotManager.delete_slot(1) == OK)
	await _test_screen(host)
	_test_migration_marker_failure()
	unchanged = _snapshot()
	assert(SaveSlotManager.delete_slot(7) == OK)
	assert(_snapshot() == unchanged)
	SaveSlotManager._migrate_legacy_save()
	assert(not SaveSlotManager.has_slots(), "Deleting the last slot must not reimport the live recovery checkpoint on startup")
	assert(FileAccess.file_exists(PlayerState.SAVE_PATH), "Explicit deletion must preserve the recovery checkpoint")
	PlayerState.reset()
	print("PASS: confirmed slot deletion, autosave policy, corrupt files, slot-owned overwrite/deletion preview cleanup, live/recovery isolation and delete-all migration persistence")


static func _test_screen(host: Node) -> void:
	var screen := SlotScreen.new()
	host.add_child(screen)
	var entries: Array[Dictionary] = [
		{"slot": 1, "exists": true, "valid": true},
		{"slot": 2, "exists": false, "valid": false},
		{"slot": 3, "exists": true, "valid": false},
	]
	var requested: Array[int] = []
	screen.delete_requested.connect(func(slot: int) -> void: requested.append(slot))
	screen.open("load", entries)
	screen._show_slot_details(2)
	assert(screen.delete_button.disabled, "Empty slots cannot be deleted")
	screen._show_slot_details(3)
	assert(not screen.delete_button.disabled, "Damaged save files must still offer deletion")
	screen._request_delete()
	assert(screen.confirmation.visible and screen.cancel_button.has_focus())
	screen.handle_cancel()
	assert(not screen.confirmation.visible and requested.is_empty())
	screen._request_delete()
	screen._confirm_slot()
	assert(requested == [3], "Only an explicit delete confirmation emits the selected slot")
	screen.open("save", entries, false)
	screen._show_slot_details(1)
	assert(not screen.delete_button.disabled, "Deleting an existing autosave is available even when saving is blocked")
	screen.free()
	await host.get_tree().process_frame


static func _test_migration_marker_failure() -> void:
	var marker_path: String = SaveSlotManager.LEGACY_MIGRATION_MARKER
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path)) == OK)
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(marker_path)) == OK)
	var keep_path := marker_path.path_join("keep.txt")
	var keep := FileAccess.open(keep_path, FileAccess.WRITE)
	keep.store_string("keep")
	keep.close()
	var before := FileAccess.get_file_as_bytes(SaveSlotManager.slot_path(7))
	var error: Error = SaveSlotManager.delete_slot(7)
	var unchanged := FileAccess.get_file_as_bytes(SaveSlotManager.slot_path(7)) == before
	var marker_directory_preserved := FileAccess.file_exists(keep_path)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(keep_path)) == OK)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path)) == OK)
	assert(error != OK and unchanged, "A failed migration marker must not destroy the selected save")
	assert(marker_directory_preserved)


static func _snapshot() -> Dictionary:
	return {
		"state": Codec.build_snapshot(PlayerState, PlayerState.SAVE_VERSION).data.duplicate(true),
		"recovery": FileAccess.get_file_as_bytes(PlayerState.SAVE_PATH),
		"save_count": int(PlayerState.get_meta("test_save_count", 0)),
		"run_id": SaveSlotManager.run_id(),
	}
