## MapGeometry — Physique et occlusion lumineuse d'une carte Candela.
##
## Le jeu se déroule dans le noir total : sans LightOccluder2D, la torche
## traverse les murs et la mécanique centrale disparaît. Ce module produit donc
## toujours les deux en même temps — collision ET occlusion — à partir des
## mêmes rectangles, pour qu'ils ne puissent jamais diverger.
##
## Trois étapes :
##   1. build_solid_grid()  cases pleines, bordure comprise
##   2. merge_rects()       fusion gloutonne en rectangles maximaux
##   3. build_collisions()  un seul StaticBody2D portant N formes + N occluders
##
## Règle de solidité : est solide toute case portant un mur, ET toute case sans
## sol. Le vide devient un mur plein — « seul le sol doit être une surface sur
## laquelle on peut marcher ». La grille déborde d'une case sur tout le pourtour
## pour fermer hermétiquement la carte : impossible de sortir par un bord.
##
## Gain : une carte 20×20 passe de ~400 StaticBody2D (un par tuile) à un seul
## corps portant une poignée de rectangles.

class_name MapGeometry
extends RefCounted

## Nom du corps unique produit par build_collisions().
const BODY_NAME := "MapCollisions"
## Retrait, en pixels, de l'occluder par rapport à la forme de collision.
## Laisse la face éclairée du mur capter la lumière — sans lui, le mur est
## dans sa propre ombre et reste invisible. La collision, elle, couvre
## toujours la tuile entière.
const OCCLUDER_INSET := 3.0
## Épaisseur, en cases, de la ceinture solide ajoutée autour de la grille.
## L'indice de grille (0, 0) correspond donc à la cellule de carte (-1, -1).
const BORDER := 1

# ---------------------------------------------------------------------------
# GRILLE DE SOLIDITÉ
# ---------------------------------------------------------------------------

## Grille booléenne de solidité. solid[x][y] == true si la case bloque.
##
## Dimensions : (grid_size + 2 × BORDER) sur chaque axe. Le décalage BORDER
## sépare les indices de grille des coordonnées de cellule de la carte :
##   cellule = indice - BORDER
static func build_solid_grid(data: Dictionary) -> Array:
	var grid := MapCodec.get_grid_size(data)
	var cells_w: int = clampi(grid.x, 1, MapCodec.MAX_GRID)
	var cells_h: int = clampi(grid.y, 1, MapCodec.MAX_GRID)

	# Les cellules hors grille déclarée sont ignorées : une carte mal formée ne
	# doit pas pouvoir percer un trou dans la ceinture de bordure.
	var floor_set := {}
	for cell in MapCodec.get_floor_cells(data):
		if cell.x >= 0 and cell.y >= 0 and cell.x < cells_w and cell.y < cells_h:
			floor_set[cell] = true

	var wall_set := {}
	for cell in MapCodec.get_wall_cells(data):
		if cell.x >= 0 and cell.y >= 0 and cell.x < cells_w and cell.y < cells_h:
			wall_set[cell] = true

	var width: int = cells_w + BORDER * 2
	var height: int = cells_h + BORDER * 2

	var solid: Array = []
	solid.resize(width)
	for ix in width:
		var column: Array[bool] = []
		column.resize(height)
		for iy in height:
			var cell := Vector2i(ix - BORDER, iy - BORDER)
			# Un mur bloque ; l'absence de sol bloque tout autant.
			column[iy] = wall_set.has(cell) or not floor_set.has(cell)
		solid[ix] = column

	return solid

# ---------------------------------------------------------------------------
# FUSION GLOUTONNE
# ---------------------------------------------------------------------------

## Fusionne les cases solides en rectangles maximaux (greedy meshing).
##
## Pour chaque case solide encore libre, on étend au maximum vers la droite,
## puis on descend ce ruban tant que la ligne entière est solide et libre.
## Les rectangles produits pavent exactement l'ensemble solide : aucun trou,
## aucun recouvrement. Coordonnées exprimées en indices de grille.
static func merge_rects(solid: Array) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []

	var width: int = solid.size()
	if width == 0:
		return rects
	var height: int = (solid[0] as Array).size()
	if height == 0:
		return rects

	# Cases déjà absorbées par un rectangle précédent.
	var used: Array = []
	used.resize(width)
	for ix in width:
		var column: Array[bool] = []
		column.resize(height)
		used[ix] = column

	# Balayage ligne par ligne : l'extension horizontale vient naturellement.
	for iy in height:
		for ix in width:
			if not solid[ix][iy] or used[ix][iy]:
				continue

			# 1. Extension horizontale maximale sur la ligne courante.
			var rect_w: int = 1
			while ix + rect_w < width and solid[ix + rect_w][iy] and not used[ix + rect_w][iy]:
				rect_w += 1

			# 2. Descente du ruban, ligne entière par ligne entière.
			var rect_h: int = 1
			while iy + rect_h < height:
				var row_free := true
				for cx in range(ix, ix + rect_w):
					if not solid[cx][iy + rect_h] or used[cx][iy + rect_h]:
						row_free = false
						break
				if not row_free:
					break
				rect_h += 1

			for cx in range(ix, ix + rect_w):
				for cy in range(iy, iy + rect_h):
					used[cx][cy] = true

			rects.append(Rect2i(ix, iy, rect_w, rect_h))

	return rects

