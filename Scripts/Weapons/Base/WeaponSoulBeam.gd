extends Node2D

var id = "soul_beam"
var level = 1
var current_stats = {}

# --- PARAMÈTRES DE GAME FEEL (À ajuster ici !) ---
# Vitesse à laquelle le point d'origine tourne autour du joueur (plus petit = plus lourd)
var origin_rotation_speed = 3.0 
# Vitesse à laquelle le rayon s'aligne vers la souris (plus petit = plus lourd)
var beam_rotation_speed = 3.0
# Distance du cercle autour du joueur
var orbit_radius = 18.0 

# --- STATS CALCULÉES ---
var damage: int = 4
var knockback: float = 2.0
var max_range: float = 100.0
var beam_width_base: float = 15.0
var pierce_count: int = 0
var crit_chance: float = 0.0
var crit_damage: float = 1.4

# --- INTERNE ---
var current_targets = [] # Liste des ennemis touchés à cette frame

@onready var orbit_pivot = $OrbitPivot
@onready var muzzle = $OrbitPivot/Muzzle
@onready var raycast = $OrbitPivot/Muzzle/RayCast2D
@onready var line_2d = $OrbitPivot/Muzzle/Line2D
@onready var damage_timer = $DamageTimer

func _ready():
	damage_timer.timeout.connect(_on_tick)
	
	# Configuration initiale
	muzzle.position = Vector2(orbit_radius, 0)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Dégâts
	var base_dmg = float(current_stats.get("damage", 4))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 2. Vitesse de frappe (Tick Interval)
	# On utilise "Cooldown" pour réduire l'intervalle entre les ticks
	var base_interval = float(current_stats.get("tick_interval", 0.25))
	# Note : get_stat_with_bonuses pour cooldown réduit la valeur (ex: 0.25 -> 0.22)
	var final_interval = GameData.get_stat_with_bonuses(base_interval, "cooldown")
	damage_timer.wait_time = max(0.05, final_interval)
	
	# 3. Portée (Range) -> Pilotée par AREA (Consigne spécifique)
	# On utilise la valeur "area" du JSON comme base de scaling de niveau (1.0 -> 1.4)
	var base_range_scaling = float(current_stats.get("area", 1.0))
	# Et on applique les bonus d'accessoires "Area" dessus
	var final_range_mult = GameData.get_stat_with_bonuses(base_range_scaling, "area")
	max_range = 100.0 * final_range_mult
	
	# 4. Épaisseur (Width) -> Pilotée par AMOUNT (Consigne spécifique)
	# On utilise la valeur "range" du JSON comme base d'épaisseur par niveau (1.0 -> 1.4)
	# (Puisque "area" est prise par la portée, on utilise l'autre colonne qui a les mêmes valeurs)
	var base_thickness_scaling = float(current_stats.get("range", 1.0))
	
	# Amount agit comme multiplicateur direct (1 -> x1, 2 -> x2, etc.)
	var base_amount = int(current_stats.get("amount", 1))
	var final_amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# Formule : Base(15) * Niveau(1.0-1.4) * Amount(1, 2, 3...)
	line_2d.width = beam_width_base * base_thickness_scaling * final_amount
	
	# 5. Autres
	var base_kb = float(current_stats.get("knockback", 2.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# Pierce (Si jamais des accessoires en donnent, sinon 0 de base)
	var base_pierce = int(current_stats.get("pierce", 0))
	pierce_count = int(GameData.get_stat_with_bonuses(base_pierce, "pierce"))
	
	# Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))

func _physics_process(delta):
	var mouse_pos = get_global_mouse_position()
	
	# --- 1. GESTION DU MOUVEMENT (INERTIE) ---
	
	# A. Rotation du Pivot (L'origine tourne autour du joueur)
	# On calcule l'angle idéal vers la souris
	var target_angle = (mouse_pos - global_position).angle()
	# On interpôle doucement l'angle actuel vers la cible (Lerp Angle)
	orbit_pivot.rotation = lerp_angle(orbit_pivot.rotation, target_angle, origin_rotation_speed * delta)
	
	# B. Rotation du Rayon (Le bout vise la souris)
	# Le rayon est enfant du pivot, donc il tourne déjà avec lui.
	# Mais on veut qu'il puisse pointer précisément la souris, avec un peu de retard.
	var angle_to_mouse_from_muzzle = (mouse_pos - muzzle.global_position).angle()
	# On doit convertir cet angle global en local par rapport au pivot
	var local_target_angle = angle_to_mouse_from_muzzle - orbit_pivot.global_rotation
	
	# On applique aussi une inertie ici
	muzzle.rotation = lerp_angle(muzzle.rotation, local_target_angle, beam_rotation_speed * delta)
	
	# Limite d'angle (Constraint 40 degrés)
	# On clamp la rotation locale du muzzle pour qu'il ne tire pas "derrière" son épaule
	var max_angle_rad = deg_to_rad(40)
	muzzle.rotation = clamp(muzzle.rotation, -max_angle_rad, max_angle_rad)
	
	
	# --- 2. LOGIQUE DU RAYON (RAYCAST & PIERCE) ---
	
	current_targets.clear()
	raycast.enabled = true
	raycast.exclude_parent = true
	raycast.clear_exceptions() # On repart à zéro
	
	# Point de fin visuel par défaut (Max Range)
	var cast_vector = Vector2.RIGHT.rotated(0) * max_range # 0 car Raycast est enfant de Muzzle
	raycast.target_position = cast_vector
	raycast.force_raycast_update() # Obligatoire pour avoir le résultat immédiat
	
	var final_beam_end_point = cast_vector # Local
	var remaining_pierce = pierce_count
	
	# Boucle de Pierce
	while true:
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			var collision_point = raycast.get_collision_point() # Global
			
			# On convertit le point de collision global en local pour le Line2D
			var local_col_point = muzzle.to_local(collision_point)
			
			if collider.has_method("take_damage"):
				current_targets.append(collider)
				
				if remaining_pierce > 0:
					# ON TRAVERSE !
					remaining_pierce -= 1
					raycast.add_exception(collider) # On ignore cet ennemi
					raycast.force_raycast_update() # On relance le rayon TOUT DE SUITE
					# La boucle continue, on va chercher ce qu'il y a derrière
				else:
					# ON BLOQUE (Fin du rayon sur l'ennemi)
					final_beam_end_point = local_col_point
					break
			else:
				# C'est un mur ou autre chose
				final_beam_end_point = local_col_point
				break
		else:
			# Rien touché, le rayon va au max
			break
	
	# --- 3. MISE À JOUR VISUELLE ---
	line_2d.points = [Vector2.ZERO, final_beam_end_point]

func _on_tick():
	# Applique les dégâts à tout ce qui est traversé
	for target in current_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			var push_dir = Vector2.RIGHT.rotated(orbit_pivot.rotation + muzzle.rotation)
			
			# Calcul Critique
			var final_damage = damage
			if randf() < crit_chance:
				final_damage = int(damage * crit_damage)
				# Feedback visuel critique possible ici
			
			target.take_damage(final_damage, knockback, push_dir)
