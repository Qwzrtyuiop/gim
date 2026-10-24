extends RefCounted

# Owns the passenger-selection tutorial and temporarily captures its controls.

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
var disabled_buttons: Dictionary = {}
var card_filters: Dictionary = {}


func _init(selection_screen) -> void:
	screen = selection_screen


func build() -> void:
	steps.clear()
	step_index = 0

	var refs := TutorialOverlayHelper.create(screen, UI_FONT)
	overlay = refs.overlay
	highlight = refs.highlight
	text_panel = refs.text_panel
	text_label = refs.text_label

	steps.append({
		"text": "These are your passengers. Each card is a possible rider.",
		"targets": [screen.card_a, screen.card_b, screen.card_c],
	})
	steps.append({
		"text": "Below are the stage information and estimated earnings for the trip.",
		"targets": [screen.card_a_label, screen.card_b_label, screen.card_c_label],
	})
	steps.append({
		"text": "Choose the trip distance here.",
		"targets": [screen.short_button, screen.medium_button, screen.long_button],
	})
	var stats_row := screen.view.stats_row_refs.get("row") as Control
	var stats_targets := [stats_row] if stats_row != null else [screen.status_label]
	steps.append({
		"text": "Money buys upgrades and items. Energy is spent when starting a ride; if it hits 0 you cannot start. Gas starts at %s%%, drains as you drive, and burns faster while boosting." % String.num(PlayerState.DEFAULT_STARTING_GAS_PERCENT).trim_suffix(".0"),
		"targets": stats_targets,
	})
	steps.append({
		"text": "Your status and trip notes appear here.",
		"targets": [screen.status_label],
	})
	steps.append({
		"text": "For the opening ride, start with this passenger. It keeps the first trip simple while you learn the road.",
		"targets": [screen.card_a],
	})
	steps.append({
		"text": "Stage information is written as distance, time, then modifier. In short-morning-chill, Short means the ride distance.",
		"targets": [screen.card_a_label],
	})
	steps.append({
		"text": "Morning tells you the time of day for this ride.",
		"targets": [screen.card_a_label],
	})
	steps.append({
		"text": "Chill is the modifier. It means this route should have lighter traffic and a calmer pace.",
		"targets": [screen.card_a_label],
	})


func start() -> void:
	if overlay == null or steps.is_empty():
		return
	if PlayerState.has_ride_select_tutorial_shown():
		return
	PlayerState.mark_ride_select_tutorial_shown()
	_set_active(true)
	_show_step(0)


func advance() -> void:
	if not active:
		return
	var next_index := step_index + 1
	if next_index >= steps.size():
		_end()
		return
	_show_step(next_index)


func _show_step(new_step_index: int) -> void:
	step_index = clampi(new_step_index, 0, steps.size() - 1)
	var step: Dictionary = steps[step_index]
	text_label.text = "%s\n\nPress any key or click to continue" % str(step.get("text", ""))
	text_label.visible = true
	_layout_for_targets(step.get("targets", []))


func _layout_for_targets(targets: Array) -> void:
	TutorialOverlayHelper.layout_for_targets(screen, highlight, text_panel, text_label, targets, false)


func _set_active(is_active: bool) -> void:
	active = is_active
	var buttons := [screen.back_button, screen.view.store_button, screen.short_button, screen.medium_button, screen.long_button]
	TutorialOverlayHelper.set_overlay_visible(is_active, overlay, text_panel, text_label)
	TutorialOverlayHelper.set_buttons_disabled(is_active, buttons, disabled_buttons)
	TutorialOverlayHelper.set_mouse_filter(is_active, [screen.card_a, screen.card_b, screen.card_c], card_filters, Control.MOUSE_FILTER_IGNORE)


func _end() -> void:
	_set_active(false)


func is_any_press(event: InputEvent) -> bool:
	return TutorialOverlayHelper.is_any_press(event)
