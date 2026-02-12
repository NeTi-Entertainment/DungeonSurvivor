extends Node2D

signal sequence_finished

# Vos variables existantes
var damage = 0
var knockback = 0
var swing_duration = 0.3
var current_swing_index = 0
var total_swings = 1
var range_scale = 1.0
var crit_chance = 0.0
var crit_damage = 1.5
var swing_delay = 0.15 
var is_swinging_active = false 

# --- NOUVELLES VARIABLES ---
var speed_multiplier = 1.0
var swing_offset = 0.0 # C'est cette valeur qu'on va animer (de -90 à +90 degrés)
var is_sequence_active = false # Pour savoir si on doit suivre la souris

@onready var hitbox = $Hitbox
@onready var tip = $Hitbox/Tip
@onready var swipe_trail = $SwipeTrail

func _ready():
	hitbox.body_entered.connect(_on_body_entered)
	visible = false
	hitbox.monitoring = false
	swipe_trail.clear_points()
	swipe_trail.modulate.a = 0.0

func _process(_delta):
	# LOGIQUE DE SUIVI DE LA SOURIS
	if is_sequence_active:
		var mouse_pos = get_global_mouse_position()
		# L'angle de base est celui vers la souris
		var aim_angle = (mouse_pos - global_position).angle()
		# On ajoute l'offset de l'animation (le balayage)
		rotation = aim_angle + swing_offset
	
	# LOGIQUE DE TRAINÉE (Votre code existant)
	if is_swinging_active:
		swipe_trail.add_point(tip.global_position)
		if swipe_trail.get_point_count() > 30:
			swipe_trail.remove_point(0)

func setup_stats(stats: Dictionary):
	# On reprend vos stats exactes
	damage = int(stats.get("damage", 14))
	knockback = float(stats.get("knockback", 10.0))
	range_scale = float(stats.get("area", 1.0))
	total_swings = int(stats.get("amount", 1))
	crit_chance = float(stats.get("crit_chance", 0.0))
	crit_damage = float(stats.get("crit_damage", 1.5))
	
	# Récupération du multiplicateur de vitesse
	speed_multiplier = float(stats.get("speed_mult", 1.0))
	
	# Application de la taille
	scale = Vector2(range_scale, range_scale)

func start_attack_sequence(_unused_target_pos = null):
	visible = true
	is_sequence_active = true # Active le suivi de souris dans _process
	current_swing_index = 0
	_perform_swing(0)

func _perform_swing(swing_idx):
	if swing_idx >= total_swings:
		visible = false
		is_sequence_active = false
		emit_signal("sequence_finished")
		return

	is_swinging_active = true
	hitbox.monitoring = true
	swipe_trail.clear_points()
	swipe_trail.modulate.a = 1.0
	
	# Calcul des durées modifiées par la vitesse d'attaque
	# Plus le multiplier est haut, plus le temps est court
	var actual_duration = swing_duration / speed_multiplier
	var actual_delay = swing_delay / speed_multiplier
	
	# Calcul des angles relatifs (Offset)
	# On oscille entre -90° (-PI/2) et +90° (PI/2) par rapport à la souris
	var start_offset = -PI / 2.0
	var end_offset = PI / 2.0
	
	# Inversion du sens 1 coup sur 2
	if swing_idx % 2 != 0:
		var temp = start_offset
		start_offset = end_offset
		end_offset = temp
	
	# On place le bâton au début du coup immédiatement
	swing_offset = start_offset
	
	var tween = create_tween()
	
	# 1. On anime 'swing_offset' au lieu de 'rotation'
	tween.tween_property(self, "swing_offset", end_offset, actual_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Fin du mouvement actif
	tween.tween_callback(func(): is_swinging_active = false)
	
	# 3. Fondu de la trainée + Délai (accéléré aussi)
	tween.parallel().tween_property(swipe_trail, "modulate:a", 0.0, actual_delay)
	
	# 4. Attente du délai
	tween.tween_interval(actual_delay)
	
	# 5. Coup suivant
	tween.tween_callback(func(): _perform_swing(swing_idx + 1))

func _on_body_entered(body):
	if body.has_method("take_damage"):
		var final_dmg = damage
		if randf() < crit_chance:
			final_dmg = int(damage * crit_damage)
			
		var push_dir = (body.global_position - global_position).normalized()
		body.take_damage(final_dmg, knockback, push_dir)
		
		# Logique hit_history si vous voulez éviter de toucher 2 fois le même ennemi sur un swing
		# (Non incluse ici pour rester simple, comme votre fichier actuel)
