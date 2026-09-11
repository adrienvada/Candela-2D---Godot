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
## 2. **Les hachures** : des traits NOIRS à 45°, sur le sol, le long du mur,
##    sur une bande de `HACHURE_PORTEE` px. C'est l'ombre dessinée au pied d'un
##    mur dans une planche. Noires, elles n'existent que là où le sol est
##    éclairé — dans le noir, rien ; un coup de torche, et le pied du mur se
##    hachure.
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
## Profondeur de la bande hachurée sur le sol, au pied du mur.
const HACHURE_PORTEE := 8.0
## Espacement des hachures le long du mur.
const HACHURE_PAS := 5.0
const HACHURE_LARGEUR := 1.2
const HACHURE_ALPHA := 0.7

var _boucles: Array[PackedVector2Array] = []


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
	queue_redraw()


## Les contours des masses de MURS (pas des fosses : une fosse est un vide, on
## ne la cerne pas d'un trait de mur), en pixels de monde.
static func _boucles_de(data: Dictionary) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var solide: Array = MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
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
	copy.queue_redraw()
	parent.add_child(copy)


func _draw() -> void:
	for boucle in _boucles:
		_dessiner_hachures(boucle)
	for boucle in _boucles:
		_dessiner_trait(boucle)


## Le sens « intérieur du mur » d'une arête orientée : `trace_contours` tourne
## les boucles de sorte que le solide est à DROITE de la direction (repère
## écran, y vers le bas) — une arête haute va vers +x et le mur est en dessous.
static func _interieur(dir: Vector2) -> Vector2:
	return Vector2(-dir.y, dir.x)


func _dessiner_trait(boucle: PackedVector2Array) -> void:
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
			var p := a.lerp(b, t) + dehors * (TRAIT * 0.5)
			# Aux sommets, pas de tremblement : l'angle reste franc.
			if k > 0:
				p += dehors * (_hachage(p) * 2.0 - 1.0) * TREMBLE
			pts.append(p)
	pts.append(pts[0])
	draw_polyline(pts, Charte.HALOGENE, TRAIT, false)


func _dessiner_hachures(boucle: PackedVector2Array) -> void:
	var n := boucle.size()
	if n < 3:
		return
	var encre := Color(Charte.NOIR, HACHURE_ALPHA)
	for i in n:
		var a := boucle[i]
		var b := boucle[(i + 1) % n]
		var dir := (b - a).normalized()
		var dehors := -_interieur(dir)
		var oblique := (dehors + dir).normalized()
		var longueur := a.distance_to(b)
		var d := HACHURE_PAS * 0.5
		while d < longueur - 1.0:
			var depart := a + dir * d + dehors * (TRAIT + 0.5)
			var portee := HACHURE_PORTEE * (0.7 + 0.5 * _hachage(depart))
			draw_line(depart, depart + oblique * portee, encre, HACHURE_LARGEUR)
			d += HACHURE_PAS
	# Le coin : un trait de plus dans chaque angle sortant, sinon l'angle
	# reste nu entre deux bandes.


## Hachage déterministe d'une position, dans [0, 1[. Les deux machines d'un
## match et les deux vues d'un écran scindé tracent le même mur.
static func _hachage(p: Vector2) -> float:
	var h := int(p.x * 7.0) * 73856093 ^ int(p.y * 7.0) * 19349663
	h = (h ^ (h >> 13)) & 0x7fffffff
	return float(h % 1000) / 1000.0
