## Le regard du noir (M3) s'endort hors du menu (session cloud « restes », 2026-09-28).
##
## ## Pourquoi
##
## `MenuWatcher` fait apparaître deux yeux rouges dans les marges après 25 s sans geste de menu. Il vit en
## `PROCESS_MODE_ALWAYS`, visible tant que l'interface l'est — pendant le match aussi, sous le HUD —, et seul
## `_set_focus` (qu'aucun match n'appelle) remettait son compte à zéro : 25 s après le lancement, puis toutes les 25 s,
## les yeux s'allumaient par-dessus le noir du duel. Vu à l'image par `tools/photo_regard.gd` (RAPPORT restes, § 2).
##
## ## Ce que la garde vérifie, sans rien rendre
##
## Le temps est simulé en appelant `_process(1.0)` du regard SEULEMENT quand le moteur le traiterait
## (`is_processing()`) : c'est la question posée — le jeu le laisse-t-il compter en match ?
##   • menu ouvert : il compte, et les yeux viennent après 25 s (l'effet de menu marche toujours) ;
##   • menu fermé comme au lancement d'une manche (`hide_game_over`) : les yeux déjà ouverts s'effacent, et 60 s de
##     match n'en rallument aucun ;
##   • menu rouvert : il recompte.
##
## Lancer : godot --headless --path . --script res://tools/test_regard_hors_menu.gd
extends SceneTree

var _echecs := 0
var _dessins := 0


func _init() -> void:
	# `ui.gd` nomme des autoloads : l'attente d'une image avant le `load` (comme `test_vitrine_menus.gd`).
	await process_frame
	await _tester()
	if _echecs == 0:
		print("\n✓ le regard du noir s'endort hors du menu — tout passe")
	else:
		print("\n✗ %d échec(s)" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _check(nom: String, ok: bool, detail: String = "") -> void:
	print("  %s %s%s" % ["✓" if ok else "✗", nom, ("  → " + detail) if (detail != "" and not ok) else ""])
	if not ok:
		_echecs += 1


## `secondes` de temps simulé, par pas d'une seconde, là où le moteur traiterait le regard. Rend la plus longue vie
## d'yeux vue en route : des yeux qui s'ouvrent puis se referment avant la fin comptent (ils ont été vus).
func _laisser_passer(regard: Node, secondes: int) -> float:
	var vu := 0.0
	for i in secondes:
		if regard.is_processing() and regard.is_visible_in_tree():
			regard._process(1.0)
		vu = maxf(vu, float(regard.get("_vie")))
	return vu


func _tester() -> void:
	print("[Le regard du noir hors du menu]")
	var ui: Node = (load("res://ui.tscn") as PackedScene).instantiate()
	ui.name = "UI"
	root.add_child(ui)
	await process_frame
	for m in ["_set_focus", "_allumer", "hide_game_over", "_panneau_ouvert"]:
		if not ui.has_method(m):
			_check("le harnais atteint UI.%s()" % m, false)
			ui.queue_free()
			return
	var regard: Node = ui.get("menu_watcher")
	var menu: Control = ui.game_over_panel
	var bouton: Control = ui.btn_replay
	_check("le regard, le menu et un bouton existent", regard != null and menu != null and bouton != null)
	if regard == null or menu == null or bouton == null:
		ui.queue_free()
		return
	# Un poste dont les réglages éteignent la vitrine ne dit rien de ce défaut : on rallume pour l'épreuve.
	regard.set_intensite(1.0)
	regard.draw.connect(func() -> void: _dessins += 1)

	# 1. Menu ouvert, un curseur posé, puis le silence : les yeux viennent.
	ui._m10 = 1.0
	ui._allumer(menu, true)
	ui._set_focus(0, bouton, true)
	await process_frame
	await process_frame
	_check("menu ouvert : le regard compte son silence", regard.is_processing())
	var ouverts := _laisser_passer(regard, 26)
	_check("menu ouvert : les yeux viennent après 25 s de silence", ouverts > 0.0 and float(regard.get("_vie")) > 0.0,
		"vie %.2f" % float(regard.get("_vie")))

	# 2. Le menu se ferme comme au lancement d'une manche, yeux ouverts.
	ui.hide_game_over()
	_check("le menu ne compte plus comme ouvert", not ui._panneau_ouvert(menu))
	_dessins = 0
	for i in 4:
		await process_frame
	_check("hors menu : le regard ne compte plus", not regard.is_processing())
	_check("hors menu : les yeux ouverts au menu sont effacés", float(regard.get("_vie")) <= 0.0,
		"vie %.2f" % float(regard.get("_vie")))
	_check("hors menu : le regard s'est redessiné (sinon les yeux restent peints)", _dessins >= 1)
	var en_match := _laisser_passer(regard, 60)
	_check("hors menu : une minute de match n'allume aucun œil", en_match <= 0.0,
		"yeux ouverts en match (vie jusqu'à %.2f)" % en_match)
	_dessins = 0
	for i in 4:
		await process_frame
	_check("hors menu : plus aucun redessin", _dessins == 0, "%d redessins" % _dessins)

	# 3. Le menu rouvert : le regard recompte, de zéro.
	ui._allumer(menu, true)
	ui._set_focus(0, bouton, true)
	await process_frame
	await process_frame
	_check("menu rouvert : le regard recompte", regard.is_processing())
	_check("menu rouvert : de zéro", float(regard.get("_repos")) < 1.0, "repos %.2f" % float(regard.get("_repos")))

	ui.queue_free()
	await process_frame
