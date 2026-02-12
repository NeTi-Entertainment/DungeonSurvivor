extends Area2D

# Stats (mises à jour via setup)
var speed = 300.0
var damage = 10
var knockback = 10.0
var bounce_count = 3
var bounce_range = 300.0
var direction = Vector2.ZERO
var duration = 5.0

# Gestion Critique (Nouveau)
var is_critical = false
var crit_damage_mult = 1.5

# Mémoire du projectile
var hit_history = [] 
var target_to_chase: Node2D = null

func _ready():
	body_entered.connect(_on_body_entered)
	# Le timer est géré via setup maintenant pour utiliser la stat duration
	get_tree().create_timer(duration).timeout.connect(queue_free)
	
func setup(stats: Dictionary, initial_target: Node2D):
	# 1. Extraction des stats
	damage = stats["damage"]
	knockback = stats["knockback"]
	speed = stats["speed"]
	bounce_count = stats["bounces"]
	duration = stats["duration"]
	
	# 2. Calcul Critique
	var chance = stats["crit_chance"]
	crit_damage_mult = stats["crit_damage"]
	if randf() < chance:
		is_critical = true
		modulate = Color(2.0, 0.5, 0.5) # Effet visuel rouge brillant
		scale *= 1.2
	
	# 4. Initialisation du mouvement
	if is_instance_valid(initial_target):
		target_to_chase = initial_target
		# On initialise la direction vers la cible immédiatement
		direction = (target_to_chase.global_position - global_position).normalized()
		velocity = direction * speed
		rotation = direction.angle()
	else:
		# CAS "Tir Aléatoire" (si amount > 1 et pas d'ennemis, ou si premier tir rate)
		var rand_angle = randf() * TAU
		direction = Vector2.RIGHT.rotated(rand_angle)
		velocity = direction * speed
		rotation = direction.angle()

# --- TOUT CE QUI SUIT EST IDENTIQUE A TON COMPORTEMENT D'ORIGINE ---
# (Seule la ligne de dégâts change pour appliquer le critique)

var velocity = Vector2.ZERO # Variable utilisée par ton script original

func _physics_process(delta):
	# LOGIQUE DE GUIDAGE (HOMING) - Identique
	if is_instance_valid(target_to_chase):
		direction = (target_to_chase.global_position - global_position).normalized()
	
	# Mouvement 
	position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body):
	if body.has_method("take_damage") and body not in hit_history:
		_hit_enemy(body)

func _hit_enemy(target):
	# Calcul des dégâts finaux (Ajout critique)
	var final_dmg = damage
	if is_critical:
		final_dmg = int(damage * crit_damage_mult)

	# Application Dégâts - Identique
	target.take_damage(final_dmg, knockback, direction)
	
	hit_history.append(target)
	bounce_count -= 1
	target_to_chase = null
	
	if bounce_count > 0:
		var next_target = _find_bounce_target(target.global_position)
		if next_target:
			target_to_chase = next_target
			global_position = target.global_position
		else:
			queue_free()
	else:
		queue_free()

func _find_bounce_target(search_center: Vector2):
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var min_dist = INF
	
	for e in all_enemies:
		if e not in hit_history and e.has_method("take_damage"):
			var d = search_center.distance_squared_to(e.global_position)
			# Vérification distance carrée (bounce_range * bounce_range)
			if d < min_dist and d < (bounce_range * bounce_range):
				min_dist = d
				nearest = e
	return nearest
