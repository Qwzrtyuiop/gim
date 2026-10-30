extends Control

# Scene-local fishing prototype. The session owns hook/fish movement and catches.
signal finished

const FishingSession := preload("res://scripts/home/fishing_session.gd")
const FishCatalog := preload("res://scripts/home/fishing_fish_catalog.gd")
const FishingCatchResults := preload("res://scripts/home/fishing_catch_results.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const OCEAN_FRAMES := [
	preload("res://assets/ui/fishingminigame/fishingframeloop1.png"),
	preload("res://assets/ui/fishingminigame/fishingframeloop2.png"),
	preload("res://assets/ui/fishingminigame/fishingframeloop3.png"),
]
const REEL := preload("res://assets/ui/fishingminigame/reel.png")
const HOOK := preload("res://assets/ui/fishingminigame/hook.png")
const ART_SIZE := Vector2(1774, 887)
# The rotating crank extends below the authored canvas during a full turn.
const LAYOUT_SIZE := ART_SIZE + Vector2(0, 88)
const WATER_RECT := Rect2(35, 10, 1665, 585)
const REEL_SOURCE := Rect2(272, 761, 170, 115)
# The supplied reel_pivot_indicator marks this source-canvas point.
const REEL_PIVOT := Vector2(417.5, 784.5)
const REEL_GRIP := Vector2(295, 842)
const REEL_DRAG_RADIUS := 180.0
const REEL_DEADZONE := 18.0
const REEL_FIGHT_SHAKE_PIXELS := 5.0
const HOOK_SOURCE := Rect2(974, 507, 19, 34)
const HOOK_ATTACHMENT := Vector2(12.5, 0)
const HOOK_TIP_OFFSET := Vector2(-10, 24.5)
const HOOK_FEEDBACK_SECONDS := 0.8
const INFO_RECT := Rect2(650, 706, 1060, 214)

class FishingCanvas:
	extends Control
	var paint := Callable()

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)

var active := false
var session: FishingSession = FishingSession.new()
var reel_angle := 0.0
var dragging := false
var cursor_locked := false
var ocean_frame_index := 0
var close_button: Button
var _canvas: FishingCanvas
var _water_canvas: FishingCanvas
var _status: Label
var _catch_label: Label
var _catch_results: FishingCatchResults
var _session_catches: Array[Dictionary] = []
var _info_panel: StyleBoxFlat
var _ocean_elapsed := 0.0
var _fish_elapsed := 0.0
var _feedback_elapsed := 0.0
var _reel_shake_elapsed := 0.0
var _reel_shake_offset := Vector2.ZERO
var _hook_feedback: Label
var _hook_feedback_tween: Tween
var _last_hook_cue := ""
var _hook_cue_cooldown := 0.0
var _appearance_rng := RandomNumberGenerator.new()
var _mouse_mode_before_capture: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _native_cursor_captured := false


func _ready() -> void:
	name = "FishingOverlay"
	z_index = 400
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_appearance_rng.randomize()
	_build_ui()
	session.fish_hooked.connect(_on_fish_hooked)
	session.fish_caught.connect(_on_fish_caught)
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	_layout()
	hide()
	set_process(false)


func present(seed_value: int = 0) -> void:
	if active:
		return
	session.reset(seed_value)
	session.hook_tip_offset = HOOK_TIP_OFFSET / WATER_RECT.size
	_configure_fish()
	active = true
	reel_angle = 0.0
	ocean_frame_index = 0
	_ocean_elapsed = 0.0
	_fish_elapsed = 0.0
	_feedback_elapsed = 0.0
	_session_catches.clear()
	_catch_results.hide()
	_canvas.show()
	_clear_hook_feedback()
	_release_drag()
	_status.text = "Lower the hook\ntoward a fish."
	_status.add_theme_color_override("font_color", Color("f6e2b6"))
	_refresh_catches()
	show()
	_layout()
	set_process(true)


func close() -> void:
	if not active or _catch_results.visible:
		return
	_clear_hook_feedback()
	_release_drag()
	set_process(false)
	close_button.release_focus()
	get_viewport().set_input_as_handled()
	if not _session_catches.is_empty():
		_canvas.hide()
		_catch_results.present(_catch_summary())
		return
	_finish_session()


func _finish_session() -> void:
	if not active:
		return
	active = false
	_clear_hook_feedback()
	_release_drag()
	set_process(false)
	_catch_results.hide()
	hide()
	get_viewport().set_input_as_handled()
	finished.emit()


