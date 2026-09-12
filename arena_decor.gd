class_name ArenaDecor
extends Node2D

## ArenaDecor — les marques au sol de l'arène (Roman Graphique Brutaliste).
##
## Deux choses, et deux seulement :
## 1. Les bandes de danger en chevrons ambre aux abords du vide (fosses).
## 2. Les pochoirs de travée (« 01 », « 02 », « BAY-A ») près des départs.
##
## ## Ce qui a été RETIRÉ, et pourquoi (2026-09-11, décision d'Adrien)
##
## Ce nœud habillait aussi chaque case de mur en « mobilier lourd » — cerclages,
## rivets, cornières, un fût sur les piliers isolés — et posait une équerre à
## chaque coin de sol. Mesuré par la session « régression de cadence » (sonde à
## rendu forcé, vue unique) : **81 → 3 376 appels de dessin par image** au commit
## qui l'a introduit (`bad6083`, 2026-09-08), ~5 ms de rendu CPU, en trois
## copies dont deux rendues en écran scindé ; masquer ce seul nœud faisait
## remonter la médiane de 80 à 100 et le 1 % bas de 47 à 69. Et depuis les murs
## au trait (`mur_encre.gd`), ces rivets doublaient le contour d'encre sur la
## même surface — deux vocabulaires de mur. Adrien : retirer l'habillage.
##
## ## Ce qui reste est CUIT en une texture par carte
##
## Le reste — chevrons tous les 7 px sur chaque bord de fosse, pochoirs — est
## encore des centaines de primitives. Comme le bandeau LED (`mur_led.gd`), le
## dessin est rendu UNE fois dans un `SubViewport` à la taille de la carte, et
## chaque copie n'affiche plus qu'une texture : un appel de dessin par vue.
## Tant que la cuisson n'est pas finie (deux images), et toujours en headless
## (rien n'est rastérisé, les suites y passent), le dessin direct sert.
##
## Zéro vert dans l'arène : respect strict de charte.gd. Mélange normal (lot 4
## de la refonte) : des marques peintes, pas des sources.

const Charte := preload("res://charte.gd")

const CHEVRON_WIDTH := 6.0
const TILE_SIZE := 35.0

var _map_data: Dictionary = {}
var _danger_edges: Array[Dictionary] = [] # {"start": Vector2, "end": Vector2, "normal": Vector2}
var _stencils: Array[Dictionary] = []     # {"pos": Vector2, "type": String, "rot": float}
## Le rectangle de monde que couvre la cuisson : la carte, plus une case de
## marge de chaque côté (les chevrons d'un bord de carte débordent d'un pas).
var _cadre: Rect2 = Rect2()
## La texture cuite ; `null` tant qu'elle n'est pas prête, et pour toujours en
## headless — `_draw()` dessine alors en direct.
var _cuit: Texture2D = null
## Les deux copies par vue, pour leur pousser la texture une fois cuite.
var _copies: Array[Node2D] = []
var _est_copie := false


## Le peintre de la cuisson : un nœud jetable dans le SubViewport, qui dessine
## le décor une fois, décalé pour que le cadre commence en (0, 0).
class _Peintre extends Node2D:
	var decor: Node2D
	func _draw() -> void:
		decor._dessiner_direct(self)


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
	# `duplicate()` ne recopie pas les variables de script (piège du 2026-08-25).
	copy._danger_edges = _danger_edges
	copy._stencils = _stencils
	copy._cadre = _cadre
	copy._cuit = _cuit
	copy._est_copie = true
	copy.queue_redraw()
	parent.add_child(copy)
	_copies.append(copy)


func _ready() -> void:
	if not _est_copie:
		_cuire()


## Rend le décor UNE fois dans un SubViewport à la taille du cadre, puis
## remplace le dessin direct par cette texture — ici et dans les copies.
func _cuire() -> void:
	if DisplayServer.get_name() == "headless" or _cadre.size.x <= 0.0:
		return
	# ⚠️ D'abord une image d'attente : `build()` DUPLIQUE ce nœud juste après
	# l'avoir ajouté, enfants compris — un SubViewport déjà posé partirait dans
	# les copies avec un peintre sans décor (vu à la première capture : six
	# « _dessiner_direct in base Nil »). Créé à l'image suivante, il n'est qu'ici.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var vue := SubViewport.new()
	vue.name = "CuissonDecor"
	vue.size = Vector2i(_cadre.size)
	vue.transparent_bg = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	# Le viewport entre dans l'arbre AVANT de recevoir son peintre, pour que le
	# peintre trouve son World2D dès son entrée. (L'erreur « !is_inside_tree() …
	# Returning Ref<World2D>() » qu'imprime le photographe à sa FERMETURE sur un
	# plan seul n'est pas d'ici : vérifiée présente avec l'ancien décor.)
	add_child(vue)
	var peintre := _Peintre.new()
	peintre.decor = self
	peintre.position = -_cadre.position
	vue.add_child(peintre)
	# Une image pour rendre : la texture n'est lisible qu'après.
	await RenderingServer.frame_post_draw
	# L'arène a pu être reconstruite pendant l'attente : ce nœud n'y est plus.
	if not is_inside_tree():
		return
	var img: Image = vue.get_texture().get_image()
	vue.queue_free()
	if img == null:
		return
	_cuit = ImageTexture.create_from_image(img)
	queue_redraw()
	for copy in _copies:
		if is_instance_valid(copy):
			copy._cuit = _cuit
			copy.queue_redraw()


