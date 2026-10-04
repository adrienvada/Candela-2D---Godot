## L'écran Solo (Adrien, 2026-10-03) : « un bouton tout en haut du menu principal
## redirigeant vers Solo ».
##
## Trois choses à tenir, et aucune ne se voit d'un coup d'œil :
##
## - **la première entrée de l'accueil est SOLO**, et elle mène à `SCREEN_SOLO` ;
## - **S'ENTRAÎNER et AVENTURE ont quitté l'accueil** pour cet écran, AVENTURE d'abord ;
## - **les retours de match repassent par Solo.** `show_main_menu()` remet la pile à
##   l'accueil, puis `redescendre_vers()` rejoue le chemin : sans lui, RETOUR depuis
##   l'entraînement sauterait Solo et tomberait à l'accueil, sans qu'aucune erreur
##   ne le dise. La pile du hub (`_stack`) est l'oracle — pas l'écran courant seul,
##   qui serait juste dans les deux cas.
##
## Lancer : godot --headless --path . --script res://tools/test_menu_solo.gd
extends SceneTree

var _failures: int = 0
var _ui: Node
var _hub: MenuHub

const CHEMIN_SOLO := "user://test_menu_solo.cfg"

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== ÉCRAN SOLO ===")
	# Après une frame : les autoloads référencés par `ui.gd` n'existent pas encore
	# au moment de `_init`.
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
	if _ui == null or not _ui.has_method("redescendre_vers"):
		printerr("✗ l'interface n'a pas `redescendre_vers()`")
		quit(1)
		return
	_hub = _ui.hub
	# Une progression à soi, posée AVANT toute ouverture de l'écran de l'aventure : sans elle, l'écran lirait — et ces essais
	# écriraient — celle de la machine (`user://solo.cfg`).
	_effacer(CHEMIN_SOLO)
	_ui.aventure_progression = AventureProgression.new(CHEMIN_SOLO)

	_l_accueil()
	_l_ecran_solo()
	_les_retours_repassent_par_solo()
	_la_table_des_parents_dit_vrai()
	_effacer(CHEMIN_SOLO)

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	main.queue_free()
	quit(1 if _failures > 0 else 0)


## Le libellé d'une entrée : le premier `Label` de sa rangée qui n'est pas un chevron.
func _libelle(btn: Button) -> String:
	for rangee in btn.get_children():
		for enfant in rangee.get_children():
			if enfant is Label and String((enfant as Label).text) not in ["›", "—"]:
				return String((enfant as Label).text)
	return ""


## Les libellés des entrées d'un écran, dans l'ordre, retour compris.
func _libelles_de(ecran: String) -> Array[String]:
	var vus: Array[String] = []
	for e in _hub.list_of(ecran).get_children():
		if e is Button:
			vus.append(_libelle(e))
	return vus


func _entree(ecran: String, titre: String) -> Button:
	for e in _hub.list_of(ecran).get_children():
		if e is Button and _libelle(e) == titre:
			return e
	return null


## Remet la pile à l'accueil, comme le fait `show_main_menu()` après un match.
func _a_l_accueil() -> void:
	_hub.reset()


func _pile() -> Array[String]:
	var p: Array[String] = []
	for id in _hub._stack:
		p.append(String(id))
	return p


func _l_accueil() -> void:
	print("\n[L'accueil]")
	var libelles := _libelles_de(MenuHub.ROOT)
	_check("l'accueil a des entrées", not libelles.is_empty())
	_check("la PREMIÈRE entrée de l'accueil est « SOLO »",
		not libelles.is_empty() and libelles[0] == "SOLO", str(libelles))
	_check("S'ENTRAÎNER n'est plus à l'accueil", not libelles.has("S'ENTRAÎNER"), str(libelles))
	_check("AVENTURE n'est plus à l'accueil", not libelles.has("AVENTURE"), str(libelles))
	for autre in ["1V1 ÉCRANS SCINDÉS", "1V1 AMICAL", "1V1 COMPÉTITIF", "PERSONNALISATION", "QUITTER"]:
		_check("« %s » reste à l'accueil" % autre, libelles.has(autre), str(libelles))
	_a_l_accueil()
	var solo := _entree(MenuHub.ROOT, "SOLO")
	_check("l'entrée SOLO existe", solo != null)
	if solo != null:
		solo.pressed.emit()
		_check("un appui sur SOLO mène à `SCREEN_SOLO`", _hub.current_id() == _ui.SCREEN_SOLO, _hub.current_id())
		_check("… et la pile est [accueil, solo]", _pile() == [MenuHub.ROOT, _ui.SCREEN_SOLO], str(_pile()))
	_a_l_accueil()


