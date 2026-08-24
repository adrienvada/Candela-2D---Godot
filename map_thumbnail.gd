## MapThumbnail — Miniatures de cartes peintes par le code.
##
## Pourquoi pas de SubViewport : une capture de viewport est asynchrone (il faut
## attendre au moins une trame rendue), fragile (elle dépend de l'état de la
## scène, du monde 2D partagé et du split-screen) et coûteuse à maintenir en
## cache sur disque. Ici on peint directement dans une `Image` à partir des
## données de la carte : le rendu est instantané, déterministe, jamais
## désynchronisé du contenu réel, et ne laisse aucun fichier derrière lui.
##
## Usage :
##   var tex := MapThumbnail.render(data)               # 4 px par tuile
##   var tex := MapThumbnail.render_fit(data, 96)       # ajusté à 96 px de côté
##   MapThumbnail.clear_cache()                         # après refresh du catalogue
##
## Le cache est indexé par `id` de carte + échelle. Une carte sans `id` n'est
## jamais mise en cache (on ne peut pas garantir son unicité).

class_name MapThumbnail
extends RefCounted

const Charte := preload("res://charte.gd")

## Palette « plan » : déclinaison lisible en petit de l'esthétique néon du jeu.
const COLOR_BACKGROUND := Color(Charte.SURFACE, 1.0)
const COLOR_FLOOR := Color(Charte.SOL_B * 0.72, 1.0)
const COLOR_WALL := Color(Charte.HALOGENE, 1.0)
const COLOR_SPAWN_P1 := Color(Charte.BLEU, 1.0)
const COLOR_SPAWN_P2 := Color(Charte.ROUGE, 1.0)

const MIN_PX_PER_TILE := 1
const MAX_PX_PER_TILE := 32
## En dessous, une apparition d'une seule tuile devient invisible.
const MIN_SPAWN_PX := 3

## Cache partagé : "id@échelle" → ImageTexture.
static var _cache: Dictionary = {}

# ---------------------------------------------------------------------------
# RENDU
# ---------------------------------------------------------------------------

## Peint une carte en texture. Retourne `null` si les données sont vides.
static func render(data: Dictionary, px_per_tile: int = 4) -> ImageTexture:
	if data.is_empty():
		return null

	var scale_px := clampi(px_per_tile, MIN_PX_PER_TILE, MAX_PX_PER_TILE)
	var map_id := String(data.get("id", ""))
	var key := "%s@%d" % [map_id, scale_px]
	if not map_id.is_empty() and _cache.has(key):
		var cached: ImageTexture = _cache[key]
		if is_instance_valid(cached):
			return cached
		_cache.erase(key)

	var grid := MapCodec.get_grid_size(data)
	var width := maxi(1, grid.x * scale_px)
	var height := maxi(1, grid.y * scale_px)

	var img := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_BACKGROUND)

	# Ordre de peinture : sol, puis murs par-dessus, puis apparitions au sommet.
	for cell in MapCodec.get_floor_cells(data):
		_paint_cell(img, cell, grid, scale_px, COLOR_FLOOR)
	for cell in MapCodec.get_wall_cells(data):
		_paint_cell(img, cell, grid, scale_px, COLOR_WALL)
	for player_index in 2:
		var spawn := MapCodec.get_spawn(data, player_index)
		if spawn.x < 0 or spawn.y < 0:
			continue
		var tint := COLOR_SPAWN_P1 if player_index == 0 else COLOR_SPAWN_P2
		_paint_marker(img, spawn, grid, scale_px, tint)

	var tex := ImageTexture.create_from_image(img)
	if not map_id.is_empty():
		_cache[key] = tex
	return tex

## Peint une carte de façon à ce que son plus grand côté approche `target_px`.
## Pratique pour une grille de tuiles à taille fixe : une carte 20×20 et une
## carte 32×32 occupent alors la même surface à l'écran.
static func render_fit(data: Dictionary, target_px: int) -> ImageTexture:
	if data.is_empty():
		return null
	var grid := MapCodec.get_grid_size(data)
	var largest := maxi(1, maxi(grid.x, grid.y))
	var scale_px := floori(float(target_px) / float(largest))
	return render(data, maxi(MIN_PX_PER_TILE, scale_px))

# ---------------------------------------------------------------------------
# CACHE
# ---------------------------------------------------------------------------

## Vide tout le cache. À appeler quand le catalogue change.
static func clear_cache() -> void:
	_cache.clear()

## Oublie les miniatures d'une seule carte, toutes échelles confondues.
static func invalidate(map_id: String) -> void:
	if map_id.is_empty():
		return
	var prefix := map_id + "@"
	for key in _cache.keys():
		if String(key).begins_with(prefix):
			_cache.erase(key)

## Nombre de miniatures actuellement en cache (diagnostic).
static func cache_size() -> int:
	return _cache.size()

# ---------------------------------------------------------------------------
# PRIVÉ
# ---------------------------------------------------------------------------

## Remplit le carré d'une cellule, en ignorant tout ce qui sort de la grille.
static func _paint_cell(img: Image, cell: Vector2i, grid: Vector2i,
		scale_px: int, tint: Color) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
		return
	img.fill_rect(Rect2i(cell.x * scale_px, cell.y * scale_px, scale_px, scale_px), tint)

## Repère d'apparition : au moins MIN_SPAWN_PX de côté, centré sur la cellule.
static func _paint_marker(img: Image, cell: Vector2i, grid: Vector2i,
		scale_px: int, tint: Color) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
		return

	var marker := maxi(scale_px, MIN_SPAWN_PX)
	var offset := (marker - scale_px) / 2
	var left := clampi(cell.x * scale_px - offset, 0, maxi(0, img.get_width() - 1))
	var top := clampi(cell.y * scale_px - offset, 0, maxi(0, img.get_height() - 1))
	var w := mini(marker, img.get_width() - left)
	var h := mini(marker, img.get_height() - top)
	if w <= 0 or h <= 0:
		return

	img.fill_rect(Rect2i(left, top, w, h), tint)
