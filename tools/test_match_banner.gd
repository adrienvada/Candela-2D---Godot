## Test headless du bandeau de recherche d'adversaire — Phase 8, étape 8.6.
##
## Le bandeau a remplacé un écran entier : c'est désormais la **seule** surface
## par laquelle on sort d'une file. S'il se trompe d'état, le joueur reste dans
## une recherche qu'il ne peut plus annuler, ou bien confirme un match alors qu'il
## voulait en sortir — les deux se paient au classement.
##
## Le cœur est doublé : on veut vérifier ce que le bandeau *fait d'un instantané*,
## pas qu'EOS réponde.
##
## Lancer : godot --headless --path . --script res://tools/test_match_banner.gd
extends SceneTree

var _failures: int = 0
var _banner: MatchBanner
var _core: FauxCoeur

## Doublure de `matchmaking.gd`, réduite à ce que le bandeau lit et appelle.
class FauxCoeur extends Node:
	var snap: Dictionary = {}
	var paire: Dictionary = {}
	var appels: Array[String] = []

	func search_snapshot() -> Dictionary:
		return snap

	func pairing_snapshot() -> Dictionary:
		return paire

	func cancel() -> void:
		appels.append("cancel")

	func accept() -> void:
		appels.append("accept")

	func refuse() -> void:
		appels.append("refuse")

## Cœur amputé d'une seule prise : le bandeau doit se taire entièrement.
class CoeurPartiel extends Node:
	func search_snapshot() -> Dictionary:
		return {"state": 1, "state_label": "Recherche…"}

	func cancel() -> void:
		pass

	func accept() -> void:
		pass
	# `refuse` manque volontairement.

