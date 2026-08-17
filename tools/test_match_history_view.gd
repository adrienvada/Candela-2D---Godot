## Test headless de la lecture du journal de matchs (`MatchHistoryView`).
##
## L'essentiel de ce qui est vérifié ici n'est pas la mise en forme mais la
## RÉSISTANCE : le journal vit sur le disque d'un joueur, il peut être absent,
## tronqué, trafiqué, ou écrit par une autre version du jeu. Chacun de ces cas a
## son test, parce que chacun se produira.
##
## Lancer : godot --headless --path . --script res://tools/test_match_history_view.gd
extends SceneTree

## Piège du dépôt : un script `extends SceneTree` lancé en `--script` exécute son
## `_init()` avant l'enregistrement des `class_name`. Une classe neuve, jamais
## importée, n'est pas encore dans le cache : le script ne compilerait pas, Godot
## rendrait un objet nu, et la suite annoncerait « tous les tests passent » sans
## avoir rien exécuté. On passe donc par le chemin de la ressource, qui ne dépend
## d'aucun cache — et on vérifie séparément que la classe globale existe bel et
## bien (`_test_global_class`). `MatchRecord`, lui, est déjà au catalogue.
const MHV := preload("res://match_history_view.gd")

## Journal d'essai. JAMAIS le vrai `user://match_history.json` : les tests
## tournent sur la machine d'un joueur qui a une soirée dedans.
const TMP_HISTORY := "user://test_match_history_view.json"

## Base de temps des journaux fabriqués : 2026-08-16 20:00:00 UTC.
const BASE_EPOCH := 1786032000

var _failures: int = 0

func _init() -> void:
	print("=== Test lecture du journal de matchs ===")

	_test_global_class()
	_test_missing_journal()
	_test_unreadable_journal()
	_test_damaged_record()
	_test_unknown_version()
	_test_order_and_limit()
	_test_row_shape()
	_test_formatting()
	_test_session_summary()

	_wipe_history()

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

# ---------------------------------------------------------------------------
# LA CLASSE EXISTE VRAIMENT
# ---------------------------------------------------------------------------
#
# Sans ce contrôle, une classe absente du catalogue global se solderait par une
# suite qui « passe » sans avoir rien exercé.
func _test_global_class() -> void:
	print("\n[Classe globale]")
	var declared_path := ""
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == "MatchHistoryView":
			declared_path = String(entry.get("path", ""))
	_check("MatchHistoryView est au catalogue des classes globales",
		declared_path != "",
		"catalogue vide ou classe absente — lancer : Godot --headless --path . --import")
	_check("déclarée à la racine", declared_path == "res://match_history_view.gd",
		declared_path)
	_check("le script répond", MHV.format_span(0.0) == "0 s")
	_check("version lisible calée sur celle de MatchRecord",
		MHV.READABLE_VERSION == MatchRecord.SCHEMA_VERSION, str(MHV.READABLE_VERSION))

# ---------------------------------------------------------------------------
# JOURNAL ABSENT
# ---------------------------------------------------------------------------
#
# Premier lancement : il n'y a pas d'erreur à signaler, il n'y a pas encore de
# matchs. Les deux ne se disent pas de la même façon à l'écran.
func _test_missing_journal() -> void:
	print("\n[Journal absent]")
	_wipe_history()

	_check("aucune ligne", MHV.recent(MHV.NO_LIMIT, TMP_HISTORY).is_empty())

	var report: Dictionary = MHV.recent_report(MHV.DEFAULT_LIMIT, TMP_HISTORY)
	_check("rapport vide et sans rejet",
		report["lignes"].is_empty() and report["lus"] == 0
		and report["ignores"] == 0 and report["trop_recents"] == 0, str(report))

	var summary: Dictionary = MHV.session_summary(MHV.SESSION_GAP, TMP_HISTORY)
	_check("résumé de session neutre",
		summary["matchs"] == 0 and summary["duree_totale"] == 0.0
		and summary["arme_favorite"] == "" and summary["bilan_texte"] == "", str(summary))

# ---------------------------------------------------------------------------
# JOURNAL ILLISIBLE
# ---------------------------------------------------------------------------