func _l_ecran_solo() -> void:
	print("\n[L'écran Solo]")
	_check("l'écran Solo existe dans le hub", _hub.has_screen(_ui.SCREEN_SOLO))
	var libelles := _libelles_de(_ui.SCREEN_SOLO)
	_check("l'écran Solo porte AVENTURE, S'ENTRAÎNER, puis le retour, dans cet ordre",
		libelles == ["AVENTURE", "S'ENTRAÎNER", "‹  RETOUR"], str(libelles))
	_a_l_accueil()
	_hub.push(_ui.SCREEN_SOLO)
	var aventure := _entree(_ui.SCREEN_SOLO, "AVENTURE")
	var entrainement := _entree(_ui.SCREEN_SOLO, "S'ENTRAÎNER")
	if aventure != null:
		aventure.pressed.emit()
		_check("AVENTURE (depuis Solo) mène à `SCREEN_AVENTURE`", _hub.current_id() == _ui.SCREEN_AVENTURE, _hub.current_id())
		_check("… sous Solo", _pile() == [MenuHub.ROOT, _ui.SCREEN_SOLO, _ui.SCREEN_AVENTURE], str(_pile()))
	else:
		_check("l'entrée AVENTURE existe sous Solo", false)
	_a_l_accueil()
	_hub.push(_ui.SCREEN_SOLO)
	if entrainement != null:
		entrainement.pressed.emit()
		_check("S'ENTRAÎNER (depuis Solo) mène à `SCREEN_TRAINING`", _hub.current_id() == _ui.SCREEN_TRAINING, _hub.current_id())
		_check("… sous Solo", _pile() == [MenuHub.ROOT, _ui.SCREEN_SOLO, _ui.SCREEN_TRAINING], str(_pile()))
	else:
		_check("l'entrée S'ENTRAÎNER existe sous Solo", false)
	_hub.back()
	_check("RETOUR depuis l'entraînement ramène à Solo", _hub.current_id() == _ui.SCREEN_SOLO, _hub.current_id())
	_hub.back()
	_check("… puis RETOUR ramène à l'accueil", _hub.current_id() == MenuHub.ROOT, _hub.current_id())
	_a_l_accueil()
	# Solo est un écran de navigation pure : aucun bouton de lancement ne lui est attaché.
	_check("Solo n'a pas de lanceur (écran de navigation pure)", not _ui.LANCEURS.has(_ui.SCREEN_SOLO))


