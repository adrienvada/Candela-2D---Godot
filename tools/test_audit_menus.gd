## Audit du hub : **aucune entrée ne laisse le cadre de droite vide.**
##
## Demandé par Adrien le 2026-08-18, et écrit comme une suite plutôt que comme
## une inspection : une vérification à la main vaut pour le jour où on la fait,
## un test vaut pour toutes les entrées qui seront ajoutées ensuite. Le hub compte
## des dizaines d'entrées réparties sur une vingtaine d'écrans — les parcourir à
## l'œil une fois ne garantit rien sur la suivante.
##
## La règle : survoler ou sélectionner une entrée doit **montrer quelque chose**.
## Un cadre qui reste vide se lit comme un défaut d'affichage, et il apprend au
## joueur à ne plus regarder à droite — après quoi les entrées qui, elles, ont
## quelque chose à dire ne sont plus lues non plus.
##
## « Quelque chose » veut dire un texte **ou** un panneau. Une entrée qui ouvre la
## galerie de cartes n'a pas besoin de phrase : le panneau parle pour elle.
##
## Lancer : godot --headless --path . --script res://tools/test_audit_menus.gd
extends SceneTree

var _failures: int = 0
var _ui: Node

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== AUDIT DU CADRE DE DROITE ===")
	# Après une frame : les autoloads référencés par `ui.gd` n'existent pas encore
	# au moment de `_init`, et la scène rendrait un nœud nu dont les erreurs
	# n'incrémentent aucun compteur.
	await process_frame
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		printerr("✗ main.tscn introuvable")
		quit(1)
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_ui = main.get_node_or_null("UI")
	if _ui == null or not _ui.has_method("show_pick_window"):
		printerr("✗ l'interface n'a pas son script")
		quit(1)
		return

	_audit_entrees()
	_audit_panneaux_declares()
	_audit_personnalisation()
	_audit_carte_appartient_a_l_hote()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	main.queue_free()
	quit(1 if _failures > 0 else 0)

## Chaque entrée du hub porte-t-elle de quoi remplir la droite ?
func _audit_entrees() -> void:
	print("\n[Chaque entrée a quelque chose à montrer]")
	var details: Dictionary = _ui.hub._entry_details
	_check("le hub a bien des entrées", details.size() > 10, str(details.size()))

	var muettes: Array[String] = []
	for btn: Variant in details.keys():
		if not is_instance_valid(btn):
			continue
		var d: Dictionary = details[btn]
		var texte := String(d.get("texte", "")).strip_edges()
		var panneau := String(d.get("panneau", "")).strip_edges()
		if texte.is_empty() and panneau.is_empty():
			muettes.append(_nom(details, btn))
	_check("aucune entrée ne laisse le cadre vide", muettes.is_empty(),
		", ".join(muettes))

	# Une entrée grisée doit dire POURQUOI, sans quoi le joueur ne peut pas
	# distinguer « pas encore » de « cassé ». `make_entry` met la raison à la
	# place du détail — on vérifie qu'aucune n'est grisée sans raison.
	var sans_raison: Array[String] = []
	for btn: Variant in details.keys():
		if not is_instance_valid(btn):
			continue
		var b: Button = btn
		if not b.disabled:
			continue
		if String((details[btn] as Dictionary).get("texte", "")).strip_edges().is_empty():
			sans_raison.append(_nom(details, b))
	_check("aucune entrée grisée ne tait sa raison", sans_raison.is_empty(),
		", ".join(sans_raison))

## Les panneaux désignés par les entrées existent-ils vraiment ?
##
## `_apply_panel()` retombe silencieusement sur le panneau par défaut de l'écran
## quand la clé est inconnue : une entrée qui viserait un panneau mal orthographié
## montrerait donc autre chose que ce qu'elle annonce, **sans erreur**. C'est le
## même défaut que `push()` sur un identifiant inconnu, déjà consigné.
func _audit_panneaux_declares() -> void:
	print("\n[Les panneaux visés existent]")
	var details: Dictionary = _ui.hub._entry_details
	var connus: Dictionary = _ui.hub._panels
	var fantomes: Array[String] = []
	for btn: Variant in details.keys():
		if not is_instance_valid(btn):
			continue
		var panneau := String((details[btn] as Dictionary).get("panneau", ""))
		if panneau.is_empty():
			continue
		if not connus.has(panneau):
			fantomes.append("%s → %s" % [_nom(details, btn), panneau])
	_check("aucune entrée ne vise un panneau inexistant", fantomes.is_empty(),
		", ".join(fantomes))
	print("    %d panneaux enregistrés" % connus.size())