# ---------------------------------------------------------------------------
# CONSTRUCTION DES NŒUDS
# ---------------------------------------------------------------------------

## Construit UN StaticBody2D portant N CollisionShape2D + N LightOccluder2D.
## `parent` reçoit le corps en enfant. Retourne le corps créé.
##
## Le corps reste à l'origine de `parent` : les positions sont calculées comme
## TileMapLayer.map_to_local(), donc `parent` doit partager le repère des
## calques de tuiles (typiquement le nœud Arena).
##
## Compromis assumé : on pave avec les rectangles fusionnés plutôt qu'avec les
## contours de trace_contours(). Les rectangles sont exacts pour la physique
## (RectangleShape2D, pas de polygone concave à décomposer) et suffisent à
## l'occlusion. Leur seul défaut est cosmétique : deux rectangles voisins
## partagent une arête, ce qui peut laisser filer un liseré de lumière au
## raccord selon l'angle. Les contours tracés suppriment ces coutures — la
## bascule se fera après validation visuelle, la géométrie est déjà prête.
static func build_collisions(data: Dictionary, parent: Node,
		tile_size: Vector2i = CandelaTileSet.TILE_SIZE) -> StaticBody2D:
	# Un rematch reconstruit la carte : on évacue la génération précédente.
	var previous := parent.get_node_or_null(BODY_NAME)
	if previous != null:
		# Retrait immédiat de l'arbre : queue_free() seul ne rendrait le nom
		# disponible qu'en fin de frame, et le nouveau corps hériterait d'un
		# nom suffixé que personne ne saurait retrouver.
		parent.remove_child(previous)
		previous.queue_free()

	var body := StaticBody2D.new()
	body.name = BODY_NAME
	# Couche 1 = géométrie statique. bullet.gd et les particules testent ce
	# masque : toute autre valeur rendrait les murs traversables.
	body.collision_layer = 1
	body.collision_mask = 1

	var rects := merge_rects(build_solid_grid(data))
	var cell_size := Vector2(tile_size)

	for i in rects.size():
		var rect: Rect2i = rects[i]
		# Indices de grille → repère local : on retire la bordure.
		var origin := Vector2(rect.position - Vector2i(BORDER, BORDER)) * cell_size
		var size := Vector2(rect.size) * cell_size
		var center := origin + size * 0.5

		var shape := CollisionShape2D.new()
		shape.name = "Collision%d" % i
		var box := RectangleShape2D.new()
		box.size = size
		shape.shape = box
		shape.position = center
		body.add_child(shape)

		var occluder := LightOccluder2D.new()
		occluder.name = "Occluder%d" % i
		occluder.position = center
		# occluder_light_mask laissé à sa valeur par défaut (1), comme les
		# occluders de StaticGeometry dans arena.tscn : les torches, les balles
		# et les étincelles moulinent toutes shadow_item_cull_mask & 1.
		occluder.occluder = _build_rect_occluder(size)
		body.add_child(occluder)

	parent.add_child(body)
	return body

## Polygone d'occlusion d'un rectangle centré sur l'origine du nœud.
## Sommets en coordonnées locales, sens horaire à l'écran (y vers le bas),
## identique à l'enroulement des occluders d'arena.tscn. cull_mode reste à
## CULL_DISABLED : le mur occulte des deux côtés, un joueur ne doit jamais
## voir au travers, quel que soit le côté depuis lequel il l'éclaire.
##
## L'occluder est légèrement plus petit que la forme de collision (voir
## OCCLUDER_INSET) : sans ce retrait, le mur se trouve intégralement dans sa
## propre ombre et se rend en noir sur fond noir — la torche s'arrête sur une
## limite invisible. Avec le retrait, la face éclairée du mur capte la lumière
## et fait apparaître son liseré néon. Le mur reste donc invisible dans
## l'obscurité et ne se révèle que sous le faisceau, ce qui est le
## comportement recherché.
static func _build_rect_occluder(size: Vector2) -> OccluderPolygon2D:
	# On ne retire jamais plus du quart de la dimension, pour qu'un rectangle
	# d'une seule tuile conserve un occluder représentatif.
	var inset := Vector2(
		minf(OCCLUDER_INSET, size.x * 0.25),
		minf(OCCLUDER_INSET, size.y * 0.25),
	)
	var half := size * 0.5 - inset
	var poly := OccluderPolygon2D.new()
	poly.closed = true
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	return poly

# ---------------------------------------------------------------------------
# CONTOURS
# ---------------------------------------------------------------------------

