## L'USINE EST SYMÉTRIQUE (Adrien, 2026-09-29 : « Oui corrige l'usine », à la question « L'Usine n'est pas exactement symétrique
## (son bloc central est décalé d'une case) : la laisser, ou la corriger ? »).
##
## ## Ce que la carte avait
##
## Livrée le 2026-09-07 (`b4bc38d`) et jamais retouchée depuis : les deux blocs centraux de l'Usine — 3 cases de large, x de 15 à 17,
## rangées 9-10 et 15-16 — ne se répondaient pas dans le miroir gauche-droite (x → 31 − x) qui échange les apparitions (5, 13) et
## (26, 13) : sur une grille de 32 de large l'axe passe ENTRE deux colonnes, et un bloc de 3 ne peut pas s'y centrer. Quatre cases de
## mur (17, 9) (17, 10) (17, 15) (17, 16) n'avaient pas d'image, et quatre cases de sol (14, ·) n'avaient pas la leur. Le banc d'équité
## d'ISO14 le voyait déjà : à 0°, les moitiés cachaient 9,68 % et 10,71 % du sol (écart 1,03, le critère (a) veut 1 au plus).
##
## ## Ce qu'elle a
##
## Les blocs font 4 de large (x de 14 à 17) : chaque mur posé par le dessinateur est gardé, et l'image manquante est ajoutée — la
## symétrisation par UNION, qui ne retire rien. (Les blocs de 2 auraient été symétriques aussi, et aussi équitables au banc ; c'est un
## choix de dessin, pas de mathématique — voir la ROADMAP.) Écrite au format COURANT du codec (v4, `low_walls` vide, runs canoniques).
## L'identité ne bouge pas : même fichier, même slug `map_002_l_usine`, même id `map_002`, même nom — c'est ce que l'historique des
## matchs, la galerie et `MapData.get_map()` retrouvent.
##
## ## Ce que la suite prouve
##
## - **la symétrie** : murs ET sol invariants par le miroir gauche-droite, les apparitions s'échangent, et le miroir haut-bas d'avant
##   tient toujours ;
## - **la garde rougit** : sur l'ancienne Usine (les deux chaînes de runs d'origine, gardées ICI comme témoin), elle relève exactement
##   les quatre murs et les quatre cases de sol d'avant — une garde qui ne saurait pas rougir ne prouverait rien ;
## - **la correction est celle-là et rien d'autre** : l'Usine d'aujourd'hui = l'ancienne + les quatre murs de la colonne 14 − les quatre
##   sols qu'ils couvrent ;
## - **le format** : le codec la lit sans migration à faire, ses runs sont canoniques (`encode_runs(decode_runs(s)) == s`), elle est
##   jouable, et son code de partage se relit à l'identique ;
## - **le jeu en ligne** : la carte de l'hôte voyage PAR SON CONTENU (`_host_map_code()` dans `rpc_start_round`, adoptée par
##   `adopt_shared_map`), jamais lue chez l'invité par son slug — deux versions qui se rencontreraient jouent l'Usine DE L'HÔTE, sans
##   désaccord de géométrie. Si ce chemin changeait un jour (un slug au lieu d'un contenu), cette suite rougit : la correction de
##   l'Usine deviendrait alors une affaire de version du fil.
##
## Lancer : godot --headless --path . --script res://tools/test_usine_symetrie.gd
extends SceneTree

const CHEMIN := "res://assets/maps/map_002_l_usine.json"
const PLANCHER := 25

## L'Usine d'AVANT, telle que livrée le 2026-09-07 : le témoin sur lequel la garde doit rougir.
const ANCIEN_SOL := "3,3,26;3,4,26;3,5,26;3,6,5;10,6,12;24,6,5;3,7,5;10,7,12;24,7,5;3,8,5;10,8,12;24,8,5;3,9,5;10,9,5;18,9,4;24,9,5;3,10,12;18,10,11;3,11,26;3,12,9;20,12,9;3,13,9;20,13,9;3,14,26;3,15,12;18,15,11;3,16,5;10,16,5;18,16,4;24,16,5;3,17,5;10,17,12;24,17,5;3,18,5;10,18,12;24,18,5;3,19,5;10,19,12;24,19,5;3,20,26;3,21,26;3,22,26"
const ANCIEN_MURS := "0,0,32;0,1,32;0,2,32;0,3,3;29,3,3;0,4,3;29,4,3;0,5,3;29,5,3;0,6,3;8,6,2;22,6,2;29,6,3;0,7,3;8,7,2;22,7,2;29,7,3;0,8,3;8,8,2;22,8,2;29,8,3;0,9,3;8,9,2;15,9,3;22,9,2;29,9,3;0,10,3;15,10,3;29,10,3;0,11,3;29,11,3;0,12,3;12,12,8;29,12,3;0,13,3;12,13,8;29,13,3;0,14,3;29,14,3;0,15,3;15,15,3;29,15,3;0,16,3;8,16,2;15,16,3;22,16,2;29,16,3;0,17,3;8,17,2;22,17,2;29,17,3;0,18,3;8,18,2;22,18,2;29,18,3;0,19,3;8,19,2;22,19,2;29,19,3;0,20,3;29,20,3;0,21,3;29,21,3;0,22,3;29,22,3;0,23,32;0,24,32;0,25,32"

