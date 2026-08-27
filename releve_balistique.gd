## Le relevé balistique de la killcam — DA4.6.
##
## **La trajectoire se trace AVANT que l'action reprenne**, comme l'analyse d'une
## action de football : on retrace d'abord le trajet, puis on rejoue le geste et
## l'on voit le ballon suivre exactement la ligne annoncée. Demandé par Adrien le
## 2026-08-27.
##
## ⚠️ **L'ordre est tout le propos, et il n'est pas décoratif.** Un tracé qui suit
## la balle ne fait que *constater* ; un tracé qui la précède **annonce**, et
## l'action qui suit devient une vérification. C'est la différence entre montrer
## ce qui s'est passé et faire comprendre pourquoi c'était imparable — la
## « killcam-professeur » que l'item DA4.6 nomme sans dire comment l'obtenir.
##
## ## Pourquoi ce n'est plus la balle qui dessine
##
## Le premier jet mettait le relevé dans `bullet.gd`, sous `is_replay`. Il ne
## pouvait pas faire ce que demande l'ordre inverse : **une balle ne sait pas où
## elle va**. Elle connaît son point de départ et sa direction, jamais son
## impact — c'est le rejeu qui le sait, par `ReplaySystem.trajectoire_fatale()`.
##
## Le relevé est donc un objet à part, et il en tire deux propriétés que la balle
## ne pouvait pas avoir : il existe **avant** elle, et il **reste** après son
## passage. La balle, elle, garde sa traînée pointillée de V6.2 — celle qui suit,
## et qui n'a jamais prétendu annoncer quoi que ce soit.
##
## ## Les deux temps
##
## 1. **Le pré-tracé** — le rejeu est suspendu (`ReplaySystem`), et la ligne
##    pousse de l'origine vers l'impact en un tiers de seconde de temps RÉEL. La
##    cote grandit avec elle : le nombre monte pendant que le trait avance.
## 2. **L'action** — la ligne reste, entière et atténuée ; la balle la parcourt
##    au ralenti. C'est là que le joueur vérifie.

class_name ReleveBalistique
extends Node2D

const Charte := preload("res://charte.gd")
const Echelle := preload("res://echelle.gd")

## L'objet mesuré : plus discret que son annotation.
const TRACE_COULEUR := Color(Charte.HALOGENE, 0.35)
## L'annotation lit plus franc que l'objet — c'est ce qui la distingue d'un
## second trajet.
const COTE_COULEUR := Color(Charte.HALOGENE, 0.62)

## Écart entre deux chevrons, en pixels **monde**.
##
## ⚠️ **Monde, et pas écran, contrairement à tout le reste de l'annotation.** Leur
## densité à l'écran devient alors proportionnelle à la distance réellement
## parcourue : c'est ce qu'un relevé doit dire. Voir la note de `_draw()`.
const CHEVRON_PAS := 46.0
## Garde-fou : une portée aberrante ne doit pas faire boucler `_draw`.
const CHEVRON_MAX := 48

# Dimensions d'annotation, en pixels **écran** : multipliées par 1/zoom.
const CHEVRON_L := 8.0
const CHEVRON_H := 5.5
const COTE_ECART := 26.0
const COTE_DEBORD := 6.0
const COTE_PATTE := 5.0
const COTE_TEXTE_AIR := 5.0
## En deçà, une cote est du bruit : le trait ne tient pas ses propres obliques.
const COTE_MINIMUM := 64.0

## Ce qu'il reste de vivacité une fois l'action reprise. Le relevé ne disparaît
## pas — le joueur doit pouvoir comparer la balle à la ligne — mais il cesse
## d'être le sujet.
const ATTENUATION := 0.55

var origine: Vector2 = Vector2.ZERO
var impact: Vector2 = Vector2.ZERO
## 0 pendant que la ligne pousse, 1 quand elle est entière.
var progression: float = 0.0
## Vrai une fois l'action reprise : le relevé s'atténue et cesse de grandir.
var en_arriere_plan: bool = false


