extends Node2D

var damage = 10
var knockback = 8
var crit_chance = 0.0
var crit_damage = 1.5

@onready var hitbox = $Hitbox

func _ready():
	hitbox.body_entered.connect(_on_body_entered)
	hitbox.monitoring = false
	hitbox.visible = false

func setup_stats(dmg: int, kb: float, range_scale: float, c_chance: float, c_dmg: float):
	damage = dmg
	knockback = kb
	crit_chance = c_chance
	crit_damage = c_dmg
	
	# CORRECTION : On s'assure que l'échelle est au moins 1.0 (taille normale) 
	# ou proportionnelle si > 1.0. Si range_scale arrivait à 0, ça faisait disparaître l'épée.
	var final_scale = max(1.0, range_scale)
	
	scale = Vector2(final_scale, final_scale)

func swing(target_dir: Vector2 = Vector2.RIGHT):
	if hitbox.visible: return 
	
	rotation = target_dir.angle()
	
	hitbox.visible = true
	hitbox.monitoring = true
	
	hitbox.rotation_degrees = -60
	
	var tween = create_tween()
	tween.tween_property(hitbox, "rotation_degrees", 60, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		hitbox.visible = false
		hitbox.monitoring = false
		hitbox.rotation_degrees = 0
	)

func _on_body_entered(body):
	# On évite que l'épée ne blesse le joueur par erreur
	if body.is_in_group("player"): return
	
	if body.has_method("take_damage"):
		var dir = (body.global_position - global_position).normalized()
		
		var final_dmg = damage
		if randf() < crit_chance:
			final_dmg = int(damage * crit_damage)
			
		body.take_damage(final_dmg, knockback, dir)
