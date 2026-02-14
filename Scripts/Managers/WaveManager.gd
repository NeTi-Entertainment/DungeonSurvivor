extends Node
class_name WaveManager
# WaveManager.gd - Gère le spawn des ennemis en fonction des cycles et du timer

# ============================================================================
# SIGNAUX
# ============================================================================

signal enemy_spawned(enemy: Node2D)

# ============================================================================
# RESSOURCES
# ============================================================================

var enemy_scene = preload("res://Scenes/Entities/Enemies/Enemy.tscn")

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var player: CharacterBody2D
var map_config: MapConfig
var game_scene: Node2D # Référence à la scène Game pour add_child des ennemis

# ============================================================================
# ÉTAT DU SPAWN
# ============================================================================

var current_cycle: int = 1
var is_spawning_active: bool = false
var is_in_silence: bool = false

# Timer de spawn
var spawn_timer: Timer

# ============================================================================
# STATISTIQUES (DEBUG)
# ============================================================================

var total_enemies_spawned: int = 0

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_map_config: MapConfig, p_game_scene: Node2D) -> void:
	"""Initialise le WaveManager avec les références nécessaires"""
	if not p_player or not p_map_config or not p_game_scene:
		push_error("[WaveManager] Setup échoué : Références invalides")
		return
	
	player = p_player
	map_config = p_map_config
	game_scene = p_game_scene
	
	_setup_spawn_timer()
	_connect_to_game_timer()
	
	print("[WaveManager] Initialisé - Map: %s" % map_config.map_name)

func _setup_spawn_timer() -> void:
	"""Crée et configure le timer de spawn"""
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Configure le wait_time initial selon le cycle 1
	_update_spawn_rate()

func _connect_to_game_timer() -> void:
	"""Connecte aux signaux du GameTimer"""
	GameTimer.cycle_changed.connect(_on_cycle_changed)
	GameTimer.silence_started.connect(_on_silence_started)
	GameTimer.silence_ended.connect(_on_silence_ended)

# ============================================================================
# CONTRÔLE DU SPAWN
# ============================================================================

func start_spawning() -> void:
	"""Démarre le spawn d'ennemis"""
	if is_spawning_active:
		push_warning("[WaveManager] Spawn déjà actif")
		return
	
	is_spawning_active = true
	spawn_timer.start()
	print("[WaveManager] Spawn démarré - Cycle %d - Rate: %.2f/s" % [current_cycle, _get_current_spawn_rate()])

func stop_spawning() -> void:
	"""Arrête le spawn d'ennemis"""
	is_spawning_active = false
	spawn_timer.stop()
	print("[WaveManager] Spawn arrêté")

# ============================================================================
# CALLBACKS - GAMETIMER
# ============================================================================

func _on_cycle_changed(cycle_number: int) -> void:
	"""Changement de cycle d'ennemis"""
	current_cycle = cycle_number
	_update_spawn_rate()
	print("[WaveManager] Cycle changé → %d | Nouveau rate: %.2f/s" % [current_cycle, _get_current_spawn_rate()])

func _on_silence_started(duration: float) -> void:
	"""Arrêt du spawn pendant un silence (avant boss)"""
	is_in_silence = true
	stop_spawning()
	print("[WaveManager] Silence démarré - Durée: %.1fs" % duration)

func _on_silence_ended() -> void:
	"""Reprise du spawn après un silence"""
	is_in_silence = false
	if GameTimer.time_remaining <= 120:
		print("[WaveManager] Boss final présent : Les vagues d'ennemis standards sont désactivées définitivement.")
		return
	start_spawning()
	print("[WaveManager] Silence terminé - Reprise du spawn")

# ============================================================================
# LOGIQUE DE SPAWN
# ============================================================================

func _on_spawn_timer_timeout() -> void:
	"""Appelé à chaque tick du spawn timer"""
	if not is_spawning_active or is_in_silence:
		return
	
	_spawn_enemy()

func _spawn_enemy() -> void:
	"""Spawn un ennemi du cycle actuel"""
	# Récupération du pool d'ennemis pour le cycle actif
	var enemy_pool = _get_current_enemy_pool()
	
	if enemy_pool.is_empty():
		push_warning("[WaveManager] Pool d'ennemis vide pour le cycle %d" % current_cycle)
		return
	
	# Sélection aléatoire d'un type d'ennemi
	var enemy_stats = enemy_pool.pick_random()
	
	# Création de l'instance
	var enemy = enemy_scene.instantiate()
	
	# Positionnement (spawn en cercle autour du joueur)
	enemy.global_position = _get_spawn_position()
	
	# Ajout à la scène
	game_scene.add_child(enemy)
	
	# Configuration des stats
	enemy.setup(enemy_stats)
	
	# Stats & signal
	total_enemies_spawned += 1
	enemy_spawned.emit(enemy)

func _get_spawn_position() -> Vector2:
	"""Calcule une position de spawn en cercle autour du joueur"""
	# Angle aléatoire (0 à 360 degrés)
	var angle = randf() * TAU
	
	# Distance de spawn avec variance
	var base_distance = map_config.spawn_distance
	var variance = map_config.spawn_distance_variance
	var distance = base_distance + randf_range(-variance, variance)
	
	# Calcul du vecteur de spawn
	var spawn_offset = Vector2(cos(angle), sin(angle)) * distance
	
	# Position finale = position du joueur + offset
	return player.global_position + spawn_offset

# ============================================================================
# HELPERS
# ============================================================================

func _get_current_enemy_pool() -> Array[EnemyStats]:
	"""Retourne le pool d'ennemis du cycle actif"""
	match current_cycle:
		1: return map_config.enemies_cycle_1
		2: return map_config.enemies_cycle_2
		3: return map_config.enemies_cycle_3
		_: return map_config.enemies_cycle_1

func _get_current_spawn_rate() -> float:
	"""Retourne le spawn rate du cycle actif (ennemis par seconde)"""
	match current_cycle:
		1: return map_config.spawn_rate_cycle_1
		2: return map_config.spawn_rate_cycle_2
		3: return map_config.spawn_rate_cycle_3
		_: return map_config.spawn_rate_cycle_1

func _update_spawn_rate() -> void:
	"""Met à jour le wait_time du timer selon le spawn rate actuel"""
	var rate = _get_current_spawn_rate()
	
	# Conversion : rate = ennemis/seconde → wait_time = secondes/ennemi
	# Ex: 2 ennemis/s → wait_time = 0.5s
	spawn_timer.wait_time = 1.0 / rate

# ============================================================================
# DEBUG
# ============================================================================

func get_stats() -> Dictionary:
	"""Retourne les stats de spawn pour debug"""
	return {
		"total_spawned": total_enemies_spawned,
		"current_cycle": current_cycle,
		"spawn_rate": _get_current_spawn_rate(),
		"is_active": is_spawning_active,
		"is_in_silence": is_in_silence
	}
