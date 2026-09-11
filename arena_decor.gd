class_name ArenaDecor
extends Node2D

## ArenaDecor — Habillage d'atelier & Décors d'arène (Roman Graphique Brutaliste).
##
## Missions :
## 1. Bandes de danger en chevrons noir/ambre aux abords des zones clés (fosses/gouffres).
## 2. Marquages au pochoir de numéros de travée et délimitations d'angles industriels.
## 3. Habillage des obstacles en mobilier lourd d'atelier (caisses rivetées, fûts d'encre, colonnes).
##
## Zéro vert dans l'arène : respect strict de charte.gd.
## Intérieur sombre respectant le fondu additif et liséré halogène franc.

const Charte := preload("res://charte.gd")

const CHEVRON_WIDTH := 6.0
const TILE_SIZE := 35.0

var _map_data: Dictionary = {}
var _danger_edges: Array[Dictionary] = [] # {"start": Vector2, "end": Vector2, "normal": Vector2}
var _stencils: Array[Dictionary] = []     # {"pos": Vector2, "type": String, "rot": float}
var _corner_brackets: Array[Vector2] = [] # positions d'angles
var _obstacles: Array[Dictionary] = []    # {"rect": Rect2, "type": String}


## Construit et ajoute les décors d'arène dans le nœud arena.
static func build(data: Dictionary, parent: Node2D) -> ArenaDecor:
	# Purge préalable si existant
	for old_name in ["ArenaDecor", "ArenaDecor_P1", "ArenaDecor_P2"]:
		var old := parent.get_node_or_null(old_name)
		if old:
			parent.remove_child(old)
			old.queue_free()

	var decor: Node2D = (preload("res://arena_decor.gd") as GDScript).new()
	decor.name = "ArenaDecor"
	decor.setup(data)
	parent.add_child(decor)

	# Duplications pour l'écran scindé (P1 et P2)
	decor._duplicate_for_player(parent, 1, 2, 1 | 16)
	decor._duplicate_for_player(parent, 2, 4, 1 | 32)

	return decor


func setup(data: Dictionary) -> void:
	_map_data = data
	z_index = 0
	# Calque original : visible par défaut
	visibility_layer = 1
	light_mask = 1
	# Refonte roman graphique, lot 4 (2026-09-11, Adrien : « corrige les deux
	# éléments à corriger ») : plus de matériau additif. Chevrons, équerres,
	# pochoirs et rivets sont des marques PEINTES au sol, pas des sources : en
	# addition elles ne pouvaient jamais porter de noir et s'éclaircissaient deux
	# fois sous la torche. Mélange normal, éclairé comme le sol — les LUMIÈRES,
	# elles, s'additionnent toujours (c'est le principe du jeu, et il vit dans
	# les Light2D, pas ici).

	_analyser_carte()
	queue_redraw()


func _duplicate_for_player(parent: Node2D, player_idx: int, vis_mask: int, lt_mask: int) -> void:
	var copy := duplicate() as Node2D
	copy.name = "ArenaDecor_P%d" % player_idx
	copy.visibility_layer = vis_mask
	copy.light_mask = lt_mask
	copy._danger_edges = _danger_edges
	copy._stencils = _stencils
	copy._corner_brackets = _corner_brackets
	copy._obstacles = _obstacles
	copy.queue_redraw()
	parent.add_child(copy)


