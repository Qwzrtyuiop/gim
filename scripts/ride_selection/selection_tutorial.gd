extends RefCounted

# Teaches terminal hover/selection and captures controls until its final step.
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var screen
var overlay: Control
var highlight: Panel
var text_panel: Panel
var text_label: Label
var step_index := 0
var steps: Array[Dictionary] = []
var active := false


func _init(selection_screen) -> void:
	screen = selection_screen


func build() -> void:
	steps.clear()
	step_index = 0
	var refs := TutorialOverlayHelper.create(screen, UI_FONT, 100)
	overlay = refs.overlay
	highlight = refs.highlight
	text_panel = refs.text_panel
	text_label = refs.text_label
	var passengers: Array = screen.terminal_view.buttons.values()
	steps.append({
		"text": "These are the passengers waiting at the terminal. Hover or focus someone to see their trip distance, fare, fuel estimate and risk.",
		"targets": passengers,
	})
	steps.append({
		"text": "Your money, energy and fuel are shown here. Starting a ride spends energy, and driving uses fuel. All offered distances appear together; each passenger has their own trip.",
		"targets": [screen.status_header],
	})
	steps.append({
		"text": "Visit the store to refuel or buy upgrades. Back returns to the station without changing the waiting passengers or spending time.",
		"targets": [screen.terminal_view.close_button, screen.terminal_view.store_button],
	})
	steps.append({
		"text": "Select a passenger to review the trip, then confirm to continue. Some passengers start a story before their ride. The opening trip stays short, in the morning, with chill traffic.",
		"targets": passengers.slice(0, 1),
	})


func start() -> void:
	if overlay == null or steps.is_empty() or PlayerState.has_ride_select_tutorial_shown():
		return
	PlayerState.mark_ride_select_tutorial_shown()
	_set_active(true)
	_show_step(0)


func advance() -> void:
	if not active:
		return
	if step_index + 1 >= steps.size():
		_end()
	else:
		_show_step(step_index + 1)


func _show_step(index: int) -> void:
	step_index = clampi(index, 0, steps.size() - 1)
	text_label.text = "%s\n\nPress any key or click to continue" % str(steps[step_index].get("text", ""))
	_layout_for_targets(steps[step_index].get("targets", []))


func _layout_for_targets(targets: Array) -> void:
	TutorialOverlayHelper.layout_for_targets(screen, highlight, text_panel, text_label, targets, false)


func _set_active(value: bool) -> void:
	active = value
	TutorialOverlayHelper.set_overlay_visible(value, overlay, text_panel, text_label)
	screen.terminal_view.set_enabled(not value)


func _end() -> void:
	_set_active(false)
	screen.station_ui.focus_passenger_controls()


func is_any_press(event: InputEvent) -> bool:
	return TutorialOverlayHelper.is_any_press(event)
