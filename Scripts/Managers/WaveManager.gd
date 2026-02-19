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

const MIN_SPAWN_INTERVAL: float = 0.20

#var current_cycle: int = 1
var is_spawning_active: bool = false
var is_in_silence: bool = false

# Timer de spawn
var spawn_timer: Timer

# Gestion des patterns
var current_phase_idx: int = -1
var active_phase: SpawnPhase = null

# Timers internes pour les patterns (en secondes absolues du GameTimer)
var next_pack_time: float = 0.0
var next_circle_time: float = 0.0
var next_line_time: float = 0.0

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
	
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	GameTimer.silence_started.connect(_on_silence_started)
	GameTimer.silence_ended.connect(_on_silence_ended)
	
	print("[WaveManager] Initialisé - Map: %s" % map_config.map_name)

# ============================================================================
# CONTRÔLE DU SPAWN
# ============================================================================

func start_spawning() -> void:
	"""Démarre le spawn d'ennemis"""
	if is_spawning_active:
		push_warning("[WaveManager] Spawn déjà actif")
		return
	
	is_spawning_active = true
	_update_phase_and_timers()
	spawn_timer.start()

func stop_spawning() -> void:
	"""Arrête le spawn d'ennemis"""
	is_spawning_active = false
	spawn_timer.stop()

# ============================================================================
# CALLBACKS - GAMETIMER
# ============================================================================

func _on_silence_started(duration: float) -> void:
	"""Arrêt du spawn pendant un silence (avant boss)"""
	is_in_silence = true
	print("[WaveManager] Silence démarré - Durée: %.1fs" % duration)

func _on_silence_ended() -> void:
	"""Reprise du spawn après un silence"""
	is_in_silence = false
	if GameTimer.time_remaining <= 120:
		print("[WaveManager] Boss final présent : Les vagues d'ennemis standards sont désactivées définitivement.")
		return
	_update_phase_and_timers()
	print("[WaveManager] Silence terminé - Reprise du spawn")

# ============================================================================
# LOGIQUE DE SPAWN
# ============================================================================

func _physics_process(_delta: float) -> void:
	if not is_spawning_active or is_in_silence:
		return
		
	var current_time = GameTimer.get_elapsed_time()
	
	# Vérification si la phase a changé
	var new_phase = _get_active_phase(current_time)
	if new_phase != active_phase:
		active_phase = new_phase
		_on_phase_changed(current_time)
	
	if not active_phase:
		return

	# --- GESTION DES PATTERNS SPÉCIAUX ---
	
	# 1. MEUTE (PACK)
	if active_phase.pack_enabled and current_time >= next_pack_time:
		_spawn_pack_pattern()
		next_pack_time = current_time + _get_effective_interval(active_phase.pack_interval)
		
	# 2. CERCLE
	if active_phase.circle_enabled and current_time >= next_circle_time:
		_spawn_circle_pattern()
		next_circle_time = current_time + _get_effective_interval(active_phase.circle_interval)
		
	# 3. LIGNE
	if active_phase.line_enabled and current_time >= next_line_time:
		_spawn_line_pattern()
		next_line_time = current_time + _get_effective_interval(active_phase.line_interval)

func _on_spawn_timer_timeout() -> void:
	if not is_spawning_active or is_in_silence:
		return
		
	if active_phase:
		spawn_timer.wait_time = _get_effective_interval(active_phase.spawn_interval)
		spawn_timer.start()
		
		# Spawn normal (Background noise)
		var enemy_stats = active_phase.get_random_enemy()
		if enemy_stats:
			_spawn_enemy(enemy_stats)
	else:
		# Si aucune phase, on checke plus lentement
		spawn_timer.wait_time = 1.0
		spawn_timer.start()

# --- LOGIQUE DE CHANGEMENT DE PHASE ---

func _get_active_phase(current_time: int) -> SpawnPhase:
	for phase in map_config.spawn_phases:
		if current_time >= phase.start_time and current_time < phase.end_time:
			return phase
	
	if not map_config.spawn_phases.is_empty() and current_time >= map_config.spawn_phases[-1].end_time:
		return map_config.spawn_phases[-1]
		
	return null

func _on_phase_changed(current_time: float) -> void:
	if not active_phase: return
	
	# Mise à jour du timer de base
	spawn_timer.wait_time = _get_effective_interval(active_phase.spawn_interval)
	if spawn_timer.is_stopped():
		spawn_timer.start()
		
	# Initialisation des timers de patterns pour qu'ils ne pop pas INSTANTANÉMENT au début de la phase
	# On leur donne leur délai respectif à partir de MAINTENANT
	next_pack_time = current_time + _get_effective_interval(active_phase.pack_interval)
	next_circle_time = current_time + _get_effective_interval(active_phase.circle_interval)
	next_line_time = current_time + _get_effective_interval(active_phase.line_interval)

