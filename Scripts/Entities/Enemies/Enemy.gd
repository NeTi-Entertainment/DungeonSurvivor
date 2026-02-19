extends CharacterBody2D

signal enemy_died(enemy: Node2D)

var stats: EnemyStats
var current_hp: int
var is_dying: bool = false
@export var is_boss: bool = false

var player_ref: CharacterBody2D = null
var status_manager: StatusManager = null
@onready var sprite_2d = $Sprite2D
@onready var collision_shape = $CollisionShape2D

var knockback_velocity = Vector2.ZERO
var knockback_decay: float = 5.0

var xp_gem_scene = preload("res://Scenes/Loot/ExperienceGem.tscn")
var coin_scene = preload("res://Scenes/Loot/GoldCoin.tscn")
var loot_bag_scene = preload("res://Scenes/Loot/LootBag.tscn")

func _ready() -> void:
	add_to_group("enemies")
	status_manager = StatusManager.new()
	add_child(status_manager)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
	if stats:
		var collider = $CollisionShape2D
		var new_shape = CircleShape2D.new()
		new_shape.radius = stats.hitbox_radius
		collider.shape = new_shape

func setup(stats_data: EnemyStats) -> void:
	if not stats_data:
		push_error("ERREUR : Pas de stats fournies à l'ennemi !")
		return
		
	stats = stats_data
	
	# Application des stats de survie
	current_hp = stats.max_hp
	
	# Application du visuel et de la taille
	if stats.texture and sprite_2d:
		sprite_2d.texture = stats.texture
		sprite_2d.scale = Vector2(stats.scale, stats.scale)
	
	if collision_shape:
		collision_shape.scale = Vector2(stats.scale, stats.scale)

func _physics_process(delta: float) -> void:
	if not stats or GameData.is_enemies_frozen:
		return
	#if not stats: return
	var direction = Vector2.ZERO
	if player_ref:
		direction = global_position.direction_to(player_ref.global_position)
		
	velocity = (direction * stats.speed) + knockback_velocity
	move_and_slide()
	if velocity.x > 0:
		sprite_2d.flip_h = true  # On inverse pour regarder à DROITE
	elif velocity.x < 0:
		sprite_2d.flip_h = false # On remet normal pour regarder à GAUCHE
	
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_decay * delta)
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(stats.damage)

func take_damage(damage_amount: int, knockback_force: float = 0.0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dying: return
	
	GameData.damage_taken.emit(damage_amount, global_position, false)
	
	# Debug : One-shot mode
	if GameData.debug_one_shot_mode:
		damage_amount = 999999
	
	var final_damage = damage_amount
	if stats and stats.armor > 0:
		var player_armor_pierce = 0.0
		if is_instance_valid(player_ref):
			player_armor_pierce = player_ref.armor_pierce
		var effective_armor = max(0.0, stats.armor - player_armor_pierce)
		final_damage = max(1, damage_amount - int(effective_armor))
	current_hp -= final_damage
	
	if knockback_force > 0 and stats:
		var resistance_factor = clamp(1.0 - stats.knockback_resistance, 0.0, 1.0)
		knockback_velocity = knockback_dir * knockback_force * resistance_factor
	
	modulate = Color(10, 10, 10)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
	
	if current_hp <= 0:
		die()

func die() -> void:
	if is_dying: return
	is_dying = true
	
	if xp_gem_scene and stats:
		var xp = xp_gem_scene.instantiate()
		var elapsed_min = GameTimer.get_elapsed_time() / 60.0
		var value = 1
		var roll = randf()

		if elapsed_min < 5.0:
			value = 1 # 100% Bleu
		elif elapsed_min < 10.0:
			if roll < 0.3: value = 5 # 30% Vert
			else: value = 1
		elif elapsed_min < 15.0:
			if roll < 0.2: value = 10 # 20% Rouge
			elif roll < 0.6: value = 5 # 40% Vert
			else: value = 1
		else:
			if roll < 0.1: value = 25 # 10% Violet
			elif roll < 0.5: value = 10 # 40% Rouge
			else: value = 5 # 50% Vert
		if xp.has_method("setup"): 
			xp.setup(value)
		_spawn_loot(xp)
	
	#luck_mult = shop luck bonus + bait accessory + run bonuses
	var luck_mult = 1.0
	if is_instance_valid(player_ref):
		luck_mult = player_ref.luck
	var coin_drop_chance = clamp(0.5 * luck_mult, 0.0, 0.8)
	if GameData.is_gold_rush_active:
		coin_drop_chance = 1.0
	
	if coin_scene and randf() < coin_drop_chance:
		var coin = coin_scene.instantiate()
		
		var value = 1
		if GameData.is_gold_rush_active: value = 2
		
		if coin.has_method("setup"):
			coin.setup(value)
		else:
			coin.value = value
		_spawn_loot(coin)
	
	if is_instance_valid(player_ref):
		luck_mult = player_ref.loot_drop_chance
		
	var drop_data = GameData.calculate_loot_drop(luck_mult, is_boss)
	
	if not drop_data.is_empty():
		var bag = loot_bag_scene.instantiate()
		bag.setup(drop_data["id"], drop_data["type"])
		_spawn_loot(bag)
		
	if status_manager:
		status_manager.clear_all_statuses()
	enemy_died.emit(self)
	
	queue_free()

func _spawn_loot(loot_instance: Node2D):
	loot_instance.global_position = global_position
	
	get_tree().current_scene.call_deferred("add_child", loot_instance)
	
	var angle = randf() * TAU 
	var distance = randf_range(5.0, 20.0)
	var offset = Vector2.from_angle(angle) * distance
	var target_pos = global_position + offset
	
	var tween = loot_instance.create_tween()
	
	tween.tween_property(loot_instance, "global_position", target_pos, 0.4)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)
