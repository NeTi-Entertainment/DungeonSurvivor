extends Node2D

var id = "tracer_dagger"
var level = 1
var current_stats = {}
var is_ready = true

var projectile_scene = preload("res://Scenes/Weapons/Projectiles/TracerDagger.tscn")

# STATS CALCULÉES
var damage: int = 12
var cooldown: float = 1.5
var knockback: float = 10.0
var projectile_speed: float = 600.0
var amount: int = 1
var pierce: int = 0
var rebound: int = 1
var duration: float = 5.0
var area: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 1.4

@onready var detection_zone = $DetectionZone
@onready var cooldown_timer = $CooldownTimer
@onready var detection_shape = $DetectionZone/CollisionShape2D

func _ready():
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Cooldown
	var base_cd = float(current_stats.get("cooldown", 1.5))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Dégâts
	var base_dmg = float(current_stats.get("damage", 12))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 3. Knockback
	var base_kb = float(current_stats.get("knockback", 10.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 4. Vitesse
	var base_speed = float(current_stats.get("projectile_speed", 600.0))
	projectile_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 5. Amount
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 6. Area
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 7. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))
	
	# 8. Autres (Pierce, Rebound, Duration)
	pierce = int(current_stats.get("pierce", 0))
	rebound = int(current_stats.get("rebound", 1))
	
	var base_dur = float(current_stats.get("duration", 5.0))
	duration = GameData.get_stat_with_bonuses(base_dur, "duration")
	
	# Mise à jour portée détection
	var range_val = float(current_stats.get("range", 600.0))
	if detection_shape.shape is CircleShape2D:
		detection_shape.shape.radius = range_val

func _physics_process(_delta):
	if is_ready:
		var targets = _find_sorted_targets()
		if not targets.is_empty():
			_fire_sequence(targets)

func _find_sorted_targets():
	var bodies = detection_zone.get_overlapping_bodies()
	var enemies = []
	for b in bodies:
		if b.has_method("take_damage"):
			enemies.append(b)
	
	# Tri du plus proche au plus loin
	enemies.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return enemies

func _fire_sequence(enemies_list):
	is_ready = false
	cooldown_timer.start()
	
	for i in range(amount):
		var target = null
		
		# Logique de distribution : 1 -> 1er, 2 -> 2ème...
		if i < enemies_list.size():
			target = enemies_list[i]
		else:
			# Si plus de dagues que d'ennemis, on prend au hasard
			target = enemies_list.pick_random()
		
		if target:
			_spawn_projectile(target)
		
		# Délai mitraillette
		if i < amount - 1:
			await get_tree().create_timer(0.1).timeout

func _spawn_projectile(target):
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	
	var stats_packet = {
		"damage": damage,
		"knockback": knockback,
		"speed": projectile_speed,
		"pierce": pierce,
		"rebound": rebound,
		"duration": duration,
		"area": area,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage
	}
	
	proj.setup(stats_packet, target)
	get_tree().current_scene.add_child(proj)
