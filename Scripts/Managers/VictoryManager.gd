extends Node
class_name VictoryManager
# VictoryManager.gd - Gère la victoire, le portail, et le spawn des Reapers

# ============================================================================
# SIGNAUX
# ============================================================================

signal portal_used() # Émis quand le joueur utilise le portail

# ============================================================================
# RESSOURCES
# ============================================================================

var portal_scene = preload("res://Scenes/Entities/Neutrals/VictoryPortal.tscn")
var enemy_scene = preload("res://Scenes/Entities/Enemies/Enemy.tscn")

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var player: CharacterBody2D
var map_config: MapConfig
var game_scene: Node2D
var victory_ui: Control  # Référence au UI de victoire dans Game

# ============================================================================
# ÉTAT
# ============================================================================

var portal_instance: Node2D = null
var is_victory_achieved: bool = false
var is_reaper_mode_active: bool = false

# Position où spawner le portail (position de mort du boss final)
var boss_death_position: Vector2 = Vector2.ZERO

# Reaper stats (sera chargé depuis MapConfig ou créé dynamiquement)
var reaper_stats: EnemyStats = null

# Timer pour le spawn continu des Reapers
var reaper_spawn_timer: Timer

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_map_config: MapConfig, p_game_scene: Node2D, p_victory_ui: Control) -> void:
	"""Initialise le VictoryManager avec les références nécessaires"""
	if not p_player or not p_map_config or not p_game_scene or not p_victory_ui:
		push_error("[VictoryManager] Setup échoué : Références invalides")
		return
	
	player = p_player
	map_config = p_map_config
	game_scene = p_game_scene
	victory_ui = p_victory_ui
	
	_setup_reaper_spawn_timer()
	_connect_signals()
	
	print("[VictoryManager] Initialisé")

func _setup_reaper_spawn_timer() -> void:
	"""Crée le timer de spawn des Reapers"""
	reaper_spawn_timer = Timer.new()
	reaper_spawn_timer.wait_time = 0.5  # Spawn toutes les 0.5s (spawn massif)
	reaper_spawn_timer.one_shot = false
	reaper_spawn_timer.timeout.connect(_spawn_reaper)
	add_child(reaper_spawn_timer)

func _connect_signals() -> void:
	"""Connecte aux signaux externes"""
	# Connexion à GameTimer pour le reaper_time
	GameTimer.reaper_time.connect(_on_reaper_time)

# ============================================================================
# CALLBACKS EXTERNES
# ============================================================================

func on_final_boss_defeated(boss_position: Vector2) -> void:
	"""Appelé par Game.gd quand le boss final meurt"""
	if is_victory_achieved:
		return  # Déjà géré
	
	is_victory_achieved = true
	boss_death_position = boss_position
	
	# 1. Afficher le titre VICTORY
	_show_victory_title()
	
	# 2. Spawn le portail à la position du boss mort
	_spawn_portal()
	
	# 3. Activer le mode POST_VICTORY du GameTimer
	GameTimer.start_post_victory_mode()
	
	print("[VictoryManager] VICTOIRE - Boss final vaincu")

func _on_reaper_time() -> void:
	"""Appelé à 00:30 après la victoire"""
	# 1. Faire disparaître le portail
	_despawn_portal()
	
	# 2. Démarrer le spawn des Reapers
	_start_reaper_spawn()
	
	print("[VictoryManager] REAPER TIME - Portail disparu, Reapers activés")

# ============================================================================
# VICTORY UI
# ============================================================================

func _show_victory_title() -> void:
	"""Affiche le titre VICTORY en haut de l'écran"""
	if victory_ui:
		victory_ui.show()
	else:
		push_warning("[VictoryManager] Pas de victory_ui assigné")

# ============================================================================
# PORTAIL
# ============================================================================

func _spawn_portal() -> void:
	"""Spawn le portail à la position de mort du boss final"""
	portal_instance = portal_scene.instantiate()
	portal_instance.global_position = boss_death_position
	game_scene.add_child(portal_instance)
	
	# Connexion au signal d'activation du portail
	if portal_instance.has_signal("portal_activated"):
		portal_instance.portal_activated.connect(_on_portal_activated)
	
	print("[VictoryManager] Portail spawné à position: %s" % boss_death_position)

