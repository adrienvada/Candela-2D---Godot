extends Node2D

const Charte := preload("res://charte.gd")

## Disque de la cible d'échauffement, dessiné une fois. Séparé du corps pour
## porter son propre light_mask sans affecter les collisions.

const RADIUS := 22.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Charte.ACIER * 0.72)
	draw_circle(Vector2.ZERO, RADIUS * 0.66, Charte.ACIER)
	draw_circle(Vector2.ZERO, RADIUS * 0.33, Charte.ROUGE)
