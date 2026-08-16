## Test headless du format de match (BO1), de l'archivage des résultats et du
## plafond de la réserve de particules.
##
## Lancer : godot --headless --path . --script res://tools/test_match_format.gd
extends SceneTree

var _failures: int = 0

const TMP_HISTORY := "user://test_match_history.json"

func _init() -> void:
	print("=== Test format de match & pool de particules ===")

	_test_format_constants()
	_test_record_structure()
	_test_forfeit_record()
	_test_history_roundtrip()
	_test_history_cap()
	_test_pool_capacity()
	_test_pool_lifetime()

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
# FORMAT
# ---------------------------------------------------------------------------

func _test_format_constants() -> void:
	print("\n[Format]")
	_check("BO1 demande une manche gagnante",
		MatchRecord.wins_needed(MatchRecord.Format.BO1) == 1)
	_check("un match dure 5 minutes", MatchRecord.ROUND_DURATION == 300.0,
		str(MatchRecord.ROUND_DURATION))
	_check("horloge de départ à 05:00", MatchRecord.format_clock(300.0) == "05:00",
		MatchRecord.format_clock(300.0))
	_check("horloge à mi-parcours", MatchRecord.format_clock(125.9) == "02:05",
		MatchRecord.format_clock(125.9))
	_check("horloge écrêtée à zéro", MatchRecord.format_clock(-3.0) == "00:00")

	_check("BO1 : une manche gagnée termine le match",
		MatchRecord.is_match_over(MatchRecord.Format.BO1, 1, 0))
	_check("BO1 : aucune manche gagnée ne termine rien",
		not MatchRecord.is_match_over(MatchRecord.Format.BO1, 0, 0))
	# Les formats longs ne sont pas implémentés côté jeu, mais la règle doit
	# déjà tenir : c'est ce qui permettra de les brancher sans refonte.
	_check("BO3 : une seule manche ne suffit pas",
		not MatchRecord.is_match_over(MatchRecord.Format.BO3, 1, 1))
	_check("BO3 : deux manches terminent le match",
		MatchRecord.is_match_over(MatchRecord.Format.BO3, 1, 2))

# ---------------------------------------------------------------------------
# RÉSULTAT STRUCTURÉ
# ---------------------------------------------------------------------------

func _test_record_structure() -> void:
	print("\n[Résultat de match]")
	var rec := MatchRecord.build(0, 187.25, "Pompe", "Fusil", "default", "en_ligne_hote")

	for key in ["version", "forfait", "vainqueur", "egalite", "duree", "arme_j1",
			"arme_j2", "carte", "horodatage", "mode", "format"]:
		_check("clé « %s » présente" % key, rec.has(key))

	_check("version du schéma", rec["version"] == MatchRecord.SCHEMA_VERSION,
		str(rec.get("version")))
	_check("vainqueur J1", rec["vainqueur"] == 0)
	_check("pas une égalité", rec["egalite"] == false)
	_check("durée conservée", is_equal_approx(rec["duree"], 187.25), str(rec["duree"]))
	_check("armes des deux joueurs",
		rec["arme_j1"] == "Pompe" and rec["arme_j2"] == "Fusil")
	_check("carte identifiée", rec["carte"] == "default")
	_check("format BO1", rec["format"] == "BO1")
	_check("horodatage non vide", String(rec["horodatage"]) != "")

	var draw := MatchRecord.build(-1, 300.0, "Pistolet", "Pistolet", "default", "local")
	_check("temps écoulé → égalité", draw["egalite"] == true and draw["vainqueur"] == -1)

	# Une durée négative viendrait d'un chrono recalé par l'hôte après la fin.
	var odd := MatchRecord.build(1, -5.0, "", "", "default", "local")
	_check("durée jamais négative", float(odd["duree"]) >= 0.0, str(odd["duree"]))

	# Sérialisable tel quel : c'est ce que l'envoi ELA/ELO consommera plus tard.
	_check("sérialisable en JSON", JSON.stringify(rec) != "")

