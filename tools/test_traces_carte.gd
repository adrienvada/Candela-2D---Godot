## Les traces au sol suivent la carte : balayées quand elle change, gardées à la revanche (session cloud « restes »,
## 2026-09-28).
##
## ## Pourquoi
##
## Sang, éclats de mur et douilles durent le match entier, revanche comprise (`blood_stain.gd`) ; seul le retour au
## menu principal les balayait. Or l'écran de fin permet de CHANGER DE CARTE sans y repasser : les traces du Cloître
## restaient à leurs coordonnées sur la Croisée — un éclat de mur flottant au milieu d'une salle, du sang dans un mur —,
## et la peinture iso, qui les copie, les faisait lire aux murs de la nouvelle carte. Mesuré à l'image par
## `tools/photo_restes.gd` (RAPPORT restes, § 1).
##
## ## Ce que la garde vérifie, sans rien rendre
##
## Une partie locale en écran scindé, vue iso allumée, sur le Cloître ; des traces posées par les poseurs du jeu (les
## gestes de `bullet.gd` et de `player.start_reload`), leurs copies J2 comprises ; puis une manche neuve par le démarrage
## de REJOUER (`_start_round`) :
##   • sur la même carte (la revanche) : toutes les traces restent, et leurs copies de peinture aussi ;
##   • sur la Croisée : plus aucune trace, ni copie J2, ni copie de peinture ; les murs iso ne lisent plus d'impact ;
##   • puis une trace neuve sur la Croisée se pose et se copie normalement.
##
## Lancer : godot --headless --path . --script res://tools/test_traces_carte.gd
extends SceneTree

const CLOITRE := "map_001"
const CROISEE := "map_003"
const GROUPES := ["blood_stain", "blood_p2", "wall_impact", "wall_impact_p2", "bullet_casing", "casing_p2"]

var _failures := 0
var _verifications := 0


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
	print("=== LES TRACES SUIVENT LA CARTE ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	var cartes := root.get_node("MapData")
	reglages.mode_iso = true
	_check("la carte de départ (le Cloître) est au catalogue", cartes.select_map(CLOITRE))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	main._on_replay_requested()
	_check("la première manche démarre", await _depart_fini(main))
	await _images(4)

	await _poser_des_traces(main)
	var avant := _compter()
	_check("les traces du Cloître sont posées (sang, éclat, douille, et leurs copies J2)",
		avant["blood_stain"] >= 2 and avant["wall_impact"] >= 1 and avant["bullet_casing"] >= 1
		and avant["blood_p2"] >= avant["blood_stain"] and avant["wall_impact_p2"] >= avant["wall_impact"],
		str(avant))
	var p: Node = root.get_node_or_null("Presentation3D")
	var peinture_avant := _copies_de_peinture(p)
	_check("la peinture iso les a copiées", peinture_avant >= 3, "%d copies" % peinture_avant)

	# --- La revanche, même carte : tout reste (la règle d'Adrien, « rematch compris »).
	main._start_round()
	_check("la revanche sur le Cloître démarre", await _depart_fini(main))
	await _images(4)
	var revanche := _compter()
	_check("revanche : toutes les traces restent", revanche == avant, "%s → %s" % [str(avant), str(revanche)])
	_check("revanche : leurs copies de peinture restent", _copies_de_peinture(p) == peinture_avant,
		"%d → %d" % [peinture_avant, _copies_de_peinture(p)])

	# --- CHANGER DE CARTE, puis REJOUER : tout part.
	_check("la carte d'arrivée (la Croisée) est au catalogue", cartes.select_map(CROISEE))
	main._start_round()
	_check("la manche sur la Croisée démarre", await _depart_fini(main))
	await _images(4)
	var apres := _compter()
	var total := 0
	for g in apres:
		total += int(apres[g])
	_check("Croisée : plus aucune trace du Cloître, ni copie J2", total == 0, str(apres))
	_check("Croisée : plus aucune copie de peinture", _copies_de_peinture(p) == 0, "%d copies" % _copies_de_peinture(p))
	var mat_mur: ShaderMaterial = p.get("_mat_mur") if p != null else null
	_check("Croisée : les murs iso ne lisent plus aucun impact du Cloître",
		mat_mur != null and int(mat_mur.get_shader_parameter("usure_impacts_n")) == 0,
		str(mat_mur.get_shader_parameter("usure_impacts_n")) if mat_mur != null else "pas de matériau")

	# --- La vie continue : une trace neuve sur la Croisée se pose et se copie.
	await _poser_des_traces(main)
	var neuves := _compter()
	_check("Croisée : de nouvelles traces se posent et se copient",
		neuves["blood_stain"] >= 2 and neuves["blood_p2"] >= neuves["blood_stain"], str(neuves))
	_sortir()


## Les poseurs du jeu, tels quels : deux taches de sang par touche (`bullet.gd`, `_spawn_hit_effects`), un éclat de mur
## (`_spawn_wall_effects`), une douille au rechargement (`player.start_reload`).
func _poser_des_traces(main: Node) -> void:
	var arena: Node2D = main.arena
	var pos: Vector2 = main.p1.global_position + Vector2(40, 0)
	var flaque := Node2D.new()
	flaque.set_script(preload("res://blood_stain.gd"))
	arena.add_child(flaque)
	flaque.setup(pos, Vector2.RIGHT, 0.0)
	var gerbe := Node2D.new()
	gerbe.set_script(preload("res://blood_stain.gd"))
	arena.add_child(gerbe)
	gerbe.setup(pos, Vector2.RIGHT, 0.0, true)
	var eclat := Node2D.new()
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


func _compter() -> Dictionary:
	var n := {}
	for g in GROUPES:
		var k := 0
		for t in root.get_tree().get_nodes_in_group(g):
			# Les copies de la peinture iso entrent aussi dans les groupes J2 : on ne compte ici que l'arène.
			if t.get_parent() != null and t.get_parent().name == "Arena":
				k += 1
		n[g] = k
	return n


func _copies_de_peinture(p: Node) -> int:
	if p == null or p.peinture() == null:
		return -1
	return (p.peinture().get("_copies") as Dictionary).size()


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


func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
