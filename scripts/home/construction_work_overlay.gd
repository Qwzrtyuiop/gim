extends Control

# Reuse the repair panel's layout and dot cadence for the work transition.
signal finished

const GameTuning := preload("res://scripts/config/game_tuning.gd")
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const DOT_INTERVAL_SECONDS := 0.5
const VIEWPORT_MARGIN := Vector2(48, 48)

var active := false
var _dot_count := 1
var _elapsed := 0.0
var _dot_elapsed := 0.0

@onready var title_label: Label = $Center/Panel/Content/Title
@onready var continue_button: Button = $Center/Panel/Content/Continue
@onready var panel: PanelContainer = $Center/Panel
@onready var center: CenterContainer = $Center


func _ready() -> void:
	z_index = 400
	process_mode = Node.PROCESS_MODE_PAUSABLE
	$Background.color = Color(0.035, 0.045, 0.055, 0.96)
	$Center/Panel/Content/Tricycle.hide()
	$Center/Panel/Content/Duration.text = "CONSTRUCTION WORK"
	$Center/Panel/Content/Balance.text = "One phase passes while you help Benny's crew."
	continue_button.pressed.connect(_finish)
	ButtonGlow.attach(self, continue_button)
	resized.connect(_layout_panel)
	panel.minimum_size_changed.connect(_layout_panel)
	_layout_panel()
	hide()
	set_process(false)


func present(receipt: Dictionary) -> void:
	if active or receipt.is_empty():
		return
	active = true
	_elapsed = 0.0
	_dot_elapsed = 0.0
	_dot_count = 1
	_update_title()
	$Center/Panel/Content/Bill.text = "+PhP %d   /   -%d ENERGY" % [int(receipt.get("pay", 0)), int(receipt.get("energy_cost", 0))]
	$Center/Panel/Content/NextDay.text = "DAY %d / %s" % [int(receipt.get("day", 1)), str(receipt.get("phase_after", ""))]
	continue_button.hide()
	continue_button.disabled = true
	show()
	_layout_panel()
	_layout_panel.call_deferred()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_dot_elapsed += delta
	if _dot_elapsed >= DOT_INTERVAL_SECONDS:
		_dot_elapsed = fmod(_dot_elapsed, DOT_INTERVAL_SECONDS)
		_dot_count = _dot_count % 3 + 1
		_update_title()
	if _elapsed >= GameTuning.CONSTRUCTION_WORK_PRESENTATION_SECONDS:
		title_label.text = "WORK COMPLETE"
		continue_button.show()
		continue_button.disabled = false
		continue_button.grab_focus()
		_layout_panel.call_deferred()
		set_process(false)


func _finish() -> void:
	if not active or continue_button.disabled:
		return
	active = false
	get_viewport().set_input_as_handled()
	hide()
	finished.emit()


func _update_title() -> void:
	title_label.text = "WORKING" + ".".repeat(_dot_count).rpad(3, " ")


func _layout_panel() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	# Fit the actual content in its own canvas. Scaling a full-rect anchored
	# container makes its offsets and minimum size fight the viewport layout.
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var content_size := panel.get_combined_minimum_size().max(Vector2.ONE)
	var available := (size - VIEWPORT_MARGIN).max(Vector2.ONE)
	var fit := minf(1.0, minf(available.x / content_size.x, available.y / content_size.y))
	center.size = content_size
	center.scale = Vector2.ONE * fit
	center.position = (size - content_size * fit) * 0.5
