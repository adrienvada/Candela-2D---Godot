## Test headless du panneau de pause, séparé du menu à onglets à la Phase 5.
##
## Le vrai `ui.gd` est instancié — pas une copie, pas un double : ces règles ne
## valent que si elles portent sur le menu réellement livré.
##
## Ce que ce test couvre : l'ouverture et la fermeture de la pause, son isolement
## du menu à onglets, la navigation qui n'en sort pas, la parenthèse des options,
## et surtout **les deux signaux par lesquels un abandon devient un forfait**.
##
## Ce qu'il ne couvre pas, et c'est délibéré : la mise en page à l'écran, qu'aucun
## test headless ne remplace. Il vérifie que les bons nœuds existent, sont
## atteignables et émettent ce qu'il faut — pas qu'ils sont lisibles.
##
## Lancer : godot --headless --path . --script res://tools/test_pause_menu.gd
extends SceneTree

var _failures: int = 0
var _ui: Node

func _init() -> void:
	print("=== Test du panneau de pause ===")
	_run.call_deferred()

func _run() -> void:
	# `ui.gd` référence des autoloads (MapData, NetworkManager…). Les charger
	# depuis `_init` échouait à la compilation, silencieusement : Godot rendait un
	# CanvasLayer nu et chaque appel partait en erreur sans faire échouer le test.
	# D'où l'attente d'une image, et le garde-fou juste en dessous.
	await process_frame
	var scene: PackedScene = load("res://ui.tscn")
	_ui = scene.instantiate()
	_ui.name = "UI"
	root.add_child(_ui)
	await process_frame

	# Contrôle préalable ÉLARGI, et il a été payé : la suite a un jour annoncé
	# « tous les tests passent » en appelant `_visible_tabs()`, supprimée avec la
	# barre d'onglets. Une erreur de script n'échoue pas un test — seul un `_check`
	# le fait. Le harnais doit donc vérifier son propre contrat avant de conclure.
	for m in ["_handle_pause_input", "_resume_game", "force_close_pause",
			"is_pause_menu_open", "_open_pause_options", "_nav_candidates"]:
		if not _ui.has_method(m):
			printerr("\n✗ ui.gd n'expose pas %s : le test ne prouverait rien." % m)
			quit(1)
			return
	for prop in ["hub", "pause_panel", "btn_back", "game_over_panel"]:
		if _ui.get(prop) == null:
			printerr("\n✗ ui.gd n'a pas %s : le test ne prouverait rien." % prop)
			quit(1)
			return

	_test_construction()
	await _test_ouverture_fermeture()
	_test_isolement_du_menu()
	_test_navigation_captive()
	_test_signaux_de_sortie()
	_test_parenthese_options()
	_test_fermeture_forcee()
	_test_retour_menu_principal()

	# Libéré explicitement : sinon Godot signale des fuites à la sortie, et ce
	# bruit noierait une vraie fuite le jour où il y en aura une.
	root.remove_child(_ui)
	_ui.free()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

## Place l'UI dans l'état « match en cours » : ni menu principal, ni écran de fin.
func _en_match() -> void:
	_ui._is_main_menu = false
	_ui._options_from_pause = false
	_ui.game_over_panel.hide()
	_ui.pause_panel.hide()
	paused = false

# ---------------------------------------------------------------------------

func _test_construction() -> void:
	print("\n[Construction]")
	_check("le panneau de pause existe", _ui.pause_panel != null)
	_check("il est caché au démarrage",
		_ui.pause_panel != null and not _ui.pause_panel.visible)
	_check("il porte ses quatre issues et rien d'autre",
		_ui.btn_pause_resume != null and _ui.btn_pause_options != null \
		and _ui.btn_pause_menu != null and _ui.btn_pause_quit != null)
	# Le menu à onglets ne doit plus proposer de reprise : il ne s'affiche plus
	# jamais par-dessus un match, sauf pour les options, qui ont leur retour.
	_check("la barre d'actions du menu offre un RETOUR, caché par défaut",
		_ui.btn_back != null and not _ui.btn_back.visible)

