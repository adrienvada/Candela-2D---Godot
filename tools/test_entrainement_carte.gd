## L'entraînement se joue sur la carte que le joueur a CHOISIE, et les traces au sol ne suivent pas d'une carte à l'autre
## (Adrien, 2026-09-29, Q38 : « l'entraînement doit se dérouler dans la carte sélectionnée par le joueur. Pas de mémoire
## des taches de sang : à chaque changement de carte, les taches de sang sont effacées »).
##
## ## Pourquoi
##
## `GameState._on_training_requested()` rappelait `MapData.select_map(DEFAULT_MAP_ID)` : l'écran d'entraînement offrait
## « CHANGER DE CARTE » et son affiche annonçait la carte choisie, mais c'est l'arène standard qui s'ouvrait, quoi que le
## joueur ait pris. Aucune suite ne posait la question — `test_entrainement` (`test_online_match --training`) vérifiait,
## au contraire, que la sélection était ramenée à la carte par défaut : c'était la règle, elle est retournée.
##
## ## Ce que la garde vérifie, sans rien rendre
##
## Le vrai `_on_training_requested()`, sur un jeu monté (vue iso allumée, comme un joueur) :
##   • pour CHAQUE carte livrée : la choisir puis lancer l'entraînement — la sélection ne bouge pas, et l'arène posée est
##     celle de la carte (cases du sol et des murs, point d'apparition de J1, cible au point d'apparition de J2) ;
##   • une sélection qui n'est pas au catalogue — la carte d'un hôte adoptée en ligne (`MapData.adopt_shared_map`) — n'est le
##     choix de personne : l'arène standard, comme avant cette décision ;
##   • les traces qui durent (sang, éclats de mur, douilles, leurs copies J2 et les copies de la peinture iso) partent quand
##     la carte de l'entraînement change, y compris SANS repasser par le menu principal (le seul chemin qui les balayait) ;
##     elles ne reviennent pas quand on retourne sur la carte d'où elles venaient — aucune mémoire d'une carte à l'autre ;
##   • par le menu principal et par les gestes du joueur : quitter l'entraînement, ouvrir l'écran d'entraînement, y prendre
##     une carte (la vignette de la galerie), lancer — l'arène qui s'ouvre est celle que l'affiche annonçait.
##
## Lancer : godot --headless --path . --script res://tools/test_entrainement_carte.gd
extends SceneTree

const CLOITRE := "map_001"
const CROISEE := "map_003"
const BUNKER := "map_004"
const GROUPES := ["blood_stain", "blood_p2", "wall_impact", "wall_impact_p2", "bullet_casing", "casing_p2"]

