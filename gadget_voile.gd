class_name GadgetVoile
extends GadgetBase

## Le voile — gadget du Spectre, chantier CLASSES, étapes 5 et 25.
##
## Une toile entre deux piquets, tendue mais pas trop. **Elle arrête la lumière
## et les joueurs ; les balles la traversent** — en la déchirant, et deux y
## suffisent.
##
## ## Ce qu'Adrien en a fait le 2026-09-10
##
## *« Il a deux piquets sur les côtés qui le tiennent, et au milieu un voile
## tendu, mais pas trop : il pourrait onduler un peu, avoir un peu de physique.
## On ne peut pas passer au travers. »* Jusque-là les joueurs le traversaient :
## il n'était qu'un écran de lumière. Il devient un obstacle qu'on ne franchit
## qu'en le crevant — et toujours pas un mur, puisque la balle passe. Adrien a
## tranché le même jour que cette différence-là restait.
##
## ⚠️ **Il peut donc fermer un couloir**, jusqu'à ce que deux balles le crèvent.
## Un seul par joueur à la fois, et une minute de recharge (étape 24).
##
## ## Ce qui ondule, et ce qui n'ondule pas
##
## La TOILE ondule, rien d'autre. La collision et l'occluder restent une bande
## droite de `2 × DEMI_EPAISSEUR` : ils décident de ce qui se SIMULE — qui passe,
## qui voit qui —, et chaque pair doit avoir exactement la même. L'onde n'a pas
## cette exigence, personne ne compare deux écrans : elle court sur un temps
## local. Elle reste en revanche bornée DANS la bande, pour que ce qu'on voit ne
## dépasse jamais ce qui arrête.
##
## ## Les sprites
##
## Cette note disait jusqu'à l'étape 25 qu'un sprite lisible de dessus serait un
## défaut de conception. Adrien a décidé l'inverse le 2026-09-10 : deux pièces,
## générées par la session des menus. La TOILE est la texture du trait qui ondule
## (`gadget_voile_toile.png`, 168 × 8, étirée d'un piquet à l'autre) ; les deux
## PIQUETS sont des sprites fixes posés aux bouts (`gadget_voile_piquet.png`).

## Demi-longueur de la toile, en pixels. Elle est LARGE et mince : c'est ce
## rapport qui en fait un obstacle de lumière et non un objet.
const DEMI_LONGUEUR := 84.0
## Demi-épaisseur de la bande qui arrête — la lumière comme les joueurs.
##
## ⚠️ **6,5 et non plus 4, depuis l'étape 26 — décision d'Adrien.** La toile
## peinte fait 8 px de haut ; dans une bande de 8, l'onde n'avait plus de place.
## Le choix était d'épaissir la bande, d'onduler d'un pixel, ou de laisser la
## toile dépasser de ce qui arrête : Adrien a épaissi.
const DEMI_EPAISSEUR := 6.5

## L'onde de la toile, en pixels. ⚠️ **Les trois amplitudes et la demi-largeur du
## trait, additionnées, ne dépassent pas `DEMI_EPAISSEUR`** : c'est la borne qui
## garde la toile dans la bande. `tools/test_tir_et_reserves.gd` la vérifie.
## La hauteur de l'image de la toile : le trait la porte à sa taille peinte.
const LARGEUR_TOILE := 8.0
## Le mou : la toile pend un peu, même sans vent.
const CREUX := 1.0
## L'ondulation qui court le long de la toile.
const ONDULATION := 0.75
## Le frisson qu'une balle y laisse en passant, au plus.
const SECOUSSE_MAX := 0.75
const PERIODE_ONDULATION := 1.7
## Vitesse à laquelle le frisson s'éteint, par seconde : au bout d'un tiers de
## seconde, il en reste un cinquième.
const AMORTI_SECOUSSE := 5.0
const POINTS_TOILE := 17

var _toile: Line2D = null
## Le temps LOCAL de l'onde. Pas `age()` : l'onde n'est pas de la simulation.
var _temps: float = 0.0
var _secousse: float = 0.0