## Attend que le fondu d'extinction (M10) ait fini de jouer.
##
## Budget large et sortie dès que c'est fait : on veut prouver que le panneau
## finit vraiment par disparaître, pas mesurer une durée. Un test qui dormirait
## un temps fixe deviendrait rouge le jour où la durée du fondu change d'un
## centième.
func _attendre_extinction(panneau: Control) -> void:
	var tours := 0
	while panneau.visible and tours < 240:
		await process_frame
		tours += 1

func _test_ouverture_fermeture() -> void:
	print("\n[Ouverture et fermeture]")
	_en_match()

	_check("aucune pause ouverte au départ", not _ui.is_pause_menu_open())
	_check("la pause s'ouvre sur l'événement système", _ui._handle_pause_input())
	_check("le panneau est visible", _ui.pause_panel.visible)
	_check("is_pause_menu_open le confirme", _ui.is_pause_menu_open())

	_check("un second appui la referme", _ui._handle_pause_input())
	# ÉLARGI le 2026-08-18 avec M10, l'extinction des feux. Le panneau ne
	# disparaît plus d'un coup : il se noie dans le noir avant que le rideau se
	# lève. `visible` reste donc vrai six centièmes de seconde de plus.
	#
	# Ce qui protège le joueur n'est pas `visible`, c'est **la décision** : à
	# l'instant de l'appui, la pause est levée et le joueur a repris la main. En
	# ligne, où le monde n'a jamais cessé de tourner, un dixième de seconde
	# d'inaction imposée après avoir repris est une mort qu'on ne comprend pas.
	# C'est cette garantie-là qu'on vérifie d'abord, et immédiatement.
	_check("la pause est levée SUR-LE-CHAMP", not _ui.is_pause_menu_open())
	_check("l'arbre n'est plus gelé", not paused)
	# Et le panneau finit bien par disparaître pour de bon : un fondu qui ne se
	# terminerait pas laisserait un menu noir par-dessus l'arène, à jamais.
	await _attendre_extinction(_ui.pause_panel)
	_check("le panneau finit caché", not _ui.pause_panel.visible)

	# Depuis le menu principal, la pause n'a rien à ouvrir.
	_ui._is_main_menu = true
	_check("le menu principal ne se met pas en pause", not _ui._handle_pause_input())
	_check("aucun panneau de pause n'est apparu", not _ui.pause_panel.visible)

func _test_isolement_du_menu() -> void:
	print("\n[Isolement du menu à onglets]")
	_en_match()
	_ui._handle_pause_input()

	_check("le menu à onglets reste caché pendant la pause",
		not _ui.game_over_panel.visible)
	_check("la préparation de match n'est pas exposée",
		not _ui.weapon_hbox.visible or not _ui.game_over_panel.visible)
	_ui._resume_game()

func _test_navigation_captive() -> void:
	print("\n[Navigation]")
	_en_match()
	_ui._handle_pause_input()

	# La pause est modale : le curseur ne doit pas filer dans les onglets, qui
	# sont cachés mais toujours présents dans l'arbre.
	var attendus := [_ui.btn_pause_resume, _ui.btn_pause_options,
		_ui.btn_pause_menu, _ui.btn_pause_quit]
	for player in 2:
		var candidats: Array = _ui._nav_candidates(player)
		_check("joueur %d : les quatre boutons de pause sont atteignables" % (player + 1),
			candidats.size() == attendus.size(), "%d candidat(s)" % candidats.size())
		var tous := true
		for btn in attendus:
			if not candidats.has(btn):
				tous = false
		_check("joueur %d : aucun bouton du menu n'est atteignable" % (player + 1), tous)

	_check("le curseur se pose sur REPRENDRE",
		_ui.p1_focus == _ui.btn_pause_resume,
		str(_ui.p1_focus.text) if _ui.p1_focus != null else "aucun")
	_ui._resume_game()

