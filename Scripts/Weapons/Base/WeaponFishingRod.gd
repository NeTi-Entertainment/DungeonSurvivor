extends Node2D

var id = "fishing_rod"
var level = 1
var current_stats = {}
var is_attacking = false

#Useful accessories stats : amount, knockback, projectile_speed, cooldown, area

# Stats Calculées
var damage: int = 10
var cooldown: float = 2.0
var area: float = 1.0
var knockback: float = 10.0
var amount: int = 1
var crit_chance: float = 0.0
var crit_damage: float = 1.5
# AJOUT : Variable pour la vitesse d'attaque
var projectile_speed: float = 1.0 

@onready var cooldown_timer = $CooldownTimer
@onready var rod_swing = $FishingRodSwing

@export var icon: Texture2D

func _ready():
	cooldown_timer.timeout.connect(_try_attack)
	# On connecte le signal de fin du FishingRodSwing
	if not rod_swing.sequence_finished.is_connected(_on_sequence_finished):
		rod_swing.sequence_finished.connect(_on_sequence_finished)
		
	load_stats(1)
	cooldown_timer.start()

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Dégâts
	var base_dmg = float(current_stats.get("damage", 14))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 2. Cooldown
	var base_cd = float(current_stats.get("cooldown", 2.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 3. Area
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 4. Knockback
	var base_kb = float(current_stats.get("knockback", 15.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 5. Amount
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 6. Critique
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))
	
	# 7. AJOUT : Vitesse (utilisée pour accélérer l'animation et réduire le délai entre les coups)
	var base_speed = float(current_stats.get("projectile_speed", 1.0))
	projectile_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# Configuration de l'enfant avec TOUTES les stats
	rod_swing.setup_stats({
		"damage": damage,
		"area": area,
		"knockback": knockback,
		"amount": amount,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"speed_mult": projectile_speed # On transmet le multiplicateur
	})

func _physics_process(_delta):
	if cooldown_timer.is_stopped() and not is_attacking:
		_try_attack()

func _try_attack():
	is_attacking = true
	# On lance la séquence. 
	# Note : Plus besoin de passer mouse_pos, le swing la récupère en temps réel.
	rod_swing.start_attack_sequence()

func _on_sequence_finished():
	is_attacking = false
	cooldown_timer.start()
