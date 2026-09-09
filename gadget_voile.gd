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


func _monter_visuel() -> void:
	var chemin := "res://assets/sprites/gadget_voile.png"
	if not ResourceLoader.exists(chemin):
		# ⚠️ Aucun repli. Un rectangle de secours donnerait une bâche plausible,
		# et une bâche plausible se prend pour une intention : on ne saurait plus
		# distinguer « l'asset manque » de « le gadget ne se pose pas ».
		push_error("GadgetVoile : sprite absent — %s" % chemin)
		return
	var s := Sprite2D.new()
	s.name = "Visuel"
	s.texture = load(chemin)
	s.light_mask = MapGeometry.WALL_LAYER
	add_child(s)
