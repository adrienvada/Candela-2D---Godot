## MapCodec — Encodage / décodage du format de carte Candela v3.
##
## Deux responsabilités :
##   1. Compression RLE des cellules (runs horizontaux) — une carte 20×20 pleine
##      passe de ~16 Ko en liste de dictionnaires à ~600 octets.
##   2. Code de partage court : JSON → gzip → base64, préfixé "CANDELA-".
##      Une carte complète tient dans ~300-500 caractères, collables dans un chat.
##
## Format RLE : "x,y,longueur;x,y,longueur;..."
##   Chaque run décrit une suite horizontale de cellules pleines sur la ligne y,
##   démarrant en x. Les runs sont triés par y puis par x.

class_name MapCodec
extends RefCounted

const VERSION := 3
const SHARE_PREFIX := "CANDELA-"
const MAX_GRID := 128
const MIN_GRID := 8
## Garde-fou anti-bombe de décompression sur les codes importés (8 Mo).
const MAX_DECOMPRESSED_BYTES := 8 << 20

# ---------------------------------------------------------------------------
# RLE
# ---------------------------------------------------------------------------

## Compresse une liste de cellules en runs horizontaux.
static func encode_runs(cells: Array[Vector2i]) -> String:
	if cells.is_empty():
		return ""

	var sorted_cells := cells.duplicate()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)

	var runs: PackedStringArray = []
	var run_x: int = sorted_cells[0].x
	var run_y: int = sorted_cells[0].y
	var run_len: int = 1

	for i in range(1, sorted_cells.size()):
		var c: Vector2i = sorted_cells[i]
		# Doublon exact : on ignore.
		if c.y == run_y and c.x == run_x + run_len - 1:
			continue
		# Continuité horizontale : on étend le run courant.
		if c.y == run_y and c.x == run_x + run_len:
			run_len += 1
			continue
		# Rupture : on ferme le run et on en ouvre un nouveau.
		runs.append("%d,%d,%d" % [run_x, run_y, run_len])
		run_x = c.x
		run_y = c.y
		run_len = 1

	runs.append("%d,%d,%d" % [run_x, run_y, run_len])
	return ";".join(runs)

