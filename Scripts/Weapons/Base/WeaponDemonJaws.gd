extends Node2D

var id = "demonic_jaws" #
var level = 1
var current_stats = {}
var is_ready = true
var hit_enemies = []

# --- STATS CALCULÉES ---
var damage: int = 20
var knockback: float = 35.0
var amount: int = 1
var cooldown: float = 2.5
var area: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var lifesteal: float = 0.0
# -----------------------

# Distance devant le joueur où la mâchoire apparait
var jaw_distance_from_player = 20.0 

# Angles d'ouverture (en degrés)
var closed_angle = 0.0      # Mâchoire fermée (ligne droite)
var open_angle_top = -45.0  # Mâchoire du haut lève (négatif = sens anti-horaire)
var open_angle_bottom = 45.0 # Mâchoire du bas descend (positif = sens horaire)

@onready var jaws_container = $JawsContainer
@onready var top_jaw = $JawsContainer/TopJaw
@onready var bottom_jaw = $JawsContainer/BottomJaw
@onready var attack_hitbox = $JawsContainer/AttackHitbox
@onready var detection_zone = $DetectionZone
@onready var cooldown_timer = $CooldownTimer
@onready var player = get_parent().get_parent()

@export var icon: Texture2D

func _ready():
	jaws_container.visible = false
	attack_hitbox.monitoring = false
	attack_hitbox.body_entered.connect(_on_hitbox_body_entered)
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Cooldown (Vitesse d'attaque)
	var base_cd = float(current_stats.get("cooldown", 2.5))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Area (Taille mâchoire + Zone détection)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	jaws_container.scale = Vector2(area, area)
	
	# Mise à jour de la détection (portée)
	var range_val = float(current_stats.get("range", 250.0))
	var shape = detection_zone.get_node("CollisionShape2D").shape
	if shape is CircleShape2D: shape.radius = range_val
	
	# 3. Dégâts
	var base_dmg = float(current_stats.get("damage", 20))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 4. Knockback
	var base_kb = float(current_stats.get("knockback", 35.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 5. Amount (Nombre de morsures)
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 6. Critiques & Vol de vie
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))
	
	var base_lifesteal = float(current_stats.get("lifesteal", 0.0))
	lifesteal = GameData.get_stat_with_bonuses(base_lifesteal, "lifesteal")

func _physics_process(_delta):
	if is_ready:
		var target = _find_nearest_enemy()
		if target:
			_start_attack_sequence(target)

func _find_nearest_enemy():
	var bodies = detection_zone.get_overlapping_bodies()
	var nearest = null
	var min_dist = INF
	for b in bodies:
		if b.has_method("take_damage"):
			var d = global_position.distance_squared_to(b.global_position)
			if d < min_dist:
				min_dist = d
				nearest = b
	return nearest

func _start_attack_sequence(target):
	is_ready = false
	hit_enemies.clear()
	
	# 1. Orientation
	var dir = (target.global_position - global_position).normalized()
	jaws_container.rotation = dir.angle()
	
	# 2. Positionnement (On les colle ensemble à la base)
	# IMPORTANT : On met la position Y à 0 pour les DEUX.
	# Le décalage vertical est géré par vos Offsets réglés à l'étape 1 !
	top_jaw.position = Vector2(jaw_distance_from_player, 0)
	bottom_jaw.position = Vector2(jaw_distance_from_player, 0)
	
	# On place la hitbox un peu plus loin (sur les dents)
	attack_hitbox.position = Vector2(jaw_distance_from_player + 40, 0)
	
	# 3. État initial (Fermé)
	top_jaw.rotation_degrees = closed_angle
	bottom_jaw.rotation_degrees = closed_angle
	jaws_container.visible = true
	
	# 4. Séquence d'animation (SÉCURISÉE)
	var tween = create_tween()
	
	# Phase A : OUVERTURE (0.7 sec)
	tween.set_parallel(true)
	tween.tween_property(top_jaw, "rotation_degrees", open_angle_top, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(bottom_jaw, "rotation_degrees", open_angle_bottom, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false) # Stop parallèle obligatoire ici
	
	# Phase B : ATTENTE COURTE (0.1 sec) - Pour bien voir la gueule ouverte
	tween.tween_interval(0.1)
	
	for i in range(amount):
		# Phase C : MORSURE (0.2 sec) - Un peu plus lent pour être visible
		tween.chain().set_parallel(true) # Le chain() force à attendre la fin de l'ouverture
		tween.tween_property(top_jaw, "rotation_degrees", closed_angle, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.tween_property(bottom_jaw, "rotation_degrees", closed_angle, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
	
		# Phase D : DÉGÂTS (Instantané à la fin de la morsure)
		tween.chain().tween_callback(func(): 
			_trigger_bite_impact(dir)
		)
		# 3. RÉOUVERTURE (Si ce n'est pas la dernière morsure)
		if i < amount - 1:
			tween.chain().set_parallel(true)
			tween.tween_property(top_jaw, "rotation_degrees", open_angle_top, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(bottom_jaw, "rotation_degrees", open_angle_bottom, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.set_parallel(false)
			
			# On vide la liste des touchés pour pouvoir remordre les mêmes ennemis au prochain coup
			tween.chain().tween_callback(func(): hit_enemies.clear())

	# Phase E : MAINTIEN FERMÉ (0.3 sec)
	tween.tween_interval(0.3)
	
	# Phase F : FIN
	tween.chain().tween_callback(_finish_attack)

# Fonction helper pour gérer l'activation précise de la hitbox
func _trigger_bite_impact(dir):
	attack_hitbox.monitoring = true
	
	# Shake visuel
	var shake = create_tween()
	shake.tween_property(jaws_container, "position", jaws_container.position + dir * 8, 0.05)
	shake.tween_property(jaws_container, "position", jaws_container.position, 0.05)
	
	# On coupe la détection juste après l'impact (0.1s)
	get_tree().create_timer(0.1).timeout.connect(func(): attack_hitbox.monitoring = false)

func _on_hitbox_body_entered(body):
	if body.has_method("take_damage") and body not in hit_enemies:
		hit_enemies.append(body)
		
		# Calcul Critique
		var final_dmg = damage
		if randf() < crit_chance:
			final_dmg = int(damage * crit_damage)
			# Feedback visuel optionnel pour crit (ex: flash rouge)
			
		# Recul dans le sens de la mâchoire
		var kb_dir = Vector2.RIGHT.rotated(jaws_container.rotation)
		
		# Application Dégâts
		body.take_damage(final_dmg, knockback, kb_dir)
		
		# Application Vol de Vie (Si le joueur a PV < Max)
		if lifesteal > 0.0:
			# Petite chance ou montant fixe, selon ta logique. 
			# Ici : On rend 'lifesteal' PV par ennemi touché (ex: 1.0 = 1 PV)
			if randf() < 0.2: # Exemple : 20% de chance de proc le lifesteal par hit
				# Adapte cette ligne selon comment ton Player gère le soin
				if player.has_method("heal"):
					player.heal(int(lifesteal))
				elif "current_health" in player:
					player.current_health = min(player.current_health + int(lifesteal), player.max_health)

func _finish_attack():
	jaws_container.visible = false
	attack_hitbox.monitoring = false
	cooldown_timer.start()
