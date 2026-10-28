extends RefCounted

# Builds and advances shop onboarding while locking shop controls.


static func build_tutorial(owner) -> void:
	owner.tutorial_steps.clear()
	owner.tutorial_step_index = 0

	var refs: Dictionary = owner.TutorialOverlayHelper.create(owner, owner.UI_FONT, 200)
	owner.tutorial_overlay = refs.overlay
	owner.tutorial_highlight = refs.highlight
	owner.tutorial_text_panel = refs.text_panel
	owner.tutorial_text_label = refs.text_label

	owner.tutorial_steps.append({
		"text": "Click Lito's counter for condition repairs. You only pay for the amount repaired.",
		"targets": [owner.street.buttons["tricycle"]],
	})
	owner.tutorial_steps.append({
		"text": "His upgrades improve the engine, brakes or fuel efficiency. Each item shows its price and effect.",
		"targets": [owner.street.buttons["tricycle"]],
	})
	owner.tutorial_steps.append({
		"text": "One gas can adds %s%% fuel. The price changes each day." % String.num(PlayerState.GAS_CAN_PERCENT).trim_suffix(".0"),
		"targets": [owner.street.buttons["tricycle"]],
	})
	owner.tutorial_steps.append({
		"text": "Click Mang Eddie's counter for food. Items restore up to 2 energy, reduce stress, or do both.",
		"targets": [owner.street.buttons["food"]],
	})
	owner.tutorial_steps.append({
		"text": "Use MAP to go home or choose another location. Home and passenger pickup areas are free to visit.",
		"targets": [owner.map_button],
	})
	owner.tutorial_steps.append({
		"text": "The right exit returns to the station. This trip is free too.",
		"targets": [owner.street.buttons["station"]],
	})


static func start_tutorial(owner) -> void:
	if PlayerState.is_midnight():
		return
	if owner.tutorial_overlay == null or owner.tutorial_steps.is_empty():
		return
	if PlayerState.has_store_tutorial_shown():
		return
	PlayerState.mark_store_tutorial_shown()
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
	var controls: Array = [owner.back_button, owner.ride_button, owner.map_button]
	controls.append_array(owner.store_buy_buttons)
	owner.TutorialOverlayHelper.set_overlay_visible(is_active, owner.tutorial_overlay, owner.tutorial_text_panel, owner.tutorial_text_label)
	owner.TutorialOverlayHelper.set_buttons_disabled(is_active, controls, owner.tutorial_disabled_controls)
	owner.street.set_enabled(not is_active and not owner.shop_overlay.visible and not owner.is_transitioning)
	owner.map_button.disabled = is_active or owner.is_transitioning


static func end_tutorial(owner) -> void:
	set_tutorial_active(owner, false)


static func is_any_press(owner, event: InputEvent) -> bool:
	return owner.TutorialOverlayHelper.is_any_press(event)
