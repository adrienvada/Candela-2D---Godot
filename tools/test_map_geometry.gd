## Test headless de la géométrie de carte (collisions + occlusion lumineuse).
## Lancer : godot --headless --path . --script res://tools/test_map_geometry.gd
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test MapGeometry ===")

	_test_solid_grid()
	_test_merge_exact_cover()
	_test_merge_count_default_map()
	_test_build_collisions()
	_test_edge_cases()
	_test_contours()
	_test_occluder_inset_keeps_collision_intact()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

# ---------------------------------------------------------------------------
# CARTES D'ESSAI
# ---------------------------------------------------------------------------

## Carte livrée avec le jeu (20×20, 256 sols, 144 murs).
func _default_map() -> Dictionary:
	var file := FileAccess.open("res://assets/maps/default.json", FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parsed := json.parse(file.get_as_text())
	file.close()
	if parsed != OK:
		return {}
	var result := MapCodec.validate(json.data as Dictionary)
	return result["data"] if result["ok"] else {}

## Sol plein sur toute la grille, murs éventuels ajoutés par l'appelant.
func _open_map(grid: Vector2i) -> Dictionary:
	var cells: Array[Vector2i] = []
	for y in grid.y:
		for x in grid.x:
			cells.append(Vector2i(x, y))
	var map := MapCodec.new_map("Essai", grid)
	map["floor"] = MapCodec.encode_runs(cells)
	return map

# ---------------------------------------------------------------------------
# GRILLE DE SOLIDITÉ
# ---------------------------------------------------------------------------

func _test_solid_grid() -> void:
	print("\n[Grille de solidité]")

	var map := _open_map(Vector2i(10, 10))
	# On perce un trou dans le sol et on pose un mur au milieu.
	var floor_cells := MapCodec.get_floor_cells(map)
	floor_cells.erase(Vector2i(3, 3))
	map["floor"] = MapCodec.encode_runs(floor_cells)
	var single_wall: Array[Vector2i] = [Vector2i(5, 5)]
	map["walls"] = MapCodec.encode_runs(single_wall)

	var solid := MapGeometry.build_solid_grid(map)
	var b := MapGeometry.BORDER

	_check("dimensions = grille + bordure", solid.size() == 12 and (solid[0] as Array).size() == 12,
		"%d×%d" % [solid.size(), (solid[0] as Array).size()])
	_check("sol → traversable", not solid[b + 1][b + 1])
	_check("mur sur du sol → solide", solid[b + 5][b + 5])
	_check("sol absent → solide (le vide est un mur)", solid[b + 3][b + 3])

	var border_sealed := true
	for i in solid.size():
		if not solid[i][0] or not solid[i][11] or not solid[0][i] or not solid[11][i]:
			border_sealed = false
			break
	_check("bordure hermétique sur les quatre côtés", border_sealed)

	# Carte sans aucun sol : tout doit bloquer.
	var barren := MapCodec.new_map("Sans sol", Vector2i(8, 8))
	var barren_solid := MapGeometry.build_solid_grid(barren)
	var all_solid := true
	for ix in barren_solid.size():
		for iy in (barren_solid[ix] as Array).size():
			if not barren_solid[ix][iy]:
				all_solid = false
				break
	_check("carte sans sol → 100 % solide", all_solid)

	# Une cellule déclarée hors grille ne doit pas ouvrir la bordure.
	var overflow := _open_map(Vector2i(8, 8))
	var overflow_cells := MapCodec.get_floor_cells(overflow)
	overflow_cells.append(Vector2i(30, 30))
	overflow["floor"] = MapCodec.encode_runs(overflow_cells)
	var overflow_solid := MapGeometry.build_solid_grid(overflow)
	_check("cellule hors grille ignorée", overflow_solid.size() == 10,
		"%d colonnes" % overflow_solid.size())

# ---------------------------------------------------------------------------
# FUSION — LE TEST QUI COMPTE
# ---------------------------------------------------------------------------

## Vérifie case par case que les rectangles pavent exactement l'ensemble solide.
## Retourne le nombre de rectangles produits.
func _assert_exact_cover(label: String, solid: Array) -> int:
	var rects := MapGeometry.merge_rects(solid)
	var width: int = solid.size()
	var height: int = (solid[0] as Array).size() if width > 0 else 0

	# Nombre de rectangles recouvrant chaque case.
	var cover: Array = []
	cover.resize(width)
	for ix in width:
		var column: Array[int] = []
		column.resize(height)
		cover[ix] = column

	var out_of_bounds := 0
	for rect: Rect2i in rects:
		if rect.size.x <= 0 or rect.size.y <= 0:
			out_of_bounds += 1
			continue
		if rect.position.x < 0 or rect.position.y < 0 \
				or rect.end.x > width or rect.end.y > height:
			out_of_bounds += 1
			continue
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				cover[x][y] += 1

	var holes := 0
	var overlaps := 0
	var spills := 0
	for ix in width:
		for iy in height:
			var n: int = cover[ix][iy]
			if solid[ix][iy]:
				if n == 0:
					holes += 1
				elif n > 1:
					overlaps += 1
			elif n > 0:
				spills += 1

	_check("%s — aucune case solide oubliée" % label, holes == 0, "%d trous" % holes)
	_check("%s — aucun recouvrement" % label, overlaps == 0, "%d doublons" % overlaps)
	_check("%s — aucun débordement sur le vide" % label, spills == 0, "%d débordements" % spills)
	_check("%s — rectangles dans les bornes" % label, out_of_bounds == 0,
		"%d hors bornes" % out_of_bounds)

	return rects.size()

func _test_merge_exact_cover() -> void:
	print("\n[Fusion — couverture exacte]")

	var default_map := _default_map()
	_check("carte livrée chargée", not default_map.is_empty())
	if not default_map.is_empty():
		_assert_exact_cover("carte livrée", MapGeometry.build_solid_grid(default_map))

	# Damier : pire cas possible, aucune fusion n'est réalisable.
	var checker := _open_map(Vector2i(12, 12))
	var checker_walls: Array[Vector2i] = []
	for y in 12:
		for x in 12:
			if (x + y) % 2 == 0:
				checker_walls.append(Vector2i(x, y))
	checker["walls"] = MapCodec.encode_runs(checker_walls)
	var checker_count := _assert_exact_cover("damier", MapGeometry.build_solid_grid(checker))
	print("    damier 12×12 : %d rectangles" % checker_count)

	# Salle avec deux piliers et un couloir borgne.
	var rooms := _open_map(Vector2i(24, 18))
	var room_walls: Array[Vector2i] = []
	for y in range(4, 14):
		room_walls.append(Vector2i(8, y))
		room_walls.append(Vector2i(15, y))
	for x in range(2, 22):
		room_walls.append(Vector2i(x, 9))
	rooms["walls"] = MapCodec.encode_runs(room_walls)
	var rooms_count := _assert_exact_cover("salle à piliers", MapGeometry.build_solid_grid(rooms))
	print("    salle 24×18 : %d rectangles" % rooms_count)

	# Sol non rectangulaire : diagonale, donc beaucoup d'escaliers.
	var diagonal := MapCodec.new_map("Diagonale", Vector2i(16, 16))
	var diagonal_floor: Array[Vector2i] = []
	for y in 16:
		for x in 16:
			if x + y >= 6 and x + y <= 20:
				diagonal_floor.append(Vector2i(x, y))
	diagonal["floor"] = MapCodec.encode_runs(diagonal_floor)
	var diagonal_count := _assert_exact_cover("sol diagonal", MapGeometry.build_solid_grid(diagonal))
	print("    diagonale 16×16 : %d rectangles" % diagonal_count)

func _test_merge_count_default_map() -> void:
	print("\n[Fusion — gain sur la carte livrée]")

	var map := _default_map()
	if map.is_empty():
		_check("carte livrée chargée", false)
		return

	var solid := MapGeometry.build_solid_grid(map)
	var rects := MapGeometry.merge_rects(solid)

	var solid_cells := 0
	for ix in solid.size():
		for iy in (solid[ix] as Array).size():
			if solid[ix][iy]:
				solid_cells += 1

	print("    %d cases solides → %d rectangles" % [solid_cells, rects.size()])
	_check("moins de 40 rectangles sur default.json", rects.size() < 40,
		"%d rectangles" % rects.size())
	_check("moins de 20 rectangles (objectif visé)", rects.size() < 20,
		"%d rectangles" % rects.size())

	var merged_area := 0
	for rect: Rect2i in rects:
		merged_area += rect.size.x * rect.size.y
	_check("aire fusionnée = aire solide", merged_area == solid_cells,
		"%d vs %d" % [merged_area, solid_cells])

# ---------------------------------------------------------------------------
# CONSTRUCTION DES NŒUDS
# ---------------------------------------------------------------------------

func _test_build_collisions() -> void:
	print("\n[Construction du corps de collision]")

	var map := _default_map()
	if map.is_empty():
		_check("carte livrée chargée", false)
		return

	var parent := Node2D.new()
	var root := MapGeometry.build_collisions(map, parent)

	_check("conteneur retourné", root != null)
	if root == null:
		parent.free()
		return

	_check("nom du conteneur = MapCollisions", root.name == MapGeometry.BODY_NAME, str(root.name))
	_check("enfant du parent fourni", root.get_parent() == parent)

	var body := root.get_node_or_null("Murs") as StaticBody2D
	var pit_body := root.get_node_or_null("Fosses") as StaticBody2D
	_check("corps des murs présent", body != null)
	_check("corps des fosses présent", pit_body != null)
	if body == null or pit_body == null:
		parent.free()
		return

	_check("murs sur la couche 1 (bullet.gd teste ce masque)",
		body.collision_layer == MapGeometry.WALL_LAYER, str(body.collision_layer))
	_check("fosses sur une couche distincte des murs",
		pit_body.collision_layer == MapGeometry.PIT_LAYER
			and pit_body.collision_layer != MapGeometry.WALL_LAYER,
		str(pit_body.collision_layer))

	var shapes: Array[CollisionShape2D] = []
	var occluders: Array[LightOccluder2D] = []
	for child in body.get_children():
		if child is CollisionShape2D:
			shapes.append(child)
		elif child is LightOccluder2D:
			occluders.append(child)

	var expected := MapGeometry.merge_rects(
		MapGeometry.build_grid(map, MapGeometry.Kind.WALLS)).size()
	_check("autant de formes que de rectangles de mur", shapes.size() == expected,
		"%d vs %d" % [shapes.size(), expected])
	_check("autant d'occluders que de formes", occluders.size() == shapes.size(),
		"%d occluders vs %d formes" % [occluders.size(), shapes.size()])
	_check("aucun autre enfant parasite", body.get_child_count() == shapes.size() + occluders.size())

	# LE point de la règle « une fosse est un trou, pas un mur ».
	var pit_shapes := 0
	var pit_occluders := 0
	for child in pit_body.get_children():
		if child is CollisionShape2D:
			pit_shapes += 1
		elif child is LightOccluder2D:
			pit_occluders += 1
	_check("les fosses ont des collisions", pit_shapes > 0, "%d formes" % pit_shapes)
	_check("les fosses ne projettent AUCUNE ombre", pit_occluders == 0,
		"%d occluders de trop" % pit_occluders)

	var geometry_ok := true
	var mask_ok := true
	var winding_ok := true
	for i in shapes.size():
		var shape := shapes[i]
		var occluder := occluders[i]
		var box := shape.shape as RectangleShape2D
		if box == null:
			geometry_ok = false
			break
		var polygon := occluder.occluder.polygon
		if occluder.position != shape.position or polygon.size() != 4:
			geometry_ok = false
			break
		# Le polygone est local et volontairement plus petit que la forme de
		# collision : le retrait laisse la face éclairée du mur capter la
		# lumière, faute de quoi le mur reste noir dans sa propre ombre.
		var inset := Vector2(
			minf(MapGeometry.OCCLUDER_INSET, box.size.x * 0.25),
			minf(MapGeometry.OCCLUDER_INSET, box.size.y * 0.25),
		)
		var half := box.size * 0.5 - inset
		var expected_polygon := PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])
		if polygon != expected_polygon:
			winding_ok = false
			break
		# Réglages par défaut, alignés sur les occluders d'arena.tscn.
		if occluder.occluder_light_mask != 1 \
				or occluder.occluder.cull_mode != OccluderPolygon2D.CULL_DISABLED \
				or not occluder.occluder.closed:
			mask_ok = false
			break

	_check("occluder aligné sur sa forme (RectangleShape2D, 4 sommets)", geometry_ok)
	_check("polygone local, sens horaire comme arena.tscn", winding_ok)
	_check("masques d'occlusion identiques à arena.tscn", mask_ok)

	# Les rectangles doivent pavier la carte au bon endroit : la case du spawn
	# J1 est du sol, donc aucune forme ne doit la recouvrir.
	var cell_size := Vector2(CandelaTileSet.TILE_SIZE)
	var spawn := MapCodec.get_spawn(map, 0)
	var spawn_center := (Vector2(spawn) + Vector2(0.5, 0.5)) * cell_size
	var spawn_blocked := false
	var outside_point := Vector2(-0.5, -0.5) * cell_size
	for shape in shapes:
		var box := shape.shape as RectangleShape2D
		var rect := Rect2(shape.position - box.size * 0.5, box.size)
		if rect.has_point(spawn_center):
			spawn_blocked = true
	_check("apparition J1 laissée libre", not spawn_blocked)

	# L'extérieur de la grille est une fosse, pas un mur : on ne peut pas y
	# aller, mais la lumière file au-delà sans être arrêtée.
	var outside_blocked := false
	for child in pit_body.get_children():
		if child is CollisionShape2D:
			var pit_box := (child as CollisionShape2D).shape as RectangleShape2D
			var pit_rect := Rect2((child as CollisionShape2D).position - pit_box.size * 0.5,
				pit_box.size)
			if pit_rect.has_point(outside_point):
				outside_blocked = true
	_check("extérieur de la grille infranchissable (fosse)", outside_blocked)

	# Reconstruction (rematch) : le corps précédent doit céder sa place.
	var rebuilt := MapGeometry.build_collisions(map, parent)
	_check("reconstruction : le nom reste sur le nouveau conteneur",
		parent.get_node_or_null(MapGeometry.BODY_NAME) == rebuilt)
	_check("reconstruction : pas d'empilement de corps", parent.get_child_count() == 1,
		"%d enfants" % parent.get_child_count())

	parent.free()