func _init() -> void:
	# La balle la déchire et poursuit. C'est TOUT ce qui distingue ce gadget
	# d'un mur, et c'est la ligne à ne pas « simplifier ».
	arrete_les_balles = false
	# Un joueur, lui, s'y arrête — décision d'Adrien, 2026-09-10.
	arrete_les_joueurs = true
	eblouit = false
	pv = 2.0
	# En travers du regard, comme la valeur par défaut du socle : une bâche
	# plantée DANS l'axe où l'on vise ne masque rien du tout.
	angle_pose = PI / 2.0
	# ⚠️ `rayon` n'est PAS réglé. Il valait `DEMI_LONGUEUR`, et le socle en
	# faisait un DISQUE de collision de 84 px autour d'une ombre de 8 px
	# d'épaisseur — voir `_forme_de_collision()`.


## La bande, la même que l'occluder au pixel près : c'est elle qui arrête le
## joueur, que la balle touche, et que le rayon d'éblouissement heurte.
##
## ⚠️ **C'était un disque de 84 px de rayon jusqu'au 2026-09-10**, hérité du
## socle : une balle déchirait la toile en passant à 84 px d'elle, et
## l'éblouissement butait sur un disque que rien ne montrait. Muet tant que la
## forme ne servait qu'aux balles ; intenable dès qu'elle arrête les joueurs.
func _forme_de_collision() -> Shape2D:
	var bande := RectangleShape2D.new()
	bande.size = Vector2(DEMI_LONGUEUR, DEMI_EPAISSEUR) * 2.0
	return bande


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


## La toile, un trait qui ondule et porte l'image de la toile ; les piquets, deux
## sprites fixes aux bouts.
##
## L'« ourlet » dessiné de l'étape 25 — un trait clair sur l'arête — a disparu :
## l'image porte déjà son bord et sa couture, et le redoubler l'aurait souligné.
func _monter_visuel() -> void:
	var texture := _texture_de("voile_toile")
	if texture == null:
		return
	_toile = Line2D.new()
	_toile.name = "Visuel"
	_toile.width = LARGEUR_TOILE
	_toile.texture = texture
	# Étirée d'un piquet à l'autre, pas répétée : l'image fait déjà 168 px.
	_toile.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_toile.default_color = Color.WHITE
	# Éclairée comme le décor : elle n'existe à l'œil que lorsqu'une torche la frôle.
	_toile.light_mask = MapGeometry.WALL_LAYER
	add_child(_toile)
	_onduler()
	# Les piquets APRÈS la toile, donc dessinés par-dessus : ce sont eux qui la
	# tiennent, et ses deux bouts disparaissent sous eux.
	for cote in [-1.0, 1.0]:
		var piquet := _poser_sprite("PiquetG" if cote < 0.0 else "PiquetD", "voile_piquet")
		if piquet != null:
			piquet.position = Vector2(cote * DEMI_LONGUEUR, 0.0)


func _process(delta: float) -> void:
	_temps += delta
	_secousse *= exp(-AMORTI_SECOUSSE * delta)
	_onduler()


func _onduler() -> void:
	if _toile == null:
		return
	var points := PackedVector2Array()
	points.resize(POINTS_TOILE)
	for i in POINTS_TOILE:
		var u := float(i) / float(POINTS_TOILE - 1)
		points[i] = Vector2(lerpf(-DEMI_LONGUEUR, DEMI_LONGUEUR, u),
			decalage(u, _temps, _secousse))
	_toile.points = points


## Le décalage de la toile, en travers, au point `u` — 0 et 1 sont les piquets.
##
## L'enveloppe `sin(πu)` le tient à ZÉRO aux deux bouts : les piquets ne bougent
## pas, c'est la toile entre eux qui vit.
static func decalage(u: float, t: float, secousse: float) -> float:
	var onde := ONDULATION * sin(TAU * (1.5 * u - t / PERIODE_ONDULATION))
	var frisson := secousse * sin(TAU * 3.0 * u - t * 40.0)
	return sin(PI * u) * (CREUX + onde + frisson)


## Une balle vient de la traverser : la toile bat.
func secouer() -> void:
	_secousse = SECOUSSE_MAX
