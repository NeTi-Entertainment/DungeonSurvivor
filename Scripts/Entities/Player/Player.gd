extends CharacterBody2D

signal player_died
signal level_up_triggered(level)
signal inventory_updated(weapons: Array, accessories: Array)
#signal experience_changed(current, required) # Pour mettre à jour l'UI

@export var movement_speed: float = 300.0
@export var max_health: int = 100

# Système d'XP
var level: int = 1
var experience: float = 0.0
var experience_required: float = 0.0
var last_facing_direction: Vector2 = Vector2.UP # Par défaut vers la droite

var current_health: int = 100
var current_gold: int = 0

var armor: float = 0.0
var armor_pierce: float = 0.0
var pickup_range: float = 10.0
var recovery: float = 0.0
var saved_resources_ratio: float = 0.5

var gold_gain_multiplier: float = 1.0 # Base 100% (1.0)
var xp_gain_multiplier: float = 1.0 # Base 100% (1.0)
var luck: float = 1.0 # "Chance" générique (pour les événements/procs futurs)
var loot_drop_chance: float = 1.0

var _regen_accumulator: float = 0.0

var reroll_count: int = 0
var skip_count: int = 0
var banish_count: int = 0

var enemy_amount_multiplier: float = 1.0

var is_god_mode: bool = false
var speed_buff_multiplier: float = 1.0

var accessories: Array = []
var weapons: Array = []

# Limites d'inventaire
const MAX_WEAPON_SLOTS = 5
const MAX_ACCESSORY_SLOTS = 5

# Références
@onready var health_bar: ProgressBar = $HealthBar
@onready var xp_bar: ProgressBar = $XPBar
@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var invincibility_timer: Timer = $InvincibilityTimer

func _ready() -> void:
	current_health = max_health
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Initialiser l'XP requise via GameData
	experience_required = GameData.get_xp_requirement(level)
	
	# Configurer la barre d'XP
	xp_bar.min_value = 0
	xp_bar.max_value = experience_required
	xp_bar.value = experience
	
	# Connexion aimant
	if not pickup_area.area_entered.is_connected(_on_pickup_area_entered):
		pickup_area.area_entered.connect(_on_pickup_area_entered)
	
	# --- INITIALISATION DE L'ARME DE DÉPART ---
	var starting_weapon_id = ""
	
	match GameData.selected_character_id:
		"tor_ob1":
			starting_weapon_id = "projector"
			# +10% Zone (Passif TOR-OB1 - à implémenter plus tard)
		"kat":
			starting_weapon_id = "compressed_air_tank"
			# +20% Dégâts physiques (Passif Kat)
			
		"zzokrugug":
			starting_weapon_id = "flint_blades"
			
		"irvikktiti":
			starting_weapon_id = "purifying_missiles"
			
		"krofhon":
			starting_weapon_id = "phase_shift_scepter"
			
		"shaqur":
			starting_weapon_id = "whirling_axes"
			
		"khormol":
			starting_weapon_id = "demonic_jaws"
			
		"perma":
			starting_weapon_id = "tracer_dagger"
		
		"vigo":
			starting_weapon_id = "sanguine_nanobots"
			
		"fram":
			starting_weapon_id = "infernal_pentagram"
			
		"naerum":
			starting_weapon_id = "spike_mine"
			
		"sulphura":
			starting_weapon_id = "first_flame"
			
		"sseroghol":
			starting_weapon_id = "wave_in_a_bottle"
			
		"hojo":
			starting_weapon_id = "fishing_rod"
			
		"guhulgghuru":
			starting_weapon_id = "crystalline_impact"
			
		"omocqitheqq":
			starting_weapon_id = "soul_beam"
			
		"allucard":
			starting_weapon_id = "horn_of_the_oppressed"
			
		"liv, ficu & aduj":
			starting_weapon_id = "triseal"
			
		"gnarlhom":
			starting_weapon_id = "coin_spitting_pouch"
			
		"test_evolution":
			starting_weapon_id = ""
			
		_:
			starting_weapon_id = "projector"
	
	_spawn_weapon(starting_weapon_id)
	
	if not GameData.run_stats_updated.is_connected(update_stats):
		GameData.run_stats_updated.connect(update_stats)
	
	update_stats()
	current_health = max_health
	health_bar.value = current_health
	
	for child in get_children():
		# On vérifie si c'est une arme (si elle a un script avec 'id' ou 'load_stats')
		if child.get("id") != null and child.has_method("load_stats"):
			if not weapons.has(child):
				weapons.append(child)
	
	# Même chose si tu utilises un WeaponsHolder (décommente si besoin)
	if has_node("WeaponsHolder"):
		for child in $WeaponsHolder.get_children():
			if child.get("id") != null and not weapons.has(child):
				weapons.append(child)
	
	call_deferred("emit_inventory_update")

