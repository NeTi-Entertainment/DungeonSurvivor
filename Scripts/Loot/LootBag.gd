extends Area2D

var item_id: String = ""
var item_type: String = "material" # "material" ou "consumable"
var speed: float = 300.0
var target = null
var is_collected: bool = false

func setup(p_item_id: String, p_type: String = "material"):
	item_id = p_item_id
	item_type = p_type
	
	# Visuel : Change la couleur pour les buffs
	if item_type == "consumable":
		# Buffs : Couleurs vives
		match item_id:
			"buff_potion": $Sprite2D.modulate = Color.RED # Soin
			"buff_magnet": $Sprite2D.modulate = Color.BLUE # Aimant
			"buff_freeze": $Sprite2D.modulate = Color.CYAN # Gel
			"buff_nuke": $Sprite2D.modulate = Color.ORANGE # Bombe
			"buff_dice": $Sprite2D.modulate = Color.PURPLE
			"buff_invincible": $Sprite2D.modulate = Color.FLORAL_WHITE # Blanc pur
			"buff_zeal": $Sprite2D.modulate = Color.TEAL # Bleu vert électrique
			"buff_gold": $Sprite2D.modulate = Color(1, 0.8, 0.2) # Jaune Pâle
			"buff_repulsion": $Sprite2D.modulate = Color.MAGENTA
			"buff_buff": $Sprite2D.modulate = Color.PINK
			_: $Sprite2D.modulate = Color.GREEN # Par défaut

func attract(player_node):
	target = player_node

func _physics_process(delta):
	if target:
		global_position = global_position.move_toward(target.global_position, speed * delta)
		speed += 15.0
		
		if global_position.distance_to(target.global_position) < 15:
			_collect()

func _collect():
	if is_collected: return
	is_collected = true
	
	if item_type == "material":
		# Logique existante
		GameData.add_run_material(item_id, 1)
		
	elif item_type == "consumable":
		# Logique d'effet immédiat
		_apply_buff_effect()
	
	queue_free()

func _apply_buff_effect():
	if not target: return
	
	match item_id:
		"buff_potion":
			# Rend 30 PV (ou 20% max hp)
			if target.has_method("heal"):
				target.max_health * 0.20
				
		"buff_magnet":
			# Attire TOUS les items (XP, Or, Sacs)
			# Nécessite que ces objets soient dans le groupe "loot"
			var magnetizables = get_tree().get_nodes_in_group("magnetizable")
			for item in magnetizables:
				if item.has_method("attract"):
					item.attract(target)
					
		"buff_nuke":
			_trigger_nuke()
			
		"buff_freeze":
			# Gèle pendant 10 secondes via GameData
			GameData.trigger_freeze_enemies(10.0)
			
		"buff_dice":
			_trigger_dice_roll()
			
		"buff_invincible":
			if target.has_method("activate_god_mode"):
				target.activate_god_mode(10.0)
				
		"buff_zeal":
			if target.has_method("activate_speed_buff"):
				target.activate_speed_buff(10.0)
			
		"buff_gold":
			GameData.trigger_gold_rush(10.0)
			
		"buff_repulsion":
			_trigger_repulsion()
			
		"buff_buff":
			var stat_name = GameData.apply_random_stat_bonus()
			# Petit texte pour dire quoi a été boosté
			_spawn_floating_text(global_position, "+1% " + stat_name.capitalize(), Color.PINK)

func _trigger_nuke():
	# Rayon approximatif de l'écran (ex: 1920 / 2 = 960, on prend large : 1000)
	# Ou mieux : utiliser la distance visuelle
	var kill_radius = 1000.0 
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		# Vérifie si l'ennemi est à portée de vue
		if enemy.global_position.distance_to(target.global_position) <= kill_radius:
			if enemy.has_method("take_damage"):
				if enemy.is_boss:
					# Boss : 25% de la santé max
					var dmg = int(enemy.max_hp * 0.25)
					enemy.take_damage(dmg)
					_spawn_floating_text(enemy.global_position, "-" + str(dmg), Color.RED)
				else:
					# Normal : Mort instantanée
					enemy.take_damage(999999)

func _trigger_repulsion():
	if not target: return
	
	# On récupère tous les ennemis
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		# 1. Calcul de la distance entre le joueur et l'ennemi
		var dist = enemy.global_position.distance_to(target.global_position)
		
		# 2. Si l'ennemi est À L'INTÉRIEUR du cercle (plus proche que la limite)
		if dist < GameData.REPULSION_RADIUS:
			# On calcule la distance qu'il doit parcourir pour toucher le bord
			var push_distance = GameData.REPULSION_RADIUS - dist
			
			# 3. Calcul de la force nécessaire
			# Formule : Force = Distance * Friction (récupérée sur l'ennemi ou 5.0 par défaut)
			var decay = 5.0
			if "knockback_decay" in enemy:
				decay = enemy.knockback_decay
				
			var required_force = push_distance * decay
			
			# 4. Application
			var dir = (enemy.global_position - target.global_position).normalized()
			
			if enemy.has_method("take_damage"):
				# 0 dégâts, juste le recul calculé sur mesure
				enemy.take_damage(0, required_force, dir)

func _trigger_dice_roll():
	var options = ["reroll", "skip", "banish"]
	var result = options.pick_random()
	var text_display = ""
	
	match result:
		"reroll":
			target.reroll_count += 1
			text_display = "+1 REROLL"
		"skip":
			target.skip_count += 1
			text_display = "+1 SKIP"
		"banish":
			target.banish_count += 1
			text_display = "+1 BANISH"
	
	# Afficher le texte à l'endroit du ramassage
	_spawn_floating_text(global_position, text_display, Color.WHITE)

# Petite fonction utilitaire pour le texte flottant "Dice"
func _spawn_floating_text(pos: Vector2, txt: String, color: Color):
	var label = Label.new()
	label.text = txt
	label.modulate = color
	label.position = pos + Vector2(-20, -50) # Un peu au dessus
	label.z_index = 100 # Au dessus de tout
	
	# Style simple (Outline)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	get_tree().current_scene.add_child(label)
	
	# Animation (Monter et disparaitre)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