func _les_retours_repassent_par_solo() -> void:
	print("\n[Les retours de match repassent par Solo]")
	_a_l_accueil()
	_ui.redescendre_vers(_ui.SCREEN_TRAINING)
	_check("`redescendre_vers(entraînement)` laisse la pile [accueil, solo, entraînement]",
		_pile() == [MenuHub.ROOT, _ui.SCREEN_SOLO, _ui.SCREEN_TRAINING], str(_pile()))
	_hub.back()
	_check("… et un RETOUR ramène à Solo (pas à l'accueil)", _hub.current_id() == _ui.SCREEN_SOLO, _hub.current_id())

	_a_l_accueil()
	_ui.redescendre_vers(_ui.SCREEN_AVENTURE)
	_check("`redescendre_vers(aventure)` laisse la pile [accueil, solo, aventure]",
		_pile() == [MenuHub.ROOT, _ui.SCREEN_SOLO, _ui.SCREEN_AVENTURE], str(_pile()))

	_a_l_accueil()
	_ui.redescendre_vers(_ui.SCREEN_AVENTURE_SALLES)
	_check("`redescendre_vers(salles)` laisse la pile [accueil, solo, aventure, salles]",
		_pile() == [MenuHub.ROOT, _ui.SCREEN_SOLO, _ui.SCREEN_AVENTURE, _ui.SCREEN_AVENTURE_SALLES], str(_pile()))
	_hub.back()
	_check("… et un RETOUR ramène à l'écran des chapitres", _hub.current_id() == _ui.SCREEN_AVENTURE, _hub.current_id())

	# Le chapitre et la salle pris survivent à la redescente aux salles : l'écran de l'aventure, traversé en route, ne doit pas
	# remettre le choix à zéro (il le fait à l'OUVERTURE depuis Solo, pas au retour d'un match qui a eu lieu dans une salle).
	var prog: AventureProgression = _ui.aventure_progression
	for i in 3:
		prog.reussir_niveau(0, i)
	_a_l_accueil()
	_ui.aventure_chapitre = 0
	_ui.aventure_niveau = 1
	_ui.redescendre_vers(_ui.SCREEN_AVENTURE_SALLES)
	_check("la salle prise survit à la redescente jusqu'aux salles", _ui.aventure_niveau == 1, "niveau %d" % _ui.aventure_niveau)
	# … alors que la redescente vers l'écran des chapitres (fin d'un chapitre) repart du prochain à jouer, comme l'ouverture.
	_a_l_accueil()
	_ui.aventure_chapitre = 0
	_ui.aventure_niveau = 1
	_ui.redescendre_vers(_ui.SCREEN_AVENTURE)
	_check("la redescente vers les chapitres repart du prochain à jouer", _ui.aventure_niveau == 3, "niveau %d" % _ui.aventure_niveau)

	# Les autres écrans ne changent pas : un seul cran sous l'accueil.
	_a_l_accueil()
	_ui.redescendre_vers(_ui.SCREEN_LOCAL)
	_check("un écran sans parent déclaré descend d'un cran : [accueil, écrans scindés]",
		_pile() == [MenuHub.ROOT, _ui.SCREEN_LOCAL], str(_pile()))
	_a_l_accueil()
	_ui.redescendre_vers(_ui.SCREEN_HOST)
	_check("un salon en ligne aussi : [accueil, salon hôte]", _pile() == [MenuHub.ROOT, _ui.SCREEN_HOST], str(_pile()))
	_a_l_accueil()
	_ui.redescendre_vers("ecran_qui_nexiste_pas")
	_check("un écran inconnu ne change rien (pile [accueil])", _pile() == [MenuHub.ROOT], str(_pile()))
	_ui.redescendre_vers(_ui.SCREEN_SOLO)
	_ui.redescendre_vers(_ui.SCREEN_SOLO)
	_check("viser l'écran déjà courant ne le réempile pas", _pile() == [MenuHub.ROOT, _ui.SCREEN_SOLO], str(_pile()))
	_a_l_accueil()


## Chaque parent déclaré est un écran du hub : un identifiant mal orthographié serait
## refusé en silence par `push()`, et la descente s'arrêterait en route.
func _la_table_des_parents_dit_vrai() -> void:
	print("\n[La table des parents]")
	for enfant: String in _ui.PARENT_DE_L_ECRAN:
		var parent := String(_ui.PARENT_DE_L_ECRAN[enfant])
		_check("« %s » et son parent « %s » sont des écrans du hub" % [enfant, parent],
			_hub.has_screen(enfant) and _hub.has_screen(parent))
	_check("aucun écran n'est son propre ancêtre (la descente se termine)", _sans_cycle())


func _sans_cycle() -> bool:
	for depart: String in _ui.PARENT_DE_L_ECRAN:
		var vu := {}
		var courant := depart
		while _ui.PARENT_DE_L_ECRAN.has(courant):
			if vu.has(courant):
				return false
			vu[courant] = true
			courant = String(_ui.PARENT_DE_L_ECRAN[courant])
	return true


func _effacer(chemin: String) -> void:
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)
