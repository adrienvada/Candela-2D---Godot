## La rubrique CONTRÔLES dit-elle vrai, et réassigne-t-elle vraiment ? (DA4.11)
##
## **Deux défauts de cette rubrique n'ont été vus qu'en la refondant**, et aucun
## des deux ne pouvait rougir : ils produisaient un écran plausible.
##
## 1. **La capture ne connaissait que la manette.** `_handle_rebind_input` ne
##    testait que `InputEventJoypadButton` et `InputEventJoypadMotion` : appuyer
##    sur une touche pendant « Appuyez… » ne faisait **rien**. La réassignation
##    au clavier n'a jamais fonctionné, c'est-à-dire pour la plupart des joueurs.
##
## 2. **Réassigner une touche détruisait la liaison manette.** La boucle
##    d'effacement visait toujours les événements de manette, quel que soit ce
##    qu'on venait de presser — et laissait l'ancienne touche en place. Deux
##    liaisons clavier pour une action, plus de manette. **Personne ne pouvait le
##    voir : les deux appareils étaient affichés ensemble sur un seul bouton.**
##
## ⚠️ **Ce banc réassigne pour de bon, puis remet le monde comme il l'a trouvé.**
## Interroger la fonction sur ce qu'elle ferait serait la comparer à elle-même ;
## l'oracle est l'`InputMap` après coup.

extends SceneTree

var _ok := 0
var _ko := 0
var _ui: Node


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


# ---------------------------------------------------------------------------
# 1. CE QUI EST LU VIENT DE L'INPUT MAP
# ---------------------------------------------------------------------------

func _test_l_occupation_suit_l_input_map(l: GDScript, toutes: Dictionary) -> void:
	var occupe: Dictionary = l.occupation(toutes)
	_check(occupe.size() >= 12,
		"seulement %d touches occupées : la lecture a raté" % occupe.size())

	var ancienne := InputMap.action_get_events("p2_shoot")
	var neuve := InputEventKey.new()
	neuve.physical_keycode = KEY_G
	InputMap.action_erase_events("p2_shoot")
	InputMap.action_add_event("p2_shoot", neuve)

	var apres: Dictionary = l.occupation(toutes)
	_check(apres.has(KEY_G), "après réassignation sur G, G n'est pas occupée")
	_check(not apres.has(KEY_O), "l'ancienne touche reste occupée")

	InputMap.action_erase_events("p2_shoot")
	for ev in ancienne:
		InputMap.action_add_event("p2_shoot", ev)
	_check((l.occupation(toutes) as Dictionary).has(KEY_O),
		"la remise en état n'a pas restauré la liaison d'origine")


func _test_une_touche_partagee_est_nommee(l: GDScript, toutes: Dictionary) -> void:
	_check((l.collisions(toutes) as Array).is_empty(),
		"les touches par défaut se marchent dessus : %s" % str(l.collisions(toutes)))

	var ancienne := InputMap.action_get_events("p1_shoot")
	var neuve := InputEventKey.new()
	neuve.physical_keycode = KEY_P
	InputMap.action_erase_events("p1_shoot")
	InputMap.action_add_event("p1_shoot", neuve)
	_check((l.collisions(toutes) as Array).has(KEY_P),
		"deux joueurs sur P et la collision n'est pas nommée")

	InputMap.action_erase_events("p1_shoot")
	for ev in ancienne:
		InputMap.action_add_event("p1_shoot", ev)
	_check((l.collisions(toutes) as Array).is_empty(),
		"la remise en état laisse une collision")


func _test_les_libelles(l: GDScript) -> void:
	_check(String(l.libelle_de(KEY_UP)) == "▲", "la flèche du haut n'a pas son signe")
	_check(String(l.libelle_de(KEY_SPACE)) == "ESPACE",
		"la barre d'espace n'est pas nommée en toutes lettres")
	# ⚠️ Le contrôle qui a une histoire : `keyboard_get_keycode_from_physical()`
	# n'existe pas en headless et journalise une erreur par appel. Un banc qui
	# imprime des erreurs apprend à les ignorer.
	var source := FileAccess.get_file_as_string("res://liaisons.gd")
	_check(source.contains("DisplayServer.get_name() == \"headless\""),
		"la traduction de disposition n'est pas gardée contre le headless")
	_check(not FileAccess.file_exists("res://carte_appareil.gd"),
		"carte_appareil.gd survit alors que son dessin est abandonné")


# ---------------------------------------------------------------------------
# 2. LA LISTE COUVRE CE QUE LE JOUEUR EMPLOIE
# ---------------------------------------------------------------------------

