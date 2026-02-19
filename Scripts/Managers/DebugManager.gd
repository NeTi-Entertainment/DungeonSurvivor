extends Node
class_name DebugManager
# DebugManager.gd - Outils de debug pour tester rapidement
# À RETIRER EN PRODUCTION ou désactiver via une constante

# ============================================================================
# CONFIGURATION
# ============================================================================

const DEBUG_ENABLED: bool = true  # Mettre à false pour désactiver en prod

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var player: CharacterBody2D = null
var game_scene: Node2D = null

# ============================================================================
# ÉTAT
# ============================================================================

var god_mode_active: bool = false
var one_shot_mode_active: bool = false

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_game_scene: Node2D) -> void:
	"""Initialise le DebugManager"""
	if not DEBUG_ENABLED:
		return
	
	player = p_player
	game_scene = p_game_scene
	
	print("\n=== DEBUG MANAGER ACTIVÉ ===")
	print("F1  : Passer à 17:30 (30s avant boss final)")
	print("F2  : Passer à 19:30 (30s après victoire)")
	print("F3  : Toggle God Mode (immortalité)")
	print("F4  : Toggle One-Shot Mode (ennemis meurent en 1 coup)")
	print("F5  : Ralentir le jeu (x0.5)")
	print("F6  : Vitesse normale (x1.0)")
	print("F7  : Accélérer le jeu (x2.0)")
	print("9   : Accélérer le jeu (x5.0)  [CHANGÉ: était F8]")
	print("F9  : Kill tous les ennemis à l'écran")
	print("F10 : Heal joueur au max")
	print("0   : +1 niveau joueur  [CHANGÉ: était F11 avec +10 niveaux]")
	print("F12 : Force victoire immédiate")
	print("============================\n")

func _input(event: InputEvent) -> void:
	"""Gestion des raccourcis clavier de debug"""
	if not DEBUG_ENABLED:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_jump_to_time(1045)  # 17:30 (30s avant boss final)
			KEY_F2:
				_jump_to_time(1230)  # 19:30 (après boss, avant reapers)
			KEY_F3:
				_toggle_god_mode()
			KEY_F4:
				_toggle_one_shot_mode()
			KEY_F5:
				_set_game_speed(0.5)
			KEY_F6:
				_set_game_speed(1.0)
			KEY_F7:
				_set_game_speed(2.0)
			KEY_9:  # Changé de F8 à 9 (F8 = touche système Godot)
				_set_game_speed(5.0)
			KEY_F9:
				_kill_all_enemies()
			KEY_F10:
				_heal_player()
			KEY_0:  # Changé de F11 à 0 (+1 niveau au lieu de +10)
				_add_player_levels(1)
			KEY_F12:
				_force_victory()
			KEY_DELETE:
				_print_full_snapshot()
			KEY_P:
				GameData.total_banked_gold += 10000
				GameData.save_bank(0)

func _print_full_snapshot() -> void:
	"""Snapshot complet : joueur / armes / accessoires / boutique"""
	if not player:
		print("[Debug Snapshot] Aucun joueur référencé.")
		return

	var sep  = "═══════════════════════════════════════════════════════════════"
	var _sep2 = "───────────────────────────────────────────────────────────────"

	print("\n" + sep)
	var time_str = "??:??"
	if GameTimer:
		time_str = GameTimer.get_formatted_time()
	print("📊  SNAPSHOT DEBUG — %s  |  Niv %d  |  HP %d/%d  |  Or %d" % [
		time_str,
		player.level,
		player.current_health,
		player.max_health,
		player.current_gold
	])
	print(sep)

	_print_player_stats()
	_print_weapons()
	_print_accessories()
	_print_shop_state()

	print(sep + "\n")

# ============================================================================
# SNAPSHOT DEBUG COMPLET
# ============================================================================

# Valeurs de base du joueur (indépendantes du personnage choisi — debug only)
const _PLAYER_BASE: Dictionary = {
	"health":               100.0,
	"movement_speed":       300.0,
	"armor":                  0.0,
	"armor_pierce":           0.0,
	"pickup_range":          10.0,
	"recovery":               0.0,
	"luck":                   1.0,
	"gold_gain":              1.0,
	"xp_gain":                1.0,
	"enemy_amount":           1.0,
	"reroll":                 0.0,
	"banish":                 0.0,
	"skip":                   0.0,
}


