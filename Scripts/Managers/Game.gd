extends Node2D
# Game.gd - Coordinateur principal du jeu (REFACTORISÉ)
# Délègue la logique aux managers spécialisés

# ============================================================================
# MANAGERS
# ============================================================================

var wave_manager: WaveManager
var boss_manager: BossManager
var victory_manager: VictoryManager
var debug_manager: DebugManager
var damage_number_manager: DamageNumberManager
var level_up_manager: LevelUpManager
var evolution_manager: EvolutionManager
var game_state_manager: GameStateManager
var destructible_manager: DestructibleManager

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var current_map_config: MapConfig

# ============================================================================
# RÉFÉRENCES DE SCÈNE
# ============================================================================

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

@onready var option_1: Button = $CanvasLayer/LevelUpUI/OptionsContainer/Option1
@onready var option_2: Button = $CanvasLayer/LevelUpUI/OptionsContainer/Option2
@onready var option_3: Button = $CanvasLayer/LevelUpUI/OptionsContainer/Option3

@onready var btn_reroll: Button = $CanvasLayer/LevelUpUI/QoLButtonsContainer/ButtonReroll
@onready var btn_skip: Button = $CanvasLayer/LevelUpUI/QoLButtonsContainer/ButtonSkip
@onready var btn_banish: Button = $CanvasLayer/LevelUpUI/QoLButtonsContainer/ButtonBanish

# UI EVOLUTION
@onready var evolution_ui: Control = $CanvasLayer/EvolutionUI
@onready var option_evo1: Button = $CanvasLayer/EvolutionUI/OptionsContainer/OptionEvo1
@onready var option_evo2: Button = $CanvasLayer/EvolutionUI/OptionsContainer/OptionEvo2

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_initialize_map_border()
	_initialize_managers()
	_setup_game_timer_connections()
	_connect_player_signals()
	_start_game_timer()
	
	# Reset de la run (bannissements, etc.)
	GameData.reset_run_state()
	
	# IMPORTANT : Level-up UI doit fonctionner en pause
	level_up_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	evolution_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	print("[Game] Jeu initialisé - Map: %s" % current_map_config.map_name)

func _physics_process(_delta: float) -> void:
	"""Gère la limite circulaire de la map"""
	if current_map_config and player:
		var radius = current_map_config.map_radius
		if player.global_position.length() > radius:
			player.global_position = player.global_position.limit_length(radius)

# ============================================================================
# INITIALISATION
# ============================================================================

func _initialize_map_border() -> void:
	"""Configure le mur circulaire de la map"""
	if current_map_config and map_border:
		map_border.setup(current_map_config.map_radius, Color.BLACK)
		map_border.z_index = 5

func _initialize_managers() -> void:
	"""Initialise tous les managers du jeu"""
	# WaveManager
	wave_manager = WaveManager.new()
	wave_manager.setup(player, current_map_config, self)
	add_child(wave_manager)
	wave_manager.start_spawning()
	
	# BossManager
	boss_manager = BossManager.new()
	boss_manager.setup(player, current_map_config, self)
	add_child(boss_manager)
	boss_manager.final_boss_defeated.connect(_on_final_boss_defeated)
	
	# VictoryManager
	victory_manager = VictoryManager.new()
	victory_manager.setup(player, current_map_config, self, victory_ui)
	add_child(victory_manager)
	victory_manager.portal_used.connect(_on_portal_used)
	
	# DamageNumberManager
	damage_number_manager = DamageNumberManager.new()
	add_child(damage_number_manager)
	
	# DebugManager
	debug_manager = DebugManager.new()
	debug_manager.setup(player, self)
	add_child(debug_manager)
	
	# LevelUpManager
	level_up_manager = LevelUpManager.new()
	level_up_manager.setup(player, level_up_ui, option_1, option_2, option_3, 
						   btn_reroll, btn_skip, btn_banish)
	add_child(level_up_manager)
	level_up_manager.level_up_completed.connect(_on_level_up_completed)
	
	# GameStateManager
	game_state_manager = GameStateManager.new()
	game_state_manager.setup(player, game_over_ui, victory_ui, 
							 button_return, button_victory_return)
	add_child(game_state_manager)
	game_state_manager.game_ended.connect(_on_game_ended)
	
	# DestructibleManager
	destructible_manager = DestructibleManager.new()
	destructible_manager.setup(player, current_map_config, self)
	add_child(destructible_manager)
	destructible_manager.generate_destructibles()
	
	# EvolutionManager
	evolution_manager = EvolutionManager.new()
	evolution_manager.setup(player, evolution_ui, option_evo1, option_evo2)
	add_child(evolution_manager)
	
	print("[Game] Tous les managers initialisés")

