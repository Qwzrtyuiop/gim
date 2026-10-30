extends Control

# Session-only presentation; the caller supplies catches already stored in PlayerState.
signal finished

const FishSpecies := preload("res://scripts/home/fishing_species_catalog.gd")
const DashboardTheme := preload("res://scripts/ui/dashboard_theme.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const PAPER := Color("f6e2b6")
const RECORD_COLOR := Color("f3c978")
const PANEL_LIMIT := Vector2(960, 640)

var active := false
var done_button: Button
var _panel: PanelContainer
var _margin: MarginContainer
var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _catches: Array[Dictionary] = []
var _compact := false


func _ready() -> void:
	name = "FishingCatchResults"
	z_index = 1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	resized.connect(_layout_panel)
	hide()
	_layout_panel()


func present(catches: Array[Dictionary]) -> void:
	_catches.assign(catches.duplicate(true))
	active = true
	_subtitle.text = "%d fish caught" % _catches.size()
	_layout_panel()
	_rebuild_cards()
	_scroll.scroll_vertical = 0
	show()
	done_button.grab_focus()
	_layout_panel.call_deferred()
	queue_redraw()


func _finish() -> void:
	if not active:
		return
	active = false
	done_button.release_focus()
	hide()
	get_viewport().set_input_as_handled()
	finished.emit()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style(Color("142b31"), Color("7b887c"), 2))
	add_child(_panel)
	_margin = MarginContainer.new()
	_panel.add_child(_margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_margin.add_child(content)
	_title = _label("YOUR CATCH", 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_subtitle = _label("", 12)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", Color("b7ccc7"))
	content.add_child(_subtitle)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)
	done_button = Button.new()
	done_button.name = "DoneFishing"
	done_button.text = "DONE"
	done_button.custom_minimum_size = Vector2(168, 44)
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DashboardTheme.apply_button(done_button)
	done_button.pressed.connect(_finish)
	content.add_child(done_button)
	UIAudioManager.attach_button(done_button)


func _rebuild_cards() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _catches.is_empty():
		var empty := _label("No fish this time.\nThere's always another cast.", 12)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.y = 100
		_list.add_child(empty)
		return
	for catch_data: Dictionary in _catches:
		_list.add_child(_catch_card(catch_data))


func _catch_card(catch_data: Dictionary) -> PanelContainer:
	var fish_id := str(catch_data.get("fish_id", ""))
	var species: Dictionary = FishSpecies.find(fish_id)
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 112 if _compact else 132
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := _panel_style(Color("203b41"), Color("50645f"), 1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20 if not _compact else 12)
	card.add_child(row)
	var picture := TextureRect.new()
	picture.texture = FishSpecies.texture_for(fish_id)
	picture.custom_minimum_size = Vector2(112, 78) if _compact else Vector2(152, 98)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_theme_constant_override("separation", 8)
	row.add_child(details)
	var fish_name := _label(str(species.get("name", "Fish")), 14)
	fish_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(fish_name)
	var length_label := _label("%.1f cm" % float(catch_data.get("length_cm", 0.0)), 14)
	length_label.add_theme_color_override("font_color", Color("c7e3da"))
	details.add_child(length_label)
	var badges := PackedStringArray()
	if bool(catch_data.get("first_catch", false)):
		badges.append("First catch")
	else:
		if bool(catch_data.get("is_largest", false)):
			badges.append("Largest caught")
		if bool(catch_data.get("is_smallest", false)):
			badges.append("Smallest caught")
	if not badges.is_empty():
		var record := _label("\n".join(badges), 10)
		record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		record.add_theme_color_override("font_color", RECORD_COLOR)
		details.add_child(record)
	return card


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PAPER)
	return label


func _panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	return style


func _layout_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var compact := size.x < 850.0 or size.y < 500.0
	var rebuild := compact != _compact and is_visible_in_tree()
	_compact = compact
	var inset := 16 if _compact else 24
	for edge in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + edge, inset)
	_title.add_theme_font_size_override("font_size", 18 if _compact else 22)
	_panel.size = (size - Vector2(48, 48)).max(Vector2.ONE).min(PANEL_LIMIT)
	_panel.position = (size - _panel.size) * 0.5
	if rebuild:
		_rebuild_cards()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.035, 0.2))
