## MapEditorTools — Outils de dessin et pile d'annulation de l'éditeur de cartes.
##
## Le module ne connaît que deux calques de tuiles et deux points d'apparition.
## Toute modification passe par une transaction : un coup de pinceau, aussi long
## soit-il, ne produit qu'une seule entrée d'historique. La profondeur est bornée
## à [constant HISTORY_DEPTH].
##
## Cycle de vie type :
## [codeblock]
## tools.begin("Pinceau")
## tools.paint_line(MapEditorTools.LAYER_FLOOR, from_cell, to_cell, true)
## tools.commit()
## [/codeblock]
##
## Les outils n'écrivent jamais dans les fichiers : c'est l'éditeur qui extrait
## les données via [code]MapData.extract_from_layers()[/code] au moment voulu.

class_name MapEditorTools
extends RefCounted

## Émis quand la pile d'annulation change (nouvelle transaction, annulation…).
signal history_changed()
## Émis dès qu'une cellule ou une apparition change réellement de valeur.
signal map_changed()
## Émis par lot après une opération de dessin, pour l'habillage visuel.
signal cells_touched(cells: Array[Vector2i], layer: StringName, painting: bool)
## Émis quand un point d'apparition est déplacé (index 0 = J1, 1 = J2).
signal spawn_moved(index: int, cell: Vector2i)

const LAYER_FLOOR: StringName = &"floor"
const LAYER_WALLS: StringName = &"walls"

## Coordonnée atlas conventionnelle d'une cellule vide.
const EMPTY_ATLAS := Vector2i(-1, -1)
## Cellule conventionnelle d'une apparition non posée.
const NO_CELL := Vector2i(-1, -1)
## Profondeur maximale de la pile d'annulation.
const HISTORY_DEPTH := 100
## Garde-fou du pot de peinture (une grille 128×128 fait 16 384 cellules).
const FILL_LIMIT := 16384

const NEIGHBOURS_4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const NEIGHBOURS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

# ---------------------------------------------------------------------------
# ENREGISTREMENTS D'HISTORIQUE
# ---------------------------------------------------------------------------

## Une cellule modifiée : son état avant et après, pour rejouer dans les deux sens.
class CellEdit extends RefCounted:
	var layer: StringName = &""              ## &"floor" | &"walls"
	var cell: Vector2i = Vector2i.ZERO
	var before: Vector2i = Vector2i(-1, -1)  ## coord atlas, Vector2i(-1, -1) si vide
	var after: Vector2i = Vector2i(-1, -1)

	func _init(p_layer: StringName = &"", p_cell: Vector2i = Vector2i.ZERO,
			p_before: Vector2i = Vector2i(-1, -1),
			p_after: Vector2i = Vector2i(-1, -1)) -> void:
		layer = p_layer
		cell = p_cell
		before = p_before
		after = p_after


## Un point d'apparition déplacé.
class SpawnEdit extends RefCounted:
	var index: int = 0                       ## 0 = J1, 1 = J2
	var before: Vector2i = Vector2i(-1, -1)
	var after: Vector2i = Vector2i(-1, -1)

	func _init(p_index: int = 0, p_before: Vector2i = Vector2i(-1, -1),
			p_after: Vector2i = Vector2i(-1, -1)) -> void:
		index = p_index
		before = p_before
		after = p_after


## Un geste complet de l'utilisateur, annulable d'un seul coup.
class Transaction extends RefCounted:
	var label: String = ""
	var cells: Array[CellEdit] = []
	var spawns: Array[SpawnEdit] = []

	func _init(p_label: String = "") -> void:
		label = p_label

	func is_empty() -> bool:
		return cells.is_empty() and spawns.is_empty()

	func touched_count() -> int:
		return cells.size() + spawns.size()

# ---------------------------------------------------------------------------
# ÉTAT
# ---------------------------------------------------------------------------

## Taille de la grille, pilotée par les données de la carte.
var grid_size: Vector2i = Vector2i(32, 32)

var _floor_layer: TileMapLayer = null
var _walls_layer: TileMapLayer = null
var _spawns: Array[Vector2i] = [NO_CELL, NO_CELL]

var _undo_stack: Array[Transaction] = []
var _redo_stack: Array[Transaction] = []
var _pending: Transaction = null
## Cellules déjà enregistrées dans la transaction courante : une même cellule
## repeinte deux fois pendant un glisser ne doit produire qu'un seul CellEdit.
var _pending_seen: Dictionary = {}

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

func setup(floor_layer: TileMapLayer, walls_layer: TileMapLayer, p_grid: Vector2i) -> void:
	_floor_layer = floor_layer
	_walls_layer = walls_layer
	grid_size = p_grid

