extends Node2D

var wave_manager: WaveManager
var boss_manager: BossManager
var victory_manager: VictoryManager

var debug_manager: DebugManager

var current_options = []

@export var current_map_config: MapConfig

# Référence au joueur pour savoir où spawner autour
@onready var map_border = $MapBorder
@onready var player = $Player

# UI References
@onready var game_over_ui: Control = $CanvasLayer/GameOverUI
@onready var victory_ui: Control = $CanvasLayer/VictoryUI
@onready var button_return: Button = $CanvasLayer/GameOverUI/ButtonReturn
@onready var button_victory_return: Button = $CanvasLayer/VictoryUI/ButtonReturn
@onready var timer_label: Label = $CanvasLayer/TimerLabel

# UI LEVEL UP
@onready var level_up_ui: Control = $CanvasLayer/LevelUpUI

@onready var inventory_hud: InventoryHUD = $CanvasLayer/InventoryHUD
# On récupère les boutons (solution temporaire avant de les générer dynamiquement)
@onready var option_1: Button = $CanvasLayer/LevelUpUI/OptionsContainer/Option1
@onready var option_2: Button = $CanvasLayer/LevelUpUI/OptionsContainer/Option2
@onready var option_3: Button = $CanvasLayer/LevelUpUI/OptionsContainer/Option3

@onready var btn_reroll: Button = $CanvasLayer/LevelUpUI/QoLButtonsContainer/ButtonReroll
@onready var btn_skip: Button = $CanvasLayer/LevelUpUI/QoLButtonsContainer/ButtonSkip
@onready var btn_banish: Button = $CanvasLayer/LevelUpUI/QoLButtonsContainer/ButtonBanish
var is_banish_active: bool = false

var damage_number_manager: DamageNumberManager

func _ready() -> void:
	#timer.timeout.connect()
	
	_setup_game_timer_connections()
	_start_game_timer()
	_initialize_wave_manager()
	_initialize_boss_manager()
	_initialize_victory_manager()
	
	damage_number_manager = DamageNumberManager.new()
	add_child(damage_number_manager)
	
	_initialize_debug_manager()
	
	# Connect the Button
	button_return.pressed.connect(_on_return_pressed)
	button_victory_return.pressed.connect(_on_return_pressed)
	
	# Connexions Joueur
	player.player_died.connect(_on_player_died)
	player.level_up_triggered.connect(_on_level_up) # Connexion du nouveau signal
	
	# Connexions UI (Pour tester, cliquer sur une option reprend le jeu)
# Connexions des 3 boutons aux fonctions spécifiques
	if not option_1.pressed.is_connected(_on_option_1_pressed):
		option_1.pressed.connect(_on_option_1_pressed)
	if not option_2.pressed.is_connected(_on_option_2_pressed):
		option_2.pressed.connect(_on_option_2_pressed)
	if not option_3.pressed.is_connected(_on_option_3_pressed):
		option_3.pressed.connect(_on_option_3_pressed)
	
	# IMPORTANT : Il faut que le menu LevelUp puisse fonctionner pendant la pause !
	level_up_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	btn_reroll.pressed.connect(_on_reroll_pressed)
	btn_skip.pressed.connect(_on_skip_pressed)
	btn_banish.pressed.connect(_on_banish_pressed)
	
	# Réinitialiser les bannissements au lancement de la scène Game
	GameData.reset_run_state()
	if current_map_config:
		# 1. Configurer le visuel du mur
		if map_border:
			map_border.setup(current_map_config.map_radius, Color.BLACK)
			# Assure-toi que le MapBorder est au-dessus du sol (Z=0) et des ennemis (Z=1)
			map_border.z_index = 5
	if player:
		# Connexion du signal
		player.inventory_updated.connect(_on_player_inventory_updated)
		
		# Force une première mise à jour immédiate
		inventory_hud.update_inventory(player.weapons, player.accessories)

func _on_player_inventory_updated(weapons: Array, accessories: Array) -> void:
	if inventory_hud:
		inventory_hud.update_inventory(weapons, accessories)

func _initialize_debug_manager() -> void:
	"""Initialise le DebugManager pour les tests"""
	debug_manager = DebugManager.new()
	debug_manager.setup(player, self)
	add_child(debug_manager)

func _initialize_wave_manager() -> void:
	"""Initialise et démarre le WaveManager"""
	wave_manager = WaveManager.new()
	wave_manager.setup(player, current_map_config, self)
	add_child(wave_manager)
	wave_manager.start_spawning()
	print("[Game] WaveManager initialisé et démarré")

