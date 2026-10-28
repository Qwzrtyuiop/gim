extends PanelContainer

const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CONTENT_TOP := 64.0
const BAR_HEIGHT := 44.0

var day_label: Label
var stats_refs: Dictionary = {}
var display_day := 0
var display_phase := ""
var _content: Node2D


func _ready() -> void:
	name = "HubStatusHeader"
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	# Keep one logical line and scale it together on small viewports. Matching
	# side reservations keep the date centered even when resource text is wider.
	_content = Node2D.new()
	add_child(_content)
	day_label = Label.new()
	day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_label.add_theme_font_override("font", FONT)
	day_label.add_theme_font_size_override("font_size", 12)
	day_label.add_theme_color_override("font_color", Color("#fff6e1"))
	day_label.add_theme_color_override("font_outline_color", Color("#392719"))
	day_label.add_theme_constant_override("outline_size", 3)
	_content.add_child(day_label)
	stats_refs = PlayerStatsRow.create({
		"font": FONT,
		"font_size": 12,
		"font_color": Color("#fff6e1"),
		"outline_color": Color(0.0, 0.0, 0.0, 0.8),
		"separation": 10,
	})
	_content.add_child(stats_refs.row)
	stats_refs.money_label.reparent(_content)
	for signal_name in ["money_changed", "energy_changed", "stress_changed", "hull_changed", "gas_changed"]:
		PlayerState.connect(signal_name, _on_resource_changed)
	refresh()


func set_display_time(day := 0, phase := "") -> void:
	# Screens previewing a trip can show its destination phase without advancing
	# the live clock. Other hub screens keep the current day/time by default.
	display_day = day
	display_phase = phase
	if is_node_ready():
		refresh()


func refresh() -> void:
	var day: int = display_day if display_day > 0 else PlayerState.get_current_day()
	var phase: String = display_phase if not display_phase.is_empty() else PlayerState.get_current_time_of_day()
	day_label.text = "DAY %d / %s" % [day, PlayerState.get_hub_time_name(day, phase)]
	PlayerStatsRow.refresh(stats_refs)
	call_deferred("layout_in", get_parent().size)


func layout_in(viewport_size: Vector2) -> void:
	var row := stats_refs.row as HBoxContainer
	var money := stats_refs.money_label as Label
	var row_size := row.get_combined_minimum_size()
	var money_size := money.get_combined_minimum_size()
	var day_size := day_label.get_combined_minimum_size()
	var required_width := maxf(row_size.x, money_size.x) * 2.0 + day_size.x + 32.0
	var available_width := maxf(1.0, viewport_size.x - 32.0)
	var fit := minf(1.0, available_width / required_width)
	var logical_width := available_width / fit
	var line_height := maxf(row_size.y, maxf(money_size.y, day_size.y))
	_content.scale = Vector2.ONE * fit
	_content.position = Vector2(16.0, (BAR_HEIGHT - line_height * fit) * 0.5)
	money.position = Vector2.ZERO
	money.size = Vector2(money_size.x, line_height)
	day_label.position = Vector2((logical_width - day_size.x) * 0.5, 0.0)
	day_label.size = Vector2(day_size.x, line_height)
	row.position = Vector2(logical_width - row_size.x, 0.0)
	row.size = Vector2(row_size.x, line_height)
	position = Vector2.ZERO
	size = Vector2(viewport_size.x, BAR_HEIGHT)


func _on_resource_changed(_amount) -> void:
	refresh()
