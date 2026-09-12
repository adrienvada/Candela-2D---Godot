## Test headless des CONDITIONS de match (chantier « prêt à l'essai », PE2.1),
## du texte de diagnostic (PE2.2) et du plafond d'images par seconde selon le
## régime (PE3.1).
##
## Lancer : godot --headless --path . --script res://tools/test_conditions_de_match.gd
extends SceneTree

const Settings := preload("res://settings_manager.gd")
const TMP_SETTINGS := "user://test_conditions_settings.cfg"

var _failures := 0

func _init() -> void:
	print("=== Test conditions de match, diagnostic & plafond par régime ===")

	_test_statistiques()
	_test_trous_et_rtt()
	_test_machine()
	_test_diagnostic()
	_test_archive()
	_test_rapport_emporte_les_conditions()
	_test_plafond()

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

func _proche(a: float, b: float, tol: float = 0.15) -> bool:
	return absf(a - b) <= tol

# ---------------------------------------------------------------------------
# STATISTIQUES — les définitions du banc, sur des durées connues d'avance
# ---------------------------------------------------------------------------

func _test_statistiques() -> void:
	print("\n[Statistiques]")
	# Cent images de 10 ms et une de 50 ms. Le centième le plus lent, c'est
	# UNE image (round(1,01) = 1) : le 1 % bas vaut donc la pire, 20 fps.
	var durees := PackedFloat32Array()
	for i in range(100):
		durees.append(0.010)
	durees.append(0.050)
	var s := ConditionsDeMatch.statistiques(durees)
	_check("101 images comptées", int(s["images"]) == 101, str(s["images"]))
	_check("médiane à 100 fps", _proche(float(s["fps_median"]), 100.0), str(s["fps_median"]))
	_check("1 % bas à 20 fps — la pire image, et elle seule",
		_proche(float(s["fps_1pc_bas"]), 20.0), str(s["fps_1pc_bas"]))
	_check("pire image à 50 ms", _proche(float(s["pire_image_ms"]), 50.0), str(s["pire_image_ms"]))
	# Moyenne = images / temps, PAS moyenne des 1/dt (qui flatterait le résultat).
	_check("moyenne = 101 images / 1,05 s ≈ 96,2 fps",
		_proche(float(s["fps_moyen"]), 96.2), str(s["fps_moyen"]))
	_check("durée totale 1,05 s", _proche(float(s["duree_s"]), 1.05, 0.02), str(s["duree_s"]))

	# Deux cents images : le centième vaut DEUX images, et c'est leur moyenne.
	var deux := PackedFloat32Array()
	for i in range(198):
		deux.append(0.010)
	deux.append(0.030)
	deux.append(0.050)
	var s2 := ConditionsDeMatch.statistiques(deux)
	_check("sur 200 images, le 1 % bas moyenne les deux plus lentes (25 fps)",
		_proche(float(s2["fps_1pc_bas"]), 25.0), str(s2["fps_1pc_bas"]))

	var vide := ConditionsDeMatch.statistiques(PackedFloat32Array())
	_check("aucune image : zéro partout, sans division par zéro",
		int(vide["images"]) == 0 and float(vide["fps_median"]) == 0.0)

# ---------------------------------------------------------------------------
# ÉCHANTILLONNAGE — trous, lien, et l'état commencé / arrêté
# ---------------------------------------------------------------------------

func _test_trous_et_rtt() -> void:
	print("\n[Échantillonnage]")
	var c := ConditionsDeMatch.new()
	c.echantillonner(-1.0, 500_000)
	_check("rien n'est relevé avant commencer()", int(c.resume()["images"]) == 0)

	c.commencer()
	_check("en cours après commencer()", c.en_cours())
	c.echantillonner(40.0, 1_000_000)   # premier tic : pas d'image encore
	c.echantillonner(60.0, 1_010_000)   # 10 ms
	c.echantillonner(-1.0, 1_020_000)   # 10 ms, pas de lien
	c.echantillonner(-1.0, 1_700_000)   # 680 ms : un TROU, pas une saccade
	c.echantillonner(-1.0, 1_710_000)   # 10 ms
	var r := c.resume()
	_check("trois images de 10 ms", int(r["images"]) == 3, str(r["images"]))
	_check("le trou de 680 ms est compté à part", int(r["trous"]) == 1, str(r["trous"]))
	_check("… et n'entre pas dans la pire image",
		_proche(float(r["pire_image_ms"]), 10.0), str(r["pire_image_ms"]))
	_check("RTT moyen 50 ms sur les deux relevés liés",
		_proche(float(r["rtt_moyen_ms"]), 50.0), str(r["rtt_moyen_ms"]))
	_check("RTT max 60 ms", _proche(float(r["rtt_max_ms"]), 60.0), str(r["rtt_max_ms"]))
	_check("le résumé porte sa version", int(r["version"]) == ConditionsDeMatch.VERSION)
	_check("le résumé porte la machine", r["machine"] is Dictionary and r["machine"].has("os"))

	c.arreter()
	c.echantillonner(-1.0, 1_720_000)
	_check("plus rien n'est relevé après arreter()", int(c.resume()["images"]) == 3)

	var sans_lien := ConditionsDeMatch.new()
	sans_lien.commencer()
	sans_lien.echantillonner(-1.0, 10)
	sans_lien.echantillonner(-1.0, 10_010)
	_check("sans lien, le RTT vaut -1 et non 0",
		float(sans_lien.resume()["rtt_moyen_ms"]) < 0.0)

	c.commencer()
	_check("commencer() repart de zéro", int(c.resume()["images"]) == 0 and int(c.resume()["trous"]) == 0)