## Contours tracés des régions solides (marching squares), pour des ombres
## sans coutures. Retourne un polygone par région connexe.
##
## Coordonnées en indices de grille (le sommet (0, 0) est le coin haut-gauche
## de la case d'indice (0, 0)) : multiplier par tile_size et retirer BORDER
## pour passer dans le repère local de la carte.
##
## Convention : le solide est toujours à main droite du sens de parcours, donc
## les contours extérieurs sortent en sens horaire (y vers le bas) et les
## contours de trous en sens antihoraire — même enroulement que les occluders
## d'arena.tscn. Une région percée produit donc plusieurs polygones : son
## contour extérieur, plus un par trou. Deux régions qui ne se touchent que par
## une diagonale restent deux contours distincts (connexité 4).
##
## Non utilisé par build_collisions() pour l'instant : voir le compromis
## documenté là-bas.
static func trace_contours(solid: Array) -> Array[PackedVector2Array]:
	var contours: Array[PackedVector2Array] = []

	var width: int = solid.size()
	if width == 0:
		return contours
	var height: int = (solid[0] as Array).size()
	if height == 0:
		return contours

	# Arêtes orientées de la frontière : une case solide donne une arête par
	# côté tourné vers du vide (ou vers l'extérieur de la grille).
	var outgoing := {}
	for iy in height:
		for ix in width:
			if not solid[ix][iy]:
				continue
			if not _is_solid(solid, ix, iy - 1, width, height):
				_add_edge(outgoing, Vector2i(ix, iy), Vector2i(1, 0))
			if not _is_solid(solid, ix + 1, iy, width, height):
				_add_edge(outgoing, Vector2i(ix + 1, iy), Vector2i(0, 1))
			if not _is_solid(solid, ix, iy + 1, width, height):
				_add_edge(outgoing, Vector2i(ix + 1, iy + 1), Vector2i(-1, 0))
			if not _is_solid(solid, ix - 1, iy, width, height):
				_add_edge(outgoing, Vector2i(ix, iy + 1), Vector2i(0, -1))

	# Chaînage des arêtes en boucles fermées. keys() est une copie : on peut
	# consommer le dictionnaire pendant le parcours.
	for start: Vector2i in outgoing.keys():
		while outgoing.has(start):
			var loop := _walk_loop(outgoing, start)
			if loop.size() >= 3:
				contours.append(loop)

	return contours

static func _is_solid(solid: Array, ix: int, iy: int, width: int, height: int) -> bool:
	# Hors grille = vide : la frontière extérieure doit se refermer.
	if ix < 0 or iy < 0 or ix >= width or iy >= height:
		return false
	return solid[ix][iy]

static func _add_edge(outgoing: Dictionary, point: Vector2i, dir: Vector2i) -> void:
	if not outgoing.has(point):
		var fresh: Array[Vector2i] = []
		outgoing[point] = fresh
	var list: Array[Vector2i] = outgoing[point]
	list.append(dir)

## Consomme une arête sortante de `point`. `incoming` est la direction par
## laquelle on est arrivé (ZERO pour un départ de boucle).
static func _take_edge(outgoing: Dictionary, point: Vector2i, incoming: Vector2i) -> Vector2i:
	if not outgoing.has(point):
		return Vector2i.ZERO

	var list: Array[Vector2i] = outgoing[point]
	if list.is_empty():
		outgoing.erase(point)
		return Vector2i.ZERO

	if incoming != Vector2i.ZERO:
		# Sommet ambigu (deux solides en diagonale) : on privilégie le virage
		# vers le solide, puis tout droit, puis le virage vers le vide. Les
		# deux régions restent ainsi séparées au lieu de fusionner.
		var toward_solid := Vector2i(-incoming.y, incoming.x)
		var preferred: Array[Vector2i] = [toward_solid, incoming, -toward_solid]
		for wanted: Vector2i in preferred:
			var idx := list.find(wanted)
			if idx >= 0:
				list.remove_at(idx)
				if list.is_empty():
					outgoing.erase(point)
				return wanted

	var first: Vector2i = list[0]
	list.remove_at(0)
	if list.is_empty():
		outgoing.erase(point)
	return first

## Suit les arêtes depuis `start` jusqu'au retour au point de départ.
## Chaque tour consomme une arête : la boucle termine toujours.
static func _walk_loop(outgoing: Dictionary, start: Vector2i) -> PackedVector2Array:
	var points: Array[Vector2i] = []
	var point := start
	var dir := _take_edge(outgoing, point, Vector2i.ZERO)

	while dir != Vector2i.ZERO:
		points.append(point)
		point += dir
		if point == start:
			break
		dir = _take_edge(outgoing, point, dir)

	return _to_polygon(points)

## Convertit une suite de sommets en polygone, sans les sommets alignés :
## chaque arête faisant exactement une case, deux pas identiques consécutifs
## signalent un sommet inutile.
static func _to_polygon(points: Array[Vector2i]) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var count := points.size()
	if count < 3:
		return polygon

	for i in count:
		var previous: Vector2i = points[(i - 1 + count) % count]
		var current: Vector2i = points[i]
		var following: Vector2i = points[(i + 1) % count]
		if current - previous == following - current:
			continue
		polygon.append(Vector2(current))

	return polygon
