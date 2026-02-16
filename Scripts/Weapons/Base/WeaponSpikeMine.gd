extends Node2D

var id = "spike_mine"
var level = 1
var current_stats = {}

var mine_scene = preload("res://Scenes/Weapons/Projectiles/SpikeMineObject.tscn")

@onready var cooldown_timer = $CooldownTimer

# STATS CALCULÉES
var damage: int = 20
var knockback: float = 45.0
var projectile_speed: float = 1.0
var explosion_delay: float = 1.0 # Duration dans le JSON
var amount: int = 5 # Nombre de piques
var area: float = 1.0
var cooldown: float = 4.0
var crit_chance: float = 0.0
var crit_damage: float = 1.4

@export var icon: Texture2D

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	load_stats(1)
	
	# Premier tir dès le début (différé)
	call_deferred("_spawn_mine")

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Cooldown (Fréquence de pose des mines)
	var base_cd = float(current_stats.get("cooldown", 4.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Dégâts
	var base_dmg = float(current_stats.get("damage", 20))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 3. Amount (Nombre de piques à l'explosion)
	var base_amount = int(current_stats.get("amount", 5))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 4. Area (Taille Mine + Piques)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 5. Vitesse des piques (Projectile Speed)
	var base_speed = float(current_stats.get("projectile_speed", 1.0))
	projectile_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 6. Knockback
	var base_kb = float(current_stats.get("knockback", 45.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 7. Duration (Délai avant explosion)
	var base_dur = float(current_stats.get("duration", 1.0))
	explosion_delay = GameData.get_stat_with_bonuses(base_dur, "duration")
	
	# 8. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))

func _spawn_mine():
	var mine = mine_scene.instantiate()
	
	# 1. Calcul de la position aléatoire
	# Cercle de rayon 150px autour du joueur
	var spawn_radius = 150.0
	var random_angle = randf() * TAU
	var random_dist = randf_range(0, spawn_radius)
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_dist
	
	# global_position ici est celle du joueur (car l'arme est son enfant)
	var target_pos = global_position + offset
	mine.global_position = target_pos
	
	# 2. Transmission des stats
	var stats_packet = {
		"damage": damage,
		"knockback": knockback,
		"projectile_speed": projectile_speed,
		"amount": amount,
		"duration": explosion_delay,
		"area": area,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage
	}
	mine.setup_stats(stats_packet)
	
	# 3. Ajout à la scène (La mine est posée au sol, elle ne suit pas le joueur)
	get_tree().current_scene.add_child(mine)
	
	# 4. Lancement du cooldown
	cooldown_timer.start()

func _on_cooldown_finished():
	_spawn_mine()