func _analyser_carte() -> void:
	_danger_edges.clear()
	_stencils.clear()

	var grid := MapCodec.get_grid_size(_map_data)
	_cadre = Rect2(Vector2(-TILE_SIZE, -TILE_SIZE), (Vector2(grid) + Vector2(2, 2)) * TILE_SIZE)
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


func _draw() -> void:
	if _cuit != null:
		draw_texture(_cuit, _cadre.position)
		return
	_dessiner_direct(self)


## Le dessin lui-même, sur n'importe quel CanvasItem : le nœud (avant cuisson
## et en headless) ou le peintre de la cuisson.
func _dessiner_direct(sur: CanvasItem) -> void:
	_dessiner_bandes_danger(sur)
	_dessiner_pochoirs(sur)


## Bandes de sécurité en chevrons noir / ambre d'atelier le long des gouffres
func _dessiner_bandes_danger(sur: CanvasItem) -> void:
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
			sur.draw_colored_polygon(poly, Charte.AMBRE * 0.85)

		# Liseré de délimitation ambre franc en bordure de bande
		sur.draw_line(p1 + normal * CHEVRON_WIDTH, p2 + normal * CHEVRON_WIDTH,
			Charte.AMBRE * 0.5, 1.0)


## Pochoirs de travée et numérotation d'atelier
func _dessiner_pochoirs(sur: CanvasItem) -> void:
	for st in _stencils:
		var pos: Vector2 = st["pos"]
		var txt: String = st["text"]
		var col := Charte.AMBRE * 0.75 if st["type"] == "spawn" else Charte.HALOGENE * 0.45

		# Cadre pochoir discontinu
		var half := 12.0
		# 4 coins en équerre
		sur.draw_line(pos + Vector2(-half, -half), pos + Vector2(-half + 5, -half), col, 1.0)
		sur.draw_line(pos + Vector2(-half, -half), pos + Vector2(-half, -half + 5), col, 1.0)

		sur.draw_line(pos + Vector2(half, -half), pos + Vector2(half - 5, -half), col, 1.0)
		sur.draw_line(pos + Vector2(half, -half), pos + Vector2(half, -half + 5), col, 1.0)

		sur.draw_line(pos + Vector2(-half, half), pos + Vector2(-half + 5, half), col, 1.0)
		sur.draw_line(pos + Vector2(-half, half), pos + Vector2(-half, half - 5), col, 1.0)

		sur.draw_line(pos + Vector2(half, half), pos + Vector2(half - 5, half), col, 1.0)
		sur.draw_line(pos + Vector2(half, half), pos + Vector2(half, half - 5), col, 1.0)

		# Dessin vectoriel du chiffre ou symbole pochoir
		_dessiner_glyphe_pochoir(sur, pos, txt, col)


func _dessiner_glyphe_pochoir(sur: CanvasItem, pos: Vector2, txt: String, col: Color) -> void:
	match txt:
		"01":
			# Chiffre 01 stylisé au pochoir brutaliste
			# 0 : rectangle avec découpe centrale
			sur.draw_rect(Rect2(pos.x - 7, pos.y - 5, 5, 10), col, false, 1.0)
			# 1 : trait vertical franc
			sur.draw_line(Vector2(pos.x + 3, pos.y - 5), Vector2(pos.x + 3, pos.y + 5), col, 1.5)
			sur.draw_line(Vector2(pos.x + 1, pos.y - 3), Vector2(pos.x + 3, pos.y - 5), col, 1.2)
		"02":
			# Chiffre 02 stylisé au pochoir
			sur.draw_rect(Rect2(pos.x - 7, pos.y - 5, 5, 10), col, false, 1.0)
			# 2 en traits brisés
			sur.draw_line(Vector2(pos.x + 1, pos.y - 5), Vector2(pos.x + 6, pos.y - 5), col, 1.2)
			sur.draw_line(Vector2(pos.x + 6, pos.y - 5), Vector2(pos.x + 6, pos.y), col, 1.2)
			sur.draw_line(Vector2(pos.x + 6, pos.y), Vector2(pos.x + 1, pos.y + 5), col, 1.2)
			sur.draw_line(Vector2(pos.x + 1, pos.y + 5), Vector2(pos.x + 6, pos.y + 5), col, 1.2)
		_:
			# Symbole de baie industrielle (losange barré)
			sur.draw_line(pos - Vector2(5, 0), pos + Vector2(5, 0), col, 1.0)
			sur.draw_line(pos - Vector2(0, 5), pos + Vector2(0, 5), col, 1.0)
			sur.draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), col, false, 1.0)
