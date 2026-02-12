extends Node2D

var id = "triseal"
var level = 1
var current_stats = {}

# --- PARAMÈTRES ---
var base_rotation_speed = 1.0 
var beam_scene = preload("res://Scenes/Weapons/Projectiles/TrisealBeam.tscn")
var beam_length_base = 150.0 
var beam_width_base = 10.0

# --- STATS CALCULÉES ---
var damage: int = 7
var knockback: float = 10.0
var tick_interval: float = 0.75
var duration: float = 1.5       # Temps Actif
var cooldown_duration: float = 5.5 # Temps Inactif (Attente)
var fade_duration: float = 0.5     # Temps Inactif (Transition)
var rotation_speed: float = 1.0
var amount: int = 3
var crit_chance: float = 0.0
var crit_damage: float = 1.4

# --- ÉTAT ---
var is_damage_active = false
var beams = [] 

@onready var rotating_container = $RotatingContainer
@onready var tick_timer = $TickTimer

func _ready():
	tick_timer.timeout.connect(_on_tick)
	load_stats(1)
	
	# Démarrage du cycle infini
	_start_cycle_sequence()

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Amount (Nombre de rayons)
	var base_amount = int(current_stats.get("amount", 3))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 2. Dimensions (Area & Range logic)
	# On récupère le multiplicateur global d'Area donné par les accessoires (ex: 1.1 pour +10%)
	var area_bonus_total = GameData.get_stat_with_bonuses(1.0, "area")
	
	# Longueur : Affectée par la stat "Range" de l'arme ET "Area" des accessoires (Ratio 1:1)
	var range_stat = float(current_stats.get("range", 1.0))
	var final_length = beam_length_base * range_stat * area_bonus_total
	
	# Largeur : Affectée par la stat "Area" de l'arme ET "Area" des accessoires (Ratio Faible 0.2)
	# Si area_bonus_total est 1.5 (+50%), on veut que la largeur n'augmente que de 10% (0.1)
	var area_stat_weapon = float(current_stats.get("area", 1.0))
	var width_bonus_ratio = 1.0 + ((area_bonus_total - 1.0) * 0.2) # On ne prend que 20% du bonus
	var final_width = beam_width_base * area_stat_weapon * width_bonus_ratio
	
	# 3. Vitesse de rotation (Projectile Speed)
	var base_speed = float(current_stats.get("projectile_speed", 1.0))
	rotation_speed = base_rotation_speed * GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 4. Tick Rate (Vitesse de frappe)
	var base_tick = float(current_stats.get("tick_interval", 0.75))
	tick_interval = GameData.get_stat_with_bonuses(base_tick, "tick_interval")
	tick_timer.wait_time = max(0.05, tick_interval)
	
	# 5. Cooldown & Duration
	# La stat Cooldown réduit le temps d'inactivité (Fade + Cooldown Wait)
	# get_stat_with_bonuses pour "cooldown" renvoie un multiplicateur réduit (ex: 0.9)
	var cd_multiplier = GameData.get_stat_with_bonuses(1.0, "cooldown")
	
	var base_fade = 0.5
	fade_duration = base_fade * cd_multiplier 
	
	var base_cd_wait = float(current_stats.get("cooldown", 5.5))
	cooldown_duration = base_cd_wait * cd_multiplier
	
	var base_dur = float(current_stats.get("duration", 1.5))
	duration = GameData.get_stat_with_bonuses(base_dur, "duration")
	
	# 6. Dégâts & Critiques
	var base_dmg = float(current_stats.get("damage", 7))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	var base_kb = float(current_stats.get("knockback", 10.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))

	# RECREATION DES RAYONS (Mise à jour visuelle)
	for b in beams:
		if is_instance_valid(b): b.queue_free()
	beams.clear()
	
	var angle_step = TAU / amount
	
	for i in range(amount):
		var beam = beam_scene.instantiate()
		rotating_container.add_child(beam)
		beam.setup(final_length, final_width)
		
		# Répartition équitable
		beam.rotation = i * angle_step
		beams.append(beam)

func _physics_process(delta):
	# Rotation continue
	rotating_container.rotation += rotation_speed * delta

func _start_cycle_sequence():
	# On utilise les variables calculées dans load_stats
	var tween = create_tween()
	
	# PHASE 1 : FADE IN (Inactif -> Actif)
	tween.tween_property(rotating_container, "modulate:a", 1.0, fade_duration)
	
	tween.tween_callback(func(): 
		is_damage_active = true 
		tick_timer.start()
		_on_tick() # Premier tick immédiat
	)
	
	# PHASE 2 : MAINTIEN (Actif)
	tween.tween_interval(duration)
	
	# PHASE 3 : FADE OUT (Actif -> Inactif)
	tween.tween_callback(func(): 
		is_damage_active = false
		tick_timer.stop()
	)
	tween.tween_property(rotating_container, "modulate:a", 0.1, fade_duration)
	
	# PHASE 4 : COOLDOWN (Inactif)
	tween.tween_interval(cooldown_duration)
	
	# BOUCLE
	tween.tween_callback(_start_cycle_sequence)

func _on_tick():
	if not is_damage_active: return
	
	# Liste globale pour ne pas toucher le même ennemi plusieurs fois par tick (croisement de rayons)
	var enemies_hit_this_tick = []
	
	for beam in beams:
		var bodies = beam.get_overlapping_bodies()
		for body in bodies:
			if body.has_method("take_damage") and body not in enemies_hit_this_tick:
				enemies_hit_this_tick.append(body)
				
				var push_dir = (body.global_position - global_position).normalized()
				
				# Calcul Critique
				var final_dmg = damage
				if randf() < crit_chance:
					final_dmg = int(damage * crit_damage)
				
				body.take_damage(final_dmg, knockback, push_dir)
