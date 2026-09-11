## La télémétrie des gadgets dans l'archive des matchs — chantier DIX CLASSES,
## étape 28, lot E (suggestion 8, PE5 ; 2026-09-11).
##
## Ce que ces contrôles protègent ne se voit pas à l'usage : une télémétrie à zéro
## ressemble en tout point à des gadgets qui ne servent pas, et deux archives qui
## divergent entre l'hôte et le client ne se contredisent nulle part où quelqu'un
## regarde. Quatre familles :
##
##   A. la comptabilité pure (`TelemetrieGadgets`), sur une horloge synthétique ;
##   B. le schéma 6 de `MatchRecord` — la clé, la copie, l'absence qui n'est pas zéro ;
##   C. les garde-fous lus dans le TEXTE — le nom littéral relié à son inverse, les
##      clés du tamis serveur comparées aux compteurs dans les deux sens ;
##   D. deux matchs scénarisés sur le VRAI `main.tscn`, par le vrai départ de manche ;
##   E. les branches EN LIGNE, exécutées — pas seulement lues dans le texte.
##
## ⚠️ **E existe parce que D ne suffisait pas** (revue du 2026-09-11). Les deux matchs
## de D tournent en écran scindé : ils ne passent ni par la branche `ONLINE_HOST` de
## `take_damage`, qui met la CAUSE sur le fil, ni par l'ORDRE `rpc_detruire_gadget`,
## par lequel le CLIENT compte les morts de gadget. Les trois erreurs qu'on peut y
## faire — l'hôte qui envoie une cause en dur, le client qui la lit à l'envers —
## laissaient les 143 contrôles verts.
##
## ⚠️ **Une suite en `--script` ne précharge jamais `game_state.gd`**, ni ne nomme un
## autoload ou la classe `Player` à la compilation : le fichier entier cesserait de
## compiler. `main.tscn` se charge par `load()` dans le `_run` différé ; l'autoload
## réseau se lit par son nœud et ses modes par chaîne.
##
## ⚠️ **On attend des CONDITIONS, jamais des durées** (piège « Un banc qui vacille est
## pire qu'aucun banc ») : chaque attente a un plafond, qui n'est pas un délai. Chaque
## état encore FORCÉ est commenté (piège « Un test qui force l'état ne voit pas l'état
## réel »).
##
## Lancer : godot --headless --path . --script res://tools/test_telemetrie_gadgets.gd
extends SceneTree

const _IP = preload("res://input_provider.gd")

## Un joueur qui ne fait rien : ni pas, ni tir, ni torche — regard à droite.
class Inerte extends _IP:
	func get_movement_vector() -> Vector2: return Vector2.ZERO
	func get_aim_direction(_p: Vector2) -> Vector2: return Vector2.RIGHT
	func is_shoot_pressed() -> bool: return false
	func is_flashlight_pressed() -> bool: return false
	func is_flare_pressed() -> bool: return false
	func is_reload_pressed() -> bool: return false
	func is_gadget_pressed() -> bool: return false

var _failures := 0


func _init() -> void:
	print("=== Télémétrie des gadgets (étape 28, lot E) ===")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_comptabilite()
	_test_poseur_du_nom()
	_test_schema_6()
	_test_garde_fous_texte()
	await _test_matchs_scenarises()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


# ---------------------------------------------------------------------------
# A. COMPTABILITÉ PURE — horloge synthétique
# ---------------------------------------------------------------------------

