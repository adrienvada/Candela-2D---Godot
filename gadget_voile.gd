class_name GadgetVoile
extends GadgetBase

## Le voile — gadget du Spectre, chantier CLASSES, étape 5.
##
## Une bâche tendue entre deux piquets. **Elle arrête la lumière, les balles la
## traversent.** C'est un mur qui n'en est pas un : il corrompt la lecture de la
## carte, qui est le seul repère stable du joueur dans le noir.
##
## ## Pourquoi il est presque invisible, et pourquoi c'est voulu
##
## Vue strictement de dessus, une bâche verticale est **une ligne**. On ne la
## remarque pas ; on remarque ce qu'elle fait à la lumière. Un sprite bien
## lisible de dessus serait un défaut de conception, pas une réussite — d'où une
## bande étroite et non un objet reconnaissable.

## Demi-longueur de la bâche, en pixels. Elle est LARGE et mince : c'est ce
## rapport qui en fait un obstacle de lumière et non un objet.
const DEMI_LONGUEUR := 84.0
const DEMI_EPAISSEUR := 4.0


func _init() -> void:
	rayon = DEMI_LONGUEUR
	# La balle la déchire et poursuit. C'est TOUT ce qui distingue ce gadget
	# d'un mur, et c'est la ligne à ne pas « simplifier ».
	arrete_les_balles = false
	eblouit = false
	pv = 2.0
	# En travers du regard, comme la valeur par défaut du socle : une bâche
	# plantée DANS l'axe où l'on vise ne masque rien du tout.
	angle_pose = PI / 2.0


## Une bande, pas un disque. L'ombre portée doit avoir la forme de la bâche.
func _monter_occluder() -> void:
	var occ := LightOccluder2D.new()
	occ.name = "Occluder"
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-DEMI_LONGUEUR, -DEMI_EPAISSEUR),
		Vector2(DEMI_LONGUEUR, -DEMI_EPAISSEUR),
		Vector2(DEMI_LONGUEUR, DEMI_EPAISSEUR),
		Vector2(-DEMI_LONGUEUR, DEMI_EPAISSEUR),
	])
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.occluder_light_mask = MapGeometry.WALL_LAYER
	add_child(occ)


## Le visuel est DESSINÉ, et il n'y a pas de sprite à attendre.
##
## ⚠️ **Ceci renverse la décision de l'étape 5**, qui criait « sprite absent » et
## ne montrait rien. Cette décision supposait qu'une planche viendrait ; la note
## de tête de ce fichier dit l'inverse depuis le premier jour — *« vue
## strictement de dessus, une bâche verticale est une ligne »*, et *« un sprite
## bien lisible de dessus serait un défaut de conception »*. Peindre une image
## pour obtenir une ligne serait payer un asset pour dessiner deux segments.
##
## Ce n'est donc pas un repli en attendant mieux : c'est la forme finale, et il
## n'y a rien à distinguer d'un asset manquant puisqu'il n'en manque aucun.
func _monter_visuel() -> void:
	# La bâche : une bande sombre, à peine plus claire que le noir, qui n'existe
	# à l'œil que lorsqu'une torche la frôle.
	var bache := Line2D.new()
	bache.name = "Visuel"
	bache.points = PackedVector2Array([
		Vector2(-DEMI_LONGUEUR, 0.0), Vector2(DEMI_LONGUEUR, 0.0)])
	bache.width = DEMI_EPAISSEUR * 2.0
	bache.default_color = Charte.SOL_A
	bache.light_mask = MapGeometry.WALL_LAYER
	add_child(bache)

	# Le câble tendu qui la tient, sur l'arête haute : c'est lui qui accroche la
	# lumière et donne à la bande son épaisseur lisible.
	var cable := Line2D.new()
	cable.name = "Cable"
	cable.points = PackedVector2Array([
		Vector2(-DEMI_LONGUEUR, -DEMI_EPAISSEUR), Vector2(DEMI_LONGUEUR, -DEMI_EPAISSEUR)])
	cable.width = 1.5
	cable.default_color = Charte.LINE
	cable.light_mask = MapGeometry.WALL_LAYER
	add_child(cable)
