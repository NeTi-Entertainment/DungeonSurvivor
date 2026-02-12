extends Node2D

var id = "crystalline_impact"
var level = 1
var current_stats = {}
var is_ready = true

var projectile_scene = preload("res://Scenes/Weapons/Projectiles/CrystallineProjectile.tscn")

# VARIABLES CALCULÉES
var final_rift_damage: int = 0
var final_explo_damage: int = 0
var final_rift_knockback: float = 0.0
var final_explo_knockback: float = 0.0
var final_area: float = 1.0
var final_cooldown: float = 3.5
var final_amount: int = 1
var final_duration: float = 1.0 # Fixe
var final_speed_mult: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5

@onready var detection_zone = $DetectionZone
@onready var cooldown_timer = $CooldownTimer

func _ready():
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
# 1. Dégâts (s'applique au Rift ET à l'Explosion)
	var base_rift_dmg = float(current_stats.get("rift_damage", 10))
	final_rift_damage = int(round(GameData.get_stat_with_bonuses(base_rift_dmg, "damage")))
	
	var base_explo_dmg = float(current_stats.get("explo_damage", 15))
	final_explo_damage = int(round(GameData.get_stat_with_bonuses(base_explo_dmg, "damage")))
	
	# 2. Knockback (s'applique aux deux)
	var base_rift_kb = float(current_stats.get("rift_knockback", 20.0))
	final_rift_knockback = GameData.get_stat_with_bonuses(base_rift_kb, "knockback")
	
	var base_explo_kb = float(current_stats.get("explo_knockback", 60.0))
	final_explo_knockback = GameData.get_stat_with_bonuses(base_explo_kb, "knockback")
	
	# 3. Area (Taille)
	var base_area = float(current_stats.get("area", 1.0))
	final_area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 4. Amount (Quantité)
	var base_amount = int(current_stats.get("amount", 1))
	final_amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 5. Cooldown
	var base_cd = float(current_stats.get("cooldown", 3.5))
	final_cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	
	# 6. Duration (NON ALTÉRÉE - Reste à la base, par défaut 1.0s)
	final_duration = float(current_stats.get("duration", 1.0))
	
	# 7. Projectile Speed
	# On part d'une base de 1.0 (100% de la vitesse normale)
	var base_speed = float(current_stats.get("projectile_speed", 1.0))
	final_speed_mult = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 8. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))
	
	# Mise à jour de la zone de détection
	var weapon_range = float(current_stats.get("range", 200.0))
	var shape = detection_zone.get_node("CollisionShape2D").shape
	if shape is CircleShape2D:
		shape.radius = weapon_range + 50.0

func _physics_process(_delta):
	if is_ready:
		var targets = _find_potential_targets()
		if targets.size() > 0:
			_start_firing_sequence(targets)

func _find_potential_targets():
	var bodies = detection_zone.get_overlapping_bodies()
	var enemies = []
	for b in bodies:
		if b.has_method("take_damage"):
			enemies.append(b)
	return enemies

func _start_firing_sequence(targets: Array):
	is_ready = false
	
	# Séquence de tir
	for i in range(final_amount):
		# À chaque tir, on choisit une cible aléatoire parmi celles dispo
		var random_target = targets.pick_random()
		if random_target:
			var direction = (random_target.global_position - global_position).normalized()
			_fire_projectile(direction)
		else:
			# Si plus de cible (tous morts entre temps ?), on tire devant
			_fire_projectile(Vector2.RIGHT.rotated(randf_range(-PI, PI)))
			
		# Petit délai entre les projectiles multiples
		if i < final_amount - 1:
			await get_tree().create_timer(0.2).timeout
	
	# GESTION DU COOLDOWN SPÉCIFIQUE
	cooldown_timer.wait_time = final_duration + final_cooldown
	cooldown_timer.start()

func _fire_projectile(dir: Vector2):
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	
	# On crée un paquet avec les stats déjà calculées
	var stats_packet = {
		"rift_damage": final_rift_damage,
		"explo_damage": final_explo_damage,
		"rift_knockback": final_rift_knockback,
		"explo_knockback": final_explo_knockback,
		"area": final_area,
		"duration": final_duration,
		"range": float(current_stats.get("range", 200.0)),
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"projectile_speed": final_speed_mult
	}
	
	proj.setup(stats_packet, dir)
	get_tree().current_scene.add_child(proj)
