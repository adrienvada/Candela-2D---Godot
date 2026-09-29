## Les traces au sol ne survivent d'une manche à l'autre que contre le MÊME adversaire, sur la même carte, dans le même mode
## de jeu (Adrien, Q53, 2026-09-29 : « oui on efface le sang du match : un changement de mode de jeu efface le sang du
## match. En fait le sang du match ne se conserve que contre un même adversaire »).
##
## ## Pourquoi
##
## `balayer_les_traces_si_la_carte_change` ne retenait que la CARTE. Or l'écran de fin ouvre bien d'autres portes que
## « CHANGER DE CARTE » sans repasser par le menu principal (le seul qui balayait tout) : passer à l'entraînement, à
## l'écran scindé, ou — pour l'hôte, dont l'arène survit au départ de son adversaire — accueillir quelqu'un d'autre. Le
## sang d'un match contre A décorait alors l'entraînement, ou le duel contre B. `test_entrainement_carte` prouve le
## changement de carte ; celui-ci prouve les deux autres dimensions de la clé.
##
## ## Ce que la garde vérifie, sans rien rendre
##
## Un jeu monté (vue iso allumée), des traces posées par les poseurs du jeu, puis un changement de rencontre SANS repasser
## par le menu principal, chaque fois sur la MÊME carte :
##   • écran scindé, revanche : tout reste (les copies de peinture aussi) ;
##   • écran scindé → entraînement : tout part, copies J2 et copies de peinture comprises — la cible n'est pas un
##     adversaire ; puis entraînement → écran scindé : tout part ;
##   • écran scindé → lien en ligne d'hôte contre le pair 1001 : tout part ; la revanche contre le MÊME pair : tout
##     reste ; contre un AUTRE pair : tout part ; le premier qui revient ne retrouve rien — aucune mémoire ; puis l'invité,
##     puis l'écran scindé : tout part à chaque pas ;
##   • l'hôte ↔ l'entraînement, dans les deux sens : tout part.
##
## ⚠️ **Le lien en ligne est SIMULÉ, et sans une seule image de jeu sous le mode simulé** : `NetworkManager.current_mode`
## et `client_peer_id` sont posés le temps d'un `rebuild_arena()` synchrone, puis rendus. Une image sous `ONLINE_CLIENT`
## ferait émettre à P2 ses commandes (`rpc_id`) vers un pair qui n'existe pas. Les traces, elles, se posent en écran scindé,
## où les images sont sûres : la clé retenue est celle du dernier `rebuild_arena()`, pas du mode où l'on a posé.
##
## Lancer : godot --headless --path . --script res://tools/test_traces_rencontre.gd
extends SceneTree

const CLOITRE := "map_001"
const GROUPES := ["blood_stain", "blood_p2", "wall_impact", "wall_impact_p2", "bullet_casing", "casing_p2"]