func _test_unreadable_journal() -> void:
	print("\n[Journal illisible]")

	_write_raw("{ ceci n'est pas du JSON")
	_check("JSON invalide → liste vide", MHV.recent(MHV.NO_LIMIT, TMP_HISTORY).is_empty())

	# Coupé en pleine écriture : la fin manque, le décodeur échoue.
	_write_raw('[{"version": 2, "vainqueur": 0, "duree": 12')
	_check("journal tronqué → liste vide", MHV.recent(MHV.NO_LIMIT, TMP_HISTORY).is_empty())

	# JSON parfaitement valide, mais ce n'est pas une liste de matchs.
	_write_raw('{"matchs": 3}')
	_check("JSON valide mais pas une liste → liste vide",
		MHV.recent(MHV.NO_LIMIT, TMP_HISTORY).is_empty())

	_write_raw('"CANDELA"')
	_check("JSON réduit à une chaîne → liste vide",
		MHV.recent(MHV.NO_LIMIT, TMP_HISTORY).is_empty())

	_write_raw("[]")
	_check("liste vide → liste vide", MHV.recent(MHV.NO_LIMIT, TMP_HISTORY).is_empty())

	# Une liste dont les entrées ne sont pas des enregistrements : chacune est
	# sautée pour elle-même, le match valide au milieu survit.
	_write_history([3, "deux", null, [], _record(0, "en_ligne_hote")])
	var report: Dictionary = MHV.recent_report(MHV.NO_LIMIT, TMP_HISTORY)
	_check("le seul match valide d'une liste de déchets est rendu",
		report["lignes"].size() == 1, str(report["lignes"].size()))
	_check("les quatre déchets sont comptés",
		report["ignores"] == 4 and report["lus"] == 5, str(report))

	_wipe_history()

# ---------------------------------------------------------------------------
# ENREGISTREMENT ABÎMÉ
# ---------------------------------------------------------------------------
#
# Deux règles, et il faut les distinguer : sans vainqueur une ligne d'historique
# ne veut rien dire, donc elle est écartée ; le reste se dégrade en valeur neutre
# plutôt que de faire perdre le match tout entier.
func _test_damaged_record() -> void:
	print("\n[Enregistrement abîmé]")

	var amputated := _record(0, "en_ligne_hote")
	amputated.erase("vainqueur")
	_check("sans vainqueur → écarté", MHV.row_from(amputated, 0).is_empty())

	var no_weapon := _record(0, "en_ligne_hote")
	no_weapon.erase("arme_j2")
	var row: Dictionary = MHV.row_from(no_weapon, 0)
	_check("sans arme adverse → conservé", not row.is_empty())
	_check("l'arme manquante devient vide",
		row.get("arme_j2", "?") == "" and row.get("arme_adverse", "?") == "",
		str(row.get("arme_j2")))

	var no_mode := _record(0, "en_ligne_hote")
	no_mode.erase("mode")
	row = MHV.row_from(no_mode, 0)
	_check("sans mode → conservé, sans camp local",
		not row.is_empty() and row["moi"] == -1 and row["issue"] == MHV.Outcome.NO_SIDE,
		str(row.get("moi")))
	_check("mode vide → tiret", row["mode_texte"] == "—", String(row["mode_texte"]))

	var absurd := _record(0, "en_ligne_hote")
	absurd["vainqueur"] = 7
	_check("vainqueur hors bornes → écarté", MHV.row_from(absurd, 0).is_empty())

	var texts := _record(0, "en_ligne_hote")
	texts["vainqueur"] = "J1"
	_check("vainqueur en toutes lettres → écarté", MHV.row_from(texts, 0).is_empty())

	var bad_duration := _record(0, "en_ligne_hote")
	bad_duration["duree"] = "beaucoup"
	row = MHV.row_from(bad_duration, 0)
	_check("durée illisible → 00:00, ligne conservée",
		not row.is_empty() and row["duree"] == 0.0 and row["duree_texte"] == "00:00",
		str(row.get("duree_texte")))

	var negative := _record(0, "en_ligne_hote")
	negative["duree"] = -12.0
	_check("durée négative écrêtée", MHV.row_from(negative, 0)["duree"] == 0.0)

	var numeric_weapon := _record(0, "en_ligne_hote")
	numeric_weapon["arme_j1"] = 3
	_check("arme numérique → vide, jamais « 3 »",
		MHV.row_from(numeric_weapon, 0)["arme_j1"] == "")

	var bad_stamp := _record(0, "en_ligne_hote")
	bad_stamp["horodatage"] = "hier soir"
	row = MHV.row_from(bad_stamp, 0)
	_check("horodatage illisible → ligne sans date",
		not row.is_empty() and row["date_texte"] == "" and row["epoch"] == -1,
		str(row.get("date_texte")))

	_check("un non-dictionnaire est écarté sans broncher",
		MHV.row_from(42, 0).is_empty() and MHV.row_from(null, 0).is_empty())

