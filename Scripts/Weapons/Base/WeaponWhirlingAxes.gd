extends Node2D

var id = "whirling_axes"
var level = 1
var current_stats = {}
var is_ready = true

# Configuration visuelle
var radius = 80.0 # Distance au joueur
var axe_sprite_texture = preload("res://Assets/WhirlingAxe.png") 

# STATS CALCULÉES
var damage: int = 10
var knockback: float = 40.0
var cooldown: float = 5.0
var duration: float = 1.5
var amount: int = 2
var area: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 1.4

@onready var rotator = $Rotator
@onready var cooldown_timer = $CooldownTimer

@export var icon: Texture2D

# Stockage des haches créées
var active_axes = []

func _ready():
	cooldown_timer.timeout.connect(func(): is_ready = true)
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Cooldown (Appliqué à la fin de l'attaque)
	var base_cd = float(current_stats.get("cooldown", 5.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Dégâts
	var base_dmg = float(current_stats.get("damage", 10))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 3. Knockback
	var base_kb = float(current_stats.get("knockback", 40.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 4. Duration (Durée de la rotation)
	var base_dur = float(current_stats.get("duration", 1.5))
	duration = GameData.get_stat_with_bonuses(base_dur, "duration")
	
	# 5. Amount (Nombre de haches)
	var base_amount = int(current_stats.get("amount", 2))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 6. Area (Taille des haches)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 7. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))

func _process(_delta):
	if is_ready:
		_start_spin()

func _start_spin():
	is_ready = false
	
	# 1. Nettoyage et Réinitialisation
	_clear_axes()
	rotator.rotation = 0 
	
	# 2. Création des Haches (Utilisation des stats calculées)
	var angle_step = TAU / amount 
	
	for i in range(amount):
		_spawn_axe(i * angle_step, area)
	
	# 3. Calcul de la rotation (Basé sur la Durée)
	# Règle conservée : 1 tour complet prend 1.5s de base. 
	# Si la durée augmente, on tourne plus longtemps à la même vitesse.
	var base_rotation_time = 1.5 
	var total_turns = duration / base_rotation_time
	var final_rotation = total_turns * TAU 
	
	# Rotation inverse pour que la hache reste droite ou tourne sur elle-même
	var self_spin_rotation = -final_rotation * 5.0
	
	# 4. Animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Rotation du conteneur
	tween.tween_property(rotator, "rotation", final_rotation, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	# Rotation individuelle des haches
	for axe in active_axes:
		var target_rot = axe.rotation + self_spin_rotation
		tween.tween_property(axe, "rotation", target_rot, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	tween.set_parallel(false)
	tween.tween_callback(_on_spin_finished)

func _spawn_axe(angle_offset: float, scale_mult: float):
	var axe_area = Area2D.new()
	axe_area.collision_layer = 0
	axe_area.collision_mask = 2 # Ennemis
	
	# Positionnement
	var pos = Vector2(radius, 0).rotated(angle_offset)
	axe_area.position = pos
	axe_area.rotation = angle_offset
	axe_area.scale = Vector2(scale_mult, scale_mult)
	
	# Collision
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(32, 32) 
	col.shape = rect
	axe_area.add_child(col)
	
	# Visuel
	var sprite = Sprite2D.new()
	if axe_sprite_texture:
		sprite.texture = axe_sprite_texture
	else:
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(32, 32)
		sprite.texture = placeholder
	axe_area.add_child(sprite)
	
	# Connexion Signal
	axe_area.body_entered.connect(_on_axe_body_entered)
	
	rotator.add_child(axe_area)
	active_axes.append(axe_area)

func _on_axe_body_entered(body):
	if body.has_method("take_damage"):
		var kb_dir = (body.global_position - global_position).normalized()
		
		# Calcul Critique
		var final_dmg = damage
		if randf() < crit_chance:
			final_dmg = int(damage * crit_damage)
		
		body.take_damage(final_dmg, knockback, kb_dir)

func _on_spin_finished():
	_clear_axes()
	cooldown_timer.start()

func _clear_axes():
	for axe in active_axes:
		if is_instance_valid(axe): axe.queue_free()
	active_axes.clear()
