## MapData — Autoload
## Catalogue des cartes, sélection de session, sauvegarde et partage.
##
## Emplacements :
##   res://assets/maps/<slug>.json  — cartes livrées avec le jeu (LECTURE SEULE)
##   user://maps/<slug>.json        — cartes créées par le joueur
##
## Règles de sauvegarde (corrige la perte de données de la v2) :
##   • Une carte = un fichier nommé. Plus de slot unique "custom" écrasé à chaque save.
##   • res://assets/maps/ n'est JAMAIS écrit. Les slugs livrés sont réservés.
##   • La lecture cherche res:// AVANT user:// — une carte livrée ne peut pas être masquée.
##   • Aucune adoption automatique au démarrage : la sélection démarre sur "default".
##
## Usage :
##   MapData.list_maps()            → catalogue complet pour la galerie
##   MapData.select_map(id)         → choix actif, conservé toute la session
##   MapData.get_selected()         → données de la carte à charger au prochain match
##   MapData.save_map(data, nom)    → écrit dans user://maps/
##   MapData.to_share_code(data)    → code court à copier
##   MapData.import_share_code(code)→ valide puis ajoute au catalogue

extends Node

signal catalog_changed
signal map_selected(map_id: String)

const DEFAULT_MAP_ID := "default"
const USER_MAPS_DIR := "user://maps"
const BUILTIN_MAPS_DIR := "res://assets/maps"

## Carte active pour le prochain match. Persiste toute la session.
var selected_map_id: String = DEFAULT_MAP_ID
## Données de la carte active (dictionnaire v3 validé).
var current_map_data: Dictionary = {}

var _catalog: Array[Dictionary] = []
var _builtin_slugs: PackedStringArray = []

## [Compat] Vrai dès qu'une carte est chargée. Tout passe désormais par le
## pipeline JSON, y compris l'arène standard.
var has_custom_map: bool:
	get:
		return not current_map_data.is_empty()

## [Compat] Alias de current_map_data pour l'ancien code appelant.
var custom_map_data: Dictionary:
	get:
		return current_map_data

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(USER_MAPS_DIR)
	refresh_catalog()
	# Sélection initiale : l'arène standard, jamais une carte utilisateur.
	select_map(DEFAULT_MAP_ID)

# ---------------------------------------------------------------------------
# CATALOGUE
# ---------------------------------------------------------------------------

## Relit les deux dossiers de cartes et reconstruit le catalogue.
func refresh_catalog() -> void:
	_catalog.clear()
	_builtin_slugs.clear()

	for entry in _scan_dir(BUILTIN_MAPS_DIR, "builtin"):
		_catalog.append(entry)
		_builtin_slugs.append(String(entry["slug"]))

	for entry in _scan_dir(USER_MAPS_DIR, "user"):
		# Une carte utilisateur ne peut pas masquer une carte livrée.
		if String(entry["slug"]) in _builtin_slugs:
			push_warning("MapData: carte utilisateur ignorée (nom réservé) : %s" % entry["slug"])
			continue
		_catalog.append(entry)

	catalog_changed.emit()

## Catalogue complet : [{id, slug, name, source, path, grid_size, floor_count, wall_count, data}]
func list_maps() -> Array[Dictionary]:
	return _catalog.duplicate()

func get_map(map_id: String) -> Dictionary:
	for entry in _catalog:
		if entry["id"] == map_id or entry["slug"] == map_id:
			return entry
	return {}

func _scan_dir(dir_path: String, source: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return entries

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var slug := file_name.trim_suffix(".json")
			var full_path := dir_path.path_join(file_name)
			var result := _read_map_file(full_path)
			if result["ok"]:
				var data: Dictionary = result["data"]
				entries.append({
					"id": String(data.get("id", slug)),
					"slug": slug,
					"name": String(data.get("name", slug)),
					"source": source,
					"path": full_path,
					"grid_size": MapCodec.get_grid_size(data),
					"floor_count": MapCodec.get_floor_cells(data).size(),
					"wall_count": MapCodec.get_wall_cells(data).size(),
					"data": data,
				})
			else:
				push_warning("MapData: carte illisible %s — %s" % [full_path, result["error"]])
		file_name = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0
	)
	return entries

