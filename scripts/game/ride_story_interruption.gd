extends RefCounted

# Keep the live driving scene intact while a passenger story owns the screen.
# Saved story checkpoints resume separately and restart driving as usual.
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const Economy := preload("res://scripts/game/game_economy_manager.gd")
const PlayerHorn := preload("res://scripts/game/player_horn_controller.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const STORY_SCENE := "res://scenes/story_scene.tscn"
const REPAIR_SCENE := "res://scenes/repair_transition.tscn"
const STAGE_RESULTS_SCENE := "res://scenes/stage_results.tscn"
const OVERLAY_LAYER := 600

var active := false
var reader: Control
var overlay: CanvasLayer
var _game
var _context: Dictionary = {}
var _previous_game_state := "playing"
var _previous_process_mode := Node.PROCESS_MODE_INHERIT
var _audio_state: Array[Dictionary] = []


func try_start(game, fatal_detail := "") -> bool:
	if active or game.game_state != "playing" or game.get_tree().paused:
		return false
	if PlayerState.is_run_failed() or not PlayerState.get_pending_story().is_empty():
		return false
	# The current driving event belongs to Isidro; ordinary rides need no
	# trigger lookup every frame, including after his once-per-run event.
	if PlayerState.get_current_mock_character_id() != "ito":
		return false
	if bool(PlayerState.consumed_story_triggers.get("isidro_first_encounter", false)) or bool(PlayerState.get_event_value("isidro_first_encounter_seen", false)):
		return false
	var unsafe_driving: bool = (
		game.trip_peak_speed_kmh > GameTuning.ISIDRO_FIRST_EVENT_SPEED_KMH
		or game.trip_vehicle_collision_count >= 1
	)
	if not unsafe_driving:
		return false
	var trigger := PlayerState.find_story_trigger_for_phase(
		PlayerState.STORY_TRIGGER_DRIVING,
		PlayerState.get_current_day(),
		{
			"character_id": PlayerState.get_current_mock_character_id(),
			"stage_type": game.stage_type,
			"difficulty": game.stage_difficulty,
			"time_of_day": game.stage_time_of_day,
			"traffic": game.stage_traffic,
			"unsafe_driving": unsafe_driving,
		}
	)
	if trigger.is_empty():
		return false
	var payload := PlayerState.get_story_payload_for_trigger(trigger)
	if payload.is_empty():
		return false
	_game = game
	_context = {
		"character_id": PlayerState.get_current_mock_character_id(),
		"day": PlayerState.get_current_day(),
		"phase": PlayerState.get_current_time_of_day(),
		"stage_round": int(PlayerState.stage_round),
		"stage_type": game.stage_type,
		"difficulty": game.stage_difficulty,
		"time_of_day": game.stage_time_of_day,
		"traffic": game.stage_traffic,
		"stage_special_type": game.stage_special_type,
		"special_stage_id": game.special_stage_id,
		"distance": game.distance,
		"target_distance": game.target_distance,
		"peak_speed_kmh": game.trip_peak_speed_kmh,
		"vehicle_collision_count": game.trip_vehicle_collision_count,
		"fatal_collision_detail": fatal_detail,
	}
	payload["_driving_interruption"] = _context.duplicate(true)
	if str(payload.get("return_scene", "")).is_empty():
		payload["return_scene"] = MAIN_SCENE
	if str(payload.get("next_scene", "")).is_empty():
		payload["next_scene"] = MAIN_SCENE
	PlayerState._begin_state_batch()
	PlayerState.consume_story_trigger(trigger)
	PlayerState.set_last_seen_story_section(str(payload.get("story_id", "")), 0)
	PlayerState.set_pending_story(payload)
	PlayerState.set_resume_scene(STORY_SCENE)
	PlayerState._end_state_batch()
	_pause_game()
	active = true
	overlay = CanvasLayer.new()
	overlay.name = "RideStoryInterruption"
	overlay.layer = OVERLAY_LAYER
	overlay.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.get_tree().root.add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_reader()
	return true


func _pause_game() -> void:
	PlayerHorn.stop(_game)
	_previous_game_state = str(_game.game_state)
	_previous_process_mode = _game.process_mode
	_audio_state.clear()
	for node: Node in _game.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		_audio_state.append({"player": player, "paused": player.stream_paused})
		player.stream_paused = true
	_game.game_state = "story"
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	AmbientAudioManager.stop_all()


func _show_reader() -> void:
	if not active or not is_instance_valid(overlay):
		return
	# Loading at entry avoids a preload cycle with StoryScene's finish handler.
	var scene := load(STORY_SCENE) as PackedScene
	reader = scene.instantiate()
	reader.set("inline_complete_callback", Callable(self, "_finish_inline"))
	overlay.add_child(reader)
	reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _finish_inline(scene_path: String) -> void:
	if not active or not is_instance_valid(_game):
		dispose()
		return
	var tree: SceneTree = _game.get_tree()
	_game.get_viewport().set_input_as_handled()
	if scene_path == STORY_SCENE and not PlayerState.get_pending_story().is_empty():
		# StoryGameFlow carries this context across chains. Keep it defensively
		# for custom payload handoffs that do not use the normal queue action.
		var pending := PlayerState.get_pending_story()
		if not pending.has("_driving_interruption"):
			pending["_driving_interruption"] = _context.duplicate(true)
			PlayerState.set_pending_story(pending)
		if is_instance_valid(reader):
			reader.queue_free()
		reader = null
		_show_reader.call_deferred()
		return
	if scene_path == MAIN_SCENE and _can_resume_live_ride():
		var game = _game
		game.game_state = _previous_game_state
		game.process_mode = _previous_process_mode
		for state: Dictionary in _audio_state:
			var player: AudioStreamPlayer = state.player
			if is_instance_valid(player):
				player.stream_paused = bool(state.paused)
		AmbientAudioManager.enter_drive(game.stage_weather, game.stage_time_of_day)
		dispose()
		return
	# A story-directed destination (including fatal collision repairs) abandons
	# this paused instance and follows the ordinary scene handoff.
	dispose()
	tree.change_scene_to_file.call_deferred(scene_path)


func _can_resume_live_ride() -> bool:
	return (
		is_instance_valid(_game)
		and _game.is_inside_tree()
		and not PlayerState.is_run_failed()
		and PlayerState.active_event_special_stage.is_empty()
		and PlayerState.get_current_day() == int(_context.get("day", -1))
		and PlayerState.get_current_time_of_day() == str(_context.get("phase", ""))
		and int(PlayerState.stage_round) == int(_context.get("stage_round", -1))
		and PlayerState.get_current_mock_character_id() == str(_context.get("character_id", ""))
		and PlayerState.get_current_stage_type() == str(_context.get("stage_type", ""))
		and PlayerState.get_current_special_stage_id() == str(_context.get("special_stage_id", ""))
	)


func dispose() -> void:
	active = false
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	reader = null
	_audio_state.clear()
	_context.clear()
	_game = null


static func resolve_destination(payload: Dictionary, target_scene: String) -> String:
	if bool(payload.get("replay", payload.get("memory_replay", false))):
		return target_scene
	var context: Dictionary = payload.get("_driving_interruption", {})
	if context.is_empty() or target_scene != MAIN_SCENE or PlayerState.is_run_failed():
		return target_scene
	var resolved := str(payload.get("_driving_resolved_destination", ""))
	if not resolved.is_empty():
		return resolved
	var detail := str(context.get("fatal_collision_detail", ""))
	if not detail.is_empty() and PlayerState.energy <= 0:
		# Collision repair takes precedence over an authored early ride ending.
		payload["_driving_resolved_destination"] = REPAIR_SCENE
		if not PlayerState.pending_crash_repair.is_empty():
			return REPAIR_SCENE
		PlayerState._begin_state_batch()
		PlayerState.record_stage_failure()
		Economy.store_failed_stage_result(
			str(context.get("stage_type", "")),
			str(context.get("difficulty", "short")),
			str(context.get("time_of_day", "morning")),
			str(context.get("traffic", "chill")),
			str(context.get("stage_special_type", "")),
			str(context.get("special_stage_id", "")),
			float(context.get("distance", 0.0)),
			float(context.get("target_distance", 0.0)),
			detail
		)
		var failed := PlayerState.get_last_stage_result()
		failed["peak_speed_kmh"] = float(context.get("peak_speed_kmh", 0.0))
		failed["vehicle_collision_count"] = int(context.get("vehicle_collision_count", 0))
		PlayerState.set_last_stage_result(failed)
		PlayerState.active_event_special_stage.clear()
		PlayerState.begin_crash_repair()
		PlayerState._end_state_batch()
		return REPAIR_SCENE
	if str(payload.get("driving_outcome", "")) != "end_without_fare":
		return target_scene
	# The story's payment actions have already run. Ending the interrupted ride
	# records its distance and progression once, without collecting any fare.
	payload["_driving_resolved_destination"] = STAGE_RESULTS_SCENE
	PlayerState._begin_state_batch()
	Economy.store_stage_result(
		str(context.get("stage_type", "")),
		str(context.get("difficulty", "short")),
		str(context.get("time_of_day", "morning")),
		str(context.get("traffic", "chill")),
		str(context.get("stage_special_type", "")),
		str(context.get("special_stage_id", "")),
		float(context.get("distance", 0.0)),
		float(context.get("target_distance", 0.0)),
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0,
		{
			"peak_speed_kmh": float(context.get("peak_speed_kmh", 0.0)),
			"vehicle_collision_count": int(context.get("vehicle_collision_count", 0)),
		}
	)
	var result := PlayerState.get_last_stage_result()
	result["fare"] = 0
	result["bonus"] = 0
	result["total"] = 0
	result["unpaid_story"] = str(payload.get("story_id", ""))
	result["ended_early"] = true
	result["early_end_reason"] = "Ride ended early. No fare collected."
	var detail_lines: Array = result.get("detail_lines", []).duplicate()
	detail_lines.insert(0, result["early_end_reason"])
	result["detail_lines"] = detail_lines
	PlayerState.set_last_stage_result(result)
	PlayerState._end_state_batch()
	return STAGE_RESULTS_SCENE
