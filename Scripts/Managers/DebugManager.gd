extends Node
class_name DebugManager
# DebugManager.gd - Outils de debug pour tester rapidement
# À RETIRER EN PRODUCTION ou désactiver via une constante

# ============================================================================
# CONFIGURATION
# ============================================================================

const DEBUG_ENABLED: bool = true  # Mettre à false pour désactiver en prod

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var player: CharacterBody2D = null
var game_scene: Node2D = null

# ============================================================================
# ÉTAT
# ============================================================================

var god_mode_active: bool = false
var one_shot_mode_active: bool = false

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_game_scene: Node2D) -> void:
	"""Initialise le DebugManager"""
	if not DEBUG_ENABLED:
		return
	
	player = p_player
	game_scene = p_game_scene
	
	print("\n=== DEBUG MANAGER ACTIVÉ ===")
	print("F1  : Passer à 17:30 (30s avant boss final)")
	print("F2  : Passer à 19:30 (30s après victoire)")
	print("F3  : Toggle God Mode (immortalité)")
	print("F4  : Toggle One-Shot Mode (ennemis meurent en 1 coup)")
	print("F5  : Ralentir le jeu (x0.5)")
	print("F6  : Vitesse normale (x1.0)")
	print("F7  : Accélérer le jeu (x2.0)")
	print("9   : Accélérer le jeu (x5.0)  [CHANGÉ: était F8]")
	print("F9  : Kill tous les ennemis à l'écran")
	print("F10 : Heal joueur au max")
	print("0   : +1 niveau joueur  [CHANGÉ: était F11 avec +10 niveaux]")
	print("F12 : Force victoire immédiate")
	print("============================\n")

func _input(event: InputEvent) -> void:
	"""Gestion des raccourcis clavier de debug"""
	if not DEBUG_ENABLED:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_jump_to_time(1045)  # 17:30 (30s avant boss final)
			KEY_F2:
				_jump_to_time(1230)  # 19:30 (après boss, avant reapers)
			KEY_F3:
				_toggle_god_mode()
			KEY_F4:
				_toggle_one_shot_mode()
			KEY_F5:
				_set_game_speed(0.5)
			KEY_F6:
				_set_game_speed(1.0)
			KEY_F7:
				_set_game_speed(2.0)
			KEY_9:  # Changé de F8 à 9 (F8 = touche système Godot)
				_set_game_speed(5.0)
			KEY_F9:
				_kill_all_enemies()
			KEY_F10:
				_heal_player()
			KEY_0:  # Changé de F11 à 0 (+1 niveau au lieu de +10)
				_add_player_levels(1)
			KEY_F12:
				_force_victory()

# ============================================================================
# FONCTIONS DE DEBUG
# ============================================================================

func _jump_to_time(target_seconds: int) -> void:
	"""Saute à un temps spécifique (0-1200)"""
	if not GameTimer:
		print("[Debug] GameTimer non trouvé")
		return
	
	GameTimer.time_remaining = GameTimer.GAME_DURATION - target_seconds
	
	var formatted = GameTimer.get_formatted_time()
	print("[Debug] Temps sauté → %s" % formatted)

func _toggle_god_mode() -> void:
	"""Active/désactive l'immortalité du joueur"""
	if not player:
		return
	
	god_mode_active = !god_mode_active
	
	player.is_god_mode = god_mode_active
	
	print("[Debug] God Mode : %s" % ("ON" if god_mode_active else "OFF"))

func _toggle_one_shot_mode() -> void:
	"""Active/désactive le mode one-shot (ennemis meurent en 1 coup)"""
	one_shot_mode_active = !one_shot_mode_active
	GameData.debug_one_shot_mode = one_shot_mode_active
	
	print("[Debug] One-Shot Mode : %s" % ("ON" if one_shot_mode_active else "OFF"))

func _set_game_speed(speed: float) -> void:
	"""Change la vitesse du jeu"""
	Engine.time_scale = speed
	print("[Debug] Vitesse de jeu : x%.1f" % speed)

func _kill_all_enemies() -> void:
	"""Tue tous les ennemis à l'écran"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = enemies.size()
	
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(999999)
	
	print("[Debug] %d ennemis tués" % count)

func _heal_player() -> void:
	"""Soigne le joueur au max"""
	if not player:
		return
	
	if player.has("current_health") and player.has("max_health"):
		player.current_health = player.max_health
		if player.has("health_bar"):
			player.health_bar.value = player.max_health
	
	print("[Debug] Joueur soigné au max")

func _add_player_levels(amount: int) -> void:
	"""Ajoute des niveaux au joueur"""
	if not player:
		return
	
	if player.has_method("level_up"):
		for i in range(amount):
			# On donne l'XP nécessaire pour level up
			if player.has("experience") and player.has("experience_required"):
				player.experience = player.experience_required
				player.level_up()
	
	print("[Debug] +%d niveaux ajoutés" % amount)

func _force_victory() -> void:
	"""Force la victoire immédiatement"""
	# Option 1 : Via BossManager si disponible
	if game_scene.has("boss_manager") and game_scene.boss_manager:
		game_scene.boss_manager.final_boss_defeated.emit()
		print("[Debug] Victoire forcée (via BossManager)")
		return
	
	# Option 2 : Via VictoryManager si disponible
	if game_scene.has("victory_manager") and game_scene.victory_manager:
		if game_scene.victory_manager.has_method("force_victory"):
			game_scene.victory_manager.force_victory()
			print("[Debug] Victoire forcée (via VictoryManager)")
			return
	
	print("[Debug] Impossible de forcer la victoire (managers non trouvés)")

# ============================================================================
# HELPERS
# ============================================================================

func is_god_mode_active() -> bool:
	return god_mode_active

func is_one_shot_mode_active() -> bool:
	return one_shot_mode_active