func _analyser_carte() -> void:
	_danger_edges.clear()
	_stencils.clear()
	_corner_brackets.clear()
	_obstacles.clear()

	var grid := MapCodec.get_grid_size(_map_data)
	var floor_cells := MapCodec.get_floor_cells(_map_data)
	var wall_cells := MapCodec.get_wall_cells(_map_data)

	var floor_set := {}
	for c in floor_cells:
		floor_set[c] = true

	var wall_set := {}
	for c in wall_cells:
		wall_set[c] = true

	var p1_spawn := MapCodec.get_spawn(_map_data, 0)
	var p2_spawn := MapCodec.get_spawn(_map_data, 1)

	# 1. Détection des zones de danger pour bandes chevrons noir/ambre :
	# Bords de fosses/gouffres (sol bordé de vide), et délimitations de zones d'accès clés.
	for cell in floor_cells:
		var pos := Vector2(cell) * TILE_SIZE
		# Voisin Nord (fosse)
		var north := cell + Vector2i(0, -1)
		if not floor_set.has(north) and not wall_set.has(north):
			_danger_edges.append({
				"start": pos,
				"end": pos + Vector2(TILE_SIZE, 0),
				"dir": Vector2(1, 0),
				"normal": Vector2(0, 1)
			})
		# Voisin Sud (fosse)
		var south := cell + Vector2i(0, 1)
		if not floor_set.has(south) and not wall_set.has(south):
			_danger_edges.append({
				"start": pos + Vector2(TILE_SIZE, TILE_SIZE),
				"end": pos + Vector2(0, TILE_SIZE),
				"dir": Vector2(-1, 0),
				"normal": Vector2(0, -1)
			})
		# Voisin Ouest (fosse)
		var west := cell + Vector2i(-1, 0)
		if not floor_set.has(west) and not wall_set.has(west):
			_danger_edges.append({
				"start": pos + Vector2(0, TILE_SIZE),
				"end": pos,
				"dir": Vector2(0, -1),
				"normal": Vector2(1, 0)
			})
		# Voisin Est (fosse)
		var east := cell + Vector2i(1, 0)
		if not floor_set.has(east) and not wall_set.has(east):
			_danger_edges.append({
				"start": pos + Vector2(TILE_SIZE, 0),
				"end": pos + Vector2(TILE_SIZE, TILE_SIZE),
				"dir": Vector2(0, 1),
				"normal": Vector2(-1, 0)
			})

	# Si la carte n'a pas de gouffre intérieur (ex: carte fermée), on pose des chevrons de danger
	# aux seuils des zones de spawn pour délimiter les zones de départ / combat
	if _danger_edges.is_empty():
		for sp in [p1_spawn, p2_spawn]:
			if sp.x >= 0:
				var sp_pos := Vector2(sp) * TILE_SIZE
				_danger_edges.append({
					"start": sp_pos + Vector2(0, TILE_SIZE),
					"end": sp_pos + Vector2(TILE_SIZE, TILE_SIZE),
					"dir": Vector2(1, 0),
					"normal": Vector2(0, -1)
				})

	# 2. Délimitations d'angles industriels (L-brackets aux coins des sols libres)
	for cell in floor_cells:
		var pos := Vector2(cell) * TILE_SIZE
		var has_n := floor_set.has(cell + Vector2i(0, -1))
		var has_s := floor_set.has(cell + Vector2i(0, 1))
		var has_w := floor_set.has(cell + Vector2i(-1, 0))
		var has_e := floor_set.has(cell + Vector2i(1, 0))

		if not has_n and not has_w:
			_corner_brackets.append(pos + Vector2(3, 3))
		if not has_n and not has_e:
			_corner_brackets.append(pos + Vector2(TILE_SIZE - 3, 3))
		if not has_s and not has_w:
			_corner_brackets.append(pos + Vector2(3, TILE_SIZE - 3))
		if not has_s and not has_e:
			_corner_brackets.append(pos + Vector2(TILE_SIZE - 3, TILE_SIZE - 3))

	# 3. Marquages pochoir de travées aux abords des spawns P1 et P2
	if p1_spawn.x >= 0:
		_stencils.append({
			"pos": Vector2(p1_spawn) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5),
			"text": "01",
			"type": "spawn"
		})
	if p2_spawn.x >= 0:
		_stencils.append({
			"pos": Vector2(p2_spawn) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5),
			"text": "02",
			"type": "spawn"
		})

	# Pochoir de travée centrale si disponible
	var centre_cell := Vector2i(grid.x / 2, grid.y / 2)
	if floor_set.has(centre_cell) and not wall_set.has(centre_cell):
		_stencils.append({
			"pos": Vector2(centre_cell) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5),
			"text": "BAY-A",
			"type": "bay"
		})

	# 4. Identification des obstacles pour habillage mobilier lourd
	# Fûts d'encre sur piliers isolés 1x1, caisses rivetées sur blocs
	for cell in wall_cells:
		var has_n := wall_set.has(cell + Vector2i(0, -1))
		var has_s := wall_set.has(cell + Vector2i(0, 1))
		var has_w := wall_set.has(cell + Vector2i(-1, 0))
		var has_e := wall_set.has(cell + Vector2i(1, 0))

		var rect := Rect2(Vector2(cell) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
		if not has_n and not has_s and not has_w and not has_e:
			_obstacles.append({"rect": rect, "type": "fut_encre"})
		else:
			_obstacles.append({"rect": rect, "type": "caisse_acier"})


func _draw() -> void:
	_dessiner_bandes_danger()
	_dessiner_equerres_angles()
	_dessiner_pochoirs()
	_dessiner_obstacles_atelier()


## Bandes de sécurité en chevrons noir / ambre d'atelier le long des gouffres
func _dessiner_bandes_danger() -> void:
	var chevron_step := 7.0
	for edge in _danger_edges:
		var p1: Vector2 = edge["start"]
		var p2: Vector2 = edge["end"]
		var normal: Vector2 = edge["normal"] # vers l'intérieur du sol
		var tangent: Vector2 = edge["dir"]

		var length := p1.distance_to(p2)
		var num_chevrons := int(length / chevron_step)

		for i in range(num_chevrons):
			var t := float(i) * chevron_step
			var pt := p1 + tangent * t
			var pt_next := p1 + tangent * minf(t + chevron_step * 0.5, length)

			# Alternance chevrons ambre et noir
			var poly := PackedVector2Array([
				pt,
				pt_next,
				pt_next + normal * CHEVRON_WIDTH + tangent * (chevron_step * 0.4),
				pt + normal * CHEVRON_WIDTH + tangent * (chevron_step * 0.4)
			])
			draw_colored_polygon(poly, Charte.AMBRE * 0.85)

		# Liseré de délimitation ambre franc en bordure de bande
		draw_line(p1 + normal * CHEVRON_WIDTH, p2 + normal * CHEVRON_WIDTH,
			Charte.AMBRE * 0.5, 1.0)


## Équerres industrielles de coin d'atelier (L-brackets pochoir)
func _dessiner_equerres_angles() -> void:
	var bras := 7.0
	var col := Charte.AMBRE * 0.70
	for pt in _corner_brackets:
		draw_line(pt - Vector2(bras, 0), pt + Vector2(bras, 0), col, 1.5)
		draw_line(pt - Vector2(0, bras), pt + Vector2(0, bras), col, 1.5)


## Pochoirs de travée et numérotation d'atelier
func _dessiner_pochoirs() -> void:
	for st in _stencils:
		var pos: Vector2 = st["pos"]
		var txt: String = st["text"]
		var col := Charte.AMBRE * 0.75 if st["type"] == "spawn" else Charte.HALOGENE * 0.45

		# Cadre pochoir discontinu
		var half := 12.0
		# 4 coins en équerre
		draw_line(pos + Vector2(-half, -half), pos + Vector2(-half + 5, -half), col, 1.0)
		draw_line(pos + Vector2(-half, -half), pos + Vector2(-half, -half + 5), col, 1.0)

		draw_line(pos + Vector2(half, -half), pos + Vector2(half - 5, -half), col, 1.0)
		draw_line(pos + Vector2(half, -half), pos + Vector2(half, -half + 5), col, 1.0)

		draw_line(pos + Vector2(-half, half), pos + Vector2(-half + 5, half), col, 1.0)
		draw_line(pos + Vector2(-half, half), pos + Vector2(-half, half - 5), col, 1.0)

		draw_line(pos + Vector2(half, half), pos + Vector2(half - 5, half), col, 1.0)
		draw_line(pos + Vector2(half, half), pos + Vector2(half, half - 5), col, 1.0)

		# Dessin vectoriel du chiffre ou symbole pochoir
		_dessiner_glyphe_pochoir(pos, txt, col)


func _dessiner_glyphe_pochoir(pos: Vector2, txt: String, col: Color) -> void:
	match txt:
		"01":
			# Chiffre 01 stylisé au pochoir brutaliste
			# 0 : rectangle avec découpe centrale
			draw_rect(Rect2(pos.x - 7, pos.y - 5, 5, 10), col, false, 1.0)
			# 1 : trait vertical franc
			draw_line(Vector2(pos.x + 3, pos.y - 5), Vector2(pos.x + 3, pos.y + 5), col, 1.5)
			draw_line(Vector2(pos.x + 1, pos.y - 3), Vector2(pos.x + 3, pos.y - 5), col, 1.2)
		"02":
			# Chiffre 02 stylisé au pochoir
			draw_rect(Rect2(pos.x - 7, pos.y - 5, 5, 10), col, false, 1.0)
			# 2 en traits brisés
			draw_line(Vector2(pos.x + 1, pos.y - 5), Vector2(pos.x + 6, pos.y - 5), col, 1.2)
			draw_line(Vector2(pos.x + 6, pos.y - 5), Vector2(pos.x + 6, pos.y), col, 1.2)
			draw_line(Vector2(pos.x + 6, pos.y), Vector2(pos.x + 1, pos.y + 5), col, 1.2)
			draw_line(Vector2(pos.x + 1, pos.y + 5), Vector2(pos.x + 6, pos.y + 5), col, 1.2)
		_:
			# Symbole de baie industrielle (losange barré)
			draw_line(pos - Vector2(5, 0), pos + Vector2(5, 0), col, 1.0)
			draw_line(pos - Vector2(0, 5), pos + Vector2(0, 5), col, 1.0)
			draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), col, false, 1.0)


