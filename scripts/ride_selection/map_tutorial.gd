extends RefCounted

# The first completed morning ride introduces exploration without travelling.
const TutorialOverlayHelper := preload("res://scripts/ui/tutorial_overlay_helper.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const COMPLETION_EVENT := "tutorial_first_ride_map_complete"

var screen
var overlay: Control
var highlight: Panel
var text_panel: Panel
var text_label: Label
var step_index := 0
var steps: Array[Dictionary] = []
var active := false
var _back_disabled := false
var _layout_tree: SceneTree


func _init(selection_screen) -> void:
	screen = selection_screen


static func is_eligible() -> bool:
	if bool(PlayerState.get_event_value(COMPLETION_EVENT, false)):
		return false
	if PlayerState.get_current_day() != 1 or PlayerState.get_current_time_of_day() != "noon":
		return false
	var result: Dictionary = PlayerState.get_last_stage_result()
	return (
		int(result.get("day", 0)) == 1
		and str(result.get("time_of_day", "")) == "morning"
		and bool(result.get("completed", false))
	)


func build() -> void:
	step_index = 0
	var refs := TutorialOverlayHelper.create(screen, UI_FONT, 300)
	overlay = refs.overlay
	overlay.name = "FirstRideMapTutorial"
	highlight = refs.highlight
	text_panel = refs.text_panel
	text_label = refs.text_label
	_layout_tree = screen.get_tree()
	screen.tree_exiting.connect(_on_screen_tree_exiting)
	steps.assign([
		{
			"text": "Your tricycle opens the town map. Click it to see where you can go.",
			"interaction": "map",
		},
		{
			"text": "Passengers wait in more than one place. Check the Station, Market and Street for people who need a ride.",
			"locations": ["station", "market", "street"],
		},
		{
			"text": "You can visit other places, too. Going to the Park reduces stress by %d and costs %d energy." % [GameTuning.PARK_STRESS_RELIEF, GameTuning.MAP_TRAVEL_ENERGY_COST],
			"locations": ["park"],
		},
		{
			"text": "More places open as the game goes on. Keep exploring and taking passengers; you might find a new story along the way.",
		},
		{
			"text": "That wraps up the tutorial. Good luck, and have fun playing Gulong ng Buhay!",
		},
	])


func start() -> void:
	if active or overlay == null or steps.is_empty() or not is_eligible():
		return
	if screen.is_departing or screen.passenger_overlay.visible or screen.travel_map.visible:
		return
	_back_disabled = screen.station_back_button.disabled
	active = true
	screen.hub_dialogue.clear()
	screen.station.set_enabled(false)
	screen.terminal_view.set_enabled(false)
	screen.station_back_button.disabled = true
	TutorialOverlayHelper.set_overlay_visible(true, overlay, text_panel, text_label)
	_show_step(0)


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if str(steps[step_index].get("interaction", "")) == "map":
		if _clicked_tricycle(event) or _accept_pressed(event):
			screen._open_map(true)
			if screen.travel_map.visible:
				screen.travel_map.map_view.set_enabled(false)
				overlay.grab_focus()
				advance()
	elif _continue_pressed(event):
		advance()
	return true


func advance() -> void:
	if not active:
		return
	if step_index + 1 >= steps.size():
		_end()
	else:
		_show_step(step_index + 1)


func _show_step(index: int) -> void:
	step_index = clampi(index, 0, steps.size() - 1)
	var map_step := str(steps[step_index].get("interaction", "")) == "map"
	var hint := "Click the tricycle, or press Enter." if map_step else "Click or press Enter to continue."
	text_label.text = "%s\n\n%s" % [steps[step_index].text, hint]
	_layout_for_targets()
	if not _layout_tree.process_frame.is_connected(_relayout_current_step):
		_layout_tree.process_frame.connect(_relayout_current_step, CONNECT_ONE_SHOT)


func _layout_for_targets(targets: Array = []) -> void:
	if not active or not is_instance_valid(screen) or not screen.is_inside_tree():
		return
	if targets.is_empty():
		if str(steps[step_index].get("interaction", "")) == "map":
			targets = [screen.station.buttons.map]
		else:
			for location_id: String in steps[step_index].get("locations", []):
				var control: Variant = screen.travel_map.map_view.buttons.get(location_id)
				if control is Control:
					targets.append(control)
	TutorialOverlayHelper.layout_for_targets(screen, highlight, text_panel, text_label, targets)


func _relayout_current_step() -> void:
	_layout_for_targets()


func _end() -> void:
	active = false
	_disconnect_relayout()
	TutorialOverlayHelper.set_overlay_visible(false, overlay, text_panel, text_label)
	screen.station_back_button.disabled = _back_disabled
	# Leave the player on the map; closing it restores the ordinary station UI.
	screen.station.set_enabled(false)
	screen.travel_map.map_view.set_enabled(true)
	screen.travel_map.map_view.back_button.grab_focus()
	PlayerState.set_event_value(COMPLETION_EVENT, true)


func _disconnect_relayout() -> void:
	if is_instance_valid(_layout_tree) and _layout_tree.process_frame.is_connected(_relayout_current_step):
		_layout_tree.process_frame.disconnect(_relayout_current_step)


func _on_screen_tree_exiting() -> void:
	active = false
	_disconnect_relayout()
	screen = null


func _clicked_tricycle(event: InputEvent) -> bool:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	var control: Control = screen.station.buttons.map
	var local_point: Vector2 = control.get_global_transform().affine_inverse() * event.position
	return bool(control.call("_has_point", local_point))


func _accept_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") and not event.is_echo()


func _continue_pressed(event: InputEvent) -> bool:
	return _accept_pressed(event) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
