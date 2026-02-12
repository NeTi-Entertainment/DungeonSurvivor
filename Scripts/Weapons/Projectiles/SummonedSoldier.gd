extends CharacterBody2D

# --- STATS ---
var move_speed = 150.0 
var attack_range = 60.0
var idle_distance = 100.0 

var current_target: Node2D = null
var player_ref: Node2D = null
var stats_buffer: Dictionary = {}

# --- COMPOSANTS ---
@onready var sword = $SoldierSword
@onready var attack_timer = $AttackTimer
@onready var detection_zone = $DetectionZone

func setup(stats: Dictionary, player: Node2D):
	player_ref = player
	stats_buffer = stats 
	
	var spd_mult = stats.get("move_speed_mult", 1.0)
	move_speed = 150.0 * spd_mult
	
	# Sécurité : on s'assure que range_mult n'est jamais 0
	var r_mult = max(0.5, stats.get("range_mult", 1.0))
	
	detection_radius = 300.0 * r_mult 
	attack_range = 60.0 * r_mult
	
	idle_distance = stats.get("spawn_radius", 100.0)

var detection_radius = 300.0 # Déclaré ici pour être accessible

func _ready():
	detection_zone.monitoring = true
	# Scan large (Ennemis + Joueur + Decor)
	detection_zone.collision_mask = 0b1111 
	
	if not stats_buffer.is_empty():
		_apply_stats()
	
	attack_timer.timeout.connect(_try_attack)

func _apply_stats():
	# 1. Zone de détection
	var col_shape = detection_zone.get_node_or_null("CollisionShape2D")
	if col_shape and col_shape.shape is CircleShape2D:
		col_shape.shape.radius = detection_radius
	
	# 2. Timer d'attaque
	var interval = stats_buffer.get("tick_interval", 1.0)
	attack_timer.wait_time = max(0.1, interval)
	attack_timer.start() 
	
	# 3. Durée de vie
	var duration = stats_buffer.get("duration", 10.0)
	get_tree().create_timer(duration).timeout.connect(_on_death)
	
	# 4. Setup de l'épée
	# Sécurité : on renvoie le range_mult sécurisé
	var safe_range = max(0.5, stats_buffer.get("range_mult", 1.0))
	
	sword.setup_stats(
		stats_buffer.get("damage", 10), 
		stats_buffer.get("knockback", 10), 
		safe_range, 
		stats_buffer.get("crit_chance", 0.0),
		stats_buffer.get("crit_damage", 1.5)
	)

func _physics_process(_delta):
	if not is_instance_valid(player_ref):
		return 
	
	var dist_to_player = global_position.distance_to(player_ref.global_position)
	
	# 1. RECHERCHE (Si pas de cible ou cible morte)
	if not is_instance_valid(current_target):
		current_target = _find_nearest_enemy_in_zone()
	
	# 2. MOUVEMENT
	if is_instance_valid(current_target):
		# COMBAT : On fonce sur l'ennemi
		var dist_to_enemy = global_position.distance_to(current_target.global_position)
		if dist_to_enemy > attack_range: 
			_move_towards(current_target.global_position)
		else:
			velocity = Vector2.ZERO
	else:
		# IDLE : On reste près du joueur
		if dist_to_player > idle_distance:
			_move_towards(player_ref.global_position)
		else:
			velocity = Vector2.ZERO
	
	move_and_slide()
	
	if velocity.x != 0:
		$Sprite2D.flip_h = velocity.x < 0

func _move_towards(target_pos: Vector2):
	var dir = (target_pos - global_position).normalized()
	velocity = dir * move_speed

func _try_attack():
	if is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range + 30.0:
			var dir = (current_target.global_position - global_position).normalized()
			sword.swing(dir)

func _find_nearest_enemy_in_zone():
	var bodies = detection_zone.get_overlapping_bodies()
	var nearest = null
	var min_dist = INF
	
	for b in bodies:
		# CORRECTION CRITIQUE : ON EXCLUT LE JOUEUR
		if b == player_ref or b.is_in_group("player"):
			continue
			
		if b.has_method("take_damage"):
			var d = global_position.distance_squared_to(b.global_position)
			if d < min_dist:
				min_dist = d
				nearest = b
	return nearest

func _on_death():
	queue_free()