func emit_inventory_update() -> void:
	inventory_updated.emit(weapons, accessories)

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * movement_speed * speed_buff_multiplier
	
	# AJOUT : Mémoriser la direction du regard (uniquement horizontal pour cette arme)
	if input_dir != Vector2.ZERO:
		last_facing_direction = input_dir.normalized()
		
		if input_dir.x != 0:
			#last_facing_direction = Vector2(input_dir.x, 0).normalized()
		# Optionnel : Retourner le sprite visuellement
			sprite.flip_h = input_dir.x < 0
	
	move_and_slide()
	
	# --- LOGIQUE DE RÉGÉNÉRATION ---
	if recovery > 0 and current_health < max_health:
		_regen_accumulator += recovery * delta
		if _regen_accumulator >= 1.0:
			var heal_amount = floor(_regen_accumulator)
			heal(int(heal_amount))
			_regen_accumulator -= heal_amount

# --- GESTION XP ---
func gain_experience(amount: int) -> void:
	var final_xp = amount * xp_gain_multiplier
	experience += final_xp
	
	# Si on dépasse le seuil, on Level Up
	if experience >= experience_required:
		level_up()
	else:
		# Sinon on met juste à jour la barre
		_update_xp_ui()

func level_up() -> void:
	experience -= experience_required
	level += 1
	experience_required = GameData.get_xp_requirement(level)
	
	# Mise à jour immédiate de la barre pour le nouveau niveau
	_update_xp_ui()
	
	# ON PRÉVIENT LE JEU QU'ON A LEVEL UP (Pour ouvrir le menu)
	level_up_triggered.emit(level)

func _update_xp_ui() -> void:
	xp_bar.max_value = experience_required
	xp_bar.value = experience

func update_stats():
	var base_hp = 100.0 
	var base_spd = 300.0
	
	max_health = int(GameData.get_stat_with_bonuses(base_hp, "health"))
	if health_bar:
		health_bar.max_value = max_health
	armor = GameData.get_stat_with_bonuses(0.0, "armor")
	recovery = GameData.get_stat_with_bonuses(0.0, "recovery")
	saved_resources_ratio = GameData.get_stat_with_bonuses(0.5, "saved_resources")
	movement_speed = GameData.get_stat_with_bonuses(base_spd, "movement_speed")
	gold_gain_multiplier = GameData.get_stat_with_bonuses(1.0, "gold_gain")
	xp_gain_multiplier = GameData.get_stat_with_bonuses(1.0, "xp_gain")
	pickup_range = GameData.get_stat_with_bonuses(10.0, "pickup_range")
	armor_pierce = GameData.get_stat_with_bonuses(0.0, "armor_pierce")
	enemy_amount_multiplier = GameData.get_stat_with_bonuses(1.0, "enemy_amount")
	luck = GameData.get_stat_with_bonuses(1.0, "luck")
	loot_drop_chance = luck
	
	# Mise à jour collision shape (Ton code existant)
	if pickup_area and pickup_area.has_node("CollisionShape2D"):
		var shape = pickup_area.get_node("CollisionShape2D").shape
		if shape is CircleShape2D:
			shape.radius = pickup_range
		
	var targets = get_children()
	if has_node("WeaponsHolder"):
		targets.append_array($WeaponsHolder.get_children())
	for child in targets:
		if child.has_method("load_stats") and "level" in child:
			# On recharge les stats de l'arme avec son niveau actuel
			# Comme load_stats appelle GameData.get_stat_with_bonuses, les nouveaux buffs seront appliqués !
			child.load_stats(child.level)
	
	reroll_count = int(GameData.get_stat_with_bonuses(0.0, "reroll"))
	skip_count = int(GameData.get_stat_with_bonuses(0.0, "skip"))
	banish_count = int(GameData.get_stat_with_bonuses(0.0, "banish"))
	print("\n=== [DEBUG] STATS GLOBALES APRÈS CALCUL (BUFF INCLUS) ===")
	print("JOUEUR | HP Max: %s | Armure: %s | Vitesse: %s | Récup: %s" % [max_health, armor, movement_speed, recovery])
	print("JOUEUR | Chance: %s | Portée Attraction: %s | Perce-Armure: %s" % [luck, pickup_range, armor_pierce])
	print("JOUEUR | Multipliers -> Or: %s | XP: %s" % [gold_gain_multiplier, xp_gain_multiplier])
	
	# Log spécifique pour les armes (on vérifie le WeaponsHolder)
	if has_node("WeaponsHolder"):
		print("--- ARMES ---")
		for weapon in $WeaponsHolder.get_children():
			# On affiche les stats courantes si l'arme possède les propriétés standards
			var w_info = "Arme: " + weapon.name 
			if "damage" in weapon: w_info += " | Dmg: " + str(weapon.damage)
			if "cooldown" in weapon: w_info += " | Cd: " + str(weapon.cooldown)
			if "tick_interval" in weapon: w_info += " | Tck: " + str(weapon.tick_interval)
			if "area" in weapon: w_info += " | Area: " + str(weapon.area)
			if "amount" in weapon: w_info += " | Amt: " + str(weapon.amount)
			if "duration" in weapon: w_info += " | Dur: " + str(weapon.duration)
			if "projectile_speed" in weapon: w_info += " | ProjSpd: " + str(weapon.projectile_speed)
			if "crit_chance" in weapon: w_info += " | CritC: " + str(weapon.crit_chance)
			if "crit_damage" in weapon: w_info += " | CritD: " + str(weapon.crit_damage)
			if "range" in weapon: w_info += " | Range: " + str(weapon.range)
			if "knockback" in weapon: w_info += " | Knock: " + str(weapon.knockback)
			if "lifesteal" in weapon: w_info += " | Ls: " + str(weapon.lifesteal)
			print(w_info)
	print("=========================================================\n")

