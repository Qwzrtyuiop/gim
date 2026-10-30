extends Control

# A paid session owns up to three timing clicks. Energy is charged by the garage.
signal finished
signal attempt_resolved(success: bool)

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const RepairFrame := preload("res://scripts/home/garage_repair_frame.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const WRENCH := preload("res://assets/ui/wrenchrepair/wrenchmain.png")
const SLIDER := preload("res://assets/ui/wrenchrepair/wrenchslider.png")
const TARGET := preload("res://assets/ui/wrenchrepair/wrenchtarget.png")
const DESIGN_SIZE := Vector2(980, 420)
const MAIN_SOURCE := Rect2(39, 216, 2094, 320)
# Keep the replacement's visible body; the export has a black tail below it.
const SLIDER_SOURCE := Rect2(994, 251, 184, 254)
const TARGET_SOURCE := Rect2(802, 337, 187, 79)
# Track coordinates relative to the tightly cropped wrench, shared by art/input.
const TRACK := Rect2(237, 121, 1619, 79)
const ART_ORIGIN := Vector2(52, 145)
const ART_SCALE := 876.0 / 2094.0
const TARGET_FRACTION := 187.0 / 1619.0
const BACKDROP_OPACITY := 0.85

var active := false
var _complete := false
var _clicks := 0
var _repaired := 0
var _slider_phase := 0.0
var _target_left := 0.0
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _content: Control
var _slider: TextureRect
var _target: TextureRect
var _status: Label
var _instruction: Label
var _done: Button


func _ready() -> void:
	name = "GarageRepairOverlay"
	z_index = 400
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_build_ui()
	resized.connect(_layout)
	_layout()
	hide()
	set_process(false)


func present() -> void:
	if active:
		return
	active = true
	_complete = false
	_clicks = 0
	_repaired = 0
	_slider_phase = 0.0
	_cooldown = GameTuning.GARAGE_REPAIR_CLICK_COOLDOWN_SECONDS
	_instruction.text = "Align the slider with the target.\nClick or press Space."
	_instruction.add_theme_color_override("font_color", RepairFrame.SECONDARY_TEXT)
	_done.hide()
	_done.disabled = true
	_done.release_focus()
	_move_target()
	_update_status()
	_position_markers()
	show()
	_layout()
	set_process(true)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_slider_phase = fmod(_slider_phase + delta * GameTuning.GARAGE_REPAIR_SLIDER_SPEED, 2.0)
	_position_markers()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_submit()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if active and is_visible_in_tree() and event.is_action_pressed("ui_accept") and not event.is_echo():
		_submit()
		get_viewport().set_input_as_handled()


func _submit() -> void:
	if not active or _complete or _cooldown > 0.0:
		return
	_cooldown = GameTuning.GARAGE_REPAIR_CLICK_COOLDOWN_SECONDS
	_clicks += 1
	var slider_center := _slider_fraction()
	var success := slider_center >= _target_left and slider_center <= _target_left + TARGET_FRACTION
	if success:
		_repaired += PlayerState.repair_hull(GameTuning.GARAGE_REPAIR_HULL_PER_SUCCESS)
	_show_feedback(success)
	_update_status()
	if _clicks >= GameTuning.GARAGE_REPAIR_MAX_ATTEMPTS or PlayerState.hull >= PlayerState.max_hull:
		_complete = true
		set_process(false)
		_instruction.text = "Repairs finished.\n+%d tricycle condition" % _repaired
		_instruction.add_theme_color_override("font_color", RepairFrame.SUCCESS_TEXT)
		_done.disabled = false
		_done.show()
		_done.grab_focus()
	else:
		_move_target()
		_position_markers()
	attempt_resolved.emit(success)


func _move_target() -> void:
	# Pick from the available interval after excluding the previous target area.
	# A private stream leaves passenger, weather and traffic rolls untouched.
	var maximum := 1.0 - TARGET_FRACTION
	if _clicks == 0:
		_target_left = _rng.randf_range(0.0, maximum)
		return
	var gap := TARGET_FRACTION * 1.2
	var before := maxf(0.0, _target_left - gap)
	var after := minf(maximum, _target_left + gap)
	var available := before + maximum - after
	var pick := _rng.randf_range(0.0, available)
	_target_left = pick if pick < before else after + pick - before


func _slider_fraction() -> float:
	return 1.0 - absf(_slider_phase - 1.0)


func _position_markers() -> void:
	var origin := ART_ORIGIN + TRACK.position * ART_SCALE
	var track_size := TRACK.size * ART_SCALE
	_target.position = origin + Vector2(_target_left * track_size.x, 0.0)
	_slider.position = origin + Vector2(_slider_fraction() * track_size.x - _slider.size.x * 0.5, (track_size.y - _slider.size.y) * 0.5)


func _update_status() -> void:
	_status.text = "CLICKS %d/%d    CONDITION %d/%d" % [_clicks, GameTuning.GARAGE_REPAIR_MAX_ATTEMPTS, PlayerState.hull, PlayerState.max_hull]


func _show_feedback(success: bool) -> void:
	var feedback := _label("Nice!" if success else "Miss!", 20, Rect2(0, 0, 160, 36))
	feedback.add_theme_color_override("font_color", Color("c4ef8a") if success else Color("ffa68f"))
	feedback.position = Vector2(_slider.position.x + _slider.size.x * 0.5 - 80.0, ART_ORIGIN.y - 12.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(feedback, "position:y", feedback.position.y - 42.0, GameTuning.GARAGE_REPAIR_FEEDBACK_SECONDS)
	tween.tween_property(feedback, "modulate:a", 0.0, GameTuning.GARAGE_REPAIR_FEEDBACK_SECONDS)
	tween.chain().tween_callback(feedback.queue_free)


func _finish() -> void:
	if not active or not _complete:
		return
	active = false
	_done.release_focus()
	hide()
	get_viewport().set_input_as_handled()
	finished.emit()


func _build_ui() -> void:
	_content = RepairFrame.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = DESIGN_SIZE
	add_child(_content)
	var title := _label("GARAGE REPAIRS", 23, Rect2(32, 28, 916, 42))
	title.add_theme_color_override("font_color", Color("e5c68a"))
	_instruction = _label("", 14, Rect2(32, 78, 916, 50))
	_instruction.add_theme_constant_override("line_spacing", 8)
	var wrench := _art(WRENCH, MAIN_SOURCE)
	wrench.position = ART_ORIGIN
	_target = _art(TARGET, TARGET_SOURCE)
	_slider = _art(SLIDER, SLIDER_SOURCE)
	_status = _label("", 14, Rect2(32, 300, 916, 32))
	_status.add_theme_color_override("font_color", RepairFrame.SECONDARY_TEXT)
	_done = Button.new()
	_done.text = "DONE"
	_done.position = Vector2((DESIGN_SIZE.x - DashboardTheme.BUTTON_SIZE.x) * 0.5, 350)
	_done.size = DashboardTheme.BUTTON_SIZE
	DashboardTheme.apply_button(_done)
	_done.pressed.connect(_finish)
	_content.add_child(_done)
	UIAudioManager.attach_button(_done)


func _label(text: String, font_size: int, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", RepairFrame.TEXT)
	label.add_theme_color_override("font_outline_color", RepairFrame.INK)
	label.add_theme_constant_override("outline_size", 3)
	_content.add_child(label)
	return label


func _art(source: Texture2D, region: Rect2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	atlas.filter_clip = true
	var art := TextureRect.new()
	art.texture = atlas
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = region.size * ART_SCALE
	_content.add_child(art)
	return art


func _layout() -> void:
	if _content == null:
		return
	var available := (size - Vector2(48, 48)).max(Vector2.ONE)
	var fit := minf(1.0, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
	_content.scale = Vector2.ONE * fit
	_content.position = (size - DESIGN_SIZE * fit) * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, BACKDROP_OPACITY))