func _initialize_boss_manager() -> void:
	"""Initialise le BossManager"""
	boss_manager = BossManager.new()
	boss_manager.setup(player, current_map_config, self)
	add_child(boss_manager)
	# Connexion au signal de victoire (boss final)
	boss_manager.final_boss_defeated.connect(_on_final_boss_defeated)
	print("[Game] BossManager initialisé")

func _on_final_boss_defeated() -> void:
	"""Appelé quand le boss final (18min) est vaincu"""
	print("[Game] Boss final vaincu - Activation de la victoire")
	
	GameData.boss_defeated = true
	
	# Récupérer la position du boss mort
	var boss_position = Vector2.ZERO
	if boss_manager.active_bosses.size() > 0:
		var last_boss = boss_manager.active_bosses[-1]
		if is_instance_valid(last_boss):
			boss_position = last_boss.global_position
	
	# Appeler le VictoryManager
	victory_manager.on_final_boss_defeated(boss_position)

func _initialize_victory_manager() -> void:
	victory_manager = VictoryManager.new()
	victory_manager.setup(player, current_map_config, self, victory_ui)
	add_child(victory_manager)
	victory_manager.portal_used.connect(_on_portal_used)

func _on_portal_used() -> void:
	victory_ui.show()
	GameData.finalize_run(1.0)
	get_tree().paused = true

func _setup_game_timer_connections() -> void:
	"""Connecte les signaux du GameTimer"""
	GameTimer.time_updated.connect(_on_time_updated)
	GameTimer.cycle_changed.connect(_on_cycle_changed)
	GameTimer.game_time_over.connect(_on_game_time_over)

func _on_time_updated(_seconds_remaining: int, _formatted_time: String) -> void:
	timer_label.text = _formatted_time

func _on_cycle_changed(cycle_number: int) -> void:
	"""Changement de cycle d'ennemis (Phase 2)"""
	print("[Game] Cycle changé → Cycle %d" % cycle_number)
	# TODO Phase 2 : Le WaveManager utilisera ce signal pour changer le pool d'ennemis

func _on_game_time_over() -> void:
	"""Temps de jeu écoulé - 20:00 → 00:00 (Phase 4)"""
	print("[Game] Temps écoulé - Spawn du portail de victoire")
	# TODO Phase 4 : Le VictoryManager spawne le portail ici

func _start_game_timer() -> void:
	"""Démarre le timer de jeu"""
	GameTimer.start_game()
	print("[Game] Timer démarré - Map: %s" % current_map_config.map_name)

func _physics_process(_delta: float) -> void:
	# Si on a une config de map et un joueur actif
	if current_map_config and player:
		var radius = current_map_config.map_radius
		
		# Si le joueur dépasse le rayon (distance au centre > rayon)
		if player.global_position.length() > radius:
			# On le téléporte doucement à la limite exacte du cercle
			player.global_position = player.global_position.limit_length(radius)

func _on_player_died() -> void:
	if GameData.boss_defeated:
		victory_ui.show()
		GameData.finalize_run(1.0)
	else:
		game_over_ui.show()
		var save_ratio = player.saved_resources_ratio
		GameData.finalize_run(save_ratio)
	
	get_tree().paused = true
	GameTimer.stop_game()
	wave_manager.stop_spawning()

func _on_victory() -> void:
	victory_ui.show()
	GameData.finalize_run(1.0)
	get_tree().paused = true

func _on_return_pressed() -> void:
	print("[Game] _on_return_pressed() APPELÉ")
	get_tree().paused = false
	print("[Game] Jeu dépausé")
	
	GameTimer.stop_game()
	print("[Game] GameTimer stoppé")
	
	print("[Game] Changement de scène vers MainMenu...")
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/UI/MainMenu.tscn")
	print("[Game] Changement de scène demandé")

# --- LEVEL UP SYSTEM ---
func _on_level_up(_new_level: int) -> void:
	get_tree().paused = true
	GameTimer.pause_game()
	
	# 1. Générer les 3 options aléatoires
	current_options = generate_upgrade_options()
	
	# 2. Mettre à jour l'affichage des boutons
	_update_button_display(option_1, current_options[0])
	_update_button_display(option_2, current_options[1])
	_update_button_display(option_3, current_options[2])
	
	is_banish_active = false # Reset du mode par sécurité
	_update_qol_buttons_display() # <--- AJOUTER ICI
	
	# 3. Afficher le menu
	level_up_ui.show()
	option_1.grab_focus()

