extends Node
class_name LevelUpManager
# LevelUpManager.gd - Gère TOUT le système de level-up (options, QoL, application)

# ============================================================================
# SIGNAUX
# ============================================================================

signal level_up_completed() # Émis quand le joueur a choisi et le jeu peut reprendre

# ============================================================================
# RÉFÉRENCES (injectées depuis Game.gd)
# ============================================================================

var player: CharacterBody2D
var level_up_ui: Control

# Boutons d'options
var option_1: Button
var option_2: Button
var option_3: Button

# Boutons QoL
var btn_reroll: Button
var btn_skip: Button
var btn_banish: Button

# ============================================================================
# ÉTAT
# ============================================================================

var current_options: Array = []
var is_banish_active: bool = false

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_level_up_ui: Control, 
		   p_option_1: Button, p_option_2: Button, p_option_3: Button,
		   p_btn_reroll: Button, p_btn_skip: Button, p_btn_banish: Button) -> void:
	"""Initialise le LevelUpManager avec toutes les références UI nécessaires"""
	
	player = p_player
	level_up_ui = p_level_up_ui
	option_1 = p_option_1
	option_2 = p_option_2
	option_3 = p_option_3
	btn_reroll = p_btn_reroll
	btn_skip = p_btn_skip
	btn_banish = p_btn_banish
	
	_connect_buttons()
	
	print("[LevelUpManager] Initialisé")

func _connect_buttons() -> void:
	"""Connecte tous les boutons du level-up UI"""
	if not option_1.pressed.is_connected(_on_option_1_pressed):
		option_1.pressed.connect(_on_option_1_pressed)
	if not option_2.pressed.is_connected(_on_option_2_pressed):
		option_2.pressed.connect(_on_option_2_pressed)
	if not option_3.pressed.is_connected(_on_option_3_pressed):
		option_3.pressed.connect(_on_option_3_pressed)
	
	btn_reroll.pressed.connect(_on_reroll_pressed)
	btn_skip.pressed.connect(_on_skip_pressed)
	btn_banish.pressed.connect(_on_banish_pressed)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func show_level_up_screen(_new_level: int) -> void:
	"""Affiche l'écran de level-up (appelé par Game.gd)"""
	# 1. Générer les 3 options aléatoires
	current_options = generate_upgrade_options()
	
	# 2. Mettre à jour l'affichage des boutons
	_update_button_display(option_1, current_options[0])
	_update_button_display(option_2, current_options[1])
	_update_button_display(option_3, current_options[2])
	
	# 3. Reset du mode bannissement
	is_banish_active = false
	_update_qol_buttons_display()
	
	# 4. Afficher le menu
	level_up_ui.show()
	option_1.grab_focus()

# ============================================================================
# GÉNÉRATION DES OPTIONS
# ============================================================================

func generate_upgrade_options() -> Array:
	"""Génère 3 options de level-up valides"""
	var valid_candidates = []
	
	# A. Récupérer l'inventaire actuel du joueur
	var weapons_holder = player.get_node_or_null("WeaponsHolder")
	var current_weapons = []
	if weapons_holder:
		current_weapons = weapons_holder.get_children()
	
	var owned_weapon_ids = []
	for w in current_weapons:
		if "id" in w: 
			owned_weapon_ids.append(w.id)
	
	# B. AMÉLIORATIONS (Armes possédées < Niv 10)
	for w in current_weapons:
		if w.level < 10:
			valid_candidates.append({
				"type": "weapon_upgrade",
				"id": w.id,
				"level": w.level + 1,
				"name": GameData.weapon_data[w.id]["name"],
				"icon": null
			})
	
	# C. NOUVELLES ARMES (Si slots < 5)
	if current_weapons.size() < 5:
		for weapon_id in GameData.weapon_data:
			if weapon_id in GameData.banished_items:
				continue
			if not weapon_id in owned_weapon_ids:
				valid_candidates.append({
					"type": "weapon_new",
					"id": weapon_id,
					"level": 1,
					"name": GameData.weapon_data[weapon_id]["name"],
					"icon": null
				})
	
	# D. ACCESSOIRES
	var current_accs = GameData.current_accessories
	var acc_slots_used = current_accs.size()
	var max_acc_slots = player.MAX_ACCESSORY_SLOTS
	
	# D1. ACCESSORY UPGRADES (Owned < Max Level)
	for acc_id in current_accs:
		var current_lvl = current_accs[acc_id]
		var data = GameData.accessory_data[acc_id]
		if current_lvl < data["max_level"]:
			valid_candidates.append({
				"type": "accessory_upgrade",
				"id": acc_id,
				"level": current_lvl + 1,
				"name": data["name"],
				"desc": data["description"],
				"icon": data.get("icon", null)
			})
	
	# D2. NEW ACCESSORIES (If slots < 5)
	if acc_slots_used < max_acc_slots:
		for acc_id in GameData.accessory_data:
			if acc_id in GameData.banished_items:
				continue
			if not acc_id in current_accs:
				var data = GameData.accessory_data[acc_id]
				valid_candidates.append({
					"type": "accessory_new",
					"id": acc_id,
					"level": 1,
					"name": data["name"],
					"desc": data["description"],
					"icon": data.get("icon", null)
				})
	
	# E. TIRAGE ALÉATOIRE
	valid_candidates.shuffle()
	
	var final_options = []
	
	# On prend les 3 premiers candidats valides
	for i in range(3):
		if i < valid_candidates.size():
			final_options.append(valid_candidates[i])
		else:
			# FILLER (Si pas assez de choix, on met du Soin)
			final_options.append({
				"type": "heal",
				"amount": 1,
				"name": "Soin d'urgence",
				"desc": "Restaure 1 PV"
			})
	
	return final_options

