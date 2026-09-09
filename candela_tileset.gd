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

	# --- Tiles (0,0) et (0,1) : les deux cases du damier béton brut ---
	var peint_a := _tuile_peinte(SOL_A_PEINT)
	var peint_b := _tuile_peinte(SOL_B_PEINT)
	_generer_dalle_beton(img, 0, Charte.SOL_A, Charte.SOL_A_ARETE, 101, peint_a)
	_generer_dalle_beton(img, TILE_SIZE.y, Charte.SOL_B, Charte.SOL_B_ARETE, 203, peint_b)

	# --- Tile (1,0) : Mur atelier (le noir du monde + arête halogène + mobilier riveté) ---
	# Liséré halogène franc de 2 px préservé pour l'accroche de la torche,
	# intérieur sombre respectant le fondu additif, enrichi d'un dessin de
	# caisse rivetée et cornières d'acier d'atelier lourd.
	_generer_mur_atelier(img, TILE_SIZE.x, 0)

	var tex := ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = TILE_SIZE

	source.create_tile(FLOOR_ATLAS_A)
	source.create_tile(FLOOR_ATLAS_B)
	source.create_tile(WALL_ATLAS)

	ts.add_source(source, 0)
	return ts


## Génère une dalle de béton brut aux micro-aspérités d'encre contrastée.
static func _generer_dalle_beton(img: Image, oy: int, bg: Color, border: Color,
		graine: int, base_peinte: Image = null) -> void:
	if base_peinte != null:
		img.blit_rect(base_peinte, Rect2i(Vector2i.ZERO, TILE_SIZE), Vector2i(0, oy))
	else:
		for y in range(TILE_SIZE.y):
			for x in range(TILE_SIZE.x):
				var on_edge := (x == 0 or y == 0 or x == TILE_SIZE.x - 1 or y == TILE_SIZE.y - 1)
				img.set_pixel(x, oy + y, border if on_edge else bg)

	# Micro-aspérités d'encre contrastée et grain brut de béton industriel.
	# Déterministe pour que les deux écrans et toutes les machines rendent l'identique.
	for y in range(1, TILE_SIZE.y - 1):
		for x in range(1, TILE_SIZE.x - 1):
			var h := (x * 374761393 + y * 668265263 + graine * 912345671) ^ ((x * 127) + (y * 311))
			h = (h ^ (h >> 13)) & 0x7fffffff
			var pix := img.get_pixel(x, oy + y)

			# Aspérités d'encre sombre (pores du béton coulé, micro-impacts)
			if (h % 17) == 0:
				var assombri := pix.lerp(Charte.NOIR, 0.40)
				img.set_pixel(x, oy + y, assombri)
			# Micro-particules minérales claires (reflets d'aspérité sous la torche)
			elif (h % 23) == 0:
				var eclairci := pix.lerp(Charte.HALOGENE, 0.10)
				img.set_pixel(x, oy + y, eclairci)

	# Micro-fissures d'atelier discrètes (2 courtes lignes d'encre sombre par dalle)
	var f1_y := 8 + (graine % 7)
	for dx in range(4):
		var fx := 7 + dx
		var fy := oy + f1_y + (1 if dx >= 2 else 0)
		if fx < TILE_SIZE.x - 2 and fy < oy + TILE_SIZE.y - 2:
			var c := img.get_pixel(fx, fy).lerp(Charte.NOIR, 0.55)
			img.set_pixel(fx, fy, c)

	var f2_y := 20 + ((graine >> 3) % 7)
	for dx in range(5):
		var fx := 20 + dx
		var fy := oy + f2_y - (1 if dx >= 3 else 0)
		if fx < TILE_SIZE.x - 2 and fy < oy + TILE_SIZE.y - 2:
			var c := img.get_pixel(fx, fy).lerp(Charte.NOIR, 0.50)
			img.set_pixel(fx, fy, c)


## Dessine la tuile de mur d'atelier : liséré halogène franc, intérieur sombre
## avec rivets d'acier et cornières de caisse industrielle.
static func _generer_mur_atelier(img: Image, ox: int, oy: int) -> void:
	var wall_bg     := Charte.NOIR
	var wall_border := Charte.HALOGENE
	var acier_discret := Charte.LINE * 0.65
	var rivet_color   := Charte.ACIER * 0.40

	for y in range(TILE_SIZE.y):
		for x in range(TILE_SIZE.x):
			var on_outer_edge := (x <= 1 or x >= TILE_SIZE.x - 2 or y <= 1 or y >= TILE_SIZE.y - 2)
			if on_outer_edge:
				img.set_pixel(ox + x, oy + y, wall_border)
			else:
				img.set_pixel(ox + x, oy + y, wall_bg)

	# Cornières intérieures à 4 px du bord extérieur
	for y in range(4, TILE_SIZE.y - 4):
		img.set_pixel(ox + 4, oy + y, acier_discret)
		img.set_pixel(ox + TILE_SIZE.x - 5, oy + y, acier_discret)
	for x in range(4, TILE_SIZE.x - 4):
		img.set_pixel(ox + x, oy + 4, acier_discret)
		img.set_pixel(ox + x, oy + TILE_SIZE.y - 5, acier_discret)

	# 4 rivets d'acier d'atelier aux 4 angles de la cornière
	var rivets := [
		Vector2i(5, 5),
		Vector2i(TILE_SIZE.x - 6, 5),
		Vector2i(5, TILE_SIZE.y - 6),
		Vector2i(TILE_SIZE.x - 6, TILE_SIZE.y - 6)
	]
	for r in rivets:
		img.set_pixel(ox + r.x, oy + r.y, rivet_color)

	# Fines traverses diagonales en croix d'armature sombre
	for d in range(6, TILE_SIZE.x - 6):
		if d % 2 == 0:
			img.set_pixel(ox + d, oy + d, Charte.LINE * 0.35)
			img.set_pixel(ox + d, oy + (TILE_SIZE.y - 1 - d), Charte.LINE * 0.35)

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


const SHADER_SHIMMER_MURS := preload("res://shimmer_murs.gdshader")

## Crée le matériau Shader pour les murs (V5.8 — Chantier 2).
## Anime les arêtes halogènes sous le balayage de la torche avec micro-aspérités
## et spécularité en lumière rasante, tout en garantissant un noir pur absolu (Charte.NOIR)
## pour le corps du mur.
static func creer_materiau_mur() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_SHIMMER_MURS
	mat.set_shader_parameter("intensite_shimmer", 0.85)
	mat.set_shader_parameter("frequence_scintillement", 4.5)
	mat.set_shader_parameter("rugosite_arete", 8.0)
	mat.set_shader_parameter("couleur_lisere", Charte.HALOGENE)
	mat.set_shader_parameter("couleur_reflet", Charte.AMBRE)
	return mat
