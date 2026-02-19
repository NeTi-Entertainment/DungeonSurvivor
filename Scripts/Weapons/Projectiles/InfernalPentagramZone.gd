extends Area2D

# Stats reçues de l'arme
var burn_damage = 0
var burn_interval = 0.75
var burn_duration = 1.5
var zone_duration = 1.5
var crit_chance: float = 0.0
var crit_damage: float = 1.4
var target_scale = Vector2.ONE

# Pour s'assurer qu'un ennemi ne prend la brûlure qu'une seule fois par pentagramme
var enemies_burned_history = []

func _ready():
	z_index = -1

	# Durée de vie visuelle du pentagramme au sol
	var life_timer = get_tree().create_timer(zone_duration)
	life_timer.timeout.connect(queue_free)
	
	# Petit effet d'apparition (fade in)
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(_delta):
	# DÉTECTION ACTIVE : Plus fiable que le signal body_entered pour les zones qui grandissent
	# On scanne tous les corps présents dans la zone à chaque frame physique
	var bodies = get_overlapping_bodies()
	
	for body in bodies:
		# Si c'est un ennemi qu'on n'a pas encore brûlé
		if "status_manager" in body and body.status_manager and body not in enemies_burned_history:
			_apply_effect(body)

# Configuration externe (appelée par l'arme)
func setup_stats(dmg, interval, duration, area_scale, chance_crit, dmg_crit):
	burn_damage = dmg
	burn_interval = interval
	burn_duration = duration # La brûlure dure autant que le pentagramme (stat réutilisée)
	zone_duration = duration
	crit_chance = chance_crit
	crit_damage = dmg_crit
	
	# On applique la taille finale (le tween d'apparition ira vers cette valeur)
	target_scale = Vector2(area_scale, area_scale)

func _apply_effect(body):
	if "status_manager" in body and body.status_manager and body not in enemies_burned_history:
		# On marque l'ennemi comme "déjà brûlé par ce pentagramme"
		enemies_burned_history.append(body)
		
		# --- AJOUT CRITIQUE ---
		var final_damage = burn_damage
		if randf() < crit_chance:
			final_damage = int(burn_damage * crit_damage)
		# ----------------------
		
		# On applique le DoT sur l'ennemi via le StatusManager
		body.status_manager.apply_status("burn", {
			"damage": final_damage,
			"tick_rate": burn_interval,
			"duration": burn_duration
		})
