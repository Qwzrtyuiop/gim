extends Control

const NEXT_STAGE_SCENE := "res://scenes/main.tscn"
const DAY_START_SCENE := "res://scenes/day_start_transition.tscn"
const HOUSE_DAY_START_SCENE := "res://scenes/day_start_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const FALLBACK_SCENE := "res://scenes/main_menu.tscn"
const STORE_SCENE := "res://scenes/store.tscn"
const ButtonGlow := preload("res://scripts/ui/button_glow.gd")
const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GENERIC_PORTRAIT := preload("res://assets/characters/blankface.png")
const EMPTY_CARD_CHANCE := 0.28
const RIDE_SELECT_BGM_PATH := "res://assets/stagebgm/normalstage1.mp3"

@onready var subtitle_label: Label = $Panel/Subtitle
@onready var status_label: Label = $Panel/StatusLabel
@onready var money_label: Label = $Panel/MoneyLabel
@onready var back_button: BaseButton = $Panel/BackButton
@onready var back_label: Label = $Panel/BackButton/BackLabel
@onready var short_button: BaseButton = $Panel/ShortButton
@onready var medium_button: BaseButton = $Panel/MediumButton
@onready var long_button: BaseButton = $Panel/LongButton
@onready var card_a: Panel = $Panel/CardA
@onready var card_b: Panel = $Panel/CardB
@onready var card_c: Panel = $Panel/CardC
@onready var card_a_label: Label = $Panel/CardA/CardALabel
@onready var card_b_label: Label = $Panel/CardB/CardBLabel
@onready var card_c_label: Label = $Panel/CardC/CardCLabel
@onready var portrait_a_panel: Panel = $Panel/CardA/PortraitA
@onready var portrait_b_panel: Panel = $Panel/CardB/PortraitB
@onready var portrait_c_panel: Panel = $Panel/CardC/PortraitC

var pending_trip_selection: Dictionary = {}
var rng := RandomNumberGenerator.new()
var selected_distance := "short"
var locked_character_pools: Dictionary = {}
var displayed_characters: Array[Dictionary] = []
var stats_row_refs: Dictionary = {}
var portrait_images: Array[TextureRect] = []
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_text_panel: Panel
var tutorial_text_label: Label
var tutorial_step_index := 0
var tutorial_steps: Array[Dictionary] = []
var tutorial_active := false
var tutorial_disabled_buttons: Dictionary = {}
var tutorial_card_filters: Dictionary = {}
var bgm_player: AudioStreamPlayer


