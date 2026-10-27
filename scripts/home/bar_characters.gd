extends Node

# Scene-local bar cast; travel and audio remain with HomeMap.
signal interacted(character_id: String)

const BarAlmaSpawn := preload("res://scripts/home/bar_alma_spawn.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const BENNY_TEXTURE := preload("res://assets/characters/sprites/bennybar.png")
const BENNY_REGION := Rect2(735, 328, 250, 470)
const BENNY_MIN_BOND := 2
const BENNY_SPAWN_CHANCE := 0.30

static var _benny_atlas: AtlasTexture
static var _benny_mask: BitMap

var alma_spawn: BarAlmaSpawn
var benny_spawn: TextureButton
var active := false
var _background: TextureRect
var _dialogue: HubDialogue
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "BarCharacters"
	_rng.randomize()
	set_process(false)


func setup(background: TextureRect) -> void:
	_background = background
	alma_spawn = BarAlmaSpawn.new()
	_background.add_child(alma_spawn)
	alma_spawn.interacted.connect(_on_character_interacted)
	_build_benny_spawn()


func setup_dialogue(dialogue: HubDialogue) -> void:
	_dialogue = dialogue
	_dialogue.register_control("bar:benny", benny_spawn)
	_dialogue.register_target("bar:alma", _alma_message_target)


func set_active(value: bool) -> void:
	active = value
	alma_spawn.set_active(value)
	# Roll once on entry, independently of passenger and driving RNG.
	var benny_present := value and PlayerState.get_unique_character_progress("benny") >= BENNY_MIN_BOND and _rng.randf() < BENNY_SPAWN_CHANCE
	benny_spawn.visible = benny_present
	benny_spawn.disabled = not benny_present
	benny_spawn.self_modulate = _background.self_modulate
	if not value:
		benny_spawn.release_focus()
	set_process(benny_present)


func layout_in(view_size: Vector2) -> void:
	if _background.texture == null:
		return
	var art_size := _background.texture.get_size()
	var fit := minf(view_size.x / art_size.x, view_size.y / art_size.y)
	benny_spawn.position = (_background.size - art_size * fit) * 0.5 + BENNY_REGION.position * fit
	benny_spawn.size = BENNY_REGION.size * fit


func _process(_delta: float) -> void:
	if benny_spawn.self_modulate != _background.self_modulate:
		benny_spawn.self_modulate = _background.self_modulate


func _on_character_interacted(character_id: String) -> void:
	if not active or not _background.is_visible_in_tree() or _dialogue.blocks_input():
		return
	_dialogue.say("...", {
		"target": "bar:" + character_id,
		"character_id": character_id,
		"duration": 2.5,
	})
	interacted.emit(character_id)


func _alma_message_target() -> Rect2:
	if not alma_spawn.active or not alma_spawn.is_visible_in_tree():
		return Rect2()
	return alma_spawn.get_global_transform_with_canvas() * alma_spawn.sprite_rect


func _build_benny_spawn() -> void:
	_prepare_benny_art()
	benny_spawn = TextureButton.new()
	benny_spawn.name = "BennyBarSpawn"
	benny_spawn.ignore_texture_size = true
	benny_spawn.stretch_mode = TextureButton.STRETCH_SCALE
	benny_spawn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	benny_spawn.texture_normal = _benny_atlas
	benny_spawn.texture_click_mask = _benny_mask
	benny_spawn.pressed.connect(_on_character_interacted.bind("benny"))
	_background.add_child(benny_spawn)
	benny_spawn.hide()
	benny_spawn.disabled = true


static func _prepare_benny_art() -> void:
	if _benny_atlas != null:
		return
	_benny_atlas = AtlasTexture.new()
	_benny_atlas.atlas = BENNY_TEXTURE
	_benny_atlas.region = BENNY_REGION
	_benny_atlas.filter_clip = true
	var image := BENNY_TEXTURE.get_image()
	if image.is_compressed():
		image.decompress()
	_benny_mask = BitMap.new()
	_benny_mask.create_from_image_alpha(image.get_region(Rect2i(BENNY_REGION)), 0.7)
