## Test headless de la carte transmise par l'hôte — Phase 8, étape 8.8.
##
## Le défaut que cette suite verrouille est le plus coûteux du jeu à
## diagnostiquer : quand le client n'arrive pas à lire l'arène de l'hôte, la
## manche démarrait quand même. Chacun jouait alors sur sa propre géométrie —
## les balles traversant des murs absents chez l'un, la torche éclairant un
## couloir que l'autre n'a pas — et **les deux machines restaient parfaitement
## cohérentes avec elles-mêmes**. Aucun plantage, aucune erreur console, deux
## joueurs convaincus que l'autre triche.
##
## `adopt_shared_map()` est une fonction pure sur une chaîne : les cinq cas
## d'échec s'exercent donc sans réseau, sans EOS et sans seconde machine.
##
## Lancer : godot --headless --path . --script res://tools/test_carte_partagee.gd
extends SceneTree

var _failures: int = 0

## `MapData` est un autoload, donc absent en mode `--script` : on l'instancie à
## la main, comme le fait déjà `test_arena_build`. Aucune des méthodes exercées
## ici ne dépend de l'arbre de scène — `adopt_shared_map()` est une fonction pure
## sur une chaîne.
var _map: Node = null

func _init() -> void:
	print("=== Test de la carte transmise par l'hôte ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_map = preload("res://map_data.gd").new()
	_map.refresh_catalog()

	_test_aller_retour()
	_test_carte_absente_du_client()
	_test_code_vide()
	_test_code_tronque()
	_test_version_future()
	_test_grille_hors_bornes()
	_test_pas_de_trace_sur_disque()

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

## Le jeu d'essai dérive de la **vraie carte livrée**, et non d'un dictionnaire
## écrit à la main : un décor fabriqué ici finirait par diverger du format réel,
## et la suite validerait alors un format que le jeu n'écrit plus. La première
## version de ce fichier posait un `Vector2i` sous `grid_size` là où le format
## sur disque met `{"x":…, "y":…}` — elle échouait donc pour une raison qui
## n'apprenait rien.
func _carte(grille: Vector2i = Vector2i.ZERO) -> Dictionary:
	_map.select_map("default")
	var base: Dictionary = (_map.current_map_data as Dictionary).duplicate(true)
	if grille != Vector2i.ZERO:
		base["grid_size"] = {"x": grille.x, "y": grille.y}
	return base

# ---------------------------------------------------------------------------

## Le cas nominal, et il vaut d'être dit : **la carte voyage par valeur.** Ce
## n'est pas un identifiant qui transite mais la géométrie entière, compressée.
func _test_aller_retour() -> void:
	print("\n[Aller-retour]")
	var code := MapCodec.to_share_code(_carte())
	_check("un code de partage est produit", code.begins_with(MapCodec.SHARE_PREFIX),
		code.substr(0, 20))

	var decode := MapCodec.from_share_code(code)
	_check("et relu sans perte", bool(decode["ok"]), String(decode.get("error", "")))
	if bool(decode["ok"]):
		var data: Dictionary = decode["data"]
		_check("la grille survit au voyage",
			MapCodec.get_grid_size(data) == MapCodec.get_grid_size(_carte()), str(data.get("grid_size")))

## La question posée par Adrien : une carte qui n'existe que chez l'hôte. Elle
## n'est **jamais cherchée** dans le catalogue du client — donc son absence n'est
## pas un problème, c'est le principe.
func _test_carte_absente_du_client() -> void:
	print("\n[Carte inconnue du client]")
	var inedite := _carte(Vector2i(24, 24))
	inedite["id"] = "carte_qui_nexiste_nulle_part_ailleurs"
	inedite["name"] = "Dessinée il y a cinq minutes"

	_check("elle n'est pas au catalogue local",
		(_map.get_map(String(inedite["id"])) as Dictionary).is_empty())

	var err := String(_map.adopt_shared_map(MapCodec.to_share_code(inedite)))
	_check("et pourtant elle est adoptée", err == "", err)
	_check("la géométrie reçue est celle de l'hôte",
		MapCodec.get_grid_size(_map.current_map_data as Dictionary) == Vector2i(24, 24),
		str((_map.current_map_data as Dictionary).get("grid_size")))

## Le cas le plus sournois, parce qu'il ne disait rien du tout : la garde
## `if map_code != ""` traitait l'absence comme « rien à faire », et le client
## entrait dans la manche sur sa carte précédente, sans message.
func _test_code_vide() -> void:
	print("\n[Code vide]")
	var decode := MapCodec.from_share_code("")
	_check("un code vide ne décode pas", not bool(decode["ok"]))
	_check("adopter un code vide échoue", String(_map.adopt_shared_map("")) != "")

## Une chaîne coupée en deux : le gzip ne se termine pas.
##
## Ces trois cas font crier le moteur (« Decompression failed », « b64_decode »).
## Ce sont des `ERROR` et non des `SCRIPT ERROR` — le lanceur ne s'en émeut pas,
## et leur présence est justement la preuve que le garde-fou travaille.
func _test_code_tronque() -> void:
	print("\n[Code tronqué]")
	var code := MapCodec.to_share_code(_carte())
	var moitie := code.substr(0, code.length() / 2)
	_check("un code coupé est refusé", String(_map.adopt_shared_map(moitie)) != "")
	_check("et une chaîne quelconque aussi",
		String(_map.adopt_shared_map("CANDELA-pas-du-tout-un-code")) != "")
	_check("y compris sans le préfixe attendu",
		String(_map.adopt_shared_map("bonjour")) != "")

## Le seul cas **certain** d'arriver : deux builds, deux versions de codec. C'est
## lui qui rend l'étape 8.8 urgente plutôt que théorique — il se reproduira à
## chaque mise à jour publiée tant qu'il n'y a pas de mise à jour forcée.
func _test_version_future() -> void:
	print("\n[Version de codec plus récente]")
	var future := _carte()
	future["version"] = MapCodec.VERSION + 7
	var err := String(_map.adopt_shared_map(MapCodec.to_share_code(future)))
	# On ne teste pas *comment* il refuse, seulement qu'il ne fait pas semblant
	# d'avoir compris : un décodage optimiste donnerait deux géométries.
	_check("une version inconnue ne passe pas en silence", err != "", "err=«%s»" % err)

## Bornes de grille : `MIN_GRID` = 8, `MAX_GRID` = 128.
func _test_grille_hors_bornes() -> void:
	print("\n[Grille hors bornes]")
	var minuscule := _carte(Vector2i(4, 4))
	_check("une grille sous le minimum est refusée",
		String(_map.adopt_shared_map(MapCodec.to_share_code(minuscule))) != "",
		"MIN_GRID=%d" % MapCodec.MIN_GRID)

## Adopter n'installe rien. Le client joue la carte de l'hôte le temps du match
## et ne la garde pas : écrire silencieusement le fichier d'un inconnu dans
## `user://maps/` serait une décision qui ne nous appartient pas.
func _test_pas_de_trace_sur_disque() -> void:
	print("\n[Rien n'est écrit sur le disque]")
	var avant := int(_map.list_maps().size())
	var etrangere := _carte(Vector2i(20, 20))
	etrangere["id"] = "venue_dailleurs"
	_map.adopt_shared_map(MapCodec.to_share_code(etrangere))
	_map.refresh_catalog()
	_check("le catalogue local n'a pas grossi",
		int(_map.list_maps().size()) == avant,
		"%d → %d" % [avant, int(_map.list_maps().size())])
	_check("et la carte reçue n'y figure pas",
		(_map.get_map("venue_dailleurs") as Dictionary).is_empty())
