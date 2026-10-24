extends RefCounted

const StoryAudioRuntime := preload("res://scripts/story/story_audio_runtime.gd")
const StoryPresentation := preload("res://scripts/story/story_presentation.gd")
const StoryInterface := preload("res://scripts/story/story_interface.gd")

# Snapshot the state reached along the chosen path, not every preceding array
# element. Completed line effects are not run again after a save is loaded.
static func capture(reader) -> Dictionary:
	return {
		"version": 1,
		"continuation": reader.checkpoint_continuation.duplicate(true),
		"line_index": reader.current_line_index,
		"background": reader.current_background_ref,
		"left": reader.current_left_portrait_ref,
		"right": reader.current_right_portrait_ref,
		"portraits": reader.portrait_layer.entries.duplicate(true),
		"focus": reader.current_focus_side,
		"zoom": reader.background_zoom,
		"pan": reader.background_pan,
		"fade": reader.background_fade_overlay.color,
		"dialogue_visible": reader.dialogue_panel.visible,
		"speaker": reader.speaker_label.text,
		"text": reader.body_label.text,
		"continue_hint": reader.continue_label.text,
		"music": reader.active_music_action.duplicate(true) if reader.bgm_player.playing else {},
		"loop_sfx": reader.active_loop_sfx_action.duplicate(true) if reader.sfx_player.playing else {},
		"debt_visible": reader.debt_overlay.visible,
		"debt_remaining": reader.debt_remaining_label.text,
		"debt_due": reader.debt_due_label.text,
		"weekly_debt_visible": is_instance_valid(reader.weekly_debt_transition),
		"next_scene": reader.complete_scene_path,
		"gallery_images": reader.shown_gallery_images.duplicate(),
	}


static func restore(reader, state: Dictionary) -> void:
	reader.is_input_locked = true
	reader.current_line_index = int(state.line_index)
	reader.current_background_ref = state.background
	reader.current_left_portrait_ref = state.left
	reader.current_right_portrait_ref = state.right
	StoryPresentation.set_background_texture(reader, state.background, false)
	reader.shown_gallery_images.assign(state.get("gallery_images", {}))
	StoryPresentation.set_background_camera(reader, float(state.zoom), state.pan, 0.0)
	StoryPresentation.set_portrait(reader, reader.left_portrait_frame, reader.left_portrait, state.left)
	StoryPresentation.set_portrait(reader, reader.right_portrait_frame, reader.right_portrait, state.right)
	reader.portrait_layer.replace_portraits(state.portraits)
	StoryPresentation.apply_portrait_focus_from_side(reader, str(state.focus))
	reader.background_fade_overlay.color = state.fade
	StoryInterface.set_dialogue_content(reader, str(state.speaker), str(state.text), str(state.continue_hint), bool(state.dialogue_visible))
	reader.speaker_label.text = str(state.speaker)
	reader.debt_overlay.visible = bool(state.debt_visible)
	reader.debt_overlay.modulate = Color.WHITE
	reader.debt_remaining_label.text = str(state.debt_remaining)
	reader.debt_due_label.text = str(state.debt_due)
	reader.complete_scene_path = str(state.next_scene)
	if not Dictionary(state.music).is_empty():
		var music: Dictionary = state.music.duplicate(true)
		music["fade_in"] = 0.0
		music["fade_out"] = 0.0
		await StoryAudioRuntime.play_music_action(reader, music)
	if not Dictionary(state.loop_sfx).is_empty():
		StoryAudioRuntime.play_sfx_action(reader, state.loop_sfx)
	if bool(state.weekly_debt_visible):
		await StoryInterface.show_weekly_debt_transition(reader)
	StoryInterface.render_choices(reader, reader.story_lines[reader.current_line_index])
	reader.is_input_locked = false
