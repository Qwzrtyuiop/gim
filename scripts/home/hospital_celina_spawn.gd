extends TextureButton

# Full-canvas exports retain their authored hospital placement and occlusion.
signal interacted(character_id: String)

const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const ART_SIZE := Vector2(1672, 941)
const POSES := {
	"default1": {
		"texture": preload("res://assets/characters/sprites/celinahosp/default1.png"),
		"region": Rect2(794, 335, 95, 142),
	},
	"default2": {
		"texture": preload("res://assets/characters/sprites/celinahosp/default2.png"),
		"region": Rect2(786, 335, 110, 136),
	},
	"busy": {
		"texture": preload("res://assets/characters/sprites/celinahosp/busy.png"),
		"region": Rect2(486, 311, 168, 358),
	},
	"idle": {
		"texture": preload("res://assets/characters/sprites/celinahosp/idle.png"),
		"region": Rect2(276, 311, 106, 258),
	},
}
const DEFAULT_POSES := ["default1", "default2"]
const POSE_INTERVAL := 10.0
const BUSY_CHANCE := 0.25
const IDLE_SECONDS := 30.0

static var _atlases: Dictionary = {}
static var _masks: Dictionary = {}

var active := false
var interaction_override: Callable
var _background: TextureRect
var _dialogue: HubDialogue
var _pose := "default1"
var _pose_elapsed := 0.0
var _unattended_seconds := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "CelinaHospitalSpawn"
	_background = get_parent() as TextureRect
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	_rng.randomize()
	_prepare_art()
	_background.resized.connect(_layout_art)
	pressed.connect(_on_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_set_pose(_pose)
	set_active(false)


func setup_dialogue(dialogue: HubDialogue) -> void:
	_dialogue = dialogue
	_dialogue.register_control("hospital:cel", self)


func set_active(value: bool) -> void:
	active = value
	_pose_elapsed = 0.0
	_unattended_seconds = 0.0
	if value:
		_show_default()
		self_modulate = _background.self_modulate
	else:
		release_focus()
	disabled = not value
	visible = value
	set_process(value and is_visible_in_tree())


func _process(delta: float) -> void:
	if self_modulate != _background.self_modulate:
		self_modulate = _background.self_modulate
	# Keep distant poses in place on hover so they can still be clicked.
	if _pointer_over() or (_dialogue != null and _dialogue.blocks_input()):
		_pose_elapsed = 0.0
		_unattended_seconds = 0.0
		return
	_unattended_seconds += delta
	if _unattended_seconds >= IDLE_SECONDS:
		_set_pose("idle")
		return
	_pose_elapsed += delta
	if _pose_elapsed >= POSE_INTERVAL:
		_pose_elapsed = fmod(_pose_elapsed, POSE_INTERVAL)
		if _pose == "busy" or _pose == "idle":
			_show_default()
		elif _rng.randf() < BUSY_CHANCE:
			_set_pose("busy")
		else:
			_set_pose("default2" if _pose == "default1" else "default1")


func _on_pressed() -> void:
	if not active or not is_visible_in_tree() or _dialogue == null or _dialogue.blocks_input():
		return
	_pose_elapsed = 0.0
	_unattended_seconds = 0.0
	_show_default()
	if interaction_override.is_valid() and bool(interaction_override.call("cel")):
		return
	_dialogue.say("...", {
		"target": "hospital:cel",
		"character_id": "cel",
		"duration": 2.5,
	})
	interacted.emit("cel")


func _show_default() -> void:
	_set_pose(DEFAULT_POSES[_rng.randi_range(0, DEFAULT_POSES.size() - 1)])


func _pointer_over() -> bool:
	if get_viewport().gui_get_hovered_control() != self:
		return false
	var point := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	var pixel := Vector2i(point / size * Vector2(texture_click_mask.get_size()))
	return texture_click_mask.get_bitv(pixel)


func _set_pose(pose: String) -> void:
	_pose = pose
	texture_normal = _atlases[pose]
	texture_click_mask = _masks[pose]
	_layout_art()


func _layout_art() -> void:
	var fit := minf(_background.size.x / ART_SIZE.x, _background.size.y / ART_SIZE.y)
	var region: Rect2 = POSES[_pose]["region"]
	position = (_background.size - ART_SIZE * fit) * 0.5 + region.position * fit
	size = region.size * fit


func _on_visibility_changed() -> void:
	set_process(active and is_visible_in_tree())


static func _prepare_art() -> void:
	if not _atlases.is_empty():
		return
	for pose: String in POSES:
		var texture: Texture2D = POSES[pose]["texture"]
		var region: Rect2 = POSES[pose]["region"]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		atlas.filter_clip = true
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		var mask := BitMap.new()
		mask.create_from_image_alpha(image.get_region(Rect2i(region)), 0.7)
		_atlases[pose] = atlas
		_masks[pose] = mask
