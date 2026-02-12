extends Area2D

@export var xp_value: int = 20000
var target: Node2D = null
var speed: float = 400.0 # Vitesse à laquelle la gemme vole vers le joueur

func _physics_process(delta: float) -> void:
	if target:
		# Mouvement magnétique vers le joueur
		global_position = global_position.move_toward(target.global_position, speed * delta)
		
		# Si la gemme touche le joueur (distance très faible)
		if global_position.distance_to(target.global_position) < 10.0:
			_collect()

func _collect() -> void:
	# On appelle la fonction du joueur pour donner l'XP
	if target.has_method("gain_experience"):
		target.gain_experience(xp_value)
	queue_free() # La gemme disparaît

# Cette fonction sera appelée par le "Collecteur" du joueur
func attract(player_node: Node2D) -> void:
	target = player_node