# ---------------------------------------------------------------------------
# VERSIONS DE SCHÉMA
# ---------------------------------------------------------------------------
#
# La décision est commentée dans match_history_view.gd : plus récent qu'attendu
# = écarté et compté, plus ancien = lu au mieux. Ce test la fige.
func _test_unknown_version() -> void:
	print("\n[Versions de schéma]")

	var future := _record(0, "en_ligne_hote")
	future["version"] = MatchRecord.SCHEMA_VERSION + 1
	_check("version plus récente → écartée", MHV.row_from(future, 0).is_empty())

	var ancient := _record(1, "en_ligne_hote")
	ancient.erase("version")
	ancient.erase("forfait")
	var row: Dictionary = MHV.row_from(ancient, 0)
	_check("version absente → lue comme le premier schéma",
		not row.is_empty() and row["version"] == MHV.LEGACY_VERSION, str(row.get("version")))
	_check("un enregistrement d'avant le forfait n'en est pas un",
		row["forfait"] == false)

	var v1 := _record(0, "en_ligne_hote")
	v1["version"] = 1
	_check("version 1 → lue", not MHV.row_from(v1, 0).is_empty())

	var garbled := _record(0, "en_ligne_hote")
	garbled["version"] = "deux"
	_check("version en toutes lettres → écartée", MHV.row_from(garbled, 0).is_empty())
	_check("version illisible signalée par version_of", MHV.version_of(garbled) == -1)

	# Les deux rejets ne se comptent pas ensemble : un écran doit pouvoir dire
	# « 1 match écrit par une version plus récente » sans mentir sur le reste.
	_write_history([future, garbled, _record(0, "en_ligne_hote")])
	var report: Dictionary = MHV.recent_report(MHV.NO_LIMIT, TMP_HISTORY)
	_check("un seul match rendu", report["lignes"].size() == 1, str(report))
	_check("le trop récent est compté à part",
		report["trop_recents"] == 1 and report["ignores"] == 1, str(report))

	_wipe_history()

# ---------------------------------------------------------------------------
# ORDRE ET LIMITE
# ---------------------------------------------------------------------------

func _test_order_and_limit() -> void:
	print("\n[Ordre et limite]")

	var history: Array = []
	for i in 5:
		var rec := _record(0, "en_ligne_hote")
		rec["carte"] = "carte_%d" % i
		rec["horodatage"] = _stamp(BASE_EPOCH + i * 600)
		history.append(rec)
	_write_history(history)

	var lines: Array = MHV.recent(MHV.NO_LIMIT, TMP_HISTORY)
	_check("les cinq matchs sont rendus", lines.size() == 5, str(lines.size()))
	_check("le plus récent d'abord", lines[0]["carte"] == "carte_4",
		String(lines[0]["carte"]))
	_check("le plus ancien en dernier", lines[4]["carte"] == "carte_0",
		String(lines[4]["carte"]))

	var descending := true
	for i in range(1, lines.size()):
		if lines[i]["epoch"] > lines[i - 1]["epoch"]:
			descending = false
	_check("horodatages strictement antichronologiques", descending)

	var page: Array = MHV.recent(2, TMP_HISTORY)
	_check("la limite est respectée", page.size() == 2, str(page.size()))
	_check("la limite garde bien les plus récents",
		page[0]["carte"] == "carte_4" and page[1]["carte"] == "carte_3",
		"%s / %s" % [page[0]["carte"], page[1]["carte"]])

	var report: Dictionary = MHV.recent_report(2, TMP_HISTORY)
	_check("la lecture s'arrête à la limite (rien n'est lu pour rien)",
		report["lus"] == 2, str(report["lus"]))

	_check("une limite plus grande que le journal ne coupe rien",
		MHV.recent(500, TMP_HISTORY).size() == 5)
	_check("limite nulle = tout le journal",
		MHV.recent(MHV.NO_LIMIT, TMP_HISTORY).size() == 5)
	_check("limite négative = tout le journal",
		MHV.recent(-3, TMP_HISTORY).size() == 5)

	# La limite compte des lignes RENDUES, pas des entrées parcourues : deux
	# déchets intercalés ne doivent pas amputer la page.
	_write_history([_record(0, "en_ligne_hote"), "déchet", _record(1, "en_ligne_hote"),
		null, _record(-1, "en_ligne_hote")])
	_check("la limite compte les lignes rendues, pas les entrées lues",
		MHV.recent(3, TMP_HISTORY).size() == 3)

	_wipe_history()

