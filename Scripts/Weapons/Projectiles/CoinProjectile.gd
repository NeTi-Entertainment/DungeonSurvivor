extends Area2D

var damage = 0
var knockback = 0
var speed = 800.0 # Très rapide
var pierce_count = 1
var velocity = Vector2.ZERO
var crit_chance = 0.0
var crit_damage_mult = 1.4

var lifetime = 0.5

func setup(stats: Dictionary, dir: Vector2):
	damage = int(stats.get("damage", 4))
	knockback = float(stats.get("knockback", 1))
	pierce_count = int(stats.get("pierce", 1))
	lifetime = float(stats.get("duration", 0.5))
	
	#var duration = float(stats.get("duration", 0.5)) # Portée limitée par le temps
	#get_tree().create_timer(duration).timeout.connect(queue_free)
	
	# Vitesse très élevée
	var spd_mult = float(stats.get("projectile_speed", 1.0))
	speed = 900.0 * spd_mult 
	
	# 1. Gestion de la Taille (Area)
	var area_mult = float(stats.get("area", 1.0))
	scale = Vector2(area_mult, area_mult) # On grossit tout l'objet
	
	# 2. Gestion du Critique
	crit_chance = float(stats.get("crit_chance", 0.0))
	crit_damage_mult = float(stats.get("crit_damage", 1.4))
	
	velocity = dir * speed
	rotation = dir.angle()

func _physics_process(delta):
	position += velocity * delta

func _ready():
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		var push_dir = velocity.normalized()
		
		var _final_damage = damage
		var _is_crit = false
		
		if randf() < crit_chance:
			_is_crit = true
			_final_damage = int(damage * crit_damage_mult)
			# Ici, on pourrait ajouter un effet visuel "CRIT!" ou changer la couleur
			modulate = Color(1, 0.2, 0.2) # Flash rouge pour tester
		
		body.take_damage(damage, knockback, push_dir)
		
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()
