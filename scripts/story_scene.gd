extends Control

# Coordinates story progression, actions, checkpoints, and scene returns.
# Focused helpers own presentation, interface controls, conditions, and audio.

const StoryAudioRuntime := preload("res://scripts/story/story_audio_runtime.gd")
const StoryConditions := preload("res://scripts/story/story_conditions.gd")
const StoryPresentation := preload("res://scripts/story/story_presentation.gd")
const StoryInterface := preload("res://scripts/story/story_interface.gd")

const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const StoryActionRunner := preload("res://scripts/story/story_action_runner.gd")
const StoryPayload := preload("res://scripts/story/story_payload.gd")
const StoryCheckpoint := preload("res://scripts/story/story_checkpoint.gd")
const StoryPortraitLayer := preload("res://scripts/story/story_portrait_layer.gd")
const StoryGameFlow := preload("res://scripts/story/story_game_flow.gd")
const PassengerStory := preload("res://scripts/ride_selection/passenger_story.gd")
const StoryDialoguePlayback := preload("res://scripts/story/story_dialogue_playback.gd")
const CharacterSpriteRuntime := preload("res://scripts/story/story_character_sprite_runtime.gd")
const RideStoryInterruption := preload("res://scripts/game/ride_story_interruption.gd")

@onready var background: TextureRect = $Background
@onready var background_fade_overlay: ColorRect = $BackgroundFadeOverlay
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var chapter_label: Label = $ChapterLabel
@onready var debt_overlay: Panel = $DebtOverlay
@onready var debt_remaining_label: Label = $DebtOverlay/DebtRemainingLabel
@onready var debt_due_label: Label = $DebtOverlay/DebtDueLabel
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var left_portrait_frame: Panel = $LeftPortraitFrame
@onready var left_portrait: TextureRect = $LeftPortraitFrame/LeftPortrait
@onready var right_portrait_frame: Panel = $RightPortraitFrame
@onready var right_portrait: TextureRect = $RightPortraitFrame/RightPortrait
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/SpeakerLabel
@onready var body_label: Label = $DialoguePanel/BodyLabel
@onready var continue_label: Label = $DialoguePanel/ContinueLabel
@onready var choice_container: VBoxContainer = $ChoiceContainer

var story_payload: Dictionary = {}
var story_lines: Array[Dictionary] = []
var current_line_index := -1
var current_background_ref = null
var current_left_portrait_ref = null
var current_right_portrait_ref = null
var current_focus_side := "none"
var return_scene_path := FALLBACK_SCENE
var complete_scene_path := ""
var story_id := ""
var choice_buttons: Array[BaseButton] = []
var background_zoom := 1.0
var background_pan := Vector2.ZERO
var background_motion_tween: Tween
var bgm_fade_tween: Tween
var debt_overlay_tween: Tween
var is_input_locked := false
var shown_gallery_images: Dictionary = {}
var is_finishing_story := false
var portrait_layer: Control
var weekly_debt_transition: Panel
var checkpoint_batch_depth := 0
var active_music_action: Dictionary = {}
var active_loop_sfx_action: Dictionary = {}
var checkpoint_continuation: Dictionary = {}
var dialogue_playback: Node
var character_sprites: Dictionary = {}
var inline_complete_callback := Callable()


# Scene lifecycle.

