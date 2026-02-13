extends Area2D
# VictoryPortal.gd - Portail de victoire interactible

# ============================================================================
# SIGNAUX
# ============================================================================

signal portal_activated()

# ============================================================================
# CONSTANTES
# ============================================================================

const INTERACTION_DISTANCE: float = 100.0  # Distance pour pouvoir interagir

# ============================================================================
# ÉTAT
# ============================================================================

var player_nearby: bool = false
var player_ref: Node2D = null

# ============================================================================
# RÉFÉRENCES NODES
# ============================================================================

@onready var sprite = $Sprite2D
@onready var interaction_label = $InteractionLabel  # Label "Press E"

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connexions
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Cacher le label au départ
	if interaction_label:
		interaction_label.hide()

func _process(_delta: float) -> void:
	# Vérifier si le joueur appuie sur E quand il est proche
	if player_nearby and Input.is_action_just_pressed("ui_accept"):
		_activate_portal()

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	"""Appelé quand un corps entre dans l'Area2D"""
	if body.is_in_group("player"):
		player_nearby = true
		player_ref = body
		
		# Afficher le label "Press E"
		if interaction_label:
			interaction_label.show()

func _on_body_exited(body: Node2D) -> void:
	"""Appelé quand un corps sort de l'Area2D"""
	if body.is_in_group("player"):
		player_nearby = false
		player_ref = null
		
		# Cacher le label
		if interaction_label:
			interaction_label.hide()

# ============================================================================
# ACTIVATION
# ============================================================================

func _activate_portal() -> void:
	"""Active le portail (joueur a appuyé sur E)"""
	print("[VictoryPortal] Portail activé par le joueur")
	portal_activated.emit()
	
	# Désactivation pour éviter la double activation
	player_nearby = false
	if interaction_label:
		interaction_label.hide()
