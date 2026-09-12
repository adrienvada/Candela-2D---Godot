## CandelaTileSet — Génération procédurale du TileSet visuel.
## La physique des murs est gérée via MapGeometry.build_collisions()
## et non plus via les données de collision du TileSet, pour contourner
## une limitation de Godot 4 avec les TileSet entièrement générés par code.

class_name CandelaTileSet
extends RefCounted

const Charte := preload("res://charte.gd")

const TILE_SIZE    := Vector2i(35, 35)
const GRID_SIZE    := Vector2i(20, 20)
const FLOOR_ATLAS_A := Vector2i(0, 0)
const FLOOR_ATLAS_B := Vector2i(0, 1)
const WALL_ATLAS    := Vector2i(1, 0)

## ## Le sol DESSINÉ — refonte roman graphique, lot 1 (2026-09-11)
##
## Il était peint (DA2.6, choisi par Adrien le 2026-08-25 : une photo de béton
## cuite en tuiles par `tools/fabrique_tuiles.gd`, plus un grain procédural).
## Sous la torche, la plus grande surface éclairée du jeu lisait comme une
## texture, pas comme un dessin. Adrien, le 2026-09-11 : « ok » pour un aplat
## deux tons et des fissures au trait, contraste inchangé.
##
## **Le damier survit, à la même valeur.** Les dalles peintes valaient 0,148 et
## 0,178 de luminance moyenne (mesuré sur les fichiers) : ce sont les deux
## aplats `SOL_DESSIN_A` et `SOL_DESSIN_B`. Ce n'est pas de l'ornement : dans le
## noir absolu, l'alternance des cases est **la seule référence spatiale du
## joueur**, et ce lot ne la touche pas.
##
## Ce qui remplace le grain : un JOINT d'encre d'un pixel sur les QUATRE bords
## de chaque dalle (le trait qui sépare deux dalles d'une planche — sur les
## quatre, parce que `orientation()` retourne les tuiles dans les huit sens et
## qu'un joint sur deux bords seulement se dédoublerait ici et manquerait là),
## deux ou trois FISSURES au trait noir, placées par un hachage de la graine —
## donc identiques sur toutes les machines et les deux vues —, et quelques
## pores. Rien de clair : un dessin d'encre n'a pas de reflets, la torche les
## fait. Entre deux dalles, le joint fait donc deux pixels : c'est pourquoi il
## est moins noir que les fissures.
const SOL_DESSIN_A := Color(0.148, 0.148, 0.140)
const SOL_DESSIN_B := Color(0.178, 0.179, 0.168)
## Le joint et le trait des fissures, en part de noir mêlée à l'aplat.
const JOINT_ENCRE := 0.42
const FISSURE_ENCRE := 0.72
const PORE_ENCRE := 0.45

## ⚠️ **Le mur n'est PAS peint, et c'est une décision, pas un oubli.**
## Voir « Décisions actées » — DA2.7 a été mesurée puis abandonnée le
## 2026-08-25. L'intérieur du mur reste du noir pur : un mur n'est pas une
## surface éclairée, c'est une masse noire cernée d'un filament.

## Crée et retourne un TileSet visuel (damier dessiné + murs noirs).
## NB : pas de physique dans ce TileSet — voir MapGeometry.build_collisions().
static func create_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE

	var source := TileSetAtlasSource.new()

	# Atlas : 2 tiles large × 2 tiles haut = 70×70 px
	var img := Image.create_empty(TILE_SIZE.x * 2, TILE_SIZE.y * 2, false, Image.FORMAT_RGBA8)

	# --- Tiles (0,0) et (0,1) : les deux cases du damier, dessinées ---
	_generer_dalle_encre(img, 0, SOL_DESSIN_A, 101)
	_generer_dalle_encre(img, TILE_SIZE.y, SOL_DESSIN_B, 203)

	# --- Tile (1,0) : le mur, du noir pur (le contour vit dans `mur_encre.gd`) ---
	_generer_mur_atelier(img, TILE_SIZE.x, 0)

	var tex := ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = TILE_SIZE

	source.create_tile(FLOOR_ATLAS_A)
	source.create_tile(FLOOR_ATLAS_B)
	source.create_tile(WALL_ATLAS)

	ts.add_source(source, 0)
	return ts


## Hachage déterministe d'un entier, dans [0, 1[ — même famille que celui de
## `mur_encre.gd` : les deux machines d'un match dessinent la même dalle.
static func _hachage(n: int) -> float:
	var h := n * 374761393
	h = (h ^ (h >> 13)) * 1274126177
	h = (h ^ (h >> 16)) & 0x7fffffff
	return float(h % 10000) / 10000.0


