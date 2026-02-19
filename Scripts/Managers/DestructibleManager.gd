extends Node
class_name DestructibleManager
# DestructibleManager.gd - Génère procéduralement les destructibles sur la map

# ============================================================================
# CONFIGURATION
# ============================================================================

const DESTRUCTIBLE_PATH = "res://Assets/Destructibles/"
const MIN_DISTANCE_FROM_PLAYER: float = 300.0  # Ne pas spawn trop près du joueur
const MIN_DISTANCE_BETWEEN: float = 80.0  # Distance minimale entre destructibles

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var map_config: MapConfig = null
var player: CharacterBody2D = null
var game_scene: Node2D = null

var destructible_scene = preload("res://Scenes/Entities/Neutrals/Destructible.tscn")

# ============================================================================
# TEXTURES CHARGÉES
# ============================================================================

var available_textures: Array[Texture2D] = []

# ============================================================================
# SETUP
# ============================================================================

func setup(p_player: CharacterBody2D, p_map_config: MapConfig, p_game_scene: Node2D) -> void:
	"""Initialise le manager et charge les textures"""
	if not p_player or not p_map_config or not p_game_scene:
		push_error("[DestructibleManager] Setup échoué : Références invalides")
		return
	
	player = p_player
	map_config = p_map_config
	game_scene = p_game_scene
	
	_load_textures()
	
	if available_textures.is_empty():
		push_warning("[DestructibleManager] Aucune texture trouvée dans %s" % DESTRUCTIBLE_PATH)
		return
	
	print("[DestructibleManager] %d textures chargées" % available_textures.size())

func generate_destructibles() -> void:
	"""Génère tous les destructibles de la map"""
	if not map_config:
		push_error("[DestructibleManager] MapConfig non défini")
		return
	
	if available_textures.is_empty():
		push_warning("[DestructibleManager] Aucune texture disponible - skip génération")
		return
	
	var count = map_config.destructible_count
	var radius = map_config.map_radius * 0.9  # 90% du rayon pour éviter les bords
	
	var spawned_positions: Array[Vector2] = []
	var attempts = 0
	var max_attempts = count * 10  # Éviter boucle infinie
	
	print("[DestructibleManager] Génération de %d destructibles..." % count)
	
	while spawned_positions.size() < count and attempts < max_attempts:
		attempts += 1
		
		var pos = _get_random_position_in_circle(radius)
		
		# Vérifier distance du joueur
		if pos.distance_to(player.global_position) < MIN_DISTANCE_FROM_PLAYER:
			continue
		
		# Vérifier distance des autres destructibles
		if _is_position_valid(pos, spawned_positions):
			_spawn_destructible(pos)
			spawned_positions.append(pos)
	
	print("[DestructibleManager] %d destructibles générés" % spawned_positions.size())

# ============================================================================
# GÉNÉRATION
# ============================================================================

func _load_textures() -> void:
	"""Charge toutes les textures du dossier Destructibles"""
	var dir = DirAccess.open(DESTRUCTIBLE_PATH)
	
	if not dir:
		push_warning("[DestructibleManager] Impossible d'ouvrir %s" % DESTRUCTIBLE_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Charger uniquement les fichiers image
		if not dir.current_is_dir() and _is_image_file(file_name):
			var full_path = DESTRUCTIBLE_PATH + file_name
			var texture = load(full_path) as Texture2D
			
			if texture:
				available_textures.append(texture)
			else:
				push_warning("[DestructibleManager] Impossible de charger : %s" % full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _is_image_file(filename: String) -> bool:
	"""Vérifie si le fichier est une image supportée"""
	var ext = filename.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "webp", "svg"]

func _get_random_position_in_circle(radius: float) -> Vector2:
	"""Génère une position aléatoire dans le cercle de la map"""
	var angle = randf() * TAU
	var distance = sqrt(randf()) * radius  # sqrt pour distribution uniforme
	
	return Vector2(cos(angle), sin(angle)) * distance

func _is_position_valid(pos: Vector2, existing_positions: Array[Vector2]) -> bool:
	"""Vérifie qu'une position est suffisamment éloignée des autres"""
	for existing_pos in existing_positions:
		if pos.distance_to(existing_pos) < MIN_DISTANCE_BETWEEN:
			return false
	return true

func _spawn_destructible(pos: Vector2) -> void:
	"""Instancie un destructible à la position donnée"""
	if not destructible_scene:
		push_error("[DestructibleManager] Destructible.tscn introuvable")
		return
	
	var destructible = destructible_scene.instantiate()
	destructible.global_position = pos
	
	# Texture aléatoire
	var texture = available_textures[randi() % available_textures.size()]
	
	# HP aléatoire (2-4)
	var hp = randi_range(2, 4)
	
	game_scene.add_child(destructible)
	
	# Setup après l'ajout à la scène (pour que @onready soit valide)
	destructible.call_deferred("setup", texture, hp)