var _failures := 0
var _verifications := 0
## Combien de poses de traces ont eu lieu : elles se distinguent par leur nom.
var _poses := 0
var _reseau: Node = null


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LES TRACES NE SURVIVENT QUE CONTRE LE MÊME ADVERSAIRE ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	var cartes := root.get_node("MapData")
	_reseau = root.get_node("NetworkManager")
	reglages.mode_iso = true
	_check("le Cloître est choisi", cartes.select_map(CLOITRE))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# --- Un match en écran scindé, des traces, puis la revanche : contre le même adversaire, tout reste.
	print("\n--- Écran scindé : la revanche garde tout ---")
	main.ui._intended_mode = _mode("LOCAL_SPLITSCREEN")
	main._on_replay_requested()
	_check("le match en écran scindé démarre", await _depart_fini(main))
	await _images(4)
	var p: Node = root.get_node_or_null("Presentation3D")
	await _poser_des_traces(main)
	var posees := _compter(main)
	_check("les traces du match sont posées (sang, éclat, douille, et leurs copies J2)",
		posees["blood_stain"] >= 2 and posees["wall_impact"] >= 1 and posees["bullet_casing"] >= 1
		and posees["blood_p2"] >= posees["blood_stain"] and posees["wall_impact_p2"] >= posees["wall_impact"],
		str(posees))
	var copies := _copies_de_peinture(p)
	_check("la peinture iso les a copiées", copies >= 3, "%d copies" % copies)
	main._start_round()
	_check("la revanche démarre", await _depart_fini(main))
	await _images(4)
	_check("revanche : toutes les traces restent", _compter(main) == posees, "%s → %s" % [str(posees), str(_compter(main))])
	_check("revanche : leurs copies de peinture restent", _copies_de_peinture(p) == copies,
		"%d → %d" % [copies, _copies_de_peinture(p)])

	# --- Écran scindé → entraînement, même carte : la cible n'est pas un adversaire.
	print("\n--- Écran scindé → entraînement ---")
	main._on_training_requested()
	await _images(4)
	_check("l'entraînement est armé, sur la même carte",
		main.training_mode and cartes.selected_map_id == String(cartes.get_map(CLOITRE)["id"]), cartes.selected_map_id)
	_check("entraînement : plus aucune trace du match, ni copie J2", _total(_compter(main)) == 0, str(_compter(main)))
	_check("entraînement : plus aucune copie de peinture", _copies_de_peinture(p) == 0, "%d copies" % _copies_de_peinture(p))
	_check("entraînement : les murs iso ne lisent plus aucun impact du match", _impacts_lus(p) == 0, str(_impacts_lus(p)))
	await _poser_des_traces(main)
	_check("des traces se posent à l'entraînement", _total(_compter(main)) > 0)

	# --- Entraînement → écran scindé.
	print("\n--- Entraînement → écran scindé ---")
	main._start_round()
	_check("le match qui suit l'entraînement démarre", await _depart_fini(main))
	await _images(4)
	_check("match : plus aucune trace de l'entraînement", _total(_compter(main)) == 0, str(_compter(main)))
	_check("match : plus aucune copie de peinture", _copies_de_peinture(p) == 0, "%d copies" % _copies_de_peinture(p))
	await _poser_des_traces(main)
	_check("des traces se posent au match", _total(_compter(main)) > 0)
	# La manche est finie : sans pair, rien ne doit plus partir en RPC de l'hôte simulé qui suit.
	main.round_active = false

	# --- Écran scindé → lien en ligne : contre le pair 1001, puis 1002, puis 1001 de nouveau.
	print("\n--- Écran scindé → en ligne : l'adversaire ---")
	_reconstruire_en_ligne(main, "ONLINE_HOST", 1001)
	_check("hôte, pair 1001 : plus aucune trace du match en écran scindé", _total(_compter(main)) == 0,
		str(_compter(main)))
	await _poser_des_traces(main)
	var contre_1001 := _compter(main)
	_check("des traces se posent contre le pair 1001", _total(contre_1001) > 0)
	_reconstruire_en_ligne(main, "ONLINE_HOST", 1001)
	_check("revanche contre le MÊME pair : toutes les traces restent", _compter(main) == contre_1001,
		"%s → %s" % [str(contre_1001), str(_compter(main))])
	_reconstruire_en_ligne(main, "ONLINE_HOST", 1002)
	_check("contre un AUTRE pair (1002) : plus aucune trace", _total(_compter(main)) == 0, str(_compter(main)))
	await _poser_des_traces(main)
	_check("des traces se posent contre le pair 1002", _total(_compter(main)) > 0)
	_reconstruire_en_ligne(main, "ONLINE_HOST", 1001)
	_check("le premier adversaire revient : ni ses traces d'avant, ni celles du second — aucune mémoire",
		_total(_compter(main)) == 0, str(_compter(main)))
	await _poser_des_traces(main)
	_reconstruire_en_ligne(main, "ONLINE_CLIENT", 0)
	_check("de l'hôte à l'invité : plus aucune trace", _total(_compter(main)) == 0, str(_compter(main)))
	await _poser_des_traces(main)
	_check("des traces se posent en invité", _total(_compter(main)) > 0)
	main.rebuild_arena()
	_check("de l'invité à l'écran scindé : plus aucune trace", _total(_compter(main)) == 0, str(_compter(main)))

	# --- En ligne ↔ entraînement : le dernier couple de modes.
	print("\n--- En ligne ↔ entraînement ---")
	await _poser_des_traces(main)
	_reconstruire_en_ligne(main, "ONLINE_HOST", 1001)
	_check("de l'écran scindé à l'hôte : plus aucune trace", _total(_compter(main)) == 0, str(_compter(main)))
	await _poser_des_traces(main)
	main._on_training_requested()
	await _images(4)
	_check("de l'hôte à l'entraînement : plus aucune trace", _total(_compter(main)) == 0, str(_compter(main)))
	await _poser_des_traces(main)
	_reconstruire_en_ligne(main, "ONLINE_HOST", 1001)
	_check("de l'entraînement à l'hôte : plus aucune trace", _total(_compter(main)) == 0, str(_compter(main)))

	_sortir()


