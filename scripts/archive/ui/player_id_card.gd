extends Control

# Source-pixel regions follow the supplied full card, including John's photo.
const FRAME := preload("res://assets/archive/ui/id_card/IDfull.png")
const FONT := preload("res://assets/fonts/PixelifySans-wght.ttf")
const ENERGY_ICON := preload("res://assets/ui/icons/energy_lightning.svg")
const STRESS_ICON := preload("res://assets/ui/icons/stress_brain.png")
const HULL_ICON := preload("res://assets/ui/icons/hull_shield.svg")
const GAS_ICON := preload("res://assets/ui/icons/gas_pump.svg")
const SOURCE_REGION := Rect2(37, 78, 1564, 837)
const PHOTO_REGION := Rect2(104, 176, 446, 521)
const DESIGN_SIZE := Vector2(451, 241)
const COLLAPSED_VISIBLE_HEIGHT := 28.0
const SLIDE_SECONDS := 0.22
const FRAME_TINT := Color("#d8c8ac")
const RESOURCE_COLORS := {
	"energy": Color("#e6ba43"),
	"stress": Color("#d57499"),
	"hull": Color("#72a977"),
	"gas": Color("#639bb7"),
}
const RESOURCES := ["energy", "stress", "hull", "gas"]

var name_label: Label
var portrait: TextureRect
var money_label: Label
var bars: Dictionary = {}
var labels: Dictionary = {}
var stats_refs: Dictionary = {}
var expanded_position := Vector2.ZERO
var _slide_distance := 0.0
var _reveal_amount := 0.0
var _expanded := false
var _slide_tween: Tween


func _ready() -> void:
	name = "PlayerIDCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(set_expanded.bind(true))
	mouse_exited.connect(set_expanded.bind(false))
	visibility_changed.connect(_on_visibility_changed)
	size = DESIGN_SIZE
	var frame_atlas := AtlasTexture.new()
	frame_atlas.atlas = FRAME
	frame_atlas.region = SOURCE_REGION
	frame_atlas.filter_clip = true
	var frame := _texture(frame_atlas, Rect2(Vector2.ZERO, DESIGN_SIZE))
	frame.self_modulate = FRAME_TINT
	# IDfull already contains the photo. Redraw its exact region without the
	# paper tint so the supplied portrait retains its original colors.
	var portrait_atlas := AtlasTexture.new()
	portrait_atlas.atlas = FRAME
	portrait_atlas.region = PHOTO_REGION
	portrait_atlas.filter_clip = true
	portrait = _texture(portrait_atlas, Rect2(
		(PHOTO_REGION.position - SOURCE_REGION.position) / SOURCE_REGION.size * DESIGN_SIZE,
		PHOTO_REGION.size / SOURCE_REGION.size * DESIGN_SIZE,
	))
	name_label = _label("Toda, John A.", Rect2(20, 191, 128, 29), 20)
	name_label.add_theme_color_override("font_color", Color("#392719"))
	name_label.add_theme_constant_override("outline_size", 0)
	var icons := [ENERGY_ICON, STRESS_ICON, HULL_ICON, GAS_ICON]
	for index in range(RESOURCES.size()):
		var id: String = RESOURCES[index]
		var y := 31.0 + index * 40.7
		_texture(icons[index], Rect2(160, y - 1, 29, 27))
		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		bar.step = 0.01
		var background_style := StyleBoxFlat.new()
		background_style.bg_color = Color(0.19, 0.13, 0.09, 0.55)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = RESOURCE_COLORS[id]
		bar.add_theme_stylebox_override("background", background_style)
		bar.add_theme_stylebox_override("fill", fill_style)
		bar.position = Vector2(199, y)
		bar.size = Vector2(225, 24)
		add_child(bar)
		bars[id] = bar
		labels[id] = _label("", Rect2(bar.position, bar.size), 18)
	money_label = _label("", Rect2(249, 201, 178, 23), 18)
	money_label.add_theme_color_override("font_color", Color("#392719"))
	money_label.add_theme_constant_override("outline_size", 0)
	stats_refs = {
		"row": self,
		"money_label": money_label,
		"energy_label": labels.energy,
		"stress_label": labels.stress,
		"hull_label": labels.hull,
		"gas_label": labels.gas,
	}
	for signal_name in ["money_changed", "energy_changed", "stress_changed", "hull_changed", "gas_changed"]:
		PlayerState.connect(signal_name, _on_resource_changed)
	refresh()


static func display_scale(viewport_size: Vector2) -> float:
	return clampf(minf(viewport_size.x / 1672.0, viewport_size.y / 941.0), 0.60, 0.90)


static func reserved_rect(viewport_size: Vector2) -> Rect2:
	var displayed := DESIGN_SIZE * display_scale(viewport_size)
	return Rect2(Vector2(0, viewport_size.y - displayed.y), displayed)


func layout_in(viewport_size: Vector2, parent_origin := Vector2.ZERO) -> void:
	var rect := reserved_rect(viewport_size)
	scale = Vector2.ONE * display_scale(viewport_size)
	expanded_position = rect.position - parent_origin
	_slide_distance = maxf(0.0, rect.size.y - COLLAPSED_VISIBLE_HEIGHT)
	_apply_reveal(_reveal_amount)


func set_expanded(expanded: bool, animate := true) -> void:
	var target := 1.0 if expanded else 0.0
	if _expanded == expanded and is_equal_approx(_reveal_amount, target):
		return
	_expanded = expanded
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if not animate or not is_inside_tree():
		_apply_reveal(target)
		return
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_apply_reveal, _reveal_amount, target, SLIDE_SECONDS)


func _apply_reveal(amount: float) -> void:
	_reveal_amount = amount
	position = expanded_position + Vector2(0.0, _slide_distance * (1.0 - amount))


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		set_expanded(false, false)


func refresh() -> void:
	if money_label == null:
		return
	var values := [float(PlayerState.energy), float(PlayerState.stress), float(PlayerState.hull), PlayerState.gas]
	var totals := [float(PlayerState.max_energy), float(PlayerState.max_stress), float(PlayerState.max_hull), PlayerState.max_gas]
	for index in range(RESOURCES.size()):
		var id: String = RESOURCES[index]
		bars[id].max_value = totals[index]
		bars[id].value = values[index]
		labels[id].text = "%.1f/%.1f" % [values[index], totals[index]] if id == "gas" else "%d/%d" % [values[index], totals[index]]
	money_label.text = str(PlayerState.money)
	var money_width := FONT.get_string_size(money_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	money_label.add_theme_font_size_override("font_size", mini(18, floori(18.0 * 171.0 / maxf(171.0, money_width))))


func _on_resource_changed(_amount) -> void:
	refresh()


func _texture(texture: Texture2D, rect: Rect2) -> TextureRect:
	var widget := TextureRect.new()
	# Set the sizing policy first: assigning a large texture otherwise expands
	# the control to its source dimensions before its minimum size is removed.
	widget.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	widget.texture = texture
	widget.position = rect.position
	widget.size = rect.size
	widget.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(widget)
	return widget


func _label(text: String, rect: Rect2, font_size: int) -> Label:
	var widget := Label.new()
	widget.text = text
	widget.position = rect.position
	widget.size = rect.size
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	widget.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	widget.add_theme_font_override("font", FONT)
	widget.add_theme_font_size_override("font_size", font_size)
	widget.add_theme_color_override("font_color", Color("#fff6e1"))
	widget.add_theme_color_override("font_outline_color", Color("#392719"))
	widget.add_theme_constant_override("outline_size", 2)
	add_child(widget)
	return widget
