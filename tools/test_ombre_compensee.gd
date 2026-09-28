extends SceneTree
## La garde du drapeau d'essai `--ombre-compensee` (session cloud ombre-orientation, 2026-09-27).
##
## Le drapeau multiplie la lumière qu'un corps lit dans son capteur par le facteur de sa classe (voie « d » de l'ombre
## des classes, `ombre_compensee.gd`). Il ne doit RIEN changer tant qu'il est éteint, et ne jamais valoir ni en release
## ni en ligne. Cette suite le vérifie :
## - la règle pure (`OmbreCompensee.mode`) : éteint, release, en ligne, valeurs, préfixe voisin ;
## - la géométrie : un occluder qui contient l'anneau l'éteint, pas d'occluder ne cache rien, le rond du torse cache la
##   même part dans toutes les directions, la table interpolée retombe sur le calcul direct aux directions de la table,
##   le Parasite vaut 1 exactement dans les deux variantes ;
## - les shaders des corps : l'uniforme `compensation_ombre` existe, vaut 1,0 par défaut, et la multiplication est
##   gardée par `!= 1.0` (éteint, aucune opération de plus : la lecture du capteur au bit près) ;
## - les vrais joueurs de `main.tscn` et la vraie présentation iso, dix classes : éteint, la présentation ne pose RIEN
##   sur les matériaux des corps ; allumé, le facteur de la classe ; allumé mais en ligne, rien de nouveau et 1,0
##   rendu ; éteint à nouveau, 1,0.
##
##   godot --headless --path . --script res://tools/test_ombre_compensee.gd

const OC := preload("res://ombre_compensee.gd")
const CharteS := preload("res://charte.gd")

var _failures := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	print("=== test_ombre_compensee ===")
	_test_regle()
	_test_geometrie()
	_test_shaders()
	await _test_joueurs()
	if _failures == 0:
		print("\nTous les tests passent.")
	else:
		printerr("\n%d échec(s)." % _failures)
	quit(1 if _failures > 0 else 0)


func _test_regle() -> void:
	print("\n[La règle pure]")
	var rien := PackedStringArray()
	var seul := PackedStringArray(["--ombre-compensee"])
	var un := PackedStringArray(["--autre", "--ombre-compensee=1"])
	var deux := PackedStringArray(["--ombre-compensee=2"])
	_check("sans drapeau : éteint", OC.mode(rien, true, false) == 0)
	_check("`--ombre-compensee` seul : 2", OC.mode(seul, true, false) == 2)
	_check("`=1` : 1", OC.mode(un, true, false) == 1)
	_check("`=2` : 2", OC.mode(deux, true, false) == 2)
	_check("valeur illisible : éteint", OC.mode(PackedStringArray(["--ombre-compensee=7"]), true, false) == 0)
	_check("un préfixe voisin ne l'allume pas", OC.mode(PackedStringArray(["--ombre-compenseee"]), true, false) == 0)
	_check("release : éteint, même demandé", OC.mode(deux, false, false) == 0)
	_check("en ligne : éteint, même demandé", OC.mode(deux, true, true) == 0)
	_check("forcé par un outil : 1", OC.mode(rien, true, false, 1) == 1)
	_check("forcé à 0 : éteint, même demandé", OC.mode(deux, true, false, 0) == 0)
	_check("forcé, mais en ligne : éteint", OC.mode(rien, true, true, 2) == 0)
	_check("forcé, mais release : éteint", OC.mode(rien, false, false, 2) == 0)
	# La garde « éteint » plus bas n'a de sens que si la ligne de commande ne l'allume pas.
	_check("lancée sans `--ombre-compensee`",
		OC.mode(OS.get_cmdline_user_args() + OS.get_cmdline_args(), true, false) == 0)


func _test_geometrie() -> void:
	print("\n[La géométrie]")
	var grand: PackedVector2Array = CharteS.ombre_ronde(18.0)
	var torse: PackedVector2Array = CharteS.ombre_ronde(12.0)
	_check("un rond de 18 contient l'anneau : part 0", OC.part_eclairee(grand, Vector2.RIGHT) == 0.0)
	_check("sans occluder : part 1", OC.part_eclairee(PackedVector2Array(), Vector2.RIGHT) == 1.0)
	var parts := []
	for i in 16:
		parts.append(OC.part_eclairee(torse, Vector2.from_angle(TAU * float(i) / 16.0 + 0.013)))
	var ok := true
	for p in parts:
		ok = ok and absf(float(p) - float(parts[0])) <= 2.0 / 64.0
	_check("le rond du torse cache la même part dans toutes les directions (±2 points)", ok, str(parts))
	_check("le rond du torse : entre la moitié et les trois quarts éclairés", parts[0] > 0.5 and parts[0] < 0.75,
		str(parts[0]))
	var ref: PackedVector2Array = OC.forme_reference()
	_check("l'étoile du Parasite : 32 sommets", ref.size() == 32)
	var pompe: PackedVector2Array = CharteS.ombre_de_silhouette(load("res://assets/sprites/pompe_silhouette.png"))
	var tenue := true
	for i in OC.DIRECTIONS:
		var d: Vector2 = OC.direction_de_case(i)
		tenue = tenue and is_equal_approx(OC.part_table(pompe, d), OC.part_eclairee(pompe, d))
	_check("la table retombe sur le calcul direct à ses directions", tenue)
	_check("Parasite, (d1) : 1 exactement", OC.facteur_constant(ref) == 1.0)
	_check("Parasite, (d2) : 1 exactement", OC.facteur_direction(ref, Vector2(-3, 7)) == 1.0)
	var f1: float = OC.facteur_constant(pompe)
	_check("Terrassier, (d1) : un facteur borné, différent de 1", f1 >= OC.FACTEUR_MIN and f1 <= OC.FACTEUR_MAX
		and f1 != 1.0, str(f1))