func _update_phase_and_timers() -> void:
	# Force la mise à jour immédiate (utile après un Silence ou Start)
	var t = GameTimer.get_elapsed_time()
	active_phase = _get_active_phase(t)
	if active_phase:
		spawn_timer.wait_time = _get_effective_interval(active_phase.spawn_interval)
		if spawn_timer.is_stopped(): spawn_timer.start()

# --- SPAWNERS SPÉCIFIQUES ---

func _spawn_pack_pattern() -> void:
	if not player or not active_phase: return
	
	var center_pos = _get_random_position_around_player()
	var count = randi_range(active_phase.pack_min_size, active_phase.pack_max_size)
	
	var stats = active_phase.pack_enemy
	if not stats:
		stats = active_phase.get_random_enemy()
	
	if not stats: return

	for i in range(count):
		# Position aléatoire dans le rayon du pack
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, active_phase.pack_radius)
		var spawn_pos = center_pos + offset
		_instantiate_enemy_at(stats, spawn_pos)

func _spawn_circle_pattern() -> void:
	if not player or not active_phase: return
	
	var count = active_phase.circle_enemy_count
	var radius = active_phase.circle_radius
	
	var stats = active_phase.circle_enemy
	if not stats:
		stats = active_phase.get_random_enemy()
	
	if not stats: return
	
	var angle_step = TAU / count
	var player_pos = player.global_position
	
	for i in range(count):
		var angle = i * angle_step
		var spawn_pos = player_pos + Vector2(cos(angle), sin(angle)) * radius
		_instantiate_enemy_at(stats, spawn_pos)

func _spawn_line_pattern() -> void:
	if not player or not active_phase: return
	
	var count = active_phase.enemies_per_line
	
	var stats = active_phase.line_enemy
	if not stats:
		stats = active_phase.get_random_enemy()
	
	if not stats: return
	
	# Choisir un côté (0: Haut, 1: Droite, 2: Bas, 3: Gauche)
	var side = randi() % 4
	var screen_rect = get_viewport().get_visible_rect()
	var size = screen_rect.size
	var origin = player.global_position # On centre la ligne relative au joueur ou à l'écran ? Relative joueur c'est mieux.
	
	# Distance pour être hors écran
	var offset_dist = max(size.x, size.y) * 0.7 
	
	var start_pos = Vector2.ZERO
	var step_vec = Vector2.ZERO
	
	# On crée une ligne de 800px de large par exemple
	var line_width = 1000.0
	var step = line_width / count
	
	match side:
		0: # Haut (Arrive du haut)
			start_pos = origin + Vector2(-line_width/2, -offset_dist)
			step_vec = Vector2(step, 0)
		1: # Droite (Arrive de droite)
			start_pos = origin + Vector2(offset_dist, -line_width/2)
			step_vec = Vector2(0, step)
		2: # Bas
			start_pos = origin + Vector2(-line_width/2, offset_dist)
			step_vec = Vector2(step, 0)
		3: # Gauche
			start_pos = origin + Vector2(-offset_dist, -line_width/2)
			step_vec = Vector2(0, step)
			
	for i in range(count):
		var pos = start_pos + (step_vec * i)
		_instantiate_enemy_at(stats, pos)

# --- BASE SPAWNER ---

func _spawn_enemy(stats: EnemyStats) -> void:
	var pos = _get_random_position_around_player()
	_instantiate_enemy_at(stats, pos)

func _instantiate_enemy_at(stats: EnemyStats, pos: Vector2) -> void:
	if not game_scene or not stats: return
	
	var new_enemy = enemy_scene.instantiate()
	new_enemy.global_position = pos
	
	game_scene.add_child(new_enemy)
	new_enemy.setup(stats)
	
	total_enemies_spawned += 1
	enemy_spawned.emit(new_enemy)

func _get_random_position_around_player() -> Vector2:
	if not player: return Vector2.ZERO
	
	# Spawn sur un anneau autour du joueur (hors écran mais pas trop loin)
	var viewport_rect = get_viewport().get_visible_rect()
	var spawn_radius = max(viewport_rect.size.x, viewport_rect.size.y) * 0.6
	
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	
	return player.global_position + offset

func get_stats() -> Dictionary:
	return {
		"total_spawned": total_enemies_spawned,
		"active_phase": active_phase.resource_path if active_phase else "None"
	}

# HELPERS

func _get_enemy_amount_multiplier() -> float:
	"""Lit le multiplicateur de quantité d'ennemis depuis le joueur.
	Retourne 1.0 si le joueur n'est pas valide (aucun effet)."""
	if is_instance_valid(player) and "enemy_amount_multiplier" in player:
		return player.enemy_amount_multiplier
	return 1.0

func _get_effective_interval(base_interval: float) -> float:
	"""Applique le multiplicateur War Banner à un intervalle, avec cap de sécurité.
	Plus le multiplicateur est élevé, plus l'intervalle est court (plus de spawns)."""
	var mult = _get_enemy_amount_multiplier()
	return max(MIN_SPAWN_INTERVAL, base_interval / mult)