func _despawn_portal() -> void:
	"""Fait disparaître le portail (à 00:30)"""
	if portal_instance and is_instance_valid(portal_instance):
		portal_instance.queue_free()
		portal_instance = null
		print("[VictoryManager] Portail disparu")

func _on_portal_activated() -> void:
	"""Appelé quand le joueur utilise le portail (touche E)"""
	print("[VictoryManager] Portail utilisé - Fin de partie")
	portal_used.emit()
	
	# Sauvegarde des ressources (victoire = 100%)
	GameData.finalize_run(true, 1.0)
	
	# Arrêt du GameTimer
	GameTimer.stop_game()
	
	# Affichage de l'écran de fin
	_show_end_screen()

# ============================================================================
# REAPERS
# ============================================================================

func _start_reaper_spawn() -> void:
	"""Démarre le spawn continu des Reapers"""
	is_reaper_mode_active = true
	
	# Chargement des stats du Reaper
	reaper_stats = _get_reaper_stats()
	
	if not reaper_stats:
		push_error("[VictoryManager] Impossible de charger les stats du Reaper")
		return
	
	# Démarrage du timer de spawn
	reaper_spawn_timer.start()
	
	print("[VictoryManager] Spawn des Reapers démarré")

func _spawn_reaper() -> void:
	"""Spawn un Reaper autour du joueur"""
	if not is_reaper_mode_active or not reaper_stats:
		return
	
	# Création de l'instance
	var reaper = enemy_scene.instantiate()
	
	# Marquer comme boss (pour éviter qu'il soit one-shot par des buffs)
	reaper.is_boss = true
	
	# Positionnement aléatoire
	reaper.global_position = _get_random_spawn_position()
	
	# Ajout à la scène
	game_scene.add_child(reaper)
	
	# Configuration des stats
	reaper.setup(reaper_stats)

func _get_random_spawn_position() -> Vector2:
	"""Position aléatoire en cercle autour du joueur"""
	var angle = randf() * TAU
	var distance = map_config.spawn_distance
	var spawn_offset = Vector2(cos(angle), sin(angle)) * distance
	return player.global_position + spawn_offset

func _get_reaper_stats() -> EnemyStats:
	"""Retourne les stats du Reaper (depuis MapConfig ou création dynamique)"""
	# Option 1 : Charger depuis MapConfig (si tu as créé un champ reaper_stats)
	if map_config.has("reaper_stats") and map_config.reaper_stats:
		return map_config.reaper_stats
	
	# Option 2 : Création dynamique (stats hardcodées pour l'instant)
	# Tu devras créer un fichier Reaper.tres plus tard
	push_warning("[VictoryManager] Pas de reaper_stats dans MapConfig, création dynamique")
	return _create_default_reaper_stats()

func _create_default_reaper_stats() -> EnemyStats:
	"""Crée des stats de Reaper par défaut (temporaire)"""
	var stats = EnemyStats.new()
	stats.id = "reaper"
	stats.name = "Reaper"
	stats.max_hp = 999999  # Quasi-immortel
	stats.armor = 999
	stats.knockback_resistance = 1.0  # Ne recule pas
	stats.damage = 100  # One-shot ou presque
	stats.speed = 400.0  # Plus rapide que le joueur
	stats.scale = 2.0  # Plus gros
	# texture sera null, donc affichage par défaut
	return stats

# ============================================================================
# END SCREEN
# ============================================================================

func _show_end_screen() -> void:
	"""Affiche l'écran de fin simple avec bouton menu"""
	# Pour l'instant, on affiche juste l'UI de victoire avec le bouton
	# L'écran de score détaillé sera fait plus tard
	
	# Pause du jeu
	get_tree().paused = true
	
	# Affichage de l'UI (qui contient déjà le bouton retour menu)
	victory_ui.show()
	
	# Cacher le titre VICTORY, afficher le bouton
	if victory_ui.has_node("VictoryTitle"):
		victory_ui.get_node("VictoryTitle").hide()
	if victory_ui.has_node("EndScreenPanel"):
		victory_ui.get_node("EndScreenPanel").show()

# ============================================================================
# DEBUG
# ============================================================================

func force_victory() -> void:
	"""[DEBUG] Force la victoire immédiatement"""
	on_final_boss_defeated(player.global_position)

func force_reaper_time() -> void:
	"""[DEBUG] Force le spawn des Reapers immédiatement"""
	_on_reaper_time()
