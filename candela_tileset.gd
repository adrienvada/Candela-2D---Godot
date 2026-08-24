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

## Crée et retourne un TileSet visuel (damier + murs noirs bordure blanche).
## NB : pas de physique dans ce TileSet — voir MapGeometry.build_collisions().
static func create_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE

	var source := TileSetAtlasSource.new()

	# Atlas : 2 tiles large × 2 tiles haut = 70×70 px
	var img := Image.create_empty(TILE_SIZE.x * 2, TILE_SIZE.y * 2, false, Image.FORMAT_RGBA8)

	# --- Tile (0,0) : Sol A (case sombre du damier) ---
	var floor_a_bg     := Charte.SOL_A
	var floor_a_border := Charte.SOL_A_ARETE
	for y in range(TILE_SIZE.y):
		for x in range(TILE_SIZE.x):
			var on_edge := (x == 0 or y == 0 or x == TILE_SIZE.x - 1 or y == TILE_SIZE.y - 1)
			img.set_pixel(x, y, floor_a_border if on_edge else floor_a_bg)

	# --- Tile (0,1) : Sol B (case claire du damier) ---
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

## Retourne la coordonnée atlas du sol selon la position (damier).
static func get_floor_atlas(pos: Vector2i) -> Vector2i:
	return FLOOR_ATLAS_A if (pos.x + pos.y) % 2 == 0 else FLOOR_ATLAS_B