# ---------------------------------------------------------------------------
# UNE LIGNE D'ÉCRAN
# ---------------------------------------------------------------------------

func _test_row_shape() -> void:
	print("\n[Ligne d'écran]")

	var rec := MatchRecord.build(0, 187.25, "Pompe", "Fusil", "default", "en_ligne_hote")
	var row: Dictionary = MHV.row_from(rec, 0)
	for key in ["issue", "issue_texte", "forfait", "vainqueur", "moi", "duree",
			"duree_texte", "arme_j1", "arme_j2", "arme_moi", "arme_adverse",
			"carte", "mode", "mode_texte", "format", "horodatage", "date_texte",
			"epoch", "version"]:
		_check("clé « %s » présente" % key, row.has(key))

	_check("durée mise en forme", row["duree_texte"] == "03:07", String(row["duree_texte"]))
	_check("carte reportée telle quelle", row["carte"] == "default")
	_check("format reporté", row["format"] == "BO1")
	_check("mode traduit", row["mode_texte"] == "En ligne — hôte", String(row["mode_texte"]))

	# L'hôte est J1 : le match gagné par J1 est une victoire, vu d'ici.
	_check("hôte vainqueur → VICTOIRE",
		row["issue"] == MHV.Outcome.WIN and row["issue_texte"] == "VICTOIRE")
	_check("armes rapportées au camp local",
		row["arme_moi"] == "Pompe" and row["arme_adverse"] == "Fusil")

	# Vu du client, le même score est une défaite : le camp change, pas le match.
	var seen_by_client: Dictionary = MHV.row_from(
		MatchRecord.build(0, 60.0, "Pompe", "Fusil", "default", "en_ligne_client"), 0)
	_check("vu du client, J1 vainqueur → DÉFAITE",
		seen_by_client["issue"] == MHV.Outcome.LOSS
		and seen_by_client["issue_texte"] == "DÉFAITE")
	_check("le camp du client est J2", seen_by_client["moi"] == 1)
	_check("ses armes sont inversées",
		seen_by_client["arme_moi"] == "Fusil" and seen_by_client["arme_adverse"] == "Pompe")

	var draw: Dictionary = MHV.row_from(
		MatchRecord.build(-1, 300.0, "Pistolet", "Pistolet", "default", "en_ligne_hote"), 0)
	_check("temps écoulé → ÉGALITÉ",
		draw["issue"] == MHV.Outcome.DRAW and draw["issue_texte"] == "ÉGALITÉ")

	# Écran partagé : les deux joueurs sont sur ce poste, aucun n'est « moi ».
	var split: Dictionary = MHV.row_from(
		MatchRecord.build(1, 90.0, "Pompe", "Arbalète", "default", "local"), 0)
	_check("écran partagé → aucun camp local",
		split["issue"] == MHV.Outcome.NO_SIDE and split["moi"] == -1)
	_check("la ligne nomme le vainqueur", split["issue_texte"] == "VICTOIRE J2",
		String(split["issue_texte"]))
	_check("aucune arme n'est « la mienne »",
		split["arme_moi"] == "" and split["arme_adverse"] == "")

	var forfeit: Dictionary = MHV.row_from(MatchRecord.build(0, 42.0, "Pompe", "Fusil",
		"default", "en_ligne_hote", MatchRecord.Format.BO1, true), 0)
	_check("le forfait est porté par la ligne", forfeit["forfait"] == true)
	_check("un forfait reste une victoire", forfeit["issue"] == MHV.Outcome.WIN)

	# LE piège du journal : après un aller-retour par le disque, tout nombre JSON
	# revient en flottant. Un contrôle de type strict écarterait ici des matchs
	# parfaitement valides — et seul un test qui passe VRAIMENT par JSON le voit.
	var relu: Variant = JSON.parse_string(JSON.stringify(rec))
	var from_disk: Dictionary = MHV.row_from(relu, 0)
	_check("un enregistrement relu du disque reste lisible", not from_disk.is_empty())
	_check("vainqueur relu en flottant → même issue",
		from_disk["issue"] == MHV.Outcome.WIN, str(from_disk.get("issue")))
	_check("version relue en flottant → toujours lisible",
		from_disk["version"] == MatchRecord.SCHEMA_VERSION, str(from_disk.get("version")))

