extends Area2D

# Identifiant unique de l'arme (doit correspondre à GameData)
var id = "projector"
var level = 1

# Stats actuelles (chargées depuis GameData)
var current_stats = {}

# --- STATS CALCULÉES ---
var damage: int = 5
var knockback: float = 0.0
var area: float = 1.0
var tick_interval: float = 0.5
var crit_chance: float = 0.0
var crit_damage: float = 1.5
# -----------------------

var tick_timer = 0.0

@onready var sprite = $Sprite2D # Assure-toi que ton Sprite s'appelle bien Sprite2D
# Si tu n'as pas de Sprite mais une CollisionShape, on adaptera.

func _ready():
	# Au démarrage, on charge les stats du niveau 1
	load_stats(1)

# Cette fonction va chercher les infos dans le dictionnaire GameData
func load_stats(new_level: int):
	level = new_level
	current_stats = GameData.get_weapon_stats(id, level)
	
	# 1. Dégâts
	var base_dmg = float(current_stats.get("damage", 5))
	damage = int(round(GameData.get_stat_with_bonuses(base_dmg, "damage")))
	
	# 2. Knockback (Repoussement)
	var base_kb = float(current_stats.get("knockback", 0.0))
	knockback = GameData.get_stat_with_bonuses(base_kb, "knockback")
	
	# 3. Area (Taille de la zone)
	var base_area = float(current_stats.get("area", 1.0))
	area = GameData.get_stat_with_bonuses(base_area, "area")
	
	# Application directe de la taille
	scale = Vector2(area, area)
	
	# 4. Intervalle (Fréquence des dégâts)
	# Plus ce chiffre est bas, plus ça tape vite
	var base_tick = float(current_stats.get("tick_interval", 0.5))
	tick_interval = GameData.get_stat_with_bonuses(base_tick, "tick_interval")
	
	# 5. Critiques
	var base_crit = float(current_stats.get("crit_chance", 0.0))
	crit_chance = GameData.get_stat_with_bonuses(base_crit, "crit_chance")
	crit_damage = float(current_stats.get("crit_damage", 1.5))

func _process(delta):
	# Gestion des dégâts continus (Tick Rate)
	# On utilise "tick_interval" défini dans GameData
	var interval = current_stats.get("tick_interval", 0.5) # 0.5 par défaut si pas trouvé
	
	tick_timer += delta
	if tick_timer >= interval:
		_deal_damage_in_zone()
		tick_timer = 0.0

func _deal_damage_in_zone():
	# Récupère tous les corps (ennemis) qui sont DANS la zone (Area2D)
	var overlapping_bodies = get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body.has_method("take_damage"):
			# On applique les dégâts et le recul
			# Note: Le recul (knockback) nécessite la position du joueur pour pousser dans le bon sens
			# Ici, comme c'est une zone autour du joueur, on pousse vers l'extérieur
			# Calcul des dégâts (Critique)
			var final_dmg = damage
			if randf() < crit_chance:
				final_dmg = int(damage * crit_damage)
			
			var push_dir = (body.global_position - global_position).normalized()
			body.take_damage(final_dmg, knockback, push_dir)
