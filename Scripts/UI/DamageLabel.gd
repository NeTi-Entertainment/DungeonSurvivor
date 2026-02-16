extends Label
class_name DamageLabel

var velocity: Vector2 = Vector2(0, -50) # Monte vers le haut
var duration: float = 0.8
var timer: float = 0.0

func setup(amount: int, start_pos: Vector2, is_critical: bool = false) -> void:
	text = str(amount)
	global_position = start_pos
	
	# Configuration visuelle rapide (Code-only pour éviter de dépendre d'un .tres)
	var settings = LabelSettings.new()
	settings.font_size = 24 if is_critical else 16
	settings.font_color = Color(1, 0.2, 0.2) if is_critical else Color(1, 1, 1)
	settings.outline_size = 4
	settings.outline_color = Color(0, 0, 0)
	label_settings = settings
	
	# Centrer le texte sur le point d'impact
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	z_index = 100 # Toujours au-dessus des ennemis

func _process(delta: float) -> void:
	# Mouvement
	global_position += velocity * delta
	
	# Timer pour l'animation de disparition
	timer += delta
	if timer >= duration:
		queue_free()
	elif timer > duration * 0.5:
		# Fade out sur la deuxième moitié de la vie
		modulate.a = 1.0 - ((timer - duration * 0.5) / (duration * 0.5))