var _failures := 0
var _verifications := 0
## Combien de poses de traces ont eu lieu : elles se distinguent par leur nom.
var _poses := 0


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
	print("=== L'ENTRAÎNEMENT JOUE LA CARTE CHOISIE ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	var cartes := root.get_node("MapData")
	reglages.mode_iso = true
	var standard: Dictionary = cartes.get_map_by_slug(cartes.DEFAULT_MAP_ID)
	_check("l'arène standard est au catalogue", not standard.is_empty())
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# --- (a) Chaque carte livrée : choisie, puis jouée.
	print("\n--- La carte choisie est celle qui s'ouvre ---")
	var livrees: Array[Dictionary] = []
	for entree in cartes.list_maps():
		if String(entree["source"]) == "builtin":
			livrees.append(entree)
	_check("le catalogue livre plusieurs cartes", livrees.size() >= 3, str(livrees.size()))
	for entree in livrees:
		var id := String(entree["id"])
		var nom := String(entree["name"])
		if id != String(standard.get("id", "")):
			_check("« %s » se distingue de l'arène standard (sans quoi la garde ne discrimine rien)" % nom,
				_signature(entree) != _signature(standard), str(_signature(entree)))
		_check("« %s » : la carte est choisie" % nom, cartes.select_map(id))
		main._on_training_requested()
		await _images(3)
		_check("« %s » : l'entraînement est armé, sans manche" % nom,
			main.training_mode and main.sandbox_mode and not main.round_active)
		_check("« %s » : la sélection n'a pas bougé" % nom, cartes.selected_map_id == id,
			"%s au lieu de %s" % [cartes.selected_map_id, id])
		var ecart := _ecart_arene(main, entree)
		_check("« %s » : l'arène posée est celle de la carte" % nom, ecart == "", ecart)

	# --- (a bis) Une sélection qui n'est pas au catalogue n'est le choix de personne : l'arène standard.
	print("\n--- La carte d'un hôte, adoptée en ligne, n'est pas un choix ---")
	var etrangere: Dictionary = (cartes.get_map(BUNKER)["data"] as Dictionary).duplicate(true)
	etrangere["id"] = "ETRANGERE"
	etrangere["name"] = "Carte d'un hôte"
	var erreur: String = cartes.adopt_shared_map(cartes.to_share_code(etrangere))
	_check("la carte de l'hôte est adoptée", erreur == "", erreur)
	_check("elle est la sélection, mais n'est pas au catalogue",
		cartes.selected_map_id == "ETRANGERE" and cartes.get_map("ETRANGERE").is_empty(), cartes.selected_map_id)
	main._on_training_requested()
	await _images(3)
	_check("l'entraînement retombe sur l'arène standard",
		cartes.selected_map_id == String(standard.get("id", "")), cartes.selected_map_id)
	var ecart_etrangere := _ecart_arene(main, standard)
	_check("et c'est bien elle qui est posée", ecart_etrangere == "", ecart_etrangere)

	# --- (b) Les traces ne suivent pas d'une carte à l'autre.
	print("\n--- Les traces suivent la carte, sans mémoire ---")
	_check("le Cloître est choisi", cartes.select_map(CLOITRE))
	main._on_training_requested()
	await _images(4)
	await _poser_des_traces(main)
	var cloitre := _compter(main)
	_check("les traces du Cloître sont posées (sang, éclat, douille, et leurs copies J2)",
		cloitre["blood_stain"] >= 2 and cloitre["wall_impact"] >= 1 and cloitre["bullet_casing"] >= 1
		and cloitre["blood_p2"] >= cloitre["blood_stain"] and cloitre["wall_impact_p2"] >= cloitre["wall_impact"],
		str(cloitre))
	var p: Node = root.get_node_or_null("Presentation3D")
	_check("la peinture iso les a copiées", _copies_de_peinture(p) >= 3, "%d copies" % _copies_de_peinture(p))

	# Le geste : choisir une autre carte, relancer l'entraînement — sans repasser par le menu principal.
	_check("la Croisée est choisie", cartes.select_map(CROISEE))
	main._on_training_requested()
	await _images(4)
	var croisee := _compter(main)
	_check("Croisée : plus aucune trace du Cloître, ni copie J2", _total(croisee) == 0, str(croisee))
	_check("Croisée : plus aucune copie de peinture", _copies_de_peinture(p) == 0,
		"%d copies" % _copies_de_peinture(p))
	var mat_mur: ShaderMaterial = p.get("_mat_mur") if p != null else null
	_check("Croisée : les murs iso ne lisent plus aucun impact du Cloître",
		mat_mur != null and int(mat_mur.get_shader_parameter("usure_impacts_n")) == 0,
		str(mat_mur.get_shader_parameter("usure_impacts_n")) if mat_mur != null else "pas de matériau")
	_check("Croisée : l'arène posée est celle de la Croisée",
		_ecart_arene(main, cartes.get_map(CROISEE)) == "", _ecart_arene(main, cartes.get_map(CROISEE)))

	# La vie continue, et la carte d'où l'on vient ne redonne rien : ni ses traces, ni celles de la Croisée.
	await _poser_des_traces(main)
	var neuves := _compter(main)
	_check("Croisée : de nouvelles traces se posent et se copient",
		neuves["blood_stain"] >= 2 and neuves["blood_p2"] >= neuves["blood_stain"], str(neuves))
	_check("le Cloître est rechoisi", cartes.select_map(CLOITRE))
	main._on_training_requested()
	await _images(4)
	var retour := _compter(main)
	_check("retour au Cloître : ni ses traces d'avant, ni celles de la Croisée — aucune mémoire",
		_total(retour) == 0, str(retour))
	_check("retour au Cloître : plus aucune copie de peinture", _copies_de_peinture(p) == 0,
		"%d copies" % _copies_de_peinture(p))

	# Par le menu principal, et par les gestes du joueur : quitter l'entraînement, ouvrir l'écran d'entraînement,
	# y prendre une autre carte (la vignette de la galerie), lancer.
	await _poser_des_traces(main)
	_check("des traces sont posées avant de quitter l'entraînement", _total(_compter(main)) > 0)
	main._on_main_menu_requested()
	await _images(4)
	_check("quitter l'entraînement balaie les traces", _total(_compter(main)) == 0, str(_compter(main)))
	var ui: Node = main.ui
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	var bunker: Dictionary = cartes.get_map(BUNKER)
	ui.map_gallery._on_tile_pressed(BUNKER)
	await _images(2)
	_check("l'affiche de l'écran d'entraînement annonce le Bunker",
		String(ui.map_card_name.text) == String(bunker["name"]), String(ui.map_card_name.text))
	ui._on_hub_action("entrainement")
	await _images(4)
	_check("Bunker : l'entraînement s'ouvre sur ce que l'affiche annonçait",
		main.training_mode and _ecart_arene(main, bunker) == "", _ecart_arene(main, bunker))
	_check("Bunker : aucune trace en arrivant", _total(_compter(main)) == 0, str(_compter(main)))
	_check("et l'affiche annonce toujours le Bunker", String(ui.map_card_name.text) == String(bunker["name"]),
		String(ui.map_card_name.text))

	cartes.select_map(cartes.DEFAULT_MAP_ID)
	_sortir()


## Ce qui distingue une carte d'une autre pour cette garde : cases du sol, cases de murs, apparitions.
func _signature(entree: Dictionary) -> Array:
	var data: Dictionary = entree["data"]
	return [int(entree["floor_count"]), int(entree["wall_count"]),
		MapCodec.get_spawn(data, 0), MapCodec.get_spawn(data, 1)]


## La première divergence entre l'arène posée et la carte donnée, ou "" si tout concorde : le sol et les murs posés,
## J1 à son point d'apparition, la cible d'entraînement à celui de J2.
func _ecart_arene(main: Node, entree: Dictionary) -> String:
	var sol := main.arena.get_node_or_null("CustomFloor") as TileMapLayer
	var murs := main.arena.get_node_or_null("CustomWalls") as TileMapLayer
	if sol == null or murs == null:
		return "les calques de l'arène sont absents"
	if sol.get_used_cells().size() != int(entree["floor_count"]):
		return "sol : %d cases posées, %d attendues" % [sol.get_used_cells().size(), int(entree["floor_count"])]
	if murs.get_used_cells().size() != int(entree["wall_count"]):
		return "murs : %d cases posées, %d attendues" % [murs.get_used_cells().size(), int(entree["wall_count"])]
	var cartes := root.get_node("MapData")
	var data: Dictionary = entree["data"]
	var attendu_j1: Vector2 = cartes.get_spawn_world_position(0, sol, data)
	if main.p1.global_position.distance_to(attendu_j1) > 1.0:
		return "J1 en %s, apparition attendue en %s" % [main.p1.global_position, attendu_j1]
	var attendu_j2: Vector2 = cartes.get_spawn_world_position(1, sol, data)
	if main.training_target.global_position.distance_to(attendu_j2) > 1.0:
		return "cible en %s, apparition de J2 attendue en %s" % [main.training_target.global_position, attendu_j2]
	return ""


## Les poseurs du jeu, tels quels : deux taches de sang par touche (`bullet.gd`, `_spawn_hit_effects`), un éclat de mur
## (`_spawn_wall_effects`), une douille au rechargement (`player.start_reload`). Les nœuds portent un nom explicite (règle
## du dépôt), une série par pose : deux poses ne se disputent jamais un nom.
func _poser_des_traces(main: Node) -> void:
	_poses += 1
	var arena: Node2D = main.arena
	var pos: Vector2 = main.p1.global_position + Vector2(40, 0)
	var flaque := Node2D.new()
	flaque.name = "FlaqueEssai%d" % _poses
	flaque.set_script(preload("res://blood_stain.gd"))
	arena.add_child(flaque)
	flaque.setup(pos, Vector2.RIGHT, 0.0)
	var gerbe := Node2D.new()
	gerbe.name = "GerbeEssai%d" % _poses
	gerbe.set_script(preload("res://blood_stain.gd"))
	arena.add_child(gerbe)
	gerbe.setup(pos, Vector2.RIGHT, 0.0, true)
	var eclat := Node2D.new()
	eclat.name = "EclatEssai%d" % _poses
	eclat.set_script(preload("res://wall_impact.gd"))
	if eclat.setup(pos + Vector2(0, 30)):
		arena.add_child(eclat)
	else:
		eclat.free()
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


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
