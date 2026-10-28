extends Node

# Hospital cast and crowd; HomeMap owns travel and location audio.
signal interacted(character_id: String)

const CelinaSpawn := preload("res://scripts/home/hospital_celina_spawn.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const CROWD := preload("res://assets/characters/sprites/celinahosp/hospitaldaycrowd.png")
# The seated group ends at x=876; standing patients begin at x=889.
const NIGHT_CROWD_RIGHT_EDGE := 884.0

var celina_spawn: CelinaSpawn
var crowd: TextureRect
var _background: TextureRect
var _night_crowd: AtlasTexture


func _ready() -> void:
	name = "HospitalCharacters"
	set_process(false)


func setup(background: TextureRect) -> void:
	_background = background
	celina_spawn = CelinaSpawn.new()
	_background.add_child(celina_spawn)
	celina_spawn.interacted.connect(interacted.emit)
	_night_crowd = AtlasTexture.new()
	_night_crowd.atlas = CROWD
	_night_crowd.region = Rect2(0.0, 0.0, NIGHT_CROWD_RIGHT_EDGE, CROWD.get_height())
	# Transparent padding keeps the original canvas size and placement.
	_night_crowd.margin = Rect2(Vector2.ZERO, CROWD.get_size() - _night_crowd.region.size)
	_night_crowd.filter_clip = true
	crowd = TextureRect.new()
	crowd.name = "HospitalDayCrowd"
	crowd.texture = CROWD
	crowd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crowd.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crowd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crowd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Both casts are indoors. Foreground patients occlude Celina and window rain.
	crowd.z_index = 2
	_background.add_child(crowd)
	crowd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crowd.hide()


func setup_dialogue(dialogue: HubDialogue) -> void:
	celina_spawn.setup_dialogue(dialogue)


func set_active(value: bool, daytime := true) -> void:
	celina_spawn.set_active(value)
	crowd.texture = CROWD if daytime else _night_crowd
	crowd.visible = value
	crowd.self_modulate = _background.self_modulate
	set_process(crowd.visible)


func _process(_delta: float) -> void:
	if crowd.self_modulate != _background.self_modulate:
		crowd.self_modulate = _background.self_modulate
