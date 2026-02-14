extends Resource
class_name EnemyStats

# --- VISUEL ---
@export_group("Visuel et Identité")
@export var id: String = "enemy_01"
@export var name: String = "Nom Affiché"
@export var texture: Texture2D # Le sprite de l'ennemi
@export var scale: float = 1.0 # Pour faire des gros ou des petits ennemis avec le même sprite
@export var hitbox_radius: float = 15.0

# --- STATS DE SURVIE ---
@export_group("Statistiques de Survie")
@export var max_hp: int = 20
@export var armor: int = 0
@export var knockback_resistance: float = 0.0 # 0.0 = Plume, 1.0 = Mur de briques

# --- STATS OFFENSIVES ---
@export_group("Statistiques Offensives")
@export var damage: int = 5
@export var speed: float = 100.0 # Rappel: Joueur = 300.0
