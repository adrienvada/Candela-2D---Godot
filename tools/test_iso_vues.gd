## Les vues et les canaux de la vue isométrique (ISO2) — et leurs aller-retours.
##
## Sans rien rendre :
##   • **écran scindé** : deux sous-vues 3D partageant le `World3D` de la racine, une
##     caméra et un sol par joueur, murs et corps communs sur le calque 1, chaque caméra
##     avec son `cull_mask` ; les deux lightmaps gardent leurs masques réels (`~4` / `~2`,
##     `game_state.gd` fait foi) moins la couche des capteurs ;
##   • **les capteurs de corps** : un par vue regardée et par corps, dans le `World2D` du
##     duel, ne lisant que leur couche, portant le masque de lumière du sprite qu'ils
##     remplacent — miroir entre J1 et J2 ;
##   • **les canaux** : rien de ce qu'une lightmap dessine ne reçoit le canal de vue de
##     l'autre joueur (le halo de J2 n'écrit rien chez J1), ni dans les capteurs ;
##   • **les effets d'écran suivent la vue** : calques (vignette, flash de mort) et
##     brouillage de chaque joueur logés dans SON viewport 3D, jamais dans la lightmap ;
##   • **l'audio** : exactement un viewport auditeur du monde du duel par joueur devant
##     l'écran (deux en scindé, un en vue unique), jamais la racine, jamais une vue iso ;
##   • **aller-retour** scindé → unique (la killcam cache une vue) → scindé → gel du kill
##     → 2D → iso → nouvelle manche : monde, masques, caméras, tailles, calques,
##     brouillage et auditeur restaurés à l'identique, sans erreur console ;
##   • **la simulation** identique pas pour pas avec ou sans iso en écran scindé (la vue
##     unique est prouvée par `test_iso_camera.gd`), avec un témoin ;
##   • le réglage de lightmap (`plein` / `1080p`, `--lightmap`), `mode_iso` faux par défaut.
##
## Ce qu'elle ne voit pas : ce que le GPU met dans les lightmaps et les capteurs. Ça se
## prouve au banc, dans une vraie fenêtre (`tools/banc_iso.gd --jeu --scinde --noir`, et la
## planche « torche de J1 seule / torche de J2 seule »).
##
## Lancer : godot --headless --path . --script res://tools/test_iso_vues.gd
extends SceneTree

const PLANCHER := 90
const PAS_SIMULES := 120

