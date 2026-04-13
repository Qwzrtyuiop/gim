extends RefCounted

const NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const GLOW_MODULATE := Color(1.35, 1.18, 0.62, 1.0)
const DEFAULT_DURATION := 0.08


static func attach(
	host: Node,
	button: BaseButton,
	normal_modulate := NORMAL_MODULATE,
	glow_modulate := GLOW_MODULATE,
	duration := DEFAULT_DURATION
) -> void:
	if button == null:
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var audio_manager := tree.root.get_node_or_null("UIAudioManager")
		if audio_manager and audio_manager.has_method("attach_button"):
			audio_manager.attach_button(button)

	button.modulate = normal_modulate
	button.mouse_entered.connect(func() -> void:
		set_state(host, button, true, normal_modulate, glow_modulate, duration)
	)
	button.mouse_exited.connect(func() -> void:
		set_state(host, button, false, normal_modulate, glow_modulate, duration)
	)
	button.focus_entered.connect(func() -> void:
		set_state(host, button, true, normal_modulate, glow_modulate, duration)
	)
	button.focus_exited.connect(func() -> void:
		set_state(host, button, false, normal_modulate, glow_modulate, duration)
	)


static func set_state(
	host: Node,
	target: CanvasItem,
	is_glowing: bool,
	normal_modulate := NORMAL_MODULATE,
	glow_modulate := GLOW_MODULATE,
	duration := DEFAULT_DURATION
) -> void:
	_tween_modulate(
		host,
		target,
		glow_modulate if is_glowing else normal_modulate,
		duration
	)


static func _tween_modulate(host: Node, target: CanvasItem, modulate_value: Color, duration: float) -> void:
	if host == null or target == null:
		return
	if not is_instance_valid(host) or not is_instance_valid(target):
		return

	var tween := host.create_tween()
	tween.tween_property(target, "modulate", modulate_value, duration)