func generate_upgrade_options() -> Array:
	var valid_candidates = []
	
	# A. Récupérer l'inventaire actuel du joueur
	# On suppose que les armes sont dans un noeud "WeaponsHolder"
	var weapons_holder = player.get_node_or_null("WeaponsHolder")
	var current_weapons = []
	if weapons_holder:
		current_weapons = weapons_holder.get_children()
	
	# Liste des IDs d'armes possédées
	var owned_weapon_ids = []
	for w in current_weapons:
		if "id" in w: owned_weapon_ids.append(w.id)
	
	# B. Identifier les AMÉLIORATIONS (Armes possédées < Niv 10)
	for w in current_weapons:
		if w.level < 10:
			valid_candidates.append({
				"type": "weapon_upgrade",
				"id": w.id,
				"level": w.level + 1,
				"name": GameData.weapon_data[w.id]["name"],
				"icon": null # Ajouter icône plus tard
			})
	
	# C. Identifier les NOUVELLES ARMES (Si slots < 5)
	if current_weapons.size() < 5:
		for weapon_id in GameData.weapon_data:
			if weapon_id in GameData.banished_items:
				continue
			# Si on ne possède pas déjà cette arme
			if not weapon_id in owned_weapon_ids:
				valid_candidates.append({
					"type": "weapon_new",
					"id": weapon_id,
					"level": 1,
					"name": GameData.weapon_data[weapon_id]["name"],
					"icon": null
				})
	
	# D. ACCESSORIES LOGIC
	var current_accs = GameData.current_accessories
	var acc_slots_used = current_accs.size()
	# Access constants from Player script
	var max_acc_slots = player.MAX_ACCESSORY_SLOTS 
	
	# D1. Identify ACCESSORY UPGRADES (Owned < Max Level)
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

	# D2. Identify NEW ACCESSORIES (If slots < 5)
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
			# F. LE "FILLER" (Si pas assez de choix, on met du Soin)
			final_options.append({
				"type": "heal",
				"amount": 1, # Valeur du soin
				"name": "Soin d'urgence",
				"desc": "Restaure 1 PV"
			})
			
	return final_options

func _update_button_display(btn: Button, option: Dictionary) -> void:
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

func _apply_option(option: Dictionary) -> void:
	if option.type == "heal":
		# Appliquer le soin (suppose que le player a une méthode heal ou on modifie current_health)
		if player.current_health < player.max_health:
			player.current_health += option.amount
			player.health_bar.value = player.current_health
			
	elif option.type == "weapon_upgrade":
		# Trouver l'arme et l'améliorer
		var holder = player.get_node("WeaponsHolder")
		
		for w in holder.get_children():
			if w.id == option.id:
				w.load_stats(option.level)
				break
				
	elif option.type == "weapon_new":
		# Instancier la nouvelle arme
		var path = GameData.weapon_data[option.id]["scene_path"]
		var new_weapon_scene = load(path)
		if new_weapon_scene:
			var new_weapon = new_weapon_scene.instantiate()
			player.get_node("WeaponsHolder").add_child(new_weapon)
			player.weapons.append(new_weapon)
			# Initialiser stats niveau 1
			new_weapon.load_stats(1) 
		
	elif option.type == "accessory_new" or option.type == "accessory_upgrade":
		GameData.add_accessory(option.id)
		
		player.accessories.clear()
		for acc_id in GameData.current_accessories.keys():
			if acc_id in GameData.accessory_data:
				var data = GameData.accessory_data[acc_id]
				player.accessories.append(data)
			
		# Force all existing weapons to recalculate stats to apply the passive bonus immediately
		var holder = player.get_node("WeaponsHolder")
		for w in holder.get_children():
			# Reload stats at current level to apply new modifiers
			if w.has_method("load_stats"):
				w.load_stats(w.level)
		player.update_stats()
		# LOG APRES ACCESSOIRES
		_log_all_weapon_stats()

# Vérification du Multi-Leveling (XP Résiduelle)
	# Si le joueur a encore assez d'XP pour le niveau suivant, on enchaîne directement
	if player.experience >= player.experience_required:
		# On appelle level_up() qui va déduire l'XP, augmenter le niveau et émettre le signal 'level_up_triggered'
		# Ce signal va rappeler _on_level_up() dans ce script, régénérant les choix et gardant le jeu en pause.
		player.level_up()
	else:
		# Sinon, on reprend le jeu normalement
		level_up_ui.hide()
		get_tree().paused = false