## Les quatre cases de mur sans image, et les quatre cases de sol sans image, de l'ancienne Usine.
const MURS_SANS_IMAGE := [Vector2i(17, 9), Vector2i(17, 10), Vector2i(17, 15), Vector2i(17, 16)]
const SOLS_SANS_IMAGE := [Vector2i(14, 9), Vector2i(14, 10), Vector2i(14, 15), Vector2i(14, 16)]

var _echecs := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ %s" % label)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== L'USINE EST SYMÉTRIQUE ===")
	await process_frame
	var brut := _lire(CHEMIN)
	_check("le fichier de l'Usine se lit", not brut.is_empty())
	if brut.is_empty():
		_terminer()
		return
	var lu := MapCodec.validate(brut)
	_check("le codec courant l'accepte", bool(lu["ok"]), String(lu.get("error", "")))
	if not bool(lu["ok"]):
		_terminer()
		return
	var d: Dictionary = lu["data"]

	print("\n— l'identité ne bouge pas")
	_check("même fichier : map_002_l_usine.json (le slug, réservé, par lequel le catalogue la retrouve)",
		CHEMIN.get_file() == "map_002_l_usine.json")
	_check("même id (map_002) et même nom (« L Usine »)", String(d.get("id", "")) == "map_002" and String(d.get("name", "")) == "L Usine",
		"%s / %s" % [d.get("id", ""), d.get("name", "")])
	var grille := MapCodec.get_grid_size(d)
	_check("mêmes dimensions (32 × 26, tuile 35) et mêmes apparitions ((5, 13) et (26, 13))",
		grille == Vector2i(32, 26) and int(d.get("tile_size", 0)) == 35
		and MapCodec.get_spawn(d, 0) == Vector2i(5, 13) and MapCodec.get_spawn(d, 1) == Vector2i(26, 13))

	print("\n— la symétrie")
	var murs := MapCodec.get_wall_cells(d)
	var sol := MapCodec.get_floor_cells(d)
	_check("murs : chaque mur a son image par le miroir gauche-droite", _sans_image(murs, grille.x, false).is_empty(),
		str(_sans_image(murs, grille.x, false)))
	_check("sol : chaque case de sol a la sienne", _sans_image(sol, grille.x, false).is_empty(), str(_sans_image(sol, grille.x, false)))
	_check("les apparitions s'échangent par ce miroir",
		_miroir(MapCodec.get_spawn(d, 0), grille.x) == MapCodec.get_spawn(d, 1)
		and _miroir(MapCodec.get_spawn(d, 1), grille.x) == MapCodec.get_spawn(d, 0))
	_check("le miroir haut-bas d'avant tient toujours (murs)", _sans_image(murs, grille.y, true).is_empty(),
		str(_sans_image(murs, grille.y, true)))
	_check("le miroir haut-bas d'avant tient toujours (sol)", _sans_image(sol, grille.y, true).is_empty(),
		str(_sans_image(sol, grille.y, true)))
	_check("aucune case n'est à la fois mur et sol", _inter(murs, sol).is_empty(), str(_inter(murs, sol)))

	print("\n— la garde rougit sur l'ancienne Usine")
	var ancien_murs := MapCodec.decode_runs(ANCIEN_MURS)
	var ancien_sol := MapCodec.decode_runs(ANCIEN_SOL)
	var sans_mur := _sans_image(ancien_murs, grille.x, false)
	var sans_sol := _sans_image(ancien_sol, grille.x, false)
	_check("ancienne : quatre murs sans image, (17, 9) (17, 10) (17, 15) (17, 16)", _memes(sans_mur, MURS_SANS_IMAGE), str(sans_mur))
	_check("ancienne : quatre cases de sol sans image, (14, 9) (14, 10) (14, 15) (14, 16)", _memes(sans_sol, SOLS_SANS_IMAGE), str(sans_sol))
	_check("ancienne : les apparitions s'échangeaient déjà (c'était le seul miroir de la carte)",
		_miroir(Vector2i(5, 13), grille.x) == Vector2i(26, 13))
	# Une mutation d'aujourd'hui : un seul des quatre murs ajoutés retiré, et la garde le voit.
	var mutee: Array[Vector2i] = murs.duplicate()
	mutee.erase(Vector2i(14, 9))
	_check("mutation : retirer un seul mur de la colonne 14 rend la carte asymétrique",
		_memes(_sans_image(mutee, grille.x, false), [Vector2i(17, 9)]), str(_sans_image(mutee, grille.x, false)))

	print("\n— la correction est celle-là, et rien d'autre")
	var ajoutes := _sans(murs, ancien_murs)
	var retires := _sans(ancien_murs, murs)
	var sols_retires := _sans(ancien_sol, sol)
	var sols_ajoutes := _sans(sol, ancien_sol)
	_check("murs : les quatre images de la colonne 14 sont ajoutées", _memes(ajoutes, SOLS_SANS_IMAGE), str(ajoutes))
	_check("murs : aucun mur posé par le dessinateur n'est retiré", retires.is_empty(), str(retires))
	_check("sol : les quatre cases que les murs couvrent sortent du sol", _memes(sols_retires, SOLS_SANS_IMAGE), str(sols_retires))
	_check("sol : aucune case n'est ajoutée", sols_ajoutes.is_empty(), str(sols_ajoutes))
	var blocs_ok := true
	for y in [9, 10, 15, 16]:
		for x in range(14, 18):
			blocs_ok = blocs_ok and murs.has(Vector2i(x, y))
		blocs_ok = blocs_ok and not murs.has(Vector2i(13, y)) and not murs.has(Vector2i(18, y))
	_check("les deux blocs centraux font 4 de large (x de 14 à 17), sur les rangées 9-10 et 15-16", blocs_ok)

	print("\n— le format courant du codec")
	_check("les runs du sol sont canoniques (encode_runs(decode_runs(s)) == s)", MapCodec.encode_runs(sol) == String(brut.get("floor", "")),
		MapCodec.encode_runs(sol))
	_check("les runs des murs sont canoniques", MapCodec.encode_runs(murs) == String(brut.get("walls", "")), MapCodec.encode_runs(murs))
	_check("écrite en v%d, sans murs bas, comme `MapCodec.new_map` la ferait" % MapCodec.VERSION,
		int(brut.get("version", 0)) == MapCodec.VERSION and String(brut.get("low_walls", "?")) == ""
		and MapCodec.get_low_wall_cells(d).is_empty())
	_check("jouable (le contrôle de l'éditeur)", bool(MapCodec.check_playable(d)["ok"]), str(MapCodec.check_playable(d)["checks"]))

	print("\n— le jeu en ligne : la carte de l'hôte voyage par son contenu")
	var code := MapCodec.to_share_code(d)
	var relue := MapCodec.from_share_code(code)
	_check("le code de partage de l'Usine se relit à l'identique (ce que l'invité adopte)",
		bool(relue["ok"]) and MapCodec.encode_runs(MapCodec.get_wall_cells(relue["data"])) == MapCodec.encode_runs(murs)
		and MapCodec.encode_runs(MapCodec.get_floor_cells(relue["data"])) == MapCodec.encode_runs(sol))
	var jeu := FileAccess.get_file_as_string("res://game_state.gd")
	var carte := FileAccess.get_file_as_string("res://map_data.gd")
	_check("l'hôte envoie SA carte à chaque manche : `rpc_start_round.rpc(…, _host_map_code(), …)`",
		jeu.contains("rpc_start_round.rpc(w1_idx, w2_idx, _host_map_code(), _new_match_id())")
		and jeu.contains("return MapData.get_map_share_code()"))
	_check("l'invité l'adopte par son contenu, et refuse la manche s'il ne le peut pas : `adopt_shared_map`, jamais un slug lu chez lui",
		jeu.contains("return MapData.adopt_shared_map(map_code)") and carte.contains("func adopt_shared_map(code: String) -> String:")
		and carte.contains("MapCodec.from_share_code(code)") and jeu.contains("func _refuse_match_on_map(reason: String) -> void:"))
	_check("le témoin du fil ne lit que la version du codec, pas le contenu des cartes livrées : la version de la carte ne change pas le fil",
		FileAccess.get_file_as_string("res://tools/test_protocole.gd").contains("morceaux.append(\"mapcodec=%d\" % MapCodec.VERSION)"))

	_terminer()


