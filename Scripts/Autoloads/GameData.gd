extends Node

signal loot_collected(item_id, amount)
signal run_stats_updated

var debug_one_shot_mode: bool = false

# --- XP CURVE CONFIGURATION (System Design) ---
const XP_BASE = 5
const XP_GROWTH = 10
const XP_CURVE = 2.0

const REPULSION_RADIUS: float = 600.0

var selected_character_id: String = "tor-ob1"

# --- SYSTÈME ÉCONOMIQUE ---
var total_banked_gold: int = 0
var shop_unlocks: Dictionary = {} 
const SAVE_PATH = "user://savegame.save"

var buffs_table = ["buff_buff", "buff_potion", "buff_magnet", "buff_nuke", "buff_freeze", "buff_dice", "buff_invincible", "buff_zeal", "buff_gold", "buff_repulsion"]

var banished_items: Array = []
var boss_defeated: bool = false

# Inventaire permanent (Sauvegardé) : { "iron_scrap": 12, "void_dust": 5 }
var material_inventory: Dictionary = {}
# Inventaire temporaire de la run (Perdu ou réduit à la mort)
var run_materials: Dictionary = {}
# Base de données des loots (Placeholder)
var loot_table = {
	"common": ["Ecorce", "Huile", "Cendres", "Rune", "Mucus", "Gravier"],
	"uncommon": ["Gland", "Plaque de metal", "Charbon", "Eau de lune", "Visceres", "Mousse"],
	"rare": ["Disque dur", "Encens", "Lumiere en bouteille", "Outil sacrificiel", "Brique"],
	"boss": ["Fleur de lys", "Fourrure de bete", "Circuit imprime", "Microprocesseur", "Coeur cramoisi", "Essence de feu", "Foi", "Croix sacree", "Ame en peine", "Croix bafouee", "Silex", "Fossile"]
}

var is_enemies_frozen: bool = false
var is_gold_rush_active: bool = false
var run_stat_bonuses: Dictionary = {}

var buff_definitions = {
	"damage": 			{"value": 0.01, "type": "percent", "display": "Dégâts"}, 
	"area": 			{"value": 0.01, "type": "percent", "display": "Taille de zone"},
	"movement_speed": 	{"value": 0.01, "type": "percent", "display": "Vitesse de déplacement"},
	"cooldown": 		{"value": 0.01, "type": "percent", "display": "Réduction de Cooldown"}, 
	"duration": 		{"value": 0.01, "type": "percent", "display": "Durée d'effet"},
	"max_health": 		{"value": 1.0,  "type": "flat",    "display": "Santé Max"}, 
	"projectile_speed": {"value": 0.01, "type": "percent", "display": "Vitesse Projectile"},
	"crit_chance": 		{"value": 0.01, "type": "flat_percent", "display": "Critique"}, 
	"crit_damage": 		{"value": 0.01, "type": "percent", "display": "Dégâts Critiques"},
	"tick_interval": 	{"value": 0.01, "type": "percent", "display": "Fréquence de Tick"}, 
	"range": 			{"value": 0.01, "type": "percent", "display": "Portée"},
	"knockback": 		{"value": 0.01, "type": "percent", "display": "Recul"},
	"lifesteal": 		{"value": 0.001, "type": "flat",   "display": "Vol de vie"}, 
	"armor": 			{"value": 0.1,  "type": "flat",    "display": "Armure"},
	"recovery": 		{"value": 0.1,  "type": "flat",    "display": "Régénération"},
	"pickup_range": 	{"value": 0.05, "type": "percent", "display": "Zone de Ramassage"}
}

func reset_run_state():
	banished_items.clear()
	boss_defeated = false

func save_bank(run_gold: int):
	total_banked_gold += run_gold
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# On sauvegarde un dictionnaire pour être extensible plus tard
		var data = {
			"gold": total_banked_gold, 
			"shop": shop_unlocks,
			"materials": material_inventory
		}
		file.store_string(JSON.stringify(data))

func load_bank():
	if not FileAccess.file_exists(SAVE_PATH):
		return # Pas de sauvegarde, on commence à 0
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			var data = json.get_data()
			total_banked_gold = int(data.get("gold", 0))
			shop_unlocks = data.get("shop", {})
			material_inventory = data.get("materials", {})
# ---------
func delete_save():
	# 1. On remet les variables en mémoire à zéro
	total_banked_gold = 0
	shop_unlocks = {}
	
	# 2. On écrase le fichier de sauvegarde existant avec ces données vides
	save_bank(0)

# --- CHEAT CODES (P = +10k, O = -10k) ---
func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			total_banked_gold += 10000
			save_bank(0) # Sauvegarde immédiate
		elif event.keycode == KEY_O:
			total_banked_gold = max(0, total_banked_gold - 10000)
			save_bank(0)

# --- SYSTÈME DE BOUTIQUE (SHOP) ---

# Définition des données statiques (Prix et Bonus par niveau selon le PDF)
# Format: "id": {name, type, max_lvl, cost_curve: [prix_lv1, prix_lv2...], bonus_per_lvl}
var shop_definitions = {
	# --- QUALITY OF LIFE ---
	"saved_resources": {
		"name": "Ressources récupérées", 
		"type": "qol", "max_lvl": 5, "bonus": 0.08, # +8%
		"costs": [400, 1300, 2500, 4000, 7500]
	},
	"loot_chance": {
		"name": "Chance de Butin", 
		"type": "qol", "max_lvl": 5, "bonus": 0.03, # +3%
		"costs": [400, 1300, 2500, 4000, 7500]
	},
	"reroll": {
		"name": "Dés pipés", 
		"type": "qol", "max_lvl": 5, "bonus": 1, # +1
		"costs": [200, 1000, 2200, 3500, 5000]
	},
	"banish": {
		"name": "Bannissement", 
		"type": "qol", "max_lvl": 5, "bonus": 1, 
		"costs": [200, 1000, 2200, 3500, 5000]
	},
	"skip": {
		"name": "Passer", 
		"type": "qol", "max_lvl": 5, "bonus": 1, 
		"costs": [200, 1000, 2200, 3500, 5000]
	},
	
	# --- STATISTIQUES ---
	"health": {
		"name": "Vitalité", 
		"type": "stat", "max_lvl": 5, "bonus": 0.05, # +5%
		"costs": [100, 400, 800, 1400, 2200]
	},
	"armor": {
		"name": "Armure", 
		"type": "stat", "max_lvl": 5, "bonus": 0.5, # last level must give 1 full point for a total of 3
		"costs": [400, 1000, 2000, 4000, 6000]
	},
	"recovery": {
		"name": "Régénération", 
		"type": "stat", "max_lvl": 5, "bonus": 0.001, # +0.1%
		"costs": [300, 700, 1400, 2500, 4000]
	},
	"damage": {
		"name": "Dégâts", 
		"type": "stat", "max_lvl": 5, "bonus": 0.03, # +3%
		"costs": [200, 400, 800, 1500, 3000]
	},
	"attack_speed": {
		"name": "Vitesse d'Attaque", 
		"type": "stat", "max_lvl": 5, "bonus": 0.02, # +2%
		"costs": [500, 1200, 2500, 4200, 7500]
	},
	"gold_gain": {
		"name": "Avidité", 
		"type": "stat", "max_lvl": 5, "bonus": 0.05, # +5%
		"costs": [500, 1500, 3000, 5000, 8000]
	},
	"xp_gain": {
		"name": "Sagesse", 
		"type": "stat", "max_lvl": 5, "bonus": 0.05, # +5%
		"costs": [500, 1500, 3000, 5000, 8000]
	},
	"area_of_effect": {
		"name": "Zone d'Effet",
		"type": "stat", "max_lvl": 5, "bonus": 0.025,
		"costs": [300, 700, 1400, 2500, 4000]
	},
	"projectile_speed": {
		"name": "Vitesse de Projectile",
		"type": "stat", "max_lvl": 5, "bonus": 0.03,
		"costs": [300, 700, 1200, 1800, 2500]
	},
	"movement_speed": {
		"name": "Vitesse de Déplacement",
		"type": "stat", "max_lvl": 5, "bonus": 0.02,
		"costs": [300, 800, 1500, 2500, 5000]
	},
	"pickup_range": {
		"name": "Aimant", 
		"type": "stat", "max_lvl": 5, "bonus": 0.04, # +10%
		"costs": [400, 800, 1600, 2800, 4500]
	},
	"chance": {
		"name": "Chance",
		"type": "stat", "max_lvl": 5, "bonus": 0.03,
		"costs": [500, 1500, 2700, 4800, 7200]
	},
	"crit_chance": {
		"name": "Chance de Critique",
		"type": "stat", "max_lvl": 5, "bonus": 0.01,
		"costs": [400, 900, 1800, 3000, 5000]
	},
	"crit_damage": {
		"name": "Dégâts de Critique",
		"type": "stat", "max_lvl": 5, "bonus": 0.02,
		"costs": [1000, 2000, 3500, 6000, 10000]
	},
	"knockback": {
		"name": "Recul",
		"type": "stat", "max_lvl": 5, "bonus": 0.02,
		"costs": [600, 1300, 2300, 3800, 5600]
	},
}

