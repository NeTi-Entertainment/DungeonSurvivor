extends Node2D

# ID must match GameData
var id = "flint_blades"
var level = 1
var current_stats = {}

# Variables de combat
var is_ready = true
var is_attacking = false
var hit_enemies = []

# Stats locales
var damage = 0
var knockback_force = 0
var duration = 0.3
var amount = 1
var crit_chance = 0.0
var crit_damage = 1.5
var range_multiplier = 1.0 # Pour éloigner le coup du corps

# References
@onready var cooldown_timer = $CooldownTimer
@onready var hitbox = $Hitbox
@onready var sprite_visual = $Hitbox/Sprite2D 
@onready var collision_shape = $Hitbox/CollisionPolygon2D

@onready var player = get_parent().get_parent()

func _ready():
	_disable_hitbox()
	
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	
	# Load level 1
	load_stats(1)

func load_stats(new_level: int):
	level = new_level
	var data = GameData.get_weapon_stats(id, level)
	if data.is_empty(): return
	
	current_stats = data
	
	# --- 1. Dégâts ---
	var base_dmg = float(current_stats.get("damage", 10))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# --- 2. Knockback ---
	var base_kb = float(current_stats.get("knockback", 10.0))
	# On garde le x10 pour la physique spécifique de cette arme
	knockback_force = GameData.get_stat_with_bonuses(base_kb, "knockback") * 10.0
	
	# --- 3. Cooldown (Vitesse d'attaque) ---
	var base_cd = float(current_stats.get("cooldown", 1.5))
	var final_cd = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, final_cd)
	
	# --- 4. Amount (Nombre de coups) ---
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# --- 5. Area (Taille) ---
	var base_area = float(current_stats.get("area", 1.0))
	var final_area = GameData.get_stat_with_bonuses(base_area, "area")
	hitbox.scale = Vector2(final_area, final_area)
	
	# --- 6. Critiques ---
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))
	
	# --- 7. Autres ---
	duration = float(current_stats.get("duration", 0.3))
	range_multiplier = float(current_stats.get("range", 1.0))

func _process(_delta):
	if is_ready and not is_attacking:
		_start_attack_sequence()

func _start_attack_sequence():
	is_ready = false
	is_attacking = true
	cooldown_timer.start()
	
	# 1. VERROUILLAGE DE LA DIRECTION
	# On capture la direction au début de la rafale pour que tous les coups partent au même endroit
	var fixed_direction = Vector2.UP # Défaut
	if player.get("last_facing_direction"):
		fixed_direction = player.last_facing_direction
	
	# 2. RAFALE DE COUPS
	for i in range(amount):
		await _perform_slash(fixed_direction)
		
		# Petit délai très rapide entre les coups (flurry)
		if i < amount - 1:
			await get_tree().create_timer(0.1).timeout
	is_attacking = false

func _perform_slash(direction: Vector2):
	# 1. Positionnement
	# On place la hitbox devant le joueur selon la direction
	# 30px est la distance de base, multipliée par la stat "range"
	var offset_distance = 10.0 * range_multiplier
	hitbox.position = direction * offset_distance
	
	# 2. Rotation (Le coeur de la logique 8 directions)
	# Godot : 0 radian = Droite. 
	# Notre sprite : Regarde vers le Haut.
	# Donc il faut ajouter 90 degrés (PI/2) à l'angle de la direction.
	hitbox.rotation = direction.angle() + PI/2
	
	# 3. Reset des touches
	hit_enemies.clear()
	
	# 4. Activation visuelle et physique
	_enable_hitbox()
	
	# 5. Attente
	await get_tree().create_timer(duration).timeout
	
	# 6. Désactivation
	_disable_hitbox()

func _enable_hitbox():
	hitbox.visible = true
	hitbox.monitoring = true

func _disable_hitbox():
	hitbox.visible = false
	hitbox.monitoring = false

func _on_hitbox_body_entered(body):
	if body.has_method("take_damage") and not body.is_in_group("player"):
		if body in hit_enemies: return 
		
		hit_enemies.append(body)
		
		# Recul : Toujours dans la direction du coup (plus logique pour un slash)
		# Ou opposé au joueur, au choix. Ici on prend opposé au joueur.
		var kb_dir = (body.global_position - player.global_position).normalized()
		
		# Critique
		var final_damage = damage
		if randf() < crit_chance:
			final_damage *= crit_damage
		
		body.take_damage(final_damage, knockback_force, kb_dir)

func _on_cooldown_finished():
	is_ready = true
