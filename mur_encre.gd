class_name MurEncre
extends Node2D
## Les murs au TRAIT — refonte roman graphique (Adrien, 2026-09-11 : « remplace
## leur allure pour qu'ils soient en style roman graphique »).
##
## ## Ce que c'était, et pourquoi ça ne lisait pas comme un dessin
##
## Chaque tuile de mur portait un liseré halogène de 2 px sur ses QUATRE côtés,
## et un intérieur noir. Une masse de murs de plusieurs tuiles montrait donc une
## GRILLE de filets — le quadrillage des captures de killcam — là où un dessin
## d'encre trace UN contour autour de la masse et rien dedans.
##
## ## Ce que c'est
##
## Un seul nœud par arène qui dessine, depuis les contours des masses de murs
## (`MapGeometry.trace_contours`, le même tracé qui sert aux occluders) :
##
## 1. **Le trait** : un contour halogène de 3 px, posé du côté du SOL de la
##    frontière — l'occluder est en retrait de `OCCLUDER_INSET` px dans le mur,
##    au-delà tout est dans l'ombre du mur et un trait qui y passerait serait
##    noir sur noir. Le trait est légèrement irrégulier (un point tous les 7 px,
##    déplacé de ±0,7 px par un hachage de sa position, donc identique sur les
##    deux machines et d'une manche à l'autre) : un trait de plume, pas un
##    rectangle.
## 2. **Le lavis au pied** : un dégradé NOIR, de l'encre au pied du mur vers le
##    sol nu, sur `LAVIS_PORTEE` px. C'est l'ombre dessinée au pied d'un mur dans
##    une planche. Noir, il n'existe que là où le sol est éclairé — dans le noir,
##    rien ; un coup de torche, et le pied du mur s'assombrit.
##    (ISO10, 1b, 2026-09-15 : il remplace une bande de hachures à 45° — des
##    tirets à période fixe que la vue iso grossissait 2,4 fois. Voir
##    `LAVIS_PORTEE`.)
##
## Les tuiles de mur, elles, deviennent du noir pur (`candela_tileset.gd`) : la
## masse. La décision du 2026-08-25 — « un mur n'est pas une surface, c'est une
## masse cernée d'un filament » — tient toujours ; le filament cesse d'être un
## quadrillage pour devenir un contour.
##
## Même cycle de vie qu'`ArenaDecor` : un original caché qui porte la
## géométrie, une copie par vue (`_P1`, `_P2`) avec ses masques. Éclairé comme
## le décor (`light_mask` 1 + ambiance du joueur) : le trait n'apparaît que
## sous une lumière, comme le liseré qu'il remplace.

const Charte := preload("res://charte.gd")

## Épaisseur du trait de contour, en pixels de monde.
const TRAIT := 3.0
## Pas de subdivision du trait, pour le rendre irrégulier.
const PAS_TRAIT := 7.0
## Amplitude de l'irrégularité du trait, en pixels.
const TREMBLE := 0.7
## ISO10, 1b (2026-09-15) — **le pied du mur est un LAVIS, plus une bande de hachures.** Verdict de la loupe
## (tour 1) : des tirets noirs obliques à période fixe, grossis 2,4 fois en iso, que la planche du DA (face_mur_01,
## béton à coups d'encre diluée, bords diffus) n'a pas. Un dégradé continu, de l'encre au pied vers le sol nu :
## bord diffus par construction, aucune période, aucun trait à un texel. Un seul dessin pour les deux vues
## (décision de la session cloud, 16:56) : la vue de dessus change avec l'iso.
##
## Profondeur 7 px, et pas les 8 de l'ancienne bande : le lavis part de la ligne du trait (`TRAIT + 0,5`) et finit
## donc à 10,5 px du mur, avant les 12 px où les faces iso lisent leur lumière (`IsoMateriaux.PIED_FACE_PX`,
## `test_iso_beaute`). Les hachures, elles, allaient jusqu'à 13,1 px — au-delà, sans que le test le voie.
const LAVIS_PORTEE := 7.0
## L'encre au pied du mur, en alpha de noir. Plus légère que les hachures (0,7 sur un trait fin) : une surface.
const LAVIS_ALPHA := 0.45
## Le trait d'un mur BAS : 2 px au lieu de 3 (dessin gardé par Adrien, H-MB0,
## 2026-09-14). Pas de hachures au pied : le dessus du mur bas est déjà hachuré
## (`CandelaTileSet._generer_mur_bas`), et sa bande d'ombre finie viendra en MB3.
const TRAIT_BAS := 2.0

var _boucles: Array[PackedVector2Array] = []
var _boucles_bas: Array[PackedVector2Array] = []


## Construit le tracé des murs de `data` dans `parent`, avec ses deux copies.
static func build(data: Dictionary, parent: Node2D) -> MurEncre:
	for old_name in ["MurEncre", "MurEncre_P1", "MurEncre_P2"]:
		var old := parent.get_node_or_null(old_name)
		if old:
			parent.remove_child(old)
			old.queue_free()
	var mur: MurEncre = (preload("res://mur_encre.gd") as GDScript).new()
	mur.name = "MurEncre"
	mur.setup(data)
	parent.add_child(mur)
	mur._duplicate_for_player(parent, 1, 2, 1 | 16)
	mur._duplicate_for_player(parent, 2, 4, 1 | 32)
	return mur


