## Le bilan d'une fin de soirée (V6.10 / DA6.3 / DA6.4).
##
## De la comptabilité, et la comptabilité se relit à froid : ce fichier ne charge
## ni `game_state.gd`, ni le moindre autoload. Même raison que
## `test_serie_de_session.gd` — en `--script` les noms d'autoload ne résolvent
## pas, l'erreur avorte la fonction de test **sans incrémenter le compteur**, et
## la suite annonce « tous les tests passent » sur des appels morts.
##
## Ce qui est vérifié ici, et pourquoi ces cas-là :
##
## - **La fenêtre de la soirée.** L'historique persiste entre deux lancements ;
##   une carte qui compterait les matchs d'hier mentirait sur ce soir.
## - **Le seuil de trois.** En deçà, il n'y a pas de soirée, et la carte ne doit
##   pas s'ouvrir.
## - **Les deux façons de compter une victoire** — l'issue déclarée en ligne, le
##   vainqueur numéroté en écran partagé. C'est le seul endroit du fichier où
##   deux chemins produisent la même valeur, donc le seul qui puisse diverger.
## - **Le départage du favori.** Sans lui, deux armes à égalité donnent une
##   réponse qui dépend de l'ordre d'insertion du dictionnaire — donc une carte
##   qui change d'avis sur la même soirée.
##
## Lancer : godot --headless --path . --script res://tools/test_bilan_de_soiree.gd
extends SceneTree

const B := preload("res://bilan_de_soiree.gd")

const SEANCE := "2026-09-09T20:00:00"

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== BILAN DE SOIRÉE ===")
	_test_fenetre()
	_test_seuil()
	_test_comptage()
	_test_favoris()
	_test_phrase()
	_test_durees()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


## Un match plausible. `t` est l'horodatage, `v` le vainqueur (0, 1 ou -1).
func _m(t: String, v: int, issue: String = "", arme1 := "Pistolet",
		arme2 := "Fusil", carte := "default", duree := 120.0) -> Dictionary:
	return {"horodatage": t, "vainqueur": v, "egalite": v < 0, "issue": issue,
		"arme_j1": arme1, "arme_j2": arme2, "carte": carte, "duree": duree}


func _test_fenetre() -> void:
	print("\n[Ce soir, et pas hier]")
	var histo := [
		_m("2026-09-08T21:00:00", 0, "win"),
		_m("2026-09-09T20:30:00", 0, "win"),
		_m("2026-09-09T21:00:00", 1, "loss"),
	]
	var b: Dictionary = B.de_la_soiree(histo, 0, SEANCE)
	_check("les matchs d'avant la séance sont écartés", int(b["matchs"]) == 2,
		str(b["matchs"]))
	_check("sans repère, tout l'historique compte",
		int(B.de_la_soiree(histo, 0, "")["matchs"]) == 3)
	# Le plancher de durée : un match de deux secondes est une connexion qui
	# tombe, pas un match. Le compter fausserait « le plus court », qui est
	# justement une ligne qu'on lit.
	var court := histo.duplicate()
	court.append(_m("2026-09-09T22:00:00", 0, "win", "Pistolet", "Fusil",
		"default", 2.0))
	_check("un match plus court que le plancher n'est pas un match",
		int(B.de_la_soiree(court, 0, SEANCE)["matchs"]) == 2)


func _test_seuil() -> void:
	print("\n[Le seuil de la fiche V6.10]")
	var deux := [_m("2026-09-09T20:10:00", 0, "win"),
		_m("2026-09-09T20:20:00", 0, "win")]
	_check("deux matchs ne font pas une soirée",
		not bool(B.de_la_soiree(deux, 0, SEANCE)["assez"]))
	deux.append(_m("2026-09-09T20:30:00", 1, "loss"))
	_check("trois en font une",
		bool(B.de_la_soiree(deux, 0, SEANCE)["assez"]))
	_check("et une soirée vide n'en est pas une",
		not bool(B.de_la_soiree([], 0, SEANCE)["assez"]))


