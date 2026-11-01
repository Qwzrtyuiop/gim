extends Node

# Scene-local acceleration. Story actions and checkpoints keep their normal order.
const SKIP_LINES_PER_FRAME := 32

var host
var skipping := false
var _control_held := false
var _window_focused := true


func setup(story_scene: Control) -> void:
	host = story_scene
	name = "StoryPlaybackControls"
	process_mode = Node.PROCESS_MODE_PAUSABLE


func is_accelerating() -> bool:
	return _can_process_story() and (skipping or _control_held)


func request_skip() -> void:
	if not _can_process_story() or _has_choices() or host.is_finishing_story:
		return
	skipping = true


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.keycode == KEY_CTRL:
		_control_held = event.pressed
		return true
	return false


func _process(_delta: float) -> void:
	_control_held = _window_focused and Input.is_key_pressed(KEY_CTRL)
	if not _can_process_story():
		return
	var choices := _has_choices()
	if choices:
		skipping = false
	if is_instance_valid(host.skip_button):
		host.skip_button.disabled = choices or host.is_finishing_story
		host.skip_button.visible = not host.is_finishing_story
	if not is_accelerating() or choices:
		return
	var camera: Tween = host.background_motion_tween
	if camera != null and camera.is_valid():
		camera.custom_step(86400.0)
	var budget := SKIP_LINES_PER_FRAME if skipping else 1
	for _line in range(budget):
		if not _can_process_story() or host.is_finishing_story:
			break
		if is_instance_valid(host.dialogue_playback):
			host.dialogue_playback.finish_now()
		if _has_choices():
			skipping = false
			break
		if host.is_input_locked:
			break
		host._advance_story()
		if not _can_process_story():
			break
		if _has_choices():
			skipping = false
			break


func _has_choices() -> bool:
	if not host.choice_container.visible:
		return false
	for button in host.choice_buttons:
		if is_instance_valid(button) and not button.disabled:
			return true
	return false


func _can_process_story() -> bool:
	return (
		is_instance_valid(host)
		and host.is_inside_tree()
		and not host.is_queued_for_deletion()
		and host.is_visible_in_tree()
		and host.can_process()
		and _window_focused
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		_control_held = false
		skipping = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true


static func accelerating(story_scene) -> bool:
	return is_instance_valid(story_scene) and story_scene.has_method("is_story_fast_forwarding") and bool(story_scene.is_story_fast_forwarding())


static func wait_seconds(story_scene: Node, duration: float) -> void:
	if not is_finite(duration) or duration <= 0.0 or accelerating(story_scene):
		return
	var remaining := duration
	while is_instance_valid(story_scene) and story_scene.is_inside_tree() and remaining > 0.0:
		await story_scene.get_tree().process_frame
		if accelerating(story_scene):
			return
		if is_instance_valid(story_scene) and story_scene.can_process():
			remaining -= maxf(0.0, story_scene.get_process_delta_time())


static func wait_tween(story_scene: Node, tween: Tween) -> void:
	if tween == null or not tween.is_valid():
		return
	# Finish, rather than kill, so any awaiting action can commit its next cursor.
	var ended := [false]
	var on_finished := func() -> void: ended[0] = true
	tween.finished.connect(on_finished, Object.CONNECT_ONE_SHOT)
	while is_instance_valid(story_scene) and story_scene.is_inside_tree() and tween.is_valid() and not ended[0]:
		if accelerating(story_scene):
			tween.custom_step(86400.0)
			if not tween.is_valid() or ended[0]:
				break
		await story_scene.get_tree().process_frame
	if tween.finished.is_connected(on_finished):
		tween.finished.disconnect(on_finished)
