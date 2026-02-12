extends Node2D

var radius: float = 1500.0
var void_color: Color = Color.BLACK

func setup(map_radius: float, color: Color):
	radius = map_radius
	void_color = color
	queue_redraw() # Force le redessin

func _draw():
	var _huge_radius = radius + 4000.0 # L'extérieur du mur
	var thickness = 4000.0 # L'épaisseur du mur noir
	
	# On dessine un cercle vide dont le trait est si épais qu'il fait le "noir" autour
	draw_arc(Vector2.ZERO, radius + (thickness / 2.0), 0, TAU, 64, void_color, thickness)
	
	# Optionnel : Dessiner une ligne fine rouge pour délimiter la zone jouable
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color.RED, 5.0)
