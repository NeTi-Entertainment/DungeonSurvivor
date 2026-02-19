extends Node
class_name EvolutionManager
# EvolutionManager.gd - Gère les évolutions d'armes

signal evolution_menu_opened
signal evolution_menu_closed
signal weapon_evolved(weapon_id: String, evolution_chosen: String)

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var player: CharacterBody2D = null
var evolution_ui: Control = null
var option_evo1: Button = null
var option_evo2: Button = null

# ============================================================================
# ÉTAT
# ============================================================================

var current_base_weapon_id: String = ""
var pending_evolution: bool = false

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_evolution_ui: Control, 
		   p_option_evo1: Button, p_option_evo2: Button) -> void:
	player = p_player
	evolution_ui = p_evolution_ui
	option_evo1 = p_option_evo1
	option_evo2 = p_option_evo2
	
	# Connecter les boutons
	option_evo1.pressed.connect(func(): _on_evolution_selected("evolution_1"))
	option_evo2.pressed.connect(func(): _on_evolution_selected("evolution_2"))
	
	print("[EvolutionManager] Initialisé")

# ============================================================================
# AFFICHAGE DU MENU D'ÉVOLUTION
# ============================================================================

func show_evolution_menu(weapon_id: String) -> void:
	"""Affiche le menu de choix d'évolution pour une arme"""
	current_base_weapon_id = weapon_id
	pending_evolution = true
	
	# Récupérer les données d'évolution
	var evolutions = GameData.evolved_weapons_data.get(weapon_id, {})
	var evo1 = evolutions.get("evolution_1", {})
	var evo2 = evolutions.get("evolution_2", {})
	
	# Mettre à jour les boutons
	if evo1:
		option_evo1.text = evo1.get("name", "Évolution 1") + "\n" + evo1.get("desc", "")
	if evo2:
		option_evo2.text = evo2.get("name", "Évolution 2") + "\n" + evo2.get("desc", "")
	
	# Afficher le menu et mettre en pause
	evolution_ui.show()
	get_tree().paused = true
	option_evo1.grab_focus()
	
	evolution_menu_opened.emit()
	print("[EvolutionManager] Menu d'évolution affiché pour : %s" % weapon_id)

# ============================================================================
# SÉLECTION D'ÉVOLUTION
# ============================================================================

func _on_evolution_selected(evolution_key: String) -> void:
	"""Appelé quand le joueur choisit une évolution"""
	if not pending_evolution or current_base_weapon_id.is_empty():
		return
	
	# Récupérer les données d'évolution
	var evolutions = GameData.evolved_weapons_data.get(current_base_weapon_id, {})
	var chosen_evo = evolutions.get(evolution_key, {})
	
	if not chosen_evo:
		push_error("[EvolutionManager] Évolution introuvable : %s" % evolution_key)
		return
	
	# Appliquer l'évolution
	_apply_evolution(chosen_evo)
	
	# Fermer le menu
	_close_menu()

func _apply_evolution(evolution_data: Dictionary) -> void:
	"""Remplace l'arme de base par l'arme évoluée"""
	var weapon_id = evolution_data.get("id", "")
	var scene_path = evolution_data.get("scene_path", "")
	
	if weapon_id.is_empty() or scene_path.is_empty():
		push_error("[EvolutionManager] Données d'évolution invalides")
		return
	
	# Supprimer l'arme de base
	var old_weapon = _find_weapon_node(current_base_weapon_id)
	if old_weapon:
		old_weapon.queue_free()
	
	# Charger et instancier la nouvelle arme
	if not ResourceLoader.exists(scene_path):
		push_error("[EvolutionManager] Scène introuvable : %s" % scene_path)
		return
	
	var weapon_scene = load(scene_path)
	var new_weapon = weapon_scene.instantiate()
	
	# Ajouter au WeaponsHolder
	var weapons_holder = player.get_node_or_null("WeaponsHolder")
	if weapons_holder:
		weapons_holder.add_child(new_weapon)
		print("[EvolutionManager] Arme évoluée : %s → %s" % [current_base_weapon_id, weapon_id])
		weapon_evolved.emit(current_base_weapon_id, weapon_id)

func _find_weapon_node(weapon_id: String) -> Node:
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

func _close_menu() -> void:
	"""Ferme le menu d'évolution et reprend le jeu"""
	evolution_ui.hide()
	get_tree().paused = false
	
	current_base_weapon_id = ""
	pending_evolution = false
	
	evolution_menu_closed.emit()
	print("[EvolutionManager] Menu d'évolution fermé")