# ---------------------------------------------------------------------------
# SÉLECTION
# ---------------------------------------------------------------------------

## Choisit la carte active pour les prochains matchs. Conservée toute la session.
## Une carte par son SLUG — le nom de fichier, sans extension.
##
## Réservé aux cartes livrées : `res://assets/maps/` est en lecture seule et ses
## slugs sont donc stables, là où deux cartes peuvent partager un identifiant
## (celui-ci vient du contenu du fichier, pas de son nom).
## L'identifiant est-il déjà porté par une carte AUTRE que celle-ci ?
##
## La comparaison se fait sur le slug, qui est l'identité de fichier : réécrire
## `cathedrale.json` doit pouvoir garder son identifiant, alors qu'une carte
## importée sous un autre nom ne le doit pas.
##
## Statique et sans état pour être exerçable sans toucher au disque — les suites
## partagent le `user://` du jeu installé, et écrire un vrai fichier de carte pour
## vérifier une règle de nommage serait payer cher une garantie faible.
static func id_collides(catalog: Array, id: String, slug: String) -> bool:
	if id.is_empty():
		return false
	for entry in catalog:
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry
		if String(e.get("id", "")) == id and String(e.get("slug", "")) != slug:
			return true
	return false

## Même question, posée au catalogue courant.
func id_taken_by_other(id: String, slug: String) -> bool:
	return id_collides(_catalog, id, slug)

func get_map_by_slug(slug: String) -> Dictionary:
	for entry in _catalog:
		if String(entry.get("slug", "")) == slug:
			return entry
	return {}

func select_map(map_id: String) -> bool:
	var entry := get_map(map_id)
	# `DEFAULT_MAP_ID` est un SLUG, pas un identifiant : l'arène livrée s'appelle
	# `default.json` mais porte `id: "00000001"` dans son contenu. La chercher par
	# identifiant ne la trouvait donc jamais, et tous les replis « retour à la
	# carte par défaut » échouaient en silence — le jeu paraissait pourtant y être
	# puisque `selected_map_id` vaut « default » à l'initialisation.
	#
	# Le slug est d'ailleurs la bonne clé pour une carte livrée : il vient du nom
	# de fichier, réservé par construction, là où l'identifiant vient du contenu
	# et peut entrer en collision avec celui d'une carte joueur.
	if entry.is_empty() and map_id == DEFAULT_MAP_ID:
		entry = get_map_by_slug(DEFAULT_MAP_ID)
	if entry.is_empty():
		# Repli sur l'arène standard plutôt que de laisser le jeu sans carte.
		if map_id != DEFAULT_MAP_ID:
			push_warning("MapData: carte introuvable '%s', repli sur '%s'" % [map_id, DEFAULT_MAP_ID])
			return select_map(DEFAULT_MAP_ID)
		push_error("MapData: aucune carte par défaut disponible")
		return false

	selected_map_id = String(entry["id"])
	current_map_data = (entry["data"] as Dictionary).duplicate(true)
	map_selected.emit(selected_map_id)
	return true

## Tire une arène au hasard et la rend active. Rend l'identifiant retenu, ou une
## chaîne vide si le catalogue est vide.
##
## Réservé à l'appariement automatique : personne n'y a choisi de carte, et
## laisser jouer celle du dernier match donnerait l'arène du joueur qui a cherché
## en dernier — c'est-à-dire un avantage à qui connaît sa carte par cœur. Seul
## l'hôte tire ; le client adopte la sienne par `rpc_start_round`, comme dans un
## salon à code.
##
## Le tirage porte sur tout le catalogue, cartes joueur comprises. C'est voulu :
## une carte importée est une carte, et la restreindre aux cartes livrées
## demanderait de trancher ce qu'est une carte « légitime » — question qui n'a pas
## à se poser tant qu'on joue entre gens qui se sont trouvés par une file.
func select_random_map() -> String:
	if _catalog.is_empty():
		return ""
	var entry: Dictionary = _catalog[randi() % _catalog.size()]
	var id := String(entry["id"])
	return id if select_map(id) else ""