func _ready() -> void:
	# Additif non éclairé, comme la traînée de `bullet.gd` : sans quoi le
	# `CanvasModulate` noir de l'arène avale le trait.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 9
	top_level = true


## Arme le relevé sur une trajectoire. Rend `false` si elle n'en est pas une.
func poser(depart: Vector2, arrivee: Vector2) -> bool:
	if depart.distance_to(arrivee) < 1.0:
		return false
	origine = depart
	impact = arrivee
	progression = 0.0
	en_arriere_plan = false
	global_position = depart
	rotation = (arrivee - depart).angle()
	queue_redraw()
	return true


## Fait avancer le pré-tracé. `t` va de 0 à 1.
func avancer(t: float) -> void:
	var neuf := clampf(t, 0.0, 1.0)
	if is_equal_approx(neuf, progression):
		return
	progression = neuf
	queue_redraw()


## L'action reprend : la ligne reste, entière, et passe derrière.
func passer_derriere() -> void:
	if en_arriere_plan:
		return
	en_arriere_plan = true
	progression = 1.0
	queue_redraw()


## Le zoom de la caméra qui regarde ce relevé, ou 1,0 si personne ne regarde.
##
## ⚠️ **Lu sur le viewport, jamais demandé à `GameState`.** En écran scindé chaque
## vue a sa propre caméra : demander « le » zoom n'aurait même pas de sens.
func _zoom_de_la_vue() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var cam := vp.get_camera_2d()
	if cam == null:
		return 1.0
	return maxf(0.05, minf(cam.zoom.x, cam.zoom.y))


## La géométrie complète du relevé, en espace local — l'origine du trajet est en
## `-portee`, la tête du tracé en zéro.
##
## ⚠️ **Ce calcul a un nom parce qu'un `_draw()` n'en a pas.** Rien ne peut
## mesurer une cote dessinée : il faudrait tuer un joueur, lancer une killcam et
## lire des pixels au bon instant. `tools/test_releve_balistique.gd` s'y branche.
##
## ⚠️ **Tout ce qui est ANNOTATION se compense du zoom ; ce qui est GÉOMÉTRIE suit
## le monde.** La caméra de killcam va de 0,7× à 2,8× — un facteur quatre. Une
## cote posée en pixels locaux serait illisible à 8 px au dézoom et grosse comme
## un titre au zoom serré, sur le même tir. Sixième occurrence du motif du
## 2026-08-19 : *une valeur absolue là où il fallait un rapport*.
static func geometrie_du_releve(portee: float, zoom: float,
		angle: float) -> Dictionary:
	var k := 1.0 / maxf(zoom, 0.05)
	var depart := Vector2(-portee, 0.0)

	var chevrons: Array[Vector2] = []
	var n := int(portee / CHEVRON_PAS)
	for i in range(1, mini(n, CHEVRON_MAX) + 1):
		chevrons.append(Vector2(-portee + float(i) * CHEVRON_PAS, 0.0))

	# ⚠️ **De quel côté du trait poser la cote ?** Toujours du côté qui est EN
	# HAUT à l'écran, quel que soit le sens du tir — sinon la cote passe sous le
	# trait dès qu'on tire vers la gauche, et le relevé se retourne en cours de
	# killcam. On demande donc au monde, pas au repère local.
	var s := 1.0 if Vector2(0.0, -1.0).rotated(angle).y > 0.0 else -1.0
	var ecart := s * COTE_ECART * k
	var cote_a := depart + Vector2(0.0, ecart)
	var cote_b := Vector2(0.0, ecart)
	var debord := Vector2(0.0, s * COTE_DEBORD * k)

	# Les obliques ISO : un trait à 45° traversant la ligne de cote à chaque
	# extrémité.
	var oblique := (Vector2.RIGHT + Vector2(0.0, s)).normalized() \
		* (COTE_PATTE * k)

	return {
		"trace": [depart, Vector2.ZERO],
		"chevrons": chevrons,
		"chevron_l": CHEVRON_L * k,
		"chevron_h": CHEVRON_H * k,
		"cote": [cote_a, cote_b],
		"attaches": [
			[depart, cote_a + debord],
			[Vector2.ZERO, cote_b + debord],
		],
		"obliques": [
			[cote_a - oblique, cote_a + oblique],
			[cote_b - oblique, cote_b + oblique],
		],
		"ancre_texte": (cote_a + cote_b) * 0.5
			+ Vector2(0.0, s * COTE_TEXTE_AIR * k),
		"epaisseur": maxf(1.0, 1.4 * k),
		"cote_visible": portee >= COTE_MINIMUM,
		"echelle_texte": k,
	}


