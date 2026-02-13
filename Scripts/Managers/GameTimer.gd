extends Node
# GameTimer.gd - Singleton qui gère TOUT le timing du jeu
# AutoLoad requis : Project Settings → AutoLoad → Name: "GameTimer"

# ============================================================================
# SIGNAUX
# ============================================================================

# Émis chaque seconde pour mettre à jour l'UI
signal time_updated(seconds_remaining: int, formatted_time: String)

# Émis quand on change de cycle d'ennemis (6min et 12min)
signal cycle_changed(cycle_number: int)

# Émis avant les boss pour arrêter le spawn (silence)
signal silence_started(duration: float)
signal silence_ended()

# Émis quand un boss doit spawn
signal boss_checkpoint(minute: int)

# Émis quand le timer principal atteint 00:00
signal game_time_over()

# Émis quand le mode Reaper démarre (après refus du portail)
signal reaper_mode_started()

# ============================================================================
# ÉTATS
# ============================================================================

enum GamePhase { NORMAL, TIME_UP, REAPER_MODE }

# ============================================================================
# CONSTANTES
# ============================================================================

const GAME_DURATION: int = 1200  # 20 minutes en secondes
const CYCLE_2_START: int = 360   # 6 minutes (1200 - 840)
const CYCLE_3_START: int = 720   # 12 minutes (1200 - 480)

# Checkpoints des boss (en minutes, pas en secondes)
const BOSS_CHECKPOINTS: Array[int] = [3, 6, 9, 12, 15, 18]

# Durée des silences avant chaque boss (en secondes)
# Format: {minute_du_boss: durée_du_silence}
const SILENCE_DURATIONS: Dictionary = {
	3: 10.0,   # 10s de silence avant boss de 3min
	6: 15.0,   # 15s de silence avant boss de 6min
	9: 15.0,
	12: 20.0,
	15: 20.0,
	18: 30.0   # 30s avant le boss final
}

# ============================================================================
# VARIABLES D'ÉTAT
# ============================================================================

var current_phase: GamePhase = GamePhase.NORMAL
var is_running: bool = false
var time_remaining: int = GAME_DURATION
var reaper_time_elapsed: int = 0  # Temps écoulé en mode Reaper (compte à l'envers)

# Tracking des événements déjà déclenchés
var triggered_cycles: Array[int] = []
var triggered_bosses: Array[int] = []
var is_in_silence: bool = false

# Timer interne
var _tick_timer: Timer

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_timer()

func _setup_timer() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0  # Tick toutes les secondes
	_tick_timer.one_shot = false
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func start_game() -> void:
	"""Démarre le timer de jeu (appelé au lancement d'une run)"""
	if is_running:
		push_warning("GameTimer: start_game() appelé alors que le timer tourne déjà")
		return
	
	# Reset complet
	current_phase = GamePhase.NORMAL
	time_remaining = GAME_DURATION
	reaper_time_elapsed = 0
	triggered_cycles.clear()
	triggered_bosses.clear()
	is_in_silence = false
	
	is_running = true
	_tick_timer.start()
	
	# Émission initiale pour l'UI
	time_updated.emit(time_remaining, _format_time(time_remaining))
	
	print("[GameTimer] Jeu démarré - Durée: %d secondes" % GAME_DURATION)

func stop_game() -> void:
	"""Arrête le timer (fin de run, retour au menu)"""
	is_running = false
	_tick_timer.stop()
	print("[GameTimer] Timer arrêté")

func pause_game() -> void:
	"""Met en pause le timer (menu pause, level-up)"""
	if not is_running:
		return
	_tick_timer.paused = true

func resume_game() -> void:
	"""Reprend le timer après une pause"""
	if not is_running:
		return
	_tick_timer.paused = false

func start_reaper_mode() -> void:
	"""Active le mode Reaper (portail refusé)"""
	if current_phase == GamePhase.REAPER_MODE:
		push_warning("GameTimer: Mode Reaper déjà actif")
		return
	
	current_phase = GamePhase.REAPER_MODE
	reaper_time_elapsed = 0
	reaper_mode_started.emit()
	
	print("[GameTimer] MODE REAPER ACTIVÉ - Timer inversé démarré")

# ============================================================================
# GETTERS
# ============================================================================

func get_current_cycle() -> int:
	"""Retourne le cycle d'ennemis actuel (1, 2 ou 3)"""
	var elapsed = GAME_DURATION - time_remaining
	
	if elapsed < CYCLE_2_START:
		return 1
	elif elapsed < CYCLE_3_START:
		return 2
	else:
		return 3

