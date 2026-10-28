extends RefCounted

# The station teaches resources. The first drive only rehearses its controls.
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const PHASES := ["up", "down", "accelerate", "brake", "boost", "horn"]
const CONTROL_KEYS := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_S, KEY_A, KEY_D, KEY_SHIFT, KEY_Q]
const CONTROL_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right"]
const PROMPTS := {
	"up": "MOVE UP\n\nPress W or Up to move to the lane above.",
	"down": "MOVE DOWN\n\nPress S or Down to move to the lane below.",
	"accelerate": "ACCELERATE\n\nHold D or Right to speed up.\nPress it now to continue.",
	"brake": "BRAKE\n\nHold A or Left to slow down.\nPress it now to continue.",
	"boost": "BOOST\n\nHold Shift for a burst of speed.\nPress it now to continue.",
	"horn": "HORN\n\nHold Q to sound the horn.\nPress it now to finish practicing.",
	"release": "Release the controls to start driving.",
}

var layer: CanvasLayer
var overlay: Control
var hint_label: Label
var highlight: Panel
var text_panel: Panel
var host: Control
var phase := ""
var active := false
var timer_started := false
var input_lock_active := false
var _layout_size := Vector2.ZERO
var _held_keys: Dictionary = {}
var _held_actions: Dictionary = {}


static func schedule(owner) -> void:
	if owner.stage_tutorial == null or owner.stage_tutorial.timer_started:
		return
	if not should_show(owner) or owner.game_state != "playing":
		return
	owner.stage_tutorial.timer_started = true
	owner.stage_tutorial.show(owner)


static func should_show(owner) -> bool:
	return (
		owner.use_player_state_stage_sequence
		and PlayerState.get_current_day() <= 1
		and int(PlayerState.stage_round) <= 1
	)


func show(parent: Node) -> void:
	if active:
		return
	if overlay == null:
		_build_overlay(parent)
	active = true
	input_lock_active = false
	_held_keys.clear()
	_held_actions.clear()
	_set_phase(PHASES[0])


func end() -> void:
	active = false
	phase = ""
	input_lock_active = false
	_held_keys.clear()
	_held_actions.clear()
	TutorialOverlayHelper.set_overlay_visible(false, overlay, text_panel, hint_label)


func handle_input(event: InputEvent) -> bool:
	if input_lock_active:
		return true
	if not active:
		return false
	_track_controls(event)
	if phase == "release":
		if not _controls_held():
			end()
		return true
	if event.is_echo():
		return true
	var matched := false
	match phase:
		"up":
			matched = event.is_action_pressed("ui_up") or _is_key(event, [KEY_UP, KEY_W])
		"down":
			matched = event.is_action_pressed("ui_down") or _is_key(event, [KEY_DOWN, KEY_S])
		"accelerate":
			matched = event.is_action_pressed("ui_right") or _is_key(event, [KEY_RIGHT, KEY_D])
		"brake":
			matched = event.is_action_pressed("ui_left") or _is_key(event, [KEY_LEFT, KEY_A])
		"boost":
			matched = _is_key(event, [KEY_SHIFT])
		"horn":
			matched = _is_key(event, [KEY_Q])
	if matched:
		var index := PHASES.find(phase) + 1
		if index >= PHASES.size():
			_set_phase("release")
		else:
			_set_phase(PHASES[index])
	return true


func update_positions(player: Sprite2D, _player_x: float, viewport_size: Vector2, _lane_y_provider: Callable) -> void:
	# Regression probes and restored rides can toggle the lock state without
	# ever constructing this presentation layer.
	if not active or overlay == null or host == null or highlight == null or text_panel == null:
		return
	_layout(viewport_size)
	if player == null or player.texture == null:
		highlight.hide()
		return
	var player_bounds := player.get_global_transform_with_canvas() * player.get_rect()
	highlight.position = player_bounds.position - Vector2(10, 10)
	highlight.size = player_bounds.size + Vector2(20, 20)
	highlight.show()
	# Keep the control card clear of the highlighted tricycle.
	if text_panel.get_rect().intersects(highlight.get_rect()):
		text_panel.position.y = maxf(16.0, highlight.position.y - text_panel.size.y - 18.0)


func _set_phase(new_phase: String) -> void:
	phase = new_phase
	if overlay == null:
		return
	hint_label.text = str(PROMPTS[phase]) if phase == "release" else "%s\n\n%d / %d" % [str(PROMPTS.get(phase, "")), PHASES.find(phase) + 1, PHASES.size()]
	TutorialOverlayHelper.set_overlay_visible(true, overlay, text_panel, hint_label)
	_layout(host.get_viewport_rect().size)


func _build_overlay(parent: Node) -> void:
	layer = CanvasLayer.new()
	layer.layer = 950
	parent.add_child(layer)
	host = Control.new()
	host.name = "DrivingControlsTutorial"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var refs := TutorialOverlayHelper.create(host, UI_FONT)
	overlay = refs.overlay
	highlight = refs.highlight
	text_panel = refs.text_panel
	hint_label = refs.text_label
	highlight.hide()


func _layout(viewport_size: Vector2) -> void:
	if text_panel == null or _layout_size.is_equal_approx(viewport_size):
		return
	_layout_size = viewport_size
	text_panel.size = Vector2(minf(600.0, maxf(1.0, viewport_size.x - 40.0)), 172.0)
	text_panel.position = Vector2((viewport_size.x - text_panel.size.x) * 0.5, maxf(16.0, viewport_size.y * 0.16))
	hint_label.add_theme_font_size_override("font_size", 11 if viewport_size.x < 800.0 else 12)


static func _is_key(event: InputEvent, keycodes: Array) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode in keycodes or event.physical_keycode in keycodes)
	)


func _track_controls(event: InputEvent) -> void:
	if event is InputEventKey:
		for key in [event.keycode, event.physical_keycode]:
			if not key in CONTROL_KEYS:
				continue
			if event.pressed:
				_held_keys[key] = true
			else:
				_held_keys.erase(key)
	for action: String in CONTROL_ACTIONS:
		if event.is_action_pressed(action):
			_held_actions[action] = true
		elif event.is_action_released(action):
			_held_actions.erase(action)


func _controls_held() -> bool:
	if not _held_keys.is_empty() or not _held_actions.is_empty():
		return true
	# Event tracking also works with viewport-injected input. Polling covers
	# controls that were already held before the tutorial was shown.
	for key: Key in CONTROL_KEYS:
		if Input.is_key_pressed(key) or Input.is_physical_key_pressed(key):
			return true
	for action: String in CONTROL_ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false