func _test_comptabilite() -> void:
	print("\n[A. La comptabilité, sur une horloge synthétique]")
	var n := TelemetrieGadgets.FENETRE_EFFET_S

	# La fenêtre : 4,99 s après un effet, la mort compte ; 5,01 s, non.
	var t := TelemetrieGadgets.new()
	t.pose(0, 10.0)
	t.pv_perdus(1, 0, false, 100.0, true, 10.0 + n - 0.01)
	_check("une mort dans la fenêtre d'un effet adverse est comptée",
		_cote(t, 0)["morts_adverses_apres_effet"] == 1, str(_cote(t, 0)))
	var temoin := TelemetrieGadgets.new()
	temoin.pose(0, 10.0)
	temoin.pv_perdus(1, 0, false, 100.0, true, 10.0 + n + 0.01)
	_check("témoin : juste après la fenêtre, elle ne l'est pas",
		_cote(temoin, 0)["morts_adverses_apres_effet"] == 0, str(_cote(temoin, 0)))

	# L'extinction n'est pas un effet : allumée à 0, éteinte à 5, mort à 6.
	var b := TelemetrieGadgets.new()
	b.bascule(1, true, 1.0, 0.0)
	b.bascule(1, false, 0.4, 5.0)
	b.pv_perdus(0, 1, false, 100.0, true, 6.0)
	_check("une extinction ne rouvre pas la fenêtre",
		_cote(b, 1)["morts_adverses_apres_effet"] == 0, str(_cote(b, 1)))
	_check("… et elle est comptée comme un geste du joueur",
		_cote(b, 1)["bascules_allume"] == 1 and _cote(b, 1)["bascules_eteint"] == 1
			and _cote(b, 1)["batterie_vide"] == 0, str(_cote(b, 1)))
	var v := TelemetrieGadgets.new()
	v.bascule(0, false, 0.0, 1.0)
	_check("une extinction à batterie 0,0 est la coupure de l'hôte",
		_cote(v, 0)["batterie_vide"] == 1 and _cote(v, 0)["bascules_eteint"] == 0,
		str(_cote(v, 0)))

	# Une bobine posée éteinte : une pose, pas un effet.
	var e := TelemetrieGadgets.new()
	e.pose(0, 0.0, false)
	e.pv_perdus(1, 0, false, 100.0, true, 1.0)
	_check("une bobine posée éteinte compte une pose…", _cote(e, 0)["poses"] == 1)
	_check("… mais pas un effet", _cote(e, 0)["morts_adverses_apres_effet"] == 0,
		str(_cote(e, 0)))

	# Les braises : des PV, pas des appels ; au poseur, qu'il se brûle ou non.
	var br := TelemetrieGadgets.new()
	for i in 4:
		br.pv_perdus(1, 0, true, 0.25, false, 1.0 + i)
	br.pv_perdus(0, 0, true, 4.0, false, 5.0)
	_check("quatre fois 0,25 PV sur l'adversaire font 1,0",
		is_equal_approx(float(_cote(br, 0)["pv_braises_adversaire"]), 1.0),
		str(_cote(br, 0)["pv_braises_adversaire"]))
	_check("le poseur qui se brûle compte à part",
		is_equal_approx(float(_cote(br, 0)["pv_braises_soi"]), 4.0),
		str(_cote(br, 0)["pv_braises_soi"]))
	_check("la victime des braises n'est pas créditée",
		is_zero_approx(float(_cote(br, 1)["pv_braises_adversaire"]))
			and is_zero_approx(float(_cote(br, 1)["pv_braises_soi"])))

	# Témoin : une BALLE du poseur n'est ni une brûlure ni un effet.
	var balle := TelemetrieGadgets.new()
	balle.pv_perdus(1, 0, false, 30.0, false, 0.0)
	balle.pv_perdus(1, 0, false, 70.0, true, 1.0)
	_check("témoin : une balle du poseur ne compte pas en braises",
		is_zero_approx(float(_cote(balle, 0)["pv_braises_adversaire"])))
	_check("… et ne crée pas d'effet", _cote(balle, 0)["morts_adverses_apres_effet"] == 0)

	# Le dernier PV de braises tue à délai nul : l'effet est noté AVANT la mort.
	var fatal := TelemetrieGadgets.new()
	fatal.pv_perdus(1, 0, true, 4.0, true, 100.0)
	_check("un dernier PV de braises mortel compte sa mort",
		_cote(fatal, 0)["morts_adverses_apres_effet"] == 1, str(_cote(fatal, 0)))

	# Les allumages et les morts de gadget.
	var m := TelemetrieGadgets.new()
	m.allumage(0, 3.0)
	m.mort_de_gadget(0, true)
	m.mort_de_gadget(0, false)
	m.pv_perdus(0, 1, false, 100.0, true, 4.0)
	_check("un allumage est compté et ouvre la fenêtre",
		_cote(m, 0)["allumages"] == 1 and _cote(m, 0)["morts_propres_apres_effet"] == 1,
		str(_cote(m, 0)))
	_check("une mort par balle et une en fin de vie, chacune à sa place",
		_cote(m, 0)["morts_balle"] == 1 and _cote(m, 0)["morts_fin_de_vie"] == 1)
	_check("la mort d'un gadget n'est pas un effet",
		_cote(m, 1)["morts_adverses_apres_effet"] == 0)

	# Un joueur inconnu est ignoré, sans erreur.
	var inconnu := TelemetrieGadgets.new()
	inconnu.pv_perdus(1, -1, true, 4.0, false, 1.0)
	inconnu.pose(-1, 0.0)
	inconnu.allumage(2, 0.0)
	inconnu.mort_de_gadget(-1, true)
	inconnu.bascule(7, true, 1.0, 0.0)
	_check("un poseur inconnu (−1, 2, 7) n'est compté nulle part",
		_cote(inconnu, 0) == _vierge_resume() and _cote(inconnu, 1) == _vierge_resume(),
		"%s / %s" % [str(_cote(inconnu, 0)), str(_cote(inconnu, 1))])

	# commencer() remet tout à zéro, fenêtre comprise.
	m.commencer()
	m.pv_perdus(0, 1, false, 100.0, true, 4.5)
	_check("commencer() remet tout à zéro, fenêtre comprise",
		_cote(m, 0) == _vierge_resume() and _cote(m, 1) == _vierge_resume(),
		"%s / %s" % [str(_cote(m, 0)), str(_cote(m, 1))])

	# La forme du bloc.
	var r := br.resume("nappe_braises", "", 1)
	var attendues := TelemetrieGadgets.COMPTEURS + TelemetrieGadgets.CUMULS + ["gadget"]
	for cote in ["j1", "j2"]:
		var cles: Array = (r[cote] as Dictionary).keys()
		_check("%s porte exactement les compteurs, les cumuls et le gadget" % cote,
			_memes_cles(cles, attendues), str(cles))
	_check("le premier niveau porte version, fenêtre, joueur local et les deux côtés",
		_memes_cles(r.keys(), ["version", "fenetre_s", "joueur_local", "j1", "j2"]),
		str(r.keys()))
	_check("la fenêtre et la version voyagent dans le bloc",
		is_equal_approx(float(r["fenetre_s"]), n) and int(r["version"]) == TelemetrieGadgets.VERSION)
	_check("chaque côté porte le slug de son gadget",
		r["j1"]["gadget"] == "nappe_braises" and r["j2"]["gadget"] == "")
	_check("aucune clé ne contient « classe » (le booléen du classement)",
		not _une_cle_contient(r, "classe"))
	var arrondi := TelemetrieGadgets.new()
	arrondi.pv_perdus(1, 0, true, 1.0 / 3.0, false, 0.0)
	_check("les cumuls sont arrondis au centième",
		float(arrondi.resume("", "", -1)["j1"]["pv_braises_adversaire"]) == 0.33)


