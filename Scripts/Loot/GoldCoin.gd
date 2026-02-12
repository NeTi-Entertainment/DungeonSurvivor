extends Area2D

var value = 1
var speed = 300.0
var target = null

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if target:
		var dir = (target.global_position - global_position).normalized()
		position += dir * speed * delta
		
		# Accélération effet aimant
		speed += 10.0

func _on_body_entered(body):
	# Si le joueur s'approche, on active l'aimant
	if body.name == "Player":
		target = body

	# Si on touche le joueur physiquement (on peut ajouter une petite distance de seuil)
	if target and global_position.distance_to(target.global_position) < 20.0:
		if target.has_method("add_gold"):
			target.add_gold(value)
			queue_free()

func attract(player_node):
	target = player_node
