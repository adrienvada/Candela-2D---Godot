extends SceneTree

## Le son rendu visible, EN JEU : l'entonnoir d'`AudioManager`, `GameState` et les
## liserés des deux vues (chantier SON VISIBLE, 0.8.0, décisions d'Adrien du
## 2026-09-29). Le modèle seul est gardé par `test_son_visible.gd`.
##
## Ce qu'elle garde :
## - chaque famille dosée par l'audio a sa sorte ou se déclare muette, et les
##   ancres du modèle SONT les niveaux de l'audio (pas une copie qui dériverait) ;
## - l'entonnoir annonce chaque son au niveau que l'oreille reçoit — allure,
##   posture, duck sous le tir — même quand le pool n'a plus de voix ;
## - en écran scindé à 45° B, J1 voit les sons de J2 et jamais les siens, et
##   inversement ; **à situation miroir, les deux liserés sont identiques** —
##   largeur, force, et angle à l'écran, mesuré par la caméra de CHAQUE vue ;
## - rien pendant la killcam ni le décompte ; en vue unique, un seul liseré.
##
## Lancer : godot --headless --path . --script res://tools/test_son_visible_jeu.gd

const SV := preload("res://son_visible.gd")

var _failures := 0
var _verifications := 0
var _recus: Array[Dictionary] = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _noter(evenement: Dictionary) -> void:
	_recus.append(evenement)


func _run() -> void:
	print("=== SON RENDU VISIBLE — EN JEU ===")
	await process_frame
	var audio := root.get_node("AudioManager")
	var consts: Dictionary = audio.get_script().get_script_constant_map()
	_couverture(consts)
	_ancres_liees(consts)
	_entonnoir(audio, consts)
	await _en_jeu(audio)
	_sortir()


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# --- La table des sortes couvre l'audio ----------------------------------------------

func _couverture(consts: Dictionary) -> void:
	print("\n--- Chaque famille de l'audio a sa sorte ---")
	var familles := {}
	for fam in consts["NIVEAU_RELATIF"]:
		familles[String(fam)] = true
	for fam in consts["PORTEE_RELATIVE"]:
		familles[String(fam)] = true
	var orphelines: Array = []
	for fam in familles:
		if not (SV.CATEGORIE_DE_FAMILLE.has(fam) or SV.FAMILLES_MUETTES.has(fam)):
			orphelines.append(fam)
	_check("chaque famille dosée a sa sorte ou se déclare muette", orphelines.is_empty(), str(orphelines))
	var inconnues: Array = []
	for fam in SV.CATEGORIE_DE_FAMILLE:
		if not familles.has(String(fam)):
			inconnues.append(fam)
	_check("la table des sortes ne nomme que des familles de l'audio (une faute de frappe y serait muette)",
		inconnues.is_empty(), str(inconnues))


func _ancres_liees(consts: Dictionary) -> void:
	print("\n--- Les ancres du modèle sont les niveaux de l'audio ---")
	var niv: Dictionary = consts["NIVEAU_RELATIF"]
	for fam in ["footstep", "footstep_a", "footstep_b"]:
		_check("l'ancre nette (10°) est le niveau du pas : %s" % fam,
			is_equal_approx(float(niv[fam]), SV.NIVEAU_NET_DB), str(niv[fam]))
	_check("l'ancre floue (180°) est le pas accroupi",
		is_equal_approx(SV.NIVEAU_NET_DB + float(consts["PAS_ACCROUPI_DB"]), SV.NIVEAU_FLOU_DB))
	_check("un mur coûte au liseré ce qu'il coûte à l'oreille",
		is_equal_approx(float(consts["OCCLUSION_PENTE_DB"]), SV.PERTE_OCCLUSION_DB))
	_check("le pas lent debout reste au-dessus du pas accroupi (Q47)",
		SV.PAS_LENT_DB > float(consts["PAS_ACCROUPI_DB"]))


# --- L'entonnoir annonce ce que l'oreille reçoit ----------------------------------------

func _dernier() -> Dictionary:
	return _recus[_recus.size() - 1] if not _recus.is_empty() else {}