## Personnalisation ne descend nulle part : ses quatre rubriques se règlent dans
## le cadre.
##
## Demandé par Adrien le 2026-08-18, après une première tentative qui n'avait
## déplacé que la calibration : « Je ne dois pas rentrer dans un autre menu en
## dessous de personnalisation ». Le test l'écrit sous sa forme vérifiable — aucune
## entrée ne vise un écran, chacune vise un panneau, et ce panneau porte de quoi
## régler quelque chose.
##
## Le dernier point est celui qui compte. Un panneau enregistré mais vide passerait
## les deux contrôles précédents : l'entrée aurait bien un panneau, ce panneau
## existerait bien, et la rubrique n'afficherait rien.
func _audit_personnalisation() -> void:
	print("\n[Personnalisation ne descend nulle part]")
	var liste: VBoxContainer = _ui.hub.list_of(_ui.SCREEN_CUSTOM)
	if liste == null:
		_check("l'écran de personnalisation existe", false)
		return
	var details: Dictionary = _ui.hub._entry_details
	# Ce qu'on compte : des commandes ACTIONNABLES, pas des boutons. Les effets se
	# règlent au curseur et l'audio au bouton ; exiger des boutons partout aurait
	# fait passer une rubrique entière pour vide alors qu'elle est complète.
	var attendus := {
		"CONTRÔLES": 6,  # trois actions × deux joueurs
		"AFFICHAGE": 9,  # 3 résolutions + 2 vsync + 5 cadences, au moins
		"EFFETS": 4,
		"AUDIO": 4,
	}
	var vus: Array[String] = []
	for enfant in liste.get_children():
		if not enfant is Button:
			continue
		var btn: Button = enfant
		var libelle := _nom(details, btn)
		if not attendus.has(libelle):
			continue
		vus.append(libelle)
		var d: Dictionary = details.get(btn, {})
		var cle := String(d.get("panneau", ""))
		# Une rubrique de réglages ne doit PAS être une destination. `make_entry`
		# ne garde pas la cible d'une entrée : on la reconnaît à ce qu'elle n'a
		# pas de panneau — une entrée qui pousse un écran laisse la clé vide.
		_check("%s ne pousse aucun écran" % libelle, cle != "")
		_check("%s a un panneau" % libelle, cle != "")
		if cle == "":
			continue
		var contenu: Control = _ui.hub._panels.get(cle, null)
		var commandes := _compte_commandes(contenu)
		_check("%s montre ses réglages dans le cadre (%d commandes)" % [libelle, commandes],
			commandes >= int(attendus[libelle]),
			"attendu au moins %d" % int(attendus[libelle]))
	for libelle: String in attendus.keys():
		_check("la rubrique %s est présente" % libelle, vus.has(libelle))

## Le libellé d'une entrée, tel qu'il s'affiche.
##
## `Button.text` est VIDE sur toutes les entrées du hub : le libellé vit dans un
## `Label` enfant, à côté du chevron. Une première version de cet audit nommait
## donc les entrées fautives par une chaîne vide — le test aurait bien échoué,
## mais sans dire sur quoi.
func _nom(details: Dictionary, btn: Button) -> String:
	return String((details.get(btn, {}) as Dictionary).get("titre", "")).strip_edges()

## Compte ce qu'un joueur peut réellement actionner dans un panneau.
##
## Le critère est la **focalisabilité**, pas le type : un bouton, un curseur de
## volume et une case à cocher se règlent tous, un `Label` non. C'est aussi le
## critère du système de navigation à deux curseurs — compter autre chose ici
## reviendrait à mesurer une propriété que personne n'utilise.
func _compte_commandes(racine: Control) -> int:
	if racine == null:
		return 0
	var n := 0
	for enfant in racine.get_children():
		if enfant is Control:
			var c: Control = enfant
			if c.focus_mode != Control.FOCUS_NONE:
				n += 1
			n += _compte_commandes(c)
	return n

## Famille 7.2 de la checklist en ligne : **la carte appartient à l'hôte.**
##
## L'invité ne doit pas se voir proposer d'en changer — non par avarice, mais
## parce que son choix serait **écrasé au lancement** : c'est la carte de l'hôte
## qui est envoyée. Un bouton qui laisse choisir puis n'en tient pas compte est
## pire qu'un bouton absent ; il fait croire à une décision qui n'existe pas.
##
## Vérifié ici plutôt que dans un banc à deux instances : c'est une propriété de
## structure du menu, elle ne demande ni réseau ni adversaire, et elle est
## déterministe — contrairement à tout ce qui s'échantillonne pendant une
## transition.
func _audit_carte_appartient_a_l_hote() -> void:
	print("\n[La carte appartient à l'hôte]")
	var details: Dictionary = _ui.hub._entry_details
	var avec_cartes := func(ecran: String) -> bool:
		var liste: VBoxContainer = _ui.hub.list_of(ecran)
		if liste == null:
			return false
		for enfant in liste.get_children():
			if not enfant is Button:
				continue
			var d: Dictionary = details.get(enfant, {})
			if String(d.get("panneau", "")) == _ui.PANEL_MAPS:
				return true
		return false

	for hote: String in [_ui.SCREEN_HOST, _ui.SCREEN_LOCAL_HOST]:
		_check("l'hôte peut changer de carte (%s)" % hote, avec_cartes.call(hote))
	for invite: String in [_ui.SCREEN_JOIN, _ui.SCREEN_LOCAL_JOIN]:
		_check("l'invité ne se voit pas proposer d'en changer (%s)" % invite,
			not avec_cartes.call(invite))
	# Et l'écran partagé, lui, l'offre : les deux joueurs sont du même côté.
	_check("l'écran partagé garde le choix de la carte",
		avec_cartes.call(_ui.SCREEN_LOCAL))
