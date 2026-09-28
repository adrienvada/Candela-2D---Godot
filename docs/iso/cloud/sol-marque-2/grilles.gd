## Sol marqué 2 — la géométrie des six cartes livrées, pour `lecture.py` : les boîtes de murs hauts (les rectangles fusionnés
## que `IsoGeometrie.build_meshes` extrude), les murets, et les cases de sol libre. Headless.
##     godot --headless --path . --script res://docs/iso/cloud/sol-marque-2/grilles.gd -- --sortie=/chemin/grilles.json
extends SceneTree


func _init() -> void:
	var sortie := "user://grilles.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	var out := {}
	var fichiers := Array(DirAccess.get_files_at("res://assets/maps")).filter(func(f): return String(f).ends_with(".json"))
	fichiers.sort()
	for f in fichiers:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
		var hauts := []
		for r in IsoGeometrie.rects_px(d, MapGeometry.Kind.WALLS):
			hauts.append([r.position.x, r.position.y, r.size.x, r.size.y])
		var bas := []
		for r in IsoGeometrie.rects_px(d, MapGeometry.Kind.LOW_WALLS):
			bas.append([r.position.x, r.position.y, r.size.x, r.size.y])
		var sol := []
		var murs := {}
		for c in MapCodec.get_wall_cells(d):
			murs[c] = true
		for c in MapCodec.get_floor_cells(d):
			if not murs.has(c):
				sol.append([c.x, c.y])
		var g := MapCodec.get_grid_size(d)
		out[String(f).get_basename()] = {"id": String(d.get("id", "")), "grille": [g.x, g.y], "hauts": hauts, "bas": bas,
			"sol": sol, "tuile": CandelaTileSet.TILE_SIZE.x, "pied": IsoMateriaux.PIED_FACE_PX,
			"lisere": IsoMateriaux.LISERE_SOMMET_PX}
	var fa := FileAccess.open(sortie, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out))
	fa.close()
	print("grilles : %s" % sortie)
	quit(0)
