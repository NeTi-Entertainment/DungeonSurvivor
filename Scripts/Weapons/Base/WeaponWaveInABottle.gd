extends Node2D

var id = "wave_in_a_bottle"
var level = 1
var current_stats = {}
var is_ready = true

var wave_scene = preload("res://Scenes/Weapons/Projectiles/WaveProjectile.tscn")

# STATS CALCULÉES
var damage: int = 15
var knockback: float = 370.0
var cooldown: float = 3.0
var duration: float = 0.75
var amount: int = 1
var width_mult: float = 1.0 # Multiplicateur de Largeur (Area Ratio 1)
var length_mult: float = 1.0 # Multiplicateur de Longueur (Area Ratio 0.5 + Range)
var crit_chance: float = 0.0
var crit_damage: float = 1.4

@onready var detection_zone = $DetectionZone
@onready var cooldown_timer = $CooldownTimer

func _ready():
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Cooldown
	var base_cd = float(current_stats.get("cooldown", 3.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Dégâts
	var base_dmg = float(current_stats.get("damage", 15))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 3. Knockback
	var base_kb = float(current_stats.get("knockback", 370.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 4. Duration
	var base_dur = float(current_stats.get("duration", 0.75))
	duration = GameData.get_stat_with_bonuses(base_dur, "duration")
	
	# 5. Amount (Vagues multiples)
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 6. AREA & RANGE (Ta logique spécifique)
	# On récupère le bonus d'Area global des accessoires (ex: 1.1 pour +10%)
	var area_bonus_total = GameData.get_stat_with_bonuses(1.0, "area")
	
	# A. Largeur : Ratio 1 (Impact total du bonus Area)
	var weapon_area_stat = float(current_stats.get("area", 1.0))
	width_mult = weapon_area_stat * area_bonus_total
	
	# B. Longueur : Ratio 0.5 sur le bonus Area + Stat Range de l'arme
	var weapon_range_stat = float(current_stats.get("range", 1.0))
	# Si area_bonus_total est 1.2 (+20%), le ratio 0.5 donne un bonus de +10% (1.1)
	var area_length_influence = 1.0 + ((area_bonus_total - 1.0) * 0.5)
	length_mult = weapon_range_stat * area_length_influence
	
	# 7. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))
	
	# Mise à jour de la zone de détection
	var base_range_px = 100.0 # Doit correspondre à celle du projectile
	# On s'assure de détecter assez loin pour tirer
	var detect_radius = base_range_px * length_mult + 100.0 
	
	var shape = detection_zone.get_node("CollisionShape2D").shape
	if shape is CircleShape2D:
		shape.radius = detect_radius

func _physics_process(_delta):
	if is_ready:
		var target = _find_nearest_enemy()
		if target:
			_fire(target)

func _find_nearest_enemy():
	var bodies = detection_zone.get_overlapping_bodies()
	var nearest = null
	var min_dist = INF
	for b in bodies:
		if b.has_method("take_damage"):
			var d = global_position.distance_squared_to(b.global_position)
			if d < min_dist:
				min_dist = d
				nearest = b
	return nearest

func _fire(target):
	is_ready = false
	cooldown_timer.start()
	
	var dir = (target.global_position - global_position).normalized()
	
	# Tir Multiple (Amount)
	for i in range(amount):
		var wave = wave_scene.instantiate()
		wave.global_position = global_position
		
		var stats_packet = {
			"damage": damage,
			"knockback": knockback,
			"duration": duration,
			"width_mult": width_mult,
			"length_mult": length_mult,
			"crit_chance": crit_chance,
			"crit_damage": crit_damage
		}
		
		wave.setup(stats_packet, dir)
		get_tree().current_scene.add_child(wave)
		
		# Délai entre les vagues
		if i < amount - 1:
			await get_tree().create_timer(0.2).timeout
