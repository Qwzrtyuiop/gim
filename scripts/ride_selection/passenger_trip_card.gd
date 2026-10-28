extends PanelContainer

# Shared presentation for a passenger's hover preview and confirmation summary.
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GameTuning := preload("res://scripts/config/game_tuning.gd")
const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const STRESS_ICON := preload("res://assets/ui/icons/stress_brain.png")
const CREAM := Color("faefd5")
const MUTED := Color("b8ab92")
const GOLD := Color("dfba78")

var name_label: Label
var route_label: Label
var traffic_label: Label
var badge_label: Label
var fare_label: Label
var fuel_label: Label
var risk_label: Label
var energy_cost_label: Label
var stress_gain_label: Label
var _badge_panel: PanelContainer
var _metrics: HBoxContainer
var _divider: HSeparator
var _resource_costs: HBoxContainer
var _built := false


func _ready() -> void:
	_build()


func set_summary(summary: Dictionary) -> void:
	_build()
	name_label.text = str(summary.get("name", ""))
	var distance := str(summary.get("distance", ""))
	var phase := str(summary.get("phase", ""))
	var route: Array[String] = []
	if not distance.is_empty():
		route.append(distance.capitalize() + " trip")
	if not phase.is_empty():
		route.append(phase.capitalize())
	route_label.text = " / ".join(route)
	var traffic := str(summary.get("traffic", ""))
	traffic_label.text = "Traffic: " + traffic.capitalize() if not traffic.is_empty() else ""
	badge_label.text = str(summary.get("badge", "")).to_upper()
	_badge_panel.visible = not badge_label.text.is_empty()
	var encounter := str(summary.get("kind", "")) == "encounter"
	_metrics.visible = not encounter
	_divider.visible = not encounter
	_resource_costs.visible = not encounter and not summary.is_empty()
	traffic_label.visible = not encounter
	if encounter:
		route_label.text = phase.capitalize() + " / " + str(summary.get("description", ""))
	fare_label.text = str(summary.get("fare", ""))
	fuel_label.text = str(summary.get("fuel", ""))
	risk_label.text = str(summary.get("risk", "")).to_upper()
	var risk_color := CREAM
	match risk_label.text:
		"LOW":
			risk_color = Color("b6d598")
		"MODERATE":
			risk_color = Color("edc77e")
		"HIGH":
			risk_color = Color("f19a86")
	risk_label.add_theme_color_override("font_color", risk_color)
	energy_cost_label.text = "Energy -%d" % int(summary.get("energy_cost", GameTuning.TRIP_ENERGY_COST))
	stress_gain_label.text = "Stress +%d" % int(summary.get("stress_gain", GameTuning.TRIP_STRESS_GAIN))


func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.043, 0.030, 0.97)
	style.border_color = Color("a58a5f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 20)
	content.add_child(heading)
	name_label = _label(16, CREAM)
	name_label.name = "PassengerName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(name_label)
	_badge_panel = PanelContainer.new()
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("483620")
	badge_style.border_color = Color("b78f52")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(3)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 5
	badge_style.content_margin_bottom = 5
	_badge_panel.add_theme_stylebox_override("panel", badge_style)
	heading.add_child(_badge_panel)
	badge_label = _label(9, GOLD)
	badge_label.name = "TripSpecial"
	_badge_panel.add_child(badge_label)
	_badge_panel.hide()
	var route := HBoxContainer.new()
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route.add_theme_constant_override("separation", 20)
	content.add_child(route)
	route_label = _label(10, MUTED)
	route_label.name = "TripRoute"
	route_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route.add_child(route_label)
	traffic_label = _label(10, MUTED)
	traffic_label.name = "TripTraffic"
	traffic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	route.add_child(traffic_label)
	var divider := HSeparator.new()
	_divider = divider
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := StyleBoxLine.new()
	line.color = Color(0.65, 0.54, 0.37, 0.45)
	line.thickness = 1
	divider.add_theme_stylebox_override("separator", line)
	content.add_child(divider)
	var metrics := HBoxContainer.new()
	_metrics = metrics
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics.add_theme_constant_override("separation", 24)
	content.add_child(metrics)
	fare_label = _metric(metrics, "EST. FARE", "EstimatedFare")
	fuel_label = _metric(metrics, "EST. FUEL", "EstimatedFuel")
	risk_label = _metric(metrics, "RISK", "TripRisk")
	var cost_refs := create_resource_cost_row()
	_resource_costs = cost_refs.row
	_resource_costs.name = "TripResourceCosts"
	energy_cost_label = cost_refs.energy_label
	stress_gain_label = cost_refs.stress_label
	content.add_child(_resource_costs)


static func create_resource_cost_row(with_caption := false) -> Dictionary:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	if with_caption:
		var caption := _label(9, MUTED)
		caption.text = "Per ride:"
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_outline_color", Color("181008"))
		caption.add_theme_constant_override("outline_size", 2)
		row.add_child(caption)
	var refs := {"row": row}
	for entry in [
		{"id": "energy", "texture": ENERGY_ICON, "text": "Energy -%d" % GameTuning.TRIP_ENERGY_COST, "color": GOLD},
		{"id": "stress", "texture": STRESS_ICON, "text": "Stress +%d" % GameTuning.TRIP_STRESS_GAIN, "color": Color("eea4b6")},
	]:
		var pair := HBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 6)
		row.add_child(pair)
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = entry.texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(icon)
		var value := _label(10, entry.color)
		value.text = entry.text
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_color_override("font_outline_color", Color("181008"))
		value.add_theme_constant_override("outline_size", 2)
		pair.add_child(value)
		refs[entry.id + "_label"] = value
	return refs


func _metric(parent: HBoxContainer, caption: String, value_name: String) -> Label:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	var label := _label(9, MUTED)
	label.text = caption
	column.add_child(label)
	var value := _label(14, CREAM)
	value.name = value_name
	column.add_child(value)
	return value


static func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
