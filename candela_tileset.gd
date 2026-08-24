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

## ## Le sol peint (DA2.6)
##
## Choisi par Adrien le 2026-08-25 dans `tools/apercu_matiere.tscn` : variante 1,
## damier « faible ». Cuit par `tools/fabrique_tuiles.gd` depuis
## `assets/sources/floor_tiles/F1_01.jpg`, qui est versionnée pour qu'on puisse
## recuire.
##
## **Le damier survit, affaibli.** Il opposait 0,111 à 0,231 de luminance ; il
## oppose désormais 0,148 à 0,178. Ce n'est pas de l'ornement : dans le noir
## absolu, l'alternance des cases est **la seule référence spatiale du joueur**.
## Adrien l'a trouvée trop criarde une fois la matière ajoutée — le grain donne
## maintenant une partie de l'information que le contraste portait seul.
##
## Si les fichiers manquent, le damier procédural reprend la main. C'est un repli
## DISCERNABLE : deux aplats au lieu d'une matière, personne ne s'y trompe.
const SOL_A_PEINT := "res://assets/tuiles/solA_faible_1.png"
const SOL_B_PEINT := "res://assets/tuiles/solB_faible_1.png"

## ⚠️ **Le mur n'est PAS peint, et c'est une décision, pas un oubli.**
## Voir « Décisions actées » — DA2.7 a été mesurée puis abandonnée le
## 2026-08-25. L'intérieur du mur reste du noir pur : un mur n'est pas une
## surface éclairée, c'est une masse noire cernée d'un filament.

## Crée et retourne un TileSet visuel (damier + murs noirs bordure blanche).
## NB : pas de physique dans ce TileSet — voir MapGeometry.build_collisions().
static func create_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE

	var source := TileSetAtlasSource.new()

	# Atlas : 2 tiles large × 2 tiles haut = 70×70 px
	var img := Image.create_empty(TILE_SIZE.x * 2, TILE_SIZE.y * 2, false, Image.FORMAT_RGBA8)

	# --- Tiles (0,0) et (0,1) : les deux cases du damier ---
	var peint_a := _tuile_peinte(SOL_A_PEINT)
	var peint_b := _tuile_peinte(SOL_B_PEINT)
	if peint_a != null and peint_b != null:
		img.blit_rect(peint_a, Rect2i(Vector2i.ZERO, TILE_SIZE), Vector2i(0, 0))
		img.blit_rect(peint_b, Rect2i(Vector2i.ZERO, TILE_SIZE), Vector2i(0, TILE_SIZE.y))
	else:
		var floor_a_bg     := Charte.SOL_A
		var floor_a_border := Charte.SOL_A_ARETE
		for y in range(TILE_SIZE.y):
			for x in range(TILE_SIZE.x):
				var on_edge := (x == 0 or y == 0 or x == TILE_SIZE.x - 1 or y == TILE_SIZE.y - 1)
				img.set_pixel(x, y, floor_a_border if on_edge else floor_a_bg)
		var floor_b_bg     := Charte.SOL_B
		var floor_b_border := Charte.SOL_B_ARETE
		var oy := TILE_SIZE.y
		for y in range(TILE_SIZE.y):
			for x in range(TILE_SIZE.x):
				var on_edge := (x == 0 or y == 0 or x == TILE_SIZE.x - 1 or y == TILE_SIZE.y - 1)
				img.set_pixel(x, oy + y, floor_b_border if on_edge else floor_b_bg)

	# --- Tile (1,0) : Mur (le noir du monde + une arête que la torche accroche) ---
	#
	# **L'arête était `Color(1, 1, 1)`, et c'était le blanc pur le plus visible du
	# jeu** : on ne voit presque rien d'autre que ces bordures pendant une manche.
	# Un blanc pur ne dit pas « lumière », il dit « aucune décision n'a été prise
	# ici » — et il donnait au décor une température de néon dans un jeu éclairé à
	# la lampe torche. `HALOGENE` rend l'arête au filament qui l'éclaire.
	var wall_bg     := Charte.NOIR
	var wall_border := Charte.HALOGENE
	var ox := TILE_SIZE.x
	for y in range(TILE_SIZE.y):
		for x in range(TILE_SIZE.x):
			var on_edge := (x <= 1 or x >= TILE_SIZE.x - 2 or y <= 1 or y >= TILE_SIZE.y - 2)
			img.set_pixel(ox + x, y, wall_border if on_edge else wall_bg)

	var tex := ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = TILE_SIZE

	source.create_tile(FLOOR_ATLAS_A)
	source.create_tile(FLOOR_ATLAS_B)
	source.create_tile(WALL_ATLAS)

	ts.add_source(source, 0)
	return ts

## Charge une tuile peinte, ou rend `null` si elle n'a pas été cuite ou importée.
static func _tuile_peinte(chemin: String) -> Image:
	if not ResourceLoader.exists(chemin):
		return null
	var t: Texture2D = load(chemin)
	var img := t.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_width() != TILE_SIZE.x or img.get_height() != TILE_SIZE.y:
		push_error("CandelaTileSet : %s fait %dx%d, attendu %dx%d"
			% [chemin, img.get_width(), img.get_height(), TILE_SIZE.x, TILE_SIZE.y])
		return null
	return img


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
