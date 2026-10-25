extends PanelContainer

const PlayerStatsRow := preload("res://scripts/ui/player_stats_row.gd")
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CONTENT_TOP := 96.0

var day_label: Label
var stats_refs: Dictionary = {}
var display_day := 0
var display_phase := ""


func _ready() -> void:
	name = "HubStatusHeader"
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.015, 0.82)
	style.border_color = Color(0.68, 0.51, 0.30, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	day_label = Label.new()
	day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_override("font", FONT)
	day_label.add_theme_font_size_override("font_size", 16)
	day_label.add_theme_color_override("font_color", Color("faefd5"))
	content.add_child(day_label)
	stats_refs = PlayerStatsRow.create({
		"font": FONT, "font_size": 11,
		"font_color": Color("faefd5"), "outline_color": Color("181008"),
	})
	content.add_child(stats_refs["row"])
	PlayerState.money_changed.connect(_on_resource_changed)
	PlayerState.energy_changed.connect(_on_resource_changed)
	PlayerState.gas_changed.connect(_on_resource_changed)
	refresh()


func _on_resource_changed(_amount) -> void:
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
	day_label.text = "DAY %d / %s" % [day, phase.capitalize()]
	PlayerStatsRow.refresh(stats_refs)
	call_deferred("layout_in", get_parent().size)


func layout_in(viewport_size: Vector2) -> void:
	size = Vector2(maxf(460, get_combined_minimum_size().x), 74)
	position = Vector2((viewport_size.x - size.x) * 0.5, 8)
