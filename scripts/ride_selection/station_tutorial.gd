extends RefCounted

# Introduces one station control/resource at a time before opening passengers.
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var screen
var overlay: Control
var highlight: Panel
var text_panel: Panel
var text_label: Label
var step_index := 0
var steps: Array[Dictionary] = []
var active := false
var _back_disabled := false


func _init(selection_screen) -> void:
	screen = selection_screen


func build() -> void:
	steps.clear()
	step_index = 0
	var refs := TutorialOverlayHelper.create(screen, UI_FONT, 100)
	overlay = refs.overlay
	overlay.name = "StationTutorial"
	highlight = refs.highlight
	text_panel = refs.text_panel
	text_label = refs.text_label
	steps.assign([
		{
			"text": "This shows the day and time. Your workday moves from morning to noon, then night.",
			"targets": [screen.status_header.day_label],
		},
		{
			"text": "This is your money. Earn fares to pay your debt and buy supplies.",
			"targets": [screen.status_header.stats_refs.money_label],
		},
		{
			"text": "Energy is your activity budget. Each ride or paid map visit uses %d. Rest, sleep or food restores it." % GameTuning.TRIP_ENERGY_COST,
			"targets": _resource_targets("energy"),
		},
		{
			"text": "Each ride adds %d stress; crashes add more. High stress lowers speed and handling, but never stops you driving." % GameTuning.TRIP_STRESS_GAIN,
			"targets": _resource_targets("stress"),
		},
		{
			"text": "This is tricycle condition. Crashes damage it. At 0, your ride ends and the tricycle goes for repairs.",
			"targets": _resource_targets("hull"),
		},
		{
			"text": "Gas runs down while driving. Boosting uses more. Refill at the store before the tank runs empty.",
			"targets": _resource_targets("gas"),
		},
		{
			"text": "Click your tricycle to open the town map and travel to other places.",
			"targets": [screen.station.buttons.map],
		},
		{
			"text": "This entrance leads to the store for fuel, food, repairs and upgrades.",
			"targets": [screen.station.buttons.store],
		},
		{
			"text": "Passengers wait inside the terminal. Click the highlighted building to meet them.",
			"targets": [screen.station.buttons.passengers],
			"interaction": "terminal",
		},
	])


func start() -> void:
	if active or overlay == null or steps.is_empty():
		return
	_back_disabled = screen.station_back_button.disabled
	_set_active(true)
	_show_step(0)


func advance() -> void:
	if not active:
		return
	if step_index + 1 >= steps.size():
		_end()
	else:
		_show_step(step_index + 1)


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if str(steps[step_index].get("interaction", "")) == "terminal":
		if _clicked_control(event, screen.station.buttons.passengers) or _accept_pressed(event):
			advance()
	elif _continue_pressed(event):
		advance()
	return true


func _show_step(index: int) -> void:
	step_index = clampi(index, 0, steps.size() - 1)
	var terminal_step := str(steps[step_index].get("interaction", "")) == "terminal"
	var hint := "Click the terminal, or press Enter." if terminal_step else "Click or press Enter to continue."
	text_label.text = "%s\n\n%s" % [steps[step_index].text, hint]
	_layout_for_targets()


func _layout_for_targets(targets: Array = []) -> void:
	if targets.is_empty() and not steps.is_empty():
		targets = steps[step_index].get("targets", [])
	TutorialOverlayHelper.layout_for_targets(screen, highlight, text_panel, text_label, targets)


func _set_active(value: bool) -> void:
	active = value
	TutorialOverlayHelper.set_overlay_visible(value, overlay, text_panel, text_label)
	screen.station.set_enabled(not value)
	screen.terminal_view.set_enabled(false)
	screen.station_back_button.disabled = true if value else _back_disabled


func _end() -> void:
	_set_active(false)
	screen._finish_station_tutorial()


func _resource_targets(resource_id: String) -> Array:
	var result: Array = []
	for suffix in ["_icon", "_label"]:
		var target: Variant = screen.status_header.stats_refs.get(resource_id + suffix)
		if target is Control:
			result.append(target)
	return result


func _clicked_control(event: InputEvent, control: Control) -> bool:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	var local_point: Vector2 = control.get_global_transform().affine_inverse() * event.position
	return bool(control.call("_has_point", local_point))


func _accept_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") and not event.is_echo()


func _continue_pressed(event: InputEvent) -> bool:
	return _accept_pressed(event) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