func _entonnoir(audio: Node, consts: Dictionary) -> void:
	print("\n--- L'entonnoir annonce chaque son localisé ---")
	audio.son_localise.connect(_noter)
	var pos := Vector2(300, 300)

	_recus.clear()
	var voix: AudioStreamPlayer2D = audio.play_footstep(pos, Vector2i(0, 0), false, 1.0, 1)
	_check("un pas s'annonce, une fois", _recus.size() == 1, str(_recus.size()))
	var ev := _dernier()
	if not ev.is_empty():
		_check("… sous la famille du damier", ["footstep_a", "footstep"].has(String(ev["famille"])), String(ev["famille"]))
		_check("… avec son émetteur", int(ev["emetteur"]) == 1)
		_check("… au niveau du pas de course", is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_NET_DB),
			str(ev["niveau_db"]))
		_check("… à la portée de sa famille",
			is_equal_approx(float(ev["portee"]), audio.portee_courante(String(ev["famille"]))))
		if voix != null:
			_check("la voix joue au niveau annoncé (ni mur ni fumée ici)",
				is_equal_approx(voix.volume_db, float(ev["niveau_db"])), "%s / %s" % [voix.volume_db, ev["niveau_db"]])
			_check("la voix porte à la portée annoncée", is_equal_approx(voix.max_distance, float(ev["portee"])))

	_recus.clear()
	var bas: AudioStreamPlayer2D = audio.play_footstep(pos, Vector2i(1, 0), true, 1.0, 1)
	ev = _dernier()
	_check("le pas accroupi s'annonce au niveau accroupi",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_FLOU_DB), str(ev.get("niveau_db")))
	_check("… et à la moitié de sa portée",
		not ev.is_empty() and is_equal_approx(float(ev["portee"]),
			audio.portee_courante(String(ev["famille"])) * float(consts["PAS_ACCROUPI_PORTEE"])))
	if bas != null and not ev.is_empty():
		_check("la voix accroupie joue ce qui est annoncé (MB2 inchangé)",
			is_equal_approx(bas.volume_db, float(ev["niveau_db"])) and is_equal_approx(bas.max_distance, float(ev["portee"])))

	_recus.clear()
	audio.play_footstep(pos, Vector2i(0, 0), false, 0.5, 1)
	ev = _dernier()
	_check("le pas à mi-stick s'annonce plus bas (Q47)",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_NET_DB + SV.ecart_allure_db(0.5)),
		str(ev.get("niveau_db")))
	_recus.clear()
	audio.play_footstep(pos, Vector2i(0, 0), true, 0.2, 1)
	ev = _dernier()
	_check("accroupi, l'allure n'ajoute rien : la posture est déjà le minimum",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_FLOU_DB))

	_recus.clear()
	audio.play_percuteur("pistolet", pos, 0)
	ev = _dernier()
	_check("le percuteur s'annonce, avec son émetteur",
		not ev.is_empty() and String(ev["famille"]) == "weapon_dry" and int(ev["emetteur"]) == 0)

	_recus.clear()
	audio.play_weapon_shot("pistolet", pos, 0)
	ev = _dernier()
	_check("le tir s'annonce au plus fort", not ev.is_empty() and String(ev["famille"]) == "shoot"
		and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_FORT_DB))
	_recus.clear()
	audio.play_footstep(pos, Vector2i(0, 0), false, 1.0, 1)
	ev = _dernier()
	_check("le pas juste après un tir s'annonce au niveau que l'oreille entend (duck V4.15)",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]),
			SV.NIVEAU_NET_DB + float(consts["DUCK_TIR_DB"])), str(ev.get("niveau_db")))

	_recus.clear()
	audio.annoncer_son_2d("fusee_combustion", pos)
	ev = _dernier()
	_check("la combustion (voix dédiée) s'annonce par sa propre porte",
		not ev.is_empty() and String(ev["famille"]) == "fusee_combustion" and int(ev["emetteur"]) == -1
		and is_equal_approx(float(ev["niveau_db"]), float(consts["NIVEAU_RELATIF"]["fusee_combustion"])))

	# Pool plein de sons plus prioritaires : le pas n'a pas de voix, mais il a eu lieu.
	for i in 16:
		audio.play_sfx_2d("hit_center", pos)
	_recus.clear()
	var sans_voix: AudioStreamPlayer2D = audio.play_footstep(pos, Vector2i(0, 0), false, 1.0, 1)
	if sans_voix == null:
		_check("pool plein : le pas sans voix s'annonce quand même", _recus.size() == 1)
	else:
		print("  (pool jamais plein ici : le cas « sans voix » n'a pas pu être joué)")
	audio.son_localise.disconnect(_noter)


