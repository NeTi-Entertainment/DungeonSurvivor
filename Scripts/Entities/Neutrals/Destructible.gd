extends Area2D
class_name Destructible
# Destructible.gd - Objet destructible (caisse, urne, baril, etc.)

# ============================================================================
# STATS
# ============================================================================

var max_hp: int = 3
var current_hp: int = 3

# ============================================================================
# LOOT
# ============================================================================

# Chances de drop (total = 100%)
const DROP_CHANCE_PICKUP_BASE: float = 0.05
const DROP_CHANCE_HEAL_BASE: float = 0.20
const DROP_CHANCE_GOLD_BASE: float = 0.50
const DROP_CHANCE_GOLD_CAP: float = 0.80
# Rien = 0.20 (implicite)

var heal_scene = preload("res://Scenes/Loot/Heal.tscn")  # À créer plus tard
var coin_scene = preload("res://Scenes/Loot/GoldCoin.tscn")
var loot_bag_scene = preload("res://Scenes/Loot/LootBag.tscn")

# ============================================================================
# RÉFÉRENCES
# ============================================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_destroyed: bool = false
var player_ref: CharacterBody2D = null

var active_damage_zones: Dictionary = {}

# ============================================================================
# SETUP
# ============================================================================

func _ready() -> void:
	add_to_group("destructibles")
	area_entered.connect(_on_area_entered)  # Changé de body_entered
	
	# Récupérer la référence au joueur
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func setup(texture: Texture2D, hp: int = 3) -> void:
	"""Configure l'apparence et les HP du destructible"""
	if sprite:
		sprite.texture = texture
	max_hp = hp
	current_hp = hp

func _physics_process(_delta: float) -> void:
	"""Gère les dégâts continus des zones actives (Projecteur, Pentagramme, etc.)"""
	if is_destroyed:
		return
	
	# Récupérer toutes les areas qui touchent actuellement le destructible
	var overlapping = get_overlapping_areas()
	var current_time = Time.get_ticks_msec() / 1000.0  # Temps en secondes
	
	# Nettoyer les zones qui ne sont plus actives
	for area in active_damage_zones.keys():
		if not is_instance_valid(area) or area not in overlapping:
			active_damage_zones.erase(area)
	
	# Traiter chaque zone active
	for area in overlapping:
		# Ignorer si pas une arme
		if not ("damage" in area or area.is_in_group("player_weapon")):
			continue
		
		# Si l'arme a un tick_interval (zone continue), gérer les ticks
		if "tick_interval" in area and area.tick_interval > 0:
			# Première fois qu'on voit cette zone, ou temps écoulé suffisant
			if not active_damage_zones.has(area):
				active_damage_zones[area] = current_time
				take_damage(1)
			else:
				var time_since_last_tick = current_time - active_damage_zones[area]
				if time_since_last_tick >= area.tick_interval:
					active_damage_zones[area] = current_time
					take_damage(1)

# ============================================================================
# DÉGÂTS
# ============================================================================

func _on_area_entered(area: Area2D) -> void:
	"""Détection des projectiles/armes du joueur"""
	if is_destroyed:
		return
	
	# Si c'est une arme ou un projectile
	if "damage" in area or area.is_in_group("player_weapon"):
		take_damage(1)

func take_damage(amount: int) -> void:
	"""Applique des dégâts au destructible"""
	if is_destroyed:
		return
	
	current_hp -= amount
	
	# Effet visuel de hit (flash blanc)
	_flash_hit()
	
	if current_hp <= 0:
		_destroy()

func _flash_hit() -> void:
	"""Flash blanc rapide pour feedback visuel"""
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	sprite.modulate = Color(2, 2, 2, 1)  # Blanc brillant
	
	await get_tree().create_timer(0.1).timeout
	
	if is_instance_valid(sprite):
		sprite.modulate = original_modulate

# ============================================================================
# DESTRUCTION
# ============================================================================

func _destroy() -> void:
	"""Détruit l'objet et drop du loot"""
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# Désactiver les collisions
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Effet de destruction (fade out + scale down)
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.3)
	
	# Drop du loot
	_drop_loot()
	
	# Suppression après l'animation
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _drop_loot() -> void:
	"""Détermine et spawn le loot (2 rolls indépendants)"""
	# Récupérer luck du joueur (boutique + accessoires)
	var luck_mult = 1.0
	if is_instance_valid(player_ref):
		luck_mult = player_ref.luck
	
	# ROLL 1 : Or (indépendant, peut coexister avec heal/pickup)
	var gold_drop_chance = clamp(DROP_CHANCE_GOLD_BASE * luck_mult, 0.0, DROP_CHANCE_GOLD_CAP)
	if randf() < gold_drop_chance:
		_spawn_gold()
	
	# ROLL 2 : Heal ou Pickup (mutuellement exclusifs)
	var heal_pickup_roll = randf()
	var heal_chance = DROP_CHANCE_HEAL_BASE * luck_mult
	var pickup_chance = DROP_CHANCE_PICKUP_BASE * luck_mult
	
	if heal_pickup_roll < heal_chance:
		_spawn_heal()
	elif heal_pickup_roll < (heal_chance + pickup_chance):
		_spawn_pickup()
	# Sinon : rien pour ce roll (or peut quand même avoir drop)

func _spawn_heal() -> void:
	"""Spawn un pickup de soin"""
	# Si la scène n'existe pas encore, on skip silencieusement
	if not ResourceLoader.exists("res://Scenes/Loot/Heal.tscn"):
		print("[Destructible] Heal.tscn n'existe pas encore - skip")
		return
	
	var heal = heal_scene.instantiate()
	heal.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", heal)

func _spawn_gold() -> void:
	"""Spawn une pièce d'or"""
	if not coin_scene:
		return
	
	var coin = coin_scene.instantiate()
	coin.global_position = global_position
	
	# Valeur : 1-3 pièces aléatoire
	var value = randi_range(1, 3)
	if coin.has_method("setup"):
		coin.setup(value)
	else:
		coin.value = value
	
	get_tree().current_scene.call_deferred("add_child", coin)

func _spawn_pickup() -> void:
	"""Spawn un pickup de matériau/consommable (via GameData.calculate_loot_drop)"""
	if not loot_bag_scene:
		return
	
	# Utiliser la même logique que Enemy.gd
	var luck_mult = 1.0
	if is_instance_valid(player_ref):
		luck_mult = player_ref.luck
	
	# calculate_loot_drop gère matériaux (2% × luck) et consommables (0.7% × luck)
	# On force is_boss = false pour les destructibles
	var drop_data = GameData.calculate_loot_drop(luck_mult, false)
	
	if not drop_data.is_empty():
		var bag = loot_bag_scene.instantiate()
		bag.global_position = global_position
		bag.setup(drop_data["id"], drop_data["type"])
		get_tree().current_scene.call_deferred("add_child", bag)