# Fonction pour récupérer le bonus total (ex: +15% dégâts si niv 5)
func get_shop_bonus_value(upgrade_id: String) -> float:
	var level = shop_unlocks.get(upgrade_id, 0)
	var data = shop_definitions.get(upgrade_id)
	if data:
		return level * data["bonus"]
	return 0.0

# --- WEAPON DATABASE ---
# Format:
# "id": {
#    "name": "Display Name",
#    "type": "weapon_type" (Type A: Proj, Type B: Area, Type C: Summon),
#    "stats": { Level: {Stats} }
# }
# Stats keys: damage, cooldown (s), area (scale multiplier), speed (projectile), 
#             duration (s), amount (count), knockback, pierce.

var current_accessories = {}

var accessory_data = {
	"frequency_coil": {
		"name": "Bobine de fréquence",
		"icon": preload("res://Assets/Icon/FrequencyCoilIcon.png"),
		"description": "Intervalle de ticks -10%/niv",
		"type": "stat_modifier",
		"stat_target": "tick_interval",
		"value": -0.10, # -10%
		"method": "multiply_reduction", # On réduit une valeur (0.9, 0.8...)
		"max_level": 10
	},
	"wave_diffuser": {
		"name": "Diffuseur d'ondes",
		"icon": preload("res://Assets/Icon/WaveDiffuserIcon.png"),
		"description": "Zone d'effet +10%/niv",
		"type": "stat_modifier",
		"stat_target": "area",
		"value": 0.10,
		"method": "multiply_additive", # Base * (1 + (0.10 * level))
		"max_level": 10
	},
	"whetstone": {
		"name": "Pierre à aiguiser",
		"icon": preload("res://Assets/Icon/WhetstoneIcon.png"),
		"description": "Vitesse d'attaque +5%/niv (Réduit Cooldown)",
		"type": "stat_modifier",
		"stat_target": "cooldown",
		"value": -0.05, 
		"method": "multiply_reduction", # Cooldown * (1 - 0.05 * level)
		"max_level": 10
	},
	"judgment_lens": {
		"name": "Lentille du jugement",
		"icon": preload("res://Assets/Icon/JudgmentLensIcon.png"),
		"description": "Chance critique +1%/niv",
		"type": "stat_modifier",
		"stat_target": "crit_chance",
		"value": 0.01, # +1% brut
		"method": "add", # Base + (0.01 * level)
		"max_level": 10
	},
	"corrupt_ichor": {
		"name": "Ichor corrompu",
		"icon": preload("res://Assets/Icon/CorruptedIchorIcon.png"),
		"description": "Vol de vie +0.2%/niv",
		"type": "stat_modifier",
		"stat_target": "lifesteal",
		"value": 0.002, 
		"method": "add",
		"max_level": 10
	},
	"war_paint": {
		"name": "Peinture de guerre",
		"icon": preload("res://Assets/Icon/WarPaintIcon.png"),
		"description": "Dégâts +5%/niv",
		"type": "stat_modifier",
		"stat_target": "damage",
		"value": 0.05,
		"method": "multiply_additive",
		"max_level": 10
	},
	"acceleration_feather": {
		"name": "Plume d'accélération",
		"icon": preload("res://Assets/Icon/AccelerationFeatherIcon.png"),
		"description": "Vitesse projectiles +10%/niv",
		"type": "stat_modifier",
		"stat_target": "projectile_speed",
		"value": 0.10,
		"method": "multiply_additive",
		"max_level": 10
	},
	"torment_hourglass": {
		"name": "Sablier de tourments",
		"icon": preload("res://Assets/Icon/TormentHourglassIcon.png"),
		"description": "Durée des effets +10%/niv",
		"type": "stat_modifier",
		"stat_target": "duration",
		"value": 0.10,
		"method": "multiply_additive",
		"max_level": 10
	},
	"propagation_roots": {
		"name": "Racines de propagation",
		"icon": preload("res://Assets/Icon/PropagationRootsIcon.png"),
		"description": "Nombre de projectiles +0.3/niv",
		"type": "stat_modifier",
		"stat_target": "amount",
		"value": 0.34,
		"method": "add_floor", # On ajoute 0.3*lvl et on arrondit à l'inférieur
		"max_level": 10
	},
	"tides_amulet": {
		"name": "Amulette des marées",
		"icon": preload("res://Assets/Icon/Tide'sCharmIcon.png"),
		"description": "Knockback +5%/niv",
		"type": "stat_modifier",
		"stat_target": "knockback",
		"value": 0.05,
		"method": "multiply_additive",
		"max_level": 10
	},
	"advanced_stitches_pack": {
		"name": "Kit de Suture Avancee",
		"icon": preload("res://Assets/Icon/AdvancedStitchesPackIcon.png"),
		"description": "Natural regeneration +0.25/niv",
		"type": "stat_modifier",
		"stat_target": "recovery",
		"value": 0.25,
		"method": "add",
		"max_level": 10
	},
	"titan_heart": {
		"name": "Coeur de Titan",
		"icon": preload("res://Assets/Icon/Titan'sHeartIcon.png"),
		"description": "Max health +8%/niv",
		"type": "stat_modifier",
		"stat_target": "health",
		"value": 0.08,
		"method": "multiply_additive",
		"max_level": 10
	},
	"bait": {
		"name": "Appat",
		"icon": preload("res://Assets/Icon/BaitIcon.png"),
		"description": "Luck +5%/niv",
		"type": "stat_modifier",
		"stat_target": "luck",
		"value": 0.05,
		"method": "multiply_additive",
		"max_level": 10
	},
	"chains_of_the_freed": {
		"name": "Chaines du Libere",
		"icon": preload("res://Assets/Icon/ChainsOfTheFreedIcon.png"),
		"description": "Armor Pierce +0.2/niv",
		"type": "stat_modifier",
		"stat_target": "armor_pierce",
		"value": 0.2,
		"method": "additive",
		"max_level": 10
	},
	"quatuor_needle_dial": {
		"name": "Cadran Quatuor-Aiguille",
		"icon": preload("res://Assets/Icon/DialNeedleQuartetIcon.png"),
		"description": "Experience +10%/niv",
		"type": "stat_modifier",
		"stat_target": "experience",
		"value": 0.1,
		"method": "multiply_additive",
		"max_level": 10
	},
	"soul_collector": {
		"name": "Collecteur d'Ames",
		"icon": preload("res://Assets/Icon/SoulCollectorIcon.png"),
		"description": "Attraction Range +10/niv",
		"type": "stat_modifier",
		"stat_target": "pickup_range",
		"value": 10,
		"method": "add",
		"max_level": 10
	},
	"war_banner": {
		"name": "Banniere de Combat",
		"icon": preload("res://Assets/Icon/WarBannerIcon.png"),
		"description": "Enemy amount +10%/niv",
		"type": "stat_modifier",
		"stat_target": "enemy_amount",
		"value": 0.1,
		"method": "multiply_additive",
		"max_level": 10
	},
	"inferlink": {
		"name": "Inferlien",
		"icon": preload("res://Assets/Icon/InferlinkIcon.png"),
		"description": "Armor +0.5/niv",
		"type": "stat_modifier",
		"stat_target": "armor",
		"value": 0.5,
		"method": "add",
		"max_level": 10
	},
	"jawed_chest": {
		"name": "Coffret Dentele",
		"icon": preload("res://Assets/Icon/JawedChestIcon.png"),
		"description": "Gold +10%/niv",
		"type": "stat_modifier",
		"stat_target": "gold",
		"value": 0.1,
		"method": "multiply_additive",
		"max_level": 10
	}
	# Les autres accessoires (PV, XP, Or) seront gérés dans Player.gd plus tard
}

