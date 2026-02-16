extends Resource
class_name SpawnPhase
# SpawnPhase.gd - Définit une phase de spawn avec timing et poids

@export_group("Timing")
@export var start_time: int = 0
@export var end_time: int = 60
@export var spawn_interval: float = 1.0

@export_group("Spawns")
@export var enemies: Array[WeightedEnemy] = []

@export_group("Pattern: Meute (Pack)")
@export var pack_enemy: EnemyStats
@export var pack_enabled: bool = false
@export var pack_interval: float = 10.0
@export var pack_min_size: int = 3
@export var pack_max_size: int = 5
@export var pack_radius: float = 100.0

@export_group("Pattern: Cercle (Encerclement)")
@export var circle_enemy: EnemyStats
@export var circle_enabled: bool = false
@export var circle_interval: float = 20.0
@export var circle_enemy_count: int = 12
@export var circle_radius: float = 500.0

@export_group("Pattern: Ligne (Vague)")
@export var line_enemy: EnemyStats
@export var line_enabled: bool = false
@export var line_interval: float = 30.0
@export var enemies_per_line: int = 10

# Cette fonction calcule le poids total et tire un ennemi au hasard
func get_random_enemy() -> EnemyStats:
	if enemies.is_empty():
		return null
	
	var total_weight: int = 0
	for entry in enemies:
		if entry.enemy_stats:
			total_weight += entry.weight
	
	if total_weight == 0:
		return null
	
	var random_value = randi() % total_weight
	var current_weight = 0
	
	for entry in enemies:
		if entry.enemy_stats:
			current_weight += entry.weight
			if random_value < current_weight:
				return entry.enemy_stats
	
	return enemies[0].enemy_stats
