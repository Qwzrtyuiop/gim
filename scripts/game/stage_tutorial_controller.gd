extends RefCounted

const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const TUTORIAL_IMAGE := preload("res://assets/tutorial/tutorial.png")
const GameInput := preload("res://scripts/game/game_input.gd")

var layer: CanvasLayer
var overlay: Control
var image_rect: TextureRect
var hint_label: Label
var arrow_up_label: Label
var arrow_down_label: Label
var arrow_left_label: Label
var arrow_right_label: Label
var phase := ""
var active := false
var timer_started := false
var input_lock_active := false


static func schedule(owner) -> void:
	if owner.stage_tutorial == null or owner.stage_tutorial.timer_started:
		return
	if not should_show(owner):
		return
	if owner.game_state != "playing":
		return
	owner.stage_tutorial.timer_started = true
	owner.stage_tutorial.show(owner)


static func should_show(owner) -> bool:
	if not owner.use_player_state_stage_sequence:
		return false
	if PlayerState.get_current_day() > 1:
		return false
	if int(PlayerState.stage_round) > 1:
		return false
	return true


func show(parent: Node) -> void:
	if active:
		return
	if overlay == null:
		_build_overlay(parent)
	active = true
	input_lock_active = false
	_set_phase("image")


func end() -> void:
	active = false
	phase = ""
	if overlay != null:
		overlay.visible = false
	input_lock_active = false


func handle_input(event: InputEvent) -> bool:
	if input_lock_active:
		return true
	if not active:
		return false

	if phase == "image" and GameInput.is_any_press(event):
		_set_phase("move")
	elif phase == "move" and GameInput.is_up_down_input(event):
		_set_phase("speed")
	elif phase == "speed" and GameInput.is_left_right_input(event):
		_set_phase("boost")
	elif phase == "boost" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT:
		end()
	return true


func update_positions(player: Sprite2D, player_x: float, viewport_size: Vector2, lane_y_provider: Callable) -> void:
	if not active or player == null:
		return

	var lane_center := Vector2(
		clampf(player_x + 360.0, 260.0, viewport_size.x - 280.0),
		float(lane_y_provider.call(1, viewport_size)) - 72.0
	)
	if arrow_up_label != null and arrow_up_label.visible:
		arrow_up_label.position = lane_center + Vector2(-230.0, -32.0)
	if arrow_down_label != null and arrow_down_label.visible:
		arrow_down_label.position = lane_center + Vector2(10.0, -32.0)
	if arrow_left_label != null and arrow_left_label.visible:
		arrow_left_label.position = lane_center + Vector2(-250.0, -32.0)
	if arrow_right_label != null and arrow_right_label.visible:
		arrow_right_label.position = lane_center + Vector2(10.0, -32.0)


func _set_phase(new_phase: String) -> void:
	phase = new_phase
	if overlay == null:
		return
	overlay.visible = true
	if image_rect != null:
		image_rect.visible = phase == "image"
	if arrow_up_label != null:
		arrow_up_label.visible = phase == "move"
	if arrow_down_label != null:
		arrow_down_label.visible = phase == "move"
	if arrow_left_label != null:
		arrow_left_label.visible = phase == "speed"
	if arrow_right_label != null:
		arrow_right_label.visible = phase == "speed"
	if hint_label != null:
		var is_boost_step := phase == "boost"
		hint_label.anchor_left = 0.05 if is_boost_step else 0.5
		hint_label.anchor_right = 0.95 if is_boost_step else 0.5
		hint_label.anchor_top = 0.5 if is_boost_step else 1.0
		hint_label.anchor_bottom = 0.5 if is_boost_step else 1.0
		hint_label.offset_left = 0.0 if is_boost_step else -260.0
		hint_label.offset_right = 0.0 if is_boost_step else 260.0
		hint_label.offset_top = -70.0 if is_boost_step else -60.0
		hint_label.offset_bottom = 70.0 if is_boost_step else -20.0
		match phase:
			"image":
				hint_label.text = "Press any key to close tutorial"
			"move":
				hint_label.text = "Press UP or DOWN to continue"
			"speed":
				hint_label.text = "Press LEFT or RIGHT to continue"
			"boost":
				hint_label.text = "Press Shift to boost\n\nWARNING: this increases the use of gas"
			_:
				hint_label.text = ""
		hint_label.visible = not hint_label.text.is_empty()


func _build_overlay(parent: Node) -> void:
	layer = CanvasLayer.new()
	layer.layer = 950
	parent.add_child(layer)

	overlay = Control.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	layer.add_child(overlay)

	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	image_rect = TextureRect.new()
	image_rect.texture = TUTORIAL_IMAGE
	image_rect.anchor_right = 1.0
	image_rect.anchor_bottom = 1.0
	image_rect.offset_left = 24.0
	image_rect.offset_top = 24.0
	image_rect.offset_right = -24.0
	image_rect.offset_bottom = -72.0
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(image_rect)

	hint_label = _make_label(14, Color(0.98, 0.96, 0.88, 1.0), 3)
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -260.0
	hint_label.offset_top = -60.0
	hint_label.offset_right = 260.0
	hint_label.offset_bottom = -20.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(hint_label)

	arrow_up_label = _make_arrow_label("UP ARROW\nMOVE UP", 220.0)
	overlay.add_child(arrow_up_label)
	arrow_down_label = _make_arrow_label("DOWN ARROW\nMOVE DOWN", 220.0)
	overlay.add_child(arrow_down_label)
	arrow_left_label = _make_arrow_label("LEFT ARROW\nDECELERATE", 240.0)
	overlay.add_child(arrow_left_label)
	arrow_right_label = _make_arrow_label("RIGHT ARROW\nACCELERATE", 240.0)
	overlay.add_child(arrow_right_label)


func _make_arrow_label(text: String, width: float) -> Label:
	var label := _make_label(13, Color(0.98, 0.96, 0.88, 1.0), 3)
	label.text = text
	label.size = Vector2(width, 52.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	return label


func _make_label(font_size: int, color: Color, outline_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("outline_size", outline_size)
	return label