func _ready() -> void:
	is_input_locked = true
	StoryInterface.apply_theme(self)
	StoryAudioRuntime.setup(self)
	dialogue_playback = StoryDialoguePlayback.new()
	dialogue_playback.name = "DialoguePlayback"
	add_child(dialogue_playback)
	dialogue_playback.setup(body_label)
	portrait_layer = StoryPortraitLayer.new()
	add_child(portrait_layer)
	move_child(portrait_layer, chapter_label.get_index())
	portrait_layer.setup(dialogue_panel, StoryPresentation.resolve_texture, background)
	_load_story_payload()
	if not _is_replay_mode():
		PlayerState.set_resume_scene("res://scenes/story_scene.tscn")
	StoryPresentation.refresh_background_transform(self)
	await StoryPresentation.play_intro_fade(self)
	var resume_index: int = 0
	if not _is_replay_mode():
		resume_index = PlayerState.get_last_seen_story_section(story_id)
		if resume_index < 0 or resume_index >= story_lines.size():
			resume_index = 0
	var checkpoint: Dictionary = story_payload.get("_checkpoint", {})
	if not _is_replay_mode() and int(checkpoint.get("line_index", -1)) == resume_index:
		await StoryCheckpoint.restore(self, checkpoint)
		await _resume_checkpoint_continuation(checkpoint.get("continuation", {}))
		return
	await StoryAudioRuntime.restore_story_music_state(self, resume_index)
	# Ambient sound belongs to the SFX channel and restarts on save/resume.
	var ambient_sfx: Variant = story_payload.get("ambient_sfx", {})
	if ambient_sfx is Dictionary and not ambient_sfx.is_empty():
		StoryAudioRuntime.play_sfx_action(self, ambient_sfx)
	await _show_line(resume_index)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not event.is_echo() and PauseMenuManager.request_toggle():
			# Stop the global pause handler from toggling the same press again.
			get_viewport().set_input_as_handled()
		return
	var continue_pressed := event.is_action_pressed("ui_accept") and not event.is_echo()
	continue_pressed = continue_pressed or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if continue_pressed and is_instance_valid(dialogue_playback) and dialogue_playback.active:
		# Consume the press before finishing; that may synchronously create choices.
		get_viewport().set_input_as_handled()
		dialogue_playback.finish_now()
		return
	if is_input_locked or StoryInterface.has_active_choices(self):
		return

	if event.is_action_pressed("ui_accept"):
		_advance_story()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_story()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		StoryPresentation.refresh_background_transform(self)


func _exit_tree() -> void:
	if is_instance_valid(dialogue_playback):
		dialogue_playback.cancel()
	if _is_replay_mode():
		PlayerState.clear_pending_memory_replay()
	# A pause-menu exit may interrupt a visual wait between persistent actions.
	# Save the next action cursor with the partial presentation so completed
	# rewards cannot repeat and later actions still run when the story resumes.
	if checkpoint_batch_depth > 0 and PlayerState.pending_story.get("story_id", "") == story_id:
		_save_checkpoint()
	# Never leave the global save batch suppressed if a scene is interrupted.
	while checkpoint_batch_depth > 0:
		_end_checkpoint_batch()


# Story progression and branch dispatch.

func _load_story_payload() -> void:
	var pending_story := PlayerState.get_pending_memory_replay()
	if pending_story.is_empty():
		pending_story = PlayerState.get_pending_story()
	if pending_story.is_empty():
		story_payload = _preview_story_payload()
	else:
		story_payload = pending_story
	story_payload = StoryPayload.normalize(story_payload)

	shown_gallery_images.clear()
	story_lines.clear()
	for line_data in story_payload.get("composition", []):
		if line_data is Dictionary:
			story_lines.append((line_data as Dictionary).duplicate(true))

	chapter_label.text = str(story_payload.get("chapter_title", "STORY")).to_upper()
	story_id = str(story_payload.get("story_id", chapter_label.text.to_lower().replace(" ", "_")))
	return_scene_path = str(story_payload.get("return_scene", FALLBACK_SCENE))
	if return_scene_path.is_empty():
		return_scene_path = FALLBACK_SCENE
	complete_scene_path = str(story_payload.get("next_scene", ""))
	current_background_ref = story_payload.get("background", null)
	current_left_portrait_ref = story_payload.get("left_portrait", null)
	current_right_portrait_ref = story_payload.get("right_portrait", null)
	var portrait_state: Dictionary = {} if _is_replay_mode() else Dictionary(story_payload.get("_portrait_state", {}))
	CharacterSpriteRuntime.initialize(self, portrait_state)
	current_left_portrait_ref = portrait_state.get("left", current_left_portrait_ref)
	current_right_portrait_ref = portrait_state.get("right", current_right_portrait_ref)
	portrait_layer.replace_portraits(CharacterSpriteRuntime.resolve_portraits(self, portrait_state.get("portraits", story_payload.get("portraits", []))))
	current_background_ref = portrait_state.get("background", current_background_ref)
	StoryPresentation.set_background_texture(self, current_background_ref, true)
	StoryPresentation.remember_gallery_image(self, current_background_ref)


