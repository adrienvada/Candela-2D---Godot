extends SceneTree

## L'ALLUMAGE NE SE REJOUE PAS AU RETOUR DE L'ÉDITEUR DE CARTES.
##
## Adrien, 2026-09-29 vers 15:26 : « Revenir de l'éditeur de cartes rejoue l'allumage « CANDELA » : ce n'est
## pas voulu. »
##
## ## La cause
##
## `GameState._ready()` ouvrait le menu puis lançait `_allumage()` (DA6.5) — ou l'intro, au tout premier
## lancement — **à chaque fois que `main.tscn` se monte**. Or la scène ne se monte pas qu'au lancement : l'éditeur de
## cartes en revient par `get_tree().change_scene_to_file("res://main.tscn")` (`map_editor.gd`, `_go_back`), donc par un
## `_ready()` tout neuf. La ROADMAP dit quand l'allumage DOIT se jouer : au lancement du jeu — « l'histoire une
## fois, l'allumage toutes les autres fois » sont des fois de LANCEMENT, jamais de retour au menu.
##
## ## Ce que la suite tient, par le VRAI chemin (l'éditeur monté, `_go_back()`, la scène qui se recharge)
##
## 1. Au lancement, l'allumage se joue et voile le menu — le témoin, sans quoi « il ne se rejoue pas » se vérifierait
##    d'un allumage qui ne se joue jamais.
## 2. Deux allers-retours dans l'éditeur : au retour, ni allumage ni intro, le menu est ouvert, vivant (non voilé) et
##    répond à une flèche.
## 3. Le PREMIER lancement — celui où l'intro joue à la place de l'allumage — n'y change rien : au retour de
##    l'éditeur, l'allumage ne se joue pas non plus. C'est le cas qu'une marque posée par l'allumage seul
##    laisserait passer : l'intro y joue, l'allumage jamais, et il se déclencherait donc au premier retour.
##
## Le marqueur est un `static var` de `game_state.gd` : le processus l'a levé au premier `_ready()`, et cette suite le
## rebaisse elle-même (`_relancer_le_processus`) pour rejouer un lancement neuf sans en démarrer un autre.
##
## Lancer : godot --headless --path . --script res://tools/test_allumage_unique.gd
const PLANCHER := 16

var _echecs := 0
var _verifications := 0
var _reglages: Node


