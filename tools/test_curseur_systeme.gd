## La flèche du système est-elle là partout où il faut cliquer ?
##
## **Ce banc naît de la troisième occurrence du même défaut.** La condition qui
## décide de montrer le pointeur est une énumération de cas, et elle s'est
## révélée incomplète trois fois :
##
## - **2026-08-25** — elle valait `_is_main_menu` SEUL. Pause, dialogues et choix
##   d'arme s'ouvrent par-dessus le match, donc avec ce drapeau à faux : la
##   flèche y était masquée et il fallait la manette pour en sortir. Trois cas
##   ajoutés.
## - **2026-08-27** — l'écran de FIN DE MATCH manquait toujours, relevé par
##   Adrien : « après un match mon curseur ne réapparaît pas ». `show_game_over()`
##   pose `_is_main_menu = false` puis allume `game_over_panel` ; aucun des quatre
##   cas ne correspondait, et le joueur se retrouvait devant REJOUER sans
##   pointeur.
##
## ⚠️ **Le commentaire du 2026-08-25 décrivait exactement ce défaut comme la
## chose à éviter** — « sans plus aucun moyen de cliquer *Quitter* » — corrigeait
## trois cas, et en laissait un. **Une énumération partielle se lit comme une
## liste complète** : c'est ce qui rend la relecture inopérante ici, la liste de
## quatre *paraissant* délibérée. Seul un contrôle qui ouvre chaque panneau et
## regarde peut trancher.
##
## ## Ce que le banc fait, et pourquoi il n'interroge pas la condition
##
## Il **ouvre réellement chaque panneau** puis lit `_un_menu_attend_un_clic()`.
## Demander à la condition la liste des cas qu'elle traite serait la comparer à
## elle-même — le motif du banc décoratif, payé quatre fois dans ce dépôt. La
## source de vérité est ici l'ensemble des panneaux **cliquables**, qui existe
## indépendamment de la condition : un panneau qui porte des `Button` visibles
## attend un clic, que la condition le sache ou non.

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


## Combien de boutons visibles et actifs ce panneau présente-t-il ?
func _boutons_cliquables(n: Node) -> int:
	if n == null:
		return 0
	var total := 0
	var pile: Array[Node] = [n]
	while not pile.is_empty():
		var c: Node = pile.pop_back()
		for e in c.get_children():
			pile.append(e)
		if c is Button and (c as Button).visible and not (c as Button).disabled:
			total += 1
	return total


## L'écran de fin de match montre-t-il la flèche ?
func _test_la_fin_de_match_a_son_pointeur() -> void:
	if not _ui.has_method("show_game_over"):
		_check(false, "l'interface n'a pas show_game_over")
		return

	_ui.call("show_game_over", 0)
	await process_frame
	await process_frame

	var panneau: Node = _ui.get("game_over_panel")
	_check(panneau != null and (panneau as Control).visible,
		"show_game_over n'a pas ouvert le panneau de fin")

	# ⚠️ La vérité indépendante : ce panneau porte des boutons à cliquer.
	var boutons := _boutons_cliquables(panneau)
	_check(boutons > 0,
		"l'écran de fin ne présente aucun bouton : le contrôle ne prouverait rien")

	_check(bool(_ui.call("_un_menu_attend_un_clic")),
		"l'écran de fin porte %d bouton(s) cliquable(s) et la flèche y est MASQUÉE"
			% boutons)


## Et l'inverse : en pleine manche, elle disparaît.
##
## Sans ce versant, rendre la condition toujours vraie ferait passer le banc au
## vert tout en remettant la flèche de macOS par-dessus le jeu — le défaut que
## DA2.11 avait corrigé.
func _test_en_manche_la_fleche_disparait() -> void:
	if _ui.has_method("hide_game_over"):
		_ui.call("hide_game_over")
	_ui.set("_is_main_menu", false)
	# L'extinction est animée : laisser passer de quoi la voir finir, sinon on
	# conclurait sur un panneau encore à l'écran.
	for _i in 40:
		await process_frame

	var panneau: Node = _ui.get("game_over_panel")
	if panneau != null and (panneau as Control).visible:
		# L'extinction est animée : on ne peut pas conclure tant qu'il est encore
		# à l'écran. Le dire plutôt que de rendre un vert sans valeur.
		print("    (panneau de fin encore en extinction — versant non joué)")
		return

	_check(not bool(_ui.call("_un_menu_attend_un_clic")),
		"aucun menu n'est ouvert et la flèche du système reste affichée")


## Chaque panneau cliquable connu déclenche-t-il la flèche ?
##
## La liste est celle des panneaux que `ui.gd` expose et qui portent des boutons.
## Un panneau ajouté demain sans être câblé ici ne sera pas attrapé — c'est la
## limite honnête de ce banc, et elle est écrite plutôt que tue.
func _test_chaque_panneau_cliquable(nom: String) -> void:
	var panneau: Node = _ui.get(nom)
	if panneau == null:
		return
	var ctrl := panneau as Control
	if ctrl == null:
		return

	var avant := ctrl.visible
	ctrl.visible = true
	await process_frame
	var boutons := _boutons_cliquables(ctrl)
	if boutons > 0:
		_check(bool(_ui.call("_un_menu_attend_un_clic")),
			"« %s » porte %d bouton(s) et la flèche y est masquée"
				% [nom, boutons])
	ctrl.visible = avant
	await process_frame


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== La flèche du système ===")
	# Après une frame : les autoloads que `ui.gd` référence n'existent pas encore
	# au moment de `_init`. Motif repris de `test_habillage.gd`.
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
	if _ui == null or not _ui.has_method("_un_menu_attend_un_clic"):
		printerr("✗ l'interface n'a pas sa condition de pointeur")
		quit(1)
		return

	await _test_la_fin_de_match_a_son_pointeur()
	await _test_en_manche_la_fleche_disparait()
	for nom in ["pause_panel", "dialog_panel", "pick_panel"]:
		await _test_chaque_panneau_cliquable(nom)

	print("--- %d contrôles, %d échec(s) ---" % [_ok + _ko, _ko])
	quit(1 if _ko > 0 else 0)
