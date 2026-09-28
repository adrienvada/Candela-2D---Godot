extends SceneTree

## LA TORCHE DE MENU S'ÉTEINT HORS DU MENU — la garde du « disque violacé » de l'écran scindé.
##
## `MenuTorch` (M9) pose sous chaque curseur de menu une flaque de lumière à la couleur du joueur. Elle s'allumait à
## chaque `_set_focus` et ne s'éteignait jamais : `viser(j, null)` n'était appelé nulle part. En sortant du menu, les
## deux flaques restaient dessinées par-dessus le match, au dernier bouton visé — J1 bleu et J2 rouge au même point
## font un disque violacé ≈ (19, 15, 19), à un endroit fixe de l'ÉCRAN, donc dans la moitié d'un seul joueur en écran
## scindé (docs/iso/cloud/disque-violace/RAPPORT.md). Le noir absolu et l'équité en cause, dans le jeu par défaut.
##
## Ce que la garde exige :
##   1. menu ouvert, les deux curseurs posés : les deux flaques sont allumées (le harnais atteint bien l'effet) ;
##   2. le menu fermé comme au lancement d'une manche (`hide_game_over`) : les deux curseurs se cachent, les deux
##      flaques s'éteignent, ET la torche se redessine (sans redessin, l'ancien dessin reste à l'écran) ;
##   3. le menu rouvert et un curseur reposé : la flaque se rallume (rien n'est cassé pour le menu).
##
##     godot --headless --path . --script res://tools/test_torche_hors_menu.gd

var _echecs := 0
var _dessins := 0


func _init() -> void:
	# `ui.gd` nomme des autoloads : l'attente d'une image avant le `load` (comme `test_vitrine_menus.gd`).
	await process_frame
	await _tester()
	if _echecs == 0:
		print("\n✓ la torche de menu s'éteint hors du menu — tout passe")
	else:
		print("\n✗ %d échec(s)" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _check(nom: String, ok: bool) -> void:
	print("  %s %s" % ["✓" if ok else "✗", nom])
	if not ok:
		_echecs += 1


func _tester() -> void:
	print("[La torche de menu hors du menu]")
	var ui: Node = (load("res://ui.tscn") as PackedScene).instantiate()
	ui.name = "UI"
	root.add_child(ui)
	await process_frame
	for m in ["_set_focus", "_allumer", "hide_game_over", "_panneau_ouvert", "_update_focus_rings"]:
		if not ui.has_method(m):
			_check("le harnais atteint UI.%s()" % m, false)
			ui.queue_free()
			return
	var torche: Control = ui.menu_torch
	var menu: Control = ui.game_over_panel
	var bouton: Control = ui.btn_replay
	_check("la torche, le menu et un bouton existent", torche != null and menu != null and bouton != null)
	if torche == null or menu == null or bouton == null:
		ui.queue_free()
		return
	torche.draw.connect(func() -> void: _dessins += 1)
	var cibles: Dictionary = torche.get("_cibles")
	if is_zero_approx(float(torche.get("_intensite"))):
		# Un poste dont les réglages éteignent la vitrine ne dit rien de ce défaut : on rallume pour l'épreuve.
		torche.set_intensite(1.0)

	# 1. Menu ouvert, les deux joueurs visent le même bouton — le cas du lancement en écran scindé.
	ui._m10 = 1.0
	ui._allumer(menu, true)
	ui._set_focus(0, bouton, true)
	ui._set_focus(1, bouton, true)
	await process_frame
	await process_frame
	cibles = torche.get("_cibles")
	_check("menu ouvert : la flaque de J1 est allumée", cibles.has(0))
	_check("menu ouvert : la flaque de J2 est allumée", cibles.has(1))

	# 2. Le menu se ferme comme au lancement d'une manche.
	ui.hide_game_over()
	_check("le menu ne compte plus comme ouvert", not ui._panneau_ouvert(menu))
	_dessins = 0
	for i in 4:
		await process_frame
	_check("hors menu : les deux liserés sont cachés", not ui.p1_cursor.visible and not ui.p2_cursor.visible)
	cibles = torche.get("_cibles")
	_check("hors menu : la flaque de J1 est éteinte", not cibles.has(0))
	_check("hors menu : la flaque de J2 est éteinte", not cibles.has(1))
	_check("hors menu : la torche s'est redessinée (sinon l'ancienne flaque reste à l'écran)", _dessins >= 1)
	# Et rien ne se redessine plus ensuite : l'extinction se fait une fois, pas à chaque image du match.
	_dessins = 0
	for i in 4:
		await process_frame
	_check("hors menu : plus aucun redessin une fois éteinte", _dessins == 0)

	# 3. Le menu rouvert, un curseur reposé : la flaque revient.
	ui._allumer(menu, true)
	ui._set_focus(0, bouton, true)
	await process_frame
	cibles = torche.get("_cibles")
	_check("menu rouvert : la flaque de J1 se rallume", cibles.has(0))

	ui.queue_free()
	await process_frame