# --- GESTION DÉGÂTS ---
func take_damage(amount: int) -> void:
	if is_god_mode: return
	
	# Maintenant, on s'assure que les degats finaux sont un
	# entier mais on permet a l'armure de 0.5 de compter.
	var damage_reduction = armor
	var final_damage = max(1, amount - int(damage_reduction))
	
	if not invincibility_timer.is_stopped():
		return
	
	current_health -= final_damage
	health_bar.value = current_health
	invincibility_timer.start()
	
	if current_health <= 0:
		player_died.emit()

# --- GESTION SOIN ---
func heal(amount: int) -> void:
	if current_health >= max_health:
		return
		
	current_health += amount
	
	# On s'assure de ne pas dépasser le maximum
	if current_health > max_health:
		current_health = max_health
		
	health_bar.value = current_health

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("attract"):
		area.attract(self)

func add_gold(amount: int):
	var bonus_gold = round(amount * gold_gain_multiplier)
	current_gold += int(bonus_gold)

func _spawn_weapon(weapon_id: String) -> void:
	if not GameData.weapon_data.has(weapon_id): return
	
	var path = GameData.weapon_data[weapon_id].get("scene_path")
	if path:
		var w_scene = load(path)
		var w_instance = w_scene.instantiate()
		$WeaponsHolder.add_child(w_instance)
		w_instance.load_stats(1)
	if weapon_id == "coin_spitting_pouch":
		add_gold(20)

func activate_god_mode(duration: float):
	is_god_mode = true
	# Effet visuel : Le joueur devient doré
	modulate = Color(1, 0.84, 0) 
	
	# On attend la durée
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	
	is_god_mode = false
	modulate = Color.WHITE

func activate_speed_buff(duration: float):
	speed_buff_multiplier = 2.0
	
	# Effet visuel : Teinte cyan légère sur le sprite uniquement (si possible) ou le joueur
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 1, 1), 0.5)
	
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	
	speed_buff_multiplier = 1.0
	
	# Retour à la normale
	var tween_back = create_tween()
	tween_back.tween_property(sprite, "modulate", Color.WHITE, 0.5)

func add_weapon(weapon_scene: PackedScene) -> void:
	# ... (ton code existant d'instanciation) ...
	var new_weapon = weapon_scene.instantiate()
	if has_node("WeaponsHolder"):
		$WeaponsHolder.add_child(new_weapon)
	else:
		add_child(new_weapon)
	weapons.append(new_weapon)
	inventory_updated.emit(weapons, accessories)

# Fonction future pour ajouter un accessoire
func add_accessory(accessory_data: Resource) -> void:
	accessories.append(accessory_data)
	
	inventory_updated.emit(weapons, accessories)
