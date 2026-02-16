extends Node2D

var id = "coin_spitting_pouch"
var level = 1
var current_stats = {}
var is_ready = true

var projectile_scene = preload("res://Scenes/Weapons/Projectiles/CoinProjectile.tscn")

@export var icon: Texture2D

#Useful accessories stats: projectile_speed, amount, crit_chance, cooldown, damage

# --- BLOC STATS CALCULÉES ---
var damage: int = 0
var knockback: float = 0.0
var projectile_speed: float = 1.0
var duration: float = 0.0
var amount: int = 1
var area: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 1.4
#var lifesteal: float = 0.0
#var tick_interval: float = 0.0
# ----------------------------

@onready var detection_zone = $DetectionZone
@onready var cooldown_timer = $CooldownTimer
@onready var player = get_parent().get_parent() # Hypothèse structure: Player/WeaponHolder/Weapon

func _ready():
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Dégâts (Peinture de guerre)
	var base_dmg = float(current_stats.get("damage", 0))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 2. Cooldown (Pierre à aiguiser)
	var base_cd = float(current_stats.get("cooldown", 1.0))
	var final_cd = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.05, final_cd) # Sécurité min 0.05s
	# ATTENTION : J'ai supprimé la ligne qui était ici et qui écrasait tout !
	
	# 3. Area / Taille (Diffuseur d'ondes)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 4. Amount / Nombre (Racines de propagation)
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 5. Duration (Sablier)
	var base_duration = float(current_stats.get("duration", 1.0))
	duration = GameData.get_stat_with_bonuses(base_duration, "duration")
	
	# 6. Projectile_speed (Plume d'accélération)
	var base_speed = float(current_stats.get("projectile_speed", 1.0))
	projectile_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 7. Knockback (Amulette des marées)
	var base_kb = float(current_stats.get("knockback", 0.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 8. Tick_interval (Bobine de fréquence)
	#var base_ticki = float(current_stats.get("tick_interval", 1.0)) # Par défaut 1.0 pour éviter div/0
	#tick_interval = GameData.get_stat_with_bonuses(base_ticki, "tick_interval")
	
	# 9. Lifesteal (Ichor corrompu)
	#var base_ls = float(current_stats.get("lifesteal", 0.0))
	#lifesteal = GameData.get_stat_with_bonuses(base_ls, "lifesteal")
	
	# 10. Crit_chance (Lentille du jugement)
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")

func _physics_process(_delta):
	if is_ready:
		var target = _get_closest_enemy()
		if target:
			_try_shoot(target)

func _get_closest_enemy():
	var bodies = detection_zone.get_overlapping_bodies()
	var closest = null
	var min_dist = INF
	for b in bodies:
		if b.has_method("take_damage"):
			var d = global_position.distance_squared_to(b.global_position)
			if d < min_dist:
				min_dist = d
				closest = b
	return closest

func _try_shoot(target):
	# VERIFICATION DES MUNITIONS (OR)
	if player.current_gold <= 0:
		return # Pas d'argent, pas de tir (Clic-clic...)
	
	# PAIEMENT
	player.add_gold(-1) # On retire 1 pièce
	
	is_ready = false
	cooldown_timer.start()
	
	# TIR
	var dir = (target.global_position - global_position).normalized()
	
	var final_stats_packet = {
		"damage": damage,
		"knockback": knockback,
		"duration": duration,
		"area": area,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"pierce": int(current_stats.get("pierce", 1)), # Celle-ci n'est pas modifiée par accessoire, on garde la base
		"projectile_speed": projectile_speed # Déjà calculé avec bonus
	}
	
	# Tir multiple éventuel (Mitraillette à pièces)
	for i in range(amount):
		var proj = projectile_scene.instantiate()
		proj.global_position = global_position
		
		# Légère dispersion si plusieurs projectiles
		var spread = 0.0
		if amount > 1: spread = randf_range(-0.1, 0.1)
		var final_dir = dir.rotated(spread)
		
		proj.setup(final_stats_packet, final_dir)
		get_tree().current_scene.add_child(proj)
# Si ce n'est pas le dernier projectile, on attend 0.1s avant le prochain
		if i < amount - 1:
			await get_tree().create_timer(0.1).timeout
