extends Node2D

var id = "compressed_air_tank"
var level = 1
var current_stats = {}

# --- STATS ---
var damage: int = 10
var knockback: float = 20.0
var area: float = 1.0 
var cooldown: float = 1.5
var amount: int = 1
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var tick_interval: float = 0.5
# -------------

var is_attacking = false
var current_punch_hits = []

# Mémorise la dernière direction (par défaut : Droite)
var last_look_right = true

@onready var cooldown_timer = $CooldownTimer
@onready var hitbox = $Hitbox
@onready var sprite = $Hitbox/Sprite2D
@onready var collision_shape = $Hitbox/CollisionShape2D

@export var icon: Texture2D

func _ready():
	#hitbox.visible = false
	#hitbox.monitoring = false
	
	# 1. CENTRAGE & PIVOT
	#hitbox.position = Vector2.ZERO
	
	# On décale le sprite vers la droite pour que l'origine (0,0) soit l'épaule
	#if sprite.texture:
	#	sprite.flip_h = true
	#	var tex_width = sprite.texture.get_width()
	#	var offset_from_body = 16.0
	#	var shift_x = (tex_width / 2.0) + offset_from_body
	#	
	#	sprite.position = Vector2(shift_x, 0)
	#	collision_shape.position = Vector2(shift_x, 0)
	#	
	#	if collision_shape.shape is RectangleShape2D:
	#		collision_shape.shape.size = sprite.texture.get_size()
	
	hitbox.visible = false
	hitbox.monitoring = false
	
	# 1. CENTRAGE & PIVOT (CORRECTION)
	# On déplace la Hitbox entière pour créer l'écart (offset).
	# Le pivot de scaling (0,0 local) sera donc fixe à cette position.
	var offset_from_body = 20.0
	hitbox.position = Vector2(offset_from_body, 0)
	
	# Le sprite, lui, est positionné par rapport à ce pivot.
	if sprite.texture:
		sprite.flip_h = true
		var tex_width = sprite.texture.get_width()
		
		# On ne met plus d'offset ici, juste le centrage du sprite lui-même
		var center_x = tex_width / 2.0
		
		sprite.position = Vector2(center_x, 0)
		collision_shape.position = Vector2(center_x, 0)
		
		if collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size = sprite.texture.get_size()
	
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		
	cooldown_timer.timeout.connect(_try_start_sequence)
	load_stats(1)
	cooldown_timer.start()

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	var base_dmg = float(current_stats.get("damage", 10))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	var base_tick_interval = float(current_stats.get("tick_interval", 0.5))
	tick_interval = float(GameData.get_stat_with_bonuses(base_tick_interval, "tick_interval"))
	
	var base_cd = float(current_stats.get("cooldown", 1.5))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	var base_kb = float(current_stats.get("knockback", 25.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))

func _physics_process(_delta):
	# DETECTION DE LA DIRECTION DU JOUEUR (Input)
	# Cela permet de mettre à jour le sens du coup même pendant le cooldown
	var input_x = Input.get_axis("move_left", "move_right")
	
	if input_x > 0:
		last_look_right = true
	elif input_x < 0:
		last_look_right = false
	
	# Tentative d'attaque
	if cooldown_timer.is_stopped() and not is_attacking:
		_try_start_sequence()

func _try_start_sequence():
	is_attacking = true
	
	# On utilise la direction mémorisée par les inputs
	var look_right = last_look_right
	
	for i in range(amount):
		# Alternance : Coup 1 = direction regardée, Coup 2 = dos, Coup 3 = face...
		var is_facing_target = (i % 2 == 0)
		var final_look_right = look_right if is_facing_target else not look_right
		
		await _perform_punch(final_look_right)
		
		if i < amount - 1:
			await get_tree().create_timer(tick_interval).timeout
	
	is_attacking = false
	cooldown_timer.start()

func _perform_punch(face_right: bool):
	current_punch_hits.clear()
	hitbox.visible = true
	hitbox.monitoring = true
	
	# MIROIR GAUCHE / DROITE
	# scale.x = 1 -> Droite (Normal)
	# scale.x = -1 -> Gauche (Miroir)
	var dir_scale = 1 if face_right else -1
	scale.x = dir_scale 
	scale.y = 1
	
# ANIMATION D'EXTENSION
	# On part d'un point minuscule : 
	# X = 0.1 (très court/écrasé)
	# Y = 0.1 (très fin)
	hitbox.scale = Vector2(0.1, 0.1)
	
	var tween = create_tween()
	var punch_speed = 0.3
	
# On étend vers la taille finale :
	# X = area (portée maximum)
	# Y = 1.0 (hauteur normale)
	tween.tween_property(hitbox, "scale", Vector2(area, area), punch_speed)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# Pause impact
	await get_tree().create_timer(0.05).timeout
	
	hitbox.visible = false
	hitbox.monitoring = false

func _on_hitbox_body_entered(body):
	if body.has_method("take_damage") and body not in current_punch_hits:
		current_punch_hits.append(body)
		
		var final_dmg = damage
		if randf() < crit_chance:
			final_dmg = int(damage * crit_damage)
			
		# Recul dans le sens du coup
		var push_dir = Vector2.RIGHT * scale.x
		
		body.take_damage(final_dmg, knockback, push_dir)