## Recale la grille après un chargement de carte. Vide l'historique : les
## coordonnées d'une carte ne veulent rien dire pour la suivante.
func reset(p_grid: Vector2i, spawn_p1: Vector2i, spawn_p2: Vector2i) -> void:
	grid_size = p_grid
	_spawns = [spawn_p1, spawn_p2]
	_undo_stack.clear()
	_redo_stack.clear()
	_pending = null
	_pending_seen.clear()
	history_changed.emit()

func get_spawn(index: int) -> Vector2i:
	return _spawns[clampi(index, 0, 1)]

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

# ---------------------------------------------------------------------------
# TRANSACTIONS
# ---------------------------------------------------------------------------

## Ouvre une transaction. Un appel imbriqué est ignoré : le geste en cours prime.
func begin(label: String) -> void:
	if _pending != null:
		return
	_pending = Transaction.new(label)
	_pending_seen.clear()

func is_open() -> bool:
	return _pending != null

## Ferme la transaction courante. Retourne false si rien n'a changé (aucune
## entrée d'historique n'est alors créée : annuler ne doit jamais « ne rien faire »).
func commit() -> bool:
	if _pending == null:
		return false

	var transaction := _pending
	_pending = null
	_pending_seen.clear()

	if transaction.is_empty():
		return false

	_undo_stack.append(transaction)
	while _undo_stack.size() > HISTORY_DEPTH:
		_undo_stack.pop_front()
	_redo_stack.clear()

	history_changed.emit()
	map_changed.emit()
	return true

## Abandonne la transaction courante en restaurant l'état d'avant.
func abort() -> void:
	if _pending == null:
		return
	var transaction := _pending
	_pending = null
	_pending_seen.clear()
	_revert(transaction)

# ---------------------------------------------------------------------------
# ANNULER / RÉTABLIR
# ---------------------------------------------------------------------------

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

## Libellé du prochain geste annulable, pour l'afficher à l'écran.
func peek_undo_label() -> String:
	return _undo_stack[_undo_stack.size() - 1].label if can_undo() else ""

func peek_redo_label() -> String:
	return _redo_stack[_redo_stack.size() - 1].label if can_redo() else ""

## Annule le dernier geste. Retourne son libellé, ou "" si la pile est vide.
func undo() -> String:
	if _undo_stack.is_empty():
		return ""
	var transaction: Transaction = _undo_stack.pop_back()
	_revert(transaction)
	_redo_stack.append(transaction)
	history_changed.emit()
	map_changed.emit()
	return transaction.label

## Rétablit le dernier geste annulé. Retourne son libellé, ou "".
func redo() -> String:
	if _redo_stack.is_empty():
		return ""
	var transaction: Transaction = _redo_stack.pop_back()
	_replay(transaction)
	_undo_stack.append(transaction)
	history_changed.emit()
	map_changed.emit()
	return transaction.label

func _revert(transaction: Transaction) -> void:
	# Ordre inverse : deux écritures sur la même cellule doivent se défaire
	# dans le sens opposé à leur application.
	for i in range(transaction.cells.size() - 1, -1, -1):
		var edit: CellEdit = transaction.cells[i]
		_write_cell(edit.layer, edit.cell, edit.before)
	for i in range(transaction.spawns.size() - 1, -1, -1):
		var edit: SpawnEdit = transaction.spawns[i]
		_write_spawn(edit.index, edit.before)

func _replay(transaction: Transaction) -> void:
	for edit in transaction.cells:
		_write_cell(edit.layer, edit.cell, edit.after)
	for edit in transaction.spawns:
		_write_spawn(edit.index, edit.after)

# ---------------------------------------------------------------------------
# ÉCRITURE BAS NIVEAU
# ---------------------------------------------------------------------------

func _layer_of(layer: StringName) -> TileMapLayer:
	return _walls_layer if layer == LAYER_WALLS else _floor_layer

func _write_cell(layer: StringName, cell: Vector2i, atlas: Vector2i) -> void:
	var target := _layer_of(layer)
	if target == null:
		return
	if atlas == EMPTY_ATLAS:
		target.erase_cell(cell)
	else:
		target.set_cell(cell, 0, atlas)

func _write_spawn(index: int, cell: Vector2i) -> void:
	_spawns[index] = cell
	spawn_moved.emit(index, cell)

## Coordonnée atlas actuelle d'une cellule, [constant EMPTY_ATLAS] si vide.
func atlas_at(layer: StringName, cell: Vector2i) -> Vector2i:
	var target := _layer_of(layer)
	if target == null:
		return EMPTY_ATLAS
	return target.get_cell_atlas_coords(cell)