# ---------------------------------------------------------------------------
# L'inverse du nom des gadgets
# ---------------------------------------------------------------------------

func _test_poseur_du_nom() -> void:
	print("\n[Le poseur, lu dans le nom — l'inverse du littéral de game_state]")
	var fmt := _format_du_nom()
	_check("le littéral du nom est lu dans game_state.gd", fmt == "GadgetJ%d_%d", fmt)
	if not fmt.is_empty():
		# L'aller-retour sur le format LU, pas sur une copie : le jour où le littéral
		# change, c'est ici que l'inverse cesse de le suivre.
		_check("J1, pose 3 → 0", GadgetBase.poseur_du_nom(fmt % [0 + 1, 3]) == 0)
		_check("J2, pose 17 → 1", GadgetBase.poseur_du_nom(fmt % [1 + 1, 17]) == 1)
	for faux in ["GadgetJ3_1", "GadgetJ0_1", "Gadget_P1", "@GadgetJ1_3@4", "GadgetJx_1",
			"GadgetJ1", ""]:
		_check("« %s » → −1" % faux, GadgetBase.poseur_du_nom(faux) == -1,
			str(GadgetBase.poseur_du_nom(faux)))


## Le format du nom, extrait de la ligne `g.name = "…" % [pid + 1, numero]`.
func _format_du_nom() -> String:
	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	var ligne := 'g.name = "GadgetJ%d_%d" % [pid + 1, numero]'
	if not gs.contains(ligne):
		return ""
	return ligne.get_slice('"', 1)


# ---------------------------------------------------------------------------
# B. LE SCHÉMA 6
# ---------------------------------------------------------------------------

func _test_schema_6() -> void:
	print("\n[B. Le schéma 6 de l'archive]")
	# Le nombre est ÉCRIT ici (la leçon de test_rejeu_journal : un oracle lu dans le
	# code testé ne teste rien).
	_check("le schéma est en 6", MatchRecord.SCHEMA_VERSION == 6, str(MatchRecord.SCHEMA_VERSION))

	var bloc := TelemetrieGadgets.new().resume("voile", "leurre", 0)
	var avec := MatchRecord.build(0, 12.0, "A", "B", "carte", "en_ligne_hote",
		MatchRecord.Format.BO1, false, "id", true, "win", "spectre", "illusionniste",
		{"fps_median": 120.0}, bloc)
	bloc["j1"]["poses"] = 99
	_check("le bloc est copié en profondeur",
		int(avec["gadgets"]["j1"]["poses"]) == 0, str(avec["gadgets"]["j1"]["poses"]))
	_check("les conditions n'ont pas bougé",
		float(avec["conditions"].get("fps_median", 0.0)) == 120.0)
	_check("`classe` reste le booléen du classement", avec["classe"] is bool)
	var sans := MatchRecord.build(1, 3.0, "A", "B", "carte", "local")
	_check("sans télémétrie : un dictionnaire vide, jamais une clé absente",
		sans.has("gadgets") and (sans["gadgets"] as Dictionary).is_empty())

	# Une entrée v5 — telle que le jeu l'écrivait hier : pas de clé `gadgets`.
	var v5 := {
		"version": 5, "forfait": false, "vainqueur": 0, "egalite": false,
		"duree": 88.0, "arme_j1": "A", "arme_j2": "B", "classe_j1": "spectre",
		"classe_j2": "allumeur", "carte": "default", "mode": "en_ligne_hote",
		"horodatage": "2026-09-10T12:00:00", "format": "BO1", "match_id": "v5",
		"classe": true, "issue": "win", "remonte": false, "conditions": {},
	}
	_check("une entrée v5 n'a pas de télémétrie : {}, jamais des zéros",
		MatchRecord.gadgets_de(v5).is_empty(), str(MatchRecord.gadgets_de(v5)))
	_check("… et elle se lit toujours à l'historique",
		not MatchHistoryView.row_from(v5).is_empty())
	var v6 := MatchRecord.build(0, 12.0, "A", "B", "carte", "local",
		MatchRecord.Format.BO1, false, "", false, "", "", "", {}, bloc.duplicate(true))
	var g6 := MatchRecord.gadgets_de(v6)
	_check("une entrée v6 à zéro pose porte le zéro : l'absence et le zéro se distinguent",
		g6.has("j1") and (g6["j1"] as Dictionary).has("poses") and int(g6["j2"]["poses"]) == 0)
	_check("… et se lit à l'historique", not MatchHistoryView.row_from(v6).is_empty())
	_check("une entrée abîmée rend {}",
		MatchRecord.gadgets_de("pas un dictionnaire").is_empty()
			and MatchRecord.gadgets_de({"gadgets": [1, 2]}).is_empty())

	# La seule fusion : ce qui part au serveur.
	var cond := {"fps_median": 60.0, "machine": {"os": "Test"}}
	var copie := cond.duplicate(true)
	var sans_g := MatchRecord.conditions_a_envoyer(cond, {})
	_check("sans télémétrie, le bloc d'avant exactement",
		sans_g == cond and not sans_g.has("gadgets"), str(sans_g))
	var avec_g := MatchRecord.conditions_a_envoyer(cond, bloc)
	_check("avec télémétrie, elle est rangée dans la copie",
		avec_g.has("gadgets") and avec_g["gadgets"] == bloc and avec_g["fps_median"] == 60.0)
	_check("… sans toucher aux conditions archivées", cond == copie, str(cond))
	avec_g["gadgets"]["j2"]["poses"] = 42
	_check("… ni au bloc de télémétrie", int(bloc["j2"]["poses"]) == 0)
	_check("des conditions illisibles (entrée d'avant v5) donnent un bloc propre",
		MatchRecord.conditions_a_envoyer(null, bloc).keys() == ["gadgets"])


