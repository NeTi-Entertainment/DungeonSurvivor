extends Area2D

const TEX_BLUE = preload("res://Assets/Loot/BlueExpOrb.png")   # Valeur 1
const TEX_GREEN = preload("res://Assets/Loot/GreenExpOrb.png") # Valeur 5
const TEX_RED = preload("res://Assets/Loot/RedExpOrb.png")     # Valeur 10
const TEX_PURPLE = preload("res://Assets/Loot/PurpleExpOrb.png") # Valeur 25

@export var xp_value: int = 1
var target: Node2D = null
var speed: float = 400.0 # Vitesse à laquelle la gemme vole vers le joueur

@onready var sprite = $Sprite2D

func _ready() -> void:
	# C'est ici que la magie opère : dès que l'objet apparaît dans le jeu,
	# il applique la texture correspondant à la valeur qu'on lui a donnée.
	_update_texture()

func setup(value: int) -> void:
	xp_value = value
	# Si par hasard on appelle setup ALORS que l'objet est déjà en jeu
	if is_inside_tree() and sprite:
		_update_texture()

func _update_texture() -> void:
	if not sprite:
		return
		
	match xp_value:
		1: sprite.texture = TEX_BLUE
		5: sprite.texture = TEX_GREEN
		10: sprite.texture = TEX_RED
		25: sprite.texture = TEX_PURPLE
		_: sprite.texture = TEX_BLUE

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