func get_formatted_time() -> String:
	"""Retourne le temps formaté (MM:SS)"""
	if current_phase == GamePhase.REAPER_MODE:
		return _format_time(reaper_time_elapsed)
	else:
		return _format_time(time_remaining)

func is_game_running() -> bool:
	return is_running

func get_game_phase() -> GamePhase:
	return current_phase

# ============================================================================
# LOGIQUE INTERNE
# ============================================================================

func _on_tick() -> void:
	"""Appelé toutes les secondes"""
	if not is_running:
		return
	
	match current_phase:
		GamePhase.NORMAL:
			_handle_normal_phase()
		GamePhase.TIME_UP:
			# Phase transitoire - rien à faire ici
			pass
		GamePhase.REAPER_MODE:
			_handle_reaper_phase()

func _handle_normal_phase() -> void:
	"""Gestion du timer en phase normale (20:00 → 00:00)"""
	time_remaining -= 1
	
	# Mise à jour UI
	time_updated.emit(time_remaining, _format_time(time_remaining))
	
	# Calcul du temps écoulé (pour les checkpoints)
	var elapsed_seconds = GAME_DURATION - time_remaining
	var _elapsed_minutes = elapsed_seconds / 60
	
	# ========================================
	# 1. VÉRIFICATION CHANGEMENTS DE CYCLE
	# ========================================
	var current_cycle = get_current_cycle()
	if current_cycle not in triggered_cycles:
		triggered_cycles.append(current_cycle)
		if current_cycle > 1:  # Pas de signal pour le cycle 1 (début de jeu)
			cycle_changed.emit(current_cycle)
			print("[GameTimer] Cycle changé → Cycle %d" % current_cycle)
	
	# ========================================
	# 2. VÉRIFICATION BOSS CHECKPOINTS
	# ========================================
	for boss_minute in BOSS_CHECKPOINTS:
		if boss_minute in triggered_bosses:
			continue  # Déjà traité
		
		var boss_time = boss_minute * 60  # Conversion en secondes
		var silence_duration = SILENCE_DURATIONS.get(boss_minute, 10.0)
		var silence_start_time = boss_time - int(silence_duration)
		
		# Déclenchement du silence AVANT le boss
		if elapsed_seconds == silence_start_time and not is_in_silence:
			is_in_silence = true
			silence_started.emit(silence_duration)
			print("[GameTimer] Silence démarré - Durée: %.1fs avant boss de %dmin" % [silence_duration, boss_minute])
		
		# Déclenchement du boss (fin du silence)
		if elapsed_seconds == boss_time:
			is_in_silence = false
			triggered_bosses.append(boss_minute)
			silence_ended.emit()
			boss_checkpoint.emit(boss_minute)
			print("[GameTimer] BOSS CHECKPOINT → %d minutes" % boss_minute)
	
	# ========================================
	# 3. FIN DU TIMER (00:00)
	# ========================================
	if time_remaining <= 0:
		current_phase = GamePhase.TIME_UP
		game_time_over.emit()
		print("[GameTimer] TEMPS ÉCOULÉ - Passage en phase TIME_UP")
		# Note: Le VictoryManager va spawner le portail ici

func _handle_reaper_phase() -> void:
	"""Gestion du timer inversé en mode Reaper (00:00 → 00:01 → 00:02...)"""
	reaper_time_elapsed += 1
	
	# Mise à jour UI avec le temps POSITIF
	time_updated.emit(reaper_time_elapsed, _format_time(reaper_time_elapsed))

func _format_time(seconds: int) -> String:
	"""Convertit les secondes en format MM:SS"""
	var mins = seconds / 60
	var secs = seconds % 60
	return "%02d:%02d" % [mins, secs]

# ============================================================================
# DEBUG / TESTS
# ============================================================================

func force_trigger_boss(minute: int) -> void:
	"""[DEBUG] Force le déclenchement d'un boss manuellement"""
	if minute not in BOSS_CHECKPOINTS:
		push_error("GameTimer: Minute %d n'est pas un checkpoint valide" % minute)
		return
	
	boss_checkpoint.emit(minute)
	print("[GameTimer] [DEBUG] Boss de %dmin forcé" % minute)

func force_time_over() -> void:
	"""[DEBUG] Force la fin du temps immédiatement"""
	time_remaining = 0
	current_phase = GamePhase.TIME_UP
	game_time_over.emit()
	print("[GameTimer] [DEBUG] Fin de temps forcée")