## Habillage des obstacles en mobilier lourd (fûts d'encre et caisses rivetées)
func _dessiner_obstacles_atelier() -> void:
	for obs in _obstacles:
		var r: Rect2 = obs["rect"]
		var center := r.get_center()

		if obs["type"] == "fut_encre":
			# Fût d'encre lourd d'atelier
			var rayon := (TILE_SIZE * 0.5) - 3.0
			# Cerclage extérieur acier halogène
			draw_arc(center, rayon, 0, TAU, 24, Charte.HALOGENE, 1.5)
			# Nervure concentrique intermédiaire
			draw_arc(center, rayon * 0.65, 0, TAU, 16, Charte.LINE * 0.8, 1.0)
			# Bouchon / valve décentrée
			var valve_pos := center + Vector2(rayon * 0.35, -rayon * 0.25)
			draw_circle(valve_pos, 2.5, Charte.LINE)
			draw_circle(valve_pos, 1.2, Charte.ACIER * 0.5)
			# 4 rivets de fixation du fût
			for i in 4:
				var a := float(i) * PI * 0.5 + PI * 0.25
				var pt := center + Vector2(cos(a), sin(a)) * (rayon - 2.5)
				draw_circle(pt, 1.0, Charte.ACIER * 0.45)
		else:
			# Caisse rivetée d'atelier : renforts d'angles et rivets
			var inset := 3.0
			var ir := r.grow(-inset)
			# Cornières intérieures
			draw_rect(ir, Charte.LINE * 0.6, false, 1.0)
			# Rivets aux 4 coins
			var rivets := [
				ir.position + Vector2(2, 2),
				Vector2(ir.end.x - 2, ir.position.y + 2),
				Vector2(ir.position.x + 2, ir.end.y - 2),
				ir.end - Vector2(2, 2)
			]
			for rv in rivets:
				draw_circle(rv, 1.0, Charte.ACIER * 0.5)
