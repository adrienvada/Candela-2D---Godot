class_name GadgetOmbre
extends GadgetBase

## L'ombre habitée — gadget de l'Occulteur, chantier CLASSES, étape 5.
##
## Une plaque d'acier découpée en forme de torse, boulonnée sur un mât. **Elle
## n'émet aucune lumière : elle en bloque.** Dès qu'une torche l'atteint, elle
## projette une ombre humaine sur le mur d'en face.
##
## C'est le gadget le moins cher du chantier et peut-être le plus retors : il
## n'attaque ni les yeux ni les oreilles, il attaque la **déduction**. Dans un
## jeu où l'on apprend à lire les ombres, une ombre qui ment ne se distingue de
## rien.
##
## ## Le même nœud que le voile, un autre polygone
##
## Les deux sont un `StaticBody2D` plus un `LightOccluder2D` ; seule la forme de
## l'ombre change. C'est ce qui les a fait livrer ensemble.

## Le gabarit du torse projeté. Il vaut la demi-largeur d'épaules du joueur
## (18 px de rayon), sans quoi l'ombre serait d'une taille qui ne correspond à
## personne — et une ombre qui ne trompe pas ne sert à rien.
const DEMI_TORSE := 18.0
const DEMI_EPAISSEUR := 3.0


func _init() -> void:
	rayon = DEMI_TORSE
	# Une plaque d'acier arrête la balle, contrairement à la bâche du Spectre.
	arrete_les_balles = true
	eblouit = false
	pv = 3.0


## Le contour du torse, vu de dessus : une plaque mince, mais de la LARGEUR d'un
## corps. C'est cette largeur, et elle seule, qui donne à l'ombre sa silhouette.
func _monter_occluder() -> void:
	var occ := LightOccluder2D.new()
	occ.name = "Occluder"
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-DEMI_TORSE, -DEMI_EPAISSEUR),
		Vector2(DEMI_TORSE, -DEMI_EPAISSEUR),
		Vector2(DEMI_TORSE, DEMI_EPAISSEUR),
		Vector2(-DEMI_TORSE, DEMI_EPAISSEUR),
	])
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.occluder_light_mask = MapGeometry.WALL_LAYER
	add_child(occ)


## Son image : l'arête haute de la plaque et son socle, vus de dessus. Une plaque
## d'acier vue de dessus reste une ligne, et son intérêt n'est pas ce qu'on voit
## d'elle mais l'ombre qu'elle projette.
func _monter_visuel() -> void:
	_poser_sprite("Visuel", "ombre_habitee")
