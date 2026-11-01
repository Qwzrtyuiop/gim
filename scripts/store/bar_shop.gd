extends "res://scripts/store/location_shop.gd"

const StoreItemCatalog := preload("res://scripts/store/bar_item_catalog.gd")
const HubDialogue := preload("res://scripts/ui/hub_dialogue.gd")
const OWNER_PORTRAIT := preload("res://assets/characters/almashop.png")

var _feedback: HubDialogue


func _init() -> void:
	active_category = "bar"


func _ready() -> void:
	super._ready()
	# Keep purchase speech above the shop modal, alongside its portrait.
	_feedback = HubDialogue.new()
	add_child(_feedback)
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback.register_control("counter", owner_panel)
	_feedback.set_gate(func() -> bool: return is_visible_in_tree() and not is_transitioning)


func close() -> void:
	if _feedback != null:
		_feedback.clear()
	super.close()


func _buy_item(item: Dictionary, label: RichTextLabel, tiers: HBoxContainer, button: Button) -> void:
	if _buying or not is_visible_in_tree() or is_transitioning or tutorial_active or not _shopping_allowed():
		return
	await super._buy_item(item, label, tiers, button)
	if is_visible_in_tree() and status_label.text == StoreItems.FOOD_FULL_MESSAGE:
		_feedback.say(StoreItems.FOOD_FULL_MESSAGE, {
			"target": "counter",
			"speaker": "John Toda",
			"show_tail": false,
			"duration": 3.0,
			"side": "below",
			"width": minf(380, owner_panel.size.x + 24),
		})


func _shop_node_name() -> String:
	return "BarShop"


func _shop_title() -> String:
	return "BAR"


func _shop_prompt() -> String:
	return "Choose food or a drink."


func _shop_portrait() -> Texture2D:
	return OWNER_PORTRAIT