func _show_line(index: int) -> void:
	var resolved_index: int = StoryConditions.resolve_visible_story_index(story_lines, index)
	if story_lines.is_empty() or resolved_index < 0 or resolved_index >= story_lines.size():
		await _finish_story()
		return

	is_input_locked = true
	_begin_checkpoint_batch()
	current_line_index = resolved_index
	StoryInterface.clear_choice_buttons(self)
	choice_container.visible = false
	checkpoint_continuation = {"kind": "line_start"}
	if not _is_replay_mode():
		PlayerState.set_last_seen_story_section(story_id, resolved_index)
	var line := story_lines[resolved_index]
	continue_label.visible = false
	await StoryPresentation.pause_for_seconds(self, float(line.get("pause_before", 0.0)))
	await StoryPresentation.apply_line_visuals(self, line)
	StoryInterface.apply_line_text(self, line)
	await _run_line_actions(line)
	checkpoint_continuation = {"kind": "line_end"}
	await dialogue_playback.wait_until_finished()
	await StoryPresentation.pause_for_seconds(self, float(line.get("pause_after", 0.0)))
	StoryInterface.render_choices(self, line)
	checkpoint_continuation.clear()
	_save_checkpoint()
	_end_checkpoint_batch()
	is_input_locked = false


func _current_line() -> Dictionary:
	if current_line_index < 0 or current_line_index >= story_lines.size():
		return {}
	return story_lines[current_line_index]


func _advance_story() -> void:
	if is_instance_valid(dialogue_playback) and dialogue_playback.finish_now():
		return
	if is_input_locked:
		return
	if StoryInterface.has_active_choices(self):
		return

	var line := _current_line()
	if line.is_empty():
		_finish_story()
		return

	var explicit_next_scene := str(line.get("next_scene", ""))
	if not explicit_next_scene.is_empty():
		complete_scene_path = explicit_next_scene
		_finish_story()
		return

	var next_index := current_line_index + 1
	if line.has("next_index"):
		next_index = int(line.get("next_index", next_index))

	_show_line(next_index)


func _choose_branch(choice_data: Dictionary) -> void:
	if is_input_locked or is_finishing_story:
		return
	is_input_locked = true
	_begin_checkpoint_batch()
	await _run_choice_actions(choice_data)
	await _dispatch_choice(choice_data)
	_end_checkpoint_batch()


func _dispatch_choice(choice_data: Dictionary) -> void:
	checkpoint_continuation = {"kind": "dispatch_choice", "choice": choice_data.duplicate(true)}
	var explicit_next_scene := str(choice_data.get("next_scene", ""))
	var default_next_index := current_line_index + 1
	if bool(_current_line().get("_runtime_choice_response", false)):
		default_next_index = int(_current_line().get("next_index", default_next_index))
		if not choice_data.has("next_scene") and not choice_data.has("next_index"):
			explicit_next_scene = str(_current_line().get("next_scene", ""))
	var next_index := int(choice_data.get("next_index", default_next_index))
	var response_line := _build_choice_response_line(choice_data, explicit_next_scene, next_index)
	if not response_line.is_empty():
		# Runtime responses must not move authored sections or their numeric jumps.
		# Keep the original end target as a terminator before appended responses.
		if not story_payload.has("_response_end_index"):
			story_payload["_response_end_index"] = story_lines.size()
			story_lines.append({"_runtime_story_end": true})
		response_line["_runtime_choice_response"] = true
		var response_index := story_lines.size()
		story_lines.append(response_line)
		story_payload["composition"] = story_lines.duplicate(true)
		await _show_line(response_index)
		return

	if not explicit_next_scene.is_empty():
		complete_scene_path = explicit_next_scene
		await _finish_story()
		return

	await _show_line(next_index)