# ---------------------------------------------------------------------------
# MISE EN FORME
# ---------------------------------------------------------------------------

func _test_formatting() -> void:
	print("\n[Mise en forme]")

	_check("secondes seules", MHV.format_span(45.0) == "45 s", MHV.format_span(45.0))
	_check("minutes", MHV.format_span(125.0) == "2 min", MHV.format_span(125.0))
	_check("heures", MHV.format_span(5000.0) == "1 h 23", MHV.format_span(5000.0))
	_check("durée nulle", MHV.format_span(0.0) == "0 s")
	_check("durée négative écrêtée", MHV.format_span(-10.0) == "0 s")

	# Le journal horodate en UTC : un joueur d'été à Paris a joué à 23 h, pas 21 h.
	_check("date rendue en UTC sous décalage nul",
		MHV.format_date("2026-08-16 21:34:07", 0) == "16/08 21:34",
		MHV.format_date("2026-08-16 21:34:07", 0))
	_check("date ramenée à l'heure locale (UTC+2)",
		MHV.format_date("2026-08-16 21:34:07", 120) == "16/08 23:34",
		MHV.format_date("2026-08-16 21:34:07", 120))
	_check("décalage négatif",
		MHV.format_date("2026-08-16 21:34:07", -120) == "16/08 19:34",
		MHV.format_date("2026-08-16 21:34:07", -120))
	_check("la variante « T » de l'ISO 8601 est acceptée",
		MHV.epoch_of("2026-08-16T21:34:07") == MHV.epoch_of("2026-08-16 21:34:07"))

	for broken in ["", "hier", "2026-08-16", "2026/08/16 21:34:07", "20260816213407",
			"2026-13-16 21:34:07", "2026-08-32 21:34:07", "2026-08-16 25:34:07",
			"AAAA-BB-CC DD:EE:FF"]:
		_check("horodatage refusé : « %s »" % broken, MHV.epoch_of(broken) == -1,
			str(MHV.epoch_of(broken)))
	_check("un horodatage illisible ne rend pas de date",
		MHV.format_date("hier", 0) == "")

