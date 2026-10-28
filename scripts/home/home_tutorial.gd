extends RefCounted

# Builds and advances home onboarding while locking room controls.


static func build_tutorial(owner) -> void:
	owner.tutorial_steps.clear()
	owner.tutorial_step_index = 0

	var refs: Dictionary = owner.TutorialOverlayHelper.create(owner, owner.UI_FONT, 200)
	owner.tutorial_overlay = refs.overlay
	owner.tutorial_highlight = refs.highlight
	owner.tutorial_text_panel = refs.text_panel
	owner.tutorial_text_label = refs.text_label

	owner.tutorial_steps.assign([
		{"text": "This is home. The room's objects let you check information or rest.", "targets": [owner.header_label]},
		{"text": "The radio reports today's news, gas prices and weather forecast.", "targets": [owner.house.buttons["radio"]]},
		{"text": "The calendar shows your weekly payment target and the next collection date.", "targets": [owner.house.buttons["calendar"]]},
		{"text": "Rest gives +2 energy and -2 stress. At night, sleep restores energy and starts a new day.", "targets": [owner.house.buttons["rest"]]},
		{"text": "Use MAP when you're ready to leave home.", "targets": [owner.map_button]},
	])


static func start_tutorial(owner) -> void:
	if owner.tutorial_overlay == null or owner.tutorial_steps.is_empty():
		return
	if PlayerState.has_home_tutorial_shown():
		return
	PlayerState.mark_home_tutorial_shown()
	set_tutorial_active(owner, true)
	show_tutorial_step(owner, 0)


static func advance_tutorial(owner) -> void:
	if not owner.tutorial_active:
		return
	var next_index = owner.tutorial_step_index + 1
	if next_index >= owner.tutorial_steps.size():
		end_tutorial(owner)
		return
	show_tutorial_step(owner, next_index)


static func show_tutorial_step(owner, step_index: int) -> void:
	owner.tutorial_step_index = clampi(step_index, 0, owner.tutorial_steps.size() - 1)
	var step: Dictionary = owner.tutorial_steps[owner.tutorial_step_index]
	owner.tutorial_text_label.text = "%s\n\nClick or press any key to continue" % str(step.get("text", ""))
	owner.tutorial_text_label.visible = true
	layout_tutorial_for_targets(owner, step.get("targets", []))


static func layout_tutorial_for_targets(owner, targets: Array) -> void:
	owner.TutorialOverlayHelper.layout_for_targets(owner, owner.tutorial_highlight, owner.tutorial_text_panel, owner.tutorial_text_label, targets)


static func set_tutorial_active(owner, is_active: bool) -> void:
	owner.tutorial_active = is_active
	owner.TutorialOverlayHelper.set_overlay_visible(is_active, owner.tutorial_overlay, owner.tutorial_text_panel, owner.tutorial_text_label)
	owner.house.set_enabled(not is_active)


static func end_tutorial(owner) -> void:
	set_tutorial_active(owner, false)


static func is_any_press(owner, event: InputEvent) -> bool:
	return owner.TutorialOverlayHelper.is_any_press(event)
