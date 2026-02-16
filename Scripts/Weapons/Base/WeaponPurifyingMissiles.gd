extends Node2D

var id = "purifying_missiles"
var level = 1
var current_stats = {}

# Variables de tir
var is_ready = true
var missile_scene = preload("res://Scenes/Weapons/Projectiles/Missile.tscn") # <-- VERIFIEZ CE CHEMIN

#Useful accessories stats: amount, crit_chance, 

# --- BLOC STATS CALCULÉES ---
var damage: int = 0
var knockback: float = 0.0
var projectile_speed: float = 1.0
var duration: float = 0.0
var amount: int = 1
var pierce: int = 0
var tick_interval: float = 0.25
var cooldown: float = 1.5
var crit_chance: float = 0.0
var crit_damage: float = 1.4
# ----------------------------

# Références
@onready var detection_zone = $DetectionZone
@onready var detection_shape = $DetectionZone/CollisionShape2D
@onready var cooldown_timer = $CooldownTimer
@onready var player = get_parent().get_parent() # WeaponsHolder -> Player

@export var icon: Texture2D

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Dégâts
	var base_dmg = float(current_stats.get("damage", 0))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 2. Cooldown
	var base_cd = float(current_stats.get("cooldown", 1.5))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.05, cooldown)
	
	# 3. Intervalle de tir (Salve)
	var base_tick = float(current_stats.get("tick_interval", 0.25))
	tick_interval = GameData.get_stat_with_bonuses(base_tick, "tick_interval")
	
	# 4. Nombre de projectiles (Amount)
	var base_amount = int(current_stats.get("amount", 3))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 5. Vitesse Projectile
	var base_speed = float(current_stats.get("projectile_speed", 400.0))
	projectile_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 6. Durée de vie
	var base_dur = float(current_stats.get("duration", 5.0))
	duration = GameData.get_stat_with_bonuses(base_dur, "duration")
	
	# 7. Knockback
	var base_kb = float(current_stats.get("knockback", 15.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 8. Critique
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	
	crit_damage = float(current_stats.get("crit_damage", 1.4))
	
	# Stats non modifiées par les accessoires standards
	pierce = int(current_stats.get("pierce", 0))
	var detection_radius = float(current_stats.get("range", 600.0))
	
	# Mise à jour de la zone de détection
	if detection_shape.shape is CircleShape2D:
		detection_shape.shape.radius = detection_radius

func _physics_process(_delta):
	if is_ready:
		var target = _find_nearest_enemy()
		if target:
			_start_salve(target)

func _find_nearest_enemy():
	var enemies = detection_zone.get_overlapping_bodies()
	if enemies.size() == 0:
		return null
	
	var nearest_enemy = null
	var min_dist = INF
	var player_pos = global_position
	
	for enemy in enemies:
		if enemy.has_method("take_damage"): # S'assurer que c'est un ennemi valide
			var dist = player_pos.distance_squared_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_enemy = enemy
	
	return nearest_enemy

func _start_salve(_first_target):
	is_ready = false
	
	# On garde la référence à la cible initiale pour toute la boucle
	var current_target = _find_nearest_enemy() #locked_target
	
	for i in range(amount):
		if not is_instance_valid(current_target) or current_target.is_queued_for_deletion():
			# Si elle est morte ou a disparu, on en cherche une nouvelle immédiatement
			current_target = _find_nearest_enemy()
		if current_target:
			_fire_missile(current_target)
		else:
			# Tir "à l'aveugle" (optionnel) ou on ne fait rien
			pass
			
		# Attente entre les missiles
		if i < amount - 1:
			await get_tree().create_timer(tick_interval).timeout
	
	# FIN DE LA SALVE -> DÉBUT DU COOLDOWN
	cooldown_timer.start()

func _fire_missile(target):
	var missile = missile_scene.instantiate()
	
	# 1. Positionnement
	# On le fait partir du joueur
	missile.global_position = global_position
	
	# 2. Transfert des Stats
	missile.speed = projectile_speed
	missile.damage = damage
	missile.knockback = knockback * 10.0
	missile.pierce_count = pierce
	missile.duration = duration
	missile.crit_chance = crit_chance
	missile.crit_damage = crit_damage
	
	# 3. Calcul Direction (Au moment du tir)
	var dir = (target.global_position - global_position).normalized()
	missile.direction = dir
	missile.rotation = dir.angle() # Pour orienter le sprite
	
	# 4. Ajout au monde (IMPORTANT)
	# On l'ajoute à la racine du jeu pour qu'il soit indépendant du joueur
	# get_tree().root.add_child(missile) est risqué si on change de scène.
	# Mieux : l'ajouter comme "Top Level" enfant du Weapon ou Player
	get_tree().current_scene.add_child(missile)

func _on_cooldown_finished():
	is_ready = true