# ---------------------------------------------------------------------------
# CAS LIMITES
# ---------------------------------------------------------------------------

func _test_edge_cases() -> void:
	print("\n[Cas limites]")

	# Carte d'une seule case de sol : anneau solide de 8 cases autour.
	var tiny := MapCodec.new_map("Minuscule", Vector2i(1, 1))
	var tiny_floor: Array[Vector2i] = [Vector2i(0, 0)]
	tiny["floor"] = MapCodec.encode_runs(tiny_floor)
	var tiny_solid := MapGeometry.build_solid_grid(tiny)
	_check("carte 1 case → grille 3×3", tiny_solid.size() == 3 and (tiny_solid[0] as Array).size() == 3,
		"%d×%d" % [tiny_solid.size(), (tiny_solid[0] as Array).size()])
	_check("carte 1 case → centre traversable", not tiny_solid[1][1])
	var tiny_count := _assert_exact_cover("carte 1 case", tiny_solid)
	print("    carte 1 case : %d rectangles" % tiny_count)

	var tiny_parent := Node2D.new()
	var tiny_body := MapGeometry.build_collisions(tiny, tiny_parent)
	_check("carte 1 case → corps construit", tiny_body != null and tiny_body.get_child_count() > 0)
	tiny_parent.free()

	# Dictionnaire vide : aucune donnée, aucun plantage attendu.
	var empty_solid := MapGeometry.build_solid_grid({})
	# ⚠️ **32 et non 22 : c'est la grille par défaut du codec, débordée d'une
	# case de chaque côté pour fermer la carte.** Elle suit `default.json`, passée
	# de 20×20 à 30×30 le 2026-08-26. Ce contrôle a rougi le jour même — il
	# vérifie qu'une carte VIDE se remplit quand même de solide, et son chiffre
	# est donc une copie de la taille livrée. Il l'attrape au lieu de la subir.
	_check("carte vide → grille par défaut 32×32", empty_solid.size() == 32,
		"%d colonnes" % empty_solid.size())
	var empty_rects := MapGeometry.merge_rects(empty_solid)
	_check("carte vide → un seul rectangle plein", empty_rects.size() == 1,
		"%d rectangles" % empty_rects.size())

	var empty_parent := Node2D.new()
	var empty_body := MapGeometry.build_collisions({}, empty_parent)
	_check("carte vide → corps construit sans planter", empty_body != null)
	_check("carte vide → 1 forme + 1 occluder", empty_body.get_child_count() == 2,
		"%d enfants" % empty_body.get_child_count())
	empty_parent.free()

	# Tableaux dégénérés : merge_rects et trace_contours doivent tenir.
	var nothing: Array = []
	var empty_column: Array[bool] = []
	var degenerate: Array = [empty_column]
	_check("merge_rects([]) → aucun rectangle", MapGeometry.merge_rects(nothing).is_empty())
	_check("merge_rects colonne vide → aucun rectangle",
		MapGeometry.merge_rects(degenerate).is_empty())
	_check("trace_contours([]) → aucun contour", MapGeometry.trace_contours(nothing).is_empty())