# ============================================================================
# AFFICHAGE DES BOUTONS
# ============================================================================

func _update_button_display(btn: Button, option: Dictionary) -> void:
	"""Met à jour le texte d'un bouton selon l'option"""
	if option.type == "heal":
		btn.text = option.name + "\n" + option.desc
	elif option.type == "weapon_new":
		btn.text = "NOUVEAU : " + option.name
	elif option.type == "weapon_upgrade":
		btn.text = "AMÉLIORATION : " + option.name + " (Niv " + str(option.level) + ")"
	elif option.type == "accessory_new":
		btn.text = "NOUVEAU : " + option.name + "\n" + option.desc
	elif option.type == "accessory_upgrade":
		btn.text = "AMÉLIORATION : " + option.name + " (Niv " + str(option.level) + ")\n" + option.desc

func _update_qol_buttons_display() -> void:
	"""Met à jour l'affichage des boutons QoL"""
	btn_reroll.text = "Reroll (%d)" % player.reroll_count
	btn_reroll.disabled = (player.reroll_count <= 0)
	
	btn_skip.text = "Skip (%d)" % player.skip_count
	btn_skip.disabled = (player.skip_count <= 0)
	
	btn_banish.text = "Bannir (%d)" % player.banish_count
	btn_banish.disabled = (player.banish_count <= 0)
	
	# Gestion visuelle du mode Bannissement actif
	if is_banish_active:
		btn_banish.modulate = Color(1, 0, 0) # Rouge
		btn_banish.text = "ANNULER"
		btn_banish.disabled = false
	else:
		btn_banish.modulate = Color(1, 1, 1) # Blanc normal

# ============================================================================
# APPLICATION DES OPTIONS
# ============================================================================

func _apply_option(option: Dictionary) -> void:
	"""Applique l'effet d'une option sélectionnée"""
	if option.type == "heal":
		if player.current_health < player.max_health:
			player.current_health += option.amount
			player.health_bar.value = player.current_health
	
	elif option.type == "weapon_upgrade":
		var holder = player.get_node("WeaponsHolder")
		for w in holder.get_children():
			if w.id == option.id:
				w.load_stats(option.level)
				break
	
	elif option.type == "weapon_new":
		var path = GameData.weapon_data[option.id]["scene_path"]
		var new_weapon_scene = load(path)
		if new_weapon_scene:
			var new_weapon = new_weapon_scene.instantiate()
			player.get_node("WeaponsHolder").add_child(new_weapon)
			player.weapons.append(new_weapon)
			new_weapon.load_stats(1)
	
	elif option.type == "accessory_new" or option.type == "accessory_upgrade":
		GameData.add_accessory(option.id)
		
		player.accessories.clear()
		for acc_id in GameData.current_accessories.keys():
			if acc_id in GameData.accessory_data:
				var data = GameData.accessory_data[acc_id]
				player.accessories.append(data)
		
		# Force recalcul des stats
		var holder = player.get_node("WeaponsHolder")
		for w in holder.get_children():
			if w.has_method("load_stats"):
				w.load_stats(w.level)
		player.update_stats()

# ============================================================================
# CALLBACKS - BOUTONS D'OPTIONS
# ============================================================================

