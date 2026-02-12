extends Resource
class_name MapConfig

@export var map_name: String = "Forêt Sombre"
@export var map_radius: float = 1500.0 # Taille du cercle jouable
@export var background_color: Color = Color.BLACK # Couleur du "Vide" autour
@export var background_texture: Texture2D # La texture du sol pour cette map
@export var music_track: AudioStream # La musique de la map

# Ici, on définit quels ennemis peuvent apparaître sur cette map
# On mettra nos fichiers .tres ici
@export_group("Bestiaire")
@export var enemies_cycle_1: Array[EnemyStats] # 0-6 min
@export var enemies_cycle_2: Array[EnemyStats] # 6-12 min
@export var enemies_cycle_3: Array[EnemyStats] # 12-18 min