# ---------------------------------------------------------------------------
# MACHINE
# ---------------------------------------------------------------------------

func _test_machine() -> void:
	print("\n[Machine]")
	var m := ConditionsDeMatch.machine()
	for cle in ["version", "build", "os", "os_version", "cpu", "coeurs", "memoire_mo",
			"gpu", "gpu_fournisseur", "gpu_api", "gpu_pilote", "rendu", "pilote", "fenetre",
			"plein_ecran", "ecran_hz",
			"vram_mo", "textures_mo"]:
		_check("clé « %s » présente" % cle, m.has(cle))
	_check("le système est nommé", String(m.get("os", "")) != "")
	_check("la version est celle du projet",
		String(m.get("version", "")) == String(ProjectSettings.get_setting("application/config/version", "")),
		String(m.get("version", "")))
	_check("la version n'est pas vide", String(m.get("version", "")) != "")

# ---------------------------------------------------------------------------
# DIAGNOSTIC — pure mise en forme
# ---------------------------------------------------------------------------

func _test_diagnostic() -> void:
	print("\n[Diagnostic]")
	var texte := ConditionsDeMatch.texte_diagnostic([
		["Machine", {"gpu": "Carte Témoin"}],
		["Bloc", {"a": {"b": 1}, "c": "x"}],
		"pas une paire",
		["Vide", {}],
	])
	_check("l'en-tête nomme le jeu", texte.begins_with("CANDELA 2D — DIAGNOSTIC"))
	_check("un bloc par titre", texte.contains("== Machine ==") and texte.contains("== Bloc =="))
	_check("les valeurs y sont", texte.contains("Carte Témoin"))
	_check("un dictionnaire imbriqué s'aplatit en parent.cle", texte.contains("a.b"))
	_check("un bloc mal formé est ignoré sans casser le reste",
		not texte.contains("pas une paire") and texte.contains("== Vide =="))

# ---------------------------------------------------------------------------
# ARCHIVE — schéma 5, puis 6 (étape 28, lot E : la télémétrie des gadgets, voir
# `test_telemetrie_gadgets.gd`) ; les conditions n'ont pas bougé.
# ---------------------------------------------------------------------------

func _test_archive() -> void:
	print("\n[Archive]")
	_check("schéma 6", MatchRecord.SCHEMA_VERSION == 6, str(MatchRecord.SCHEMA_VERSION))
	var avec := MatchRecord.build(0, 12.5, "A", "B", "carte", "local",
		MatchRecord.Format.BO1, false, "abc123", true, "win", "c1", "c2",
		{"fps_median": 120.0, "machine": {"os": "Test"}})
	_check("l'enregistrement porte ses conditions", avec.has("conditions"))
	_check("… et leur contenu", float(avec["conditions"].get("fps_median", 0.0)) == 120.0)
	_check("un match classé avec conditions reste à remonter",
		MatchRecord.pending_reports([avec]).size() == 1)
	var sans := MatchRecord.build(1, 3.0, "A", "B", "carte", "local")
	_check("sans conditions : un dictionnaire vide, jamais une absence de clé",
		sans.has("conditions") and (sans["conditions"] as Dictionary).is_empty())