func _handle_option_click(index: int) -> void:
	"""Gère le clic sur une option (mode normal ou bannissement)"""
	var selected_option = current_options[index]
	
	if is_banish_active:
		# MODE BANNISSEMENT
		if player.banish_count > 0:
			# On ajoute à la liste noire (sauf si c'est du Soin)
			if selected_option.type != "heal":
				GameData.banished_items.append(selected_option.id)
				player.banish_count -= 1
			
			# On désactive le mode et on reprend le jeu
			is_banish_active = false
			_resume_game()
	else:
		# MODE NORMAL (Choisir l'amélioration)
		_apply_option(selected_option)
		# VÉRIFICATION ÉVOLUTION : Si l'item vient d'atteindre niveau 10
		var item_id = selected_option.id
		var item_type = selected_option.type
		
		# Cas 1 : Arme qui vient d'atteindre niveau 10
		if item_type == "weapon_upgrade":
			var weapon_node = _find_weapon_in_holder(item_id)
			if weapon_node and weapon_node.level == 10:
				if _try_trigger_evolution(item_id, "weapon"):
					return  # Évolution déclenchée, ne pas appeler _resume_game
		
		# Cas 2 : Accessoire qui vient d'atteindre niveau 10
		elif item_type == "accessory_new" or item_type == "accessory_upgrade":
			var acc_level = GameData.current_accessories.get(item_id, 0)
			if acc_level == 10:
				if _try_trigger_evolution(item_id, "accessory"):
					return  # Évolution déclenchée, ne pas appeler _resume_game
		
		# Pas d'évolution, reprendre normalement
		_resume_game()

func _on_option_1_pressed() -> void:
	_handle_option_click(0)

func _on_option_2_pressed() -> void:
	_handle_option_click(1)

func _on_option_3_pressed() -> void:
	_handle_option_click(2)

# ============================================================================
# CALLBACKS - BOUTONS QOL
# ============================================================================

func _on_reroll_pressed() -> void:
	"""Reroll les 3 options"""
	if player.reroll_count > 0:
		player.reroll_count -= 1
		is_banish_active = false
		
		current_options = generate_upgrade_options()
		
		_update_button_display(option_1, current_options[0])
		_update_button_display(option_2, current_options[1])
		_update_button_display(option_3, current_options[2])
		
		_update_qol_buttons_display()

func _on_skip_pressed() -> void:
	"""Skip le level-up"""
	if player.skip_count > 0:
		player.skip_count -= 1
		_resume_game()

func _on_banish_pressed() -> void:
	"""Toggle le mode bannissement"""
	is_banish_active = not is_banish_active
	_update_qol_buttons_display()

# ============================================================================
# VÉRIFICATION ÉVOLUTIONS
# ============================================================================

func _find_weapon_in_holder(weapon_id: String) -> Node:
	"""Trouve le nœud d'arme dans WeaponsHolder par son ID"""
	if not player:
		return null
	
	var weapons_holder = player.get_node_or_null("WeaponsHolder")
	if not weapons_holder:
		return null
	
	for weapon in weapons_holder.get_children():
		if weapon.has("id") and weapon.id == weapon_id:
			return weapon
	
	return null

func _try_trigger_evolution(item_id: String, item_type: String) -> bool:
	"""Tente de déclencher une évolution. Retourne true si réussie."""
	var weapon_id_to_evolve = ""
	
	if item_type == "weapon":
		# L'item est une arme niveau 10, vérifier l'accessoire
		var weapon_def = GameData.weapon_data.get(item_id)
		if not weapon_def or not weapon_def.has("accessory"):
			return false  # Pas d'accessoire lié
		
		var accessory_id = weapon_def["accessory"]
		var acc_level = GameData.current_accessories.get(accessory_id, 0)
		
		if acc_level < 10:
			return false  # Accessoire pas niveau 10
		
		weapon_id_to_evolve = item_id
	
	elif item_type == "accessory":
		# L'item est un accessoire niveau 10, trouver l'arme associée
		for weapon_id in GameData.weapon_data.keys():
			var weapon_def = GameData.weapon_data[weapon_id]
			if weapon_def.get("accessory") == item_id:
				# Vérifier si le joueur possède l'arme
				var weapon_node = _find_weapon_in_holder(weapon_id)
				if not weapon_node:
					return false  # Pas l'arme
				
				if weapon_node.level < 10:
					return false  # Arme pas niveau 10
				
				weapon_id_to_evolve = weapon_id
				break
		
		if weapon_id_to_evolve.is_empty():
			return false  # Aucune arme trouvée
	
	# Vérifier que l'évolution existe
	if not GameData.evolved_weapons_data.has(weapon_id_to_evolve):
		return false
	
	# TOUTES LES CONDITIONS REMPLIES : Déclencher l'évolution
	var game = get_tree().current_scene
	if not game.has("evolution_manager"):
		return false
	
	level_up_ui.hide()
	game.evolution_manager.show_evolution_menu(weapon_id_to_evolve)
	return true

# ============================================================================
# REPRISE DU JEU
# ============================================================================

func _resume_game() -> void:
	"""Cache le menu et vérifie si multi-leveling nécessaire"""
	# Vérification du Multi-Leveling (XP Résiduelle)
	if player.experience >= player.experience_required:
		# On enchaîne directement un autre level-up
		player.level_up()
	else:
		# Sinon, on reprend le jeu
		level_up_ui.hide()
		level_up_completed.emit()