# ---------------------------------------------------------------------------
# C. LES GARDE-FOUS LUS DANS LE TEXTE
# ---------------------------------------------------------------------------

func _test_garde_fous_texte() -> void:
	print("\n[C. Les garde-fous, lus dans le texte]")
	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	var pl := FileAccess.get_file_as_string("res://player.gd")
	var br := FileAccess.get_file_as_string("res://gadget_braises.gd")
	var ri := FileAccess.get_file_as_string("res://ranked_identity.gd")
	var ts := FileAccess.get_file_as_string("res://supabase/functions/_shared/match_report.ts")

	_check("player.gd prévient la télémétrie de chaque PV perdu",
		pl.contains("gs_tel.noter_pv_perdus(player_id, source_id, cause,"))
	# CLAUDE.md, la fusion du 2026-09-09 : une garde muette change un oubli en zéro.
	_check("… sans garde has_method, qui ferait d'un oubli une télémétrie muette",
		not pl.contains('has_method("noter_pv_perdus")'))
	_check("la nappe dit la CAUSE de ses PV", br.contains("DEGATS_BRAISES)"))
	# ⚠️ La LIGNE ENTIÈRE, cause comprise (revue du 2026-09-11). Le préfixe seul
	# survivait à un client qui lirait `cause != MORT_BALLE` — il rangeait alors les
	# morts à l'envers, et l'archive du client cessait de dire ce que dit celle de
	# l'hôte, ce que ce lot promet d'empêcher.
	_check("l'hôte ET le client attribuent la mort d'un gadget par son nom, MÊME cause",
		gs.count("_telemetrie.mort_de_gadget(GadgetBase.poseur_du_nom(nom), cause == GadgetBase.MORT_BALLE)") == 2)
	_check("… et l'hôte tire cette cause de `abattu_par_balle`, pas d'une constante",
		gs.contains("var cause := GadgetBase.MORT_BALLE if g.abattu_par_balle else GadgetBase.MORT_FIN_DE_VIE"))
	_check("l'ordre de destruction PORTE la cause décidée",
		gs.contains("rpc_detruire_gadget.rpc(nom, cause)"))
	_check("l'ordre de PV porte la sienne, chez l'hôte comme en local",
		pl.contains("rpc_update_hp.rpc(new_hp, sid, cause)")
			and pl.contains("rpc_update_hp(new_hp, sid, cause)"))
	# Les matchs de D posent la bobine ALLUMÉE : ce site n'y est jamais éprouvé éteint.
	# La comptabilité l'est en A ; le texte relie le site à elle.
	_check("une bobine posée éteinte n'est pas un effet — l'état de l'hôte décide",
		gs.contains("_telemetrie.pose(pid, _t_telemetrie(), not g.est_basculable() or actif_initial)"))
	_check("l'allumage est compté à l'ordre, attribué par le nom",
		gs.contains("_telemetrie.allumage(GadgetBase.poseur_du_nom(nom), _t_telemetrie())"))
	_check("le client ne compte pas à son propre minuteur",
		gs.contains("func _sur_gadget_detruit(g: GadgetBase) -> void:\n\tif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:\n\t\treturn"))
	_check("l'archive et le rapport portent le même bloc",
		gs.contains("_report_to_ranking(winner_id, forfeit, conditions, gadgets)"))
	_check("le rejeu du journal passe par la même fusion",
		ri.contains("MatchRecord.conditions_a_envoyer(e.get(\"conditions\", {}),"))
	_check("le tamis du serveur lit la télémétrie dans les conditions",
		ts.contains("parseGadgets(source.gadgets)"))

	# Les clés du tamis, dans les DEUX sens : une clé ajoutée d'un seul côté tomberait
	# sans bruit au serveur (piège « Une garantie tenue par une ligne que rien ne relie
	# à elle »). On lit le tableau lui-même, pas le fichier entier : « poses » dans un
	# commentaire ne prouverait rien.
	var serveur := _cles_du_tableau(ts, "const GADGET_NUMBERS = [")
	var jeu: Array = TelemetrieGadgets.COMPTEURS + TelemetrieGadgets.CUMULS
	_check("le tamis connaît toutes les clés d'un côté (jeu → serveur)",
		_manquantes(jeu, serveur).is_empty(), "absentes du serveur : %s" % str(_manquantes(jeu, serveur)))
	_check("… et aucune de plus (serveur → jeu)",
		_manquantes(serveur, jeu).is_empty(), "inconnues du jeu : %s" % str(_manquantes(serveur, jeu)))
	var serveur_haut := _cles_du_tableau(ts, "const GADGETS_NUMBERS = [")
	var haut_jeu: Array = []
	var r := TelemetrieGadgets.new().resume("", "", -1)
	for k in r.keys():
		if not (r[k] is Dictionary):
			haut_jeu.append(k)
	_check("les nombres du premier niveau, dans les deux sens",
		_memes_cles(serveur_haut, haut_jeu), "%s contre %s" % [str(serveur_haut), str(haut_jeu)])


