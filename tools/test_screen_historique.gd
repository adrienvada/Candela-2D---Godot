## Test headless de l'écran d'historique (`screen_history.gd`).
##
## Ce que la suite protège, dans l'ordre d'importance :
##
##   • **ce qui a été écarté est dit** — un journal peut contenir des lignes
##     illisibles, ou écrites par une version plus récente du jeu. Un historique
##     qui les escamote se lit comme complet alors qu'il ne l'est pas, et c'est
##     la seule faute qu'un historique ne peut pas se permettre ;
##   • le journal vide se distingue du journal absent d'explication : au premier
##     lancement, l'écran dit pourquoi il est vide au lieu de ne rien montrer ;
##   • aucune règle de lecture n'est réimplémentée dans l'écran — il lit
##     `MatchHistoryView` et rien d'autre, sans quoi deux lectures du même
##     journal finiraient par diverger ;
##   • `refresh()` est idempotent, y compris avant toute construction, parce que
##     le hub le rappelle à chaque entrée sur l'écran ;
##   • les lignes sont un pool fixe : elles se remplissent et se masquent, elles
##     ne se reconstruisent pas — sans quoi le curseur perdrait son focus au
##     moment précis où l'on revient sur l'écran.
##
## Le journal réel n'est jamais touché : chaque cas passe par un fichier
## temporaire sous `user://`, et la suite vérifie en sortant que le vrai est
## intact. Les suites headless partagent le `user://` du jeu installé.
##
## Lancer : godot --headless --path . --script res://tools/test_screen_historique.gd
extends SceneTree

var _failures: int = 0

## Chargés dans `_run()`, jamais dans `_init()` : en mode --script, `_init()`
## précède les autoloads ET le cache des classes globales. Un `class_name`
## référencé trop tôt rend un objet nu, dont les erreurs n'incrémentent aucun
## compteur — la suite annonce alors « tous les tests passent » sans rien avoir
## exécuté.
var _screen_script: GDScript
var _view: GDScript
var _record: GDScript

const TMP_PATH := "user://test_historique_tmp.json"

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== ÉCRAN HISTORIQUE ===")
	_screen_script = load("res://screen_history.gd")
	_view = load("res://match_history_view.gd")
	_record = load("res://match_record.gd")
	if _screen_script == null or _view == null:
		printerr("✗ scripts introuvables")
		quit(1)
		return

	_test_construction()
	_test_vide()
	_test_lignes()
	_test_ecartes()
	_test_idempotence()
	_test_journal_reel_intact()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

## Fabrique un écran construit, prêt à rafraîchir.
func _make_screen() -> Node:
	var screen: Node = _screen_script.new()
	var body := VBoxContainer.new()
	root.add_child(screen)
	screen.add_child(body)
	screen.build(body)
	return screen

func _test_construction() -> void:
	print("\n[Construction]")
	var screen := _make_screen()
	_check("le script est bien attaché", screen.has_method("refresh"))
	_check("l'écran porte un titre", String(screen.screen_title()) != "")
	# Le pool est fixe et déclaré : c'est ce qui garantit qu'un rafraîchissement
	# ne reconstruit rien.
	_check("le pool de lignes est celui annoncé",
		screen._rows.size() == screen.SHOWN,
		"%d / %d" % [screen._rows.size(), screen.SHOWN])
	screen.queue_free()

func _test_vide() -> void:
	print("\n[Journal vide]")
	var screen := _make_screen()
	screen._rows = screen._rows  # no-op explicite : on ne touche pas au pool
	_apply(screen, {"lignes": [], "lus": 0, "ignores": 0, "trop_recents": 0},
		{"matchs": 0})
	_check("le message d'absence est montré", screen._empty.visible)
	_check("il explique au lieu de constater",
		String(screen._empty.text).length() > 20, screen._empty.text)
	_check("aucune ligne n'est visible", not screen._rows[0]["ligne"].visible)
	_check("le résumé ne prétend aucun match",
		not String(screen._summary.text).is_empty()
		and not String(screen._summary.text).contains("1 match"),
		screen._summary.text)
	screen.queue_free()

func _test_lignes() -> void:
	print("\n[Lignes remplies]")
	var screen := _make_screen()
	var l1 := {"date_texte": "18/08 06:12", "issue_texte": "VICTOIRE",
		"issue": _view.Outcome.WIN, "duree_texte": "02:31", "mode_texte": "En ligne — hôte",
		"carte": "arene_standard", "arme_moi": "Pompe", "forfait": false}
	var l2 := {"date_texte": "18/08 05:58", "issue_texte": "DÉFAITE",
		"issue": _view.Outcome.LOSS, "duree_texte": "01:04", "mode_texte": "En ligne — invité",
		"carte": "arene_trou", "arme_moi": "Fusil", "forfait": true}
	_apply(screen, {"lignes": [l1, l2], "lus": 2, "ignores": 0, "trop_recents": 0},
		{"matchs": 2, "bilan_texte": "1V 1D 0N", "duree_totale_texte": "3 min",
			"arme_favorite": "Pompe", "arme_favorite_matchs": 1, "forfaits": 1})

	_check("l'absence de match n'est plus annoncée", not screen._empty.visible)
	_check("la première ligne est visible", screen._rows[0]["ligne"].visible)
	_check("la seconde aussi", screen._rows[1]["ligne"].visible)
	_check("la troisième est masquée", not screen._rows[2]["ligne"].visible)
	_check("l'issue est reprise telle quelle",
		String(screen._rows[0]["issue"].text) == "VICTOIRE", screen._rows[0]["issue"].text)
	# La couleur porte l'information qu'on cherche en parcourant la liste.
	_check("victoire et défaite ne portent pas la même couleur",
		screen._rows[0]["issue"].get_theme_color("font_color")
		!= screen._rows[1]["issue"].get_theme_color("font_color"))
	_check("le forfait est nommé sur la ligne",
		String(screen._rows[1]["reste"].text).contains("forfait"),
		screen._rows[1]["reste"].text)
	_check("la carte et l'arme sont là",
		String(screen._rows[0]["reste"].text).contains("arene_standard")
		and String(screen._rows[0]["reste"].text).contains("Pompe"),
		screen._rows[0]["reste"].text)
	_check("le bilan de soirée est affiché",
		String(screen._summary.text).contains("1V 1D 0N"), screen._summary.text)
	_check("l'arme favorite est dite",
		String(screen._detail.text).contains("Pompe"), screen._detail.text)
	screen.queue_free()