## Décompresse une chaîne de runs en liste de cellules.
## Tolère les entrées malformées : un run invalide est ignoré, pas fatal.
static func decode_runs(encoded: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if encoded.is_empty():
		return cells

	for run in encoded.split(";", false):
		var parts := run.split(",", false)
		if parts.size() != 3:
			continue
		if not (parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int()):
			continue

		var x := int(parts[0])
		var y := int(parts[1])
		var length := int(parts[2])
		if length <= 0 or length > MAX_GRID:
			continue

		for i in range(length):
			cells.append(Vector2i(x + i, y))

	return cells

# ---------------------------------------------------------------------------
# CODE DE PARTAGE
# ---------------------------------------------------------------------------

## Sérialise une carte en code partageable court.
static func to_share_code(data: Dictionary) -> String:
	var json := JSON.stringify(data)
	var raw := json.to_utf8_buffer()
	var compressed := raw.compress(FileAccess.COMPRESSION_GZIP)
	return SHARE_PREFIX + Marshalls.raw_to_base64(compressed)

## Décode un code de partage.
## Retourne {ok: bool, data: Dictionary, error: String}.
## Toute entrée est traitée comme hostile : taille bornée puis validation stricte.
static func from_share_code(code: String) -> Dictionary:
	var cleaned := code.strip_edges()
	if cleaned.is_empty():
		return _fail("Code vide")

	# Le préfixe est optionnel à l'import — on accepte un base64 nu.
	if cleaned.begins_with(SHARE_PREFIX):
		cleaned = cleaned.substr(SHARE_PREFIX.length())
	# Les copier-coller depuis un chat introduisent souvent des retours à la ligne.
	cleaned = cleaned.replace("\n", "").replace("\r", "").replace(" ", "")

	var compressed := Marshalls.base64_to_raw(cleaned)
	if compressed.is_empty():
		return _fail("Code illisible (base64 invalide)")

	var raw := compressed.decompress_dynamic(MAX_DECOMPRESSED_BYTES, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return _fail("Code corrompu (décompression impossible)")

	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return _fail("Code corrompu (JSON invalide)")

	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("Format de carte non reconnu")

	return validate(json.data as Dictionary)

# ---------------------------------------------------------------------------
# VALIDATION & MIGRATION
# ---------------------------------------------------------------------------

## Valide et normalise une carte, en migrant depuis les versions antérieures.
## Retourne {ok: bool, data: Dictionary, error: String}.
static func validate(data: Dictionary) -> Dictionary:
	if not data.has("version"):
		return _fail("Version de carte absente")

	var version := int(data.get("version", 0))
	if version > VERSION:
		return _fail("Carte créée avec une version plus récente du jeu (v%d)" % version)

	var normalized := data.duplicate(true)
	if version < 3:
		normalized = migrate_v2_to_v3(normalized)

	# Grille : bornes strictes pour éviter une allocation absurde à la construction.
	#
	# Le type est vérifié avant d'être lu, et ce n'est pas une précaution de style :
	# `validate()` est la porte d'entrée de tout code reçu d'ailleurs — d'un
	# adversaire, d'un copier-coller. Une variable typée `Dictionary` recevant un
	# JSON qui met autre chose sous `grid_size` **jette une erreur de script** au
	# lieu de rendre le refus propre que toute la fonction s'applique à produire :
	# l'appelant reçoit `null`, et lit `["ok"]` dessus.
	var brut: Variant = normalized.get("grid_size", {})
	if typeof(brut) != TYPE_DICTIONARY:
		return _fail("Taille de grille illisible")
	var grid: Dictionary = brut
	var gx := int(grid.get("x", 0))
	var gy := int(grid.get("y", 0))
	if gx < MIN_GRID or gx > MAX_GRID or gy < MIN_GRID or gy > MAX_GRID:
		return _fail("Taille de grille invalide (%d×%d)" % [gx, gy])

	if not normalized.has("floor") or String(normalized["floor"]).is_empty():
		return _fail("La carte ne contient aucun sol")

	for key in ["spawn_p1", "spawn_p2"]:
		if not normalized.has(key):
			return _fail("Point d'apparition manquant : " + key)

	if not normalized.has("id") or String(normalized.get("id", "")).is_empty():
		normalized["id"] = generate_id()
	if not normalized.has("name") or String(normalized.get("name", "")).is_empty():
		normalized["name"] = "Carte sans nom"

	return {"ok": true, "data": normalized, "error": ""}

## Convertit le format v2 (listes de dictionnaires) vers le v3 (runs RLE).
static func migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)

	for key in ["floor", "walls"]:
		if out.has(key) and typeof(out[key]) == TYPE_ARRAY:
			var cells: Array[Vector2i] = []
			for cell in out[key]:
				if typeof(cell) == TYPE_DICTIONARY and cell.has("x") and cell.has("y"):
					cells.append(Vector2i(int(cell["x"]), int(cell["y"])))
			out[key] = encode_runs(cells)

	out["version"] = VERSION
	if not out.has("id"):
		out["id"] = generate_id()
	if not out.has("name"):
		out["name"] = "Carte importée"
	if not out.has("author"):
		out["author"] = ""
	if not out.has("created_utc"):
		out["created_utc"] = Time.get_datetime_string_from_system(true)

	return out

# ---------------------------------------------------------------------------
# FABRIQUE
# ---------------------------------------------------------------------------

## Crée une carte vide prête à être éditée.
static func new_map(map_name: String, grid_size: Vector2i = Vector2i(32, 32)) -> Dictionary:
	return {
		"version": VERSION,
		"id": generate_id(),
		"name": map_name,
		"author": "",
		"created_utc": Time.get_datetime_string_from_system(true),
		"grid_size": {"x": grid_size.x, "y": grid_size.y},
		"tile_size": CandelaTileSet.TILE_SIZE.x,
		"floor": "",
		"walls": "",
		"spawn_p1": {"x": -1, "y": -1},
		"spawn_p2": {"x": -1, "y": -1},
	}

## Identifiant court aléatoire (8 hex), stable sur toute la vie de la carte.
static func generate_id() -> String:
	return "%08x" % (randi() ^ int(Time.get_unix_time_from_system() * 1000.0))

## Translittération des caractères accentués courants — un nom français
## doit produire un nom de fichier lisible ("Cathédrale" → "cathedrale").
const ACCENT_MAP := {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a", "å": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "í": "i", "ì": "i",
	"ô": "o", "ö": "o", "ó": "o", "ò": "o", "õ": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ç": "c", "ñ": "n", "ÿ": "y", "ý": "y",
	"œ": "oe", "æ": "ae", "ß": "ss",
}

## Transforme un nom affiché en nom de fichier sûr.
static func slugify(map_name: String) -> String:
	var slug := map_name.strip_edges().to_lower()
	var out := ""
	for i in slug.length():
		var c := slug[i]
		if ACCENT_MAP.has(c):
			c = ACCENT_MAP[c]
		if c >= "a" and c <= "z" or c >= "0" and c <= "9" or c == "-" or c.length() > 1:
			out += c
		elif c == " " or c == "_":
			out += "_"
	# Un nom entièrement composé de symboles doit rester exploitable.
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	return out if not out.is_empty() else "carte"

# ---------------------------------------------------------------------------
# ACCÈS TYPÉ
# ---------------------------------------------------------------------------

## Même vigilance qu'en validation : ce lecteur sert aussi au balayage du
## catalogue, où un fichier abîmé à la main ferait tomber tout le scan.
static func get_grid_size(data: Dictionary) -> Vector2i:
	var brut: Variant = data.get("grid_size", {})
	if typeof(brut) != TYPE_DICTIONARY:
		return Vector2i(30, 30)
	var g: Dictionary = brut
	return Vector2i(int(g.get("x", 30)), int(g.get("y", 30)))

static func get_floor_cells(data: Dictionary) -> Array[Vector2i]:
	return decode_runs(String(data.get("floor", "")))

static func get_wall_cells(data: Dictionary) -> Array[Vector2i]:
	return decode_runs(String(data.get("walls", "")))

static func get_spawn(data: Dictionary, player_index: int) -> Vector2i:
	var key := "spawn_p1" if player_index == 0 else "spawn_p2"
	var s: Dictionary = data.get(key, {})
	return Vector2i(int(s.get("x", -1)), int(s.get("y", -1)))

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message}