## Données de la carte active, prêtes à être appliquées.
func get_selected() -> Dictionary:
	if current_map_data.is_empty():
		select_map(DEFAULT_MAP_ID)
	return current_map_data

# ---------------------------------------------------------------------------
# SAUVEGARDE
# ---------------------------------------------------------------------------

## Écrit une carte dans user://maps/. Refuse d'écraser une carte livrée.
## Retourne {ok: bool, error: String, path: String, id: String}.
func save_map(data: Dictionary, map_name: String, overwrite: bool = true) -> Dictionary:
	var clean_name := map_name.strip_edges()
	if clean_name.is_empty():
		return {"ok": false, "error": "Le nom de la carte est vide", "path": "", "id": ""}

	var slug := MapCodec.slugify(clean_name)
	if slug in _builtin_slugs:
		return {"ok": false, "error": "« %s » est un nom réservé au jeu" % clean_name, "path": "", "id": ""}

	var path := USER_MAPS_DIR.path_join(slug + ".json")
	if not overwrite and FileAccess.file_exists(path):
		return {"ok": false, "error": "Une carte « %s » existe déjà" % clean_name, "path": path, "id": ""}

	var out := data.duplicate(true)
	out["name"] = clean_name
	out["version"] = MapCodec.VERSION
	# Un identifiant absent est tiré ; un identifiant **déjà pris par une autre
	# carte** est retiré. Le second cas n'est pas théorique : importer le code de
	# partage d'une arène livrée en recopie l'identifiant, et le catalogue se
	# retrouve avec deux entrées de même id — `get_map()` rend alors la première
	# trouvée, si bien que sélectionner l'une charge l'autre. Une carte d'Adrien
	# porte ainsi `00000001`, celui de l'arène standard.
	#
	# On ne conserve donc l'identifiant fourni que s'il est libre : c'est ce qui
	# permet à un ré-import de la MÊME carte de garder son identité, sans laisser
	# deux cartes différentes la partager.
	var fourni := String(out.get("id", ""))
	if fourni.is_empty() or id_taken_by_other(fourni, slug):
		out["id"] = MapCodec.generate_id()
	if not out.has("created_utc"):
		out["created_utc"] = Time.get_datetime_string_from_system(true)

	var check := MapCodec.validate(out)
	if not check["ok"]:
		return {"ok": false, "error": String(check["error"]), "path": "", "id": ""}
	out = check["data"]

	DirAccess.make_dir_recursive_absolute(USER_MAPS_DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "Écriture impossible (%s)" % error_string(FileAccess.get_open_error()),
			"path": path, "id": "",
		}
	file.store_string(JSON.stringify(out, "\t"))
	file.close()

	refresh_catalog()
	return {"ok": true, "error": "", "path": path, "id": String(out["id"])}

## Supprime une carte utilisateur. Les cartes livrées sont protégées.
func delete_map(map_id: String) -> bool:
	var entry := get_map(map_id)
	if entry.is_empty() or entry["source"] != "user":
		return false

	if DirAccess.remove_absolute(String(entry["path"])) != OK:
		return false

	var was_selected := selected_map_id == String(entry["id"])
	refresh_catalog()
	if was_selected:
		select_map(DEFAULT_MAP_ID)
	return true

