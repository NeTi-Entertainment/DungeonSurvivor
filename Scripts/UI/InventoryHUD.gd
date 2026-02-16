extends Control
class_name InventoryHUD

# On stocke les références aux icônes pour pouvoir changer leur texture
@onready var weapon_icons: Array[TextureRect] = []
@onready var accessory_icons: Array[TextureRect] = []

func _ready() -> void:
	# Récupération automatique des cases (Slots) au démarrage
	_fill_icon_array($MarginContainer/MainContainer/WeaponRow, weapon_icons)
	_fill_icon_array($MarginContainer/MainContainer/AccessoryRow, accessory_icons)

func _fill_icon_array(container: HBoxContainer, target_array: Array[TextureRect]) -> void:
	for slot in container.get_children():
		# On cherche le noeud "Icon" à l'intérieur du Panel
		var icon = slot.get_node_or_null("Icon")
		if icon:
			target_array.append(icon)
			icon.texture = null # On vide l'icone au départ

func update_inventory(weapons: Array, accessories: Array) -> void:
	# 1. Mise à jour des Armes
	for i in range(weapon_icons.size()):
		if i < weapons.size():
			# On suppose que l'objet arme a une propriété 'icon' ou une méthode pour l'avoir
			var weapon_node = weapons[i]
			# Si l'arme est un Node instancié, elle a peut-être une propriété 'stats' avec l'icone
			if weapon_node.get("stats") and weapon_node.stats.icon:
				weapon_icons[i].texture = weapon_node.stats.icon
			# Fallback : si l'arme a une variable icon directe
			elif weapon_node.get("icon"):
				weapon_icons[i].texture = weapon_node.get("icon")
		else:
			weapon_icons[i].texture = null # Case vide

	# 2. Mise à jour des Accessoires
	for i in range(accessory_icons.size()):
		if i < accessories.size():
			# Même logique pour les accessoires (adapter selon ta structure future)
			var item = accessories[i]
			if item is Resource and "icon" in item:
				accessory_icons[i].texture = item.icon
			elif item.get("icon"):
				accessory_icons[i].texture = item.icon
		else:
			accessory_icons[i].texture = null
