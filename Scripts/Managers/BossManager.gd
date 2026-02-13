extends Node
class_name BossManager
# BossManager.gd - Gère le spawn des boss aux checkpoints
# IMPORTANT : Plusieurs boss peuvent coexister si le joueur est lent à les tuer

# ============================================================================
# SIGNAUX
# ============================================================================

signal boss_spawned(boss: Node2D, minute: int)
signal boss_defeated(boss: Node2D, minute: int)
signal final_boss_defeated() # Signal spécial pour le boss de 18min

# ============================================================================
# RESSOURCES
# ============================================================================

var enemy_scene = preload("res://Scenes/Entities/Enemies/Enemy.tscn")

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var player: CharacterBody2D
var map_config: MapConfig
var game_scene: Node2D

# ============================================================================
# ÉTAT
# ============================================================================

# Tracking des boss actifs uniquement (pour pouvoir en avoir plusieurs simultanément)
var active_bosses: Array[Node2D] = []

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_map_config: MapConfig, p_game_scene: Node2D) -> void:
	"""Initialise le BossManager avec les références nécessaires"""
	if not p_player or not p_map_config or not p_game_scene:
		push_error("[BossManager] Setup échoué : Références invalides")
		return
	
	player = p_player
	map_config = p_map_config
	game_scene = p_game_scene
	
	_connect_to_game_timer()
	
	print("[BossManager] Initialisé - Map: %s" % map_config.map_name)

func _connect_to_game_timer() -> void:
	"""Connecte aux signaux du GameTimer"""
	GameTimer.boss_checkpoint.connect(_on_boss_checkpoint)

# ============================================================================
# CALLBACKS - GAMETIMER
# ============================================================================

func _on_boss_checkpoint(minute: int) -> void:
	"""Spawn d'un boss au checkpoint spécifié - SANS CONDITIONS"""
	# Récupération des stats du boss depuis MapConfig
	var boss_stats = _get_boss_stats_for_checkpoint(minute)
	
	if not boss_stats:
		push_warning("[BossManager] Pas de boss assigné dans MapConfig pour le checkpoint %dmin" % minute)
		return
	
	_spawn_boss(boss_stats, minute)

# ============================================================================
# LOGIQUE DE SPAWN
# ============================================================================

func _spawn_boss(boss_stats: EnemyStats, minute: int) -> void:
	"""Spawn un boss avec les stats fournies"""
	# Création de l'instance
	var boss = enemy_scene.instantiate()
	
	# Marquer comme boss AVANT setup()
	boss.is_boss = true
	
	# Positionnement aléatoire (même logique que les ennemis normaux)
	boss.global_position = _get_random_spawn_position()
	
	# Ajout à la scène
	game_scene.add_child(boss)
	
	# Configuration des stats (charge depuis le .tres assigné dans MapConfig)
	boss.setup(boss_stats)
	
	# Connexion à la mort du boss
	if boss.has_signal("enemy_died"):
		boss.enemy_died.connect(_on_boss_died.bind(minute))
	
	# Tracking
	active_bosses.append(boss)
	
	# Signaux
	boss_spawned.emit(boss, minute)
	
	print("[BossManager] Boss spawné - Checkpoint %dmin : %s (HP: %d)" % [minute, boss_stats.name, boss_stats.max_hp])

func _get_random_spawn_position() -> Vector2:
	"""Position aléatoire en cercle autour du joueur (comme WaveManager)"""
	var angle = randf() * TAU
	var distance = map_config.spawn_distance + randf_range(-map_config.spawn_distance_variance, map_config.spawn_distance_variance)
	var spawn_offset = Vector2(cos(angle), sin(angle)) * distance
	return player.global_position + spawn_offset

# ============================================================================
# CALLBACKS - BOSS DEATH
# ============================================================================

func _on_boss_died(boss: Node2D, minute: int) -> void:
	"""Appelé quand un boss meurt"""
	# Retrait du tracking
	active_bosses.erase(boss)
	
	# Signaux
	boss_defeated.emit(boss, minute)
	
	# Cas spécial : Boss final (18min) → Déclenche la victoire
	if minute == 18:
		final_boss_defeated.emit()
		print("[BossManager] BOSS FINAL VAINCU ! Portail de victoire disponible")
	else:
		print("[BossManager] Boss vaincu - Checkpoint %dmin" % minute)

# ============================================================================
# HELPERS
# ============================================================================

func _get_boss_stats_for_checkpoint(minute: int) -> EnemyStats:
	"""Retourne les stats du boss pour un checkpoint donné (depuis MapConfig)"""
	match minute:
		3: return map_config.boss_3min
		6: return map_config.boss_6min
		9: return map_config.boss_9min
		12: return map_config.boss_12min
		15: return map_config.boss_15min
		18: return map_config.boss_18min
		_: return null

func get_active_boss_count() -> int:
	"""Retourne le nombre de boss actuellement actifs"""
	return active_bosses.size()

# ============================================================================
# DEBUG
# ============================================================================

func get_stats() -> Dictionary:
	"""Retourne les stats de boss pour debug"""
	return {
		"active_count": active_bosses.size()
	}
