extends Node2D

var id = "phase_shift_scepter"
var level = 1
var current_stats = {}
var is_ready = true

var projectile_scene = preload("res://Scenes/Weapons/Projectiles/PhaseProjectile.tscn") # <-- VERIFIEZ

# STATS CALCULÉES
var damage: int = 10
var cooldown: float = 3.0
var knockback: float = 10.0
var projectile_speed: float = 300.0
var amount: int = 1         # Nombre de projectiles tirés
var bounces: int = 3        # Nombre de rebonds (défini par Pierce ou base)
var duration: float = 5.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5

@onready var detection_zone = $DetectionZone
@onready var cooldown_timer = $CooldownTimer

@export var icon: Texture2D

func _ready():
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)

# 1. Cooldown (Vitesse d'attaque)
	var base_cd = float(current_stats.get("cooldown", 3.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Dégâts
	var base_dmg = float(current_stats.get("damage", 10))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 3. Knockback
	var base_kb = float(current_stats.get("knockback", 10.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 4. Vitesse du projectile
	var base_speed = float(current_stats.get("projectile_speed", 300.0))
	projectile_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 5. Amount (Nombre de projectiles par salve)
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 6. Bounces (Rebonds - on utilise souvent 'pierce' pour ça sur ce type d'arme)
	# Si pas de stat pierce, on garde la valeur par défaut de 3
	bounces = int(current_stats.get("pierce", 3))
	
	# 7. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))
	
	# 8. Duration (Inchangée)
	duration = float(current_stats.get("duration", 5.0))

func _physics_process(_delta):
	if is_ready:
		# On vérifie juste s'il y a au moins un ennemi pour lancer la salve
		var bodies = detection_zone.get_overlapping_bodies()
		var has_targets = false
		for b in bodies:
			if b.has_method("take_damage"):
				has_targets = true
				break
		
		if has_targets:
			_start_firing_sequence()

func _get_all_valid_enemies():
	var bodies = detection_zone.get_overlapping_bodies()
	var enemies = []
	for b in bodies:
		if b.has_method("take_damage"):
			enemies.append(b)
	return enemies

func _get_nearest(enemies_list):
	var nearest = null
	var min_dist = INF
	for b in enemies_list:
		var d = global_position.distance_squared_to(b.global_position)
		if d < min_dist:
			min_dist = d
			nearest = b
	return nearest

func _start_firing_sequence():
	is_ready = false
	cooldown_timer.start()
	
	# On récupère la liste des ennemis au début de la salve
	var enemies = _get_all_valid_enemies()
	
	for i in range(amount):
		var target = null
		
		if enemies.size() > 0:
			if i == 0:
				# 1er tir : Le plus proche
				target = _get_nearest(enemies)
			else:
				# Tirs suivants : Aléatoire dans la liste
				target = enemies.pick_random()
		
		# Note : Si target est null (aucun ennemi trouvé), le projectile partira en aléatoire
		_fire_single_projectile(target)
		
		# Petit délai mitraillette entre les tirs de la salve
		if i < amount - 1:
			await get_tree().create_timer(0.1).timeout
			# On rafraîchit la liste au cas où des ennemis meurent entre deux tirs
			enemies = _get_all_valid_enemies()

func _fire_single_projectile(target):
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	
	var stats_packet = {
		"damage": damage,
		"knockback": knockback,
		"speed": projectile_speed,
		"bounces": bounces,
		"duration": duration,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage
	}
	
	proj.setup(stats_packet, target)
	get_tree().current_scene.add_child(proj)