## Une dalle d'encre : un aplat, un joint, des fissures au trait, des pores.
static func _generer_dalle_encre(img: Image, oy: int, aplat: Color, graine: int) -> void:
	var joint := aplat.lerp(Charte.NOIR, JOINT_ENCRE)
	var fissure := aplat.lerp(Charte.NOIR, FISSURE_ENCRE)
	var pore := aplat.lerp(Charte.NOIR, PORE_ENCRE)
	for y in range(TILE_SIZE.y):
		for x in range(TILE_SIZE.x):
			var bord := x == 0 or y == 0 or x == TILE_SIZE.x - 1 or y == TILE_SIZE.y - 1
			img.set_pixel(x, oy + y, joint if bord else aplat)

	# Les pores : un pixel sur soixante environ, jamais deux voisins — un
	# semis, pas un grain.
	for y in range(2, TILE_SIZE.y - 1, 2):
		for x in range(2, TILE_SIZE.x - 1, 2):
			if _hachage(graine * 7919 + y * 131 + x) < 0.07:
				img.set_pixel(x, oy + y, pore)

	# Les fissures : deux ou trois traits brisés qui avancent surtout en
	# DIAGONALE, par pas d'un pixel, avec un coude de temps en temps. Un trait
	# de plume qui cherche son chemin dans le béton. (Un premier jet n'avançait
	# qu'en x ou en y : des escaliers à angle droit, un circuit imprimé.)
	var nb := 2 + int(_hachage(graine) * 2.0)
	for k in nb:
		var g := graine * 31 + k * 977
		var x := 2 + int(_hachage(g) * float(TILE_SIZE.x - 4))
		var y := 2 + int(_hachage(g + 1) * float(TILE_SIZE.y - 4))
		var longueur := 8 + int(_hachage(g + 2) * 11.0)
		var dx := 1 if _hachage(g + 3) < 0.5 else -1
		var dy := 1 if _hachage(g + 4) < 0.5 else -1
		for i in longueur:
			if x < 1 or y < 1 or x >= TILE_SIZE.x - 1 or y >= TILE_SIZE.y - 1:
				break
			img.set_pixel(x, oy + y, fissure)
			var r := _hachage(g + 10 + i)
			if r < 0.55:
				x += dx
				y += dy
			elif r < 0.78:
				x += dx
			elif r < 0.93:
				y += dy
			else:
				# Le coude : la fissure change de sens une fois.
				dy = -dy


## Dessine la tuile de mur : du noir d'encre pur, sur toute la tuile.
##
## Refonte roman graphique (Adrien, 2026-09-11) : le liseré halogène de 2 px
## que chaque tuile portait sur ses quatre côtés faisait une GRILLE sur toute
## masse de murs. Le contour vit désormais dans `mur_encre.gd`, tracé autour de
## la masse et non autour de chaque tuile. La tuile n'est plus que la masse.
static func _generer_mur_atelier(img: Image, ox: int, oy: int) -> void:
	for y in range(TILE_SIZE.y):
		for x in range(TILE_SIZE.x):
			img.set_pixel(ox + x, oy + y, Charte.NOIR)

## Une des huit orientations, tirée d'un hachage de la position de la cellule.
##
## **Coût mesuré : nul.** Godot porte les transformations dans l'identifiant de
## tuile alternative — pas une texture de plus, pas une tuile alternative à
## créer, un calcul entier par cellule à la construction de la carte. Les huit
## combinaisons de `FLIP_H`, `FLIP_V` et `TRANSPOSE` sont acceptées telles
## quelles par `set_cell` (vérifié le 2026-08-25, 8 sur 8).
##
## **Le hachage est déterministe sur la position**, et il le faut : la même carte
## doit rendre le même sol sur les deux machines d'un match et d'une partie à
## l'autre. Un `randi()` donnerait un sol qui change à chaque chargement — le
## joueur perdrait le repère que le damier existe pour lui donner.
##
## Sans matière peinte, la rotation ne se voit pas : un aplat bordé est
## invariant par symétrie. Elle ne coûte donc rien non plus quand elle ne sert
## à rien.
static func orientation(cell: Vector2i) -> int:
	var h := int(cell.x) * 73856093 ^ int(cell.y) * 19349663
	h = (h ^ (h >> 13)) & 0x7fffffff
	var i := h % 8
	var alt := 0
	if i & 1:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if i & 2:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if i & 4:
		alt |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return alt


## Retourne la coordonnée atlas du sol selon la position (damier).
static func get_floor_atlas(pos: Vector2i) -> Vector2i:
	return FLOOR_ATLAS_A if (pos.x + pos.y) % 2 == 0 else FLOOR_ATLAS_B


## ⚠️ **Les murs n'ont plus de matériau, et c'est voulu** (nettoyage du
## 2026-09-11). `shimmer_murs.gdshader` (V5.8) animait le liseré halogène de
## la tuile ; depuis que la tuile est du noir pur, sa luminance vaut zéro et le
## fragment sortait `vec4(0)` sur chaque pixel — un shader compilé, posé sur les
## trois calques, et qui ne dessinait rien. Le contour vit dans `mur_encre.gd`,
## un CanvasItem ordinaire que toute Light2D éclaire à son énergie. Un matériau
## qu'on reposerait ici s'appliquerait à une masse noire : rien à animer.