## ⚠️ **L'oracle est l'`InputMap`, pas la liste.** On demande au jeu quelles
## actions un joueur possède, puis on exige que la rubrique les montre toutes.
## Comparer la liste à elle-même — « chaque entrée existe-t-elle ? » — laisserait
## passer l'oubli, qui est le défaut coûteux : **une commande absente de la
## rubrique se cherche ailleurs, et il n'y a pas d'ailleurs.**
func _test_la_liste_montre_tout_ce_qui_se_regle() -> void:
	for joueur in 2:
		# Toute action de jeu liée au CLAVIER ou à la SOURIS doit avoir sa ligne
		# dans le bloc clavier. C'est l'oracle : l'InputMap, pas la rubrique.
		var attendues: Array[String] = []
		for a in InputMap.get_actions():
			var nom := String(a)
			if not nom.begins_with("p%d_" % (joueur + 1)):
				continue
			if nom.contains("menu") or nom.contains("skip") \
					or nom.contains("weapon") or nom.contains("ready"):
				continue
			for ev in InputMap.action_get_events(nom):
				if ev is InputEventKey or ev is InputEventMouseButton:
					if not attendues.has(nom):
						attendues.append(nom)

		var montrees := {}
		for suffixe: String in _ui.call("_lignes_du_bloc", joueur, "clavier"):
			montrees["p%d_%s" % [joueur + 1, suffixe]] = true

		var oubliees: Array[String] = []
		for nom in attendues:
			if not montrees.has(nom):
				oubliees.append(nom)
		_check(oubliees.is_empty(),
			"J%d : ces commandes du clavier ne figurent nulle part : %s"
				% [joueur + 1, ", ".join(oubliees)])

		# ⚠️ **Et le versant inverse : la manette ne montre QUE ce qui s'y
		# réassigne.** Les sticks ne passent pas par la capture ; une ligne
		# inerte à côté de lignes cliquables ferait croire à un réglage bloqué.
		for suffixe: String in _ui.call("_lignes_du_bloc", joueur, "manette"):
			var action := "p%d_%s" % [joueur + 1, suffixe]
			var capturable := false
			for ev in InputMap.action_get_events(action):
				if ev is InputEventJoypadButton:
					capturable = true
				elif ev is InputEventJoypadMotion:
					var ax := (ev as InputEventJoypadMotion).axis
					if ax == JOY_AXIS_TRIGGER_LEFT or ax == JOY_AXIS_TRIGGER_RIGHT:
						capturable = true
			_check(capturable,
				"le bloc manette montre « %s », que la capture ne sait pas prendre"
					% action)

		# ⚠️ **La visée ne disparaît jamais.** J1 vise à la souris : ses
		# `p1_aim_*` n'ont que le stick droit, donc aucune ligne ne se dérive.
		# Sans le repli, la commande la plus employée du jeu serait absente de la
		# rubrique qui prétend les lister toutes.
		var suffixes: Array = _ui.call("_lignes_du_bloc", joueur, "clavier")
		var a_visee: bool = _ui.call("_bloc_a_une_visee", suffixes)
		if not a_visee:
			var bloc: Control = _ui.call("_build_bloc_du_joueur", joueur)
			var trouve := false
			var pile: Array[Node] = [bloc]
			while not pile.is_empty():
				var n: Node = pile.pop_back()
				for e in n.get_children():
					pile.append(e)
				if n is Label and String((n as Label).text).contains("VISER"):
					trouve = true
			_check(trouve,
				"J%d n'a aucune ligne de visée : ni dérivée, ni le repli souris"
					% (joueur + 1))
			bloc.free()


## La visée de J1 est à la souris : elle n'a pas d'action, et la ligne l'écrit.
func _test_la_visee_souris_est_dite() -> void:
	_check(not InputMap.has_action("p1_aim"),
		"p1_aim existe maintenant : la ligne « Souris » devrait devenir un bouton")
	var ligne: Control = _ui.call("_make_ligne_de_commande", "p1_aim", 0,
		"clavier", false)
	_check(ligne != null and not (ligne is Button),
		"une commande sans action rend un bouton mort au lieu d'un texte")
	if ligne is Label:
		_check(String((ligne as Label).text) != "",
			"la ligne de la visée souris est vide : le joueur la croira absente")
	ligne.free()


# ---------------------------------------------------------------------------
# 3. RÉASSIGNER UNE TOUCHE NE DÉTRUIT PAS LA MANETTE
# ---------------------------------------------------------------------------

