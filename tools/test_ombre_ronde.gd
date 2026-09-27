extends SceneTree
## La garde du drapeau d'essai `--ombre-ronde` (session cloud ombre-classes, 2026-09-27).
##
## Le drapeau rend à toutes les classes un occluder rond, pour mesurer d'où vient l'écart du
## capteur entre classes (planche Q33). Il ne doit RIEN changer tant qu'il est éteint, et ne
## jamais valoir ni en release ni en ligne. Cette suite le vérifie de deux façons :
## - la règle pure (`Charte.rayon_ombre_ronde`) : éteint, release, en ligne, valeurs ;
## - les vrais joueurs de `main.tscn`, équipés des dix classes : éteint, l'occluder de chacun
##   est l'étoile de sa silhouette, SOMMET PAR SOMMET ; allumé, un rond ; allumé mais en
##   ligne, l'étoile encore.
##
##   godot --headless --path . --script res://tools/test_ombre_ronde.gd

## Par chemin : en `--script`, le registre des noms de classe peut ne pas être prêt.
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
	print("=== test_ombre_ronde ===")
	_test_regle()
	await _test_joueurs()
	if _failures == 0:
		print("\nTous les tests passent.")
	else:
		printerr("\n%d échec(s)." % _failures)
	quit(1 if _failures > 0 else 0)


func _test_regle() -> void:
	print("\n[La règle pure]")
	var r := CharteS.rayon_ombre_ronde
	var rien := PackedStringArray()
	var seul := PackedStringArray(["--ombre-ronde"])
	var dix_huit := PackedStringArray(["--autre", "--ombre-ronde=18"])
	_check("sans drapeau : éteint", r.call(rien, true, false) == 0.0)
	_check("`--ombre-ronde` seul : le torse (12)", r.call(seul, true, false) == CharteS.RAYON_TORSE)
	_check("`--ombre-ronde=18` : 18", r.call(dix_huit, true, false) == 18.0)
	_check("valeur illisible : le torse", r.call(PackedStringArray(["--ombre-ronde=x"]), true, false)
		== CharteS.RAYON_TORSE)
	_check("valeur bornée", r.call(PackedStringArray(["--ombre-ronde=500"]), true, false)
		== CharteS.OMBRE_RONDE_MAX)
	_check("un préfixe voisin ne l'allume pas",
		r.call(PackedStringArray(["--ombre-rondeur"]), true, false) == 0.0)
	_check("release : éteint, même demandé", r.call(dix_huit, false, false) == 0.0)
	_check("en ligne : éteint, même demandé", r.call(dix_huit, true, true) == 0.0)
	_check("forcé par un outil : 12", r.call(rien, true, false, 12.0) == 12.0)
	_check("forcé à 0 : éteint, même demandé en ligne de commande", r.call(seul, true, false, 0.0) == 0.0)
	_check("forcé, mais en ligne : éteint", r.call(rien, true, true, 12.0) == 0.0)
	_check("forcé, mais release : éteint", r.call(rien, false, false, 12.0) == 0.0)
	var rond: PackedVector2Array = CharteS.ombre_ronde(12.0)
	var ok := rond.size() == 32
	for p in rond:
		ok = ok and absf(p.length() - 12.0) < 1e-4
	_check("le rond : 32 sommets à 12", ok)


func _test_joueurs() -> void:
	print("\n[Les vrais joueurs, dix classes]")
	# La garde « éteint » n'a de sens que si la ligne de commande ne l'allume pas.
	_check("lancée sans `--ombre-ronde`", CharteS.rayon_ombre_ronde(
		OS.get_cmdline_user_args() + OS.get_cmdline_args(), true, false) == 0.0)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var catalogue: Array = main.classes()
	_check("dix classes au catalogue", catalogue.size() == 10, str(catalogue.size()))
	var formes := {}
	# Par le nœud : l'identifiant d'autoload n'est pas déclaré à la compilation d'un `--script`.
	var reseau: Node = root.get_node("NetworkManager")
	var mode_avant = reseau.current_mode
	for k in catalogue.size():
		var arme = main.weapon_for_index(k)
		for j in [main.p1, main.p2]:
			CharteS.ombre_ronde_forcee = -1.0
			j.equip_weapon(arme)
			var occ: LightOccluder2D = j.get_node("LightOccluder2D")
			var etoile: PackedVector2Array = CharteS.ombre_de_silhouette(j._sprite_sil_statique)
			var eteint: PackedVector2Array = occ.occluder.polygon
			_check("%s, %s — éteint : l'étoile de sa silhouette, sommet par sommet" % [arme.name, j.name],
				eteint == etoile and etoile.size() == 32, "%d sommets" % eteint.size())
			formes[str(eteint)] = true
			CharteS.ombre_ronde_forcee = 12.0
			j.equip_weapon(arme)
			_check("%s, %s — allumé : le rond de 12" % [arme.name, j.name],
				j.get_node("LightOccluder2D").occluder.polygon == CharteS.ombre_ronde(12.0))
			reseau.current_mode = reseau.GameMode.ONLINE_HOST
			j.equip_weapon(arme)
			_check("%s, %s — allumé mais en ligne : l'étoile" % [arme.name, j.name],
				j.get_node("LightOccluder2D").occluder.polygon == etoile)
			reseau.current_mode = mode_avant
			CharteS.ombre_ronde_forcee = -1.0
			j.equip_weapon(arme)
			_check("%s, %s — éteint à nouveau : l'étoile" % [arme.name, j.name],
				j.get_node("LightOccluder2D").occluder.polygon == etoile)
	# Sans ce contrôle, une garde qui comparerait dix fois la même forme passerait aussi.
	_check("les dix étoiles ne sont pas toutes la même", formes.size() >= 5, "%d formes" % formes.size())
	reseau.current_mode = mode_avant
	main.queue_free()
	await process_frame
