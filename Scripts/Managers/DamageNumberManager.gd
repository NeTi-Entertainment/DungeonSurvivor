extends Node
class_name DamageNumberManager

# On utilisera une simple instanciation dynamique pour commencer
# Si tu veux une scène spécifique plus tard, tu pourras charger un .tscn ici
var damage_label_script = preload("res://Scripts/UI/DamageLabel.gd")

func _ready() -> void:
	# Connexion au signal global
	GameData.damage_taken.connect(_on_damage_taken)

func _on_damage_taken(amount: int, pos: Vector2, is_critical: bool) -> void:
	if amount <= 0: return
	
	_spawn_label(amount, pos, is_critical)

func _spawn_label(amount: int, pos: Vector2, is_critical: bool) -> void:
	# Création dynamique du label
	var label = DamageLabel.new()
	label.set_script(damage_label_script)
	
	# On l'ajoute à la scène courante (Game)
	# Utiliser call_deferred est plus sûr lors des collisions physiques
	add_child(label)
	
	# Configuration (décalage aléatoire pour éviter que les chiffres se superposent trop)
	var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	label.setup(amount, pos + random_offset, is_critical)