# ---------------------------------------------------------------------------
# FORFAIT
# ---------------------------------------------------------------------------
#
# Décision actée : quitter un match en ligne en cours vaut forfait. Le drapeau
# est ce qui permettra au classement de distinguer une victoire gagnée d'une
# victoire encaissée — et de la pondérer autrement un jour, sans rejouer
# l'histoire.
func _test_forfeit_record() -> void:
	print("\n[Forfait]")

	var normal := MatchRecord.build(0, 120.0, "Pompe", "Fusil", "default", "en_ligne_hote")
	_check("un match joué n'est pas un forfait", normal["forfait"] == false)

	# L'hôte reste, le client part : J1 gagne par forfait.
	var host_wins := MatchRecord.build(0, 42.0, "Pompe", "Fusil", "default",
		"en_ligne_hote", MatchRecord.Format.BO1, true)
	_check("forfait marqué", host_wins["forfait"] == true)
	_check("le joueur resté est vainqueur", host_wins["vainqueur"] == 0)
	_check("un forfait n'est pas une égalité", host_wins["egalite"] == false)

	# Le client reste, l'hôte part : J2 gagne par forfait. Vu du client, c'est le
	# même enregistrement avec l'autre vainqueur — les deux machines écrivent
	# chacune le leur, sans échange réseau.
	var client_wins := MatchRecord.build(1, 42.0, "Pompe", "Fusil", "default",
		"en_ligne_client", MatchRecord.Format.BO1, true)
	_check("vu du client, J2 est vainqueur", client_wins["vainqueur"] == 1)
	_check("mode conservé", client_wins["mode"] == "en_ligne_client")

	# Un abandon très précoce reste un abandon : la durée peut être nulle sans
	# que l'enregistrement cesse d'être valide.
	var early := MatchRecord.build(0, 0.0, "", "", "default", "en_ligne_hote",
		MatchRecord.Format.BO1, true)
	_check("durée nulle acceptée", float(early["duree"]) == 0.0)
	_check("forfait précoce marqué", early["forfait"] == true)

	# Le champ doit survivre à l'aller-retour JSON : c'est sous cette forme que
	# le classement le relira.
	var relu: Variant = JSON.parse_string(JSON.stringify(host_wins))
	_check("forfait survit au JSON",
		relu is Dictionary and (relu as Dictionary)["forfait"] == true)

	# Le schéma a changé en ajoutant ce champ : la version doit l'avoir suivi,
	# sinon un lecteur croira relire un enregistrement d'avant.
	_check("version du schéma incrémentée", MatchRecord.SCHEMA_VERSION >= 2,
		str(MatchRecord.SCHEMA_VERSION))

# ---------------------------------------------------------------------------
# JOURNAL LOCAL
# ---------------------------------------------------------------------------

func _test_history_roundtrip() -> void:
	print("\n[Journal local]")
	_wipe_history()

	_check("journal absent → vide", MatchRecord.load_history(TMP_HISTORY).is_empty())

	var rec := MatchRecord.build(1, 42.0, "Arbalète", "Pompe", "default", "local")
	MatchRecord.append_to_history(rec, TMP_HISTORY)
	MatchRecord.append_to_history(rec, TMP_HISTORY)

	var loaded := MatchRecord.load_history(TMP_HISTORY)
	_check("deux matchs archivés", loaded.size() == 2, str(loaded.size()))
	_check("contenu relu intact",
		loaded.size() == 2 and loaded[0]["arme_j1"] == "Arbalète",
		str(loaded))
	# L'écriture passe par un temporaire renommé : rien ne doit traîner après.
	_check("pas de fichier temporaire résiduel",
		not FileAccess.file_exists(TMP_HISTORY + ".tmp"))

	# Un fichier illisible ne doit pas faire échouer une fin de match.
	var f := FileAccess.open(TMP_HISTORY, FileAccess.WRITE)
	f.store_string("{ ceci n'est pas du JSON")
	f.close()
	_check("journal corrompu → repart de vide",
		MatchRecord.load_history(TMP_HISTORY).is_empty())

	_wipe_history()