## Duplique une carte (y compris livrée) sous un nouveau nom. Retourne son id, ou "".
func duplicate_map(map_id: String, new_name: String) -> String:
	var entry := get_map(map_id)
	if entry.is_empty():
		return ""

	var copy := (entry["data"] as Dictionary).duplicate(true)
	copy["id"] = MapCodec.generate_id()
	copy["created_utc"] = Time.get_datetime_string_from_system(true)

	var result := save_map(copy, new_name)
	return String(result["id"]) if result["ok"] else ""

## Nom libre le plus proche de base_name ("Arène", "Arène 2", "Arène 3"…).
func suggest_unique_name(base_name: String) -> String:
	var taken: PackedStringArray = []
	for entry in _catalog:
		taken.append(String(entry["name"]).to_lower())

	if base_name.to_lower() not in taken:
		return base_name
	var i := 2
	while "%s %d" % [base_name, i] in taken:
		i += 1
	return "%s %d" % [base_name, i]

# ---------------------------------------------------------------------------
# PARTAGE
# ---------------------------------------------------------------------------

func to_share_code(data: Dictionary = {}) -> String:
	return MapCodec.to_share_code(data if not data.is_empty() else current_map_data)

func from_share_code(code: String) -> Dictionary:
	return MapCodec.from_share_code(code)

## Importe un code de partage et l'enregistre dans user://maps/.
## Retourne {ok: bool, error: String, id: String, name: String}.
func import_share_code(code: String) -> Dictionary:
	var decoded := MapCodec.from_share_code(code)
	if not decoded["ok"]:
		return {"ok": false, "error": String(decoded["error"]), "id": "", "name": ""}

	var data: Dictionary = decoded["data"]
	# Identité neuve : deux joueurs important la même carte ne doivent pas
	# se retrouver avec des fichiers qui se recouvrent.
	data["id"] = MapCodec.generate_id()
	var import_name := suggest_unique_name(String(data.get("name", "Carte importée")))

	var result := save_map(data, import_name)
	if not result["ok"]:
		return {"ok": false, "error": String(result["error"]), "id": "", "name": ""}

	return {"ok": true, "error": "", "id": String(result["id"]), "name": import_name}

# ---------------------------------------------------------------------------
# TILEMAP ↔ DONNÉES
# ---------------------------------------------------------------------------

## Lit l'état des calques d'édition et produit un dictionnaire de carte v3.
func extract_from_layers(floor_layer: TileMapLayer, walls_layer: TileMapLayer,
		spawns: Node2D, base: Dictionary = {}) -> Dictionary:
	var data := base.duplicate(true) if not base.is_empty() else MapCodec.new_map("Carte sans nom")

	var floor_cells: Array[Vector2i] = []
	floor_cells.assign(floor_layer.get_used_cells())
	var wall_cells: Array[Vector2i] = []
	wall_cells.assign(walls_layer.get_used_cells())

	data["floor"] = MapCodec.encode_runs(floor_cells)
	data["walls"] = MapCodec.encode_runs(wall_cells)
	data["version"] = MapCodec.VERSION
	data["tile_size"] = CandelaTileSet.TILE_SIZE.x

	if spawns != null:
		data["spawn_p1"] = _extract_spawn(spawns, "P1Spawn", floor_layer)
		data["spawn_p2"] = _extract_spawn(spawns, "P2Spawn", floor_layer)

	return data

func _extract_spawn(spawns: Node2D, node_name: String, layer: TileMapLayer) -> Dictionary:
	var node := spawns.get_node_or_null(node_name) as Node2D
	# Les spawns non posés sont parqués hors écran par l'éditeur.
	if node == null or node.global_position.x < -500.0:
		return {"x": -1, "y": -1}
	var cell := layer.local_to_map(layer.to_local(node.global_position))
	return {"x": cell.x, "y": cell.y}

