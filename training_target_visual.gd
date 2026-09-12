extends Node2D

const Charte := preload("res://charte.gd")

## Disque de la cible d'échauffement, dessiné une fois. Séparé du corps pour
## porter son propre light_mask sans affecter les collisions.
##
## Refonte roman graphique, lot 5 (2026-09-11) : c'était trois disques
## concentriques sans bord — le cas le plus simple du dépôt. Une cible de
## planche a ses anneaux CERNÉS d'encre et sa couronne hachurée : les aplats
## restent, un trait noir les sépare, et l'anneau extérieur porte des stries
## radiales, l'ombre dessinée d'une cible en tôle.

const RADIUS := 22.0
const TRAIT := Color(Charte.NOIR, 0.85)
const TRAIT_LARGEUR := 1.5
## Nombre de stries sur la couronne, et leur étendue radiale.
const STRIES := 30
const STRIE_DE := 0.72
const STRIE_A := 0.95

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Charte.ACIER * 0.72)
	draw_circle(Vector2.ZERO, RADIUS * 0.66, Charte.ACIER)
	draw_circle(Vector2.ZERO, RADIUS * 0.33, Charte.ROUGE)
	# Les stries de la couronne : des traits radiaux, un sur deux plus court,
	# pour que la bande se lise comme hachurée et non comme dentée.
	for i in STRIES:
		var a := TAU * float(i) / float(STRIES)
		var dir := Vector2(cos(a), sin(a))
		var de := STRIE_DE if i % 2 == 0 else (STRIE_DE + STRIE_A) * 0.5
		draw_line(dir * RADIUS * de, dir * RADIUS * STRIE_A, TRAIT, 1.0)
	# Les cernes, du plus grand au plus petit.
	for r in [1.0, 0.66, 0.33]:
		draw_arc(Vector2.ZERO, RADIUS * r, 0.0, TAU, 48, TRAIT, TRAIT_LARGEUR)
