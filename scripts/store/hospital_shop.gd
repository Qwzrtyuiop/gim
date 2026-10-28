extends "res://scripts/store/location_shop.gd"

const StoreItemCatalog := preload("res://scripts/store/hospital_item_catalog.gd")
const OWNER_PORTRAIT := preload("res://assets/characters/celinashop.png")
const CelinaHospitalDialogue := preload("res://scripts/home/celina_hospital_dialogue.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const DialogueAnchors := preload("res://scripts/ui/hub_dialogue_anchors.gd")

var dialogue_pool := CelinaHospitalDialogue.new()
var shop_dialogue: HubDialogue


func _init() -> void:
	active_category = "hospital"


func _ready() -> void:
	super._ready()
	shop_dialogue = HubDialogue.new()
	add_child(shop_dialogue)
	shop_dialogue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_dialogue.register_target("hospital_shop_owner", DialogueAnchors.store_owner.bind(self, "hospital"))


func open() -> bool:
	if not super.open():
		return false
	shop_dialogue.say(dialogue_pool.next_greeting(), {
		"target": "hospital_shop_owner",
		"character_id": "cel",
		"duration": 4.0,
	})
	return true


func close() -> void:
	if shop_dialogue != null:
		shop_dialogue.clear()
	super.close()


func _shopping_allowed() -> bool:
	return bool(PlayerState.get_event_value("celina_hospital_shop_unlocked", false)) and super._shopping_allowed()


func _shop_node_name() -> String:
	return "HospitalShop"


func _shop_title() -> String:
	return "MEDICINE / FIRST AID"


func _shop_prompt() -> String:
	return "Basic first aid is available once per day. Medicine applies immediately."


func _shop_portrait() -> Texture2D:
	return OWNER_PORTRAIT


func _shop_header() -> String:
	return "PhP %d    Energy: %d/%d    Stress: %d/%d" % [PlayerState.money, PlayerState.energy, PlayerState.max_energy, PlayerState.stress, PlayerState.max_stress]
