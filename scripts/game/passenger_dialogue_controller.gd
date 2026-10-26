extends RefCounted
class_name PassengerDialogueController

const GameFlowController := preload("res://scripts/game/game_flow_controller.gd")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const UI_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CATEGORY_GO_FASTER := "go_faster"
const CATEGORY_HURRY_UP := "hurry_up"
const CATEGORY_CAREFUL := "careful"
const CATEGORY_SPECIAL := "special"
const BUBBLE_WIDTH := 300.0
const BUBBLE_HEIGHT := 78.0
const BUBBLE_MARGIN := 12.0
const BASE_DISPLAY_SECONDS := 2.2
const MAX_DISPLAY_SECONDS := 3.8

var ui_root: CanvasLayer
var bubble_root: Control
var bubble_panel: PanelContainer
var bubble_label: Label
var bubble_tail: ColorRect
var bubble_tail_shadow: ColorRect
var time_remaining: float = 0.0
var cooldown_remaining: float = 1.8
var special_cooldown_remaining: float = 11.0
var recent_lane_change_timer: float = 0.0
var last_player_lane: int = 1
var current_text: String = ""


func setup(owner, target_ui_root: CanvasLayer) -> void:
	ui_root = target_ui_root
	if ui_root == null:
		return

	bubble_root = Control.new()
	bubble_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_root.visible = false
	ui_root.add_child(bubble_root)

	bubble_panel = PanelContainer.new()
	bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_root.add_child(bubble_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	panel_style.border_color = Color(0.96, 0.92, 0.78, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	bubble_panel.add_theme_stylebox_override("panel", panel_style)

	bubble_label = Label.new()
	bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble_label.add_theme_font_override("font", UI_FONT)
	bubble_label.add_theme_font_size_override("font_size", 12)
	bubble_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90, 1.0))
	bubble_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	bubble_label.add_theme_constant_override("outline_size", 2)
	bubble_panel.add_child(bubble_label)

	bubble_tail_shadow = ColorRect.new()
	bubble_tail_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_tail_shadow.color = Color(0.08, 0.08, 0.10, 0.92)
	bubble_tail_shadow.rotation = deg_to_rad(45.0)
	bubble_root.add_child(bubble_tail_shadow)

	bubble_tail = ColorRect.new()
	bubble_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_tail.color = Color(0.96, 0.92, 0.78, 0.96)
	bubble_tail.rotation = deg_to_rad(45.0)
	bubble_root.add_child(bubble_tail)

	last_player_lane = owner.player_lane
	layout(owner)


func update(owner, delta: float) -> void:
	if not GameTuning.PASSENGER_MESSAGES_ENABLED:
		clear()
		return
	if bubble_root == null:
		return

	layout(owner)
	_update_timers(owner, delta)
	_update_visibility()

	if owner.player_lane != last_player_lane:
		last_player_lane = owner.player_lane
		recent_lane_change_timer = 1.4

	if owner.game_state != "playing":
		return
	if owner.stage_tutorial != null and (owner.stage_tutorial.active or owner.stage_tutorial.input_lock_active):
		return
	if time_remaining > 0.0 or cooldown_remaining > 0.0:
		return

	var category: String = _choose_category(owner)
	if category.is_empty():
		return

	var line_data: Dictionary = _resolve_line_data(owner, category)
	var line_text: String = str(line_data.get("text", ""))
	if line_text.is_empty():
		return

	_show_line(owner, category, line_data)