## Le point qui compte : un abandon en ligne vaut forfait, et il est archivé par
## `game_state.gd` en réponse à ces deux signaux. Si un bouton cesse de les
## émettre, le forfait disparaît sans le moindre message d'erreur.
func _test_signaux_de_sortie() -> void:
	print("\n[Sorties — la chaîne du forfait]")
	_en_match()
	_ui._handle_pause_input()

	var vu_menu := [false]
	var vu_quit := [false]
	_ui.main_menu_requested.connect(func() -> void: vu_menu[0] = true)
	_ui.quit_requested.connect(func() -> void: vu_quit[0] = true)

	_ui.btn_pause_menu.pressed.emit()
	_check("MENU PRINCIPAL émet main_menu_requested", vu_menu[0])
	_check("il dégèle l'arbre avant de partir", not paused)

	_en_match()
	_ui._handle_pause_input()
	_ui.btn_pause_quit.pressed.emit()
	_check("QUITTER émet quit_requested", vu_quit[0])
	_check("il dégèle l'arbre avant de partir", not paused)
	_ui._resume_game()

func _test_parenthese_options() -> void:
	print("\n[Options depuis la pause]")
	_en_match()
	_ui._handle_pause_input()
	_ui.btn_pause_options.pressed.emit()

	_check("le menu s'ouvre", _ui.game_over_panel.visible)
	_check("la pause s'efface derrière", not _ui.pause_panel.visible)
	_check("le hub s'ouvre sur la personnalisation, et sur rien d'autre",
		_ui.hub.current_id() == _ui.SCREEN_CUSTOM, _ui.hub.current_id())
	_check("le RETOUR est offert", _ui.btn_back.visible)
	_check("aucune relance n'est proposée en plein match", not _ui.btn_replay.visible)
	# Du point de vue du joueur, il est toujours en pause : il ne doit pas agir.
	_check("le jeu se sait toujours en pause", _ui.is_pause_menu_open())

	_ui._handle_pause_input()
	_check("l'événement système ramène à la pause", _ui.pause_panel.visible)
	_check("et referme le menu", not _ui.game_over_panel.visible)
	_check("le hub est ramené à l'accueil", _ui.hub.current_id() == MenuHub.ROOT,
		_ui.hub.current_id())

	_ui.btn_pause_options.pressed.emit()
	_ui.btn_back.pressed.emit()
	_check("le bouton RETOUR ramène lui aussi à la pause", _ui.pause_panel.visible)
	_ui._resume_game()

## La killcam s'est déjà retrouvée derrière un panneau « PAUSE » que plus rien ne
## fermait. La parenthèse des options ouvre la même porte : elle doit se refermer
## aussi.
func _test_fermeture_forcee() -> void:
	print("\n[Fermeture forcée — killcam]")
	_en_match()
	_ui._handle_pause_input()
	_ui.force_close_pause()
	_check("la pause cède la place", not _ui.pause_panel.visible)
	_check("l'arbre est dégelé", not paused)

	_en_match()
	_ui._handle_pause_input()
	_ui.btn_pause_options.pressed.emit()
	_ui.force_close_pause()
	_check("les options cèdent la place aussi", not _ui.game_over_panel.visible)
	_check("l'état interne est remis à plat", not _ui.is_pause_menu_open())
	_check("le hub est ramené à l'accueil", _ui.hub.current_id() == MenuHub.ROOT)

func _test_retour_menu_principal() -> void:
	print("\n[Retour au menu principal]")
	# Un menu principal ouvert après un passage par les options ne doit garder
	# aucune trace de la parenthèse.
	_en_match()
	_ui._handle_pause_input()
	_ui.btn_pause_options.pressed.emit()
	_ui.show_main_menu()

	_check("le menu principal s'affiche", _ui.game_over_panel.visible)
	_check("la pause est refermée", not _ui.pause_panel.visible)
	_check("le RETOUR est rangé", not _ui.btn_back.visible)
	_check("le hub est à l'accueil", _ui.hub.current_id() == MenuHub.ROOT,
		_ui.hub.current_id())
	_check("la préparation de match est de retour", _ui.weapon_hbox.visible)