func _print_player_stats() -> void:
	print("\n🧑  STATS JOUEUR")
	_row_header()

	var stats_to_print = [
		["HP Max",         "health"],
		["Vitesse",        "movement_speed"],
		["Armure",         "armor"],
		["Perce-armure",   "armor_pierce"],
		["Portée aimant",  "pickup_range"],
		["Régén. HP/s",    "recovery"],
		["Luck",           "luck"],
		["Multi Or",       "gold_gain"],
		["Multi XP",       "xp_gain"],
		["Multi Ennemis",  "enemy_amount"],
		["Rerolls",        "reroll"],
		["Banish",         "banish"],
		["Skip",           "skip"],
	]

	for entry in stats_to_print:
		var label   = entry[0]
		var key     = entry[1]
		var base    = _PLAYER_BASE.get(key, 0.0)
		var w_shop  = _apply_shop_only(base, key)
		var w_full  = GameData.get_stat_with_bonuses(base, key)
		_row(label, base, w_shop, w_full)


func _print_weapons() -> void:
	var weapons_holder = player.get_node_or_null("WeaponsHolder")
	if not weapons_holder:
		print("\n⚔️  ARMES — WeaponsHolder introuvable")
		return

	var weapon_nodes = weapons_holder.get_children()
	print("\n⚔️  ARMES (%d/%d)" % [weapon_nodes.size(), player.MAX_WEAPON_SLOTS])

	if weapon_nodes.is_empty():
		print("  (aucune arme équipée)")
		return

	for weapon in weapon_nodes:
		var w_id    = weapon.get("id")
		var w_level = weapon.get("level")

		if w_id == null or w_level == null:
			print("  [?] Arme sans id/level — ignorée")
			continue

		var w_name  = GameData.weapon_data.get(w_id, {}).get("name", w_id)
		var w_type  = GameData.weapon_data.get(w_id, {}).get("type", "?")
		print("\n  [%s]  %s — Niv %d  (type: %s)" % [w_id, w_name, w_level, w_type])
		_row_header()

		var base_stats: Dictionary = GameData.get_weapon_stats(w_id, w_level)
		if base_stats.is_empty():
			print("    (stats introuvables pour ce niveau)")
			continue

		for stat_key in base_stats:
			var base_val = base_stats[stat_key]
			if base_val == null:
				continue  # Stat non applicable à cette arme

			var w_shop = _apply_shop_only(float(base_val), stat_key)
			var w_full = GameData.get_stat_with_bonuses(float(base_val), stat_key)
			_row(stat_key, base_val, w_shop, w_full)


func _print_accessories() -> void:
	print("\n💎  ACCESSOIRES (%d/%d)" % [
		GameData.current_accessories.size(),
		player.MAX_ACCESSORY_SLOTS
	])

	if GameData.current_accessories.is_empty():
		print("  (aucun accessoire)")
		return

	for acc_id in GameData.current_accessories:
		var acc_lvl  = GameData.current_accessories[acc_id]
		var acc_data = GameData.accessory_data.get(acc_id, {})
		var acc_name = acc_data.get("name", acc_id)
		var target   = acc_data.get("stat_target", "?")
		var val      = acc_data.get("value", 0.0)
		var method   = acc_data.get("method", "?")
		var max_lvl  = acc_data.get("max_level", "?")
		print("  [%s]  %s — Niv %d/%s  →  %s %s×%.2f  (méthode: %s)" % [
			acc_id, acc_name, acc_lvl, str(max_lvl), target,
			"+", val, method
		])


func _print_shop_state() -> void:
	print("\n🏪  BOUTIQUE")

	if GameData.shop_unlocks.is_empty():
		print("  (aucun achat)")
		return

	for shop_key in GameData.shop_unlocks:
		var lvl      = GameData.shop_unlocks[shop_key]
		var def      = GameData.shop_definitions.get(shop_key, {})
		var name_fr  = def.get("name", shop_key)
		var bonus    = def.get("bonus", 0.0)
		var max_lvl  = def.get("max_lvl", "?")
		var total    = lvl * bonus
		print("  %-28s  Niv %d/%s  (bonus/niv: %.4f | total: +%.4f)" % [
			name_fr, lvl, str(max_lvl), bonus, total
		])


# ─── HELPERS SNAPSHOT ────────────────────────────────────────────────────────