## ⚠️ **Le contrôle le plus cher de ce banc.** Il exerce la réassignation pour de
## bon — bouton, événement, tout — et vérifie sur l'`InputMap` que la liaison de
## l'autre appareil a survécu. C'est le seul moyen de voir un défaut dont la
## seule trace est une liaison disparue.
func _test_reassigner_une_touche_epargne_la_manette() -> void:
	var action := "p2_shoot"
	var avant := InputMap.action_get_events(action)
	var pads_avant := 0
	for ev in avant:
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			pads_avant += 1
	_check(pads_avant > 0,
		"p2_shoot n'a pas de liaison manette : le contrôle ne prouverait rien")

	var btn: Button = _ui.call("_make_rebind_button", action, 1, "clavier")
	_ui.set("_is_rebinding", true)
	_ui.set("_action_to_rebind", action)
	_ui.set("_button_to_update", btn)

	var touche := InputEventKey.new()
	touche.physical_keycode = KEY_G
	touche.pressed = true
	_ui.call("_handle_rebind_input", touche)

	var apres := InputMap.action_get_events(action)
	var pads_apres := 0
	var claviers := 0
	var sur_g := false
	for ev in apres:
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			pads_apres += 1
		elif ev is InputEventKey:
			claviers += 1
			if (ev as InputEventKey).physical_keycode == KEY_G:
				sur_g = true

	_check(sur_g, "la touche pressée n'a pas été liée : la capture ignore le clavier")
	_check(claviers == 1,
		"%d liaisons clavier après une réassignation : l'ancienne survit" % claviers)
	_check(pads_apres == pads_avant,
		"la liaison manette a été détruite par une réassignation au clavier "
		+ "(%d avant, %d après)" % [pads_avant, pads_apres])

	# Remise en état : un banc ne laisse pas le monde différent.
	InputMap.action_erase_events(action)
	for ev in avant:
		InputMap.action_add_event(action, ev)
	btn.free()
	_ui.set("_is_rebinding", false)
	_ui.set("_button_to_update", null)


## ⚠️ **Une ligne du bloc manette n'accepte pas une touche**, et l'inverse. Sans
## ce refus, deux blocs qui font la même chose ne sont pas deux blocs : c'est le
## même écrit deux fois, et le joueur qui règle sa manette casserait son clavier.
func _test_chaque_bloc_n_accepte_que_son_appareil() -> void:
	var action := "p2_torch"
	var avant := InputMap.action_get_events(action)

	var btn: Button = _ui.call("_make_rebind_button", action, 1, "manette")
	_ui.set("_is_rebinding", true)
	_ui.set("_action_to_rebind", action)
	_ui.set("_button_to_update", btn)

	var touche := InputEventKey.new()
	touche.physical_keycode = KEY_H
	touche.pressed = true
	_ui.call("_handle_rebind_input", touche)

	var lie_sur_h := false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_H:
			lie_sur_h = true
	_check(not lie_sur_h,
		"une ligne du bloc MANETTE s'est laissé réassigner par une touche")

	InputMap.action_erase_events(action)
	for ev in avant:
		InputMap.action_add_event(action, ev)
	btn.free()
	_ui.set("_is_rebinding", false)
	_ui.set("_button_to_update", null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Les liaisons de commandes ===")
	await process_frame
	var l: GDScript = load("res://liaisons.gd")
	if l == null:
		printerr("✗ liaisons.gd introuvable")
		quit(1)
		return

	var scene: PackedScene = load("res://main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_ui = main.get_node_or_null("UI")
	if _ui == null or not _ui.has_method("_handle_rebind_input"):
		printerr("✗ l'interface n'a pas son script")
		quit(1)
		return

	var toutes := {
		0: ["p1_move_up", "p1_move_left", "p1_move_down", "p1_move_right",
			"p1_shoot", "p1_torch"],
		1: ["p2_move_up", "p2_move_left", "p2_move_down", "p2_move_right",
			"p2_aim_up", "p2_aim_left", "p2_aim_down", "p2_aim_right",
			"p2_shoot", "p2_torch"],
	}

	_test_l_occupation_suit_l_input_map(l, toutes)
	_test_une_touche_partagee_est_nommee(l, toutes)
	_test_les_libelles(l)
	_test_la_liste_montre_tout_ce_qui_se_regle()
	_test_la_visee_souris_est_dite()
	_test_reassigner_une_touche_epargne_la_manette()
	_test_chaque_bloc_n_accepte_que_son_appareil()

	print("--- %d contrôles, %d échec(s) ---" % [_ok + _ko, _ko])
	main.queue_free()
	quit(1 if _ko > 0 else 0)