# ---------------------------------------------------------------------------
# JOUABILITÉ
# ---------------------------------------------------------------------------

## Nombre minimal de tuiles de sol pour qu'un duel ait un sens.
const MIN_FLOOR_TILES := 20
## En deçà, les joueurs apparaissent quasiment l'un sur l'autre.
const MIN_SPAWN_DISTANCE := 8

## Contrôle qu'une carte est jouable, contrôle par contrôle.
## Retourne {ok: bool, checks: Array[{label, passed, blocking}]}.
## `ok` est faux dès qu'un contrôle bloquant échoue — l'éditeur s'en sert
## pour interdire la sauvegarde d'une carte cassée.
static func check_playable(data: Dictionary) -> Dictionary:
	var floor_cells := get_floor_cells(data)
	var wall_cells := get_wall_cells(data)
	var spawn1 := get_spawn(data, 0)
	var spawn2 := get_spawn(data, 1)

	# Ensemble des cases praticables : du sol, sans mur par-dessus.
	var walkable := {}
	for c in floor_cells:
		walkable[c] = true
	for c in wall_cells:
		walkable.erase(c)

	var checks: Array[Dictionary] = []

	checks.append({
		"label": "Sol dessiné (%d/%d tuiles)" % [floor_cells.size(), MIN_FLOOR_TILES],
		"passed": floor_cells.size() >= MIN_FLOOR_TILES,
		"blocking": true,
	})
	checks.append({
		"label": "Apparition J1 posée sur du sol",
		"passed": spawn1.x >= 0 and walkable.has(spawn1),
		"blocking": true,
	})
	checks.append({
		"label": "Apparition J2 posée sur du sol",
		"passed": spawn2.x >= 0 and walkable.has(spawn2),
		"blocking": true,
	})

	# Volontairement pas de contrôle de connexité : une carte peut légitimement
	# séparer les deux joueurs par un gouffre infranchissable, où l'on ne
	# s'affronte qu'à distance. Les balles et la lumière traversent les fosses.

	var far_enough := spawn1.x >= 0 and spawn2.x >= 0 \
		and Vector2(spawn1).distance_to(Vector2(spawn2)) >= MIN_SPAWN_DISTANCE
	checks.append({
		"label": "Apparitions suffisamment éloignées",
		"passed": far_enough,
		"blocking": false,
	})

	var ok := true
	for c in checks:
		if c["blocking"] and not c["passed"]:
			ok = false
			break

	return {"ok": ok, "checks": checks}

## Cases praticables réellement atteignables depuis l'apparition J1.
## Sert à mettre en évidence les zones orphelines dans l'éditeur.
static func get_reachable_cells(data: Dictionary) -> Dictionary:
	var walkable := {}
	for c in get_floor_cells(data):
		walkable[c] = true
	for c in get_wall_cells(data):
		walkable.erase(c)

	var start := get_spawn(data, 0)
	if start.x < 0 or not walkable.has(start):
		return {}

	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	const NEIGHBOURS: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset in NEIGHBOURS:
			var next := cell + offset
			if walkable.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)

	return seen
