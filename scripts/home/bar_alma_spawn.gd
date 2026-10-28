extends Control

# Scene-local bar ambience. These full-canvas exports retain authored placement.
signal interacted(character_id: String)

const ART_SIZE := Vector2(1672, 941)
const DEFAULT_TEXTURES := [
	preload("res://assets/characters/sprites/almabar/almadefault.png"),
	preload("res://assets/characters/sprites/almabar/almadefault2.png"),
	preload("res://assets/characters/sprites/almabar/almadefault3.png"),
]
const PHONE_TEXTURE := preload("res://assets/characters/sprites/almabar/phone_from1-3.png")
const IDLE_TEXTURE := preload("res://assets/characters/sprites/almabar/almaidle2.png")
# Ignore distant faint export remnants without moving the actual character.
const DEFAULT_REGION := Rect2(367, 303, 148, 216)
const IDLE_REGION := Rect2(1170, 320, 130, 370)
const POSE_INTERVAL := 10.0
const DEFAULT_CHANGE_CHANCE := 0.65
const PHONE_CHANCE := 0.25
const PHONE_IDLE_SECONDS := 30.0
const IDLE_SECONDS := 120.0

var active := false
var pose_locked := false
var image_rect := Rect2()
var sprite_rect := Rect2()
var _texture: Texture2D
var _region := DEFAULT_REGION
var _image: Image
var _images: Dictionary = {}
var _default_index := 0
var _pose_elapsed := 0.0
var _unattended_seconds := 0.0
var _hovered := false
var _tint := Color.WHITE
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "AlmaBarSpawn"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_art)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(func() -> void: _hovered = false)
	visibility_changed.connect(_on_visibility_changed)
	set_active(false)
	_layout_art()


func set_active(value: bool) -> void:
	if active == value and _texture != null:
		return
	active = value
	_hovered = false
	_pose_elapsed = 0.0
	_unattended_seconds = 0.0
	if value:
		_default_index = _rng.randi_range(0, DEFAULT_TEXTURES.size() - 1)
		_show_default()
	visible = value
	set_process(value and is_visible_in_tree())


func set_pose_locked(value: bool) -> void:
	if pose_locked == value:
		return
	pose_locked = value
	_hovered = false
	_pose_elapsed = 0.0
	_unattended_seconds = 0.0
	if value:
		_set_sprite(IDLE_TEXTURE, IDLE_REGION)
	elif active:
		_show_default()


func _process(delta: float) -> void:
	var background := get_parent() as TextureRect
	if background != null and _tint != background.self_modulate:
		_tint = background.self_modulate
		queue_redraw()
	if pose_locked:
		return
	var pointer_over := get_viewport().gui_get_hovered_control() == self and _has_point(get_local_mouse_position())
	if pointer_over:
		if not _hovered:
			_attend(_texture != IDLE_TEXTURE)
		_hovered = true
		_unattended_seconds = 0.0
		_pose_elapsed = 0.0
		return
	_hovered = false
	_unattended_seconds += delta
	if _unattended_seconds >= IDLE_SECONDS:
		if _texture != IDLE_TEXTURE:
			_set_sprite(IDLE_TEXTURE, IDLE_REGION)
		return
	if _unattended_seconds >= PHONE_IDLE_SECONDS:
		_set_sprite(PHONE_TEXTURE, DEFAULT_REGION)
		return
	_pose_elapsed += delta
	if _pose_elapsed >= POSE_INTERVAL:
		_pose_elapsed = fmod(_pose_elapsed, POSE_INTERVAL)
		if _texture == PHONE_TEXTURE:
			_show_default()
		elif _rng.randf() < PHONE_CHANCE:
			_set_sprite(PHONE_TEXTURE, DEFAULT_REGION)
		elif _rng.randf() < DEFAULT_CHANGE_CHANCE:
			_default_index = (_default_index + _rng.randi_range(1, DEFAULT_TEXTURES.size() - 1)) % DEFAULT_TEXTURES.size()
			_show_default()


func _on_mouse_entered() -> void:
	if active and not pose_locked:
		_hovered = true
		# Keep the distant idle pose in place so its next click still hits Alma.
		_attend(_texture != IDLE_TEXTURE)


func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_attend()
		accept_event()
		interacted.emit("alma")


func _attend(restore_default := true) -> void:
	if pose_locked:
		return
	_unattended_seconds = 0.0
	_pose_elapsed = 0.0
	if restore_default:
		_show_default()


func _show_default() -> void:
	if pose_locked:
		_set_sprite(IDLE_TEXTURE, IDLE_REGION)
	else:
		_set_sprite(DEFAULT_TEXTURES[_default_index], DEFAULT_REGION)


func _set_sprite(texture: Texture2D, region: Rect2) -> void:
	if _texture == texture and _region == region:
		return
	_texture = texture
	_region = region
	# The window rain stays behind Alma when she moves to her idle spot.
	z_index = 1 if texture == IDLE_TEXTURE else 0
	if not _images.has(texture):
		_images[texture] = texture.get_image()
	_image = _images[texture]
	_layout_art()


func _has_point(point: Vector2) -> bool:
	if not active or not is_visible_in_tree() or _image == null or not sprite_rect.has_area() or not sprite_rect.has_point(point):
		return false
	var source := _region.position + (point - sprite_rect.position) / sprite_rect.size * _region.size
	var pixel := Vector2i(source)
	return _image.get_pixelv(pixel).a >= 0.7


func _layout_art() -> void:
	var ratio := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	image_rect = Rect2((size - ART_SIZE * ratio) * 0.5, ART_SIZE * ratio)
	sprite_rect = Rect2(image_rect.position + _region.position * ratio, _region.size * ratio)
	queue_redraw()


func _on_visibility_changed() -> void:
	_hovered = false
	set_process(active and is_visible_in_tree())


func _draw() -> void:
	if _texture != null:
		draw_texture_rect_region(_texture, sprite_rect, _region, _tint)
