extends Area2D
class_name Heal
# Heal.gd - Pickup de soin

@export var heal_amount: int = 10  # Quantité de PV restaurés

var target: Node2D = null
var speed: float = 300.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Si tu as une texture de heal, assigne-la ici
	# sprite.texture = preload("res://Assets/Loot/HealIcon.png")
	pass

func _physics_process(delta: float) -> void:
	if not target:
		return
	
	# Mouvement vers le joueur (comme ExperienceGem)
	global_position = global_position.move_toward(target.global_position, speed * delta)
	speed += 10.0  # Accélération
	
	# Collection par proximité
	if global_position.distance_to(target.global_position) < 15.0:
		_collect()

func _collect() -> void:
	"""Soigne le joueur et se détruit"""
	if not target:
		queue_free()
		return
	
	# Appeler la fonction de soin du joueur
	if target.has_method("heal"):
		target.heal(heal_amount)
	queue_free()

func attract(player_node: Node2D) -> void:
	"""Appelé par le PickupArea du joueur"""
	target = player_node