# --- En jeu : deux vues, deux joueurs -------------------------------------------------

func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	return true


func _vider(vues: Array) -> void:
	for v in vues:
		v.vider()


func _en_jeu(audio: Node) -> void:
	print("\n--- En jeu : écran scindé à 45° B ---")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(main))
	await process_frame
	var vues: Array = main._sons_vues
	_check("deux liserés, un par vue", vues.size() == 2)
	if vues.size() != 2:
		return
	_check("scindé : les deux liserés sont dans l'arbre", vues[0].get_parent() != null and vues[1].get_parent() != null)
	_check("chaque liseré porte la couche de SON joueur",
		vues[0].get("couche_vue") == GadgetBase.couche_de_vue(0) and vues[1].get("couche_vue") == GadgetBase.couche_de_vue(1))
	var p1: Node2D = main.p1
	var p2: Node2D = main.p2
	var reglages := root.get_node("GameSettings")
	_check("le lacet de J2 est celui de J1 plus 180° (45° B)",
		is_equal_approx(fposmod(float(main.lacet_de_la_vue(1)) - float(main.lacet_de_la_vue(0)), 360.0), 180.0)
		or not bool(reglages.mode_iso))

	# Deux points miroir : J2 entend J1 à −d quand J1 entend J2 à +d.
	var a := p1.global_position
	p2.global_position = a + Vector2(180, -60)
	_vider(vues)
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("J1 voit le pas de J2", vues[0].traces_vivantes() == 1, str(vues[0].traces_vivantes()))
	_check("J2 ne voit pas son propre pas", vues[1].traces_vivantes() == 0)
	audio.play_footstep(p1.global_position, Vector2i(0, 0), false, 1.0, 0)
	_check("J2 voit le pas de J1", vues[1].traces_vivantes() == 1, str(vues[1].traces_vivantes()))
	_check("J1 ne voit pas son propre pas", vues[0].traces_vivantes() == 1)
	if vues[0].traces_vivantes() == 1 and vues[1].traces_vivantes() == 1:
		var t1: Dictionary = vues[0].traces()[0]
		var t2: Dictionary = vues[1].traces()[0]
		_check("équité : même largeur (%.2f° / %.2f°)" % [t1["largeur"], t2["largeur"]],
			is_equal_approx(float(t1["largeur"]), float(t2["largeur"])))
		_check("équité : même force", is_equal_approx(float(t1["alpha"]), float(t2["alpha"])))
		_check("équité : à situation miroir, même angle à l'écran (%.2f° / %.2f°)"
			% [rad_to_deg(t1["angle"]), rad_to_deg(t2["angle"])],
			absf(angle_difference(float(t1["angle"]), float(t2["angle"]))) < 0.01)
		_check("le pas de course à 190 px reste précis (%.1f°)" % t1["largeur"], float(t1["largeur"]) < 60.0)
		_check("la couleur des pas", t1["couleur"] == SV.couleur(SV.Categorie.PAS))
		var pres := root.get_node_or_null("Presentation3D")
		if pres != null and bool(reglages.mode_iso):
			_check("J1 : l'angle est celui de SA caméra",
				absf(angle_difference(float(t1["angle"]), pres.angle_ecran(0, p1.global_position, p2.global_position))) < 0.01)
			_check("J2 : l'angle est celui de SA caméra",
				absf(angle_difference(float(t2["angle"]), pres.angle_ecran(1, p2.global_position, p1.global_position))) < 0.01)

	# Le tir de J1, à la bouche de son arme : jamais chez lui, chez l'autre en blanc chaud.
	_vider(vues)
	audio.play_weapon_shot("pistolet", p1.global_position + Vector2(40, 0), 0)
	_check("J1 ne voit pas son propre tir, même à 40 px de lui", vues[0].traces_vivantes() == 0)
	_check("J2 voit le tir de J1, en blanc chaud",
		vues[1].traces_vivantes() == 1 and vues[1].traces()[0]["couleur"] == SV.couleur(SV.Categorie.TIR))

	# Tout près, accroupi : un bruissement, presque sans direction.
	_vider(vues)
	p2.global_position = a + Vector2(40, 0)
	audio.play_footstep(p2.global_position, Vector2i(0, 0), true, 1.0, 1)
	if vues[0].traces_vivantes() == 1:
		var t: Dictionary = vues[0].traces()[0]
		_check("le pas accroupi tout près : très large (%.0f°) et très léger (%.2f)" % [t["largeur"], t["alpha"]],
			float(t["largeur"]) > 150.0 and float(t["alpha"]) < 0.2)
	else:
		_check("le pas accroupi tout près dessine un liseré", false)

	# Le dessin passe sans erreur (le lanceur rougit sur toute SCRIPT ERROR).
	audio.play_footstep(p2.global_position + Vector2(200, 200), Vector2i(0, 0), false, 1.0, 1)
	await process_frame
	await process_frame

	# S6 — les bruits de corps de l'hôte, tels que le client les reçoit.
	print("\n--- S6 : les bruits de corps de l'hôte arrivent chez le client ---")
	var reseau := root.get_node("NetworkManager")
	var modes: Dictionary = reseau.get_script().get_script_constant_map()["GameMode"]
	_check("l'hôte envoie les bruits de SON joueur, en ligne",
		p1.bruit_a_repliquer(int(modes["ONLINE_HOST"]), 0, true))
	_check("… jamais ceux du joueur du client (le client le prédit)",
		not p1.bruit_a_repliquer(int(modes["ONLINE_HOST"]), 1, true))
	_check("… jamais depuis le client",
		not p1.bruit_a_repliquer(int(modes["ONLINE_CLIENT"]), 0, true))
	_check("… jamais en écran partagé ni sans pair",
		not p1.bruit_a_repliquer(int(modes["LOCAL_SPLITSCREEN"]), 0, true)
		and not p1.bruit_a_repliquer(int(modes["ONLINE_HOST"]), 0, false))
	_vider(vues)
	p2.global_position = a + Vector2(180, -60)
	var genres: Dictionary = p1.get_script().get_script_constant_map()["BruitDeCorps"]
	p1.rpc_bruit_de_corps(int(genres["RECHARGE"]), "pistolet", a + Vector2(8, 0))
	_check("le rechargement de J1 reçu : J2 le voit, en acier",
		vues[1].traces_vivantes() == 1 and vues[1].traces()[0]["couleur"] == SV.couleur(SV.Categorie.RECHARGE))
	_check("… et J1 ne voit pas le sien", vues[0].traces_vivantes() == 0)
	p1.rpc_bruit_de_corps(int(genres["FROLEMENT"]), "", a)
	_check("le frôlement de J1 reçu : J2 le voit",
		vues[1].traces_vivantes() == 2 and vues[1].traces()[1]["couleur"] == SV.couleur(SV.Categorie.FROLEMENT))
	# Q54 — le clic à vide de l'hôte, relayé comme les autres bruits de corps.
	p1.rpc_bruit_de_corps(int(genres["PERCUTEUR"]), "pistolet", a + Vector2(20, 0))
	_check("le clic à vide de J1 reçu : J2 le voit (Q54)",
		vues[1].traces_vivantes() == 3 and vues[1].traces()[2]["couleur"] == SV.couleur(SV.Categorie.PERCUTEUR))

	# Fermé : décompte, puis killcam.
	_vider(vues)
	main.countdown_left = 1.0
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("pendant le décompte : aucun liseré", vues[0].traces_vivantes() == 0)
	main.countdown_left = 0.0
	var rejeu := root.get_node("ReplaySystem")
	rejeu.playing_back = true
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("pendant la killcam : aucun liseré", vues[0].traces_vivantes() == 0)
	rejeu.playing_back = false
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("rouvert : le liseré revient", vues[0].traces_vivantes() == 1)
	rejeu.playing_back = true
	await process_frame
	_check("la killcam efface les liserés déjà là", vues[0].traces_vivantes() == 0)
	rejeu.playing_back = false

	# Vue unique : un seul liseré dans l'arbre, celui de J1.
	print("\n--- Vue unique ---")
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()
	await process_frame
	_check("vue unique : le liseré de J1 est dans l'arbre", vues[0].get_parent() != null)
	_check("vue unique : celui de J2 est retiré", vues[1].get_parent() == null)
	_vider(vues)
	p2.global_position = a + Vector2(180, -60)
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("vue unique : J1 voit toujours le pas de J2", vues[0].traces_vivantes() == 1)
	main.vp2.get_parent().show()
	main._accorder_rendu_aux_vues()
	await process_frame
