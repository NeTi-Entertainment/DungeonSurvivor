extends Node2D

# Stats transférées par l'arme
var damage = 20
var knockback = 45
var projectile_speed_mult = 1.0
var amount = 5
var explosion_delay = 1.0
var area_scale = 1.0
var crit_chance = 0.0
var crit_damage = 1.4

var spike_scene = preload("res://Scenes/Weapons/Projectiles/SpikeProjectile.tscn")

@onready var explosion_timer = $ExplosionTimer

func _ready():
	# On lance le compte à rebours dès l'apparition
	explosion_timer.wait_time = explosion_delay
	explosion_timer.timeout.connect(_explode)
	explosion_timer.start()
	
	# Petit effet d'apparition (Pop)
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func setup_stats(stats: Dictionary):
	damage = stats["damage"]
	knockback = stats["knockback"]
	projectile_speed_mult = stats["projectile_speed"]
	amount = stats["amount"]
	explosion_delay = stats["duration"] # Délai avant boom
	area_scale = stats["area"]
	crit_chance = stats["crit_chance"]
	crit_damage = stats["crit_damage"]

func _explode():
	# Calcul de la répartition angulaire
	# Règle : Le premier tire vers le HAUT (-PI/2 ou -90 deg)
	# Les autres sont répartis équitablement (TAU / amount)
	
	var start_angle = -PI / 2 # Vers le haut
	var angle_step = TAU / amount
	
	for i in range(amount):
		var current_angle = start_angle + (i * angle_step)
		var direction = Vector2.RIGHT.rotated(current_angle)
		
		_spawn_spike(direction)
	
	# Une fois explosée, la mine disparaît
	queue_free()

func _spawn_spike(dir: Vector2):
	var spike = spike_scene.instantiate()
	spike.global_position = global_position
	spike.setup(damage, knockback, projectile_speed_mult, dir, area_scale, crit_chance, crit_damage)
	
	# On ajoute les piques à la racine du jeu (pour ne pas qu'elles disparaissent avec la mine)
	get_tree().current_scene.add_child(spike)