var weapon_data = {
	# 1. TOR-OB1: Projecteur (Type B - Area/Tick)
	"projector": {
		"name": "Projecteur",
		"type": "area",
		"scene_path": "res://Scenes/Weapons/Base/WeaponProjector.tscn",
		"stats": {
			1: {"damage": 5, "cooldown": null, "tick_interval": 0.5, "area": 1.0, "range": null, "duration": 9999, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			2: {"damage": 5, "cooldown": null, "tick_interval": 0.5, "area": 1.2, "range": null, "duration": 9999, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			3: {"damage": 6, "cooldown": null, "tick_interval": 0.5, "area": 1.2, "range": null, "duration": 9999, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			4: {"damage": 6, "cooldown": null, "tick_interval": 0.5, "area": 1.2, "range": null, "duration": 9999, "knockback": 1, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			5: {"damage": 6, "cooldown": null, "tick_interval": 0.45, "area": 1.2, "range": null, "duration": 9999, "knockback": 2.5, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			6: {"damage": 6, "cooldown": null, "tick_interval": 0.45, "area": 1.4, "range": null, "duration": 9999, "knockback": 2.5, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			7: {"damage": 7, "cooldown": null, "tick_interval": 0.45, "area": 1.4, "range": null, "duration": 9999, "knockback": 2.5, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			8: {"damage": 7, "cooldown": null, "tick_interval": 0.45, "area": 1.4, "range": null, "duration": 9999, "knockback": 2.5, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			9: {"damage": 7, "cooldown": null, "tick_interval": 0.45, "area": 1.6, "range": null, "duration": 9999, "knockback": 2.5, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
			10: {"damage": 7, "cooldown": null, "tick_interval": 0.4, "area": 2.0, "range": null, "duration": 9999, "knockback": 2.5, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": null, "pierce": null},
		}
	},
	
	# 2. KAT: Avant-bras à air comprimé (Type C - Unique/Directional)
	"compressed_air_tank": {
		"name": "Avant-bras à air",
		"type": "directional",
		"scene_path": "res://Scenes/Weapons/Base/WeaponCompressedAir.tscn",
		"stats": {
			1: {"damage": 30, "cooldown": 2.5, "tick_interval": 0.5, "area": 1.0, "range": null, "duration": 0.6, "knockback": 70, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			2: {"damage": 30, "cooldown": 2.5, "tick_interval": 0.5, "area": 1.2, "range": null, "duration": 0.6, "knockback": 70, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			3: {"damage": 36, "cooldown": 2.5, "tick_interval": 0.5, "area": 1.2, "range": null, "duration": 0.6, "knockback": 70, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			4: {"damage": 36, "cooldown": 2.5, "tick_interval": 0.5, "area": 1.2, "range": null, "duration": 0.6, "knockback": 84, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			5: {"damage": 36, "cooldown": 2.5, "tick_interval": 0.5, "area": 1.4, "range": null, "duration": 0.6, "knockback": 84, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			6: {"damage": 42, "cooldown": 2.5, "tick_interval": 0.5, "area": 1.4, "range": null, "duration": 0.6, "knockback": 84, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			7: {"damage": 42, "cooldown": 2.5, "tick_interval": 0.5, "area": 1.6, "range": null, "duration": 0.6, "knockback": 84, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			8: {"damage": 42, "cooldown": 2.25, "tick_interval": 0.5, "area": 1.6, "range": null, "duration": 0.6, "knockback": 84, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			9: {"damage": 42, "cooldown": 2.25, "tick_interval": 0.5, "area": 1.6, "range": null, "duration": 0.6, "knockback": 98, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			10: {"damage": 42, "cooldown": 2.25, "tick_interval": 0.5, "area": 2.0, "range": null, "duration": 0.6, "knockback": 133, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
		}
	},

	# 3. ZZOKRUGUG: Lames Silex (Type B - Melee/Sweep)
	"flint_blades": {
		"name": "Lames Silex",
		"type": "melee",
		"scene_path": "res://Scenes/Weapons/Base/WeaponFlintBlades.tscn",
		"stats": {
			1: {"damage": 15, "cooldown": 2.0, "tick_interval": null, "area": 1.0, "range": 1.0, "duration": 0.3, "knockback": 25, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			2: {"damage": 15, "cooldown": 1.8, "tick_interval": null, "area": 1.0, "range": 1.0, "duration": 0.3, "knockback": 25, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			3: {"damage": 18, "cooldown": 1.8, "tick_interval": null, "area": 1.0, "range": 1.0, "duration": 0.3, "knockback": 25, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			4: {"damage": 18, "cooldown": 1.8, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 25, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			5: {"damage": 18, "cooldown": 1.8, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 31.25, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			6: {"damage": 18, "cooldown": 1.6, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 31.25, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			7: {"damage": 18, "cooldown": 1.6, "tick_interval": null, "area": 1.0, "range": 1.30, "duration": 0.3, "knockback": 31.25, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			8: {"damage": 21, "cooldown": 1.6, "tick_interval": null, "area": 1.0, "range": 1.30, "duration": 0.3, "knockback": 31.25, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			9: {"damage": 21, "cooldown": 1.4, "tick_interval": null, "area": 1.0, "range": 1.30, "duration": 0.3, "knockback": 31.25, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			10: {"damage": 21, "cooldown": 1.0, "tick_interval": null, "area": 1.0, "range": 1.30, "duration": 0.3, "knockback": 31.25, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
		}
	},

	# 4. IRVIKKTITI: Missiles Purificateurs (Type A - Projectile)
	"purifying_missiles": {
		"name": "Missiles Purificateurs",
		"type": "projectile",
		"scene_path": "res://Scenes/Weapons/Base/WeaponPurifyingMissiles.tscn",
		"stats": {
			1: {"damage": 8, "cooldown": 3.0, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 400.0, "amount": 3, "pierce": 0},
			2: {"damage": 10, "cooldown": 3.0, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 400.0, "amount": 3, "pierce": 0},
			3: {"damage": 10, "cooldown": 3.0, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 480.0, "amount": 3, "pierce": 0},
			4: {"damage": 10, "cooldown": 3.0, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 480.0, "amount": 4, "pierce": 0},
			5: {"damage": 10, "cooldown": 2.7, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 480.0, "amount": 4, "pierce": 1},
			6: {"damage": 12, "cooldown": 2.7, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 480.0, "amount": 4, "pierce": 1},
			7: {"damage": 12, "cooldown": 2.7, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 480.0, "amount": 5, "pierce": 1},
			8: {"damage": 12, "cooldown": 2.7, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 560.0, "amount": 5, "pierce": 1},
			9: {"damage": 14, "cooldown": 2.7, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 560.0, "amount": 5, "pierce": 1},
			10: {"damage": 18, "cooldown": 1.65, "tick_interval": 0.25, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 560.0, "amount": 5, "pierce": 1},
		}
	},

	# 5. KHORMOL: Mâchoires Démoniaques (Type B - Melee/Cone)
	"demonic_jaws": {
		"name": "Mâchoires Démoniaques",
		"type": "melee",
		"scene_path": "res://Scenes/Weapons/Base/WeaponDemonJaws.tscn",
		"stats": {
			1: {"damage": 20, "cooldown": 2.5, "tick_interval": null, "area": 1.0, "range": 250, "duration": 1.0, "knockback": 35, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0, "projectile_speed": null, "amount": 1, "pierce": null},
			2: {"damage": 20, "cooldown": 2.25, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 35, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0, "projectile_speed": null, "amount": 1, "pierce": null},
			3: {"damage": 20, "cooldown": 2.25, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 35, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0, "projectile_speed": null, "amount": 1, "pierce": null},
			4: {"damage": 24, "cooldown": 2.25, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 35, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0, "projectile_speed": null, "amount": 1, "pierce": null},
			5: {"damage": 24, "cooldown": 2.25, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 40, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0.01, "projectile_speed": null, "amount": 1, "pierce": null},
			6: {"damage": 24, "cooldown": 2.0, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 40, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0.01, "projectile_speed": null, "amount": 1, "pierce": null},
			7: {"damage": 28, "cooldown": 2.0, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 40, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0.01, "projectile_speed": null, "amount": 1, "pierce": null},
			8: {"damage": 28, "cooldown": 2.0, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 45, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0.01, "projectile_speed": null, "amount": 1, "pierce": null},
			9: {"damage": 28, "cooldown": 1.75, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 45, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0.01, "projectile_speed": null, "amount": 1, "pierce": null},
			10: {"damage": 34, "cooldown": 1.75, "tick_interval": null, "area": 1.2, "range": 250, "duration": 1.0, "knockback": 45, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": 0.02, "projectile_speed": null, "amount": 1, "pierce": null},
		}
	},
	
	# 6. SHAQUR: Haches Tournoyantes (Type B - Orbital)
	# Axes will do one full rotation before disapearing. Duration is here to handle time axes will stay before vanishing.
	"whirling_axes": {
		"name": "Haches Tournoyantes",
		"type": "orbital",
		"scene_path": "res://Scenes/Weapons/Base/WeaponWhirlingAxes.tscn",
		"stats": {
			1: {"damage": 10, "cooldown": 5.0, "tick_interval": null, "area": 1.0, "range": null, "duration": 1.5, "knockback": 40, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			2: {"damage": 10, "cooldown": 5.0, "tick_interval": null, "area": 1.2, "range": null, "duration": 1.5, "knockback": 40, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			3: {"damage": 12, "cooldown": 5.0, "tick_interval": null, "area": 1.2, "range": null, "duration": 1.5, "knockback": 40, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			4: {"damage": 12, "cooldown": 5.0, "tick_interval": null, "area": 1.2, "range": null, "duration": 1.5, "knockback": 48, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			5: {"damage": 14, "cooldown": 5.0, "tick_interval": null, "area": 1.2, "range": null, "duration": 3.0, "knockback": 48, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			6: {"damage": 14, "cooldown": 5.0, "tick_interval": null, "area": 1.4, "range": null, "duration": 3.0, "knockback": 48, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			7: {"damage": 16, "cooldown": 5.0, "tick_interval": null, "area": 1.4, "range": null, "duration": 3.0, "knockback": 48, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			8: {"damage": 16, "cooldown": 5.0, "tick_interval": null, "area": 1.4, "range": null, "duration": 3.0, "knockback": 56, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			9: {"damage": 16, "cooldown": 5.0, "tick_interval": null, "area": 1.6, "range": null, "duration": 3.0, "knockback": 56, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
			10: {"damage": 16, "cooldown": 5.0, "tick_interval": null, "area": 1.9, "range": null, "duration": 4.5, "knockback": 56, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": null, "amount": 2, "pierce": null},
		}
	},

	# 7. PERMA: Dague Traceuse (Type A - Projectile/Bounce)
	"tracer_dagger": {
		"name": "Dague Traceuse",
		"type": "projectile",
		"scene_path": "res://Scenes/Weapons/Base/WeaponTracerDagger.tscn",
		"stats": {
			1: {"damage": 12, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 10, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 300.0, "amount": 1, "pierce": 0, "rebound": 1},
			2: {"damage": 12, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 350.0, "amount": 1, "pierce": 0, "rebound": 1},
			3: {"damage": 12, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 350.0, "amount": 1, "pierce": 0, "rebound": 1},
			4: {"damage": 12, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 350.0, "amount": 1, "pierce": 0, "rebound": 2},
			5: {"damage": 12, "cooldown": 1.35, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.1, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 350.0, "amount": 1, "pierce": 0, "rebound": 2},
			6: {"damage": 12, "cooldown": 1.35, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.2, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 350.0, "amount": 1, "pierce": 0, "rebound": 2},
			7: {"damage": 12, "cooldown": 1.35, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.2, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 350.0, "amount": 1, "pierce": 0, "rebound": 3},
			8: {"damage": 12, "cooldown": 1.35, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.2, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 400.0, "amount": 1, "pierce": 0, "rebound": 3},
			9: {"damage": 12, "cooldown": 1.35, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.3, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 400.0, "amount": 1, "pierce": 0, "rebound": 3},
			10: {"damage": 12, "cooldown": 1.35, "tick_interval": null, "area": 1.0, "range": 600.0, "duration": 5.0, "knockback": 15, "crit_chance": 0.3, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 500.0, "amount": 1, "pierce": 0, "rebound": 4},
		}
	},

	# 8. VIGO: Nanobots Sanguins (Type B - AoE/DoT)
	"sanguine_nanobots": {
		"name": "Nanobots Sanguins",
		"type": "area",
		"scene_path": "res://Scenes/Weapons/Base/WeaponSanguineNanobots.tscn",
		"stats": {
			1: {"damage": 10, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.0, "range": 150.0, "duration": 4.0, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": null},
			2: {"damage": 10, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.2, "range": 150.0, "duration": 4.0, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": null},
			3: {"damage": 12, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.2, "range": 150.0, "duration": 4.0, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": null},
			4: {"damage": 12, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.2, "range": 150.0, "duration": 4.8, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": null},
			5: {"damage": 12, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.2, "range": 150.0, "duration": 5.6, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": null},
			6: {"damage": 12, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.4, "range": 150.0, "duration": 5.6, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": null},
			7: {"damage": 12, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.4, "range": 150.0, "duration": 5.6, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 2, "pierce": null},
			8: {"damage": 12, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.4, "range": 150.0, "duration": 6.4, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 2, "pierce": null},
			9: {"damage": 14, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.4, "range": 150.0, "duration": 6.4, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 2, "pierce": null},
			10: {"damage": 14, "cooldown": 9.0, "tick_interval": 0.5, "area": 1.7, "range": 150.0, "duration": 8.0, "knockback": 3, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 2, "pierce": null},
		}
	},

	# 9. FRAM: Pentagramme Infernal (Type B - AoE/Timed)
	# Duration stands for the burn effect length, while cooldown is for the set up of the burn (summoning the pentagramm)
	"infernal_pentagram": {
		"name": "Pentagramme Infernal",
		"type": "area_timed",
		"scene_path": "res://Scenes/Weapons/Base/WeaponInfernalPentagram.tscn",
		"stats": {
			1: {"damage": 12, "cooldown": 10.0, "tick_interval": 0.75, "area": 1.0, "range": null, "duration": 1.5, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			2: {"damage": 12, "cooldown": 10.0, "tick_interval": 0.75, "area": 1.2, "range": null, "duration": 1.5, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			3: {"damage": 14, "cooldown": 10.0, "tick_interval": 0.75, "area": 1.2, "range": null, "duration": 1.5, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			4: {"damage": 14, "cooldown": 10.0, "tick_interval": 0.75, "area": 1.2, "range": null, "duration": 1.8, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			5: {"damage": 15, "cooldown": 10.0, "tick_interval": 0.67, "area": 1.2, "range": null, "duration": 1.8, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			6: {"damage": 15, "cooldown": 10.0, "tick_interval": 0.67, "area": 1.4, "range": null, "duration": 1.8, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			7: {"damage": 17, "cooldown": 10.0, "tick_interval": 0.67, "area": 1.4, "range": null, "duration": 1.8, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			8: {"damage": 17, "cooldown": 8.5, "tick_interval": 0.67, "area": 1.4, "range": null, "duration": 1.8, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			9: {"damage": 17, "cooldown": 8.5, "tick_interval": 0.67, "area": 1.6, "range": null, "duration": 1.8, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			10: {"damage": 20, "cooldown": 8.5, "tick_interval": 0.67, "area": 1.6, "range": null, "duration": 2.25, "knockback": 0, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
		}
	},

	# 10. NAERUM: Mines-Piques
	"spike_mine": {
		"name": "Mines-Piques",
		"type": "mine",
		"scene_path": "res://Scenes/Weapons/Base/WeaponSpikeMine.tscn",
		"stats": {
			1: {"damage": 20, "cooldown": 4.0, "tick_interval": null, "area": 1.0, "range": null, "duration": 1.0, "knockback": 45, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 5, "pierce": 0},
			2: {"damage": 20, "cooldown": 3.6, "tick_interval": null, "area": 1.0, "range": null, "duration": 1.0, "knockback": 45, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 5, "pierce": 0},
			3: {"damage": 20, "cooldown": 3.6, "tick_interval": null, "area": 1.0, "range": null, "duration": 1.0, "knockback": 45, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 5, "pierce": 0},
			4: {"damage": 20, "cooldown": 3.6, "tick_interval": null, "area": 1.25, "range": null, "duration": 1.0, "knockback": 45, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 5, "pierce": 0},
			5: {"damage": 20, "cooldown": 3.2, "tick_interval": null, "area": 1.25, "range": null, "duration": 1.0, "knockback": 52, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 5, "pierce": 0},
			6: {"damage": 20, "cooldown": 3.2, "tick_interval": null, "area": 1.25, "range": null, "duration": 1.0, "knockback": 52, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 5, "pierce": 1},
			7: {"damage": 20, "cooldown": 3.2, "tick_interval": null, "area": 1.5, "range": null, "duration": 1.0, "knockback": 52, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 5, "pierce": 1},
			8: {"damage": 20, "cooldown": 3.2, "tick_interval": null, "area": 1.5, "range": null, "duration": 1.0, "knockback": 52, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.4, "amount": 5, "pierce": 1},
			9: {"damage": 20, "cooldown": 3.2, "tick_interval": null, "area": 1.5, "range": null, "duration": 1.0, "knockback": 52, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.4, "amount": 5, "pierce": 2},
			10: {"damage": 20, "cooldown": 2.0, "tick_interval": null, "area": 1.5, "range": null, "duration": 1.0, "knockback": 52, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.4, "amount": 6, "pierce": 2},
		}
	},

	# 11. SULPHURA: Feu Originel
	"first_flame": {
		"name": "Feu Originel",
		"type": "projectile",
		"scene_path": "res://Scenes/Weapons/Base/WeaponFirstFlame.tscn",
		"stats": {
			1: {"damage": 18, "cooldown": 5.0, "tick_interval": null, "area": 1.0, "range": null, "duration": 5.0, "knockback": 30, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			2: {"damage": 18, "cooldown": 5.0, "tick_interval": null, "area": 1.0, "range": null, "duration": 5.0, "knockback": 30, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			3: {"damage": 18, "cooldown": 5.0, "tick_interval": null, "area": 1.15, "range": null, "duration": 5.0, "knockback": 30, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			4: {"damage": 18, "cooldown": 5.0, "tick_interval": null, "area": 1.15, "range": null, "duration": 5.0, "knockback": 36, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			5: {"damage": 18, "cooldown": 4.5, "tick_interval": null, "area": 1.15, "range": null, "duration": 5.0, "knockback": 36, "crit_chance": 0.1, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			6: {"damage": 18, "cooldown": 4.5, "tick_interval": null, "area": 1.15, "range": null, "duration": 5.0, "knockback": 36, "crit_chance": 0.2, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			7: {"damage": 18, "cooldown": 4.5, "tick_interval": null, "area": 1.15, "range": null, "duration": 5.0, "knockback": 42, "crit_chance": 0.2, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			8: {"damage": 18, "cooldown": 4.5, "tick_interval": null, "area": 1.3, "range": null, "duration": 5.0, "knockback": 42, "crit_chance": 0.2, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			9: {"damage": 18, "cooldown": 4.5, "tick_interval": null, "area": 1.3, "range": null, "duration": 5.0, "knockback": 42, "crit_chance": 0.3, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
			10: {"damage": 18, "cooldown": 4.5, "tick_interval": null, "area": 1.6, "range": null, "duration": 5.0, "knockback": 51, "crit_chance": 0.3, "crit_damage": 1.54, "lifesteal": null, "projectile_speed": 300.0, "amount": 2, "pierce": 0},
		}
	},

	# 12. SSEROGHOL: Vague en Bouteille
	"wave_in_a_bottle": {
		"name": "Vague en Bouteille",
		"type": "projectile",
		"scene_path": "res://Scenes/Weapons/Base/WeaponWaveInABottle.tscn",
		"stats": {
			1: {"damage": 15, "cooldown": 3.0, "tick_interval": null, "area": 1.0, "range": 1.0, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			2: {"damage": 15, "cooldown": 3.0, "tick_interval": null, "area": 1.2, "range": 1.0, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			3: {"damage": 18, "cooldown": 3.0, "tick_interval": null, "area": 1.2, "range": 1.0, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			4: {"damage": 18, "cooldown": 3.0, "tick_interval": null, "area": 1.2, "range": 1.1, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			5: {"damage": 18, "cooldown": 3.0, "tick_interval": null, "area": 1.2, "range": 1.35, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			6: {"damage": 18, "cooldown": 3.0, "tick_interval": null, "area": 1.4, "range": 1.35, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			7: {"damage": 21, "cooldown": 3.0, "tick_interval": null, "area": 1.4, "range": 1.35, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			8: {"damage": 21, "cooldown": 3.0, "tick_interval": null, "area": 1.4, "range": 1.5, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			9: {"damage": 21, "cooldown": 3.0, "tick_interval": null, "area": 1.6, "range": 1.5, "duration": 0.75, "knockback": 370, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			10: {"damage": 21, "cooldown": 3.0, "tick_interval": null, "area": 1.6, "range": 1.5, "duration": 0.75, "knockback": 481, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
		}
	},

	# 13. HOJO: Canne à Pêche
	"fishing_rod": {
		"name": "Canne à Pêche",
		"type": "melee",
		"scene_path": "res://Scenes/Weapons/Base/WeaponFishingRod.tscn",
		"stats": {
			1: {"damage": 14, "cooldown": 2.0, "tick_interval": null, "area": 1.0, "range": 1.0, "duration": 0.3, "knockback": 50, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			2: {"damage": 17, "cooldown": 2.0, "tick_interval": null, "area": 1.0, "range": 1.0, "duration": 0.3, "knockback": 50, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			3: {"damage": 17, "cooldown": 2.0, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 50, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			4: {"damage": 17, "cooldown": 2.0, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 50, "crit_chance": 0, "crit_damage": 1.61, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			5: {"damage": 17, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 50, "crit_chance": 0.25, "crit_damage": 1.61, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			6: {"damage": 20, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 50, "crit_chance": 0.25, "crit_damage": 1.61, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			7: {"damage": 20, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 1.15, "duration": 0.3, "knockback": 50, "crit_chance": 0.25, "crit_damage": 1.82, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			8: {"damage": 20, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 1.3, "duration": 0.3, "knockback": 50, "crit_chance": 0.25, "crit_damage": 1.82, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			9: {"damage": 23, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 1.3, "duration": 0.3, "knockback": 50, "crit_chance": 0.25, "crit_damage": 1.82, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
			10: {"damage": 27, "cooldown": 1.5, "tick_interval": null, "area": 1.0, "range": 1.3, "duration": 0.3, "knockback": 50, "crit_chance": 0.5, "crit_damage": 1.82, "lifesteal": null, "projectile_speed": 1.0, "amount": 2, "pierce": null},
		}
	},

	# 14. GUHULGGHURU: Impact Cristallin
	"crystalline_impact": {
		"name": "Impact Cristallin",
		"type": "projectile",
		"scene_path": "res://Scenes/Weapons/Base/WeaponCrystallineImpact.tscn",
		"stats": {
			1: {"rift_damage": 10, "explo_damage": 15, "cooldown": 3.5, "tick_interval": null, "area": 1.0, "range": 100.0, "duration": 1.0, "rift_knockback": 20, "explo_knockback": 60, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			2: {"rift_damage": 10, "explo_damage": 15, "cooldown": 3.15, "tick_interval": null, "area": 1.0, "range": 100.0, "duration": 1.0, "rift_knockback": 20, "explo_knockback": 60, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			3: {"rift_damage": 12, "explo_damage": 18, "cooldown": 3.15, "tick_interval": null, "area": 1.0, "range": 100.0, "duration": 1.0, "rift_knockback": 20, "explo_knockback": 60, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			4: {"rift_damage": 12, "explo_damage": 18, "cooldown": 3.15, "tick_interval": null, "area": 1.0, "range": 100.0, "duration": 1.0, "rift_knockback": 24, "explo_knockback": 72, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			5: {"rift_damage": 12, "explo_damage": 18, "cooldown": 2.8, "tick_interval": null, "area": 1.2, "range": 100.0, "duration": 1.0, "rift_knockback": 24, "explo_knockback": 72, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			6: {"rift_damage": 12, "explo_damage": 18, "cooldown": 2.45, "tick_interval": null, "area": 1.2, "range": 100.0, "duration": 1.0, "rift_knockback": 24, "explo_knockback": 72, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			7: {"rift_damage": 14, "explo_damage": 21, "cooldown": 2.45, "tick_interval": null, "area": 1.2, "range": 100.0, "duration": 1.0, "rift_knockback": 24, "explo_knockback": 72, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			8: {"rift_damage": 14, "explo_damage": 21, "cooldown": 2.45, "tick_interval": null, "area": 1.4, "range": 100.0, "duration": 1.0, "rift_knockback": 24, "explo_knockback": 72, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			9: {"rift_damage": 14, "explo_damage": 21, "cooldown": 2.45, "tick_interval": null, "area": 1.4, "range": 100.0, "duration": 1.0, "rift_knockback": 28, "explo_knockback": 84, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
			10: {"rift_damage": 17, "explo_damage": 25, "cooldown": 1.7, "tick_interval": null, "area": 1.4, "range": 100.0, "duration": 1.0, "rift_knockback": 28, "explo_knockback": 84, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": null},
		}
	},

	# 15. KROFHON: Sceptre de Déphasage
	# For this weapon, pierce serves as an indicator for the times a projectile is redirected after hitting an enemy
	"phase_shift_scepter": {
		"name": "Sceptre de Déphasage",
		"type": "projectile",
		"scene_path": "res://Scenes/Weapons/Base/WeaponPhaseShiftScepter.tscn",
		"stats": {
			1: {"damage": 10, "cooldown": 3.0, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 500.0, "amount": 1, "pierce": 3},
			2: {"damage": 12, "cooldown": 3.0, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 500.0, "amount": 1, "pierce": 3},
			3: {"damage": 12, "cooldown": 3.0, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": 3},
			4: {"damage": 12, "cooldown": 2.7, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 600.0, "amount": 1, "pierce": 3},
			5: {"damage": 12, "cooldown": 2.7, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 700.0, "amount": 1, "pierce": 4},
			6: {"damage": 14, "cooldown": 2.7, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 700.0, "amount": 1, "pierce": 4},
			7: {"damage": 14, "cooldown": 2.7, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 700.0, "amount": 1, "pierce": 4},
			8: {"damage": 14, "cooldown": 2.4, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 700.0, "amount": 1, "pierce": 4},
			9: {"damage": 16, "cooldown": 2.4, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 700.0, "amount": 1, "pierce": 4},
			10: {"damage": 16, "cooldown": 2.4, "tick_interval": null, "area": 1.0, "range": 350, "duration": 3.0, "knockback": 12, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 700.0, "amount": 2, "pierce": 5},
		}
	},

	# 16. OMOCQITHEQQ: Faisceau d'Ame
	# Maybe see knockback more as a 'slow' than a knockback because of the high attack speed
	"soul_beam": {
		"name": "Faisceau d'Ame",
		"type": "beam",
		"scene_path": "res://Scenes/Weapons/Base/WeaponSoulBeam.tscn",
		"stats": {
			1: {"damage": 4, "cooldown": null, "tick_interval": 0.25, "area": 1.0, "range": 1.0, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			2: {"damage": 4, "cooldown": null, "tick_interval": 0.25, "area": 1.0, "range": 1.2, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			3: {"damage": 5, "cooldown": null, "tick_interval": 0.25, "area": 1.0, "range": 1.2, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			4: {"damage": 5, "cooldown": null, "tick_interval": 0.25, "area": 1.2, "range": 1.2, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			5: {"damage": 5, "cooldown": null, "tick_interval": 0.23, "area": 1.2, "range": 1.2, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			6: {"damage": 5, "cooldown": null, "tick_interval": 0.23, "area": 1.2, "range": 1.4, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			7: {"damage": 6, "cooldown": null, "tick_interval": 0.23, "area": 1.2, "range": 1.4, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			8: {"damage": 6, "cooldown": null, "tick_interval": 0.23, "area": 1.4, "range": 1.4, "duration": 9999, "knockback": 2, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			9: {"damage": 6, "cooldown": null, "tick_interval": 0.23, "area": 1.4, "range": 1.4, "duration": 9999, "knockback": 2, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
			10: {"damage": 6, "cooldown": null, "tick_interval": 0.20, "area": 1.4, "range": 1.4, "duration": 9999, "knockback": 2, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 0},
		}
	},

	# 17. ALLUCARD: Cor des Opprimés
	# For this weapon, cooldown is the time between 2 summon of soldiers,
	# tick_interval is the attack speed of each soldier, area is the MAX
	# distance from player the soldiers can spawn, range is the attack
	# scale of the soldiers and duration is the time of life of each soldiers.
	"horn_of_the_oppressed": {
		"name": "Cor des Opprimés",
		"type": "summon",
		"scene_path": "res://Scenes/Weapons/Base/WeaponHornOfTheOppressed.tscn",
		"stats": {
			1: {"damage": 10, "cooldown": 15.0, "tick_interval": 2.0, "area": 1.0, "range": 0.5, "duration": 10.0, "knockback": 8, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			2: {"damage": 10, "cooldown": 13.5, "tick_interval": 1.8, "area": 1.0, "range": 0.5, "duration": 10.0, "knockback": 8, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			3: {"damage": 12, "cooldown": 13.5, "tick_interval": 1.8, "area": 1.0, "range": 0.5, "duration": 10.0, "knockback": 8, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			4: {"damage": 12, "cooldown": 13.5, "tick_interval": 1.8, "area": 1.3, "range": 0.5, "duration": 10.0, "knockback": 8, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			5: {"damage": 12, "cooldown": 12.0, "tick_interval": 1.6, "area": 1.3, "range": 0.7, "duration": 10.0, "knockback": 8, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			6: {"damage": 14, "cooldown": 12.0, "tick_interval": 1.6, "area": 1.3, "range": 0.7, "duration": 10.0, "knockback": 8, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			7: {"damage": 14, "cooldown": 12.0, "tick_interval": 1.6, "area": 1.3, "range": 0.7, "duration": 10.0, "knockback": 8, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 4, "pierce": null},
			8: {"damage": 14, "cooldown": 12.0, "tick_interval": 1.6, "area": 1.3, "range": 0.7, "duration": 10.0, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 4, "pierce": null},
			9: {"damage": 14, "cooldown": 10.5, "tick_interval": 1.4, "area": 1.3, "range": 0.7, "duration": 10.0, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 4, "pierce": null},
			10: {"damage": 18, "cooldown": 7.5, "tick_interval": 1.0, "area": 1.3, "range": 0.7, "duration": 10.0, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 4, "pierce": null},
		}
	},

	# 18. LIV, FICU & ADUJ: Trisceau
	# The 3 beams aren't global. They have a max range. Range stands for their range and area stands for the thickness of each beam.
	"triseal": {
		"name": "Trisceau",
		"type": "beam",
		"scene_path": "res://Scenes/Weapons/Base/WeaponTriseal.tscn",
		"stats": {
			1: {"damage": 7, "cooldown": 5.5, "tick_interval": 0.75, "area": 1.0, "range": 1.0, "duration": 1.5, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			2: {"damage": 7, "cooldown": 5.5, "tick_interval": 0.75, "area": 1.0, "range": 1.2, "duration": 1.5, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			3: {"damage": 9, "cooldown": 5.5, "tick_interval": 0.75, "area": 1.0, "range": 1.2, "duration": 1.5, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			4: {"damage": 9, "cooldown": 5.5, "tick_interval": 0.75, "area": 1.0, "range": 1.2, "duration": 1.875, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			5: {"damage": 9, "cooldown": 4.95, "tick_interval": 0.67, "area": 1.0, "range": 1.2, "duration": 1.875, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			6: {"damage": 9, "cooldown": 4.95, "tick_interval": 0.67, "area": 1.0, "range": 1.4, "duration": 1.875, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			7: {"damage": 11, "cooldown": 4.95, "tick_interval": 0.67, "area": 1.0, "range": 1.4, "duration": 1.875, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			8: {"damage": 11, "cooldown": 4.95, "tick_interval": 0.67, "area": 1.0, "range": 1.4, "duration": 2.25, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			9: {"damage": 11, "cooldown": 4.95, "tick_interval": 0.67, "area": 1.0, "range": 1.6, "duration": 2.25, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
			10: {"damage": 11, "cooldown": 4.95, "tick_interval": 0.67, "area": 1.0, "range": 1.6, "duration": 3.0, "knockback": 10, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 3, "pierce": null},
		}
	},

	# 19. GNARLHOM: Pochette Crache-Pièce
	"coin_spitting_pouch": {
		"name": "Pochette Crache-Pièce",
		"type": "projectile",
		"scene_path": "res://Scenes/Weapons/Base/WeaponCoinSpittingPouch.tscn",
		"stats": {
			1: {"damage": 4, "cooldown": 0.5, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 1},
			2: {"damage": 4, "cooldown": 0.425, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.0, "amount": 1, "pierce": 1},
			3: {"damage": 4, "cooldown": 0.425, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 1, "pierce": 1},
			4: {"damage": 4, "cooldown": 0.425, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 2, "pierce": 1},
			5: {"damage": 4, "cooldown": 0.35, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 2, "pierce": 1},
			6: {"damage": 4, "cooldown": 0.35, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 2, "pierce": 2},
			7: {"damage": 4, "cooldown": 0.35, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.2, "amount": 3, "pierce": 2},
			8: {"damage": 4, "cooldown": 0.35, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.4, "amount": 3, "pierce": 2},
			9: {"damage": 4, "cooldown": 0.275, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.4, "amount": 3, "pierce": 2},
			10: {"damage": 4, "cooldown": 0.275, "tick_interval": null, "area": 1.0, "range": null, "duration": 2.0, "knockback": 1, "crit_chance": 0.1, "crit_damage": 1.4, "lifesteal": null, "projectile_speed": 1.75, "amount": 3, "pierce": 4},
		}
	}
}

# --- SYSTEM FUNCTIONS ---

func get_xp_requirement(current_level: int) -> int:
	# Formula: Base + (Growth * L) + (Curve * L^2.2)
	var lvl = float(current_level)
	return int(XP_BASE + (XP_GROWTH * lvl) + (XP_CURVE * pow(lvl, 2.2)))

func get_weapon_stats(weapon_id: String, level: int) -> Dictionary:
	if weapon_data.has(weapon_id):
		if weapon_data[weapon_id]["stats"].has(level):
			return weapon_data[weapon_id]["stats"][level]
	return {} # Return empty if not found

# --- FONCTION MAÎTRESSE DE CALCUL ---
func get_stat_with_bonuses(base_value: float, stat_name: String) -> float:
	var final_value = base_value
	
	# --- 1. APPLIQUER LES BONUS DE LA BOUTIQUE (BASE MODIFIÉE) ---
	# On cherche si une amélioration de boutique correspond à cette stat
	# Il faut parfois mapper les noms (ex: "area" dans l'arme = "area_of_effect" dans la boutique)
	var shop_key = stat_name
	
	# Mapping des noms (Code Arme -> Code Boutique)
	match stat_name:
		"area": shop_key = "area_of_effect"
		"speed": shop_key = "movement_speed" # Pour le joueur
		"projectile_speed": shop_key = "projectile_speed"
		"duration": shop_key = "duration" # Pas de shop item pour ça pour l'instant mais prévu
		"amount": shop_key = "amount" # Pas de shop item pour ça pour l'instant
		"cooldown": shop_key = "attack_speed" # Attention, l'attack speed REDUIT le cooldown
		"max_health": shop_key = "health"
		"armor": shop_key = "armor"
		"recovery": shop_key = "recovery"
		"luck": shop_key = "chance"
		"magnet": shop_key = "pickup_range"
		
	# Si on a un niveau dans cette stat en boutique
	if shop_key in shop_unlocks:
		var level = shop_unlocks[shop_key]
		var bonus_per_lvl = shop_definitions[shop_key]["bonus"]
		
		# Cas Spécial : Cooldown (Attack Speed)
		# Si j'ai +10% attack speed, mon cooldown est divisé par 1.10 (ou multiplié par 0.9, selon ton design)
		if stat_name == "cooldown":
			# Approche classique : Cooldown = Base / (1 + Bonus)
			# Ex: +100% attack speed (2.0) = Cooldown divisé par 2.
			var total_bonus = level * bonus_per_lvl
			final_value /= (1.0 + total_bonus)
			
		# Cas Spécial : Stats "Plates" (Additionnelles)
		elif stat_name in ["armor", "amount", "revival", "reroll", "banish", "skip", "recovery", "pickup_range"]:
			final_value += (level * bonus_per_lvl)
			
		# Cas Général : Multiplicateurs (Dégâts, Santé, Vitesse, Taille)
		else:
			# Ex: Base 100 + (5% * niv 2) = 110
			var multiplier = 1.0 + (level * bonus_per_lvl)
			final_value *= multiplier

	# --- 2. APPLIQUER LES ACCESSOIRES (MODIFICATEURS RUN) ---
	for acc_id in current_accessories:
		var lvl = current_accessories[acc_id]
		var data = accessory_data.get(acc_id)
		
		if data and data.get("stat_target") == stat_name:
			var method = data.get("method")
			var val_per_lvl = data.get("value")
			
			match method:
				"multiply_additive":
					var multiplier = 1.0 + (val_per_lvl * lvl)
					final_value *= multiplier
					
				"multiply_reduction":
					var reduction = min(val_per_lvl * lvl, 0.9) # Cap à -90%
					final_value *= (1.0 - reduction) # Correction mathématique ici (1 - 0.1 = 0.9)
				
				"add":
					final_value += (val_per_lvl * lvl)
					
				"add_floor":
					var bonus = floor(val_per_lvl * lvl)
					final_value += bonus
				
	# --- 3. APPLIQUER LES BONUS DE RUN (BUFF BUFF) ---
	# Mapping des noms (similaire à la boutique)
	var run_key = stat_name
	if stat_name == "movement_speed": run_key = "speed"
	if stat_name == "area_of_effect": run_key = "area"
	if stat_name == "attack_speed": run_key = "cooldown" # Simplification
	
	if run_key in run_stat_bonuses:
		var bonus = run_stat_bonuses[run_key]
		var def = buff_definitions.get(run_key, {"type": "percent"})
		match def["type"]:
			"flat":
				final_value += bonus
			"flat_percent":
				# Pour le crit : 0.05 de base + 0.01 de bonus = 0.06
				final_value += bonus
			"percent":
				# Cas spécial pour cooldown et intervalle : on divise pour réduire le temps
				if run_key in ["cooldown", "tick_interval"]:
					final_value /= (1.0 + bonus)
				else:
					final_value *= (1.0 + bonus)
	return final_value

# Fonction utilitaire pour ajouter un accessoire (debug ou level up)
func add_accessory(id: String):
	if id in current_accessories:
		if current_accessories[id] < accessory_data[id]["max_level"]:
			current_accessories[id] += 1
	else:
		current_accessories[id] = 1
	
	# IMPORTANT : Il faudra dire aux armes de se recharger !
	# On utilisera un Signal global plus tard, ou on attendra le prochain load_stats

# --- FONCTION DE CALCUL DE DROP (Double Roll) ---
func calculate_loot_drop(player_luck_modifier: float, is_boss: bool = false) -> Dictionary:
	if randf() < (0.01 * player_luck_modifier):#change back to 0.01 after tests done
		var buff_id = buffs_table.pick_random()
		return {"id": buff_id, "type": "consumable"}
	# ROLL 1 : Y a-t-il du loot ?
	# Base 3% (0.03). Multiplié par la stat du joueur (ex: 1.5 pour +50% chance).
	var drop_chance = 0.03 * player_luck_modifier
	
	# Les boss droppent toujours (100%)
	if not is_boss and randf() > drop_chance:
		return {} # Rien ne tombe
	
	# ROLL 2 : Quelle rareté ?
	# On tire un chiffre entre 0.0 et 1.0
	var rarity_roll = randf()
	var selected_rarity = ""
	
	# Rare (5%) : Si le roll est > 0.95 (car 1.0 - 0.05 = 0.95)
	if rarity_roll > 0.95:
		selected_rarity = "rare"
	# Peu Commun (25%) : Si le roll est > 0.70 (car 0.95 - 0.25 = 0.70)
	elif rarity_roll > 0.70:
		selected_rarity = "uncommon"
	# Commun (70%) : Le reste
	else:
		selected_rarity = "common"
	
	# On pioche un item au hasard dans la liste de cette rareté
	var possible_items = loot_table.get(selected_rarity, [])
	if possible_items.is_empty():
		return {}
		
	return {"id": possible_items.pick_random(), "type": "material"}

# --- GESTION DE L'INVENTAIRE ---

func add_run_material(item_id: String, amount: int = 1):
	if item_id in run_materials:
		run_materials[item_id] += amount
	else:
		run_materials[item_id] = amount
	loot_collected.emit(item_id, amount)

func finalize_run(retention_ratio: float):
	var actual_ratio = 1.0 if boss_defeated else retention_ratio
	
	for item_id in run_materials:
		var amount = run_materials[item_id]
		
		amount = floor(amount * actual_ratio)
		
		if amount > 0:
			if item_id in material_inventory:
				material_inventory[item_id] += amount
			else:
				material_inventory[item_id] = amount
	
	# On vide le sac temporaire
	run_materials.clear()
	
	# On sauvegarde tout (Or + Matériaux)
	save_bank(0) # Le 0 car l'or est déjà géré ailleurs, on veut juste déclencher l'écriture

func trigger_freeze_enemies(duration: float):
	is_enemies_frozen = true
	
	# On crée un timer temporaire dans l'arbre pour gérer la fin du gel
	var timer = get_tree().create_timer(duration)
	await timer.timeout
	
	is_enemies_frozen = false

func trigger_gold_rush(duration: float):
	is_gold_rush_active = true
	await get_tree().create_timer(duration).timeout
	is_gold_rush_active = false

func apply_random_stat_bonus() -> String:
	var stat_key = buff_definitions.keys().pick_random()
	var def = buff_definitions[stat_key]
	var value = def["value"]
	
	# On ajoute au dictionnaire des bonus de run
	if stat_key in run_stat_bonuses:
		run_stat_bonuses[stat_key] += value
	else:
		run_stat_bonuses[stat_key] = value
	
	# On prévient tout le monde
	run_stats_updated.emit()
	
	return def["display"]
