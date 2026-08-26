## Test headless de la construction d'arène.
## Vérifie les hypothèses dont dépend game_state.rebuild_arena() :
##   • TileMapLayer.duplicate() conserve les tuiles (correctif écran partagé)
##   • _map_data.apply_to_layers() peint bien la carte sélectionnée
##   • MapGeometry.build_collisions() produit collisions ET occluders
##   • une reconstruction ne laisse aucun nœud orphelin (rematch)
##
## Lancer : godot --headless --path . --script res://tools/test_arena_build.gd
extends SceneTree

var _failures: int = 0
## MapData est un autoload : indisponible en mode --script, on l'instancie
## à la main. Aucune de ses méthodes ne dépend de l'arbre de scène.
var _map_data: Node = null

func _init() -> void:
	print("=== Test construction d'arène ===")

	_map_data = preload("res://map_data.gd").new()
	_map_data.refresh_catalog()
	_map_data.select_map("default")

	_test_layer_duplication_keeps_tiles()
	_test_apply_to_layers()
	_test_collisions_and_occluders()
	_test_rebuild_is_idempotent()
	_test_spawns_land_on_floor()

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

func _load_default() -> Dictionary:
	var file := FileAccess.open("res://assets/maps/default.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return MapCodec.validate(json.data as Dictionary)["data"]

func _make_layers() -> Array:
	var tileset := CandelaTileSet.create_tileset()
	var floor_layer := TileMapLayer.new()
	floor_layer.name = "CustomFloor"
	floor_layer.tile_set = tileset
	var walls_layer := TileMapLayer.new()
	walls_layer.name = "CustomWalls"
	walls_layer.tile_set = tileset
	return [floor_layer, walls_layer]

# ---------------------------------------------------------------------------

## Le correctif écran partagé duplique les calques pour donner à chaque joueur
## sa propre copie éclairée. Si duplicate() perdait les tuiles, les deux
## viewports afficheraient une arène vide.
func _test_layer_duplication_keeps_tiles() -> void:
	print("\n[Duplication de calque]")
	var layers := _make_layers()
	var source: TileMapLayer = layers[0]

	for x in range(5):
		for y in range(3):
			source.set_cell(Vector2i(x, y), 0, CandelaTileSet.get_floor_atlas(Vector2i(x, y)))
	_check("calque source peuplé", source.get_used_cells().size() == 15)

	var copy := source.duplicate() as TileMapLayer
	_check("duplicate() conserve les tuiles", copy.get_used_cells().size() == 15,
		"%d tuiles dans la copie" % copy.get_used_cells().size())
	_check("duplicate() conserve le TileSet", copy.tile_set != null)

	copy.visibility_layer = 2
	copy.light_mask = 1 | 16
	_check("masques indépendants de l'original",
		source.visibility_layer == 1 and source.light_mask == 1)

	source.free()
	copy.free()

func _test_apply_to_layers() -> void:
	print("\n[Application de la carte sur les calques]")
	var data := _load_default()
	var layers := _make_layers()
	var floor_layer: TileMapLayer = layers[0]
	var walls_layer: TileMapLayer = layers[1]

	var spawns := Node2D.new()
	for marker_name in ["P1Spawn", "P2Spawn"]:
		var marker := Marker2D.new()
		marker.name = marker_name
		spawns.add_child(marker)

	_map_data.apply_to_layers(floor_layer, walls_layer, spawns, data)

	_check("sol peint (576 tuiles)", floor_layer.get_used_cells().size() == 576,
		"%d" % floor_layer.get_used_cells().size())
	_check("murs peints (324 tuiles)", walls_layer.get_used_cells().size() == 324,
		"%d" % walls_layer.get_used_cells().size())

	# Un second appel ne doit pas cumuler avec le précédent.
	_map_data.apply_to_layers(floor_layer, walls_layer, spawns, data)
	_check("réapplication sans cumul", floor_layer.get_used_cells().size() == 576,
		"%d" % floor_layer.get_used_cells().size())

	floor_layer.free()
	walls_layer.free()
	spawns.free()

func _test_collisions_and_occluders() -> void:
	print("\n[Collisions et occlusion]")
	var data := _load_default()
	var arena := Node2D.new()

	var root := MapGeometry.build_collisions(data, arena)
	_check("conteneur de collision créé", root != null)

	var body := root.get_node("Murs") as StaticBody2D
	var pits := root.get_node("Fosses") as StaticBody2D

	var shapes := 0
	var occluders := 0
	for child in body.get_children():
		if child is CollisionShape2D:
			shapes += 1
		elif child is LightOccluder2D:
			occluders += 1

	_check("au moins une forme de collision", shapes > 0, "%d formes" % shapes)
	_check("autant d'occluders que de formes", shapes == occluders,
		"%d formes / %d occluders" % [shapes, occluders])
	_check("murs sur la couche testée par bullet.gd",
		body.collision_layer == MapGeometry.WALL_LAYER)
	_check("fosses sur une couche que les balles ignorent",
		pits.collision_layer == MapGeometry.PIT_LAYER)

	# Le point qui répare la mécanique centrale : sans occluder, la torche
	# traverse les murs et le jeu perd son sujet.
	var pit_occluders := 0
	for child in pits.get_children():
		if child is LightOccluder2D:
			pit_occluders += 1
	_check("une fosse est un trou, pas un mur : aucune ombre projetée",
		pit_occluders == 0, "%d occluders de trop" % pit_occluders)

	var all_have_polygons := true
	for child in body.get_children():
		if child is LightOccluder2D:
			var occ := child as LightOccluder2D
			if occ.occluder == null or occ.occluder.polygon.size() < 3:
				all_have_polygons = false
				break
	_check("chaque occluder porte un polygone valide", all_have_polygons)

	arena.free()

func _test_rebuild_is_idempotent() -> void:
	print("\n[Reconstruction — rematch]")
	var data := _load_default()
	var arena := Node2D.new()

	MapGeometry.build_collisions(data, arena)
	var after_first := arena.get_child_count()

	MapGeometry.build_collisions(data, arena)
	MapGeometry.build_collisions(data, arena)
	var after_third := arena.get_child_count()

	_check("aucun empilement de corps après 3 reconstructions",
		after_first == after_third, "%d puis %d enfants" % [after_first, after_third])

	var roots := 0
	for child in arena.get_children():
		if child.name == MapGeometry.BODY_NAME:
			roots += 1
	_check("un seul conteneur de collisions vivant", roots == 1, "%d conteneurs" % roots)

	arena.free()

## Une apparition qui tombe dans un mur bloquerait le joueur au démarrage.
func _test_spawns_land_on_floor() -> void:
	print("\n[Apparitions]")
	var data := _load_default()

	var floor_set := {}
	for c in MapCodec.get_floor_cells(data):
		floor_set[c] = true
	var wall_set := {}
	for c in MapCodec.get_wall_cells(data):
		wall_set[c] = true

	for i in 2:
		var cell := MapCodec.get_spawn(data, i)
		_check("apparition J%d sur du sol" % (i + 1), floor_set.has(cell), str(cell))
		_check("apparition J%d hors des murs" % (i + 1), not wall_set.has(cell), str(cell))

	var result := MapCodec.check_playable(data)
	_check("carte livrée déclarée jouable", result["ok"])