func _ready() -> void:
	PlayerState.set_resume_scene("res://scenes/ride_selection.tscn")
	rng.randomize()
	pending_trip_selection = PlayerState.get_pending_trip_selection()
	selected_distance = PlayerState.get_locked_pending_trip_distance()
	if selected_distance.is_empty():
		selected_distance = "short"
	if _is_forced_first_day_ride():
		selected_distance = "short"
	back_button.visible = _allow_back()
	_create_stats_row()

	back_button.pressed.connect(_handle_back_button_pressed)
	short_button.pressed.connect(_set_distance.bind("short"))
	medium_button.pressed.connect(_set_distance.bind("medium"))
	long_button.pressed.connect(_set_distance.bind("long"))
	card_a.gui_input.connect(_on_card_gui_input.bind(0))
	card_b.gui_input.connect(_on_card_gui_input.bind(1))
	card_c.gui_input.connect(_on_card_gui_input.bind(2))

	for label in [card_a_label, card_b_label, card_c_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for button in [back_button, short_button, medium_button, long_button]:
		ButtonGlow.attach(self, button)

	_create_portrait_images()
	_start_ride_select_bgm()

	locked_character_pools = PlayerState.get_locked_pending_trip_character_pools()
	if locked_character_pools.is_empty():
		locked_character_pools = _roll_character_pools()
		PlayerState.lock_pending_trip_selection(locked_character_pools, selected_distance)

	_refresh_header()
	_refresh_action_button()
	_set_distance(selected_distance)
	if _show_store_shortcut():
		back_button.grab_focus()
	else:
		match selected_distance:
			"medium":
				medium_button.grab_focus()
			"long":
				long_button.grab_focus()
			_:
				short_button.grab_focus()

	_build_tutorial()
	if not PlayerState.has_ride_select_tutorial_shown():
		call_deferred("_start_tutorial")


func _unhandled_input(event: InputEvent) -> void:
	if tutorial_active:
		if event is InputEventMouseButton and event.pressed:
			_advance_tutorial()
			return
		if _is_any_press(event):
			_advance_tutorial()
		return
	if event.is_action_pressed("ui_cancel") and PauseMenuManager.request_toggle():
		return
	if event.is_action_pressed("ui_cancel") and _allow_back():
		_go_back()


func _refresh_header() -> void:
	var display_day := PlayerState.get_transition_display_day(_transition_mode())
	_refresh_stats_row()
	money_label.text = PlayerState.get_debt_status_text(display_day)


func _refresh_subtitle() -> void:
	var transition_mode := _transition_mode()
	var energy_bonus := PlayerState.get_transition_energy_bonus(transition_mode)
	var next_time := PlayerState.get_next_stage_time(transition_mode).capitalize()
	var bonus_text := " Recovery: +%d energy." % energy_bonus if energy_bonus > 0 else ""
	var route_phrase := "Choose a %s route for the %s trip.%s" if transition_mode == PlayerState.TRANSITION_CURRENT_STAGE else "Choose a %s route for the next %s trip.%s"
	subtitle_label.text = route_phrase % [
		selected_distance.capitalize(),
		next_time,
		bonus_text,
	]


func _set_distance(difficulty: String) -> void:
	selected_distance = "short" if _is_forced_first_day_ride() else difficulty
	displayed_characters = _get_pool_for_distance(selected_distance)
	PlayerState.lock_pending_trip_selection(locked_character_pools, selected_distance)
	_refresh_subtitle()
	_refresh_distance_buttons()
	_refresh_character_cards()
	if _show_store_shortcut():
		status_label.text = "Out of gas. Visit the store to refuel before Day %d begins." % _display_day()
	else:
		status_label.text = "Choose a passenger for a %s trip." % difficulty.capitalize()


func _refresh_distance_buttons() -> void:
	for button_data in [
		{"button": short_button, "id": "short"},
		{"button": medium_button, "id": "medium"},
		{"button": long_button, "id": "long"},
	]:
		var button := button_data["button"] as BaseButton
		var button_id: String = str(button_data["id"])
		var is_selected: bool = button_id == selected_distance
		button.disabled = is_selected or (_is_forced_first_day_ride() and button_id != "short")
		ButtonGlow.set_state(self, button, is_selected)


func _refresh_character_cards() -> void:
	var card_nodes := [
		{"panel": card_a, "label": card_a_label, "portrait": portrait_images[0]},
		{"panel": card_b, "label": card_b_label, "portrait": portrait_images[1]},
		{"panel": card_c, "label": card_c_label, "portrait": portrait_images[2]},
	]

	for index in range(card_nodes.size()):
		var character: Dictionary = displayed_characters[index]
		var panel := card_nodes[index]["panel"] as Panel
		var label := card_nodes[index]["label"] as Label
		var portrait := card_nodes[index]["portrait"] as TextureRect
		if character.is_empty():
			panel.modulate = Color(0.92, 0.92, 0.92, 0.52)
			label.text = "EMPTY SLOT\nNo one available yet."
			if portrait != null:
				portrait.visible = false
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			continue

		var preview_stage_type := _preview_stage_type(character)
		panel.modulate = Color.WHITE
		label.text = "%s\nStage Information:\n%s\nEstimated Earnings:\nPhP %d" % [
			str(character["name"]).to_upper(),
			preview_stage_type,
			PlayerState.estimate_stage_earnings(preview_stage_type),
		]
		if portrait != null:
			portrait.visible = true
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _roll_character_pools() -> Dictionary:
	for _attempt in range(24):
		var seeded_setup := PlayerState.get_seeded_rider_pool_setup(_build_seed_selection_context())
		var rolled_pools := _roll_character_pools_once(false, seeded_setup)
		if _has_distance_coverage(rolled_pools):
			PlayerState.consume_seeded_rider_rules(seeded_setup.get("rule_ids", []))
			return rolled_pools

	var fallback_seeded_setup := PlayerState.get_seeded_rider_pool_setup(_build_seed_selection_context())
	var fallback_pools := _roll_character_pools_once(true, fallback_seeded_setup)
	PlayerState.consume_seeded_rider_rules(fallback_seeded_setup.get("rule_ids", []))
	return fallback_pools


func _roll_character_pools_once(force_first_appearance_unlocks: bool, seeded_setup: Dictionary = {}) -> Dictionary:
	var character_pools: Dictionary = {}
	var used_ids: Dictionary = {}
	var first_appearance_rolls := _build_first_appearance_rolls(force_first_appearance_unlocks)
	var seeded_distance_slots: Dictionary = Dictionary(seeded_setup.get("distance_slots", {}))

	for distance_variant in _ordered_distances_for_generation():
		var distance := str(distance_variant)
		character_pools[distance] = _build_distance_pool(
			distance,
			used_ids,
			first_appearance_rolls,
			force_first_appearance_unlocks,
			Array(seeded_distance_slots.get(distance, []))
		)

	return character_pools


func _build_distance_pool(distance: String, used_ids: Dictionary, first_appearance_rolls: Dictionary, force_first_appearance_unlocks: bool, seeded_assignments: Array = []) -> Array[Dictionary]:
	var card_results: Array[Dictionary] = [{}, {}, {}]
	var has_seeded_character := false

	for assignment_variant in seeded_assignments:
		if not assignment_variant is Dictionary:
			continue
		var assignment: Dictionary = assignment_variant
		var seeded_character: Dictionary = assignment.get("character", {})
		var character_id := str(seeded_character.get("id", ""))
		var slot_index := int(assignment.get("slot", -1))
		if slot_index < 0 or slot_index >= card_results.size():
			continue
		if seeded_character.is_empty() or character_id.is_empty() or used_ids.has(character_id):
			continue
		used_ids[character_id] = true
		has_seeded_character = true
		card_results[slot_index] = _lock_character_for_selection(
			seeded_character,
			distance,
			str(assignment.get("forced_traffic", ""))
		)

	if not has_seeded_character:
		var guaranteed_character := _pick_character_for_distance(
			distance,
			used_ids,
			first_appearance_rolls,
			force_first_appearance_unlocks
		)
		if not guaranteed_character.is_empty():
			used_ids[str(guaranteed_character["id"])] = true
			var first_open_slot := _find_first_empty_card_slot(card_results)
			if first_open_slot >= 0:
				card_results[first_open_slot] = _lock_character_for_selection(guaranteed_character, distance)

	for slot_index in range(card_results.size()):
		if not (card_results[slot_index] as Dictionary).is_empty():
			continue
		if slot_index > 0 and rng.randf() < EMPTY_CARD_CHANCE:
			continue

		var filler := _pick_character_for_distance(
			distance,
			used_ids,
			first_appearance_rolls,
			force_first_appearance_unlocks
		)
		if filler.is_empty():
			continue

		used_ids[str(filler["id"])] = true
		card_results[slot_index] = _lock_character_for_selection(filler, distance)

	return card_results


func _pick_character_for_distance(distance: String, used_ids: Dictionary, first_appearance_rolls: Dictionary, force_first_appearance_unlocks: bool) -> Dictionary:
	var unseen_candidates: Array[Dictionary] = []
	var seen_candidates: Array[Dictionary] = []

	for character_data in PlayerState.get_mock_characters():
		var character: Dictionary = character_data
		var character_id := str(character.get("id", ""))
		if used_ids.has(character_id):
			continue

		var is_seen := PlayerState.has_seen_mock_character(character_id)
		if is_seen:
			if _supports_distance_in_selection(character, distance, false):
				seen_candidates.append(character)
			continue

		if not _supports_distance_in_selection(character, distance, true):
			continue
		if not force_first_appearance_unlocks and not bool(first_appearance_rolls.get(character_id, false)):
			continue
		unseen_candidates.append(character)

	if not unseen_candidates.is_empty():
		unseen_candidates.shuffle()
		return unseen_candidates[0]
	if not seen_candidates.is_empty():
		seen_candidates.shuffle()
		return seen_candidates[0]
	return {}


func _build_first_appearance_rolls(force_first_appearance_unlocks: bool) -> Dictionary:
	var first_appearance_rolls: Dictionary = {}
	for character_data in PlayerState.get_mock_characters():
		var character: Dictionary = character_data
		var character_id := str(character.get("id", ""))
		if PlayerState.has_seen_mock_character(character_id):
			continue
		first_appearance_rolls[character_id] = force_first_appearance_unlocks or rng.randf() <= float(character.get("first_appearance_chance", 1.0))
	return first_appearance_rolls


func _ordered_distances_for_generation() -> Array[String]:
	var ordered_distances: Array[String] = []
	if PlayerState.gas <= 4:
		ordered_distances.append("short")
	if not ordered_distances.has(selected_distance):
		ordered_distances.append(selected_distance)
	for difficulty_variant in PlayerState.STAGE_DIFFICULTIES:
		var difficulty := str(difficulty_variant)
		if not ordered_distances.has(difficulty):
			ordered_distances.append(difficulty)
	return ordered_distances


func _has_distance_coverage(character_pools: Dictionary) -> bool:
	for difficulty_variant in PlayerState.STAGE_DIFFICULTIES:
		var difficulty := str(difficulty_variant)
		if _count_non_empty_cards(character_pools.get(difficulty, [])) <= 0:
			return false
	return true


func _count_non_empty_cards(card_results: Array) -> int:
	var count := 0
	for card_variant in card_results:
		var card: Dictionary = card_variant as Dictionary
		if not card.is_empty():
			count += 1
	return count


func _supports_distance_in_selection(character: Dictionary, distance: String, is_first_appearance: bool) -> bool:
	if is_first_appearance:
		return str(character.get("first_distance", "")) == distance

	var eligible_distances: Array = character.get("eligible_distances", [])
	return eligible_distances.has(distance)


func _lock_character_for_selection(picked_character: Dictionary, active_distance: String, forced_traffic: String = "") -> Dictionary:
	var was_seen_before_roll := PlayerState.has_seen_mock_character(str(picked_character["id"]))
	PlayerState.mark_mock_character_seen(str(picked_character["id"]))
	var locked_character: Dictionary = picked_character.duplicate(true)
	locked_character["active_distance"] = active_distance
	var selected_traffic := forced_traffic.strip_edges().to_lower()
	if _is_forced_first_day_ride():
		selected_traffic = "chill"
	if not PlayerState.STAGE_TRAFFIC_TYPES.has(selected_traffic):
		selected_traffic = PlayerState.get_random_stage_traffic_type()
	locked_character["stage_traffic"] = selected_traffic
	locked_character["is_first_appearance"] = not was_seen_before_roll
	return locked_character


func _find_first_empty_card_slot(card_results: Array[Dictionary]) -> int:
	for slot_index in range(card_results.size()):
		if (card_results[slot_index] as Dictionary).is_empty():
			return slot_index
	return -1


func _build_seed_selection_context() -> Dictionary:
	return {
		"day": PlayerState.get_transition_display_day(_transition_mode()),
		"time_of_day": PlayerState.get_next_stage_time(_transition_mode()),
		"current_day": PlayerState.get_current_day(),
		"current_time_of_day": PlayerState.get_current_time_of_day(),
		"current_stage_type": PlayerState.get_current_stage_type(),
	}


func _build_tutorial() -> void:
	tutorial_steps.clear()
	tutorial_step_index = 0

	tutorial_overlay = Control.new()
	tutorial_overlay.anchor_right = 1.0
	tutorial_overlay.anchor_bottom = 1.0
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.focus_mode = Control.FOCUS_ALL
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)

	var backdrop := ColorRect.new()
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.add_child(backdrop)

	tutorial_highlight = Panel.new()
	tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_highlight.z_index = 1
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	highlight_style.border_color = Color(0.98, 0.92, 0.68, 0.95)
	highlight_style.set_border_width_all(3)
	highlight_style.set_corner_radius_all(8)
	tutorial_highlight.add_theme_stylebox_override("panel", highlight_style)
	tutorial_overlay.add_child(tutorial_highlight)

	tutorial_text_panel = Panel.new()
	tutorial_text_panel.z_index = 2
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.06, 0.92)
	panel_style.border_color = Color(0.82, 0.66, 0.40, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	tutorial_text_panel.add_theme_stylebox_override("panel", panel_style)
	tutorial_overlay.add_child(tutorial_text_panel)

	tutorial_text_label = _make_tutorial_label()
	tutorial_text_label.anchor_right = 1.0
	tutorial_text_label.anchor_bottom = 1.0
	tutorial_text_label.offset_left = 12.0
	tutorial_text_label.offset_top = 10.0
	tutorial_text_label.offset_right = -12.0
	tutorial_text_label.offset_bottom = -10.0
	tutorial_text_panel.add_child(tutorial_text_label)

	tutorial_steps.append({
		"text": "These are your passengers. Each card is a possible rider.",
		"targets": [card_a, card_b, card_c],
	})
	tutorial_steps.append({
		"text": "Below are the stage information and estimated earnings for the trip.",
		"targets": [card_a_label, card_b_label, card_c_label],
	})
	tutorial_steps.append({
		"text": "Choose the trip distance here.",
		"targets": [short_button, medium_button, long_button],
	})
	var stats_row := stats_row_refs.get("row") as Control
	var stats_targets := [stats_row] if stats_row != null else [money_label]
	tutorial_steps.append({
		"text": "Money buys upgrades and items. Energy is spent when starting a ride; if it hits 0 you cannot start. Gas is consumed per trip, so refuel when it runs low. Additionally, gas consumed depends on the distance of the trip",
		"targets": stats_targets,
	})
	tutorial_steps.append({
		"text": "Your status and trip notes appear here.",
		"targets": [money_label, status_label],
	})
	tutorial_steps.append({
		"text": "For the opening ride, start with this passenger. It keeps the first trip simple while you learn the road.",
		"targets": [card_a],
	})
	tutorial_steps.append({
		"text": "Stage information is written as distance, time, then modifier. In short-morning-chill, Short means the ride distance.",
		"targets": [card_a_label],
	})
	tutorial_steps.append({
		"text": "Morning tells you the time of day for this ride.",
		"targets": [card_a_label],
	})
	tutorial_steps.append({
		"text": "Chill is the modifier. It means this route should have lighter traffic and a calmer pace.",
		"targets": [card_a_label],
	})


func _start_tutorial() -> void:
	if tutorial_overlay == null or tutorial_steps.is_empty():
		return
	if PlayerState.has_ride_select_tutorial_shown():
		return
	PlayerState.mark_ride_select_tutorial_shown()
	_set_tutorial_active(true)
	_show_tutorial_step(0)


func _advance_tutorial() -> void:
	if not tutorial_active:
		return
	var next_index := tutorial_step_index + 1
	if next_index >= tutorial_steps.size():
		_end_tutorial()
		return
	_show_tutorial_step(next_index)


func _show_tutorial_step(step_index: int) -> void:
	tutorial_step_index = clampi(step_index, 0, tutorial_steps.size() - 1)
	var step: Dictionary = tutorial_steps[tutorial_step_index]
	tutorial_text_label.text = "%s\n\nPress any key to continue" % str(step.get("text", ""))
	tutorial_text_label.visible = true
	_layout_tutorial_for_targets(step.get("targets", []))


func _layout_tutorial_for_targets(targets: Array) -> void:
	var rect := _union_global_rect(targets)
	var label_size := Vector2(620.0, 88.0)
	if tutorial_text_label != null:
		var text_len := tutorial_text_label.text.length()
		if text_len > 180:
			label_size.y = 170.0
		elif text_len > 120:
			label_size.y = 140.0
	if rect.size == Vector2.ZERO:
		tutorial_highlight.visible = false
		if tutorial_text_panel != null:
			tutorial_text_panel.size = label_size
		var fallback_pos := Vector2(
			(get_viewport_rect().size.x - label_size.x) * 0.5,
			120.0
		)
		if tutorial_text_panel != null:
			tutorial_text_panel.global_position = fallback_pos
		return

	var padding := 14.0
	rect.position -= Vector2(padding, padding)
	rect.size += Vector2(padding * 2.0, padding * 2.0)
	tutorial_highlight.visible = true
	tutorial_highlight.global_position = rect.position
	tutorial_highlight.size = rect.size

	var label_pos := rect.position + Vector2((rect.size.x - label_size.x) * 0.5, rect.size.y + 16.0)
	if label_pos.y + label_size.y > get_viewport_rect().size.y - 12.0:
		label_pos.y = rect.position.y - label_size.y - 16.0
	label_pos.y = maxf(label_pos.y, 12.0)
	label_pos.x = clampf(label_pos.x, 20.0, get_viewport_rect().size.x - label_size.x - 20.0)
	if tutorial_text_panel != null:
		tutorial_text_panel.size = label_size
		tutorial_text_panel.global_position = label_pos


func _union_global_rect(targets: Array) -> Rect2:
	var has_rect := false
	var rect := Rect2()
	for target in targets:
		var control := target as Control
		if control == null:
			continue
		var target_rect := control.get_global_rect()
		if not has_rect:
			rect = target_rect
			has_rect = true
		else:
			rect = rect.merge(target_rect)
	return rect


func _set_tutorial_active(is_active: bool) -> void:
	tutorial_active = is_active
	if tutorial_overlay != null:
		tutorial_overlay.visible = is_active
		if is_active:
			tutorial_overlay.grab_focus()
	if tutorial_text_panel != null:
		tutorial_text_panel.visible = is_active
	if tutorial_text_label != null:
		tutorial_text_label.visible = is_active

	var buttons := [back_button, short_button, medium_button, long_button]
	if is_active:
		tutorial_disabled_buttons.clear()
		for button in buttons:
			if button == null:
				continue
			tutorial_disabled_buttons[button] = button.disabled
			button.disabled = true

		tutorial_card_filters.clear()
		for panel in [card_a, card_b, card_c]:
			if panel == null:
				continue
			tutorial_card_filters[panel] = panel.mouse_filter
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		for button in tutorial_disabled_buttons.keys():
			if button == null:
				continue
			button.disabled = bool(tutorial_disabled_buttons.get(button, false))
		tutorial_disabled_buttons.clear()

		for panel in tutorial_card_filters.keys():
			if panel == null:
				continue
			panel.mouse_filter = int(tutorial_card_filters.get(panel, panel.mouse_filter))
		tutorial_card_filters.clear()


func _end_tutorial() -> void:
	_set_tutorial_active(false)


func _make_tutorial_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _start_ride_select_bgm() -> void:
	if bgm_player != null and is_instance_valid(bgm_player):
		return
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "RideSelectBGMPlayer"
	bgm_player.stream = load(RIDE_SELECT_BGM_PATH)
	bgm_player.autoplay = false
	bgm_player.bus = &"Master"
	add_child(bgm_player)
	AudioSettingsManager.register_player(bgm_player, "music")
	bgm_player.play()


func _is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _create_portrait_images() -> void:
	portrait_images = []
	for panel in [portrait_a_panel, portrait_b_panel, portrait_c_panel]:
		portrait_images.append(_ensure_portrait_image(panel))


func _ensure_portrait_image(panel: Panel) -> TextureRect:
	if panel == null:
		return null

	var portrait := panel.get_node_or_null("PortraitImage") as TextureRect
	if portrait == null:
		portrait = TextureRect.new()
		portrait.name = "PortraitImage"
		portrait.anchor_right = 1.0
		portrait.anchor_bottom = 1.0
		portrait.offset_left = 0.0
		portrait.offset_top = 0.0
		portrait.offset_right = 0.0
		portrait.offset_bottom = 0.0
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(portrait)

	portrait.texture = GENERIC_PORTRAIT
	return portrait


func _get_pool_for_distance(distance: String) -> Array[Dictionary]:
	var locked_pool: Array = locked_character_pools.get(distance, [])
	var card_results: Array[Dictionary] = []
	for card_variant in locked_pool:
		var card := card_variant as Dictionary
		card_results.append(card)
	while card_results.size() < 3:
		card_results.append({})
	return card_results


func _on_card_gui_input(event: InputEvent, card_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_character(card_index)


func _preview_stage_type(character: Dictionary) -> String:
	if _is_forced_first_day_ride():
		return PlayerState.FIRST_STAGE_TYPE
	return PlayerState.build_stage_type(
		str(character.get("active_distance", selected_distance)),
		PlayerState.get_next_stage_time(_transition_mode()),
		str(character.get("stage_traffic", "chill"))
	)


func _choose_character(card_index: int) -> void:
	if card_index < 0 or card_index >= displayed_characters.size():
		return

	var character: Dictionary = displayed_characters[card_index]
	if character.is_empty():
		status_label.text = "That slot is empty."
		return

	var transition_mode := _transition_mode()
	var applied_bonus := PlayerState.apply_transition_energy_bonus(transition_mode)
	var stage_distance := "short" if _is_forced_first_day_ride() else selected_distance
	var stage_traffic := "chill" if _is_forced_first_day_ride() else str(character.get("stage_traffic", ""))

	if not PlayerState.prepare_stage_start(stage_distance):
		if applied_bonus > 0:
			PlayerState.add_energy(-applied_bonus)
		var start_error := PlayerState.get_stage_start_error(stage_distance)
		if _show_store_shortcut() and start_error == "Not enough gas for this trip.":
			status_label.text = "Not enough gas for this trip. Visit the store to refuel."
		else:
			status_label.text = start_error
		return

	PlayerState.set_current_mock_character(str(character.get("id", "")))
	var should_show_day_start_transition := PlayerState.will_advance_day(transition_mode) and PlayerState.get_transition_display_day(transition_mode) <= 1
	PlayerState.advance_to_next_stage(
		transition_mode,
		stage_distance,
		stage_traffic
	)
	PlayerState.clear_pending_trip_selection()
	if PlayerState.is_run_failed():
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	var target_scene := DAY_START_SCENE if should_show_day_start_transition else NEXT_STAGE_SCENE
	if str(pending_trip_selection.get("return_scene", "")) == HOUSE_DAY_START_SCENE:
		target_scene = NEXT_STAGE_SCENE
	get_tree().change_scene_to_file(target_scene)


func _go_back() -> void:
	if not _allow_back():
		return

	var return_scene := str(pending_trip_selection.get("return_scene", FALLBACK_SCENE))
	get_tree().change_scene_to_file(return_scene if not return_scene.is_empty() else FALLBACK_SCENE)


func _handle_back_button_pressed() -> void:
	if _show_store_shortcut():
		get_tree().change_scene_to_file(STORE_SCENE)
		return
	_go_back()


func _transition_mode() -> String:
	var transition_mode := str(pending_trip_selection.get("transition_mode", ""))
	if transition_mode.is_empty():
		if bool(pending_trip_selection.get("skip_to_night", false)):
			return PlayerState.TRANSITION_REST_TO_NIGHT
		return PlayerState.TRANSITION_RIDE
	return PlayerState.normalize_transition_mode(transition_mode)


func _is_forced_first_day_ride() -> bool:
	return (
		PlayerState.get_current_day() == 1
		and int(PlayerState.stage_round) <= 0
		and _transition_mode() == PlayerState.TRANSITION_CURRENT_STAGE
	)


func _allow_back() -> bool:
	return bool(pending_trip_selection.get("allow_back", true))


func _display_day() -> int:
	return PlayerState.get_transition_display_day(_transition_mode())


func _can_open_store_from_selection() -> bool:
	return _display_day() >= 2 and PlayerState.gas <= 0


func _show_store_shortcut() -> bool:
	return not _allow_back() and _can_open_store_from_selection()


func _refresh_action_button() -> void:
	back_button.visible = _allow_back() or _show_store_shortcut()
	back_label.text = "STORE" if _show_store_shortcut() else "BACK"


func _create_stats_row() -> void:
	stats_row_refs = PlayerStatsRow.create({
		"font": UI_FONT,
		"font_size": 10,
		"font_color": Color(0.30, 0.19, 0.10, 1.0),
		"outline_color": Color(0.98, 0.94, 0.83, 0.86),
	})
	var stats_row := stats_row_refs["row"] as HBoxContainer
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.layout_mode = 1
	stats_row.offset_left = 90.0
	stats_row.offset_top = 118.0
	stats_row.offset_right = 1064.0
	stats_row.offset_bottom = 144.0
	$Panel.add_child(stats_row)


func _refresh_stats_row() -> void:
	if stats_row_refs.is_empty():
		return

	PlayerStatsRow.refresh(stats_row_refs)
