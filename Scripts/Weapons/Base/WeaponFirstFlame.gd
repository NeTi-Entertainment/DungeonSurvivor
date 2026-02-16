extends Node2D

var id = "first_flame"
var level = 1
var current_stats = {}
var is_ready = true

var projectile_scene = preload("res://Scenes/Weapons/Projectiles/FirstFlameProjectile.tscn")

# --- STATS CALCULÉES ---
var damage: int = 18
var knockback: float = 30.0
var cooldown: float = 5.0
var amount: int = 2
var area: float = 1.0
var projectile_speed: float = 300.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var duration: float = 5.0
var pierce: int = 0
# -----------------------

@onready var detection_zone = $DetectionZone
@onready var cooldown_timer = $CooldownTimer

@export var icon: Texture2D

func _ready():
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Cooldown
	var base_cd = float(current_stats.get("cooldown", 5.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Dégâts
	var base_dmg = float(current_stats.get("damage", 18))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 3. Knockback
	var base_kb = float(current_stats.get("knockback", 30.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 4. Area (Taille + Amplitude de l'hélice)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 5. Amount (Quantité de projectiles)
	var base_amount = int(current_stats.get("amount", 2))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 6. Vitesse de projectile (Appliqué à la vitesse de base 300)
	var base_speed = float(current_stats.get("projectile_speed", 300.0))
	projectile_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 7. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	
	# Le multiplicateur de critique de base évolue avec le niveau de l'arme
	crit_damage = float(current_stats.get("crit_damage", 1.5))
	
	# 8. Autres (Duration, Pierce) - Pas affectés par accessoires standards ici
	duration = float(current_stats.get("duration", 5.0))
	pierce = int(current_stats.get("pierce", 0))

func _physics_process(_delta):
	if is_ready:
		var target = _find_nearest_enemy()
		# Si pas d'ennemi, on tire tout droit (facultatif, sinon on attend)
		if target:
			_fire(target.global_position)
		else:
			# Optionnel : Tir aléatoire ou devant soi si pas d'ennemi ?
			# Pour l'instant on attend un ennemi.
			pass

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

func _fire(target_pos):
	is_ready = false
	cooldown_timer.start()
	
	var dir = (target_pos - global_position).normalized()
	
	# On tire par paquets de 2 (Paires hélicoïdales)
	# Si amount = 2 : 1 paire
	# Si amount = 3 : 1 paire + 1 tout seul
	# Si amount = 4 : 2 paires
	
	# On parcourt par pas de 2
	for i in range(0, amount, 2):
		
		# Projectile 1 (Phase 0)
		_spawn_projectile(dir, 0.0)
		
		# Projectile 2 (Phase PI / 180°), seulement s'il en reste un pour compléter la paire
		if i + 1 < amount:
			_spawn_projectile(dir, PI)
		
		# Si on doit tirer une AUTRE paire (ou un autre projectile) après, on attend un peu
		# C'est le "on retire un missile juste après"
		if i + 2 < amount:
			await get_tree().create_timer(0.2).timeout

func _spawn_projectile(dir: Vector2, phase: float):
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	
	# On crée le paquet de stats finales
	var stats_packet = {
		"damage": damage,
		"knockback": knockback,
		"projectile_speed": projectile_speed,
		"duration": duration,
		"pierce": pierce,
		"area": area,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage
	}
	
	proj.setup(stats_packet, dir, phase)
	get_tree().current_scene.add_child(proj)