func _test_shaders() -> void:
	print("\n[Les shaders des corps]")
	for chemin in ["res://corps_iso.gdshader", "res://corps_iso_eclaire.gdshader"]:
		var sh := load(chemin) as Shader
		var trouve := false
		for u in sh.get_shader_uniform_list():
			if u["name"] == "compensation_ombre":
				trouve = true
		var code := sh.code
		_check("%s : l'uniforme `compensation_ombre` existe" % chemin.get_file(), trouve)
		# Lu dans le code : le rendu factice des suites headless ne rend pas les valeurs par défaut des uniformes.
		_check("%s : 1,0 par défaut" % chemin.get_file(), code.contains("uniform float compensation_ombre = 1.0;"))
		_check("%s : la multiplication est gardée par `!= 1.0`" % chemin.get_file(),
			code.contains("if (compensation_ombre != 1.0) {\n\t\tlu *= compensation_ombre;"))


func _test_joueurs() -> void:
	print("\n[Les vrais joueurs, la vraie présentation, dix classes]")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var reseau: Node = root.get_node("NetworkManager")
	var mode_avant = reseau.current_mode
	var reglages: Node = root.get_node("GameSettings")
	# La vue iso s'allume comme dans `test_iso_killcam` : une manche locale, `mode_iso` vrai.
	main.ui._intended_mode = int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
	reglages.mode_iso = true
	main._on_replay_requested()
	for i in 6:
		await process_frame
	var iso = root.get_node_or_null("Presentation3D")
	if iso == null or not bool(iso.get("_actif")):
		_check("la vue iso est allumée", false)
		reglages.mode_iso = false
		main.queue_free()
		return
	var catalogue: Array = main.classes()
	_check("dix classes au catalogue", catalogue.size() == 10, str(catalogue.size()))
	var facteurs := {}
	for k in catalogue.size():
		var arme = main.weapon_for_index(k)
		OC.mode_force = -1
		for j in [main.p1, main.p2]:
			j.equip_weapon(arme)
		for i in 3:
			await process_frame
		var mats: Array = iso._mat_corps
		if mats[0] == null or mats[1] == null:
			_check("%s : les matériaux des corps existent" % arme.name, false)
			continue
		var eteint := true
		for m in mats:
			var v = (m as ShaderMaterial).get_shader_parameter("compensation_ombre")
			eteint = eteint and v == null
		_check("%s — éteint : rien n'est posé sur les deux corps" % arme.name, eteint)
		OC.mode_force = 1
		await process_frame
		var poly: PackedVector2Array = (main.p2.get_node("LightOccluder2D") as LightOccluder2D).occluder.polygon
		var attendu: float = OC.facteur_constant(poly)
		var lu = (mats[1] as ShaderMaterial).get_shader_parameter("compensation_ombre")
		_check("%s — (d1) : le facteur de la classe (%.3f)" % [arme.name, attendu],
			lu != null and is_equal_approx(float(lu), attendu), str(lu))
		facteurs[arme.name] = attendu
		reseau.current_mode = reseau.GameMode.ONLINE_HOST
		await process_frame
		var en_ligne = [(mats[0] as ShaderMaterial).get_shader_parameter("compensation_ombre"),
			(mats[1] as ShaderMaterial).get_shader_parameter("compensation_ombre")]
		_check("%s — allumé mais en ligne : 1,0 rendu aux deux corps" % arme.name,
			en_ligne[0] != null and float(en_ligne[0]) == 1.0 and float(en_ligne[1]) == 1.0, str(en_ligne))
		reseau.current_mode = mode_avant
		OC.mode_force = 2
		await process_frame
		lu = (mats[1] as ShaderMaterial).get_shader_parameter("compensation_ombre")
		_check("%s — (d2) : un facteur borné" % arme.name,
			lu != null and float(lu) >= OC.FACTEUR_MIN and float(lu) <= OC.FACTEUR_MAX, str(lu))
		OC.mode_force = 0
		await process_frame
		var rendu = [(mats[0] as ShaderMaterial).get_shader_parameter("compensation_ombre"),
			(mats[1] as ShaderMaterial).get_shader_parameter("compensation_ombre")]
		_check("%s — éteint à nouveau : 1,0" % arme.name,
			float(rendu[0]) == 1.0 and float(rendu[1]) == 1.0, str(rendu))
	OC.mode_force = -1
	print("  facteurs (d1) : ", facteurs)
	var differents := {}
	for v in facteurs.values():
		differents[snappedf(float(v), 0.001)] = true
	# Sans ce contrôle, une garde qui lirait dix fois la même forme passerait aussi.
	_check("les dix facteurs ne sont pas tous les mêmes", differents.size() >= 4, str(differents.size()))
	reseau.current_mode = mode_avant
	reglages.mode_iso = false
	await process_frame
	main.queue_free()
	await process_frame