## Un `rebuild_arena()` sous un lien en ligne simulé, et RIEN d'autre : le mode et le pair sont posés le temps de l'appel
## synchrone, puis rendus avant la première image (voir l'en-tête).
func _reconstruire_en_ligne(main: Node, mode: String, pair: int) -> void:
	_reseau.current_mode = _mode(mode)
	main.client_peer_id = pair
	main.rebuild_arena()
	_reseau.current_mode = _mode("LOCAL_SPLITSCREEN")
	main.client_peer_id = 0


## Les poseurs du jeu, tels quels : deux taches de sang par touche (`bullet.gd`, `_spawn_hit_effects`), un éclat de mur
## (`_spawn_wall_effects`), une douille au rechargement (`player.start_reload`). Les nœuds portent un nom explicite (règle
## du dépôt), une série par pose : deux poses ne se disputent jamais un nom.
func _poser_des_traces(main: Node) -> void:
	_poses += 1
	var arena: Node2D = main.arena
	var pos: Vector2 = main.p1.global_position + Vector2(40, 0)
	var flaque := Node2D.new()
	flaque.name = "FlaqueRencontre%d" % _poses
	flaque.set_script(preload("res://blood_stain.gd"))
	arena.add_child(flaque)
	flaque.setup(pos, Vector2.RIGHT, 0.0)
	var gerbe := Node2D.new()
	gerbe.name = "GerbeRencontre%d" % _poses
	gerbe.set_script(preload("res://blood_stain.gd"))
	arena.add_child(gerbe)
	gerbe.setup(pos, Vector2.RIGHT, 0.0, true)
	var eclat := Node2D.new()
	eclat.name = "EclatRencontre%d" % _poses
	eclat.set_script(preload("res://wall_impact.gd"))
	if eclat.setup(pos + Vector2(0, 30)):
		arena.add_child(eclat)
	else:
		eclat.free()
	# Une douille à chaque pose : un rechargement encore en cours n'en éjecterait pas.
	main.p1.is_reloading = false
	main.p1.current_ammo = 0
	main.p1.start_reload()
	# Les copies J2 naissent une image plus tard ; la douille doit s'immobiliser pour être peinte (en temps de jeu : sans
	# horloge fixe, 90 images headless peuvent durer moins que sa glissade).
	var fin := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < fin:
		var immobiles := true
		for d in root.get_tree().get_nodes_in_group("bullet_casing"):
			immobiles = immobiles and bool(d.get("at_rest"))
		if immobiles:
			break
		await process_frame
	for i in 10:
		await process_frame


## Les traces de l'arène, par groupe. Les copies de la peinture iso entrent aussi dans les groupes J2 : on ne compte ici que
## les enfants de l'arène.
func _compter(main: Node) -> Dictionary:
	var n := {}
	for g in GROUPES:
		var k := 0
		for t in root.get_tree().get_nodes_in_group(g):
			if t.get_parent() == main.arena:
				k += 1
		n[g] = k
	return n


func _total(compte: Dictionary) -> int:
	var total := 0
	for g in compte:
		total += int(compte[g])
	return total


func _copies_de_peinture(p: Node) -> int:
	if p == null or p.peinture() == null:
		return -1
	return (p.peinture().get("_copies") as Dictionary).size()


## Les impacts que les murs iso lisent : zéro quand plus aucun éclat n'est à l'écran.
func _impacts_lus(p: Node) -> int:
	var mat_mur: ShaderMaterial = p.get("_mat_mur") if p != null else null
	return int(mat_mur.get_shader_parameter("usure_impacts_n")) if mat_mur != null else -1


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			printerr("    la manche n'a pas démarré (round_active=%s, décompte=%s)" % [main.round_active, main.countdown_left])
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	return main.round_active


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _mode(nom: String) -> int:
	return int(_reseau.get_script().get_script_constant_map()["GameMode"][nom])


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
