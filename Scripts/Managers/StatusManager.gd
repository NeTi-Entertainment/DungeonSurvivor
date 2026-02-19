extends Node
class_name StatusManager
# StatusManager.gd - Gère tous les statuts (burn, slow, stun, etc.) d'un ennemi

# ============================================================================
# SIGNAUX
# ============================================================================

signal status_applied(status_type: String)
signal status_removed(status_type: String)

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var enemy: CharacterBody2D = null  # Référence à l'ennemi parent

# ============================================================================
# ÉTAT DES STATUTS
# ============================================================================

# Dictionnaire des statuts actifs : { "burn": {timer: Timer, params: {...}}, ... }
var active_statuses: Dictionary = {}

# Vitesse de base de l'ennemi (sauvegardée pour restaurer après slow)
var base_speed: float = 0.0

# ============================================================================
# SETUP
# ============================================================================

func _ready() -> void:
	# Récupérer la référence à l'ennemi parent
	enemy = get_parent() as CharacterBody2D
	if not enemy:
		push_error("[StatusManager] Parent n'est pas un CharacterBody2D")
		return
	
	# Sauvegarder la vitesse de base
	if enemy.stats and "speed" in enemy.stats:
		base_speed = enemy.stats.speed

# ============================================================================
# API PUBLIQUE
# ============================================================================

func apply_status(status_type: String, params: Dictionary) -> void:
	"""Applique ou rafraîchit un statut sur l'ennemi.
	
	Paramètres attendus selon le type :
	- burn:  {damage: int, tick_rate: float, duration: float}
	- slow:  {duration: float, slow_factor: float}  # slow_factor = 0.6 pour 60% vitesse
	- stun:  {duration: float}
	"""
	
	match status_type:
		"burn":
			_apply_burn(params)
		"slow":
			_apply_slow(params)
		"stun":
			_apply_stun(params)
		_:
			push_warning("[StatusManager] Type de statut inconnu : %s" % status_type)

func remove_status(status_type: String) -> void:
	"""Retire un statut manuellement (utile pour cleanser/dispel futur)"""
	if not active_statuses.has(status_type):
		return
	
	var status_data = active_statuses[status_type]
	
	# Cleanup du timer si présent
	if status_data.has("timer") and is_instance_valid(status_data.timer):
		status_data.timer.stop()
		status_data.timer.queue_free()
	
	# Effets spécifiques au retrait
	match status_type:
		"slow", "stun":
			_restore_speed()
	
	active_statuses.erase(status_type)
	status_removed.emit(status_type)

func has_status(status_type: String) -> bool:
	return active_statuses.has(status_type)

func clear_all_statuses() -> void:
	"""Retire tous les statuts (appelé à la mort de l'ennemi)"""
	for status_type in active_statuses.keys():
		remove_status(status_type)

# ============================================================================
# IMPLÉMENTATIONS SPÉCIFIQUES
# ============================================================================

func _apply_burn(params: Dictionary) -> void:
	"""Applique ou rafraîchit le DoT de brûlure"""
	var damage: int = params.get("damage", 1)
	var tick_rate: float = params.get("tick_rate", 0.5)
	var duration: float = params.get("duration", 3.0)
	
	var total_ticks = int(duration / tick_rate)
	if total_ticks <= 0:
		return
	
	# Si burn déjà actif, on le rafraîchit (restart le timer avec nouvelle durée)
	if active_statuses.has("burn"):
		var existing = active_statuses["burn"]
		existing.timer.stop()
		existing.timer.queue_free()
	
	# Créer le timer de tick
	var burn_timer = Timer.new()
	burn_timer.wait_time = tick_rate
	burn_timer.one_shot = false
	add_child(burn_timer)
	
	# Stocker les données
	active_statuses["burn"] = {
		"timer": burn_timer,
		"ticks_left": total_ticks,
		"damage": damage
	}
	
	burn_timer.timeout.connect(func():
		if not is_instance_valid(enemy):
			burn_timer.queue_free()
			return
		
		var status = active_statuses.get("burn")
		if not status:
			burn_timer.queue_free()
			return
		
		# Appliquer les dégâts
		if enemy.has_method("take_damage"):
			enemy.take_damage(status.damage, 0, Vector2.ZERO)
		
		# Décompter
		status.ticks_left -= 1
		
		# Fin du DoT
		if status.ticks_left <= 0:
			remove_status("burn")
	)
	
	burn_timer.start()
	status_applied.emit("burn")

func _apply_slow(params: Dictionary) -> void:
	"""Applique ou rafraîchit le ralentissement"""
	var duration: float = params.get("duration", 2.0)
	var slow_factor: float = params.get("slow_factor", 0.6)  # 0.6 = 60% vitesse
	
	# Si slow déjà actif, on le rafraîchit
	if active_statuses.has("slow"):
		var existing = active_statuses["slow"]
		existing.timer.stop()
		existing.timer.queue_free()
	else:
		# Première application : réduire la vitesse
		if enemy.stats and "speed" in enemy.stats:
			enemy.stats.speed = base_speed * slow_factor
	
	# Timer de durée
	var slow_timer = Timer.new()
	slow_timer.wait_time = duration
	slow_timer.one_shot = true
	add_child(slow_timer)
	
	active_statuses["slow"] = {
		"timer": slow_timer,
		"slow_factor": slow_factor
	}
	
	slow_timer.timeout.connect(func():
		remove_status("slow")
	)
	
	slow_timer.start()
	status_applied.emit("slow")

func _apply_stun(params: Dictionary) -> void:
	"""Applique ou rafraîchit le stun (immobilisation)"""
	var duration: float = params.get("duration", 1.0)
	
	# Si stun déjà actif, on le rafraîchit
	if active_statuses.has("stun"):
		var existing = active_statuses["stun"]
		existing.timer.stop()
		existing.timer.queue_free()
	else:
		# Première application : vitesse à 0
		if enemy.stats and "speed" in enemy.stats:
			enemy.stats.speed = 0.0
	
	# Timer de durée
	var stun_timer = Timer.new()
	stun_timer.wait_time = duration
	stun_timer.one_shot = true
	add_child(stun_timer)
	
	active_statuses["stun"] = {
		"timer": stun_timer
	}
	
	stun_timer.timeout.connect(func():
		remove_status("stun")
	)
	
	stun_timer.start()
	status_applied.emit("stun")

func _restore_speed() -> void:
	"""Restaure la vitesse de base (après slow/stun)"""
	if not is_instance_valid(enemy):
		return
	
	# Si stun actif, ne pas restaurer (stun prime sur slow)
	if active_statuses.has("stun"):
		return
	
	# Si slow actif, appliquer le facteur slow (pas la vitesse de base)
	if active_statuses.has("slow"):
		var slow_data = active_statuses["slow"]
		if enemy.stats and "speed" in enemy.stats:
			enemy.stats.speed = base_speed * slow_data.slow_factor
		return
	
	# Aucun statut de mouvement actif : restaurer base
	if enemy.stats and "speed" in enemy.stats:
		enemy.stats.speed = base_speed
