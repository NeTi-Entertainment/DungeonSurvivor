extends Area2D

# Stats
var damage = 0
var knockback = 0
var speed = 300.0
var duration = 5.0
var pierce_count = 0
var direction = Vector2.RIGHT

# Critiques
var is_critical = false
var crit_damage_mult = 1.5

# Paramètres Hélicoïdaux
var amplitude = 15.0 # Écartement max (largeur de l'hélice)
var frequency = 15.0 # Vitesse de rotation
var phase_offset = 0.0 # 0 pour le premier, PI pour le second
var time_lived = 0.0

# On stocke la position "centrale" théorique pour calculer l'oscillation autour
var pivot_position = Vector2.ZERO

func _ready():
	# Initialisation de la position pivot
	pivot_position = global_position
	
	# Destruction auto
	get_tree().create_timer(duration).timeout.connect(queue_free)
	
	body_entered.connect(_on_body_entered)

func setup(stats: Dictionary, dir: Vector2, phase: float):
# Récupération directe des valeurs calculées
	damage = stats["damage"]
	knockback = stats["knockback"]
	speed = stats["projectile_speed"]
	duration = stats["duration"]
	pierce_count = stats["pierce"]
	
	# Gestion de la taille et de l'amplitude
	var area = stats["area"]
	scale = Vector2(area, area)
	amplitude = 20.0 * area # L'écartement grandit avec la taille
	
	# Calcul Critique (dès le tir)
	var chance = stats["crit_chance"]
	crit_damage_mult = stats["crit_damage"]
	
	if randf() < chance:
		is_critical = true
		modulate = Color(2.5, 0.5, 0.5) # Flash rouge pour indiquer le critique
	
	direction = dir
	phase_offset = phase
	rotation = direction.angle()

func _physics_process(delta):
	time_lived += delta
	
	# 1. On avance le point de pivot tout droit
	pivot_position += direction * speed * delta
	
	# 2. On calcule le décalage latéral (Hélicoïdal)
	# On utilise la direction perpendiculaire (orthogonal)
	# Vector2(-y, x) est perpendiculaire à (x, y)
	var perp_dir = Vector2(-direction.y, direction.x)
	
	# Formule de l'onde : sin(temps * vitesse + décalage) * largeur
	var lateral_offset = perp_dir * sin(time_lived * frequency + phase_offset) * amplitude
	
	# 3. Application de la position finale
	global_position = pivot_position + lateral_offset
	
	# 4. Rotation visuelle (Optionnel : pour que le projectile regarde un peu vers l'intérieur)
	# On ajoute la rotation de base + un petit tilt selon le mouvement
	rotation = direction.angle() + (cos(time_lived * frequency + phase_offset) * 0.5)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		var final_dmg = damage
		
		# Application du multiplicateur critique
		if is_critical:
			final_dmg = int(damage * crit_damage_mult)
			
		body.take_damage(final_dmg, knockback, direction)
		
		if pierce_count > 0:
			pierce_count -= 1
		else:
			queue_free()