func setup(data: Dictionary) -> void:
	z_index = 0
	visibility_layer = 1
	light_mask = 1
	_boucles = _boucles_de(data)
	_boucles_bas = _boucles_de(data, MapGeometry.Kind.LOW_WALLS)
	queue_redraw()


## Les contours des masses de MURS (pas des fosses : une fosse est un vide, on
## ne la cerne pas d'un trait de mur), en pixels de monde. `kind` : les murs
## hauts par défaut, `Kind.LOW_WALLS` pour les murs bas.
static func _boucles_de(data: Dictionary,
		kind: MapGeometry.Kind = MapGeometry.Kind.WALLS) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var solide: Array = MapGeometry.build_grid(data, kind)
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var bordure := Vector2(MapGeometry.BORDER, MapGeometry.BORDER)
	for boucle in MapGeometry.trace_contours(solide):
		var pts := PackedVector2Array()
		for p in boucle:
			pts.append((Vector2(p) - bordure) * tuile)
		out.append(pts)
	return out


func _duplicate_for_player(parent: Node2D, player_idx: int, vis_mask: int, lt_mask: int) -> void:
	var copy := duplicate() as MurEncre
	copy.name = "MurEncre_P%d" % player_idx
	copy.visibility_layer = vis_mask
	copy.light_mask = lt_mask
	# `duplicate()` ne recopie pas les variables de script (piège du 2026-08-25).
	copy._boucles = _boucles
	copy._boucles_bas = _boucles_bas
	copy.queue_redraw()
	parent.add_child(copy)


func _draw() -> void:
	for boucle in _boucles:
		_dessiner_lavis(boucle)
	for boucle in _boucles:
		_dessiner_trait(boucle)
	for boucle in _boucles_bas:
		_dessiner_trait(boucle, TRAIT_BAS)


## Le sens « intérieur du mur » d'une arête orientée : `trace_contours` tourne
## les boucles de sorte que le solide est à DROITE de la direction (repère
## écran, y vers le bas) — une arête haute va vers +x et le mur est en dessous.
static func _interieur(dir: Vector2) -> Vector2:
	return Vector2(-dir.y, dir.x)


func _dessiner_trait(boucle: PackedVector2Array, epaisseur: float = TRAIT) -> void:
	var n := boucle.size()
	if n < 3:
		return
	# Le contour décalé du côté du sol de TRAIT/2, pour rester dans la lumière,
	# puis subdivisé et tremblé.
	var pts := PackedVector2Array()
	for i in n:
		var a := boucle[i]
		var b := boucle[(i + 1) % n]
		var dir := (b - a).normalized()
		var dehors := -_interieur(dir)
		var longueur := a.distance_to(b)
		var pas := maxi(1, int(round(longueur / PAS_TRAIT)))
		for k in pas:
			var t := float(k) / float(pas)
			var p := a.lerp(b, t) + dehors * (epaisseur * 0.5)
			# Aux sommets, pas de tremblement : l'angle reste franc.
			if k > 0:
				p += dehors * (_hachage(p) * 2.0 - 1.0) * TREMBLE
			pts.append(p)
	pts.append(pts[0])
	draw_polyline(pts, Charte.HALOGENE, epaisseur, false)


## Le lavis au pied d'un contour de mur : pour chaque arête, un quadrilatère côté sol, de la ligne du trait jusqu'à
## `LAVIS_PORTEE`, encre au pied et transparent au bout (couleurs par sommet). Relu bilinéaire par la lightmap, son
## bord est diffus par construction.
##
## Les coins : le quadrilatère déborde d'une demi-portée aux deux bouts de l'arête, pour que deux arêtes voisines se
## recouvrent dans l'angle sortant au lieu de laisser un coin nu — le rôle qu'avait le « trait de plus » des
## hachures. Dans un angle rentrant, le débord passe dans la masse du mur voisin, noire : sans effet.
func _dessiner_lavis(boucle: PackedVector2Array) -> void:
	var n := boucle.size()
	if n < 3:
		return
	var pied := Color(Charte.NOIR, LAVIS_ALPHA)
	var bout := Color(Charte.NOIR, 0.0)
	for i in n:
		var a := boucle[i]
		var b := boucle[(i + 1) % n]
		var dir := (b - a).normalized()
		var dehors := -_interieur(dir)
		var depart := dehors * (TRAIT + 0.5)
		var fin := dehors * (TRAIT + 0.5 + LAVIS_PORTEE)
		var aa := a - dir * LAVIS_PORTEE * 0.5
		var bb := b + dir * LAVIS_PORTEE * 0.5
		draw_polygon(PackedVector2Array([aa + depart, bb + depart, bb + fin, aa + fin]),
			PackedColorArray([pied, pied, bout, bout]))


## Hachage déterministe d'une position, dans [0, 1[. Les deux machines d'un
## match et les deux vues d'un écran scindé tracent le même mur.
static func _hachage(p: Vector2) -> float:
	var h := int(p.x * 7.0) * 73856093 ^ int(p.y * 7.0) * 19349663
	h = (h ^ (h >> 13)) & 0x7fffffff
	return float(h % 1000) / 1000.0