func _test_comptage() -> void:
	print("\n[Les deux façons de compter une victoire]")
	# En ligne : l'issue est déclarée par la machine qui a joué, et c'est la
	# seule fonction du jeu qui la calcule. On la relit, on ne la refait pas.
	var en_ligne := [
		_m("2026-09-09T20:10:00", 1, "win"),
		_m("2026-09-09T20:20:00", 0, "loss"),
		_m("2026-09-09T20:30:00", -1, "draw"),
	]
	var b: Dictionary = B.de_la_soiree(en_ligne, 1, SEANCE)
	_check("en ligne, l'issue déclarée fait foi",
		int(b["victoires"]) == 1 and int(b["defaites"]) == 1
		and int(b["nulles"]) == 1,
		"%d/%d/%d" % [b["victoires"], b["defaites"], b["nulles"]])

	# En écran partagé il n'y a pas d'issue : les deux joueurs regardent le même
	# écran, et le bilan se dit du point de vue de J1.
	var partage := [
		_m("2026-09-09T20:10:00", 0),
		_m("2026-09-09T20:20:00", 0),
		_m("2026-09-09T20:30:00", 1),
	]
	var p: Dictionary = B.de_la_soiree(partage, -1, SEANCE)
	_check("en écran partagé, le vainqueur numéroté fait foi",
		int(p["victoires"]) == 2 and int(p["defaites"]) == 1,
		"%d/%d" % [p["victoires"], p["defaites"]])

	print("\n[La meilleure série]")
	var serie := [
		_m("2026-09-09T20:10:00", 0, "win"),
		_m("2026-09-09T20:20:00", 0, "win"),
		_m("2026-09-09T20:30:00", 1, "loss"),
		_m("2026-09-09T20:40:00", 0, "win"),
		_m("2026-09-09T20:50:00", 0, "win"),
		_m("2026-09-09T21:00:00", 0, "win"),
	]
	_check("c'est la plus longue, pas la dernière",
		int(B.de_la_soiree(serie, 0, SEANCE)["serie"]) == 3,
		str(B.de_la_soiree(serie, 0, SEANCE)["serie"]))
	# Une égalité rompt la série : une série est faite de VICTOIRES, et laisser
	# une nulle la prolonger reviendrait à dire qu'on n'a pas perdu.
	var nulle := [
		_m("2026-09-09T20:10:00", 0, "win"),
		_m("2026-09-09T20:20:00", -1, "draw"),
		_m("2026-09-09T20:30:00", 0, "win"),
	]
	_check("une égalité rompt la série",
		int(B.de_la_soiree(nulle, 0, SEANCE)["serie"]) == 1)


func _test_favoris() -> void:
	print("\n[Le favori, et son départage]")
	var histo := [
		_m("2026-09-09T20:10:00", 0, "win", "Pompe", "Fusil", "cloitre"),
		_m("2026-09-09T20:20:00", 0, "win", "Pompe", "Fusil", "cloitre"),
		_m("2026-09-09T20:30:00", 1, "loss", "Pistolet", "Fusil", "usine"),
	]
	var b: Dictionary = B.de_la_soiree(histo, 0, SEANCE)
	_check("l'arme du joueur, pas celle du match",
		String(b["arme"]) == "Pompe" and int(b["arme_n"]) == 2,
		"%s %d" % [b["arme"], b["arme_n"]])
	_check("vu de l'autre côté, c'est son arme à lui",
		String(B.de_la_soiree(histo, 1, SEANCE)["arme"]) == "Fusil")
	_check("en écran partagé, les deux armes comptent",
		int(B.de_la_soiree(histo, -1, SEANCE)["arme_n"]) == 3,
		str(B.de_la_soiree(histo, -1, SEANCE)["arme_n"]))
	_check("l'arène favorite est celle qu'on a revue",
		String(b["carte"]) == "cloitre" and int(b["carte_n"]) == 2)

	# ⚠️ Le cas qui rendrait la carte instable : deux favoris à égalité. Sans
	# départage explicite, la réponse suit l'ordre d'insertion du dictionnaire —
	# donc l'ordre des matchs, donc une carte qui change d'avis sur la même
	# soirée selon qu'on l'ouvre avant ou après avoir rejoué.
	_check("une égalité se tranche par le nom, pas par l'ordre",
		String(B.sommet({"Pompe": 2, "Arbalète": 2})["nom"]) == "Arbalète",
		String(B.sommet({"Pompe": 2, "Arbalète": 2})["nom"]))
	_check("et dans l'autre sens d'insertion, la même réponse",
		String(B.sommet({"Arbalète": 2, "Pompe": 2})["nom"]) == "Arbalète")
	_check("un décompte vide n'a pas de sommet",
		String(B.sommet({})["nom"]) == "")


func _test_phrase() -> void:
	print("\n[La phrase de la fiche V6.10]")
	var histo := [
		_m("2026-09-09T20:10:00", 0, "win", "Pompe"),
		_m("2026-09-09T20:20:00", 0, "win", "Pompe"),
		_m("2026-09-09T20:30:00", 1, "loss", "Pompe"),
	]
	var dite := B.phrase(B.de_la_soiree(histo, 0, SEANCE))
	_check("elle dit les matchs, le score et l'arme",
		dite == "Ce soir : 3 matchs, 2 - 1, arme favorite : pompe", dite)
	var partagee := B.phrase(B.de_la_soiree(histo, -1, SEANCE))
	_check("en écran partagé, elle nomme les joueurs",
		partagee.contains("J1 2 - 1 J2"), partagee)
	_check("une soirée vide ne dit rien", B.phrase(B.de_la_soiree([], 0, SEANCE)) == "")


func _test_durees() -> void:
	print("\n[Les durées, lisibles]")
	_check("moins d'une minute se dit en secondes", B.duree_longue(42.0) == "42 s",
		B.duree_longue(42.0))
	_check("une soirée se dit en minutes", B.duree_longue(2840.0) == "47 min",
		B.duree_longue(2840.0))
	# `mm:ss` est juste pour un match et illisible pour une soirée : « 47:12 »
	# se lit comme quarante-sept minutes ou quarante-sept heures selon qui lit.
	_check("au-delà de l'heure, elle sépare les deux",
		B.duree_longue(7920.0) == "2 h 12", B.duree_longue(7920.0))
	_check("une durée négative ne produit pas d'absurdité",
		B.duree_longue(-5.0) == "0 s", B.duree_longue(-5.0))
