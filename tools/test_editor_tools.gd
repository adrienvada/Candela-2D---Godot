## Test headless des outils d'édition : symétries et redimensionnement.
## Lancer : godot --headless --path . --script res://tools/test_editor_tools.gd
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test MapEditorTools ===")
	_test_symmetry_axes()
	_test_symmetry_is_involutive()
	_test_diagonal_requires_square()
	_test_resize_grow_keeps_everything()
	_test_resize_shrink_drops_overflow()

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

func _make_tools(grid: Vector2i) -> MapEditorTools:
	var tileset := CandelaTileSet.create_tileset()
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = tileset
	var walls_layer := TileMapLayer.new()
	walls_layer.tile_set = tileset
	var t := MapEditorTools.new()
	t.setup(floor_layer, walls_layer, grid)
	t.reset(grid, MapEditorTools.NO_CELL, MapEditorTools.NO_CELL)
	return t

func _test_symmetry_axes() -> void:
	print("\n[Axes de symétrie]")
	var t := _make_tools(Vector2i(20, 20))
	var S := MapEditorTools.Symmetry

	_check("horizontal", t.reflect(Vector2i(3, 5), S.HORIZONTAL) == Vector2i(16, 5),
		str(t.reflect(Vector2i(3, 5), S.HORIZONTAL)))
	_check("vertical", t.reflect(Vector2i(3, 5), S.VERTICAL) == Vector2i(3, 14),
		str(t.reflect(Vector2i(3, 5), S.VERTICAL)))
	_check("diagonale ↘ (transposition)", t.reflect(Vector2i(3, 5), S.DIAGONAL) == Vector2i(5, 3),
		str(t.reflect(Vector2i(3, 5), S.DIAGONAL)))
	_check("diagonale ↗", t.reflect(Vector2i(3, 5), S.ANTI_DIAGONAL) == Vector2i(14, 16),
		str(t.reflect(Vector2i(3, 5), S.ANTI_DIAGONAL)))
	_check("rotation 180°", t.reflect(Vector2i(3, 5), S.ROTATE_180) == Vector2i(16, 14),
		str(t.reflect(Vector2i(3, 5), S.ROTATE_180)))

## Appliquer deux fois le même axe doit ramener au point de départ : c'est ce
## qui garantit que la carte produite est réellement symétrique.
func _test_symmetry_is_involutive() -> void:
	print("\n[Involution]")
	var t := _make_tools(Vector2i(24, 24))
	var S := MapEditorTools.Symmetry
	for axis in [S.HORIZONTAL, S.VERTICAL, S.DIAGONAL, S.ANTI_DIAGONAL, S.ROTATE_180]:
		var ok := true
		for x in range(0, 24, 3):
			for y in range(0, 24, 3):
				var c := Vector2i(x, y)
				if t.reflect(t.reflect(c, axis), axis) != c:
					ok = false
					break
		_check("axe %d : double application = identité" % axis, ok)

	# Toute image doit rester dans la grille, sans quoi la symétrie perdrait
	# des carreaux au passage.
	var inside_ok := true
	for axis in [S.HORIZONTAL, S.VERTICAL, S.DIAGONAL, S.ANTI_DIAGONAL, S.ROTATE_180]:
		for x in 24:
			for y in 24:
				if not t.is_inside(t.reflect(Vector2i(x, y), axis)):
					inside_ok = false
					break
	_check("aucune image hors grille", inside_ok)

func _test_diagonal_requires_square() -> void:
	print("\n[Grille carrée]")
	var S := MapEditorTools.Symmetry
	var square := _make_tools(Vector2i(20, 20))
	var oblong := _make_tools(Vector2i(32, 16))

	_check("diagonale autorisée sur grille carrée", square.supports_symmetry(S.DIAGONAL))
	_check("diagonale refusée sur grille rectangulaire",
		not oblong.supports_symmetry(S.DIAGONAL))
	_check("rotation 180° autorisée partout", oblong.supports_symmetry(S.ROTATE_180))
	_check("miroir H autorisé partout", oblong.supports_symmetry(S.HORIZONTAL))

func _test_resize_grow_keeps_everything() -> void:
	print("\n[Agrandissement]")
	var t := _make_tools(Vector2i(20, 20))
	for x in range(2, 18):
		for y in range(2, 18):
			t.apply_cell(MapEditorTools.LAYER_FLOOR, Vector2i(x, y),
				CandelaTileSet.get_floor_atlas(Vector2i(x, y)))
	t.set_spawn(0, Vector2i(3, 3))
	t.set_spawn(1, Vector2i(16, 16))
	var before := t._floor_layer.get_used_cells().size()

	var removed := t.resize_grid(Vector2i(40, 40))
	_check("aucun carreau perdu en agrandissant", removed == 0, "%d perdus" % removed)
	_check("sol intact", t._floor_layer.get_used_cells().size() == before)
	_check("nouvelle grille appliquée", t.grid_size == Vector2i(40, 40), str(t.grid_size))
	_check("apparitions conservées",
		t.get_spawn(0) == Vector2i(3, 3) and t.get_spawn(1) == Vector2i(16, 16))
	_check("case lointaine désormais dans la grille", t.is_inside(Vector2i(39, 39)))

	# La borne haute du format doit être respectée.
	t.resize_grid(Vector2i(999, 999))
	_check("plafonné à MAX_GRID", t.grid_size == Vector2i(MapCodec.MAX_GRID, MapCodec.MAX_GRID),
		str(t.grid_size))

func _test_resize_shrink_drops_overflow() -> void:
	print("\n[Rétrécissement]")
	var t := _make_tools(Vector2i(20, 20))
	for x in 20:
		for y in 20:
			t.apply_cell(MapEditorTools.LAYER_FLOOR, Vector2i(x, y),
				CandelaTileSet.get_floor_atlas(Vector2i(x, y)))
	t.set_spawn(0, Vector2i(1, 1))
	t.set_spawn(1, Vector2i(18, 18))

	var removed := t.resize_grid(Vector2i(10, 10))
	_check("débordement effacé", removed == 400 - 100, "%d effacés" % removed)
	_check("il reste exactement la nouvelle grille",
		t._floor_layer.get_used_cells().size() == 100,
		"%d restants" % t._floor_layer.get_used_cells().size())

	var all_inside := true
	for cell in t._floor_layer.get_used_cells():
		if not t.is_inside(cell):
			all_inside = false
	_check("aucun carreau résiduel hors grille", all_inside)

	_check("apparition intérieure conservée", t.get_spawn(0) == Vector2i(1, 1))
	_check("apparition hors grille remise à zéro",
		t.get_spawn(1) == MapEditorTools.NO_CELL, str(t.get_spawn(1)))

	t.resize_grid(Vector2i(1, 1))
	_check("plancher à MIN_GRID", t.grid_size == Vector2i(MapCodec.MIN_GRID, MapCodec.MIN_GRID),
		str(t.grid_size))