func _test_history_cap() -> void:
	print("\n[Plafond du journal]")
	var history: Array = []
	for i in 250:
		history.append({"n": i})
	var capped := MatchRecord.cap(history, MatchRecord.HISTORY_MAX)
	_check("plafonné à HISTORY_MAX", capped.size() == MatchRecord.HISTORY_MAX,
		str(capped.size()))
	_check("les plus anciens sont oubliés",
		capped[0]["n"] == 250 - MatchRecord.HISTORY_MAX, str(capped[0]))
	_check("le plus récent est conservé", capped[-1]["n"] == 249)
	_check("en dessous du plafond, rien n'est coupé",
		MatchRecord.cap([{"n": 1}], MatchRecord.HISTORY_MAX).size() == 1)

func _wipe_history() -> void:
	for path in [TMP_HISTORY, TMP_HISTORY + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# ---------------------------------------------------------------------------
# RÉSERVE DE PARTICULES
# ---------------------------------------------------------------------------

func _make_pool() -> ParticlePool:
	var pool := ParticlePool.new()
	pool.initialize()
	return pool

func _test_pool_capacity() -> void:
	print("\n[Plafond du pool de particules]")
	var pool := _make_pool()

	_check("réserve pré-allouée", pool.free_count() == ParticlePool.CAPACITY,
		str(pool.free_count()))
	_check("rien d'actif au départ", pool.active_count() == 0)

	# Les ombres portées des lumières de particules étaient le poste de rendu le
	# plus lourd du jeu : aucune ne doit en avoir.
	var with_shadows := 0
	for child in pool.get_children():
		var light := child.get_node("Light") as PointLight2D
		if light.shadow_enabled:
			with_shadows += 1
	_check("aucune lumière de particule ne projette d'ombre",
		with_shadows == 0, "%d lumières à ombres" % with_shadows)

	pool.emit(ParticlePool.Kind.SPARK, Vector2.ZERO, Color.WHITE, 12,
		100.0, 450.0, Vector2.RIGHT, 120.0)
	_check("une salve d'étincelles est active", pool.active_count() == 12,
		str(pool.active_count()))

	# Rafale de pompe dans un mur : 5 balles × 12 étincelles, puis un kill.
	for i in 20:
		pool.emit(ParticlePool.Kind.SPARK, Vector2.ZERO, Color.WHITE, 12,
			100.0, 450.0, Vector2.RIGHT, 120.0)
	_check("le plafond global n'est jamais dépassé",
		pool.active_count() <= ParticlePool.MAX_ACTIVE, str(pool.active_count()))
	_check("le plafond est bien atteint (recyclage, pas refus)",
		pool.active_count() == ParticlePool.MAX_ACTIVE, str(pool.active_count()))
	_check("actives + libres = capacité totale",
		pool.active_count() + pool.free_count() == ParticlePool.CAPACITY,
		"%d + %d" % [pool.active_count(), pool.free_count()])

	pool.clear_all()
	_check("purge : tout revient en réserve",
		pool.active_count() == 0 and pool.free_count() == ParticlePool.CAPACITY)

	pool.free()

func _test_pool_lifetime() -> void:
	print("\n[Cycle de vie des particules]")
	var pool := _make_pool()

	pool.emit(ParticlePool.Kind.BLOOD, Vector2(10, 10), Color.RED, 25,
		200.0, 800.0, Vector2.RIGHT, 60.0)
	_check("gerbe de sang émise", pool.active_count() == 25, str(pool.active_count()))

	# Durée de vie maximale du sang : 3 s. Au-delà, plus rien ne doit rester.
	pool.advance(3.5)
	_check("tout est recyclé après la durée de vie max",
		pool.active_count() == 0, str(pool.active_count()))
	_check("aucune particule perdue en route",
		pool.free_count() == ParticlePool.CAPACITY, str(pool.free_count()))

	# Réémission après recyclage : le même nœud doit resservir, pas un neuf.
	var before := pool.get_child_count()
	pool.emit(ParticlePool.Kind.SPARK, Vector2.ZERO, Color.WHITE, 25,
		100.0, 450.0, Vector2.RIGHT, 120.0)
	_check("aucune allocation de nœud à la réémission",
		pool.get_child_count() == before, "%d → %d" % [before, pool.get_child_count()])

	pool.free()
