extends Area2D

var damage = 0
var knockback = 0
var speed = 400.0 # Vitesse de base
var speed_multiplier = 1.0
var duration = 3.0 # Durée de vie fixe des piques
var direction = Vector2.RIGHT
var crit_chance = 0.0
var crit_damage = 1.4

func _ready():
	z_index = -1
	# Disparition automatique après 3 secondes (ou autre valeur fixe)
	get_tree().create_timer(duration).timeout.connect(queue_free)
	
	# Gestion collision
	body_entered.connect(_on_body_entered)
	
	# Orientation visuelle
	rotation = direction.angle()

func _physics_process(delta):
	position += direction * (speed * speed_multiplier) * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		# Calcul Critique individuel par pique
		var final_damage = damage
		if randf() < crit_chance:
			final_damage = int(damage * crit_damage)
			# Feedback visuel critique possible ici
		body.take_damage(final_damage, knockback, direction)
		# Pierce est à 0, donc destruction immédiate
		queue_free()

# Fonction de config (appelée par la mine)
func setup(dmg, kb, spd_mult, dir, area_val, c_chance, c_dmg):
	damage = dmg
	knockback = kb
	speed_multiplier = spd_mult
	direction = dir
	
	# Application de la taille (Area)
	scale = Vector2(area_val, area_val)
	
	crit_chance = c_chance
	crit_damage = c_dmg
