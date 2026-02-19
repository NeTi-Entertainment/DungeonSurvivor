extends Node
class_name GameStateManager
# GameStateManager.gd - Gère les transitions d'état (Victory, GameOver, Pause)

# ============================================================================
# SIGNAUX
# ============================================================================

signal game_ended() # Émis quand le jeu se termine (victory ou gameover)

# ============================================================================
# RÉFÉRENCES (injectées depuis Game.gd)
# ============================================================================

var player: CharacterBody2D
var game_over_ui: Control
var victory_ui: Control
var button_return: Button
var button_victory_return: Button

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_game_over_ui: Control, p_victory_ui: Control,
		   p_button_return: Button, p_button_victory_return: Button) -> void:
	"""Initialise le GameStateManager avec les références UI"""
	
	player = p_player
	game_over_ui = p_game_over_ui
	victory_ui = p_victory_ui
	button_return = p_button_return
	button_victory_return = p_button_victory_return
	
	_connect_buttons()
	
	print("[GameStateManager] Initialisé")

func _connect_buttons() -> void:
	"""Connecte les boutons de retour menu"""
	button_return.pressed.connect(_on_return_pressed)
	button_victory_return.pressed.connect(_on_return_pressed)

# ============================================================================
# GESTION DE LA MORT DU JOUEUR
# ============================================================================

func handle_player_death() -> void:
	"""Appelé quand le joueur meurt"""
	if GameData.boss_defeated:
		# Mort après avoir tué le boss final = Victoire quand même
		_show_victory()
		GameData.finalize_run(1.0)
	else:
		# Mort normale = Game Over
		_show_game_over()
		var save_ratio = player.saved_resources_ratio
		GameData.finalize_run(save_ratio)
	
	get_tree().paused = true
	GameTimer.stop_game()
	
	game_ended.emit()

func _show_game_over() -> void:
	"""Affiche l'écran de Game Over"""
	game_over_ui.show()
	print("[GameStateManager] GAME OVER")

func _show_victory() -> void:
	"""Affiche l'écran de victoire"""
	victory_ui.show()
	print("[GameStateManager] VICTORY")

# ============================================================================
# GESTION DE LA VICTOIRE (PORTAIL)
# ============================================================================

func handle_portal_used() -> void:
	"""Appelé quand le joueur utilise le portail de victoire"""
	victory_ui.show()
	GameData.finalize_run(1.0)
	get_tree().paused = true
	
	game_ended.emit()
	
	print("[GameStateManager] Portail utilisé - Victoire !")

# ============================================================================
# RETOUR AU MENU
# ============================================================================

func _on_return_pressed() -> void:
	"""Gère le retour au menu principal"""
	print("[GameStateManager] Retour au menu principal")
	
	get_tree().paused = false
	GameTimer.stop_game()
	
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/UI/MainMenu.tscn")