func _init() -> void:
	print("=== Test du bandeau de recherche ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_banner = MatchBanner.new()
	_core = FauxCoeur.new()
	_banner.matchmaker_override = _core
	root.add_child(_banner)
	await process_frame

	_test_repos()
	_test_recherche()
	_test_trouve()
	_test_attente()
	_test_echec()
	_test_sortie_toujours_offerte()
	_test_actions()
	_test_coeur_incomplet()

	root.remove_child(_banner)
	_banner.free()
	_core.free()

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

func _pose(etat: int, extra: Dictionary = {}) -> void:
	var s := {"state": etat, "state_label": "état %d" % etat, "ranked": false}
	s.merge(extra, true)
	_core.snap = s
	_banner.refresh()

func _libelles() -> Array[String]:
	var out: Array[String] = []
	for c in _banner.focusables():
		out.append((c as Button).text)
	return out

# ---------------------------------------------------------------------------

func _test_repos() -> void:
	print("\n[Au repos]")
	_pose(MatchBanner.ST_IDLE)
	# Un bandeau permanent occuperait le haut de l'écran pour ne rien dire, et
	# apprendrait au joueur à ne plus le regarder.
	_check("aucune recherche, aucun bandeau", not _banner.visible)
	_check("et rien à atteindre au curseur", _banner.focusables().is_empty())

	_core.snap = {}
	_banner.refresh()
	_check("un instantané vide se tait aussi", not _banner.visible)

func _test_recherche() -> void:
	print("\n[En recherche]")
	_pose(MatchBanner.ST_SEARCHING, {"elapsed": 83.0, "range_label": "940 – 1060"})
	_check("le bandeau s'affiche", _banner.visible)
	# La fourchette cherchée à cet instant est ce qui rend l'attente lisible :
	# le joueur voit l'exigence baisser au lieu de subir un compteur.
	_check("le chrono est en minutes au-delà de 60 s",
		_banner._detail.text.contains("1:23"), _banner._detail.text)
	_check("la fourchette courante est dite",
		_banner._detail.text.contains("940 – 1060"), _banner._detail.text)
	_check("on peut sortir de la file", _libelles() == ["ANNULER"], str(_libelles()))

func _test_trouve() -> void:
	print("\n[Adversaire trouvé]")
	_core.paire = {"local_hosts": true}
	_pose(MatchBanner.ST_FOUND, {"handshake_remaining": 12.0})
	# En P2P l'hôte joue sans latence et l'autre non : une asymétrie qu'on
	# n'affiche pas devient une rumeur.
	_check("qui héberge est dit", _banner._detail.text.contains("vous hébergez"),
		_banner._detail.text)
	_check("le délai de réponse est dit", _banner._detail.text.contains("12 s"),
		_banner._detail.text)
	_check("confirmer ET refuser sont offerts",
		_libelles() == ["CONFIRMER", "REFUSER"], str(_libelles()))

	# Deux emplacements fixes, rangés par intention. Un bouton unique passant
	# d'ANNULER à CONFIRMER confirmerait un match à un doigt qui partait pour
	# sortir de la file.
	_pose(MatchBanner.ST_SEARCHING)
	var sortie_avant := _banner._btn_retrait
	_core.paire = {"local_hosts": false}
	_pose(MatchBanner.ST_FOUND)
	_check("l'emplacement de sortie reste le même objet",
		_banner._btn_retrait == sortie_avant)
	_check("et l'engagement n'a jamais pris sa place",
		_banner._btn_engage != sortie_avant)
	_check("l'hébergement adverse est dit aussi",
		_banner._detail.text.contains("il héberge"), _banner._detail.text)

	# Une clé absente n'est pas une valeur par défaut : deviner qui héberge
	# serait juste une fois sur deux.
	_core.paire = {}
	_pose(MatchBanner.ST_FOUND)
	_check("hôte inconnu ⇒ on n'invente pas",
		not _banner._detail.text.contains("héberge"), _banner._detail.text)

func _test_attente() -> void:
	print("\n[En attente de l'adversaire]")
	_core.paire = {"local_hosts": true}
	_pose(MatchBanner.ST_AWAITING, {"handshake_remaining": 7.0})
	# On a déjà confirmé : reconfirmer n'aurait aucun sens, mais se rétracter si.
	_check("plus rien à confirmer, seulement à refuser",
		_libelles() == ["REFUSER"], str(_libelles()))

func _test_echec() -> void:
	print("\n[Échec]")
	_pose(MatchBanner.ST_FAILED, {"last_error": "Session Epic inactive."})
	_check("la raison est reprise telle quelle",
		_banner._detail.text.contains("Session Epic inactive."), _banner._detail.text)
	_check("et le bandeau se referme d'un geste",
		_libelles() == ["FERMER"], str(_libelles()))

	_pose(MatchBanner.ST_FAILED, {"last_error": ""})
	_check("sans raison, on dit quand même quelque chose",
		_banner._detail.text != "")

## L'invariant de la manette, et le seul qui ne souffre aucune exception :
## tant qu'une file tourne, il doit toujours exister un contrôle **visible et
## atteignable** pour en sortir. Sans lui, la seule issue serait de quitter le jeu.
func _test_sortie_toujours_offerte() -> void:
	print("\n[Une sortie, toujours]")
	for etat in [MatchBanner.ST_SEARCHING, MatchBanner.ST_FOUND,
			MatchBanner.ST_AWAITING, MatchBanner.ST_FAILED]:
		_core.paire = {"local_hosts": true}
		_pose(etat)
		var sortie := _banner._btn_retrait
		_check("état %d : sortie visible et atteignable" % etat,
			sortie.visible and not sortie.disabled
			and sortie.focus_mode != Control.FOCUS_NONE)

func _test_actions() -> void:
	print("\n[Ce que les boutons appellent]")
	_core.appels.clear()

	_pose(MatchBanner.ST_SEARCHING)
	_banner._btn_retrait.pressed.emit()
	_check("annuler pendant la recherche appelle cancel()",
		_core.appels == ["cancel"], str(_core.appels))

	_core.appels.clear()
	_core.paire = {"local_hosts": true}
	_pose(MatchBanner.ST_FOUND)
	_banner._btn_engage.pressed.emit()
	_check("confirmer appelle accept()", _core.appels == ["accept"], str(_core.appels))

	_core.appels.clear()
	_pose(MatchBanner.ST_FOUND)
	_banner._btn_retrait.pressed.emit()
	# Refuser un match trouvé n'est PAS annuler la recherche : le cœur remet en
	# file sans perdre le temps déjà attendu. Appeler cancel() ici sortirait le
	# joueur de la file qu'il vient de dire vouloir continuer.
	_check("refuser un match trouvé appelle refuse(), pas cancel()",
		_core.appels == ["refuse"], str(_core.appels))

	_core.appels.clear()
	_pose(MatchBanner.ST_AWAITING)
	_banner._btn_retrait.pressed.emit()
	_check("se rétracter pendant l'attente appelle refuse()",
		_core.appels == ["refuse"], str(_core.appels))

	_core.appels.clear()
	_pose(MatchBanner.ST_FAILED, {"last_error": "x"})
	_banner._btn_retrait.pressed.emit()
	_check("fermer après un échec appelle cancel()",
		_core.appels == ["cancel"], str(_core.appels))

## Le cœur est pris en entier ou pas du tout. Un bandeau qui saurait lire l'état
## sans pouvoir refuser donnerait un bouton mort, et un bouton mort ne se
## distingue pas d'un jeu cassé.
func _test_coeur_incomplet() -> void:
	print("\n[Cœur incomplet]")
	var partiel := CoeurPartiel.new()
	_banner.matchmaker_override = partiel
	_banner.refresh()
	_check("une seule prise manquante suffit à se taire", not _banner.visible)
	_check("et rien n'est atteignable", _banner.focusables().is_empty())
	_banner.matchmaker_override = _core
	partiel.free()
