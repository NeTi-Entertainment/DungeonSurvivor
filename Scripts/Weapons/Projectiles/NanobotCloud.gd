extends Area2D

var damage = 10
var knockback = 3.0
var tick_interval = 0.5
var is_main_cloud = false # Pour la couleur

# Critiques
var crit_chance = 0.0
var crit_damage = 1.4

@onready var tick_timer = $TickTimer
@onready var sprite = $Sprite2D # Si vous avez un sprite

func setup(stats: Dictionary):
	damage = stats["damage"]
	knockback = stats["knockback"]
	tick_interval = stats["tick_interval"]
	
	crit_chance = stats["crit_chance"]
	crit_damage = stats["crit_damage"]
	
	# Application de la taille
	var area_scale = stats["area"]
	scale = Vector2(area_scale, area_scale)

func _ready():
	# Configuration visuelle pour différencier le principal
	if is_main_cloud:
		modulate = Color(1, 0, 0, 0.8) # Rouge vif
	else:
		modulate = Color(0.7, 0, 0, 0.5) # Rouge sombre transparent
	
	# Démarrage du cycle de dégâts
	tick_timer.wait_time = tick_interval
	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()

func _on_tick():
	# On récupère tous les ennemis actuellement dans la zone
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			# Calcul Critique
			var final_dmg = damage
			if randf() < crit_chance:
				final_dmg = int(damage * crit_damage)
				# Feedback visuel optionnel ici
			
			var kb_dir = (body.global_position - global_position).normalized()
			body.take_damage(final_dmg, knockback, kb_dir)

# Fonction pour mettre à jour la taille via la stat "Area"
func update_size(scale_mult: float):
	scale = Vector2(scale_mult, scale_mult)