func _build_choice_response_line(choice_data: Dictionary, explicit_next_scene: String, next_index: int) -> Dictionary:
	var response_line: Dictionary = {}
	var response_variant = choice_data.get("response", null)
	if response_variant is Dictionary:
		response_line = (response_variant as Dictionary).duplicate(true)
	else:
		var response_keys := {
			"speaker": "response_speaker",
			"text": "response_text",
			"continue_hint": "response_continue_hint",
			"background": "response_background",
			"focus": "response_focus",
			"left_portrait": "response_left_portrait",
			"right_portrait": "response_right_portrait",
			"portraits": "response_portraits",
			"background_fade": "response_background_fade",
			"pause_before": "response_pause_before",
			"pause_after": "response_pause_after",
			"camera": "response_camera",
			"choices": "response_choices",
		}
		for response_key in response_keys:
			var choice_key: String = response_keys[response_key]
			if choice_data.has(choice_key):
				response_line[response_key] = choice_data.get(choice_key)

		var response_actions: Array = choice_data.get("response_actions", [])
		if not response_actions.is_empty():
			response_line["actions"] = response_actions.duplicate(true)

	if response_line.is_empty():
		return {}

	if not response_line.has("next_scene") and not explicit_next_scene.is_empty():
		response_line["next_scene"] = explicit_next_scene
	elif not response_line.has("next_index"):
		response_line["next_index"] = next_index

	return response_line


func _finish_story() -> void:
	if is_finishing_story:
		return
	is_finishing_story = true
	is_input_locked = true
	if is_instance_valid(dialogue_playback):
		dialogue_playback.cancel()
	_begin_checkpoint_batch()
	checkpoint_continuation = {"kind": "finish_story"}
	var target_scene := complete_scene_path
	if target_scene.is_empty():
		target_scene = return_scene_path
	if target_scene.is_empty():
		target_scene = FALLBACK_SCENE
	target_scene = StoryGameFlow.destination(self, target_scene)

	var special_stage_id := "" if _is_replay_mode() or PlayerState.is_run_failed() else str(story_payload.get("queued_special_stage_id", ""))
	if not _is_replay_mode():
		StoryPresentation.unlock_gallery_images(self)

	await StoryPresentation.play_outro_fade(self)
	if not special_stage_id.is_empty() and PlayerState.begin_event_special_stage(special_stage_id, target_scene):
		_end_checkpoint_batch()
		_transition_from_story("res://scenes/game_over.tscn" if PlayerState.is_run_failed() else "res://scenes/main.tscn")
		return
	if not _is_replay_mode():
		StoryGameFlow.prepare_destination(self, target_scene)
	var queued_story := StoryGameFlow.queued_story(self, target_scene)
	if not queued_story.is_empty():
		PlayerState.set_last_seen_story_section(str(queued_story.get("story_id", "")), 0)
		PlayerState.set_pending_story(queued_story)
		PlayerState.set_resume_scene("res://scenes/story_scene.tscn")
		_end_checkpoint_batch()
		_transition_from_story("res://scenes/story_scene.tscn")
		return
	if not _is_replay_mode():
		target_scene = PassengerStory.complete(story_payload, target_scene)
	if not _is_replay_mode() and not PlayerState.is_run_failed() and not story_payload.has("_story_destination") and bool(story_payload.get("prepare_stage_start", false)):
		var stage_descriptor := str(story_payload.get("stage_descriptor", ""))
		if not PlayerState.prepare_stage_start(stage_descriptor):
			target_scene = return_scene_path if not return_scene_path.is_empty() else FALLBACK_SCENE
	if _is_replay_mode():
		PlayerState.clear_pending_memory_replay()
	else:
		target_scene = RideStoryInterruption.resolve_destination(story_payload, target_scene)
		PlayerState.clear_pending_story()
		PlayerState.set_resume_scene(StoryGameFlow.resume_destination(target_scene))
	_end_checkpoint_batch()
	_transition_from_story(target_scene)


func _transition_from_story(target_scene: String) -> void:
	if inline_complete_callback.is_valid():
		inline_complete_callback.call(target_scene)
	else:
		get_tree().change_scene_to_file(target_scene)


