extends Area2D

var value = 1
var speed = 300.0
var target = null

func _ready():
	# body_entered : collecte au contact direct (joueur marche sur la pièce)
	body_entered.connect(_on_body_entered)

func setup(p_value: int) -> void:
	value = p_value

func _physics_process(delta):
	if not target:
		return
	
	global_position = global_position.move_toward(target.global_position, speed * delta)
	speed += 10.0
	
	# Collection par proximité dans _physics_process (et non dans le signal)
	if global_position.distance_to(target.global_position) < 15.0:
		if target.has_method("add_gold"):
			target.add_gold(value)
		queue_free()

func _on_body_entered(body) -> void:
	# Le joueur marche directement sur la pièce → on définit la cible
	# La collection se fait dans _physics_process dès que la distance est atteinte
	if body.name == "Player":
		target = body

func attract(player_node) -> void:
	# Appelé par le PickupArea du joueur quand la pièce entre dans sa portée
	target = player_node

#func _ready():
#	body_entered.connect(_on_body_entered)

#func _physics_process(delta):
#	if target:
#		var dir = (target.global_position - global_position).normalized()
#		position += dir * speed * delta
		
		# Accélération effet aimant
#		speed += 10.0

#func _on_body_entered(body):
	# Si le joueur s'approche, on active l'aimant
#	if body.name == "Player":
#		target = body

	# Si on touche le joueur physiquement (on peut ajouter une petite distance de seuil)
#	if target and global_position.distance_to(target.global_position) < 20.0:
#		if target.has_method("add_gold"):
#			target.add_gold(value)
#			queue_free()

#func attract(player_node):
#	target = player_node