func _terminer() -> void:
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _lire(chemin: String) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data as Dictionary


## L'image d'une case par le miroir gauche-droite d'une grille de `largeur` colonnes.
func _miroir(c: Vector2i, largeur: int) -> Vector2i:
	return Vector2i(largeur - 1 - c.x, c.y)


## Les cases dont l'image par le miroir n'est pas dans l'ensemble. `haut_bas` : le miroir haut-bas (y → n − 1 − y, n = la
## taille donnée) au lieu du gauche-droite.
func _sans_image(cases: Array[Vector2i], taille: int, haut_bas: bool) -> Array[Vector2i]:
	var ensemble := {}
	for c in cases:
		ensemble[c] = true
	var sans: Array[Vector2i] = []
	for c in cases:
		var image := Vector2i(c.x, taille - 1 - c.y) if haut_bas else Vector2i(taille - 1 - c.x, c.y)
		if not ensemble.has(image):
			sans.append(c)
	sans.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return sans


## Les cases de `a` qui ne sont pas dans `b`.
func _sans(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var ensemble := {}
	for c in b:
		ensemble[c] = true
	var out: Array[Vector2i] = []
	for c in a:
		if not ensemble.has(c):
			out.append(c)
	out.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return x.y < y.y or (x.y == y.y and x.x < y.x))
	return out


func _inter(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var ensemble := {}
	for c in b:
		ensemble[c] = true
	var out: Array[Vector2i] = []
	for c in a:
		if ensemble.has(c):
			out.append(c)
	return out


## Les deux listes contiennent-elles les mêmes cases (l'ordre ne compte pas) ?
func _memes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for c in a:
		if not b.has(c):
			return false
	return true
