extends Area2D

enum State { TRAVEL, REBOUND }
var current_state = State.TRAVEL

# Stats
var speed = 600.0
var damage = 12
var knockback = 10.0
var pierce_count = 0
var rebound_count = 1
var direction = Vector2.ZERO
var duration = 5.0

# Critiques
var crit_chance = 0.0
var crit_damage = 1.4

# Variables pour le Rebond
var target_enemy: Node2D = null 
var hit_history = [] 

func _ready():
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(duration).timeout.connect(queue_free)

func setup(stats: Dictionary, target: Node2D):
	damage = stats["damage"]
	knockback = stats["knockback"]
	speed = stats["speed"]
	pierce_count = stats["pierce"]
	rebound_count = stats["rebound"]
	duration = stats["duration"]
	
	crit_chance = stats["crit_chance"]
	crit_damage = stats["crit_damage"]
	
	# AREA (Taille)
	var area_scale = stats["area"]
	scale = Vector2(area_scale, area_scale)
	
	# Direction
	if is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
		rotation = direction.angle()
	else:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
		rotation = direction.angle()

func _physics_process(delta):
	if current_state == State.TRAVEL:
		position += direction * speed * delta
		rotation = direction.angle()
		
	elif current_state == State.REBOUND:
		# On regarde toujours LA cible verrouillée (comportement d'origine)
		if is_instance_valid(target_enemy):
			look_at(target_enemy.global_position)
		else:
			queue_free()

func _on_body_entered(body):
	if current_state == State.TRAVEL:
		if body.has_method("take_damage") and body not in hit_history:
			_handle_hit(body)

func _handle_hit(enemy):
	# 1. Dégâts initiaux (avec Critique)
	var final_dmg = damage
	if randf() < crit_chance:
		final_dmg = int(damage * crit_damage)
		
	enemy.take_damage(final_dmg, knockback, direction)
	hit_history.append(enemy) 
	
	# 2. Gestion du REBOUND
	if rebound_count > 0:
		if pierce_count > 0:
			# CAS A : Pierce + Rebond
			# On CRÉE UNE COPIE pour rebondir SUR CET ENNEMI
			var clone = duplicate()
			get_tree().current_scene.add_child(clone)
			
			# On configure le clone. IMPORTANT : On passe les stats critiques
			clone.setup_rebound_mode(enemy, damage, rebound_count, crit_chance, crit_damage)
			
			# L'original continue
			pierce_count -= 1
			
		else:
			# CAS B : Stop + Rebond
			# Je deviens le rebondeur SUR CET ENNEMI
			setup_rebound_mode(enemy, damage, rebound_count, crit_chance, crit_damage)
	
	else:
		if pierce_count > 0:
			pierce_count -= 1
		else:
			queue_free()

# --- LOGIQUE DE REBOND (Intacte, cible le même ennemi) ---

func setup_rebound_mode(target, dmg_val, rebounds_left, c_chance, c_dmg):
	current_state = State.REBOUND
	target_enemy = target
	damage = dmg_val
	rebound_count = rebounds_left
	crit_chance = c_chance
	crit_damage = c_dmg
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	_perform_rebound_cycle()

func _perform_rebound_cycle():
	if not is_instance_valid(target_enemy):
		queue_free()
		return

	var vector_to_target = target_enemy.global_position - global_position
	var retreat_dist = 80.0
	var random_angle = deg_to_rad(randf_range(-60, 60))
	var retreat_dir = -vector_to_target.normalized().rotated(random_angle)
	
	var target_pos_retreat = target_enemy.global_position + (retreat_dir * retreat_dist)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos_retreat, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.05)
	
	tween.tween_callback(func(): 
		if is_instance_valid(target_enemy):
			var strike_tween = create_tween()
			strike_tween.tween_property(self, "global_position", target_enemy.global_position, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			strike_tween.tween_callback(_on_rebound_hit)
		else:
			queue_free()
	)

func _on_rebound_hit():
	if is_instance_valid(target_enemy):
		# Dégâts du rebond (avec Critique possible à chaque coup)
		var final_dmg = damage
		if randf() < crit_chance:
			final_dmg = int(damage * crit_damage)
			
		target_enemy.take_damage(final_dmg, knockback / 2.0, Vector2.ZERO)
		
		rebound_count -= 1
		if rebound_count > 0:
			_perform_rebound_cycle()
		else:
			queue_free()
	else:
		queue_free()