func _draw() -> void:
	var totale := origine.distance_to(impact)
	var portee := totale * progression
	if portee < 4.0:
		return

	# ⚠️ **Le nœud est à l'ORIGINE et la géométrie part de `-portee`** : la tête
	# du tracé tomberait donc derrière le point de départ. On décale le dessin
	# de la portée courante pour que la ligne POUSSE vers l'impact au lieu de
	# reculer depuis lui.
	draw_set_transform(Vector2(portee, 0.0), 0.0, Vector2.ONE)

	var g := geometrie_du_releve(portee, _zoom_de_la_vue(), rotation)
	var a := ATTENUATION if en_arriere_plan else 1.0
	var e: float = g["epaisseur"]
	var trace: Array = g["trace"]
	var c_trace := Color(TRACE_COULEUR, TRACE_COULEUR.a * a)
	var c_cote := Color(COTE_COULEUR, COTE_COULEUR.a * a)

	draw_dashed_line(trace[0], trace[1], c_trace, e * 1.4, 12.0)

	var cl: float = g["chevron_l"]
	var ch: float = g["chevron_h"]
	for p: Vector2 in g["chevrons"]:
		draw_polyline(PackedVector2Array([
			p + Vector2(-cl, -ch), p, p + Vector2(-cl, ch),
		]), c_cote, e)

	if not g["cote_visible"]:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var cote: Array = g["cote"]
	draw_line(cote[0], cote[1], c_cote, e)
	for paire: Array in g["attaches"]:
		draw_line(paire[0], paire[1], c_cote, e * 0.7)
	for paire: Array in g["obliques"]:
		draw_line(paire[0], paire[1], c_cote, e)

	_draw_cote(g, portee, Vector2(portee, 0.0), c_cote)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## La valeur de la cote, à l'horizontale et à taille d'écran constante.
##
## ⚠️ **La contre-rotation ET la contre-échelle passent par `draw_set_transform`,
## et pas par une taille de fonte calculée.** Godot rastérise un glyphe à la
## taille entière qu'on demande : passer `T_MENTION / zoom` donnerait 4 px à
## 2,8×, agrandis ensuite par la caméra — un texte en escalier. Ici le glyphe est
## gravé à sa taille finale d'écran, puis la transformation l'y ramène : les deux
## facteurs s'annulent et le rendu est net à tous les zooms.
func _draw_cote(g: Dictionary, portee: float, decalage: Vector2,
		couleur: Color) -> void:
	var f := Charte.police_ui(Charte.POIDS_APPUI)
	if f == null:
		return
	# ⚠️ **En mètres, pas en pixels.** « 340 PX » est exact et ne se raconte pas ;
	# voir `echelle.gd` pour l'ancre — la taille du sprite d'un joueur, décidée
	# par Adrien le 2026-08-27.
	var texte := Echelle.ecrire(portee)
	var largeur := f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Charte.T_MENTION).x
	var k: float = g["echelle_texte"]
	draw_set_transform(decalage + (g["ancre_texte"] as Vector2), -rotation,
		Vector2(k, k))
	draw_string(f, Vector2(-largeur * 0.5, 0.0), texte,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Charte.T_MENTION, couleur)
	# On rend la transformation au décalage du tracé, pas à l'identité : `_draw`
	# continue de dessiner dans ce repère après cet appel.
	draw_set_transform(decalage, 0.0, Vector2.ONE)
