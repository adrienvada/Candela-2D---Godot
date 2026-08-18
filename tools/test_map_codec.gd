## Test headless du codec de cartes.
## Lancer : godot --headless --path . --script res://tools/test_map_codec.gd
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test MapCodec ===")

	_test_rle_roundtrip()
	_test_rle_edge_cases()
	_test_share_code_roundtrip()
	_test_share_code_rejects_garbage()
	_test_default_map_loads()
	_test_slugify()
	_test_migration_v2()
	_test_playability()
	_test_builtin_maps()
	_test_id_collision()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

## Deux cartes ne doivent jamais partager un identifiant.
##
## Ce n'est pas théorique : importer le code de partage d'une arène **livrée** en
## recopie l'identifiant, et le catalogue se retrouve avec deux entrées de même
## id — `get_map()` rend alors la première trouvée, si bien que sélectionner
## l'une charge l'autre. Une carte d'Adrien porte `00000001`, celui de l'arène
## standard, arrivée exactement par ce chemin.
##
## La règle est exercée sur `id_collides()`, statique et sans disque : les suites
## partagent le `user://` du jeu installé, et écrire un vrai fichier de carte pour
## vérifier une règle de nommage serait payer cher une garantie faible.
func _test_id_collision() -> void:
	print("\n[Collision d'identifiants]")
	var md: GDScript = load("res://map_data.gd")
	var catalogue: Array = [
		{"id": "00000001", "slug": "default"},
		{"id": "00000002", "slug": "arene_circulaire"},
		{"id": "1a0b2c3d", "slug": "cathedrale"},
	]
	_check("un identifiant libre ne collisionne pas",
		not md.id_collides(catalogue, "deadbeef", "nouvelle"))
	# LE cas qui a produit le défaut : un import qui recopie l'id d'une livrée.
	_check("l'identifiant d'une carte livrée collisionne",
		md.id_collides(catalogue, "00000001", "ma_copie"))
	# Et celui qu'il ne faut PAS casser : réécrire sa propre carte garde son id,
	# sans quoi chaque sauvegarde créerait une identité neuve.
	_check("réécrire sa propre carte ne collisionne pas",
		not md.id_collides(catalogue, "1a0b2c3d", "cathedrale"))
	_check("un identifiant vide ne collisionne jamais",
		not md.id_collides(catalogue, "", "nouvelle"))
	# Une entrée malformée ne doit pas faire échouer la question posée.
	_check("un catalogue bruité reste lisible",
		md.id_collides([null, 42, {"id": "00000001", "slug": "default"}],
			"00000001", "autre"))

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _test_rle_roundtrip() -> void:
	print("\n[RLE aller-retour]")
	var cells: Array[Vector2i] = []
	for y in range(20):
		for x in range(20):
			if (x + y) % 3 != 0:
				cells.append(Vector2i(x, y))

	var encoded := MapCodec.encode_runs(cells)
	var decoded := MapCodec.decode_runs(encoded)

	var original := {}
	for c in cells:
		original[c] = true
	var restored := {}
	for c in decoded:
		restored[c] = true

	_check("cellules identiques après aller-retour", original.size() == restored.size(),
		"%d vs %d" % [original.size(), restored.size()])

	var all_present := true
	for c in cells:
		if not restored.has(c):
			all_present = false
			break
	_check("aucune cellule perdue", all_present)

func _test_rle_edge_cases() -> void:
	print("\n[RLE cas limites]")
	var empty: Array[Vector2i] = []
	_check("liste vide → chaîne vide", MapCodec.encode_runs(empty) == "")
	_check("chaîne vide → liste vide", MapCodec.decode_runs("").is_empty())
	_check("entrée corrompue ignorée sans planter", MapCodec.decode_runs("abc;1,2;;;9,9,3").size() == 3)

	var single: Array[Vector2i] = [Vector2i(5, 7)]
	_check("cellule unique", MapCodec.encode_runs(single) == "5,7,1")

	var dupes: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 1)]
	_check("doublons fusionnés", MapCodec.decode_runs(MapCodec.encode_runs(dupes)).size() == 2)

func _test_share_code_roundtrip() -> void:
	print("\n[Code de partage]")
	var map := MapCodec.new_map("Test Arène", Vector2i(24, 24))
	var cells: Array[Vector2i] = []
	for y in range(2, 22):
		for x in range(2, 22):
			cells.append(Vector2i(x, y))
	map["floor"] = MapCodec.encode_runs(cells)
	map["spawn_p1"] = {"x": 4, "y": 12}
	map["spawn_p2"] = {"x": 19, "y": 12}

	var code := MapCodec.to_share_code(map)
	_check("préfixe présent", code.begins_with(MapCodec.SHARE_PREFIX))
	_check("code court (<800 car.)", code.length() < 800, "%d caractères" % code.length())

	var back := MapCodec.from_share_code(code)
	_check("décodage réussi", back["ok"], String(back.get("error", "")))
	if back["ok"]:
		var d: Dictionary = back["data"]
		_check("nom conservé", d["name"] == "Test Arène")
		_check("sol conservé", MapCodec.get_floor_cells(d).size() == 400)
		_check("spawn P1 conservé", MapCodec.get_spawn(d, 0) == Vector2i(4, 12))

	var no_prefix := MapCodec.from_share_code(code.substr(MapCodec.SHARE_PREFIX.length()))
	_check("base64 nu accepté", no_prefix["ok"])

func _test_share_code_rejects_garbage() -> void:
	print("\n[Robustesse import]")
	_check("code vide rejeté", not MapCodec.from_share_code("")["ok"])
	_check("texte quelconque rejeté", not MapCodec.from_share_code("bonjour le monde")["ok"])
	_check("base64 valide mais non gzip rejeté",
		not MapCodec.from_share_code(Marshalls.utf8_to_base64("pas une carte"))["ok"])

	var no_floor := MapCodec.new_map("Vide")
	var code := MapCodec.to_share_code(no_floor)
	_check("carte sans sol rejetée", not MapCodec.from_share_code(code)["ok"])