# ---------------------------------------------------------------------------
# PE2.3 — le rapport au serveur emporte les conditions, le rejeu aussi
# ---------------------------------------------------------------------------
#
# Lu dans le TEXTE des deux fichiers, comme `test_torches` lit `game_state.gd` :
# ni l'un ni l'autre ne se charge en `--script` (autoloads au niveau de la
# classe), et c'est par le texte que le défaut reviendrait — une fusion qui
# reprend `_report_to_ranking` d'un côté sans l'autre. Un contrôle qui épingle
# l'APPEL et non sa ponctuation (voir « le schéma est passé à 4 »).

func _test_rapport_emporte_les_conditions() -> void:
	print("\n[Le rapport emporte les conditions — PE2.3]")
	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	_check("game_state calcule les conditions UNE fois pour l'archive et le rapport",
		gs.contains("var conditions := _conditions.resume()"))
	# Étape 28, lot E : la télémétrie des gadgets voyage avec, par la seule fusion.
	_check("… et les passe au rapport",
		gs.contains("_report_to_ranking(winner_id, forfeit, conditions, gadgets)"))
	_check("… qui les met dans le corps envoyé",
		gs.contains('"conditions": MatchRecord.conditions_a_envoyer(conditions, gadgets),'))
	var ri := FileAccess.get_file_as_string("res://ranked_identity.gd")
	_check("le rejeu du journal les reprend de l'archive",
		ri.contains('"conditions": MatchRecord.conditions_a_envoyer(e.get("conditions", {}),'))
	var fn := FileAccess.get_file_as_string("res://supabase/functions/report/index.ts")
	_check("la fonction Edge les transmet à la base", fn.contains("p_conditions: report.conditions"))
	var mig := FileAccess.get_file_as_string("res://supabase/migrations/20260910120000_match_conditions.sql")
	_check("la migration ajoute la colonne", mig.contains("add column conditions jsonb"))
	_check("… et la fonction SQL la reçoit en dernier, avec un défaut",
		mig.contains("p_conditions jsonb default null"))

# ---------------------------------------------------------------------------
# PLAFOND PAR RÉGIME — PE3.1
# ---------------------------------------------------------------------------

func _test_plafond() -> void:
	print("\n[Plafond par régime]")
	_wipe_tmp()
	var s := Settings.new()
	s._settings_path = TMP_SETTINGS
	var avant := Engine.max_fps

	s.set_fps_cap(0)
	_check("menu, fenêtre au premier plan : le plafond des menus",
		s.plafond_effectif() == Settings.PLAFOND_MENU, str(s.plafond_effectif()))
	_check("… et il est appliqué au moteur", Engine.max_fps == Settings.PLAFOND_MENU,
		str(Engine.max_fps))

	s.signaler_arene(true)
	_check("en arène, déplafonné : le choix du joueur, rien d'autre",
		s.plafond_effectif() == 0 and Engine.max_fps == 0, str(Engine.max_fps))

	s.signaler_arene(false)
	s.set_fps_cap(60)
	_check("un choix plus bas que le plafond des menus l'emporte", s.plafond_effectif() == 60)
	s.set_fps_cap(240)
	_check("un choix plus haut est ramené au plafond des menus",
		s.plafond_effectif() == Settings.PLAFOND_MENU)

	s.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("menu hors focus : le plafond hors focus",
		s.plafond_effectif() == Settings.PLAFOND_HORS_FOCUS and Engine.max_fps == Settings.PLAFOND_HORS_FOCUS,
		str(Engine.max_fps))
	s.signaler_arene(true)
	_check("en arène hors focus : JAMAIS de plafond en match — le choix du joueur (240)",
		s.plafond_effectif() == 240, str(s.plafond_effectif()))
	s.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	s.signaler_arene(false)
	_check("retour au menu, focus revenu : le plafond des menus",
		s.plafond_effectif() == Settings.PLAFOND_MENU)

	# Un banc qui règle lui-même Engine.max_fps ne doit pas se faire écraser.
	Engine.max_fps = 77
	s.pilotage_externe = true
	s.set_fps_cap(60)
	_check("sous pilotage externe, les réglages ne touchent plus au moteur",
		Engine.max_fps == 77, str(Engine.max_fps))
	s.pilotage_externe = false
	s.set_fps_cap(0)
	_check("pilotage rendu : le plafond des menus revient", Engine.max_fps == Settings.PLAFOND_MENU)

	_check("les deux plafonds sont des VALEURS DE DÉPART lisibles et ordonnées",
		Settings.PLAFOND_HORS_FOCUS > 0 and Settings.PLAFOND_HORS_FOCUS < Settings.PLAFOND_MENU)

	Engine.max_fps = avant
	s.free()
	_wipe_tmp()

func _wipe_tmp() -> void:
	if FileAccess.file_exists(TMP_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SETTINGS))