## Peint une carte sur les calques (visuel uniquement).
## La physique et l'occlusion sont produites par MapGeometry.build_collisions().
func apply_to_layers(floor_layer: TileMapLayer, walls_layer: TileMapLayer,
		spawns: Node2D, data: Dictionary = {}) -> void:
	var map: Dictionary = data if not data.is_empty() else get_selected()

	floor_layer.clear()
	walls_layer.clear()

	for cell in MapCodec.get_floor_cells(map):
		# DA2.6 — huit orientations tirées de la position. Voir
		# `CandelaTileSet.orientation()` : coût nul, et déterministe pour que les
		# deux machines d'un match voient le même sol.
		floor_layer.set_cell(cell, 0, CandelaTileSet.get_floor_atlas(cell),
			CandelaTileSet.orientation(cell))

	for cell in MapCodec.get_wall_cells(map):
		walls_layer.set_cell(cell, 0, CandelaTileSet.WALL_ATLAS)

	if spawns == null:
		return

	for i in 2:
		var node := spawns.get_node_or_null("P1Spawn" if i == 0 else "P2Spawn") as Node2D
		if node == null:
			continue
		var cell := MapCodec.get_spawn(map, i)
		if cell.x < 0:
			node.global_position = Vector2(-1000, -1000)
		else:
			node.global_position = floor_layer.to_global(floor_layer.map_to_local(cell))

## Position monde du point d'apparition, avec repli au centre du sol si absent.
func get_spawn_world_position(player_index: int, layer: TileMapLayer,
		data: Dictionary = {}) -> Vector2:
	var map: Dictionary = data if not data.is_empty() else get_selected()
	var cell := MapCodec.get_spawn(map, player_index)

	if cell.x < 0:
		var floor_cells := MapCodec.get_floor_cells(map)
		if floor_cells.is_empty():
			return Vector2.ZERO
		cell = floor_cells[0] if player_index == 0 else floor_cells[floor_cells.size() - 1]

	return layer.to_global(layer.map_to_local(cell))

# ---------------------------------------------------------------------------
# RÉSEAU
# ---------------------------------------------------------------------------

## Code compact de la carte active, à transmettre à un client par RPC.
func get_map_share_code() -> String:
	return MapCodec.to_share_code(current_map_data)

## Adopte une carte reçue de l'hôte, sans l'écrire sur le disque.
func adopt_shared_map(code: String) -> String:
	var decoded := MapCodec.from_share_code(code)
	if not decoded["ok"]:
		return String(decoded["error"])
	current_map_data = decoded["data"]
	selected_map_id = String(current_map_data.get("id", "distante"))
	map_selected.emit(selected_map_id)
	return ""

# ---------------------------------------------------------------------------
# PRIVÉ
# ---------------------------------------------------------------------------

func _read_map_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "Fichier introuvable"}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}, "error": "Lecture impossible"}
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "data": {}, "error": "JSON invalide ligne %d" % json.get_error_line()}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "Format non reconnu"}

	return MapCodec.validate(json.data as Dictionary)

# ---------------------------------------------------------------------------
# COMPAT — supprimé une fois game_state.gd et map_editor.gd migrés
# ---------------------------------------------------------------------------

## @deprecated Utiliser select_map().
func load_map(map_name: String) -> String:
	return "" if select_map(map_name) else "Carte introuvable : " + map_name

## @deprecated Utiliser MapGeometry.build_collisions() — cette version ne
## génère aucun LightOccluder2D, donc la torche traverse les murs.
func build_wall_collisions(walls_layer: TileMapLayer, parent: Node) -> Node2D:
	var existing := parent.get_node_or_null("CustomWallBodies")
	if existing != null:
		existing.queue_free()

	var container := Node2D.new()
	container.name = "CustomWallBodies"
	parent.add_child(container)

	var tile_size := Vector2(CandelaTileSet.TILE_SIZE)
	for cell in walls_layer.get_used_cells():
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.global_position = walls_layer.to_global(walls_layer.map_to_local(cell))

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = tile_size
		shape.shape = rect
		body.add_child(shape)
		container.add_child(body)

	return container