## Les chaînes entre guillemets du tableau qui suit `ouverture`, jusqu'au premier `]`.
func _cles_du_tableau(texte: String, ouverture: String) -> Array:
	var debut := texte.find(ouverture)
	if debut < 0:
		return []
	debut += ouverture.length()
	var fin := texte.find("]", debut)
	var re := RegEx.create_from_string("\"([a-z_0-9]+)\"")
	var cles: Array = []
	for m in re.search_all(texte.substr(debut, fin - debut)):
		cles.append(m.get_string(1))
	return cles


# ---------------------------------------------------------------------------
# D. DEUX MATCHS SUR LE VRAI main.tscn
# ---------------------------------------------------------------------------

func _test_matchs_scenarises() -> void:
	print("\n[D. Deux matchs sur le vrai main.tscn]")
	var gs: Node = load("res://main.tscn").instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame
	# Piège « Un outil de mise en scène écrivait dans le vrai historique des matchs » :
	# le banc lit `dernier_enregistrement`, il n'écrit rien chez le joueur.
	gs.archiver_les_matchs = false
	_check("le banc joue en local (écran scindé)",
		_nm().current_mode == _mode("LOCAL_SPLITSCREEN"), str(_nm().current_mode))

	var incendiaire := _index_par_gadget(gs, "nappe_braises")
	var parasite := _index_par_gadget(gs, "gresillement")
	var allumeur := _index_par_gadget(gs, "mine_magnesium")
	var illusionniste := _index_par_gadget(gs, "leurre")
	_check("les quatre classes se trouvent par leur gadget",
		incendiaire >= 0 and parasite >= 0 and allumeur >= 0 and illusionniste >= 0,
		str([incendiaire, parasite, allumeur, illusionniste]))
	if incendiaire < 0 or parasite < 0 or allumeur < 0 or illusionniste < 0:
		return
	var fournisseurs := [gs.p1.input_provider, gs.p2.input_provider]

	await _match_a(gs, incendiaire, parasite)
	await _match_b(gs, allumeur, illusionniste)
	await _test_branches_en_ligne(gs, incendiaire, parasite)

	# Rien de ce que les deux matchs posent ne doit courir après la suite.
	gs.round_active = false
	gs.countdown_left = 0.0
	Engine.time_scale = 1.0
	gs.p1.input_provider = fournisseurs[0]
	gs.p2.input_provider = fournisseurs[1]


## Le vrai départ de manche, puis ce que le menu aurait fait.
func _depart(gs: Node, w1: int, w2: int) -> void:
	# Piège « Un test qui force l'état ne voit pas l'état réel » : la VRAIE fonction,
	# celle que `rpc_start_round` et le rematch appellent.
	gs._do_start_round(w1, w2)
	# Forcé : le décompte de 3 s n'est pas ce qu'on éprouve ; et le menu, que le banc ne
	# traverse pas, aurait levé `_is_main_menu` (sans quoi les joueurs sont gelés).
	gs.countdown_left = 0.0
	gs.ui._is_main_menu = false
	gs.p1.input_provider = Inerte.new()
	gs.p2.input_provider = Inerte.new()
	# Un enregistrement périmé ne doit jamais être relu.
	gs.dernier_enregistrement = {}
	# Les joueurs viennent d'être téléportés au départ, l'arène reconstruite : deux pas
	# de physique avant la première requête (le rayon de pose).
	await physics_frame
	await physics_frame


