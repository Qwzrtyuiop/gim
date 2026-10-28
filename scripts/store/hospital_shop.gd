extends "res://scripts/store/location_shop.gd"

const StoreItemCatalog := preload("res://scripts/store/hospital_item_catalog.gd")
const OWNER_PORTRAIT := preload("res://assets/characters/celinashop.png")


func _init() -> void:
	active_category = "hospital"


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