func _check(libelle: String, condition: bool, detail: String = "") -> void:
	_verifications += 1
	if condition:
		print("  ✓ %s" % libelle)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [libelle, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== L'ALLUMAGE NE SE REJOUE PAS AU RETOUR DE L'ÉDITEUR ===")
	_reglages = root.get_node("GameSettings")
	var intro_avant: bool = _reglages.intro_vue
	await process_frame

	await _test_lancement_ordinaire()
	await _test_premier_lancement()

	_reglages.intro_vue = intro_avant
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	if _echecs == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


# ---------------------------------------------------------------------------
# LE MONTAGE
# ---------------------------------------------------------------------------

## Rebaisse le marqueur de lancement : ce processus recommence un lancement, comme s'il venait de s'ouvrir. C'est ce qu'un
## nouveau processus a de neuf, et la seule chose — les autoloads, eux, restent ceux d'un jeu déjà ouvert.
func _relancer_le_processus() -> void:
	var script: GDScript = load("res://game_state.gd")
	script.set("_deja_demarre", false)
	_check("témoin : le marqueur de lancement est bien celui de `game_state.gd` et se rebaisse",
		script.get("_deja_demarre") == false)


## Monte `main.tscn` comme le lancement du jeu le fait : scène courante, `_ready()` à l'entrée.
func _monter_le_jeu() -> Node:
	var jeu: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(jeu)
	current_scene = jeu
	await process_frame
	await process_frame
	return jeu


## Attend que la scène courante porte ce nom, puis deux images pour que son `_ready()` ait tout posé.
func _attendre_la_scene(nom: String) -> Node:
	var fin := Time.get_ticks_msec() + 20000
	while current_scene == null or String(current_scene.name) != nom:
		if Time.get_ticks_msec() > fin:
			return null
		await process_frame
	await process_frame
	await process_frame
	return current_scene


## Ce que fait la galerie (`_open_editor`) puis le bouton de retour de l'éditeur (`_go_back`) : deux changements de
## scène, et un `_ready()` neuf pour `main.tscn` au retour.
func _aller_a_l_editeur_et_revenir() -> Node:
	change_scene_to_file("res://map_editor.tscn")
	var editeur := await _attendre_la_scene("MapEditor")
	if editeur == null:
		printerr("  ✗ l'éditeur de cartes ne s'est pas monté")
		return null
	# Rien n'est modifié : `_go_back` sort du premier appui, sans le second temps réservé au travail non sauvegardé.
	editeur.call("_go_back")
	return await _attendre_la_scene("Main")


func _appui(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


## Le retour de l'éditeur, jugé : pas de cérémonie, un menu ouvert et vivant.
func _juger_le_retour(jeu: Node, etiquette: String) -> void:
	_check("%s : l'éditeur est bien revenu à un jeu neuf" % etiquette, jeu != null and jeu.is_class("Node"))
	if jeu == null:
		return
	var ui: Node = jeu.get_node_or_null("UI")
	_check("%s : pas d'allumage « CANDELA »" % etiquette, jeu.get_node_or_null("PowerOn") == null)
	_check("%s : pas d'intro non plus" % etiquette, jeu.get_node_or_null("IntroPlanches") == null)
	if ui == null:
		_check("%s : le jeu a son UI" % etiquette, false)
		return
	_check("%s : le menu n'est pas voilé" % etiquette, not bool(ui.get("menu_voile")))
	_check("%s : le menu principal est ouvert" % etiquette,
		bool(ui.get("_is_main_menu")) and bool(ui.call("_panneau_ouvert", ui.get("game_over_panel"))))
	# Vivant : une flèche déplace la sélection. Sous un voile, `ui._input` ne fait rien.
	var avant: Variant = ui.get("p1_focus")
	ui.call("_input", _appui("p1_menu_down"))
	_check("%s : et il répond (une flèche déplace la sélection)" % etiquette, ui.get("p1_focus") != avant)


# ---------------------------------------------------------------------------
# 1 ET 2. LE LANCEMENT ORDINAIRE, PUIS L'ÉDITEUR
# ---------------------------------------------------------------------------

func _test_lancement_ordinaire() -> void:
	print("\n[Le lancement, puis deux allers-retours dans l'éditeur]")
	_relancer_le_processus()
	# Le joueur a déjà vu l'intro : l'allumage est la cérémonie de CE lancement.
	_reglages.intro_vue = true
	var jeu := await _monter_le_jeu()
	var allumage: Node = jeu.get_node_or_null("PowerOn")
	_check("au lancement, l'allumage se joue", allumage != null)
	_check("… et voile le menu pendant qu'il joue", bool(jeu.get_node("UI").get("menu_voile")))
	if allumage != null:
		allumage.call("terminer")
		await create_timer(0.8).timeout
	_check("… puis lève son voile", not bool(jeu.get_node("UI").get("menu_voile")))

	for tour in 2:
		jeu = await _aller_a_l_editeur_et_revenir()
		_juger_le_retour(jeu, "retour n° %d de l'éditeur" % (tour + 1))


# ---------------------------------------------------------------------------
# 3. LE PREMIER LANCEMENT
# ---------------------------------------------------------------------------

func _test_premier_lancement() -> void:
	print("\n[Le premier lancement, où l'intro joue à la place de l'allumage]")
	var Intro: GDScript = load("res://intro_planches.gd")
	_check("témoin : l'intro est disponible dans ce dépôt", bool(Intro.call("disponible")))
	if not bool(Intro.call("disponible")):
		return
	# Le jeu précédent est libéré avant d'en monter un autre.
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	_relancer_le_processus()
	# Un joueur qui n'a jamais vu l'intro. Le jeu la marquera lui-même à son démarrage (`marquer_intro_vue`) : la valeur
	# d'avant est rendue en fin de suite.
	_reglages.intro_vue = false
	var jeu := await _monter_le_jeu()
	_check("au premier lancement, l'intro joue", jeu.get_node_or_null("IntroPlanches") != null)
	_check("… et l'allumage ne joue pas avec elle (l'une OU l'autre)", jeu.get_node_or_null("PowerOn") == null)
	var intro: Node = jeu.get_node_or_null("IntroPlanches")
	if intro != null:
		intro.call("_terminer")
		await process_frame
	jeu = await _aller_a_l_editeur_et_revenir()
	_juger_le_retour(jeu, "premier lancement, retour de l'éditeur")