func _catch_summary() -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	var records_by_species: Dictionary = {}
	for caught: Dictionary in _session_catches:
		var entry := caught.duplicate(true)
		var fish_id := str(entry.fish_id)
		if not records_by_species.has(fish_id):
			records_by_species[fish_id] = PlayerState.get_fish_size_records(fish_id)
		var records: Dictionary = records_by_species[fish_id]
		if not records.is_empty():
			entry.is_smallest = bool(entry.is_smallest) and is_equal_approx(float(entry.length_cm), float(records.smallest_cm))
			entry.is_largest = bool(entry.is_largest) and is_equal_approx(float(entry.length_cm), float(records.largest_cm))
		summary.append(entry)
	return summary


func _process(delta: float) -> void:
	if not active or not is_visible_in_tree() or get_tree().paused:
		return
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_drag()
	_hook_cue_cooldown = maxf(0.0, _hook_cue_cooldown - delta)
	var automatic_before: float = session.automatic_reel_angle
	session.update(delta)
	reel_angle = wrapf(reel_angle + session.automatic_reel_angle - automatic_before, -PI, PI)
	_update_reel_shake(delta)
	_configure_fish()
	var frame_seconds := GameTuning.FISHING_OCEAN_FRAME_SECONDS
	_ocean_elapsed = fmod(_ocean_elapsed + maxf(0.0, delta), frame_seconds * OCEAN_FRAMES.size())
	ocean_frame_index = mini(OCEAN_FRAMES.size() - 1, int(_ocean_elapsed / frame_seconds))
	_fish_elapsed = fmod(_fish_elapsed + maxf(0.0, delta), 0.54)
	_feedback_elapsed = maxf(0.0, _feedback_elapsed - delta)
	_refresh_status()
	_canvas.queue_redraw()
	_water_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree() or not dragging:
		return
	# Escape is owned by the global pause menu, including while reeling.
	if event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventMouseMotion:
		_drag_relative(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_drag()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not active or _catch_results.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var source := global_to_source(get_global_transform_with_canvas() * event.position)
			var offset := source - REEL_PIVOT
			if offset.length() <= REEL_DRAG_RADIUS and offset.length() >= REEL_DEADZONE:
				dragging = true
				session.set_reel_held(true)
				_lock_cursor()
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				_canvas.queue_redraw()
		else:
			_release_drag()
		accept_event()
	elif event is InputEventMouseMotion and not dragging:
		var source := global_to_source(get_global_transform_with_canvas() * event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if source.distance_to(REEL_PIVOT) <= REEL_DRAG_RADIUS else Control.CURSOR_ARROW


func _drag_relative(event: InputEventMouseMotion) -> void:
	var motion: Vector2
	if not event.relative.is_zero_approx():
		motion = _canvas.get_global_transform_with_canvas().affine_inverse().basis_xform(event.relative)
	else:
		motion = _canvas.get_screen_transform().affine_inverse().basis_xform(event.screen_relative)
	var grip_offset := grip_source_position() - REEL_PIVOT
	var tangent := Vector2(-grip_offset.y, grip_offset.x).normalized()
	var change := clampf(motion.dot(tangent) / grip_offset.length(), -PI * 0.65, PI * 0.65)
	var accepted: float = session.reel(change)
	reel_angle = wrapf(reel_angle + accepted, -PI, PI)
	_canvas.queue_redraw()
	_water_canvas.queue_redraw()


func grip_source_position() -> Vector2:
	return REEL_PIVOT + (REEL_GRIP - REEL_PIVOT).rotated(reel_angle)


func _update_reel_shake(delta: float) -> void:
	if not dragging or not session.is_reel_in_blocked():
		_reel_shake_elapsed = 0.0
		_reel_shake_offset = Vector2.ZERO
		return
	_reel_shake_elapsed = fmod(_reel_shake_elapsed + delta, TAU)
	_reel_shake_offset = Vector2(sin(_reel_shake_elapsed * 83.0), sin(_reel_shake_elapsed * 109.0 + 0.7)) * REEL_FIGHT_SHAKE_PIXELS


func _lock_cursor() -> void:
	if cursor_locked:
		return
	cursor_locked = true
	_mouse_mode_before_capture = Input.mouse_mode
	# A headless fixture exercises the logical lock without changing the OS cursor.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_native_cursor_captured = true


func _release_drag() -> void:
	dragging = false
	_reel_shake_elapsed = 0.0
	_reel_shake_offset = Vector2.ZERO
	session.set_reel_held(false)
	if _native_cursor_captured:
		Input.mouse_mode = _mouse_mode_before_capture
	_native_cursor_captured = false
	cursor_locked = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_drag()


func _exit_tree() -> void:
	_release_drag()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_release_drag()


func source_to_global(point: Vector2) -> Vector2:
	return _canvas.get_global_transform_with_canvas() * point


func global_to_source(point: Vector2) -> Vector2:
	return _canvas.get_global_transform_with_canvas().affine_inverse() * point


func _on_fish_hooked(_id: int) -> void:
	_refresh_status()
	_feedback_elapsed = 2.5


func _on_fish_caught(_total: int) -> void:
	if not session.catches.is_empty():
		var record := PlayerState.record_fish_catch(session.catches.back())
		if not record.is_empty():
			_session_catches.append(record)
	_configure_fish()
	_clear_hook_feedback()
	_status.text = "Got one!\nTry for another."
	_status.add_theme_color_override("font_color", Color("c4e39a"))
	_feedback_elapsed = 2.5
	_refresh_catches()


func _refresh_catches() -> void:
	_catch_label.text = "Fish caught: %d" % session.caught_count


func _refresh_status() -> void:
	if session.fight_phase == "pulling" or session.fight_phase == "resting":
		_status.text = ""
		var cue := "Hold!" if session.is_reel_in_blocked() else "Reel!"
		if cue != _last_hook_cue and _hook_cue_cooldown <= 0.0:
			_show_hook_feedback(cue)
	elif _feedback_elapsed <= 0.0:
		_status.text = "Lower the hook\ntoward a fish."
		_status.add_theme_color_override("font_color", Color("f6e2b6"))


func _show_hook_feedback(cue: String) -> void:
	_clear_hook_feedback()
	_last_hook_cue = cue
	_hook_cue_cooldown = HOOK_FEEDBACK_SECONDS
	_hook_feedback = _label(cue, 28, Rect2(0, 0, 180, 40))
	_hook_feedback.add_theme_color_override("font_color", Color("ffa68f") if cue == "Hold!" else Color("c4ef8a"))
	var tip := WATER_RECT.position + session.hook_tip_position() * WATER_RECT.size
	_hook_feedback.position = Vector2(clampf(tip.x - 90.0, 4.0, ART_SIZE.x - 184.0), maxf(50.0, tip.y - 40.0))
	_hook_feedback_tween = create_tween().set_parallel(true)
	_hook_feedback_tween.tween_property(_hook_feedback, "position:y", _hook_feedback.position.y - 42.0, HOOK_FEEDBACK_SECONDS)
	_hook_feedback_tween.tween_property(_hook_feedback, "modulate:a", 0.0, HOOK_FEEDBACK_SECONDS)
	_hook_feedback_tween.chain().tween_callback(_hook_feedback.queue_free)


func _clear_hook_feedback() -> void:
	if _hook_feedback_tween != null:
		_hook_feedback_tween.kill()
		_hook_feedback_tween = null
	if is_instance_valid(_hook_feedback):
		_hook_feedback.hide()
		_hook_feedback.queue_free()
	_hook_feedback = null
	_last_hook_cue = ""
	_hook_cue_cooldown = 0.0


func _configure_fish() -> void:
	for entry: Dictionary in session.fish:
		var revision := int(entry.get("appearance_revision", 0))
		if entry.has("species") and int(entry.get("configured_appearance_revision", -1)) == revision:
			continue
		var species := _appearance_rng.randi_range(0, FishCatalog.SPECIES.size() - 1)
		entry.species = species
		entry.configured_appearance_revision = revision
		var size_scale := float(entry.get("size_scale", 1.0))
		entry.size = FishCatalog.visual_size(species, 0, size_scale) / WATER_RECT.size
		entry.mouth_offset = FishCatalog.mouth_offset(species, 0, size_scale) / WATER_RECT.size


func _build_ui() -> void:
	_info_panel = StyleBoxFlat.new()
	_info_panel.bg_color = Color(0.025, 0.085, 0.11, 0.9)
	_info_panel.border_color = Color(0.72, 0.82, 0.77, 0.35)
	_info_panel.set_border_width_all(2)
	_info_panel.set_corner_radius_all(10)
	_info_panel.shadow_color = Color(0, 0, 0, 0.25)
	_info_panel.shadow_size = 6
	_canvas = FishingCanvas.new()
	_canvas.name = "FishingCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.paint = _paint_canvas
	_canvas.size = ART_SIZE
	add_child(_canvas)
	_water_canvas = FishingCanvas.new()
	_water_canvas.name = "FishingWater"
	_water_canvas.position = WATER_RECT.position
	_water_canvas.size = WATER_RECT.size
	_water_canvas.clip_contents = true
	_water_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_canvas.paint = _paint_water
	_canvas.add_child(_water_canvas)
	_catch_label = _label("", 26, Rect2(696, 734, 470, 40))
	_catch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status = _label("", 24, Rect2(696, 792, 470, 90))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label("Turn right: lower\nTurn left: reel in", 24, Rect2(1200, 748, 490, 124))
	close_button = Button.new()
	close_button.name = "CloseFishing"
	close_button.text = "FINISH"
	close_button.position = Vector2(1470, 18)
	close_button.size = Vector2(240, 58)
	DashboardTheme.apply_button(close_button)
	close_button.pressed.connect(close)
	_canvas.add_child(close_button)
	UIAudioManager.attach_button(close_button)
	_catch_results = FishingCatchResults.new()
	add_child(_catch_results)
	_catch_results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catch_results.finished.connect(_finish_session)


func _label(text: String, font_size: int, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f6e2b6"))
	label.add_theme_color_override("font_outline_color", Color("10231e"))
	label.add_theme_constant_override("outline_size", 4)
	_canvas.add_child(label)
	return label


func _paint_canvas(canvas: Control) -> void:
	canvas.draw_texture_rect(OCEAN_FRAMES[ocean_frame_index], Rect2(Vector2.ZERO, ART_SIZE), false)
	canvas.draw_style_box(_info_panel, INFO_RECT)
	canvas.draw_line(Vector2(1180, 734), Vector2(1180, 892), Color(0.72, 0.82, 0.77, 0.2), 2)
	canvas.draw_set_transform(REEL_PIVOT + _reel_shake_offset, reel_angle, Vector2.ONE)
	canvas.draw_texture_rect_region(REEL, Rect2(REEL_SOURCE.position - REEL_PIVOT, REEL_SOURCE.size), REEL_SOURCE)
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_circle(REEL_PIVOT + _reel_shake_offset, 7, Color("f3c259"), false, 2)
	if cursor_locked:
		var grip := grip_source_position() + _reel_shake_offset
		canvas.draw_circle(grip, 12, Color(0.95, 0.88, 0.64, 0.3))
		canvas.draw_circle(grip, 12, Color("f8e1a5"), false, 2)
		var pointer := PackedVector2Array([
			grip, grip + Vector2(2, 26), grip + Vector2(9, 20),
			grip + Vector2(17, 32), grip + Vector2(23, 28),
			grip + Vector2(15, 16), grip + Vector2(25, 15),
		])
		canvas.draw_colored_polygon(pointer, Color("fff2ce"))
		pointer.append(pointer[0])
		canvas.draw_polyline(pointer, Color("17211d"), 2, false)


func _paint_water(canvas: Control) -> void:
	var fish_frame := mini(2, int(_fish_elapsed / 0.18))
	for entry: Dictionary in session.fish:
		var species := int(entry.get("species", posmod(int(entry.id), FishCatalog.SPECIES.size())))
		var facing := float(entry.get("facing", 1))
		var mouth := session.fish_mouth_position(entry) * WATER_RECT.size
		var size_scale := float(entry.get("size_scale", 1.0))
		var visual_size := FishCatalog.visual_size(species, fish_frame, size_scale)
		var visual_mouth := FishCatalog.mouth_offset(species, fish_frame, size_scale)
		canvas.draw_set_transform(mouth, 0.0, Vector2(facing, 1.0))
		canvas.draw_texture_rect(FishCatalog.texture_for(species, fish_frame), Rect2(-visual_mouth - visual_size * 0.5, visual_size), false)
		canvas.draw_set_transform(Vector2.ZERO)
	var attachment := session.hook_position * WATER_RECT.size
	var rope_points := PackedVector2Array()
	for point: Vector2 in session.line_points:
		rope_points.append(point * WATER_RECT.size)
	if rope_points.size() >= 2:
		canvas.draw_polyline(rope_points, Color("a7e8eb"), 2, false)
	canvas.draw_texture_rect_region(HOOK, Rect2(attachment - HOOK_ATTACHMENT, HOOK_SOURCE.size), HOOK_SOURCE)


func _layout() -> void:
	if _canvas == null:
		return
	var margin := Vector2(clampf(size.x * 0.06, 24.0, 80.0), clampf(size.y * 0.075, 18.0, 60.0))
	var available := (size - margin * 2.0).max(Vector2.ONE)
	var fit := minf(available.x / LAYOUT_SIZE.x, available.y / LAYOUT_SIZE.y)
	_canvas.scale = Vector2.ONE * fit
	_canvas.position = (size - LAYOUT_SIZE * fit) * 0.5
	_canvas.queue_redraw()
	_water_canvas.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.035, 0.5))
