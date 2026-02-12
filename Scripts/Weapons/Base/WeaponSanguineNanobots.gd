extends Node2D

var id = "sanguine_nanobots"
var level = 1
var current_stats = {}

# États
var is_active = false # Est-ce que les nuages sont là ?
var is_on_cooldown = false

# Gestion du Mouvement
var square_distance = 150.0
var current_main_pos_local = Vector2(0, -150) # Position locale actuelle du nuage principal
var target_pos_local = Vector2(0, -150) # Où on veut aller

# STATS CALCULÉES
var damage: int = 10
var knockback: float = 3.0
var tick_interval: float = 0.5
var duration: float = 4.0
var cooldown: float = 9.0
var amount: int = 1
var area: float = 1.0
var cloud_speed: float = 600.0 # Vitesse de déplacement du nuage
var crit_chance: float = 0.0
var crit_damage: float = 1.4 # Base demandée

# Références
var cloud_scene = preload("res://Scenes/Weapons/Projectiles/NanobotCloud.tscn")
var active_clouds = [] # Liste des instances

@onready var cooldown_timer = $CooldownTimer
@onready var duration_timer = $DurationTimer

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	duration_timer.timeout.connect(_on_duration_finished)
	load_stats(1)
	
	# Au démarrage, on lance directement (si pas de CD initial voulu)
	call_deferred("_start_activation")

func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Cooldown
	var base_cd = float(current_stats.get("cooldown", 9.0))
	cooldown = GameData.get_stat_with_bonuses(base_cd, "cooldown")
	cooldown_timer.wait_time = max(0.1, cooldown)
	
	# 2. Duration
	var base_dur = float(current_stats.get("duration", 4.0))
	duration = GameData.get_stat_with_bonuses(base_dur, "duration")
	duration_timer.wait_time = duration
	
	# 3. Dégâts
	var base_dmg = float(current_stats.get("damage", 10))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 4. Amount (Quantité de nuages)
	var base_amount = int(current_stats.get("amount", 1))
	amount = int(GameData.get_stat_with_bonuses(base_amount, "amount"))
	
	# 5. Area (Taille)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# 6. Vitesse de déplacement (Map sur Projectile Speed)
	var base_speed = float(current_stats.get("projectile_speed", 600.0))
	cloud_speed = GameData.get_stat_with_bonuses(base_speed, "projectile_speed")
	
	# 7. Knockback
	var base_kb = float(current_stats.get("knockback", 3.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 8. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.4))
	
	# 9. Tick Interval (généralement fixe ou lié à l'arme, non modifié ici sauf si stat spécifique)
	tick_interval = float(current_stats.get("tick_interval", 0.5))

func _physics_process(delta):
	# 1. Calcul de la cible sur le carré (Input)
	_update_target_position()
	
	# 2. Déplacement fluide du point "Virtuel" principal
	if current_main_pos_local != target_pos_local:
		current_main_pos_local = current_main_pos_local.move_toward(target_pos_local, cloud_speed * delta)
	
	# 3. Mise à jour des nuages (s'ils existent)
	if is_active:
		_update_cloud_positions()

func _update_target_position():
	# On lit les inputs du joueur (Haut/Bas/Gauche/Droite)
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Si pas d'input, on garde la dernière position cible (le nuage ne revient pas au centre)
	if input == Vector2.ZERO:
		return
	
	# Projection sur le carré
	# La logique : On prend la composante la plus forte (X ou Y) et on la pousse au max (square_distance)
	# L'autre composante suit proportionnellement.
	
	var abs_x = abs(input.x)
	var abs_y = abs(input.y)
	var max_val = max(abs_x, abs_y)
	
	if max_val > 0:
		# On normalise par rapport au "bord" du carré, pas par rapport à un cercle
		var scalar = 1.0 / max_val
		target_pos_local = input * scalar * square_distance

func _start_activation():
	if is_on_cooldown: return
	
	is_active = true
	is_on_cooldown = false # On n'est pas en CD, on est en Action
	
	_spawn_clouds()
	duration_timer.start()

func _spawn_clouds():
	# Nettoyage
	for c in active_clouds: c.queue_free()
	active_clouds.clear()
	
# Création du paquet de stats
	var stats_packet = {
		"damage": damage,
		"knockback": knockback,
		"tick_interval": tick_interval,
		"area": area,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage
	}
	
	for i in range(amount):
		var cloud = cloud_scene.instantiate()
		
		# On passe le paquet
		cloud.setup(stats_packet)
		
		# Le premier est le principal
		cloud.is_main_cloud = (i == 0)
		
		# On ajoute à la scène globale pour éviter que le nuage tourne avec le joueur
		# (Il doit suivre la position mais pas la rotation du joueur)
		get_tree().current_scene.add_child(cloud)
		active_clouds.append(cloud)
	
	# Placement initial immédiat
	_update_cloud_positions()

func _update_cloud_positions():
	var player_pos = global_position
	var active_count = active_clouds.size()
	
	for i in range(active_count):
		var cloud = active_clouds[i]
		if not is_instance_valid(cloud): continue
		
		# Le nuage 0 suit exactement current_main_pos_local
		# Les nuages suivants sont décalés angulairement
		
		var angle_offset = (TAU / active_count) * i
		var rotated_pos = current_main_pos_local.rotated(angle_offset)
		
		cloud.global_position = player_pos + rotated_pos

func _on_duration_finished():
	# Fin de l'attaque
	is_active = false
	for c in active_clouds:
		if is_instance_valid(c):
			# Petit effet de disparition (optionnel) ou supression directe
			c.queue_free()
	active_clouds.clear()
	
	# Début du Cooldown
	is_on_cooldown = true
	cooldown_timer.start()

func _on_cooldown_finished():
	is_on_cooldown = false
	# Prêt à repartir
	_start_activation()