func layout(owner) -> void:
	if bubble_root == null or owner.player == null or not is_instance_valid(owner.player):
		return

	var bubble_size: Vector2 = Vector2(BUBBLE_WIDTH, BUBBLE_HEIGHT)
	bubble_root.size = bubble_size
	bubble_panel.position = Vector2.ZERO
	bubble_panel.size = bubble_size
	bubble_label.position = Vector2(BUBBLE_MARGIN, 8.0)
	bubble_label.size = bubble_size - Vector2(BUBBLE_MARGIN * 2.0, 18.0)

	var tail_size: Vector2 = Vector2(14.0, 14.0)
	var tail_position: Vector2 = Vector2(bubble_size.x * 0.5 - 7.0, bubble_size.y - 3.0)
	bubble_tail_shadow.position = tail_position + Vector2(1.0, 1.0)
	bubble_tail_shadow.size = tail_size
	bubble_tail.position = tail_position
	bubble_tail.size = tail_size

	var viewport_size: Vector2 = owner.get_viewport_rect().size
	var player_canvas_position: Vector2 = owner.player.get_global_transform_with_canvas().origin
	var vertical_offset: float = 74.0 + maxf(0.0, owner.player.scale.y * 14.0)
	var target_position: Vector2 = Vector2(
		player_canvas_position.x - bubble_size.x * 0.5,
		player_canvas_position.y - bubble_size.y - vertical_offset
	)
	target_position.x = clampf(target_position.x, 12.0, maxf(12.0, viewport_size.x - bubble_size.x - 12.0))
	target_position.y = clampf(target_position.y, 12.0, maxf(12.0, viewport_size.y - bubble_size.y - 18.0))
	bubble_root.position = target_position


