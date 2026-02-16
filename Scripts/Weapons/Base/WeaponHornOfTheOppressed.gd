extends Node2D

var id = "horn_of_the_oppressed"
var level = 1
var current_stats = {}

var soldier_scene = preload("res://Scenes/Weapons/Projectiles/SummonedSoldier.tscn")

# STATS CALCULÉES
var spawn_cooldown: float = 15.0
var max_amount: int = 3
var damage: int = 10
var knockback: float = 8.0
var duration: float = 10.0
var attack_speed: float = 2.0 # Tick interval
var area: float = 1.0 # Zone de spawn
var range_mult: float = 1.0 # Portée d'attaque soldat
var move_speed_mult: float = 1.0 # Projectile speed
var crit_chance: float = 0.0
var crit_damage: float = 1.4

@onready var cooldown_timer = $CooldownTimer

@export var icon: Texture2D

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	load_stats(1)
	
	# Premier spawn immédiat
	call_deferred("_try_spawn_soldier")

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Spawn Cooldown (Délai d'apparition entre 2 soldats)
	var base_cd = float(current_stats.get("cooldown", 15.0))
	spawn_cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.5, spawn_cooldown)
	
	# 2. Amount (Nombre Max)
	var base_amount = int(current_stats.get("amount", 3))
	max_amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 3. Dégâts (Soldat)
	var base_dmg = float(current_stats.get("damage", 10))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 4. Autres Stats
	var base_kb = float(current_stats.get("knockback", 8.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	duration = float(current_stats.get("duration", 10.0)) # Durée de vie
	
	# Vitesse d'attaque du soldat (Tick Interval) - Plus c'est bas, plus il tape vite
	# On considère que tick_interval est réduit par la stat "cooldown" ou "attack_speed" générique ?
	# Souvent tick_interval est une stat à part, ici on va utiliser tick_interval brute
	# Si tu veux que la vitesse d'attaque globale améliore ça, dis-le moi. 
	# Pour l'instant je prends la valeur brute du JSON comme base.
	attack_speed = float(current_stats.get("tick_interval", 2.0))
	
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	var base_range = float(current_stats.get("range", 1.0))
	range_mult = GameData.get_stat_with_bonuses(base_range, "range")
	
	var base_speed = float(current_stats.get("projectile_speed", 1.0))
	move_speed_mult = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))

func _try_spawn_soldier():
	# On compte combien de soldats vivants on a (via un groupe c'est le plus simple)
	# Assurez-vous d'ajouter le Soldat au groupe "soldiers" dans son _ready ou via l'éditeur
	var current_soldiers = get_tree().get_nodes_in_group("player_minions")
	
	if current_soldiers.size() < max_amount:
		_spawn()
	
	# On relance le cooldown QU'IMPORTE si on a spawn ou pas
	# Car "cooldown est l'intervalle entre chaque invocation"
	cooldown_timer.start()

func _spawn():
	var soldier = soldier_scene.instantiate()
	soldier.add_to_group("player_minions")
	
	# Position aléatoire (Area = Zone de spawn)
	var spawn_radius = 100.0 * area
	var random_angle = randf() * TAU
	var random_dist = randf_range(20.0, spawn_radius)
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_dist
	
	soldier.global_position = global_position + offset
	
	# Paquet de stats pour le soldat
	var stats_packet = {
		"damage": damage,
		"knockback": knockback,
		"duration": duration,
		"tick_interval": attack_speed,
		"range_mult": range_mult,
		"move_speed_mult": move_speed_mult,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"spawn_radius": spawn_radius
	}
	
	# Setup du soldat avec le joueur comme référence (parent du parent)
	var player_ref = get_parent().get_parent()
	soldier.setup(stats_packet, player_ref)
	
	get_tree().current_scene.add_child(soldier)

func _on_cooldown_finished():
	_try_spawn_soldier()