func _match_a(gs: Node, incendiaire: int, parasite: int) -> void:
	print("  — match A : l'Incendiaire contre le Parasite")
	await _depart(gs, incendiaire, parasite)
	var p1 = gs.p1
	var p2 = gs.p2

	# 1. Témoin : une BALLE n'est pas une brûlure.
	p2.take_damage(10.0, p1)

	# 2. Deux nappes : la seconde REMPLACE la première — un remplacement n'est pas une mort.
	gs.spawn_gadget(p1, p1.global_position, p1.rotation)
	_check("A : la première nappe est posée", gs._gadgets_poses_par[0] == 1,
		str(gs._gadgets_poses_par))
	gs._gadget_attente[0] = 0.0   # Forcé : la recharge réelle dure 60 s.
	gs.spawn_gadget(p1, p1.global_position, p1.rotation)
	_check("A : la seconde aussi", gs._gadgets_poses_par[0] == 2, str(gs._gadgets_poses_par))
	await process_frame
	var nappes := _gadgets_de(gs, 0)
	_check("A : une seule nappe debout", nappes.size() == 1, str(nappes.size()))
	if nappes.size() != 1:
		return
	var nappe = nappes[0]

	# 3. J2 dans la nappe, puis dehors ; J1 dedans, et il y reste.
	p2.global_position = nappe.global_position
	_check("A : J2 brûle", await _attendre(func(): return p2.hp <= 85.0, 5.0), "%.1f PV" % p2.hp)
	p2.global_position = gs._get_spawn_position(1)
	_check("A : témoin — J2 est ressorti de la nappe",
		p2.global_position.distance_to(nappe.global_position) > GadgetBraises.RAYON + 10.0)
	p1.global_position = nappe.global_position
	_check("A : J1 se brûle à son propre feu",
		await _attendre(func(): return p1.hp <= 97.0, 5.0), "%.1f PV" % p1.hp)

	# 4. La fin de vie de la nappe. Forcé : dix secondes de vie réelle.
	nappe._age = nappe.duree_vie
	_check("A : la nappe meurt en fin de vie",
		await _attendre(func(): return not is_instance_valid(nappe), 3.0))
	var pv1: float = p1.hp
	var pv2: float = p2.hp
	p1.global_position = gs._get_spawn_position(0)
	await physics_frame
	await physics_frame

	# 5. La bobine : posée allumée, éteinte, rallumée, puis coupée à batterie vide.
	gs.spawn_gadget(p2, p2.global_position, p2.rotation)
	var bobines := _gadgets_de(gs, 1)
	_check("A : la bobine est posée", bobines.size() == 1, str(bobines.size()))
	if bobines.size() != 1:
		return
	var bobine = bobines[0]
	_check("A : posée allumée — la batterie est pleine", bobine.actif)
	gs.basculer_gadget(p2)
	_check("A : éteinte à la main", not bobine.actif)
	gs.basculer_gadget(p2)
	_check("A : rallumée", bobine.actif)
	gs._batterie[1] = 0.0001   # Forcé : quatorze secondes de batterie réelle.
	_check("A : coupée par l'hôte à batterie vide",
		await _attendre(func(): return not bobine.actif, 3.0))

	# 6. Abattue, puis J2 tué — dans la même image.
	_precondition_fenetre(gs)
	bobine.encaisser(bobine.pv)
	p2.take_damage(1000.0, p1)

	var rec: Dictionary = gs.dernier_enregistrement
	_check("A : le match est archivé (enregistrement construit)", not rec.is_empty())
	if rec.is_empty():
		return
	var g: Dictionary = rec.get("gadgets", {})
	_check("A : aucune clé du bloc ne contient « classe »", not _une_cle_contient(g, "classe"))
	_check("A : `classe` reste le booléen du classement", rec["classe"] is bool)
	_check("A : joueur local −1 hors ligne", int(g.get("joueur_local", 99)) == -1,
		str(g.get("joueur_local")))
	_check("A : la fenêtre et la version sont portées",
		int(g.get("version", 0)) == TelemetrieGadgets.VERSION
			and is_equal_approx(float(g.get("fenetre_s", 0.0)), TelemetrieGadgets.FENETRE_EFFET_S))
	var attendu_braises := (100.0 - 10.0) - pv2
	_check("A : témoin — les braises ont réellement brûlé J2", attendu_braises >= 4.0,
		"%.2f" % attendu_braises)
	_verifier(g, "j1", "A", {
		"gadget": "nappe_braises", "poses": 2, "morts_balle": 0, "morts_fin_de_vie": 1,
		"allumages": 0, "bascules_allume": 0, "bascules_eteint": 0, "batterie_vide": 0,
		"pv_braises_adversaire": attendu_braises, "pv_braises_soi": 100.0 - pv1,
		"morts_adverses_apres_effet": 1, "morts_propres_apres_effet": 0})
	_verifier(g, "j2", "A", {
		"gadget": "gresillement", "poses": 1, "morts_balle": 1, "morts_fin_de_vie": 0,
		"allumages": 0, "bascules_allume": 1, "bascules_eteint": 1, "batterie_vide": 1,
		"pv_braises_adversaire": 0.0, "pv_braises_soi": 0.0,
		"morts_adverses_apres_effet": 0, "morts_propres_apres_effet": 1})


