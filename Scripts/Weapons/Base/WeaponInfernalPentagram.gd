extends Node2D

var id = "infernal_pentagram"
var level = 1
var current_stats = {}

var pentagram_scene = preload("res://Scenes/Weapons/Projectiles/InfernalPentagramZone.tscn")

@onready var cooldown_timer = $CooldownTimer

#Useful accessories stats : cooldown, area, tick_interval, duration

# --- STATS CALCULÉES ---
var damage: int = 10
var cooldown: float = 10.0
var area: float = 1.0
var duration: float = 3.0
var tick_interval: float = 0.5
var amount: int = 1 # Force à 1 selon ta demande
var crit_chance: float = 0.0
var crit_damage: float = 1.4
# -----------------------

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	load_stats(1)
	
	# Démarrage sécurisé
	call_deferred("_start_sequence")

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Dégâts
	var base_dmg = float(current_stats.get("damage", 12))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 2. Cooldown
	var base_cd = float(current_stats.get("cooldown", 10.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 3. Area (Taille du piège)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 4. Durée
	var base_dur = float(current_stats.get("duration", 4.0))
	duration = GameData.get_stat_with_bonuses(base_dur, "duration")
	
	# 5. Intervalle de dégâts (Tick)
	var base_tick = float(current_stats.get("tick_interval", 0.5))
	tick_interval = GameData.get_stat_with_bonuses(base_tick, "tick_interval")
	
	# 6. Critique
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))
	
	# 7. Amount (Toujours 1 pour cette arme, on ignore les bonus)
	amount = 1 

func _start_sequence():
	# Boucle pour créer la traînée (si amount > 1)
	for i in range(amount):
		_spawn_pentagram()
		
		# Si on a plusieurs pentagrammes, on attend un peu avant le suivant
		# pour créer l'effet de "traînée" derrière le joueur s'il bouge
		if i < amount - 1:
			await get_tree().create_timer(0.2).timeout
	
	# Une fois toute la séquence finie, on lance le cooldown
	cooldown_timer.start()

func _spawn_pentagram():
	var zone = pentagram_scene.instantiate()
	
	# Positionnement : Sur la position ACTUELLE du joueur (global)
	# Comme l'arme est enfant du joueur, global_position est celle du joueur.
	zone.global_position = global_position
	
	# Configuration
	zone.setup_stats(damage, tick_interval, duration, area, crit_chance, crit_damage)
	
	# Ajout à la scène principale (pour qu'il ne bouge pas avec le joueur)
	get_tree().current_scene.add_child(zone)

func _on_cooldown_finished():
	_start_sequence()
