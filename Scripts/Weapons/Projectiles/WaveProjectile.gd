extends Area2D

# --- Paramètres de base (Valeurs en pixels pour le niveau 1) ---
var base_length = 100.0 # Longueur max de la vague (Range)
var base_width = 75.0  # Largeur max de l'écume (Area)

# --- Stats dynamiques ---
var damage = 0
var knockback = 0
var duration = 0.75
var max_length = 0.0
var max_width = 0.0

var crit_chance = 0.0
var crit_damage = 1.4

# --- Variables internes ---
var time_elapsed = 0.0
var hit_history = [] 

@onready var water_body = $WaterBody
@onready var foam_edge = $FoamEdge
@onready var hitbox = $Hitbox

func _ready():
	z_index = -1
	# Au départ, tout est à zéro (sur le joueur)
	scale = Vector2.ONE
	_update_shape(0.0, 0.0)
	
	body_entered.connect(_on_body_entered)
	
	# Destruction auto à la fin de la durée
	get_tree().create_timer(duration + 0.1).timeout.connect(queue_free)

func setup(stats: Dictionary, dir: Vector2):
	damage = stats["damage"]
	knockback = stats["knockback"]
	duration = stats["duration"]
	
	crit_chance = stats["crit_chance"]
	crit_damage = stats["crit_damage"]
	
	# Calcul des dimensions finales (Séparé Largeur / Longueur)
	max_width = base_width * stats["width_mult"]
	max_length = base_length * stats["length_mult"]
	
	# Orientation
	rotation = dir.angle()

func _physics_process(delta):
	time_elapsed += delta
	
	# Progression de 0.0 à 1.0 (linéaire ou courbe)
	var t = clamp(time_elapsed / duration, 0.0, 1.0)
	
	# Interpolation
	var current_len = lerp(0.0, max_length, t)
	var current_wid = lerp(0.0, max_width, t)
	
	_update_shape(current_len, current_wid)

func _update_shape(len_val: float, wid_val: float):
	# On définit les 3 points du triangle localement
	var pt_origin = Vector2.ZERO
	var pt_left = Vector2(len_val, -wid_val / 2.0)
	var pt_right = Vector2(len_val, wid_val / 2.0)
	
	# 1. Mise à jour de l'eau (Triangle plein)
	var poly_points = PackedVector2Array([pt_origin, pt_left, pt_right])
	water_body.polygon = poly_points
	water_body.texture_offset += Vector2(2.0, 0.0) 
	
	# 2. Mise à jour de l'écume (Ligne au bout)
	foam_edge.points = PackedVector2Array([pt_left, pt_right])
	
	# 3. Mise à jour de la Hitbox
	hitbox.polygon = poly_points

func _on_body_entered(body):
	if body.has_method("take_damage") and body not in hit_history:
		hit_history.append(body)
		
		var push_dir = Vector2.RIGHT.rotated(rotation)
		
		# Calcul Critique
		var final_dmg = damage
		if randf() < crit_chance:
			final_dmg = int(damage * crit_damage)
		
		body.take_damage(final_dmg, knockback, push_dir)
