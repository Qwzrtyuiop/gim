extends Control

# Scene-local speech for hubs. No story routing, effects, checkpoints or saves.
signal message_started(line: Dictionary)
signal message_finished(line: Dictionary)
signal sequence_finished(cancelled: bool)

const SpeechBox := preload("res://scripts/ui/hub_speech_box.gd")
const DialoguePlayback := preload("res://scripts/story/story_dialogue_playback.gd")

var bubble: SpeechBox
var playback: DialoguePlayback
var active_line: Dictionary = {}
var safe_top := 96.0
var _queue: Array[Dictionary] = []
var _targets: Dictionary = {}
var _gate := Callable()
var _remaining := 0.0
var _just_started := false
var _generation := 0
var _target_rect := Rect2()


func _ready() -> void:
	name = "HubDialogue"
	z_index = 70
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble = SpeechBox.new()
	bubble.name = "SpeechBox"
	add_child(bubble)
	bubble.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble.advanced.connect(advance)
	bubble.dismissed.connect(clear)
	bubble.hide()
	UIAudioManager.attach_button(bubble.close_button)
	playback = DialoguePlayback.new()
	playback.name = "SpeechPlayback"
	add_child(playback)
	playback.setup(bubble.body_label)
	StoryLanguageManager.language_changed.connect(_on_language_changed)
	if not active_line.is_empty():
		_present_line()
	else:
		set_process(false)


func register_target(id: String, provider: Callable) -> void:
	# Providers return canvas/global rectangles, recalculated as a sprite moves.
	# An empty rectangle means the speaker is currently offscreen/unavailable.
	_targets[id] = provider


func register_control(id: String, control: Control) -> void:
	var reference: WeakRef = weakref(control)
	register_target(id, func() -> Rect2:
		var target := reference.get_ref() as Control
		if target == null or not target.is_inside_tree() or not target.is_visible_in_tree():
			return Rect2()
		var local := Rect2(Vector2.ZERO, target.size)
		if target is TextureRect and target.texture != null and target.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			var texture_size: Vector2 = target.texture.get_size()
			var fit := minf(target.size.x / texture_size.x, target.size.y / texture_size.y)
			local = Rect2((target.size - texture_size * fit) * 0.5, texture_size * fit)
		return target.get_global_transform_with_canvas() * local
	)


func register_sprite(id: String, sprite: Sprite2D) -> void:
	var reference: WeakRef = weakref(sprite)
	register_target(id, func() -> Rect2:
		var target := reference.get_ref() as Sprite2D
		if target == null or not target.is_inside_tree() or not target.is_visible_in_tree() or target.texture == null:
			return Rect2()
		return target.get_global_transform_with_canvas() * target.get_rect()
	)


func set_gate(gate: Callable) -> void:
	_gate = gate
	if is_node_ready():
		_update_context()


func say(text: Variant, options: Dictionary = {}) -> bool:
	return play([{"text": text}], options)


func play(lines: Array, options: Dictionary = {}) -> bool:
	var prepared := _prepare(lines, options)
	if prepared.is_empty():
		return false
	var expected_generation := _generation + 1
	clear()
	# A cancellation callback may already have supplied a replacement. Let that
	# newer request stand rather than overwrite a line whose start was emitted.
	if _generation != expected_generation or is_active():
		return true
	_queue.assign(prepared)
	_start_next()
	return true


func queue_messages(lines: Array, options: Dictionary = {}) -> bool:
	var prepared := _prepare(lines, options)
	if prepared.is_empty():
		return false
	_queue.append_array(prepared)
	if active_line.is_empty():
		_start_next()
	return true


func is_active() -> bool:
	return not active_line.is_empty() or not _queue.is_empty()


func blocks_input() -> bool:
	return bool(active_line.get("blocking", false)) and _can_present()


func handle_input(event: InputEvent) -> bool:
	# Nonblocking speech never steals Enter, arrows or Escape from a menu.
	# Screens call this after tutorial handling, before their normal menu input.
	if event.is_action_pressed("ui_cancel") or not blocks_input():
		return false
	# Let the balloon receive its own clicks and wheel scrolling. Only clicks
	# outside it advance a blocking conversation through this screen-level path.
	if event is InputEventMouseButton and bubble.panel.get_global_rect().has_point(event.position):
		return false
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		advance()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
	return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion


func advance() -> void:
	if not _can_present():
		return
	# First press completes the shaped line; the next completes the message.
	if playback.finish_now():
		return
	_complete_line()


func clear() -> void:
	var had_messages := is_active()
	_generation += 1
	active_line.clear()
	_queue.clear()
	_remaining = 0
	set_process(false)
	if playback != null:
		playback.cancel()
	if bubble != null:
		bubble.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if had_messages:
		sequence_finished.emit(true)


func _process(delta: float) -> void:
	if not _update_context():
		return
	if playback.active or float(active_line.get("duration", 0.0)) <= 0:
		return
	if _just_started:
		_just_started = false
		return
	_remaining -= maxf(0, delta)
	if _remaining <= 0:
		_complete_line()