var _failures := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== LES VUES ET LES CANAUX DE LA VUE ISO, ET LEURS ALLER-RETOURS ===")
	await process_frame
	var Reglages: GDScript = load("res://settings_manager.gd")
	var Pres: GDScript = load("res://presentation_3d.gd")
	var Canaux: GDScript = load("res://canaux_lumiere.gd")
	var reglages := root.get_node("GameSettings")
	var audio := root.get_node_or_null("AudioManager")
	_check("mode_iso est faux par défaut (lot lancé sans --iso)", reglages.mode_iso == false)
	_check("la lightmap est en 1080p par défaut", reglages.iso_lightmap == "1080p")
	_statiques(Reglages, Pres, Canaux)

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var vp1: SubViewport = main.vp1
	var vp2: SubViewport = main.vp2
	var c1 := vp1.get_parent() as SubViewportContainer
	var c2 := vp2.get_parent() as SubViewportContainer
	var avant := {
		"masque1": vp1.canvas_cull_mask, "masque2": vp2.canvas_cull_mask,
		"souris1": c1.mouse_filter, "souris2": c2.mouse_filter,
		"monde_racine": root.world_2d,
	}

	# --- Sans iso, le témoin : une partie locale, écran scindé, vue de dessus -------
	main.ui._intended_mode = NetworkManager_mode_local()
	main._on_replay_requested()
	_check("la première manche scindée démarre", await _depart_fini(main))
	var temoin_a: Dictionary = await _jouer(main)
	_check("la manche du témoin démarre", await _nouvelle_manche(main))
	var temoin_b: Dictionary = await _jouer(main)
	_check("témoin : deux parties scindées sans iso sont identiques pas pour pas",
		_ecarts(temoin_a["etats"], temoin_b["etats"]) == 0,
		_premier_ecart(temoin_a["etats"], temoin_b["etats"]))
	_check("sans iso : aucune Presentation3D dans l'arbre", root.get_node_or_null("Presentation3D") == null)
	_check("sans iso : les masques vivants sont ~4 et ~2",
		vp1.canvas_cull_mask == (~4 & 0xFFFFFFFF) and vp2.canvas_cull_mask == (~2 & 0xFFFFFFFF))
	var taille1_avant := vp1.size
	var taille2_avant := vp2.size

	# --- Écran scindé en iso -------------------------------------------------
	reglages.mode_iso = true
	_check("la manche iso démarre", await _nouvelle_manche(main))
	await process_frame
	await process_frame
	var p := root.get_node_or_null("Presentation3D")
	_check("le crochet de rebuild_arena a posé /root/Presentation3D", p != null)
	if p == null:
		_sortir()
		return
	_check("elle est allumée en ÉCRAN SCINDÉ", bool(p.get("_actif")) and bool(p.get("_scinde")))
	print("\n--- Écran scindé : deux vues 3D, un monde, une caméra et un sol par joueur ---")
	_scinde(main, p, Canaux)
	_canaux(main, p, Canaux)
	_effets_suivent_la_vue(main, p, true)
	_auditeurs(main, p, audio, [vp1, vp2], "scindé")
	_check("une manche neuve pour la comparaison, vue iso allumée", await _nouvelle_manche(main))
	await process_frame
	var avec: Dictionary = await _jouer(main)
	_check("la simulation scindée est identique pas pour pas avec la vue iso allumée",
		_ecarts(temoin_a["etats"], avec["etats"]) == 0, _premier_ecart(temoin_a["etats"], avec["etats"]))
	_check("pendant la partie, la vue iso tenait (allumée, scindée)", bool(avec["iso"]))
	var f3: String = p.etat
	_check("F3 dit, par vue, le mode, le masque, la lightmap et le rendu",
		f3.contains("scindé") and f3.contains("J1 : masque ~4 sans capteurs") and f3.contains("J2 : masque ~2 sans capteurs")
		and f3.contains("lightmap") and f3.contains("rendu"), f3)

	# --- Vue unique en cours de partie : la killcam cache la vue de J2 ----------
	print("\n--- Aller-retour : scindé → unique (killcam) → scindé ---")
	c2.hide()
	main._accorder_rendu_aux_vues()
	# ⚠️ Quatre images, pas deux : l'aire de la vue passe de 957 à 1920 et la caméra 2D met
	# une image à se recentrer ; la caméra 3D, qui la lit, en met une de plus. Juste après la
	# bascule, les deux s'écartaient de la demi-différence des aires (481 px au monde).
	for i in 4:
		await process_frame
	_check("vue unique : la vue iso s'est rallumée sur la seule vue de J1",
		bool(p.get("_actif")) and not bool(p.get("_scinde")) and (p.get("_vues") as Array) == [vp1])
	_check("une bascule comptée", int(p.bascules) == 1, str(p.bascules))
	_unique(main, p, 0)
	_effets_suivent_la_vue(main, p, false)
	_check("vue unique : l'interface sait que les deux vues ne sont plus affichées",
		not main.ui._deux_vues_affichees())
	_check("vue unique : le voile de J2 ne se pose plus sur la moitié droite de l'écran de J1",
		not (main.ui.p2_dazzle as CanvasItem).visible)
	audio.poser_oreille(main.p1)
	_auditeurs(main, p, audio, [vp1], "unique")
	c2.show()
	main._accorder_rendu_aux_vues()
	await process_frame
	await process_frame
	_check("retour : écran scindé de nouveau, deuxième bascule",
		bool(p.get("_scinde")) and int(p.bascules) == 2)
	_check("retour : le voile de J2 retrouve sa moitié d'écran", (main.ui.p2_dazzle as CanvasItem).visible)
	_scinde(main, p, Canaux)
	_effets_suivent_la_vue(main, p, true)
	main._accorder_oreille()
	_auditeurs(main, p, audio, [vp1, vp2], "scindé, au retour")

	# --- Le gel du kill : les lightmaps s'arrêtent, la 3D avec elles -------------
	print("\n--- Le gel du kill ---")
	vp1.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await process_frame
	var gelees := 0
	for id in 2:
		if (p.get("_vues3d")[id] as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED:
			gelees += 1
		for j in 2:
			if (p.capteurs()[id][j] as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED:
				gelees += 1
	_check("lightmaps arrêtées : les deux vues 3D et les quatre capteurs s'arrêtent avec elles (%d/6)"
		% gelees, gelees == 6)
	_check("et la vue iso ne les a PAS relancées (le gel est voulu)",
		vp1.render_target_update_mode == SubViewport.UPDATE_DISABLED
		and vp2.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	main._accorder_rendu_aux_vues()
	await process_frame
	var reprises := 0
	for id in 2:
		if (p.get("_vues3d")[id] as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			reprises += 1
	_check("l'accord du jeu rallume les lightmaps, et la 3D repart (%d/2)" % reprises,
		reprises == 2 and vp1.render_target_update_mode == SubViewport.UPDATE_ALWAYS)

	# --- La taille de la lightmap ------------------------------------------------
	print("\n--- La taille de la lightmap : plein / 1080p ---")
	var logique := Vector2i(c1.get_global_rect().size.round())
	_check("1080p : la lightmap de J1 a l'aire logique de son conteneur (%s)" % str(vp1.size),
		vp1.size == logique and vp1.size_2d_override == logique and vp1.size_2d_override_stretch)
	reglages.iso_lightmap = "plein"
	await process_frame
	var attendu: Vector2i = Pres.taille_lightmap("plein", logique, p._etirement())
	# Sans fenêtre l'étirement vaut 1 : `plein` et `1080p` ont ici la même taille, et la
	# différence ne se voit qu'au banc (qui imprime les deux). Ce qui se prouve headless :
	# la variante est lue, la formule appliquée, l'aire 2D reste logique.
	_check("plein : la variante est appliquée à la lightmap (%s, étirement ×%.2f), aire 2D logique"
		% [str(attendu), p._etirement()], p.variante_lightmap() == "plein" and vp1.size == attendu
		and vp1.size_2d_override == logique)
	# ⚠️ Godot REFUSE de changer la taille d'une sous-vue dont le conteneur est en `stretch`
	# (un simple avertissement) : sans ceci, `plein` restait `1080p` en silence.
	_check("plein : les conteneurs ont lâché stretch, hors de la mise en page (top_level)",
		not c1.stretch and not c2.stretch and c1.top_level and c2.top_level)
	reglages.iso_lightmap = "1080p"
	await process_frame
	_check("et revient en 1080p, stretch rendu aux conteneurs",
		vp1.size == logique and p.variante_lightmap() == "1080p" and c1.stretch and c2.stretch)
	# Le conteneur (`stretch`) réécrit la taille de sa vue à chaque redimensionnement de
	# fenêtre ; la vue iso doit la reposer, et le compter.
	var reposees_avant: int = p.lightmaps_reposees
	c1.size = Vector2(320, 180)
	await process_frame
	_check("un conteneur déplacé de son cadre est reposé par la vue iso, et compté",
		vp1.size == logique and c1.size.is_equal_approx(Vector2(logique))
		and p.lightmaps_reposees == reposees_avant + 1,
		"%s, %d reposée(s)" % [str(vp1.size), p.lightmaps_reposees - reposees_avant])

	# --- Retour à la vue de dessus, en cours de partie ---------------------------
	print("\n--- Aller-retour : iso → 2D → iso → nouvelle manche ---")
	reglages.mode_iso = false
	await process_frame
	await process_frame
	_check("2D : la vue iso est éteinte", not bool(p.get("_actif")) and (p.get("_vues") as Array).is_empty())
	_check("2D : les conteneurs sont opaques et reçoivent la souris",
		c1.modulate.a == 1.0 and c2.modulate.a == 1.0
		and c1.mouse_filter == avant["souris1"] and c2.mouse_filter == avant["souris2"])
	_check("2D : les conteneurs sont revenus dans la mise en page, en stretch",
		not c1.top_level and not c2.top_level and c1.stretch and c2.stretch)
	_check("2D : les sous-vues ont retrouvé leur taille et leur aire (%s, %s)" % [str(vp1.size), str(vp2.size)],
		vp1.size == taille1_avant and vp2.size == taille2_avant
		and vp1.size_2d_override == Vector2i.ZERO and vp2.size_2d_override == Vector2i.ZERO)
	_check("2D : les masques sont EXACTEMENT ~4 et ~2 (la couche des capteurs rendue)",
		vp1.canvas_cull_mask == avant["masque1"] and vp2.canvas_cull_mask == avant["masque2"],
		"%d / %d" % [vp1.canvas_cull_mask, vp2.canvas_cull_mask])
	_check("2D : le fond est visible, le rendu par la racine autorisé, et le scindé rend dans ses sous-vues",
		(main.get_node("Background") as CanvasItem).visible and main.rendu_racine_autorise and not main._rendu_racine)
	_check("2D : les vingt sprites de corps ont retrouvé leurs couches",
		_sprites_sur(main.p1, 2, 4) == 10 and _sprites_sur(main.p2, 4, 2) == 10)
	_check("2D : plus aucun capteur", _capteurs_vivants(p) == 0)
	_check("2D : les vues 3D sont arrêtées et leurs affichages cachés",
		_vues3d_arretees(p))
	_check("2D : les calques d'écran sont revenus dans les sous-vues de leurs joueurs",
		_calques_sous(main.p1, vp1) and _calques_sous(main.p2, vp2))
	_check("2D : les appareils de brouillage sont revenus dans leurs sous-vues, sans projecteur",
		(main._brouillages[0] as Node).get_parent() == vp1 and (main._brouillages[1] as Node).get_parent() == vp2
		and not (main._brouillages[0].projecteur as Callable).is_valid())
	_check("2D : la racine a son propre monde 2D", root.world_2d == avant["monde_racine"])
	_check("2D : aucun nœud 3D sous GameState ni sous Player*", _noeuds_3d_sous(main) == 0)
	main._accorder_oreille()
	_auditeurs(main, p, audio, [vp1, vp2], "2D")

	reglages.mode_iso = true
	await process_frame
	await process_frame
	_check("iso de nouveau : rallumée en scindé, capteurs et vues 3D reposés",
		bool(p.get("_actif")) and bool(p.get("_scinde")) and _capteurs_vivants(p) == 4)
	_scinde(main, p, Canaux)

	# Entre deux manches : la killcam laisse une vue, la manche suivante remontre les deux.
	c2.hide()
	main._accorder_rendu_aux_vues()
	await process_frame
	await process_frame
	_check("fin de manche : vue unique", not bool(p.get("_scinde")) and _capteurs_vivants(p) == 2)
	main._restore_viewports()
	await process_frame
	await process_frame
	_check("manche suivante : _restore_viewports() remontre les deux vues, l'iso repasse en scindé",
		bool(p.get("_scinde")) and _capteurs_vivants(p) == 4 and c1.visible and c2.visible)
	_check("aucun nœud 3D sous GameState ni sous Player*, en scindé", _noeuds_3d_sous(main) == 0)

	# Le retour au menu, par le vrai chemin : il remontre les DEUX vues derrière le hub.
	print("\n--- Retour au menu ---")
	main._on_main_menu_requested()
	await process_frame
	await process_frame
	_check("menu : la vue iso s'éteint, les deux vues remontrées ne la rallument pas en scindé",
		not bool(p.get("_actif")) and _capteurs_vivants(p) == 0 and _vues3d_arretees(p))
	_check("menu : masques, fond et rendu racine rendus au jeu",
		vp1.canvas_cull_mask == avant["masque1"] and vp2.canvas_cull_mask == avant["masque2"]
		and (main.get_node("Background") as CanvasItem).visible and main.rendu_racine_autorise
		and not main._rendu_racine)
	_check("menu : la racine a son propre monde 2D", root.world_2d == avant["monde_racine"])

	# Extinction propre : tout rendu, puis Main libéré.
	reglages.mode_iso = false
	await process_frame
	await process_frame
	_check("extinction finale : masques rendus, capteurs retirés",
		vp1.canvas_cull_mask == avant["masque1"] and _capteurs_vivants(p) == 0)
	main.queue_free()
	await process_frame
	await process_frame

	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	_sortir()


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------

func _statiques(Reglages: GDScript, Pres: GDScript, Canaux: GDScript) -> void:
	print("\n--- Les formules, sans le jeu ---")
	_check("« --lightmap plein » est reconnu", Reglages.lightmap_par_argument(PackedStringArray(["--lightmap", "plein"])) == "plein")
	_check("« --lightmap 1080p » aussi", Reglages.lightmap_par_argument(PackedStringArray(["--lightmap", "1080p"])) == "1080p")
	_check("une variante inconnue est ignorée", Reglages.lightmap_par_argument(PackedStringArray(["--lightmap", "demi"])) == "")
	_check("son absence aussi", Reglages.lightmap_par_argument(PackedStringArray(["--iso"])) == "")
	_check("plein : l'aire logique fois l'étirement (957×1080 ×1,333 = 1276×1440)",
		Pres.taille_lightmap("plein", Vector2i(957, 1080), 1440.0 / 1080.0) == Vector2i(1276, 1440))
	_check("1080p : l'aire logique telle quelle",
		Pres.taille_lightmap("1080p", Vector2i(957, 1080), 1440.0 / 1080.0) == Vector2i(957, 1080))
	# ⚠️ UNE couche PAR capteur (retour d'Adrien au jalon H-ISO2) : les quatre disques partagent le
	# monde 2D du duel, et sur une couche commune chaque capteur voyait aussi le disque posé sur
	# le même corps par l'autre vue. Créés en dernier, ceux de J2 recouvraient ceux de J1 : en
	# écran scindé, J1 voyait les corps avec les canaux de J2.
	var couches_capteurs: Array[int] = [Pres.couche_capteur(0, 0), Pres.couche_capteur(0, 1),
		Pres.couche_capteur(1, 0), Pres.couche_capteur(1, 1)]
	var union := 0
	var disjointes := true
	for c in couches_capteurs:
		if c <= 0 or (c & (c - 1)) != 0 or (c & (1 | 2 | 4)) != 0 or (union & c) != 0:
			disjointes = false
		union |= c
	_check("une couche PAR capteur : quatre bits distincts, ni 1, ni 2, ni 4 — ni la couche 0 des sprites retirés",
		disjointes and union == int(Pres.COUCHES_CAPTEURS) and int(Pres.COUCHE_HORS_VUE) == 0, str(couches_capteurs))
	_check("masque du capteur de SON corps : JOUEUR_LOCAL",
		Pres.masque_capteur(0, 0) == Canaux.JOUEUR_LOCAL and Pres.masque_capteur(1, 1) == Canaux.JOUEUR_LOCAL)
	_check("masque du capteur du corps d'EN FACE : masque_vue_adverse, miroir entre J1 et J2",
		Pres.masque_capteur(0, 1) == Canaux.masque_vue_adverse(1) and Pres.masque_capteur(0, 1) == (2 | 16)
		and Pres.masque_capteur(1, 0) == Canaux.masque_vue_adverse(0) and Pres.masque_capteur(1, 0) == (2 | 32))
	# La courbe des disques (jalon H-ISO2) : un capteur reçoit la lumière comme le sprite qu'il
	# remplace. Les shaders des disques sont des MIROIRS de ceux des sprites, comparés ici.
	var adverse := _lumiere_du_shader("res://capteur_adverse.gdshader")
	var locale := _lumiere_du_shader("res://capteur_local.gdshader")
	_check("le disque d'un corps d'en face reçoit la lumière comme le sprite ennemi (light() miroir de player_enemy_light)",
		adverse != "" and adverse == _lumiere_du_shader("res://player_enemy_light.gdshader"), adverse)
	_check("le disque de son propre corps la reçoit comme le sprite du joueur (light() miroir de player_rim_light)",
		locale != "" and locale == _lumiere_du_shader("res://player_rim_light.gdshader"), locale)
	_check("les deux disques sont en « lumière seule » : zéro sans lumière",
		FileAccess.get_file_as_string("res://capteur_adverse.gdshader").contains("render_mode light_only;")
		and FileAccess.get_file_as_string("res://capteur_local.gdshader").contains("render_mode light_only;"))

	# ISO2b — la composition du corps (miroir processeur du shader) : fondu vers ce qui est derrière,
	# silhouette de soi par-dessus, noir absolu à toute opacité.
	var gris := Color(0.75, 0.69, 0.61)
	var sol := Color(0.4, 0.3, 0.2)
	var vide := Color(0.0, 0.0, 0.0, 0.0)
	var c0: Color = Pres.composer_corps(gris, 0.0, vide)
	_check("ISO2b : à opacité 0, le corps ne recouvre rien — la vue montre ce qu'il y a derrière", c0.a == 0.0, str(c0))
	var c1: Color = Pres.composer_corps(gris, 1.0, vide)
	_check("ISO2b : à opacité 1, le corps est tel quel", c1.a == 1.0 and Color(c1.r, c1.g, c1.b).is_equal_approx(gris), str(c1))
	var cm: Color = Pres.composer_corps(gris, 0.65, vide)
	_check("ISO2b : à opacité 0,65, le fondu vers le sol est celui du sprite 2D (le mélange sol-corps à 0,65), pas un assombrissement",
		sol.lerp(Color(cm.r, cm.g, cm.b), cm.a).is_equal_approx(sol.lerp(gris, 0.65)), str(cm))
	var cn: Color = Pres.composer_corps(Color.BLACK, 0.3, vide)
	_check("ISO2b : noir absolu à toute opacité — un corps sans lumière ne rend aucune lumière", cn.r == 0.0 and cn.g == 0.0 and cn.b == 0.0, str(cn))
	var teinte := Color(0.2, 0.8, 0.9)
	var cs: Color = Pres.composer_corps(Color.BLACK, 1.0, Color(teinte.r, teinte.g, teinte.b, 0.5))
	_check("ISO2b : son corps dans le noir vaut la moitié de sa couleur, comme la silhouette 2D sur le sprite noir",
		is_equal_approx(cs.a, 1.0) and Color(cs.r, cs.g, cs.b).is_equal_approx(Color(teinte.r * 0.5, teinte.g * 0.5, teinte.b * 0.5)), str(cs))
	var source_corps := FileAccess.get_file_as_string("res://corps_grossier_iso.gdshader")
	_check("ISO2b : le shader du corps compose comme son miroir, en valeurs affichées, et se fond (blend_mix, ALPHA)",
		source_corps.contains("float a = 1.0 - (1.0 - o) * (1.0 - s);")
		and source_corps.contains("ALBEDO = (corps * o * (1.0 - s) + silhouette.rgb * s) / a;")
		and source_corps.contains("blend_mix") and source_corps.contains("ALPHA = a;"))
	var source_profondeur := FileAccess.get_file_as_string("res://corps_profondeur_iso.gdshader")
	_check("ISO2b : la passe de profondeur suit la même règle d'opacité, n'écrit aucune couleur, et rien à opacité nulle",
		source_profondeur.contains("float a = 1.0 - (1.0 - o) * (1.0 - s);") and source_profondeur.contains("ALPHA = 0.0;")
		and source_profondeur.contains("discard;") and source_profondeur.contains("depth_draw_always"))

	# Le réglage, persisté séparément de ce qui s'applique — comme `mode_iso`.
	var chemin := "user://test_iso_vues_reglages.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
	var neuf: Node = Reglages.new()
	neuf._settings_path = chemin
	neuf._load()
	_check("installation neuve : lightmap 1080p", neuf.iso_lightmap_choisi() == "1080p" and neuf.iso_lightmap == "1080p")
	neuf.set_iso_lightmap("plein")
	var cfg := ConfigFile.new()
	cfg.load(chemin)
	_check("le choix « plein » s'enregistre dans la section vidéo", cfg.get_value("video", "iso_lightmap", "") == "plein")
	var relu: Node = Reglages.new()
	relu._settings_path = chemin
	relu._load()
	_check("et se relit au lancement suivant", relu.iso_lightmap_choisi() == "plein")
	relu.set_iso_lightmap("demi")
	_check("une variante inconnue retombe sur 1080p", relu.iso_lightmap_choisi() == "1080p")
	cfg.set_value("video", "iso_lightmap", 12)
	cfg.save(chemin)
	var trafique: Node = Reglages.new()
	trafique._settings_path = chemin
	trafique._load()
	_check("une valeur trafiquée retombe sur 1080p", trafique.iso_lightmap_choisi() == "1080p")
	for n in [neuf, relu, trafique]:
		n.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))


func _scinde(main: Node, p: Node, Canaux: GDScript) -> void:
	var vp1: SubViewport = main.vp1
	var vp2: SubViewport = main.vp2
	var vues3d: Array = p.get("_vues3d")
	var cams: Array = p.get("_cameras3d")
	var affichages: Array = p.get("_affichages")
	for id in 2:
		var vue := vues3d[id] as SubViewport
		_check("VueIso%d dessine, partage le World3D de la racine, et n'est pas dans le monde 2D du duel" % (id + 1),
			vue.render_target_update_mode == SubViewport.UPDATE_ALWAYS and vue.find_world_3d() == root.find_world_3d()
			and not vue.own_world_3d and vue.world_2d != vp1.world_2d)
		_check("VueIso%d n'écoute rien" % (id + 1), not vue.is_audio_listener_2d() and not vue.is_audio_listener_3d())
		_check("VueIso%d rend aux pixels de la fenêtre sur le cadre de son conteneur, aire logique à part" % (id + 1),
			vue.size == Vector2i((_cadre(main, id).size * p._etirement()).round())
			and vue.size_2d_override == Vector2i(_cadre(main, id).size.round()) and vue.size_2d_override_stretch
			and (affichages[id] as Control).visible and (affichages[id] as Control).position == _cadre(main, id).position)
		var cam := cams[id] as Camera3D
		_check("CameraIso%d est courante dans sa vue, et ne voit que le calque commun et le sol de J%d" % [id + 1, id + 1],
			cam.current and cam.get_viewport() == vue and cam.cull_mask == (1 | (2 if id == 0 else 4)))
	_check("la caméra de la racine n'est plus courante", not (p.get("_camera") as Camera3D).current)
	var ca := vp1.get_parent() as Control
	var cb := vp2.get_parent() as Control
	var boite := ca.get_parent() as Control
	_check("les deux conteneurs 2D sont hors de la mise en page, posés sur les moitiés de la boîte (%s | %s)"
		% [str(ca.get_global_rect()), str(cb.get_global_rect())],
		ca.top_level and cb.top_level and is_equal_approx(ca.global_position.x, boite.global_position.x)
		and is_equal_approx(cb.global_position.x, ca.global_position.x + ca.size.x + boite.get_theme_constant("separation"))
		and is_equal_approx(ca.size.x + cb.size.x + boite.get_theme_constant("separation"), boite.size.x))
	var sols: Array = p.get("_sols")
	_check("Sol1 sur le calque 2, Sol2 sur le calque 4",
		(sols[0] as VisualInstance3D).layers == 2 and (sols[1] as VisualInstance3D).layers == 4)
	var hors_commun := 0
	var communs := 0
	for m in _maillages(p.get_node("SceneIso/Murs")) + _maillages(p.get_node("SceneIso/Corps1")) + _maillages(p.get_node("SceneIso/Corps2")):
		communs += 1
		if (m as VisualInstance3D).layers != 1:
			hors_commun += 1
	_check("murs et corps sont communs, sur le calque 1 (%d maillages)" % communs, communs > 2 and hors_commun == 0)

	_check("lightmap de J1 : masque ~4 sans la couche des capteurs",
		vp1.canvas_cull_mask == ((~4 & 0xFFFFFFFF) & ~int(p.COUCHES_CAPTEURS)) and (vp1.canvas_cull_mask & 2) != 0
		and (vp1.canvas_cull_mask & 4) == 0, str(vp1.canvas_cull_mask))
	_check("lightmap de J2 : masque ~2 sans la couche des capteurs",
		vp2.canvas_cull_mask == ((~2 & 0xFFFFFFFF) & ~int(p.COUCHES_CAPTEURS)) and (vp2.canvas_cull_mask & 4) != 0
		and (vp2.canvas_cull_mask & 2) == 0, str(vp2.canvas_cull_mask))
	_check("les deux lightmaps dessinent, transparentes à l'écran",
		vp1.render_target_update_mode == SubViewport.UPDATE_ALWAYS and vp2.render_target_update_mode == SubViewport.UPDATE_ALWAYS
		and (vp1.get_parent() as CanvasItem).modulate.a == 0.0 and (vp2.get_parent() as CanvasItem).modulate.a == 0.0)
	_check("le chemin SubViewport est forcé, le fond éteint",
		not main.rendu_racine_autorise and not main._rendu_racine and not (main.get_node("Background") as CanvasItem).visible)
	_check("les vingt sprites de corps sont hors de toute vue",
		_sprites_sur(main.p1, 0, 0) == 10 and _sprites_sur(main.p2, 0, 0) == 10)

	print("--- Les capteurs ---")
	var capteurs: Array = p.capteurs()
	_check("quatre capteurs, un par vue et par corps", _capteurs_vivants(p) == 4)
	for id in 2:
		for j in 2:
			var c = capteurs[id][j]
			if c == null:
				continue
			var attendu: int = Canaux.JOUEUR_LOCAL if id == j else Canaux.masque_vue_adverse(j)
			_check("capteur vue J%d corps J%d : masque de lumière %d (%s)" % [id + 1, j + 1, attendu,
				"le sien" if id == j else "celui que J%d voit d'en face" % (id + 1)],
				c.masque_lumiere() == attendu, str(c.masque_lumiere()))
			_check("capteur vue J%d corps J%d : 256², dans le monde 2D du duel, ne lit que sa couche, n'écoute rien" % [id + 1, j + 1],
				c.size == Vector2i(256, 256) and c.world_2d == vp1.world_2d
				and c.canvas_cull_mask == p.couche_capteur(id, j) and c.couche() == p.couche_capteur(id, j)
				and not c.is_audio_listener_2d() and c.get_parent() == p)
	var voit_un_autre := 0
	for a in _liste_capteurs(capteurs):
		for b in _liste_capteurs(capteurs):
			if a != b and (a.canvas_cull_mask & b.couche()) != 0:
				voit_un_autre += 1
	_check("aucun capteur ne voit le disque d'un autre (sur une couche commune, la vue de J2 recouvrait celle de J1)",
		voit_un_autre == 0, "%d paire(s)" % voit_un_autre)
	var courbes := 0
	for id in 2:
		for j in 2:
			var c = capteurs[id][j]
			if c != null and c.matiere() is ShaderMaterial and (c.matiere() as ShaderMaterial).shader == load(
					"res://capteur_local.gdshader" if id == j else "res://capteur_adverse.gdshader"):
				courbes += 1
	_check("chaque disque porte la courbe du sprite qu'il remplace (le sien : joueur ; celui d'en face : ennemi)",
		courbes == 4, "%d/4" % courbes)
	# Chaque fragment d'un corps lit son capteur À SA PLACE, autour du centre posé à chaque image :
	# un centre en retard décalerait l'éclairage du corps (côté lampe) de ce qu'il a bougé.
	var centres := 0
	var mats: Array = p.get("_mat_corps")
	for j in 2:
		var joueur: Node2D = main.p1 if j == 0 else main.p2
		var lu = (mats[j] as ShaderMaterial).get_shader_parameter("centre")
		if lu is Vector2 and (lu as Vector2).distance_to(joueur.global_position) < 0.01:
			centres += 1
	_check("chaque corps lit son capteur autour de sa position (centre posé à chaque image)", centres == 2, "%d/2" % centres)

	print("--- ISO2b : l'effacement et la silhouette, lus sur les sprites ---")
	var joueurs_b: Array = [main.p1, main.p2]
	var opacites_avant: Array[float] = [main.p1.modulate.a, main.p2.modulate.a]
	# L'opacité RENDUE, parents compris : le corps de J1 à 0,5, celui de J2 à 0,25 par leur nœud.
	main.p1.modulate.a = 0.5
	main.p2.modulate.a = 0.25
	p._suivre()
	var opacites_justes := 0
	var sous_la_moitie := 0
	for j in 2:
		for vue_id in 2:
			var attendue: float = p.opacite_du_corps(joueurs_b[j], vue_id == j)
			var lue = (mats[j] as ShaderMaterial).get_shader_parameter("opacite_%d" % (vue_id + 1))
			if lue is float and absf(float(lue) - attendue) < 0.001:
				opacites_justes += 1
			if attendue <= 0.5001:
				sous_la_moitie += 1
	_check("ISO2b : chaque corps lit, par vue, l'opacité rendue du sprite qu'il remplace (le sien chez soi, l'ennemi chez l'autre, parents compris)",
		opacites_justes == 4 and sous_la_moitie == 4, "%d/4 justes, %d/4 sous 0,5" % [opacites_justes, sous_la_moitie])
	var silhouettes_justes := 0
	for j in 2:
		var dim: Polygon2D = joueurs_b[j].get("visual_dim")
		for vue_id in 2:
			var lue = (mats[j] as ShaderMaterial).get_shader_parameter("silhouette_%d" % (vue_id + 1))
			if not (lue is Color):
				continue
			var sil := lue as Color
			if vue_id == j:
				if sil.a > 0.0 and absf(sil.a - dim.color.a * p.opacite_rendue(dim)) < 0.001 \
						and Color(sil.r, sil.g, sil.b).is_equal_approx(Color(dim.color.r, dim.color.g, dim.color.b)):
					silhouettes_justes += 1
			elif sil.a == 0.0:
				silhouettes_justes += 1
	_check("ISO2b : la silhouette de soi (visual_dim : sa couleur, sa demi-opacité) chez soi seulement, jamais dans la vue de l'autre",
		silhouettes_justes == 4, "%d/4" % silhouettes_justes)
	# Un seul fondu par pixel : chaque pièce a sa passe de profondeur, avant sa couleur.
	var passes_justes := 0
	for j in 2:
		var corps3d := (p.get("_corps") as Array)[j] as Node3D
		for nom in ["Tronc", "Nez"]:
			var couleur := corps3d.get_node_or_null(nom) as MeshInstance3D
			var prof := corps3d.get_node_or_null(nom + "Profondeur") as MeshInstance3D
			if couleur == null or prof == null:
				continue
			var mc := couleur.material_override as ShaderMaterial
			var mp := prof.material_override as ShaderMaterial
			if mp != null and mc != null and mp.shader == load("res://corps_profondeur_iso.gdshader") \
					and mp.render_priority < mc.render_priority and prof.mesh == couleur.mesh and prof.position == couleur.position \
					and absf(float(mp.get_shader_parameter("opacite_1")) - float(mc.get_shader_parameter("opacite_1"))) < 0.001:
				passes_justes += 1
	_check("ISO2b : chaque pièce de corps écrit sa profondeur avant sa couleur, à la même opacité (un seul fondu par pixel)",
		passes_justes == 4, "%d/4" % passes_justes)
	main.p1.modulate.a = opacites_avant[0]
	main.p2.modulate.a = opacites_avant[1]
	p._suivre()
	_check("masques miroir : J1 voit J2 par 2|16, J2 voit J1 par 2|32",
		capteurs[0][1].masque_lumiere() == (2 | 16) and capteurs[1][0].masque_lumiere() == (2 | 32))


## Le corps de `light()` d'un shader, commentaires et blancs retirés : deux shaders miroirs y
## sont identiques caractère pour caractère. Chaîne vide si le shader n'a pas de `light()`.
func _lumiere_du_shader(chemin: String) -> String:
	var lignes: PackedStringArray = []
	for ligne in FileAccess.get_file_as_string(chemin).split("\n"):
		var i := ligne.find("//")
		lignes.append(ligne.left(i) if i >= 0 else ligne)
	var code := "".join(lignes).replace(" ", "").replace("\t", "").replace("\r", "")
	var entete := "voidlight(){"
	var debut := code.find(entete)
	if debut < 0:
		return ""
	var profondeur := 0
	for k in range(debut + entete.length() - 1, code.length()):
		if code[k] == "{":
			profondeur += 1
		elif code[k] == "}":
			profondeur -= 1
			if profondeur == 0:
				return code.substr(debut, k - debut + 1)
	return ""


## Les capteurs vivants d'un tableau `[vue][corps]`, à plat.
func _liste_capteurs(capteurs: Array) -> Array[CapteurCorps]:
	var out: Array[CapteurCorps] = []
	for ligne in capteurs:
		for c in ligne:
			if c != null:
				out.append(c as CapteurCorps)
	return out


func _unique(main: Node, p: Node, id: int) -> void:
	var vues3d: Array = p.get("_vues3d")
	var cam := p.get("_camera") as Camera3D
	_check("vue unique : la caméra de la racine est courante et ne voit que le sol de J%d" % (id + 1),
		cam.current and cam.cull_mask == (1 | (2 if id == 0 else 4)))
	_check("vue unique : les deux vues 3D sont arrêtées, affichages cachés", _vues3d_arretees(p))
	var c: Array = p.capteurs()
	_check("vue unique : deux capteurs, ceux de la vue regardée seulement",
		_capteurs_vivants(p) == 2 and c[id][0] != null and c[id][1] != null and c[1 - id][0] == null)
	var autre: SubViewport = main.vp2 if id == 0 else main.vp1
	_check("vue unique : la vue de l'autre joueur est arrêtée par le jeu, la nôtre dessine",
		autre.render_target_update_mode == SubViewport.UPDATE_DISABLED
		and (main.vp1 if id == 0 else main.vp2).render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	var f3: String = p.etat
	_check("F3 en vue unique : « unique », J%d seul" % (id + 1),
		f3.contains("unique") and f3.contains("J%d : masque" % (id + 1)) and not f3.contains("J%d : masque" % (2 - id)), f3)
	_check("vue unique : aucun nœud 3D sous GameState ni sous Player*", _noeuds_3d_sous(main) == 0)
	_check("vue unique : les vues 3D et les capteurs n'ont pas fait entrer la racine dans le monde du duel",
		root.world_2d != main.vp1.world_2d)


## Rien de ce qu'une lightmap dessine ne reçoit le canal de vue de l'AUTRE joueur — le
## halo de J2 (`range_item_cull_mask` = canal de la vue de J2) n'écrit rien dans la
## lightmap de J1, ni dans ses capteurs. C'est la moitié « il ne voit pas mon halo » du
## jalon, prouvée sur les masques ; l'autre moitié se prouve au pixel, au banc.
func _canaux(main: Node, p: Node, Canaux: GDScript) -> void:
	print("--- Les canaux : une lumière du canal de J2 n'écrit rien chez J1 ---")
	var vp1: SubViewport = main.vp1
	var vp2: SubViewport = main.vp2
	var fuites := [0, 0]
	var examines := [0, 0]
	var noeuds: Array[Node] = [vp1]
	while not noeuds.is_empty():
		var n: Node = noeuds.pop_back()
		noeuds.append_array(n.get_children())
		var item := n as CanvasItem
		if item == null or item is Light2D:
			continue
		for id in 2:
			var vue: SubViewport = vp1 if id == 0 else vp2
			if (item.visibility_layer & vue.canvas_cull_mask) == 0:
				continue
			examines[id] += 1
			if (item.light_mask & Canaux.canal_de_vue(1 - id)) != 0:
				fuites[id] += 1
				printerr("    fuite : %s (couche %d, masque %d) chez J%d" % [item.get_path(), item.visibility_layer, item.light_mask, id + 1])
	for id in 2:
		_check("lightmap de J%d : aucun de ses %d CanvasItem ne reçoit le canal de vue de J%d"
			% [id + 1, examines[id], 2 - id], examines[id] > 50 and fuites[id] == 0, "%d fuite(s)" % fuites[id])
	var halos := [main.p1.ambient_light, main.p2.ambient_light]
	_check("le halo de chaque joueur n'éclaire que son propre canal de vue (16 / 32)",
		(halos[0] as Light2D).range_item_cull_mask == Canaux.canal_de_vue(0)
		and (halos[1] as Light2D).range_item_cull_mask == Canaux.canal_de_vue(1))
	var capteurs: Array = p.capteurs()
	var fuites_capteurs := 0
	for id in 2:
		for j in 2:
			if capteurs[id][j] != null and (capteurs[id][j].masque_lumiere() & Canaux.canal_de_vue(1 - id)) != 0:
				fuites_capteurs += 1
	_check("aucun capteur d'une vue ne reçoit le canal de l'autre vue", fuites_capteurs == 0)
	_check("mais chaque joueur reçoit bien, dans SA vue, le corps d'en face par SON halo",
		capteurs[0][1] != null and (capteurs[0][1].masque_lumiere() & Canaux.canal_de_vue(0)) != 0
		and capteurs[1][0] != null and (capteurs[1][0].masque_lumiere() & Canaux.canal_de_vue(1)) != 0)


func _effets_suivent_la_vue(main: Node, p: Node, scinde: bool) -> void:
	var vues3d: Array = p.get("_vues3d")
	# En vue unique, sous `GameState` : un `CanvasLayer` sous un nœud de la racine s'attache
	# à la fenêtre, et part avec `Main` (le patron du rendu racine).
	var ecran1: Node = vues3d[0] if scinde else main
	_check("%s : les calques d'écran de J1 vivent sous %s (l'écran), pas dans la lightmap"
		% ["scindé" if scinde else "unique", ecran1.name], _calques_sous(main.p1, ecran1))
	if scinde:
		_check("scindé : ceux de J2 dans le sien (VueIso2)", _calques_sous(main.p2, vues3d[1]))
	else:
		_check("unique : ceux de J2 restent hors de l'écran (sa sous-vue arrêtée)",
			_calques_sous(main.p2, main.vp2))
	var b1: Node = main._brouillages[0]
	var b2: Node = main._brouillages[1]
	_check("%s : l'appareil de brouillage de J1 vit dans son viewport 3D, avec le projecteur de sa caméra"
		% ("scindé" if scinde else "unique"),
		b1.get_parent() == ecran1 and (b1.projecteur as Callable).is_valid())
	if scinde:
		_check("scindé : celui de J2 dans VueIso2, avec son projecteur",
			b2.get_parent() == vues3d[1] and (b2.projecteur as Callable).is_valid())
	else:
		_check("unique : celui de J2 est retiré", b2.get_parent() == null)
	# Le projecteur est bien la caméra 3D : le centre de la vue 2D de J1 tombe au centre de
	# son écran, et deux points alignés en profondeur se rapprochent (le sol raccourci).
	var proj: Callable = b1.projecteur
	var canevas: Transform2D = main.vp1.canvas_transform
	var taille := Vector2(main.vp1.size_2d_override)
	var centre: Vector2 = canevas.affine_inverse() * (taille * 0.5)
	var ecran: Vector2 = proj.call(centre)
	# Le centre du viewport qui REND l'écran de J1 — celui où vit l'appareil. Sans fenêtre, la
	# racine n'a pas l'aire 1920×1080 : comparer à l'aire de la lightmap y mentait (349 contre 960).
	var milieu: Vector2 = b1.get_viewport().get_visible_rect().size * 0.5
	_check("le projecteur envoie le centre de la vue 2D de J1 au centre de l'écran qui la rend (%s pour %s)"
		% [str(ecran.round()), str(milieu.round())], ecran.distance_to(milieu) < 2.0)
	var haut: Vector2 = proj.call(centre + Vector2(0, -100))
	var droite: Vector2 = proj.call(centre + Vector2(100, 0))
	# H15 : la caméra GARDE LA PROFONDEUR de la vue de dessus (`size = 1080 × sin θ`) ; c'est
	# la largeur qui s'étire de 1 / sin θ — l'iso voit 1513 px de large au lieu de 1920.
	_check("et garde la profondeur (%.1f px pour 100) en étirant la largeur de 1 / sin 52° (%.1f px pour 100)"
		% [ecran.y - haut.y, droite.x - ecran.x],
		absf((ecran.y - haut.y) - 100.0) < 1.0 and absf((droite.x - ecran.x) - 100.0 / sin(deg_to_rad(52.0))) < 1.0)
	var angle: float = p.angle_ecran(0, centre, centre + Vector2(100, -100))
	_check("l'angle du voile est projeté : −45° dans le monde devient %.1f° à l'écran" % rad_to_deg(angle),
		absf(angle - atan2(-100.0, 100.0 / sin(deg_to_rad(52.0)))) < 0.01)
	_check("hors de la vue de J2 en vue unique, angle_ecran rend NAN",
		scinde or is_nan(p.angle_ecran(1, centre, centre + Vector2(1, 0))))


## Les viewports qui ÉCOUTENT le monde du duel : ceux qu'on attend, et rien d'autre —
## ni la racine, ni une vue 3D, ni un capteur. Une vue arrêtée ne compte pas (piège consigné).
func _auditeurs(main: Node, p: Node, audio: Node, attendus: Array, quand: String) -> void:
	var monde: World2D = main.vp1.world_2d
	var candidats: Array = [root, main.vp1, main.vp2]
	candidats.append_array(p.get("_vues3d"))
	for id in 2:
		for j in 2:
			if p.capteurs()[id][j] != null:
				candidats.append(p.capteurs()[id][j])
	var ecoutent: Array = []
	for v in candidats:
		var vue := v as Viewport
		if vue.world_2d != monde or not vue.is_audio_listener_2d():
			continue
		if vue != root and (vue as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED:
			continue
		ecoutent.append(vue)
	_check("%s : %d viewport(s) écoute(nt) le monde du duel — exactement %s" % [quand, ecoutent.size(),
		", ".join(attendus.map(func(v): return String(v.name)))],
		ecoutent == attendus, str(ecoutent.map(func(v): return String(v.name))))
	_check("%s : la racine n'écoute pas le duel, et le pool positionnel est dans son monde" % quand,
		not (root.world_2d == monde and root.is_audio_listener_2d())
		and (audio.sfx_players_2d[0] as Node2D).get_world_2d() == monde)


# ---------------------------------------------------------------------------

func _jouer(main: Node) -> Dictionary:
	# ⚠️ **Toute partie commence au DÉBUT d'un pas de physique.** `physics_frame` est émis
	# avant que les nœuds ne traitent le pas : partie posée après une image de rendu, la
	# première mesure tombait avant tout mouvement, et la partie iso avait un pas de retard
	# sur le témoin sans que la vue y soit pour rien.
	await physics_frame
	var p := root.get_node_or_null("Presentation3D")
	var iso: bool = p != null and bool(p.get("_actif")) and bool(p.get("_scinde"))
	var p1: Node2D = main.p1
	var p2: Node2D = main.p2
	# Chacun à son point d'apparition : loin l'un de l'autre. ⚠️ **Le flash de tir éblouit
	# jusqu'à 600 px**, et l'éblouissement s'intègre à la cadence d'image : à 300 px, le tir
	# de J2 freinait J1 d'une fraction de pixel différente d'une partie à l'autre.
	p1.global_position = main._get_spawn_position(0)
	p2.global_position = main._get_spawn_position(1)
	p1.rotation = 0.0
	p2.rotation = PI
	p1.set("velocity", Vector2.ZERO)
	p2.set("velocity", Vector2.ZERO)
	var etats: Array = []
	# ⚠️ **La visée par le STICK, jamais par la souris.** Sans stick, J1 vise la souris,
	# ramenée au monde par la caméra de sa vue : la rotation dépendait de là où la caméra
	# se trouvait, et le premier témoin divergeait dès le premier pas.
	Input.action_press("p1_aim_up")
	Input.action_press("p2_aim_down")
	for pas in PAS_SIMULES:
		Input.action_press("p1_move_right" if pas < PAS_SIMULES / 2 else "p1_move_down")
		Input.action_press("p2_move_left" if pas < PAS_SIMULES / 2 else "p2_move_up")
		if pas == PAS_SIMULES / 2:
			Input.action_release("p1_move_right")
			Input.action_release("p2_move_left")
		# ⚠️ **Pas de torche** : l'éblouissement s'intègre dans `_process`, à la cadence de
		# l'image et non du pas de physique, et freine qui le subit — deux parties sans iso
		# divergeaient dès le deuxième pas. Défaut du jeu (une pénalité qui dépend de la
		# cadence), signalé, hors périmètre d'ISO2.
		# ⚠️ **Aucun tir ici.** Même J1 seul, à son point d'apparition : J2 est à 483 px, sous
		# les 600 px du flash, et la balle suivante hérite d'une visée à peine freinée — deux
		# parties sans iso divergeaient au pas qui suit le tir (797,6341 contre 797,6379). La
		# simulation avec tirs est prouvée en vue unique par `test_iso_camera.gd`, où J2 est
		# retiré de la scène ; ici on prouve les deux joueurs, leurs pas et leurs visées.
		await physics_frame
		var balles: Array = []
		for b in main.bullet_container.get_children():
			balles.append([(b as Node2D).global_position, snappedf((b as Node2D).rotation, 1e-6)])
		etats.append([p1.global_position, snappedf(p1.rotation, 1e-6), p1.hp, p1.flashlight_on,
			p2.global_position, snappedf(p2.rotation, 1e-6), p2.hp, balles])
	for action in ["p1_move_right", "p1_move_down", "p2_move_left", "p2_move_up",
			"p1_aim_up", "p2_aim_down"]:
		Input.action_release(action)
	return {"etats": etats, "iso": iso}


## Une manche NEUVE : toute partie comparée part d'un état remis à zéro (recul après tir,
## rechargement, éblouissement, fusées) — sans elle, la seconde héritait de la première.
func _nouvelle_manche(main: Node) -> bool:
	main._start_round()
	return await _depart_fini(main)


## Attend le décompte de la manche qui vient d'être lancée et l'abrège par sa propre
## horloge. Sous budget de TEMPS, jamais en nombre d'images (piège consigné).
func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			printerr("    la manche n'a pas démarré (round_active=%s, décompte=%s)" % [main.round_active, main.countdown_left])
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	for i in 4:
		await physics_frame
	return main.round_active


func _premier_ecart(a: Array, b: Array) -> String:
	for i in mini(a.size(), b.size()):
		if str(a[i]) != str(b[i]):
			return "pas %d : %s ≠ %s" % [i, str(a[i]), str(b[i])]
	return "tailles %d / %d" % [a.size(), b.size()] if a.size() != b.size() else "aucun"


func _ecarts(a: Array, b: Array) -> int:
	var n := absi(a.size() - b.size())
	for i in mini(a.size(), b.size()):
		if str(a[i]) != str(b[i]):
			n += 1
	return n


func _cadre(main: Node, id: int) -> Rect2:
	var vue: SubViewport = main.vp1 if id == 0 else main.vp2
	return (vue.get_parent() as Control).get_global_rect()


func _sprites_sur(joueur: Node, couche_soi: int, couche_ennemi: int) -> int:
	var Pres: GDScript = load("res://presentation_3d.gd")
	var n := 0
	for nom in Pres.APPUIS_JOUEUR:
		var item := joueur.get(nom) as CanvasItem
		var attendue: int = couche_ennemi if String(nom).contains("enemy") else couche_soi
		if item != null and item.visibility_layer == attendue:
			n += 1
	return n


func _capteurs_vivants(p: Node) -> int:
	var n := 0
	for id in 2:
		for j in 2:
			var c = p.capteurs()[id][j]
			if c != null and is_instance_valid(c) and c.is_inside_tree():
				n += 1
	return n


func _vues3d_arretees(p: Node) -> bool:
	var vues3d: Array = p.get("_vues3d")
	var affichages: Array = p.get("_affichages")
	var cams: Array = p.get("_cameras3d")
	for id in 2:
		if (vues3d[id] as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED \
				or (affichages[id] as Control).visible or (cams[id] as Camera3D).current:
			return false
	return true


func _calques_sous(joueur: Node, parent: Node) -> bool:
	var calques: Array = joueur.calques_ecran
	if calques.is_empty():
		return false
	for c in calques:
		if is_instance_valid(c) and (c as Node).get_parent() != parent:
			return false
	return true


func _noeuds_3d_sous(main: Node) -> int:
	var n := 0
	var noeuds: Array[Node] = [main]
	while not noeuds.is_empty():
		var x: Node = noeuds.pop_back()
		if x is Node3D:
			n += 1
		noeuds.append_array(x.get_children())
	return n


func _maillages(racine: Node) -> Array:
	var out: Array = []
	var noeuds: Array[Node] = [racine]
	while not noeuds.is_empty():
		var x: Node = noeuds.pop_back()
		if x is MeshInstance3D:
			out.append(x)
		noeuds.append_array(x.get_children())
	return out


## `NetworkManager.GameMode.LOCAL_SPLITSCREEN`, lu par l'arbre : nommer l'autoload dans
## une suite `--script` la ferait compiler avant qu'il existe (piège consigné).
func NetworkManager_mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
