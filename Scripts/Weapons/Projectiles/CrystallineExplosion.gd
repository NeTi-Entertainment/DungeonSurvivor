extends Area2D

var damage = 0
var knockback = 0
var hit_history = []
var target_scale = Vector2.ONE

func setup(dmg: int, kb: float, scale_mult: float):
	damage = dmg
	knockback = kb
	
	# On stocke la taille cible calculée avec les bonus
	target_scale = Vector2(scale_mult, scale_mult)
	
	# On applique immédiatement pour éviter une frame visuelle incorrecte (optionnel si _ready part à 0)
	scale = target_scale

func _ready():
# L'explosion ne dure qu'un instant pour les dégâts
	
	# Animation d'apparition (Pop)
	scale = Vector2.ZERO # On part de zéro
	
	var tween = create_tween()
	# CORRECTION ICI : On tween vers 'target_scale' au lieu de 'Vector2.ONE'
	tween.tween_property(self, "scale", target_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
	tween.tween_property(self, "modulate:a", 0.0, 0.3) # Fade out
	tween.tween_callback(queue_free)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("take_damage") and body not in hit_history:
		hit_history.append(body)
		# L'explosion repousse depuis le centre de l'explosion
		var dir = (body.global_position - global_position).normalized()
		body.take_damage(damage, knockback, dir)
