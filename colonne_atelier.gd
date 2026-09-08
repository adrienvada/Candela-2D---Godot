class_name ColonneAtelier
extends Node2D

## Habillage de colonne industrielle d'atelier / pilier d'occlusion (DA Brutaliste).
##
## Dessine les cerclages métalliques, le liséré halogène franc et les rivets
## sans altérer le polygone d'occlusion ni la forme physique de collision.

const Charte := preload("res://charte.gd")

@export var rayon: float = 85.0
@export var nb_rivets: int = 16


func _ready() -> void:
	z_index = 0
	queue_redraw()


func _draw() -> void:
	# 1. Fond sombre de la colonne
	draw_circle(Vector2.ZERO, rayon, Charte.NOIR)

	# 2. Liséré halogène franc extérieur (lumière accrochée par la torche)
	draw_arc(Vector2.ZERO, rayon, 0.0, TAU, 32, Charte.HALOGENE, 2.0)

	# 3. Cerclages concentriques d'acier d'atelier
	draw_arc(Vector2.ZERO, rayon * 0.75, 0.0, TAU, 24, Charte.LINE, 1.2)
	draw_arc(Vector2.ZERO, rayon * 0.45, 0.0, TAU, 20, Charte.LINE * 0.8, 1.0)

	# 4. Couronne de rivets périphériques d'acier
	for i in range(nb_rivets):
		var angle := float(i) * (TAU / float(nb_rivets))
		var r_pos := Vector2(cos(angle), sin(angle)) * (rayon - 4.5)
		draw_circle(r_pos, 1.6, Charte.ACIER * 0.55)
		draw_circle(r_pos + Vector2(0.5, 0.5), 0.8, Charte.NOIR)

	# 5. Croisillon d'armature centrale
	var c_len := rayon * 0.35
	draw_line(Vector2(-c_len, 0), Vector2(c_len, 0), Charte.LINE * 0.6, 1.0)
	draw_line(Vector2(0, -c_len), Vector2(0, c_len), Charte.LINE * 0.6, 1.0)