# ---------------------------------------------------------------------------
# CONTOURS
# ---------------------------------------------------------------------------

## Aire signée (formule du lacet). Positive = sens horaire à l'écran (y bas).
func _signed_area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return total * 0.5

func _count_solid(solid: Array) -> int:
	var total := 0
	for ix in solid.size():
		for iy in (solid[ix] as Array).size():
			if solid[ix][iy]:
				total += 1
	return total

func _test_contours() -> void:
	print("\n[Contours]")

	# Bloc plein : un seul contour rectangulaire de 4 sommets, sens horaire.
	var full := MapGeometry.build_solid_grid(MapCodec.new_map("Plein", Vector2i(8, 8)))
	var full_contours := MapGeometry.trace_contours(full)
	_check("bloc plein → un seul contour", full_contours.size() == 1,
		"%d contours" % full_contours.size())
	if full_contours.size() == 1:
		_check("bloc plein → 4 sommets (alignés supprimés)", full_contours[0].size() == 4,
			"%d sommets" % full_contours[0].size())
		_check("sens horaire comme arena.tscn", _signed_area(full_contours[0]) > 0.0,
			str(_signed_area(full_contours[0])))

	# Carte livrée : contour extérieur + contour du trou (le sol).
	var map := _default_map()
	if not map.is_empty():
		var solid := MapGeometry.build_solid_grid(map)
		var contours := MapGeometry.trace_contours(solid)
		_check("carte livrée → 2 contours (pourtour + sol)", contours.size() == 2,
			"%d contours" % contours.size())

		# Invariant fort : la somme des aires signées vaut l'aire solide, le
		# trou étant parcouru en sens inverse.
		var total := 0.0
		for contour in contours:
			total += _signed_area(contour)
		_check("aire signée totale = cases solides", is_equal_approx(total, float(_count_solid(solid))),
			"%.1f vs %d" % [total, _count_solid(solid)])

	# Deux piliers qui ne se touchent que par une diagonale : ils doivent rester
	# deux contours distincts, en plus des deux boucles de la ceinture de bord.
	var diagonal := _open_map(Vector2i(10, 10))
	var diagonal_walls: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 5)]
	diagonal["walls"] = MapCodec.encode_runs(diagonal_walls)
	var diagonal_solid := MapGeometry.build_solid_grid(diagonal)
	var diagonal_contours := MapGeometry.trace_contours(diagonal_solid)
	_check("touche diagonale → contours séparés", diagonal_contours.size() == 4,
		"%d contours" % diagonal_contours.size())
	var diagonal_total := 0.0
	for contour in diagonal_contours:
		diagonal_total += _signed_area(contour)
	_check("aire signée totale conservée (diagonale)",
		is_equal_approx(diagonal_total, float(_count_solid(diagonal_solid))),
		"%.1f vs %d" % [diagonal_total, _count_solid(diagonal_solid)])

