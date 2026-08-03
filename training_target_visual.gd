extends Node2D

## Disque de la cible d'échauffement, dessiné une fois. Séparé du corps pour
## porter son propre light_mask sans affecter les collisions.

const RADIUS := 22.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.55, 0.55, 0.6))
	draw_circle(Vector2.ZERO, RADIUS * 0.66, Color(0.85, 0.85, 0.9))
	draw_circle(Vector2.ZERO, RADIUS * 0.33, Color(0.9, 0.25, 0.2))
