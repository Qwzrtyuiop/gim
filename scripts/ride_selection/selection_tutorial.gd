extends RefCounted

# Explains a real locked offer without selecting or charging it until the end.
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
var _offer: Dictionary = {}
var _passenger: Control
var _layout_tree: SceneTree


func _init(selection_screen) -> void:
	screen = selection_screen


func build() -> void:
	steps.clear()
	step_index = 0
	var refs := TutorialOverlayHelper.create(screen, UI_FONT, 100)
	overlay = refs.overlay
	overlay.name = "PassengerTutorial"
	highlight = refs.highlight
	text_panel = refs.text_panel
	text_label = refs.text_label
	_layout_tree = screen.get_tree()
	if not screen.tree_exiting.is_connected(_on_screen_tree_exiting):
		screen.tree_exiting.connect(_on_screen_tree_exiting)
	_choose_preview_offer()
	var card = screen.terminal_view.info_panel
	steps.assign([
		{
			"text": "Each passenger offers a different trip. Click this passenger to inspect theirs.",
			"targets": [_passenger],
			"interaction": "inspect",
		},
		{
			"text": "The route shows the trip distance and the time of day you'll be driving.",
			"targets": [card.route_label],
		},
		{
			"text": "Traffic describes the road conditions. Busier roads need more careful driving.",
			"targets": [card.traffic_label],
		},
		{
			"text": "The estimated fare is what this trip could earn. Your driving can affect the final payout.",
			"targets": [card.fare_label],
		},
		{
			"text": "Estimated fuel shows how much gas this trip may use. Make sure you have enough.",
			"targets": [card.fuel_label],
		},
		{
			"text": "Risk sums up how demanding the trip is. Start with easier trips while you learn.",
			"targets": [card.risk_label],
		},
		{
			"text": "These are the ride's energy cost and stress gain. They apply when you start driving.",
			"targets": [card.energy_cost_label, card.stress_gain_label],
		},
		{
			"text": "Click this passenger again to review and confirm the trip. Cancel there if you want to choose someone else.",
			"targets": [_passenger],
			"interaction": "choose",
		},
	])
	if not _offer.is_empty() and not str(_offer.get("summary", {}).get("badge", "")).is_empty():
		steps.insert(3, {
			"text": "This passenger has a special trip rule. Check the badge before accepting.",
			"targets": [card.badge_label],
		})


func start() -> void:
	if active or overlay == null or steps.is_empty() or PlayerState.has_ride_select_tutorial_shown():
		return
	_choose_preview_offer()
	if _offer.is_empty() or not is_instance_valid(_passenger):
		return
	steps[0].targets = [_passenger]
	steps[steps.size() - 1].targets = [_passenger]
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
	var interaction := str(steps[step_index].get("interaction", ""))
	if interaction in ["inspect", "choose"]:
		if _clicked_passenger(event) or _accept_pressed(event):
			if interaction == "choose":
				var request := _offer.duplicate(true)
				_end()
				screen._choose_offer(str(request.get("distance", "short")), int(request.get("slot", -1)))
			else:
				advance()
	elif _continue_pressed(event):
		advance()
	return true


func _choose_preview_offer() -> void:
	_offer.clear()
	_passenger = null
	for offer: Dictionary in screen.terminal_offers:
		if str(offer.get("kind", "")) == "encounter":
			continue
		var id := str(offer.get("character", {}).get("id", ""))
		var control: Variant = screen.terminal_view.buttons.get(id)
		if control is Control:
			_offer = offer.duplicate(true)
			_passenger = control
			return


func _show_step(index: int) -> void:
	step_index = clampi(index, 0, steps.size() - 1)
	var interaction := str(steps[step_index].get("interaction", ""))
	var hint := "Click the highlighted passenger, or press Enter." if not interaction.is_empty() else "Click or press Enter to continue."
	text_label.text = "%s\n\n%s" % [steps[step_index].text, hint]
	_layout_for_targets()
	if not _layout_tree.process_frame.is_connected(_relayout_current_step):
		_layout_tree.process_frame.connect(_relayout_current_step, CONNECT_ONE_SHOT)


func _refresh_preview() -> void:
	if not active or _offer.is_empty() or not is_instance_valid(screen) or not screen.is_inside_tree():
		return
	var card = screen.terminal_view.info_panel
	if step_index == 0:
		card.hide()
		return
	card.set_summary(_offer.get("summary", {}))
	card.show()
	screen.terminal_view._layout_information()


func _relayout_current_step() -> void:
	if not active:
		return
	if not is_instance_valid(screen) or not screen.is_inside_tree():
		active = false
		_disconnect_relayout()
		return
	_layout_for_targets()


func _layout_for_targets(targets: Array = []) -> void:
	if not is_instance_valid(screen) or not screen.is_inside_tree():
		return
	_refresh_preview()
	if targets.is_empty() and not steps.is_empty():
		targets = steps[step_index].get("targets", [])
	TutorialOverlayHelper.layout_for_targets(screen, highlight, text_panel, text_label, targets)


func _set_active(value: bool) -> void:
	active = value
	TutorialOverlayHelper.set_overlay_visible(value, overlay, text_panel, text_label)
	screen.terminal_view.set_enabled(not value)


func _end() -> void:
	_disconnect_relayout()
	_set_active(false)
	PlayerState.mark_ride_select_tutorial_shown()
	screen.terminal_view._clear_focus()
	screen.station_ui.focus_passenger_controls()


func _disconnect_relayout() -> void:
	if is_instance_valid(_layout_tree) and _layout_tree.process_frame.is_connected(_relayout_current_step):
		_layout_tree.process_frame.disconnect(_relayout_current_step)


func _on_screen_tree_exiting() -> void:
	active = false
	_disconnect_relayout()
	screen = null
	_passenger = null


func _clicked_passenger(event: InputEvent) -> bool:
	if not is_instance_valid(_passenger) or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	var local_point: Vector2 = _passenger.get_global_transform().affine_inverse() * event.position
	return bool(_passenger.call("_has_point", local_point))


func _accept_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") and not event.is_echo()


func _continue_pressed(event: InputEvent) -> bool:
	return _accept_pressed(event) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)


func is_any_press(event: InputEvent) -> bool:
	return TutorialOverlayHelper.is_any_press(event)
