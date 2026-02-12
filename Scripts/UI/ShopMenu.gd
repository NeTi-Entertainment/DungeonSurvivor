extends Control

@export var items_container_path: NodePath = "ScrollContainer/ShopItemsContainer" # A régler dans l'inspecteur
@export var gold_label_path: NodePath = "GoldDisplay" # A régler dans l'inspecteur

var shop_item_scene = preload("res://Scenes/UI/ShopItem.tscn")
@onready var items_container = get_node(items_container_path)
@onready var gold_label = get_node(gold_label_path)

func _ready():
	# On s'abonne à la visibilité pour rafraichir quand on ouvre le menu
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		refresh_shop_ui()

func refresh_shop_ui():
	# 1. Mise à jour de l'or
	if gold_label:
		gold_label.text = "Or : " + str(GameData.total_banked_gold)
	
	# 2. Remplissage de la liste (Seulement si vide pour éviter les doublons, ou on nettoie tout)
	for child in items_container.get_children():
		child.queue_free()
		
	for id in GameData.shop_definitions.keys():
		var item = shop_item_scene.instantiate()
		items_container.add_child(item)
		item.setup(id)
		# Connexion du signal d'achat venant de l'item
		if not item.purchase_requested.is_connected(_on_item_buy_request):
			item.purchase_requested.connect(_on_item_buy_request)

func _on_item_buy_request(id, cost):
	if GameData.total_banked_gold >= cost:
		GameData.total_banked_gold -= cost
		
		# Incrémentation du niveau
		if id in GameData.shop_unlocks:
			GameData.shop_unlocks[id] += 1
		else:
			GameData.shop_unlocks[id] = 1
			
		GameData.save_bank(0)
		
		# Rafraichissement total pour mettre à jour les boutons et prix
		refresh_shop_ui()