## Le match B part SANS attendre l'écran de fin : `_do_start_round` coupe déjà la
## séquence de fin et remet `Engine.time_scale` à 1 — c'est le chemin du rematch.
func _match_b(gs: Node, allumeur: int, illusionniste: int) -> void:
	print("  — match B : l'Allumeur contre l'Illusionniste")
	await _depart(gs, allumeur, illusionniste)
	var p1 = gs.p1
	var p2 = gs.p2

	# 1. La mine, loin de J2.
	gs.spawn_gadget(p1, p1.global_position, p1.rotation)
	var mines := _gadgets_de(gs, 0)
	_check("B : la mine est posée", mines.size() == 1, str(mines.size()))
	if mines.size() != 1:
		return
	var mine = mines[0]
	_check("B : témoin — J2 est hors de son rayon",
		p2.global_position.distance_to(mine.global_position) > GadgetMine.RAYON_DECLENCHEMENT + 20.0)

	# 2. Pendant l'armement : le leurre, abattu PUIS détruit dans la même image — deux
	# appels de detruire(), une seule mort (témoin de la garde).
	gs.spawn_gadget(p2, p2.global_position, p2.rotation)
	var leurres := _gadgets_de(gs, 1)
	_check("B : le leurre est posé", leurres.size() == 1, str(leurres.size()))
	if leurres.size() != 1:
		return
	var leurre = leurres[0]
	leurre.encaisser(leurre.pv)
	leurre.detruire()

	# 3. L'armement est une CONDITION, pas un délai ; puis J2 marche sur la mine.
	_check("B : la mine s'arme",
		await _attendre(func(): return mine.age() >= GadgetMine.ARMEMENT, 10.0),
		"âge %.2f s" % mine.age())
	p2.global_position = mine.global_position
	var allumee := await _attendre(func(): return bool(mine._allumee), 5.0)
	_check("B : J2 la déclenche (par le chemin local de l'ordre)", allumee)

	# 4. J1 tué dans l'image où l'allumage est vu : l'embrasement dure 1,6 s, la mine ne
	# peut pas mourir avant.
	_precondition_fenetre(gs)
	p1.take_damage(1000.0, p2)

	var rec: Dictionary = gs.dernier_enregistrement
	_check("B : le match est archivé (enregistrement construit)", not rec.is_empty())
	if rec.is_empty():
		return
	var g: Dictionary = rec.get("gadgets", {})
	# poses à 1 : témoin de la remise à zéro par match (3 si elle manque, le match A
	# en ayant posé deux).
	_verifier(g, "j1", "B", {
		"gadget": "mine_magnesium", "poses": 1, "morts_balle": 0, "morts_fin_de_vie": 0,
		"allumages": 1, "bascules_allume": 0, "bascules_eteint": 0, "batterie_vide": 0,
		"pv_braises_adversaire": 0.0, "pv_braises_soi": 0.0,
		"morts_adverses_apres_effet": 0, "morts_propres_apres_effet": 1})
	# morts_balle à 1 : 2 sans la garde de detruire().
	_verifier(g, "j2", "B", {
		"gadget": "leurre", "poses": 1, "morts_balle": 1, "morts_fin_de_vie": 0,
		"allumages": 0, "bascules_allume": 0, "bascules_eteint": 0, "batterie_vide": 0,
		"pv_braises_adversaire": 0.0, "pv_braises_soi": 0.0,
		"morts_adverses_apres_effet": 1, "morts_propres_apres_effet": 0})


# ---------------------------------------------------------------------------
# E. LES BRANCHES EN LIGNE, EXÉCUTÉES
# ---------------------------------------------------------------------------

## Les deux chemins que l'écran scindé ne traverse jamais. Aucun pair en face : on
## joue les deux rôles, l'un après l'autre, sur le même arbre.
func _test_branches_en_ligne(gs: Node, incendiaire: int, parasite: int) -> void:
	print("\n[E. Les branches EN LIGNE, exécutées]")
	# Un match neuf : les joueurs sont vivants, et la télémétrie repart de zéro.
	await _depart(gs, incendiaire, parasite)
	var p1 = gs.p1
	var p2 = gs.p2

	# 1. CÔTÉ CLIENT — l'ordre de destruction, tel qu'il arrive du réseau. Un RPC
	# s'appelle comme une fonction ; c'est le seul état FORCÉ ici, et il est exact :
	# le client n'a pas d'autre entrée. Les deux noms ne désignent aucun nœud vivant,
	# et c'est le propos — le client compte à l'ORDRE, que le nœud existe encore ou
	# non chez lui.
	gs._telemetrie.commencer()
	gs.rpc_detruire_gadget("GadgetJ2_99", GadgetBase.MORT_BALLE)
	gs.rpc_detruire_gadget("GadgetJ1_98", GadgetBase.MORT_FIN_DE_VIE)
	var j2: Dictionary = _cote_de(gs, 1)
	var j1: Dictionary = _cote_de(gs, 0)
	_check("E : l'ordre « par balle » compte une mort par balle chez SON poseur",
		int(j2["morts_balle"]) == 1 and int(j2["morts_fin_de_vie"]) == 0
			and int(j1["morts_balle"]) == 0, "%s / %s" % [str(j2), str(j1)])
	_check("E : l'ordre « fin de vie » compte une fin de vie chez le sien",
		int(j1["morts_fin_de_vie"]) == 1 and int(j2["morts_fin_de_vie"]) == 0,
		"%s / %s" % [str(j1), str(j2)])

	# 2. CÔTÉ HÔTE — la CAUSE sur le fil. `take_damage` y passe par
	# `rpc_update_hp.rpc()`, que le pair hors ligne exécute en local (`call_local`) :
	# les arguments sont ceux qu'un vrai client recevrait. Le mode est rendu dans la
	# MÊME image, sans un seul `await` entre les deux : aucune image de jeu n'est
	# jouée en hôte, rien d'autre ne change de chemin.
	gs._telemetrie.commencer()
	var avant: int = _nm().current_mode
	var pv_avant: float = p2.hp
	_nm().current_mode = _mode("ONLINE_HOST")
	p2.take_damage(0.25, p1, GadgetBase.DEGATS_BRAISES)
	p2.take_damage(1.0, p1)   # Témoin : une balle du même poseur, par le même chemin.
	_nm().current_mode = avant
	_check("E : le mode est rendu à l'écran scindé",
		_nm().current_mode == _mode("LOCAL_SPLITSCREEN"), str(_nm().current_mode))
	_check("E : témoin — les deux coups ont bien porté chez l'hôte",
		absf((pv_avant - p2.hp) - 1.25) <= 0.011, "%.2f PV" % (pv_avant - p2.hp))
	j1 = _cote_de(gs, 0)
	_check("E : l'hôte met la CAUSE braises sur le fil — 0,25 PV, et la balle dehors",
		absf(float(j1["pv_braises_adversaire"]) - 0.25) <= 0.011,
		str(j1["pv_braises_adversaire"]))
	_check("E : … et la mort d'aucun gadget n'a été inventée en chemin",
		int(j1["morts_balle"]) == 0 and int(j1["morts_fin_de_vie"]) == 0, str(j1))