func clear() -> void:
	time_remaining = 0.0
	current_text = ""
	if bubble_root != null:
		bubble_root.visible = false
		bubble_root.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _update_timers(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if special_cooldown_remaining > 0.0:
		special_cooldown_remaining = maxf(0.0, special_cooldown_remaining - delta)
	if recent_lane_change_timer > 0.0:
		recent_lane_change_timer = maxf(0.0, recent_lane_change_timer - delta)
	if time_remaining > 0.0:
		time_remaining = maxf(0.0, time_remaining - delta)
	elif owner.game_state != "playing":
		clear()


func _update_visibility() -> void:
	if bubble_root == null:
		return
	if time_remaining <= 0.0:
		bubble_root.visible = false
		return

	bubble_root.visible = true
	var fade_alpha: float = 1.0
	if time_remaining < 0.24:
		fade_alpha = clampf(time_remaining / 0.24, 0.0, 1.0)
	bubble_root.modulate = Color(1.0, 1.0, 1.0, fade_alpha)


func _choose_category(owner) -> String:
	var dialogue_pool: Dictionary = PlayerState.get_current_mock_character_session_dialogue(_dialogue_context(owner))
	var speed_kmh: int = GameFlowController.current_speed_kmh(owner)
	var elapsed_seconds: float = owner.time_limit - owner.time_left + owner.overtime_seconds
	var elapsed_ratio: float = clampf(elapsed_seconds / maxf(1.0, owner.time_limit), 0.0, 2.0)
	var progress_ratio: float = clampf(owner.distance / maxf(1.0, owner.target_distance), 0.0, 2.0)
	var is_behind_schedule: bool = progress_ratio + 0.14 < elapsed_ratio
	var urgent_window: bool = owner.time_left <= maxf(7.0, owner.time_limit * 0.14) or owner.overtime_seconds > 0.25
	var stage_special_type: String = PlayerState.normalize_stage_special_type(owner.stage_special_type)

	if special_cooldown_remaining <= 0.0 and _has_dialogue(dialogue_pool, CATEGORY_SPECIAL) and owner.rng.randf() < 0.16:
		return CATEGORY_SPECIAL
	if stage_special_type == PlayerState.STAGE_SPECIAL_TYPE_URGENT and is_behind_schedule and urgent_window and speed_kmh <= 34 and _has_dialogue(dialogue_pool, CATEGORY_HURRY_UP):
		return CATEGORY_HURRY_UP
	if stage_special_type == PlayerState.STAGE_SPECIAL_TYPE_URGENT and is_behind_schedule and speed_kmh <= 42 and _has_dialogue(dialogue_pool, CATEGORY_GO_FASTER):
		return CATEGORY_GO_FASTER
	if stage_special_type == PlayerState.STAGE_SPECIAL_TYPE_CAREFUL and owner.boost_active and speed_kmh >= 50 and _has_dialogue(dialogue_pool, CATEGORY_CAREFUL):
		if owner.rng.randf() < 0.58:
			return CATEGORY_CAREFUL
	if special_cooldown_remaining <= 0.0 and _has_dialogue(dialogue_pool, CATEGORY_SPECIAL):
		return CATEGORY_SPECIAL
	return ""


func _resolve_line_data(owner, category: String) -> Dictionary:
	var dialogue_pool: Dictionary = PlayerState.get_current_mock_character_session_dialogue(_dialogue_context(owner))
	var entries: Variant = dialogue_pool.get(category, [])
	if not entries is Array or (entries as Array).is_empty():
		return {}

	var localized_key: String = "tagalog" if StoryLanguageManager.is_tagalog() else "english"
	if _has_ordered_session_entries(entries as Array):
		for entry in entries:
			var candidate_text: String = _localized_dialogue_text(entry, localized_key)
			if candidate_text.is_empty():
				continue
			return _build_line_data(entry, candidate_text)
		return {}

	var shuffled_entries: Array = (entries as Array).duplicate(true)
	for index in range(shuffled_entries.size() - 1, 0, -1):
		var swap_index: int = owner.rng.randi_range(0, index)
		var temporary_entry = shuffled_entries[index]
		shuffled_entries[index] = shuffled_entries[swap_index]
		shuffled_entries[swap_index] = temporary_entry

	for entry in shuffled_entries:
		var candidate_text: String = _localized_dialogue_text(entry, localized_key)
		if candidate_text.is_empty():
			continue
		if candidate_text == current_text and shuffled_entries.size() > 1:
			continue
		return _build_line_data(entry, candidate_text)

	return _build_line_data(shuffled_entries[0], _localized_dialogue_text(shuffled_entries[0], localized_key))


func _show_line(owner, category: String, line_data: Dictionary) -> void:
	if bubble_label == null:
		return
	var line_text: String = str(line_data.get("text", ""))
	if line_text.is_empty():
		return
	current_text = line_text
	bubble_label.text = line_text
	time_remaining = clampf(BASE_DISPLAY_SECONDS + float(line_text.length()) * 0.018, BASE_DISPLAY_SECONDS, MAX_DISPLAY_SECONDS)

	match category:
		CATEGORY_HURRY_UP:
			cooldown_remaining = owner.rng.randf_range(6.0, 8.2)
		CATEGORY_GO_FASTER, CATEGORY_CAREFUL:
			cooldown_remaining = owner.rng.randf_range(5.0, 7.0)
		CATEGORY_SPECIAL:
			cooldown_remaining = owner.rng.randf_range(7.0, 10.0)
			special_cooldown_remaining = owner.rng.randf_range(15.0, 22.0)
		_:
			cooldown_remaining = owner.rng.randf_range(5.0, 7.0)

	if _is_rule_violation_category(owner, category):
		owner.passenger_rule_violation_count += 1
	if bool(line_data.get("once", false)):
		PlayerState.consume_unique_session_dialogue(str(line_data.get("entry_id", "")))

	_update_visibility()
	layout(owner)


func _dialogue_context(owner) -> Dictionary:
	return {
		"stage_type": owner.stage_type,
		"difficulty": owner.stage_difficulty,
		"time_of_day": owner.stage_time_of_day,
		"traffic": owner.stage_traffic,
	}


func _has_dialogue(dialogue_pool: Dictionary, category: String) -> bool:
	var entries: Variant = dialogue_pool.get(category, [])
	return entries is Array and not (entries as Array).is_empty()


func _is_rule_violation_category(owner, category: String) -> bool:
	var stage_special_type: String = PlayerState.normalize_stage_special_type(owner.stage_special_type)
	if stage_special_type == PlayerState.STAGE_SPECIAL_TYPE_URGENT:
		return category == CATEGORY_GO_FASTER or category == CATEGORY_HURRY_UP
	if stage_special_type == PlayerState.STAGE_SPECIAL_TYPE_CAREFUL:
		return category == CATEGORY_CAREFUL
	return false


func _localized_dialogue_text(entry, localized_key: String) -> String:
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		return str(entry_dict.get(localized_key, entry_dict.get("english", ""))).strip_edges()
	return str(entry).strip_edges()


func _build_line_data(entry: Variant, text: String) -> Dictionary:
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		return {
			"text": text,
			"entry_id": str(entry_dict.get("_session_dialogue_id", "")),
			"once": bool(entry_dict.get("_session_dialogue_once", false)),
		}
	return {
		"text": text,
		"entry_id": "",
		"once": false,
	}


func _has_ordered_session_entries(entries: Array) -> bool:
	for entry in entries:
		if entry is Dictionary and bool((entry as Dictionary).get("_session_dialogue_ordered", false)):
			return true
	return false
