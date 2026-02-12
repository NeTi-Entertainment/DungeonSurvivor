extends PanelContainer

var upgrade_id = ""
var current_cost = 0

@onready var name_lbl = $HBoxContainer/NameLabel
@onready var level_lbl = $HBoxContainer/LevelLabel
@onready var price_lbl = $HBoxContainer/PriceLabel
@onready var buy_btn = $HBoxContainer/BuyButton

signal purchase_requested(id, cost)

func setup(id: String):
	upgrade_id = id
	refresh_display()

func refresh_display():
	var def = GameData.shop_definitions[upgrade_id]
	var current_lvl = GameData.shop_unlocks.get(upgrade_id, 0)
	var max_lvl = def["max_lvl"]
	
	name_lbl.text = def["name"]
	level_lbl.text = "Niv %d / %d" % [current_lvl, max_lvl]
	
	if current_lvl < max_lvl:
		current_cost = def["costs"][current_lvl]
		price_lbl.text = str(current_cost) + " Or"
		buy_btn.disabled = (GameData.total_banked_gold < current_cost)
		buy_btn.text = "Acheter"
	else:
		price_lbl.text = "MAX"
		buy_btn.disabled = true
		buy_btn.text = "Complet"

func _on_buy_button_pressed():
	purchase_requested.emit(upgrade_id, current_cost)

func _ready():
	buy_btn.pressed.connect(_on_buy_button_pressed)