## Le retrait de l'occluder ne doit jamais rogner la collision : le joueur
## doit être bloqué sur la tuile entière, seule l'ombre est légèrement réduite.
func _test_occluder_inset_keeps_collision_intact() -> void:
	print("\n[Retrait d'occlusion]")
	var data := _default_map()
	var arena := Node2D.new()
	var root := MapGeometry.build_collisions(data, arena)
	var body := root.get_node("Murs") as StaticBody2D
	var wall_cells := _count_solid(MapGeometry.build_grid(data, MapGeometry.Kind.WALLS))

	var collision_area := 0.0
	var occluder_area := 0.0
	var all_smaller := true
	for child in body.get_children():
		if child is CollisionShape2D:
			var box := (child as CollisionShape2D).shape as RectangleShape2D
			collision_area += box.size.x * box.size.y
		elif child is LightOccluder2D:
			var poly := (child as LightOccluder2D).occluder.polygon
			var w := absf(poly[1].x - poly[0].x)
			var h := absf(poly[2].y - poly[1].y)
			occluder_area += w * h

	_check("la collision couvre la tuile entière (aire inchangée)",
		is_equal_approx(collision_area, float(wall_cells) * 35.0 * 35.0),
		"%.0f px²" % collision_area)
	_check("l'occlusion est strictement plus petite que la collision",
		occluder_area < collision_area, "%.0f vs %.0f" % [occluder_area, collision_area])

	# Un rectangle d'une tuile garde un occluder représentatif.
	var tiny := MapCodec.new_map("Minuscule", Vector2i(8, 8))
	var cells: Array[Vector2i] = []
	for y in range(1, 7):
		for x in range(1, 7):
			cells.append(Vector2i(x, y))
	tiny["floor"] = MapCodec.encode_runs(cells)
	tiny["walls"] = MapCodec.encode_runs([Vector2i(3, 3)] as Array[Vector2i])
	tiny["spawn_p1"] = {"x": 1, "y": 1}
	tiny["spawn_p2"] = {"x": 6, "y": 6}

	var arena2 := Node2D.new()
	var body2 := (MapGeometry.build_collisions(tiny, arena2)).get_node("Murs")
	var min_side := INF
	for child in body2.get_children():
		if child is LightOccluder2D:
			var poly := (child as LightOccluder2D).occluder.polygon
			min_side = minf(min_side, absf(poly[1].x - poly[0].x))
	_check("occluder d'une tuile isolée conserve au moins la moitié du côté",
		min_side >= 35.0 * 0.5, "%.1f px" % min_side)

	arena.free()
	arena2.free()
