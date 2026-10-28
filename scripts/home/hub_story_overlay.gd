extends Node

# Local hub conversations use the normal reader/checkpoints without leaving
# their host screen. A saved conversation resumes through the standalone reader.
const STORY_SCENE := "res://scenes/story_scene.tscn"
const OVERLAY_LAYER := 200

var active := false
var reader: Control
var overlay: CanvasLayer
var _host: Control
var _complete := Callable()
var _music_player: AudioStreamPlayer
var _music_was_paused := false


func setup(host: Control) -> void:
	_host = host


func play(payload: Dictionary, complete: Callable) -> bool:
	if active or not is_instance_valid(_host) or not _host.is_inside_tree():
		return false
	if payload.is_empty() or PlayerState.is_run_failed() or not PlayerState.pending_story.is_empty() or not PlayerState.pending_memory_replay.is_empty():
		return false
	var story_id := str(payload.get("story_id", ""))
	if story_id.is_empty():
		return false
	var scene := load(STORY_SCENE) as PackedScene
	if scene == null:
		return false
	_complete = complete
	active = true
	PlayerState._begin_state_batch()
	PlayerState.set_last_seen_story_section(story_id, 0)
	PlayerState.set_pending_story(payload)
	PlayerState.set_resume_scene(STORY_SCENE)
	PlayerState._end_state_batch()
	_pause_hub_music()
	overlay = CanvasLayer.new()
	overlay.name = "HubStoryLayer"
	overlay.layer = OVERLAY_LAYER
	overlay.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(overlay)
	var input_shield := ColorRect.new()
	input_shield.name = "InputShield"
	input_shield.color = Color.TRANSPARENT
	input_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(input_shield)
	input_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reader = scene.instantiate() as Control
	reader.set("inline_complete_callback", Callable(self, "_finish"))
	overlay.add_child(reader)
	reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return true


func _finish(scene_path: String) -> void:
	if not active:
		return
	if is_instance_valid(_host) and _host.is_inside_tree():
		_host.get_viewport().set_input_as_handled()
	var complete := _complete
	dispose()
	if complete.is_valid():
		complete.call(scene_path)


func _pause_hub_music() -> void:
	_music_player = HubMusicManager.player
	if is_instance_valid(_music_player):
		_music_was_paused = _music_player.stream_paused
		_music_player.stream_paused = true


func dispose() -> void:
	active = false
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	reader = null
	_complete = Callable()
	_restore_hub_music()


func _restore_hub_music() -> void:
	if is_instance_valid(_music_player):
		_music_player.stream_paused = _music_was_paused
	_music_player = null
	_music_was_paused = false


func _exit_tree() -> void:
	_restore_hub_music()
