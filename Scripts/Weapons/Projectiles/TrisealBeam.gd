extends Area2D

@onready var line_2d = $Line2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	# SÉCURITÉ : On force les réglages de collision ici
	collision_layer = 0   # Le rayon n'est pas un objet physique
	collision_mask = 2    # Il détecte uniquement la couche 2 (Ennemis)
	monitoring = true     # Il doit surveiller les chevauchements
	monitorable = false   # Personne ne peut "rentrer" dedans (optimisation)

func setup(length: float, width: float):
	# 1. Visuel
	line_2d.points = [Vector2.ZERO, Vector2(length, 0)]
	line_2d.width = width
	
	# 2. Physique (Hitbox)
	# On crée un rectangle de la taille du rayon
	var rect = RectangleShape2D.new()
	rect.size = Vector2(length, width)
	collision_shape.shape = rect
	
	# On le centre correctement :
	# X : length / 2 (pour couvrir de 0 à length)
	# Y : 0 (centré sur la ligne)
	collision_shape.position = Vector2(length / 2.0, 0)