func has_cell(layer: StringName, cell: Vector2i) -> bool:
	return atlas_at(layer, cell) != EMPTY_ATLAS

## Coordonnée atlas à poser sur une cellule pour le calque demandé.
func atlas_for(layer: StringName, cell: Vector2i) -> Vector2i:
	if layer == LAYER_WALLS:
		return CandelaTileSet.WALL_ATLAS
	return CandelaTileSet.get_floor_atlas(cell)

## Applique une valeur à une cellule en l'enregistrant dans la transaction.
## Retourne true si la cellule a réellement changé.
func apply_cell(layer: StringName, cell: Vector2i, atlas: Vector2i) -> bool:
	if not is_inside(cell):
		return false

	var before := atlas_at(layer, cell)
	if before == atlas:
		return false

	if _pending != null:
		var key := "%s:%d:%d" % [layer, cell.x, cell.y]
		if _pending_seen.has(key):
			# Cellule déjà enregistrée dans ce geste : on met simplement à jour
			# son état final, sans créer un second enregistrement.
			var index: int = _pending_seen[key]
			_pending.cells[index].after = atlas
		else:
			_pending_seen[key] = _pending.cells.size()
			_pending.cells.append(CellEdit.new(layer, cell, before, atlas))

	_write_cell(layer, cell, atlas)
	return true

# ---------------------------------------------------------------------------
# OUTILS DE DESSIN
# ---------------------------------------------------------------------------

## Pose ou efface une cellule unique.
func draw_cell(layer: StringName, cell: Vector2i, painting: bool) -> bool:
	var atlas := atlas_for(layer, cell) if painting else EMPTY_ATLAS
	var changed := apply_cell(layer, cell, atlas)
	if changed:
		cells_touched.emit([cell] as Array[Vector2i], layer, painting)
	return changed

## Trace un segment de cellules (Bresenham) — évite les trous quand le curseur
## se déplace vite d'une image à l'autre.
func draw_line(layer: StringName, from: Vector2i, to: Vector2i, painting: bool) -> int:
	var touched: Array[Vector2i] = []
	for cell in line_cells(from, to):
		var atlas := atlas_for(layer, cell) if painting else EMPTY_ATLAS
		if apply_cell(layer, cell, atlas):
			touched.append(cell)
	if not touched.is_empty():
		cells_touched.emit(touched, layer, painting)
	return touched.size()

## Remplit un rectangle défini par deux coins (inclus).
func draw_rect(layer: StringName, corner_a: Vector2i, corner_b: Vector2i, painting: bool) -> int:
	var r_min := Vector2i(mini(corner_a.x, corner_b.x), mini(corner_a.y, corner_b.y))
	var r_max := Vector2i(maxi(corner_a.x, corner_b.x), maxi(corner_a.y, corner_b.y))

	var touched: Array[Vector2i] = []
	for y in range(r_min.y, r_max.y + 1):
		for x in range(r_min.x, r_max.x + 1):
			var cell := Vector2i(x, y)
			var atlas := atlas_for(layer, cell) if painting else EMPTY_ATLAS
			if apply_cell(layer, cell, atlas):
				touched.append(cell)
	if not touched.is_empty():
		cells_touched.emit(touched, layer, painting)
	return touched.size()

## Pot de peinture : diffusion 4-directions bornée à la région connexe de même
## état que la cellule d'amorce, et aux limites de la grille.
func flood_fill(layer: StringName, seed_cell: Vector2i, painting: bool) -> int:
	if not is_inside(seed_cell):
		return 0

	var seed_filled := has_cell(layer, seed_cell)
	# Peindre une région déjà pleine (ou effacer une région déjà vide) n'a
	# aucun sens : on refuse plutôt que de produire une transaction vide.
	if seed_filled == painting:
		return 0

	var region: Array[Vector2i] = []
	var seen := {seed_cell: true}
	var queue: Array[Vector2i] = [seed_cell]

	while not queue.is_empty() and region.size() < FILL_LIMIT:
		var cell: Vector2i = queue.pop_back()
		region.append(cell)
		for offset in NEIGHBOURS_4:
			var next := cell + offset
			if seen.has(next) or not is_inside(next):
				continue
			if has_cell(layer, next) != seed_filled:
				continue
			seen[next] = true
			queue.append(next)

	var touched: Array[Vector2i] = []
	for cell in region:
		var atlas := atlas_for(layer, cell) if painting else EMPTY_ATLAS
		if apply_cell(layer, cell, atlas):
			touched.append(cell)
	if not touched.is_empty():
		cells_touched.emit(touched, layer, painting)
	return touched.size()