func _gui_input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


func _prepare(lines: Array, options: Dictionary) -> Array[Dictionary]:
	var prepared: Array[Dictionary] = []
	for value in lines:
		var line := options.duplicate(true)
		if value is String:
			line["text"] = value
		elif value is Dictionary:
			line.merge(value, true)
		else:
			return []
		if _localized(line.get("text", "")).strip_edges().is_empty():
			return []
		var duration: Variant = line.get("duration", 0.0)
		if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) < 0:
			return []
		if not line.get("blocking", false) is bool:
			return []
		if not line.get("typewriter", true) is bool and not line.get("typewriter", true) is Dictionary:
			return []
		if line.has("position") and not line.position is Vector2:
			return []
		if not line.get("target", "") is String:
			return []
		line["duration"] = minf(float(duration), 3600.0)
		prepared.append(line)
	return prepared


func _start_next() -> void:
	if _queue.is_empty():
		return
	_generation += 1
	active_line = _queue.pop_front()
	set_process(true)
	_remaining = float(active_line.get("duration", 0.0))
	_just_started = true
	if is_node_ready():
		_present_line()
	message_started.emit(active_line.duplicate(true))


func _present_line(instant := false) -> void:
	var options := active_line.duplicate(true)
	if not options.has("hint"):
		options["hint"] = "Click / Enter to continue" if bool(options.get("blocking", false)) else "Click to continue"
		if float(options.get("duration", 0.0)) > 0:
			options["hint"] = "Click to dismiss"
	var character_id := str(active_line.get("character_id", ""))
	var speaker := _localized(active_line.get("speaker", ""))
	if not character_id.is_empty():
		speaker = PlayerState.get_character_display_name(character_id)
	bubble.set_line(speaker, _localized(active_line.text), options)
	# Keep the label visible while start() shapes the line, then pause/hide if its
	# target or menu is unavailable. Hidden-label start would skip the animation.
	bubble.show()
	var voice_speaker := character_id if not character_id.is_empty() else speaker
	playback.process_mode = Node.PROCESS_MODE_INHERIT
	playback.start({}, active_line, voice_speaker)
	if instant:
		playback.finish_now()
	_update_context()


func _complete_line() -> void:
	var completed := active_line.duplicate(true)
	_generation += 1
	var generation := _generation
	active_line.clear()
	playback.cancel()
	bubble.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_finished.emit(completed)
	# A callback can replace or cancel a conversation without an old continuation
	# advancing the new one or emitting a second completion.
	if generation != _generation or not active_line.is_empty():
		return
	if not _queue.is_empty():
		_start_next()
	else:
		set_process(false)
		sequence_finished.emit(false)


func _can_present() -> bool:
	if active_line.is_empty() or not is_inside_tree() or not is_visible_in_tree() or not can_process() or bubble == null:
		return false
	if _gate.is_valid() and not bool(_gate.call()):
		return false
	_target_rect = Rect2()
	var target := str(active_line.get("target", ""))
	if not target.is_empty():
		var provider: Callable = _targets.get(target, Callable())
		if not provider.is_valid():
			return false
		var resolved: Variant = provider.call()
		if not resolved is Rect2 or resolved.size.x <= 0 or resolved.size.y <= 0:
			return false
		_target_rect = get_global_transform_with_canvas().affine_inverse() * resolved
		if not _target_rect.intersects(Rect2(Vector2.ZERO, size)):
			return false
	elif active_line.has("position"):
		var point: Vector2 = active_line.position.clamp(Vector2.ZERO, Vector2.ONE) * size
		_target_rect = Rect2(point, Vector2.ONE)
	return true


func _update_context() -> bool:
	if bubble == null:
		return false
	var ready := _can_present()
	if not ready:
		bubble.hide()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if playback != null:
			playback.process_mode = Node.PROCESS_MODE_DISABLED
			playback.voice.stop()
		return false
	bubble.show()
	playback.process_mode = Node.PROCESS_MODE_INHERIT
	mouse_filter = Control.MOUSE_FILTER_STOP if bool(active_line.get("blocking", false)) else Control.MOUSE_FILTER_IGNORE
	var top := minf(safe_top, size.y * 0.35)
	var safe_rect := Rect2(Vector2(12, maxf(12, top)), Vector2(maxf(1, size.x - 24), maxf(1, size.y - maxf(12, top) - 12)))
	bubble.layout_near(_target_rect, safe_rect, str(active_line.get("side", "auto")))
	return true


func _on_language_changed(_language: String) -> void:
	if not active_line.is_empty():
		_present_line(true)


func _localized(value: Variant) -> String:
	if value is String:
		return value
	if value is Dictionary:
		var text: Variant = value.get(StoryLanguageManager.get_language(), value.get("english", ""))
		return text if text is String else ""
	return ""
