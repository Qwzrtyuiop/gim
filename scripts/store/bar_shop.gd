extends "res://scripts/store/location_shop.gd"

const StoreItemCatalog := preload("res://scripts/store/bar_item_catalog.gd")
const OWNER_PORTRAIT := preload("res://assets/characters/almashop.png")


func _init() -> void:
	active_category = "bar"


func _shop_node_name() -> String:
	return "BarShop"


func _shop_title() -> String:
	return "BAR"


func _shop_prompt() -> String:
	return "Choose a drink."


func _shop_portrait() -> Texture2D:
	return OWNER_PORTRAIT