# ============================================================================
# CONNEXIONS DE SIGNAUX
# ============================================================================

func _setup_game_timer_connections() -> void:
	"""Connecte les signaux du GameTimer"""
	GameTimer.time_updated.connect(_on_time_updated)
	GameTimer.cycle_changed.connect(_on_cycle_changed)
	GameTimer.game_time_over.connect(_on_game_time_over)

func _connect_player_signals() -> void:
	"""Connecte les signaux du joueur"""
	player.player_died.connect(_on_player_died)
	player.level_up_triggered.connect(_on_level_up)
	player.inventory_updated.connect(_on_player_inventory_updated)
	
	# Force une première mise à jour de l'inventaire
	inventory_hud.update_inventory(player.weapons, player.accessories)

func _start_game_timer() -> void:
	"""Démarre le timer de jeu"""
	GameTimer.start_game()

# ============================================================================
# CALLBACKS - GAMETIMER
# ============================================================================

func _on_time_updated(_seconds_remaining: int, _formatted_time: String) -> void:
	"""Mise à jour du label du timer"""
	timer_label.text = _formatted_time

func _on_cycle_changed(cycle_number: int) -> void:
	"""Changement de cycle d'ennemis"""
	print("[Game] Cycle changé → Cycle %d" % cycle_number)
	# Le WaveManager gère déjà ça automatiquement

func _on_game_time_over() -> void:
	"""Temps de jeu écoulé (20:00 → 00:00)"""
	print("[Game] Temps écoulé")
	# Le VictoryManager/BossManager gèrent la suite

# ============================================================================
# CALLBACKS - PLAYER
# ============================================================================

func _on_player_died() -> void:
	"""Le joueur est mort"""
	wave_manager.stop_spawning()
	game_state_manager.handle_player_death()

func _on_level_up(new_level: int) -> void:
	"""Le joueur a level-up"""
	get_tree().paused = true
	GameTimer.pause_game()
	level_up_manager.show_level_up_screen(new_level)

func _on_level_up_completed() -> void:
	"""Le joueur a terminé son choix de level-up"""
	# Mise à jour de l'inventaire HUD
	if inventory_hud:
		inventory_hud.update_inventory(player.weapons, player.accessories)
	
	# Reprise du jeu
	get_tree().paused = false
	GameTimer.resume_game()

func _on_player_inventory_updated(weapons: Array, accessories: Array) -> void:
	"""L'inventaire du joueur a changé"""
	if inventory_hud:
		inventory_hud.update_inventory(weapons, accessories)

# ============================================================================
# CALLBACKS - VICTORY
# ============================================================================

func _on_final_boss_defeated() -> void:
	"""Le boss final (18min) a été vaincu"""
	print("[Game] Boss final vaincu - Activation de la victoire")
	GameData.boss_defeated = true
	
	# Récupérer la position du boss mort
	var boss_position = Vector2.ZERO
	if boss_manager.active_bosses.size() > 0:
		var last_boss = boss_manager.active_bosses[-1]
		if is_instance_valid(last_boss):
			boss_position = last_boss.global_position
	
	victory_manager.on_final_boss_defeated(boss_position)

func _on_portal_used() -> void:
	"""Le joueur a utilisé le portail de victoire"""
	game_state_manager.handle_portal_used()

func _on_game_ended() -> void:
	"""Le jeu s'est terminé (victory ou gameover)"""
	wave_manager.stop_spawning()
