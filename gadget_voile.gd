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
## ## Les sprites, et pourquoi les piquets ne se voient pas encore
##
## Cette note disait jusqu'ici qu'un sprite lisible de dessus serait un défaut de
## conception. Adrien a décidé l'inverse le 2026-09-10 : des sprites pour les
## gadgets, dont deux pour celui-ci — `gadget_voile_piquet.png` et
## `gadget_voile_toile.png`, générés par la session des menus. **Ils ne sont pas
## encore livrés.** La toile garde son trait dessiné et en prendra la texture ;
## les piquets, eux, attendent leur image — les dessiner d'ici là serait le
## « troisième chemin » que `GadgetBase._monter_visuel()` interdit.

## Demi-longueur de la toile, en pixels. Elle est LARGE et mince : c'est ce
## rapport qui en fait un obstacle de lumière et non un objet.
const DEMI_LONGUEUR := 84.0
## Demi-épaisseur de la bande qui arrête — la lumière comme les joueurs.
const DEMI_EPAISSEUR := 4.0

## L'onde de la toile, en pixels. ⚠️ **Les trois amplitudes et la demi-largeur du
## trait, additionnées, ne dépassent pas `DEMI_EPAISSEUR`** : c'est la borne qui
## garde la toile dans la bande. `tools/test_tir_et_reserves.gd` la vérifie.
const LARGEUR_TOILE := 3.0
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
var _ourlet: Line2D = null
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


## La toile, DESSINÉE : vue de dessus, une toile verticale est une ligne.
##
## ⚠️ Ce trait renversait déjà l'étape 5, qui criait « sprite absent » et ne
## montrait rien. Les sprites décidés le 2026-09-10 ne le remplacent pas : ils lui
## donneront sa texture. Les piquets, eux, attendent la leur (note de tête).
func _monter_visuel() -> void:
	# La toile : une bande sombre, à peine plus claire que le noir, qui n'existe
	# à l'œil que lorsqu'une torche la frôle.
	_toile = _ligne("Visuel", LARGEUR_TOILE, Charte.SOL_A)
	# L'ourlet, l'arête haute de la toile — ce qu'on en voit, de dessus. C'est lui
	# qui accroche la lumière. Il s'appelait « câble » et restait droit ; la toile
	# est lâche désormais, et son arête suit l'onde.
	_ourlet = _ligne("Ourlet", 1.5, Charte.LINE)
	_onduler()


func _ligne(nom: String, largeur: float, couleur: Color) -> Line2D:
	var ligne := Line2D.new()
	ligne.name = nom
	ligne.width = largeur
	ligne.default_color = couleur
	ligne.light_mask = MapGeometry.WALL_LAYER
	add_child(ligne)
	return ligne


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
	_ourlet.points = points


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