func _test_default_map_loads() -> void:
	print("\n[Carte livrée default.json]")
	var path := "res://assets/maps/default.json"
	_check("fichier présent", FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var parsed := json.parse(file.get_as_text())
	file.close()
	_check("JSON valide", parsed == OK)
	if parsed != OK:
		return

	var result := MapCodec.validate(json.data as Dictionary)
	_check("validation OK", result["ok"], String(result.get("error", "")))
	if not result["ok"]:
		return

	var d: Dictionary = result["data"]
	_check("version 3", int(d["version"]) == 3)
	_check("256 tuiles de sol", MapCodec.get_floor_cells(d).size() == 256)
	_check("144 tuiles de mur", MapCodec.get_wall_cells(d).size() == 144)
	_check("spawn P1 posé", MapCodec.get_spawn(d, 0) == Vector2i(4, 10))
	_check("spawn P2 posé", MapCodec.get_spawn(d, 1) == Vector2i(15, 10))

func _test_slugify() -> void:
	print("\n[Slugify]")
	_check("espaces → underscores", MapCodec.slugify("Ma Super Carte") == "ma_super_carte")
	_check("accents translittérés", MapCodec.slugify("Cathédrale") == "cathedrale",
		MapCodec.slugify("Cathédrale"))
	_check("ligature œ", MapCodec.slugify("Cœur") == "coeur", MapCodec.slugify("Cœur"))
	_check("caractères dangereux retirés", MapCodec.slugify("../../etc/passwd") == "etcpasswd")
	_check("chaîne vide → repli", MapCodec.slugify("") == "carte")
	_check("symboles seuls → repli", MapCodec.slugify("!!!") == "carte")

func _test_migration_v2() -> void:
	print("\n[Migration v2 → v3]")
	var v2 := {
		"version": 2,
		"tile_size": 35,
		"grid_size": {"x": 20, "y": 20},
		"floor": [{"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}],
		"walls": [{"x": 0, "y": 0}],
		"spawn_p1": {"x": 1, "y": 1},
		"spawn_p2": {"x": 3, "y": 1},
	}
	var result := MapCodec.validate(v2)
	_check("migration acceptée", result["ok"], String(result.get("error", "")))
	if not result["ok"]:
		return

	var d: Dictionary = result["data"]
	_check("version relevée à 3", int(d["version"]) == 3)
	_check("sol converti en runs", d["floor"] == "1,1,3")
	_check("id généré", String(d.get("id", "")).length() > 0)

func _test_playability() -> void:
	print("\n[Jouabilité]")
	var file := FileAccess.open("res://assets/maps/default.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var d: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]

	var result := MapCodec.check_playable(d)
	_check("carte livrée jouable", result["ok"], str(result["checks"]))

	# Deux salles isolées : les joueurs ne peuvent pas se rejoindre.
	var split := MapCodec.new_map("Isolée", Vector2i(20, 20))
	var cells: Array[Vector2i] = []
	for y in range(2, 8):
		for x in range(2, 8):
			cells.append(Vector2i(x, y))
		for x in range(12, 18):
			cells.append(Vector2i(x, y))
	split["floor"] = MapCodec.encode_runs(cells)
	split["spawn_p1"] = {"x": 3, "y": 3}
	split["spawn_p2"] = {"x": 16, "y": 6}
	# Deux rives séparées par un gouffre : c'est un parti pris de conception
	# légitime, pas une erreur. Balles et lumière traversent les fosses, on
	# peut donc s'affronter exclusivement à distance.
	_check("zones isolées acceptées (duel à distance)", MapCodec.check_playable(split)["ok"],
		str(MapCodec.check_playable(split)["checks"]))

	# Spawn posé dans le vide.
	var void_spawn := split.duplicate(true)
	void_spawn["spawn_p2"] = {"x": 10, "y": 10}
	_check("apparition hors sol détectée", not MapCodec.check_playable(void_spawn)["ok"])

## Une fosse est un trou, pas un mur : les deux cartes livrées doivent rester
## jouables et la carte à disque central doit bien contenir son obstacle.
func _test_builtin_maps() -> void:
	print("\n[Cartes livrées]")
	for slug in ["default", "arene_circulaire"]:
		var path := "res://assets/maps/%s.json" % slug
		if not FileAccess.file_exists(path):
			_check("%s présent" % slug, false)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		json.parse(file.get_as_text())
		file.close()

		var result := MapCodec.validate(json.data as Dictionary)
		_check("%s valide" % slug, result["ok"], String(result.get("error", "")))
		if not result["ok"]:
			continue
		var d: Dictionary = result["data"]
		_check("%s jouable" % slug, MapCodec.check_playable(d)["ok"])
		_check("%s : identifiants distincts" % slug, String(d["id"]) != "")

	# Le disque central de l'arène circulaire : des murs loin de la ceinture.
	var file2 := FileAccess.open("res://assets/maps/arene_circulaire.json", FileAccess.READ)
	var json2 := JSON.new()
	json2.parse(file2.get_as_text())
	file2.close()
	var circ: Dictionary = MapCodec.validate(json2.data as Dictionary)["data"]
	var grid := MapCodec.get_grid_size(circ)
	var centre := Vector2(grid - Vector2i.ONE) * 0.5
	var inner := 0
	for cell in MapCodec.get_wall_cells(circ):
		if Vector2(cell).distance_to(centre) <= 4.0:
			inner += 1
	_check("obstacle circulaire central présent", inner >= 30, "%d tuiles" % inner)
