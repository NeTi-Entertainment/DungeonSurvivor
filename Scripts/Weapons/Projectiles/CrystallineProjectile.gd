extends Area2D

var rift_damage = 0
var rift_knockback = 0
var explo_damage = 0
var explo_knockback = 0
var travel_duration = 1.0
var travel_distance = 100.0
var area_scale = 1.0

# Gestion Critique
var is_critical = false
var crit_damage_mult = 1.5

var velocity = Vector2.ZERO
var hit_history = [] # Pour ne taper qu'une fois chaque ennemi traversé (Rift)

# Préchargement de l'explosion
var explosion_scene = preload("res://Scenes/Weapons/Projectiles/CrystallineExplosion.tscn")

@onready var line_2d = $Line2D

func _ready():
	body_entered.connect(_on_body_entered)
	
	# La traînée doit être vidée au début et configurée
	line_2d.clear_points()
	
	# Timer de fin de vie (Explosion)
	get_tree().create_timer(travel_duration).timeout.connect(_explode)

func setup(stats: Dictionary, direction: Vector2):
# Récupération des stats déjà calculées par l'arme
	rift_damage = stats["rift_damage"]
	explo_damage = stats["explo_damage"]
	rift_knockback = stats["rift_knockback"]
	explo_knockback = stats["explo_knockback"]
	
	travel_duration = stats["duration"]
	travel_distance = stats["range"]
	
	area_scale = stats["area"]
	scale = Vector2(area_scale, area_scale)
	
	# Calcul Critique (décidé au lancement du projectile)
	var crit_chance = stats["crit_chance"]
	crit_damage_mult = stats["crit_damage"]
	if randf() < crit_chance:
		is_critical = true
		# Optionnel : Changer la couleur si critique (ex: rouge)
		modulate = Color(1.5, 0.5, 0.5) 
	
# 1. Calcul de la vitesse théorique pour atteindre la portée 'range' en 'duration'
	var base_speed = travel_distance / travel_duration
	
	# 2. Récupération du multiplicateur de vitesse (Accessoire)
	var speed_mult = float(stats.get("projectile_speed", 1.0))
	
	# 3. Application : Plus de vitesse = Plus de distance parcourue pendant le même temps
	var final_speed = base_speed * speed_mult
	
	velocity = direction * final_speed
	
	rotation = direction.angle()

func _physics_process(delta):
	position += velocity * delta
	
	# Gestion de la traînée visuelle
	line_2d.add_point(global_position)
	if line_2d.get_point_count() > 20:
		line_2d.remove_point(0)

func _on_body_entered(body):
	# Dégâts de RIFT (Traversée)
	if body.has_method("take_damage") and body not in hit_history:
		hit_history.append(body)
		
		# Application des dégâts de faille (Rift)
		var final_dmg = rift_damage
		if is_critical:
			final_dmg = int(rift_damage * crit_damage_mult)
		
		# Le recul suit la direction du projectile
		body.take_damage(final_dmg, rift_knockback, velocity.normalized())

func _explode():
	var explo = explosion_scene.instantiate()
	explo.global_position = global_position
	
	# Calcul dégâts explosion
	var final_explo_dmg = explo_damage
	if is_critical:
		final_explo_dmg = int(explo_damage * crit_damage_mult)
	
	# Configuration de l'explosion (Size x4 par rapport au projectile de base)
	# On applique aussi le area_scale global
	explo.setup(final_explo_dmg, explo_knockback, 1.0 * area_scale)
	
	get_tree().current_scene.add_child(explo)
	
	# Nettoyage
	queue_free()