func _preview_story_payload() -> Dictionary:
	return {
		"chapter_title": "Story Scene",
		"return_scene": FALLBACK_SCENE,
		"composition": [
			{
				"speaker": "Narrator",
				"text": "This scene is ready to handle dialogue sequences.",
				"actions": [
					{
						"type": "portrait_switch",
						"side": "none",
					}
				],
			},
			{
				"speaker": "System",
				"text": "Each section can now fire actions for music, portrait swaps, focus changes, and dialogue updates.",
				"choices": [
					{
						"text": "Continue",
						"next_index": 2,
					}
				],
			},
			{
				"speaker": "System",
				"text": "Use either lines, sections, or composition arrays. actions and triggers are both supported.",
			},
		],
	}


# Ordered action execution and save/resume cursors.

func _run_line_actions(line: Dictionary, start_action := 0) -> void:
	var raw_actions: Array = line.get("actions", line.get("triggers", []))
	for action_index in range(start_action, raw_actions.size()):
		checkpoint_continuation = {"kind": "line_actions", "action_index": action_index}
		var action_data_variant = raw_actions[action_index]
		if not action_data_variant is Dictionary:
			continue
		var action_data: Dictionary = (action_data_variant as Dictionary).duplicate(true)
		if not StoryConditions.matches_story_conditions(action_data):
			continue
		await _run_story_action(action_data)
		checkpoint_continuation["action_index"] = action_index + 1


func _run_choice_actions(choice_data: Dictionary, start_action := 0) -> void:
	# Choice metadata precedes its actions. A resumed cursor must not overwrite
	# event values already changed by the completed actions.
	if not _is_replay_mode() and start_action == 0:
		StoryActionRunner.apply_choice_event_values(choice_data)

	var raw_actions: Array = choice_data.get("actions", choice_data.get("effects", []))
	for action_index in range(start_action, raw_actions.size()):
		checkpoint_continuation = {"kind": "choice_actions", "choice": choice_data.duplicate(true), "action_index": action_index}
		var action_data_variant = raw_actions[action_index]
		if not action_data_variant is Dictionary:
			continue
		var action_data: Dictionary = (action_data_variant as Dictionary).duplicate(true)
		if not StoryConditions.matches_story_conditions(action_data):
			continue
		await _run_story_action(action_data)
		checkpoint_continuation["action_index"] = action_index + 1


func _run_story_action(action_data: Dictionary) -> void:
	if _is_replay_mode() and StoryActionRunner.is_persistent_story_action(action_data):
		return
	await StoryActionRunner.run(self, action_data)


func _is_replay_mode() -> bool:
	return bool(story_payload.get("replay", story_payload.get("memory_replay", false)))


func _begin_checkpoint_batch() -> void:
	if _is_replay_mode():
		return
	checkpoint_batch_depth += 1
	PlayerState._begin_state_batch()


func _end_checkpoint_batch() -> void:
	if checkpoint_batch_depth <= 0:
		return
	checkpoint_batch_depth -= 1
	PlayerState._end_state_batch()


func _save_checkpoint() -> void:
	if _is_replay_mode():
		return
	story_payload["_checkpoint"] = StoryCheckpoint.capture(self)
	PlayerState.set_pending_story(story_payload)


func _resume_checkpoint_continuation(continuation: Dictionary) -> void:
	if continuation.is_empty():
		return
	checkpoint_continuation = continuation.duplicate(true)
	var kind := str(continuation.get("kind", ""))
	if kind == "line_start":
		await _show_line(current_line_index)
		return
	if kind == "finish_story":
		await _finish_story()
		return
	is_input_locked = true
	_begin_checkpoint_batch()
	if kind in ["choice_actions", "dispatch_choice"]:
		var choice: Dictionary = continuation.get("choice", {})
		if kind == "choice_actions":
			await _run_choice_actions(choice, int(continuation.get("action_index", 0)))
		await _dispatch_choice(choice)
	else:
		var line: Dictionary = story_lines[current_line_index]
		if kind == "line_actions":
			await _run_line_actions(line, int(continuation.get("action_index", 0)))
			checkpoint_continuation = {"kind": "line_end"}
			await dialogue_playback.wait_until_finished()
		StoryInterface.render_choices(self, line)
		checkpoint_continuation.clear()
		_save_checkpoint()
		is_input_locked = false
	_end_checkpoint_batch()