func _apply_shop_only(base: float, stat_name: String) -> float:
	"""Réplique uniquement la couche boutique de get_stat_with_bonuses.
	Utilisé pour isoler l'impact boutique sans les accessoires."""
	var final_value = base

	var shop_key = stat_name
	match stat_name:
		"area":             shop_key = "area_of_effect"
		"speed":            shop_key = "movement_speed"
		"projectile_speed": shop_key = "projectile_speed"
		"cooldown":         shop_key = "attack_speed"
		"tick_interval":    shop_key = "attack_speed"  # même réduction
		"max_health":       shop_key = "health"
		"armor":            shop_key = "armor"
		"recovery":         shop_key = "recovery"
		"luck":             shop_key = "chance"
		"pickup_range":     shop_key = "pickup_range"
		"gold_gain":        shop_key = "gold_gain"
		"xp_gain":          shop_key = "xp_gain"
		"damage":           shop_key = "damage"
		"crit_chance":      shop_key = "crit_chance"
		"crit_damage":      shop_key = "crit_damage"
		"knockback":        shop_key = "knockback"

	if not GameData.shop_definitions.has(shop_key):
		return final_value
	if not GameData.shop_unlocks.has(shop_key):
		return final_value

	var lvl          = GameData.shop_unlocks[shop_key]
	var bonus_per_lvl = GameData.shop_definitions[shop_key]["bonus"]

	if stat_name in ["cooldown", "tick_interval"]:
		final_value /= (1.0 + lvl * bonus_per_lvl)
	elif stat_name in ["armor", "amount", "revival", "reroll", "banish", "skip", "recovery", "pickup_range"]:
		final_value += (lvl * bonus_per_lvl)
	else:
		final_value *= (1.0 + lvl * bonus_per_lvl)

	return final_value


func _row_header() -> void:
	print("  %-22s | %-14s | %-14s | %s" % [
		"Stat", "Base (niv actuel)", "+Boutique", "+Accessoires"
	])
	print("  " + "-".repeat(22) + "-+-" + "-".repeat(14) + "-+-" + "-".repeat(14) + "-+---------------")


func _row(label: String, base, w_shop, w_full) -> void:
	print("  %-22s | %-14s | %-14s | %s" % [
		label, _fmt(base), _fmt(w_shop), _fmt(w_full)
	])


func _fmt(v) -> String:
	if v == null:
		return "—"
	if v is float or v is int:
		var f = float(v)
		# Si entier rond, pas de décimales inutiles
		if f == int(f) and abs(f) < 10000:
			return str(int(f))
		return "%.4f" % f
	return str(v)


# ============================================================================
# FONCTIONS DE DEBUG
# ============================================================================

func _jump_to_time(target_seconds: int) -> void:
	"""Saute à un temps spécifique (0-1200)"""
	if not GameTimer:
		return
	
	GameTimer.time_remaining = GameTimer.GAME_DURATION - target_seconds
	
	var _formatted = GameTimer.get_formatted_time()

func _toggle_god_mode() -> void:
	"""Active/désactive l'immortalité du joueur"""
	if not player:
		return
	
	god_mode_active = !god_mode_active
	
	player.is_god_mode = god_mode_active

func _toggle_one_shot_mode() -> void:
	"""Active/désactive le mode one-shot (ennemis meurent en 1 coup)"""
	one_shot_mode_active = !one_shot_mode_active
	GameData.debug_one_shot_mode = one_shot_mode_active

func _set_game_speed(speed: float) -> void:
	"""Change la vitesse du jeu"""
	Engine.time_scale = speed

func _kill_all_enemies() -> void:
	"""Tue tous les ennemis à l'écran"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var _count = enemies.size()
	
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(999999)

func _heal_player() -> void:
	"""Soigne le joueur au max"""
	if not player:
		return
	
	if player.has("current_health") and player.has("max_health"):
		player.current_health = player.max_health
		if player.has("health_bar"):
			player.health_bar.value = player.max_health

func _add_player_levels(amount: int) -> void:
	"""Ajoute des niveaux au joueur"""
	if not player:
		return
	
	if player.has_method("level_up"):
		for i in range(amount):
			# On donne l'XP nécessaire pour level up
			if player.has("experience") and player.has("experience_required"):
				player.experience = player.experience_required
				player.level_up()

func _force_victory() -> void:
	"""Force la victoire immédiatement"""
	# Option 1 : Via BossManager si disponible
	if game_scene.has("boss_manager") and game_scene.boss_manager:
		game_scene.boss_manager.final_boss_defeated.emit()
		print("[Debug] Victoire forcée (via BossManager)")
		return
	
	# Option 2 : Via VictoryManager si disponible
	if game_scene.has("victory_manager") and game_scene.victory_manager:
		if game_scene.victory_manager.has_method("force_victory"):
			game_scene.victory_manager.force_victory()
			print("[Debug] Victoire forcée (via VictoryManager)")
			return

# ============================================================================
# HELPERS
# ============================================================================

func is_god_mode_active() -> bool:
	return god_mode_active

func is_one_shot_mode_active() -> bool:
	return one_shot_mode_active
