extends Area2D

# Stats reçues au moment du tir
var speed = 0
var damage = 0
var knockback = 0
var pierce_count = 0
var direction = Vector2.ZERO
var duration = 5.0
var crit_chance = 0.0
var crit_damage = 1.4

# Compteur de cibles traversées
var hit_count = 0

func _ready():
	# Connexion de la collision
	body_entered.connect(_on_body_entered)
	
	# Autodestruction après X secondes (pour ne pas saturer la mémoire)
	await get_tree().create_timer(duration).timeout
	queue_free()

func _physics_process(delta):
	# Le missile avance tout droit dans sa direction initiale
	position += direction * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		var final_damage = damage
		# On tire un nombre aléatoire entre 0.0 et 1.0
		if randf() < crit_chance:
			# COUP CRITIQUE !
			final_damage = int(damage * crit_damage)
			# Optionnel : Vous pourriez passer un flag 'is_crit' à take_damage plus tard
		# Calcul du recul (dans le sens du missile)
		body.take_damage(final_damage, knockback, direction)
		
		# Gestion du Pierce (Transpercement)
		if hit_count < pierce_count:
			# On a le droit de traverser
			hit_count += 1
		else:
			# On a atteint la limite, on détruit le missile
			queue_free()