## Chaque clé du côté, et aucune de plus (piège « Un champ que personne ne lit »).
func _verifier(g: Dictionary, cote: String, match_nom: String, attendu: Dictionary) -> void:
	var d: Dictionary = g.get(cote, {})
	_check("%s : %s porte exactement les clés attendues" % [match_nom, cote],
		_memes_cles(d.keys(), attendu.keys()), str(d.keys()))
	for k in attendu:
		var a = attendu[k]
		var ok: bool
		if a is float:
			ok = d.has(k) and absf(float(d[k]) - a) <= 0.011
		else:
			ok = d.has(k) and d[k] == a
		_check("%s : %s.%s = %s" % [match_nom, cote, k, str(a)], ok, str(d.get(k)))


## L'échec doit dire « banc trop lent », pas « compteur faux » : les deux derniers
## effets datent de moins de 4 s au moment du kill (la fenêtre en fait 5).
func _precondition_fenetre(gs: Node) -> void:
	var t: float = gs._t_telemetrie()
	var ages: Array = []
	for pid in 2:
		ages.append(snappedf(t - float(gs._telemetrie._dernier_effet[pid]), 0.01))
	print("    dernier effet de chaque joueur, avant le kill : %s s" % str(ages))
	_check("précondition : chaque dernier effet date de moins de 4 s (sinon : banc trop lent)",
		float(ages[0]) < 4.0 and float(ages[1]) < 4.0, str(ages))


## Attend une CONDITION, image après image ; `plafond` en secondes réelles n'est pas un
## délai mais une borne. Rend l'état de la condition.
func _attendre(condition: Callable, plafond: float) -> bool:
	var fin := Time.get_ticks_msec() + int(plafond * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _gadgets_de(gs: Node, pid: int) -> Array:
	var out: Array = []
	for g in gs.get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion() and g.poseur_id == pid:
			out.append(g)
	return out


func _index_par_gadget(gs: Node, slug: String) -> int:
	for i in range(10):
		var c = gs.weapon_for_index(i)
		if c != null and c.get("gadget") != null and String(c.gadget.slug) == slug:
			return i
	return -1


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

## L'autoload réseau par son NŒUD, ses modes par CHAÎNE (le patron du lot C) : nommé à
## la compilation, il ferait cesser cette suite de compiler en entier.
func _nm() -> Node:
	return root.get_node("NetworkManager")


func _mode(nom: String) -> int:
	return int(_nm().get_script().get_script_constant_map()["GameMode"][nom])


## Un côté tel que `resume()` le rend — slug de gadget vide.
func _cote(t: TelemetrieGadgets, pid: int) -> Dictionary:
	return t.resume("", "", -1)["j1" if pid == 0 else "j2"]


## Le même, lu dans la télémétrie VIVANTE du jeu, sans attendre une archive.
func _cote_de(gs: Node, pid: int) -> Dictionary:
	return _cote(gs._telemetrie, pid)


## Un côté vierge tel que `resume()` le rend : `vierge()` et le slug vide.
func _vierge_resume() -> Dictionary:
	var d := TelemetrieGadgets.vierge()
	d["gadget"] = ""
	return d


func _memes_cles(a: Array, b: Array) -> bool:
	return _manquantes(a, b).is_empty() and _manquantes(b, a).is_empty() and a.size() == b.size()


## Ce qui est dans `a` et pas dans `b`.
func _manquantes(a: Array, b: Array) -> Array:
	var out: Array = []
	for x in a:
		if not b.has(x):
			out.append(x)
	return out


func _une_cle_contient(d: Dictionary, mot: String) -> bool:
	for k in d:
		if String(k).contains(mot):
			return true
		if d[k] is Dictionary and _une_cle_contient(d[k], mot):
			return true
	return false