func _resume_game() -> void:
	level_up_ui.hide()
	get_tree().paused = false
	GameTimer.resume_game()

# --- UTILITAIRES ---
func get_projector_level() -> int:
	var proj = player.get_node_or_null("WeaponsHolder/WeaponProjector")
	if proj:
		return proj.level
	return 0

func upgrade_projector() -> void:
	var proj = player.get_node_or_null("WeaponsHolder/WeaponProjector")
	if proj:
		# On appelle la fonction load_stats du script WeaponProjector qu'on a fait avant
		proj.load_stats(proj.level + 1)

func _on_upgrade_selected() -> void:
	# Plus tard, ici, on vérifiera QUEL bouton a été cliqué pour donner le bonus.
	
	# 1. Cacher le menu
	level_up_ui.hide()
	
	# 2. Reprendre le jeu
	get_tree().paused = false

# --- DEBUG & LOGS ---
func _log_all_weapon_stats() -> void:
	print("\n\n\n================ REPORTING STATS ===================")
	print("Accessoires possédés (", GameData.current_accessories.size(), "/", player.MAX_ACCESSORY_SLOTS, ") : ", GameData.current_accessories.keys())
	
	var holder = player.get_node("WeaponsHolder")
	if holder:
		for w in holder.get_children():
			print("\n>>> ARME : ", GameData.weapon_data[w.id]["name"], " [Niv ", w.level, "]")
			
			# Liste des propriétés standards à vérifier
			var stats_check = ["damage", "cooldown", "amount", "duration", "area", "projectile_speed", "knockback", "crit_chance", "crit_damage"]
			
			for stat in stats_check:
				# get() permet de récupérer la valeur de la variable si elle existe dans le script de l'arme
				var value = w.get(stat) 
				if value != null:
					print("   - ", stat, " : ", value)
				else:
					# Si la variable n'existe pas (ex: 'area' sur une arme qui n'en a pas), on ignore
					pass
	print("====================================================\n\n\n")

# --- LOGIQUE QUALITY OF LIFE (QoL) ---

func _update_qol_buttons_display():
	# Met à jour les textes et l'état (activé/gris) des boutons
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
		btn_banish.disabled = false # On doit pouvoir annuler même si compteur à 0 (cas rare mais sécu)
	else:
		btn_banish.modulate = Color(1, 1, 1) # Blanc normal

func _on_reroll_pressed():
	if player.reroll_count > 0:
		player.reroll_count -= 1
		is_banish_active = false # Sécurité
		
		# On régénère les options
		current_options = generate_upgrade_options()
		
		# On met à jour l'affichage des 3 cartes
		_update_button_display(option_1, current_options[0])
		_update_button_display(option_2, current_options[1])
		_update_button_display(option_3, current_options[2])
		
		_update_qol_buttons_display()

func _on_skip_pressed():
	if player.skip_count > 0:
		player.skip_count -= 1
		_resume_game()

func _on_banish_pressed():
	# Bascule le mode ON/OFF
	is_banish_active = not is_banish_active
	_update_qol_buttons_display()

# --- MODIFICATION DE LA SÉLECTION D'OPTION ---
# Il faut remplacer tes fonctions _on_option_X_pressed existantes par celles-ci
# ou modifier leur contenu pour gérer le bannissement.

func _handle_option_click(index: int):
	var selected_option = current_options[index]
	
	if is_banish_active:
		# MODE BANNISSEMENT
		if player.banish_count > 0:
			
			# 1. On ajoute à la liste noire (sauf si c'est du Soin/Filler)
			if selected_option.type != "heal":
				GameData.banished_items.append(selected_option.id)
				player.banish_count -= 1
			
			# 2. On désactive le mode et on reprend le jeu (comme un Skip)
			is_banish_active = false
			_resume_game()
	else:
		# MODE NORMAL (Choisir l'amélioration)
		_apply_option(selected_option)
		if inventory_hud:
			inventory_hud.update_inventory(player.weapons, player.accessories)
		_resume_game()

# Remplacer les appels directs dans tes fonctions existantes :
func _on_option_1_pressed() -> void:
	_handle_option_click(0)

func _on_option_2_pressed() -> void:
	_handle_option_click(1)

func _on_option_3_pressed() -> void:
	_handle_option_click(2)