# ---------------------------------------------------------------------------
# RÉSUMÉ DE SESSION
# ---------------------------------------------------------------------------
#
# Jeu de matchs connu, choisi pour que chaque compteur ait une valeur qu'on peut
# vérifier de tête : 5 en ligne (3 victoires, 1 défaite, 1 égalité, dont un
# forfait) + 2 en écran partagé (1 pour chacun), plus un match vieux de deux
# jours qui ne doit PAS entrer dans la soirée.
func _test_session_summary() -> void:
	print("\n[Résumé de session]")

	var history: Array = []
	# Le vieux match, en tête de journal comme le veut l'ordre d'écriture.
	var old := _record(0, "en_ligne_hote", 100.0, "Arbalète", "Fusil")
	old["horodatage"] = _stamp(BASE_EPOCH - 2 * 86400)
	history.append(old)

	var soiree := [
		_record(0, "en_ligne_hote", 120.0, "Pompe", "Fusil"),
		_record(0, "en_ligne_hote", 90.0, "Pompe", "Fusil"),
		_record(1, "en_ligne_hote", 240.0, "Pompe", "Fusil"),
		_record(-1, "en_ligne_hote", 300.0, "Pompe", "Pistolet"),
		_record(0, "en_ligne_hote", 30.0, "Pompe", "Fusil", true),
		_record(0, "local", 150.0, "Fusil", "Arbalète"),
		_record(1, "local", 210.0, "Fusil", "Arbalète"),
	]
	for i in soiree.size():
		soiree[i]["horodatage"] = _stamp(BASE_EPOCH + i * 600)
		history.append(soiree[i])
	_write_history(history)

	var lines: Array = MHV.recent(MHV.NO_LIMIT, TMP_HISTORY)
	_check("le journal entier compte huit matchs", lines.size() == 8, str(lines.size()))

	var session: Array = MHV.session_lines(lines)
	_check("la soirée s'arrête avant le match de l'avant-veille",
		session.size() == 7, str(session.size()))

	var summary: Dictionary = MHV.summarize(session)
	_check("nombre de matchs", summary["matchs"] == 7, str(summary["matchs"]))
	_check("victoires", summary["victoires"] == 3, str(summary["victoires"]))
	_check("défaites", summary["defaites"] == 1, str(summary["defaites"]))
	_check("égalités", summary["egalites"] == 1, str(summary["egalites"]))
	_check("forfaits", summary["forfaits"] == 1, str(summary["forfaits"]))
	_check("bilan en ligne", summary["bilan_texte"] == "3V 1D 1N",
		String(summary["bilan_texte"]))
	_check("score de l'écran partagé compté à part",
		summary["victoires_j1"] == 1 and summary["victoires_j2"] == 1,
		str(summary))
	_check("bilan de l'écran partagé", summary["bilan_partage_texte"] == "J1 1 - 1 J2",
		String(summary["bilan_partage_texte"]))
	_check("tout match tombe dans exactement un compteur",
		summary["victoires"] + summary["defaites"] + summary["egalites"]
		+ summary["victoires_j1"] + summary["victoires_j2"] == summary["matchs"],
		str(summary))

	# Arme la plus jouée SUR CE POSTE : la Pompe dans les 5 matchs en ligne, le
	# Fusil et l'Arbalète une fois chacun par match en écran partagé (les deux
	# joueurs sont ici, les deux armes comptent).
	_check("arme la plus jouée", summary["arme_favorite"] == "Pompe",
		String(summary["arme_favorite"]))
	_check("son nombre de matchs", summary["arme_favorite_matchs"] == 5,
		str(summary["arme_favorite_matchs"]))

	var expected := 120.0 + 90.0 + 240.0 + 300.0 + 30.0 + 150.0 + 210.0
	_check("durée totale", is_equal_approx(summary["duree_totale"], expected),
		str(summary["duree_totale"]))
	_check("durée totale mise en forme", summary["duree_totale_texte"] == "19 min",
		String(summary["duree_totale_texte"]))

	# Le raccourci de bout en bout doit tomber sur le même résumé que la
	# composition à la main.
	var direct: Dictionary = MHV.session_summary(MHV.SESSION_GAP, TMP_HISTORY)
	_check("session_summary() lit le disque et donne le même résumé",
		direct["matchs"] == 7 and direct["bilan_texte"] == "3V 1D 1N", str(direct))

	# Le vieux match n'est exclu que par l'écart de temps : un seuil assez large
	# le réintègre. C'est ce qui prouve que la coupure vient bien de là.
	_check("un écart de session très large ramène tout",
		MHV.session_lines(lines, 10.0 * 86400.0).size() == 8)

	# Résumé du journal complet : les compteurs suivent le match supplémentaire.
	var whole: Dictionary = MHV.summarize(lines)
	_check("le journal entier compte une victoire de plus",
		whole["matchs"] == 8 and whole["victoires"] == 4, str(whole))

	# Départage à égalité : deux armes à un match chacune, la plus récente gagne.
	_write_history([
		_record(0, "en_ligne_hote", 60.0, "Pistolet", "Fusil"),
		_record(0, "en_ligne_hote", 60.0, "Arbalète", "Fusil"),
	])
	var tie: Dictionary = MHV.summarize(MHV.recent(MHV.NO_LIMIT, TMP_HISTORY))
	_check("à égalité, l'arme la plus récemment jouée l'emporte",
		tie["arme_favorite"] == "Arbalète", String(tie["arme_favorite"]))

	_check("résumé d'une liste vide", MHV.summarize([])["matchs"] == 0)
	_check("une liste de déchets ne résume rien",
		MHV.summarize([1, "deux", null])["matchs"] == 0)

	_wipe_history()

# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

## Un enregistrement réaliste : produit par `MatchRecord`, jamais écrit à la main,
## pour que la suite casse le jour où le format changera.
func _record(winner: int, mode: String, duration: float = 60.0,
		weapon_1: String = "Pompe", weapon_2: String = "Fusil",
		forfeit: bool = false) -> Dictionary:
	return MatchRecord.build(winner, duration, weapon_1, weapon_2, "default", mode,
		MatchRecord.Format.BO1, forfeit)

func _stamp(epoch: int) -> String:
	return Time.get_datetime_string_from_unix_time(epoch, true)

func _write_history(history: Array) -> void:
	_write_raw(JSON.stringify(history, "\t"))

func _write_raw(contents: String) -> void:
	var file := FileAccess.open(TMP_HISTORY, FileAccess.WRITE)
	if file == null:
		_check("écriture du journal d'essai", false, TMP_HISTORY)
		return
	file.store_string(contents)
	file.close()

func _wipe_history() -> void:
	for path in [TMP_HISTORY, TMP_HISTORY + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