## LE contrôle de cette suite : ce que la lecture a écarté doit se voir.
func _test_ecartes() -> void:
	print("\n[Ce qui est écarté est dit]")
	var screen := _make_screen()

	_apply(screen, {"lignes": [], "lus": 3, "ignores": 0, "trop_recents": 2},
		{"matchs": 0})
	_check("les matchs d'une version plus récente sont signalés",
		screen._warning.visible and String(screen._warning.text).contains("2"),
		screen._warning.text)
	_check("et nommés comme tels",
		String(screen._warning.text).contains("récente"), screen._warning.text)

	_apply(screen, {"lignes": [], "lus": 4, "ignores": 3, "trop_recents": 0},
		{"matchs": 0})
	_check("les enregistrements illisibles sont signalés",
		screen._warning.visible and String(screen._warning.text).contains("3"),
		screen._warning.text)

	_apply(screen, {"lignes": [], "lus": 5, "ignores": 1, "trop_recents": 1},
		{"matchs": 0})
	_check("les deux causes cohabitent dans le même message",
		String(screen._warning.text).contains("récente")
		and String(screen._warning.text).contains("illisible"),
		screen._warning.text)

	_apply(screen, {"lignes": [], "lus": 2, "ignores": 0, "trop_recents": 0},
		{"matchs": 0})
	_check("rien d'écarté, aucun avertissement", not screen._warning.visible,
		screen._warning.text)
	screen.queue_free()

func _test_idempotence() -> void:
	print("\n[Idempotence]")
	# Avant toute construction : le hub rafraîchit parfois un écran jamais montré.
	var vierge: Node = _screen_script.new()
	vierge.refresh()
	vierge.refresh()
	_check("rafraîchir un écran non construit ne casse rien", true)
	vierge.free()

	var screen := _make_screen()
	var l := {"date_texte": "18/08", "issue_texte": "ÉGALITÉ",
		"issue": _view.Outcome.DRAW, "duree_texte": "05:00", "mode_texte": "Écran partagé",
		"carte": "arene_standard", "arme_moi": "", "forfait": false}
	var rapport := {"lignes": [l], "lus": 1, "ignores": 0, "trop_recents": 0}
	_apply(screen, rapport, {"matchs": 1})
	var avant: Array = []
	for r in screen._rows:
		avant.append(r["ligne"])
	_apply(screen, rapport, {"matchs": 1})
	var identiques := true
	for i in screen._rows.size():
		if screen._rows[i]["ligne"] != avant[i]:
			identiques = false
	_check("les lignes ne sont pas reconstruites d'un rafraîchissement à l'autre",
		identiques)
	_check("le contenu reste le même", String(screen._rows[0]["issue"].text) == "ÉGALITÉ")
	screen.queue_free()

## Les suites partagent le `user://` du jeu installé : on vérifie que le vrai
## journal n'a pas été touché, et on nettoie le fichier temporaire.
func _test_journal_reel_intact() -> void:
	print("\n[Le journal réel est intact]")
	var reel := String(_record.HISTORY_PATH)
	var avant := FileAccess.file_exists(reel)
	var taille := -1
	if avant:
		var f := FileAccess.open(reel, FileAccess.READ)
		if f != null:
			taille = f.get_length()
			f.close()
	# L'écran ne lit qu'à travers `MatchHistoryView`, jamais en écrivant.
	var screen := _make_screen()
	screen.refresh()
	screen.queue_free()
	var apres := FileAccess.file_exists(reel)
	_check("l'existence du journal n'a pas changé", avant == apres)
	if avant and apres:
		var f2 := FileAccess.open(reel, FileAccess.READ)
		var taille2 := f2.get_length() if f2 != null else -2
		if f2 != null:
			f2.close()
		_check("sa taille non plus", taille == taille2, "%d → %d" % [taille, taille2])
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))

## Injecte un rapport de lecture et un bilan, sans passer par le disque.
##
## L'écran lit `MatchHistoryView` en dur ; on ne peut donc pas lui substituer une
## source. On appelle donc ses propres fonctions de mise en forme, qui sont ce
## que cette suite protège — la lecture du journal, elle, a sa propre suite.
func _apply(screen: Node, rapport: Dictionary, bilan: Dictionary) -> void:
	var lignes: Array = rapport.get("lignes", [])
	screen._summary.text = screen._summary_text(bilan)
	screen._detail.text = screen._detail_text(bilan)
	screen._empty.visible = lignes.is_empty()
	for i in screen._rows.size():
		var montree: bool = i < lignes.size()
		screen._rows[i]["ligne"].visible = montree
		if montree:
			screen._fill_row(screen._rows[i], lignes[i])
	screen._warning.text = screen._warning_text(rapport)
	screen._warning.visible = not String(screen._warning.text).is_empty()