## Auto-mur : ceinture le sol dessiné d'un mur continu, en une seule passe.
## Voisinage 8 pour fermer aussi les angles diagonaux. Retourne le nombre de
## murs posés.
func auto_walls() -> int:
	if _floor_layer == null:
		return 0

	var floor_cells := _floor_layer.get_used_cells()
	if floor_cells.is_empty():
		return 0

	var is_floor := {}
	for cell in floor_cells:
		is_floor[cell] = true

	var candidates := {}
	for cell in floor_cells:
		for offset in NEIGHBOURS_8:
			var next: Vector2i = cell + offset
			if is_floor.has(next) or not is_inside(next):
				continue
			candidates[next] = true

	var touched: Array[Vector2i] = []
	for cell: Vector2i in candidates.keys():
		if apply_cell(LAYER_WALLS, cell, CandelaTileSet.WALL_ATLAS):
			touched.append(cell)
	if not touched.is_empty():
		cells_touched.emit(touched, LAYER_WALLS, true)
	return touched.size()

## Miroir : réunit la carte et son reflet. Une moitié dessinée devient une
## arène de duel parfaitement symétrique.
## Les apparitions se répondent : J2 est placée au reflet de J1.
func mirror(horizontal: bool) -> int:
	var touched_floor := _mirror_layer(LAYER_FLOOR, _floor_layer, horizontal)
	var touched_walls := _mirror_layer(LAYER_WALLS, _walls_layer, horizontal)

	if not touched_floor.is_empty():
		cells_touched.emit(touched_floor, LAYER_FLOOR, true)
	if not touched_walls.is_empty():
		cells_touched.emit(touched_walls, LAYER_WALLS, true)

	# Symétrie des apparitions : le duel doit rester équitable.
	var p1 := _spawns[0]
	if p1 != NO_CELL:
		var reflected_spawn := _reflect(p1, horizontal)
		if is_inside(reflected_spawn) and reflected_spawn != p1:
			set_spawn(1, reflected_spawn)

	return touched_floor.size() + touched_walls.size()

## Recopie un calque sur son reflet. Retourne les cellules réellement ajoutées.
func _mirror_layer(layer: StringName, node: TileMapLayer, horizontal: bool) -> Array[Vector2i]:
	var touched: Array[Vector2i] = []
	if node == null:
		return touched
	for cell in node.get_used_cells():
		var reflected := _reflect(cell, horizontal)
		if reflected == cell or not is_inside(reflected):
			continue
		if apply_cell(layer, reflected, atlas_for(layer, reflected)):
			touched.append(reflected)
	return touched

func _reflect(cell: Vector2i, horizontal: bool) -> Vector2i:
	if horizontal:
		return Vector2i(grid_size.x - 1 - cell.x, cell.y)
	return Vector2i(cell.x, grid_size.y - 1 - cell.y)

## Déplace un point d'apparition. Retourne true si la position a changé.
func set_spawn(index: int, cell: Vector2i) -> bool:
	var slot := clampi(index, 0, 1)
	if cell != NO_CELL and not is_inside(cell):
		return false
	var before := _spawns[slot]
	if before == cell:
		return false

	if _pending != null:
		_pending.spawns.append(SpawnEdit.new(slot, before, cell))
	_write_spawn(slot, cell)
	return true

## Efface tout le contenu des deux calques et déplace les apparitions hors carte.
func clear_all() -> int:
	var touched_floor: Array[Vector2i] = []
	var touched_walls: Array[Vector2i] = []

	if _floor_layer != null:
		for cell in _floor_layer.get_used_cells():
			if apply_cell(LAYER_FLOOR, cell, EMPTY_ATLAS):
				touched_floor.append(cell)
	if _walls_layer != null:
		for cell in _walls_layer.get_used_cells():
			if apply_cell(LAYER_WALLS, cell, EMPTY_ATLAS):
				touched_walls.append(cell)

	for i in 2:
		set_spawn(i, NO_CELL)

	if not touched_floor.is_empty():
		cells_touched.emit(touched_floor, LAYER_FLOOR, false)
	if not touched_walls.is_empty():
		cells_touched.emit(touched_walls, LAYER_WALLS, false)
	return touched_floor.size() + touched_walls.size()

# ---------------------------------------------------------------------------
# GÉOMÉTRIE
# ---------------------------------------------------------------------------

## Cellules d'un segment, algorithme de Bresenham entier.
static func line_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x := from.x
	var y := from.y
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx + dy

	while true:
		cells.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var err2 := err * 2
		if err2 >= dy:
			err += dy
			x += sx
		if err2 <= dx:
			err += dx
			y += sy
		# Garde-fou : un segment ne peut pas dépasser la diagonale de la grille.
		if cells.size() > 4096:
			break

	return cells
