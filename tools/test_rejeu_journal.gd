## Test headless du rejeu du journal local — Phase 4, dette de l'étape 2a.
##
## `game_state.gd` promettait depuis l'origine qu'« une étape ultérieure pourra
## rejouer ce qui manque ». Elle ne le pouvait pas : l'enregistrement ne portait
## ni identifiant de match, ni nature classée, ni issue — les trois champs que le
## serveur exige. Le journal était un souvenir lisible, pas une source de rejeu.
##
## Ce que ces assertions protègent est invisible à l'usage : un classement à trous
## ressemble en tout point à un classement juste. Personne ne peut voir le match
## qui manque.
##
## Lancer : godot --headless --path . --script res://tools/test_rejeu_journal.gd
extends SceneTree

const CHEMIN := "user://test_rejeu_journal.json"

var _failures: int = 0

func _init() -> void:
	print("=== Test du rejeu du journal local ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_nettoyer()

	_test_schema_rejouable()
	_test_selection_des_en_attente()
	_test_v2_irrejouable()
	_test_marquage()
	_test_ecriture_atomique()

	_nettoyer()
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

func _nettoyer() -> void:
	if FileAccess.file_exists(CHEMIN):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN))

func _classe(id: String, issue: String = "victoire") -> Dictionary:
	return MatchRecord.build(0, 92.5, "Pistolet", "Fusil", "default", "en_ligne_hote",
		MatchRecord.Format.BO1, false, id, true, issue)

# ---------------------------------------------------------------------------

func _test_schema_rejouable() -> void:
	print("\n[Le journal porte de quoi rejouer]")
	var r := _classe("abc123")
	for cle in ["match_id", "classe", "issue", "remonte"]:
		_check("l'enregistrement porte « %s »" % cle, r.has(cle))
	_check("et il n'est pas remonté d'avance", not bool(r["remonte"]))
	_check("le schéma est bien en v3", int(r["version"]) == 3, str(r.get("version")))

func _test_selection_des_en_attente() -> void:
	print("\n[Ce qui est repris, et ce qui ne l'est pas]")
	var journal: Array = [
		_classe("en_attente_1"),
		_classe("en_attente_2"),
	]
	# Un match déjà remonté : le reprendre le renverrait à chaque démarrage.
	var remonte := _classe("deja_remonte")
	remonte["remonte"] = true
	journal.append(remonte)
	# Un match amical n'entre pas au classement : le rejouer y ferait entrer un
	# résultat qui n'aurait jamais dû compter — le pire des deux sens d'erreur.
	journal.append(MatchRecord.build(0, 60.0, "", "", "default", "en_ligne_hote",
		MatchRecord.Format.BO1, false, "amical_x", false, "victoire"))
	# Un écran partagé n'oppose aucune identité : ni id, ni issue.
	journal.append(MatchRecord.build(0, 60.0, "", "", "default", "local"))

	var en_attente := MatchRecord.pending_reports(journal)
	var ids: Array[String] = []
	for e in en_attente:
		ids.append(String((e as Dictionary)["match_id"]))
	ids.sort()
	_check("seuls les classés jamais remontés sont repris",
		ids == ["en_attente_1", "en_attente_2"], str(ids))

	# Une entrée mal formée ne doit pas faire tomber tout le rejeu : le journal a
	# pu être écrit par une version antérieure, ou édité à la main.
	journal.append("ceci n'est pas un enregistrement")
	journal.append({"match_id": "sans_issue", "classe": true})
	_check("une entrée abîmée est écartée sans faire tomber le reste",
		MatchRecord.pending_reports(journal).size() == 2,
		str(MatchRecord.pending_reports(journal).size()))

## Les journaux écrits avant le schéma v3 n'ont pas d'identifiant de match. Le
## serveur apparie les deux rapports par cet identifiant : sans lui, un rapport
## rejoué n'aurait aucun pair et ne pourrait jamais être confronté. Mieux vaut
## renoncer à ces matchs-là que d'envoyer des récits orphelins.
func _test_v2_irrejouable() -> void:
	print("\n[Les enregistrements d'avant v3]")
	var vieux := {
		"version": 2, "forfait": false, "vainqueur": 0, "egalite": false,
		"duree": 88.0, "carte": "default", "mode": "en_ligne_hote", "format": "BO1",
	}
	_check("un enregistrement v2 n'est jamais rejoué",
		MatchRecord.pending_reports([vieux]).is_empty())
	# Et surtout : il ne fait pas tomber le rejeu des enregistrements v3 voisins.
	_check("il n'empêche pas ses voisins de l'être",
		MatchRecord.pending_reports([vieux, _classe("moderne")]).size() == 1)

func _test_marquage() -> void:
	print("\n[Clore un match dans le journal]")
	_nettoyer()
	MatchRecord.append_to_history(_classe("m1"), CHEMIN)
	MatchRecord.append_to_history(_classe("m2"), CHEMIN)

	_check("les deux sont en attente",
		MatchRecord.pending_reports(MatchRecord.load_history(CHEMIN)).size() == 2)

	_check("marquer rend vrai", MatchRecord.mark_reported("m1", CHEMIN))
	var restant := MatchRecord.pending_reports(MatchRecord.load_history(CHEMIN))
	_check("il n'en reste qu'un", restant.size() == 1, str(restant.size()))
	_check("et c'est le bon",
		restant.size() == 1 and String((restant[0] as Dictionary)["match_id"]) == "m2")

	# Le marquage doit survivre à la relecture du fichier, sinon le rejeu
	# renverrait le même match à chaque démarrage jusqu'à la fin des temps.
	var relu := MatchRecord.load_history(CHEMIN)
	var trouve := false
	for e in relu:
		if String((e as Dictionary).get("match_id", "")) == "m1":
			trouve = bool((e as Dictionary).get("remonte", false))
	_check("le marquage est bien sur le disque, pas seulement en mémoire", trouve)

	_check("marquer un identifiant absent ne prétend rien",
		not MatchRecord.mark_reported("jamais_vu", CHEMIN))
	_check("marquer un identifiant vide non plus",
		not MatchRecord.mark_reported("", CHEMIN))

## Le journal est la seule copie d'un match que le réseau a perdu : une écriture
## interrompue le perdrait pour de bon.
func _test_ecriture_atomique() -> void:
	print("\n[Écriture]")
	_nettoyer()
	MatchRecord.append_to_history(_classe("atomique"), CHEMIN)
	MatchRecord.mark_reported("atomique", CHEMIN)
	_check("aucun fichier temporaire ne subsiste",
		not FileAccess.file_exists(CHEMIN + ".tmp"))
	_check("et le journal reste lisible",
		MatchRecord.load_history(CHEMIN).size() == 1)
