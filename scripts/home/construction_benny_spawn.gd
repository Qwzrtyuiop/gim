extends TextureButton

# Keep Benny at the position authored in the full construction-site export.
signal interacted(character_id: String)

const TEXTURE := preload("res://assets/story/backgrounds/locations/terminalspawns/bennyconstruction.png")
const DAY_BACKGROUND := preload("res://assets/story/backgrounds/locations/constructionday.png")
const ART_SIZE := Vector2(1672, 941)
const REGION := Rect2(639, 480, 102, 202)

static var _atlas: AtlasTexture
static var _mask: BitMap

var active := false
var can_interact: Callable
var _interaction_enabled := true
var _background: TextureRect


func _ready() -> void:
	name = "BennyConstructionSpawn"
	_background = get_parent() as TextureRect
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	_prepare_art()
	texture_normal = _atlas
	texture_click_mask = _mask
	_background.resized.connect(_layout_art)
	pressed.connect(_on_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_layout_art()
	set_active(false)


func set_active(value: bool) -> void:
	active = value
	visible = value
	disabled = not value or not _interaction_enabled
	if value:
		self_modulate = _background.self_modulate
		_layout_art()
	else:
		release_focus()
	set_process(value and is_visible_in_tree())


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	disabled = not value or not active
	if not value:
		release_focus()


func _process(_delta: float) -> void:
	if self_modulate != _background.self_modulate:
		self_modulate = _background.self_modulate


func _on_pressed() -> void:
	if not active or disabled or not is_visible_in_tree():
		return
	if can_interact.is_valid() and not bool(can_interact.call()):
		return
	interacted.emit("benny")


func _layout_art() -> void:
	var fit := minf(_background.size.x / ART_SIZE.x, _background.size.y / ART_SIZE.y)
	position = (_background.size - ART_SIZE * fit) * 0.5 + REGION.position * fit
	size = REGION.size * fit


func _on_visibility_changed() -> void:
	set_process(active and is_visible_in_tree())


static func _prepare_art() -> void:
	if _atlas != null:
		return
	_atlas = AtlasTexture.new()
	_atlas.filter_clip = true
	var image := TEXTURE.get_image()
	if image.is_compressed():
		image.decompress()
	var crop := image.get_region(Rect2i(REGION))
	if image.detect_alpha() == Image.ALPHA_NONE:
		# An opaque placement export includes the unchanged day background.
		# Compare only Benny's small crop, leaving the authored source intact.
		var backdrop := DAY_BACKGROUND.get_image()
		if backdrop.is_compressed():
			backdrop.decompress()
		backdrop = backdrop.get_region(Rect2i(REGION))
		crop.convert(Image.FORMAT_RGBA8)
		for y in crop.get_height():
			for x in crop.get_width():
				var pixel := crop.get_pixel(x, y)
				if pixel.is_equal_approx(backdrop.get_pixel(x, y)):
					pixel.a = 0.0
					crop.set_pixel(x, y, pixel)
		_atlas.atlas = ImageTexture.create_from_image(crop)
		_atlas.region = Rect2(Vector2.ZERO, REGION.size)
	else:
		_atlas.atlas = TEXTURE
		_atlas.region = REGION
	_mask = BitMap.new()
	_mask.create_from_image_alpha(crop, 0.7)
