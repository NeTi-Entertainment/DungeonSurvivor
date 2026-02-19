extends Resource
class_name MapConfig

# ============================================================================
# PARAMÈTRES VISUELS
# ============================================================================

@export var map_name: String = "Forêt Sombre"
@export var map_radius: float = 1500.0 # Taille du cercle jouable
@export var background_color: Color = Color.BLACK # Couleur du "Vide" autour
@export var background_texture: Texture2D # La texture du sol pour cette map
@export var music_track: AudioStream # La musique de la map

# ============================================================================
# BESTIAIRE & WAVES
# ============================================================================

@export_group("Bestiaire")
@export var enemies_cycle_1: Array[EnemyStats] # 0-6 min
@export var enemies_cycle_2: Array[EnemyStats] # 6-12 min
@export var enemies_cycle_3: Array[EnemyStats] # 12-18 min

@export_group("Reaper")
@export var reaper_stats: EnemyStats

@export_group("Spawn Rates")
@export_range(0.1, 10.0, 0.1) var spawn_rate_cycle_1: float = 1.0 # Ennemis par seconde
@export_range(0.1, 10.0, 0.1) var spawn_rate_cycle_2: float = 1.5
@export_range(0.1, 10.0, 0.1) var spawn_rate_cycle_3: float = 2.5

@export_group("Spawn Settings")
@export_range(800, 2000, 50) var spawn_distance: float = 1200.0 # Distance de spawn autour du joueur
@export_range(200, 1000, 50) var spawn_distance_variance: float = 200.0 # Variance pour éviter un cercle parfait

@export_group("Phases de Spawn (Nouveau Système)")
@export var spawn_phases: Array[SpawnPhase] = []

# ============================================================================
# DESTRUCTIBLES (Objets cassables)
# ============================================================================

@export_group("Destructibles")
@export_range(0, 500, 5) var destructible_count: int = 50 # Nombre d'objets destructibles

# ============================================================================
# BOSS CHECKPOINTS (Phase 3)
# ============================================================================

@export_group("Boss Checkpoints")
@export var boss_3min: EnemyStats # Mini-boss 1
@export var boss_6min: EnemyStats # Mini-boss 2
@export var boss_9min: EnemyStats # Mini-boss 3
@export var boss_12min: EnemyStats # Mini-boss 4
@export var boss_15min: EnemyStats # Mini-boss 5
@export var boss_18min: EnemyStats # Boss final
