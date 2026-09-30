extends SceneTree

## Chantier des lumières de la 0.8.0, L1 — la torche porte jusqu'au bord de l'écran de son porteur (Q45) ; depuis Q76
## (Adrien, 2026-09-30 vers 22:58 : « En fait diminuons la portée des lampe au maximum visible par le joueur en hauteur et
## largeur (le minimum des deux) »), EXACTEMENT jusqu'au bord le plus proche, pour toutes les classes.
##
## Ce qu'elle garde :
## - la formule (`PorteeEcran`) : `portee_au_bord` est le MINIMUM, sur toutes les directions, de la distance au bord (le bord
##   le plus proche : le haut ou le bas de l'écran en vue unique), `portee_minimale` le maximum (le coin, la règle de L1) ;
##   468 px en vue unique à ×1,5 ; la portée SUIT le zoom ; en écran scindé (×1,25) le bord le plus proche est à 431 px, et
##   la torche garde les 468 de la vue unique (une seule portée pour tous les modes) ;
## - la règle (`GameSettings.bornes_de_portee`) : allumée par défaut, plancher ET plafond au bord le plus proche ; la même
##   EN LIGNE quoi que dise la machine ; éteinte (`--sans-portee-ecran`), les portées de la 0.7.1 ; au coin
##   (`--portee-coin`), la règle de L1 ; les deux drapeaux en débogage seulement, et le coin jamais en ligne ; plancher,
##   plafond et échelle du cookie disent la même portée pour les dix classes ;
## - EN JEU, sur les vraies caméras iso : en écran scindé à 45° B (J1 et J2) puis en vue unique, dans huit directions de
##   visée, la formule dit la distance au bord mesurée sur la caméra ; en vue unique, la lumière que la lampe pose
##   (`texture_scale` × cookie) ne sort de l'écran dans AUCUNE direction, et atteint le bord quand on vise le haut ou le bas
##   de l'écran ; en écran scindé, elle dépasse le bord le plus proche de la vue scindée de ce qui la sépare de la vue unique.
##
## Lancer : godot --headless --path . --script res://tools/test_portee_ecran.gd

const Reglages := preload("res://settings_manager.gd")

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
	print("=== PORTÉE DES TORCHES : LE BORD DE L'ÉCRAN LE PLUS PROCHE (L1, Q76) ===")
	await process_frame
	_formule()
	_regle()
	await _en_jeu()
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# --- La formule, sans monter le jeu ------------------------------------------------------------------

func _formule() -> void:
	print("\n--- La formule ---")
	var tangage := CameraIso.TANGAGE_DEG
	var scindee := Vector2(957.0, 1080.0)
	for zoom in [1.5, 1.25, 1.0, 2.0]:
		var d := Reglages.DECALAGE_VISEE_DEFAUT
		var coin := PorteeEcran.portee_minimale(PorteeEcran.VUE_UNIQUE, zoom, d, tangage)
		var bord := PorteeEcran.portee_au_bord(PorteeEcran.VUE_UNIQUE, zoom, d, tangage)
		var pire := 0.0
		var proche := INF
		for k in 720:
			var u := Vector2.RIGHT.rotated(TAU * float(k) / 720.0)
			var t := PorteeEcran.distance_au_bord(u, PorteeEcran.VUE_UNIQUE, zoom, d, tangage)
			pire = maxf(pire, t)
			proche = minf(proche, t)
		_check("×%.2f : Q76, la portée au bord (%.1f px) est le bord le PLUS PROCHE sur 720 directions (%.1f px)"
			% [zoom, bord, proche], absf(bord - proche) < 1e-3)
		_check("×%.2f : L1, la portée au coin (%.0f px) est le bord le plus LOIN (%.0f px)" % [zoom, coin, pire],
			coin >= pire - 1e-3 and coin - pire < 2.0)
	var vu := PorteeEcran.portee_au_bord(PorteeEcran.VUE_UNIQUE, 1.5, 0.15, tangage)
	_check("vue unique à ×1,5 : min(504,3 ; 360) + 108 = 468 px (%.3f)" % vu, is_equal_approx(vu, 468.0))
	var haut := PorteeEcran.distance_au_bord(Vector2.UP, PorteeEcran.VUE_UNIQUE, 1.5, 0.15, tangage)
	var bas := PorteeEcran.distance_au_bord(Vector2.DOWN, PorteeEcran.VUE_UNIQUE, 1.5, 0.15, tangage)
	var droite := PorteeEcran.distance_au_bord(Vector2.RIGHT, PorteeEcran.VUE_UNIQUE, 1.5, 0.15, tangage)
	var attendu := 0.5 * 720.0 * sin(deg_to_rad(tangage)) * 1920.0 / 1080.0 + 0.15 * 720.0
	_check("vers le haut et le bas de l'écran : le bord le plus proche (%.1f et %.1f px)" % [haut, bas],
		is_equal_approx(haut, vu) and is_equal_approx(bas, vu))
	_check("vers la droite de l'écran : demi-largeur au sol + décalage (%.1f px), plus loin" % droite,
		is_equal_approx(droite, attendu) and droite > vu)
	var a := PorteeEcran.portee_au_bord(PorteeEcran.VUE_UNIQUE, 1.5, 0.15, tangage)
	var b := PorteeEcran.portee_au_bord(PorteeEcran.VUE_UNIQUE, 1.25, 0.15, tangage)
	_check("elle SUIT le zoom : ×1,25 porte plus loin que ×1,5, dans le rapport des zooms (%.1f / %.1f)" % [b, a],
		is_equal_approx(b / a, 1.5 / 1.25))
	var scinde := PorteeEcran.portee_au_bord(scindee, 1.25, 0.15, tangage)
	_check("écran scindé (×1,25, 957 px) : son bord le plus proche est à %.1f px, sur les côtés — la torche y garde les %.0f "
		% [scinde, vu] + "px de la vue unique (une seule portée pour tous les modes)", scinde < vu and absf(scinde - 431.2) < 0.5)


# --- La règle, dans GameSettings ----------------------------------------------------------------------

func _regle() -> void:
	print("\n--- La règle ---")
	var reglages := root.get_node("GameSettings")
	_check("allumée par défaut", bool(reglages.get("_portee_ecran_locale")))
	_check("en ligne, toujours — quoi que dise la machine", Reglages.portee_ecran_du_duel(true, false))
	_check("hors ligne, le choix local", not Reglages.portee_ecran_du_duel(false, false))
	var eteinte := Reglages.bornes_de_portee(false, false, 1.5, 0.15)
	_check("éteinte : ni plancher ni plafond (les portées de la 0.7.1)", eteinte.x == 0.0 and is_inf(eteinte.y))
	var bord := Reglages.bornes_de_portee(true, false, 1.5, 0.15)
	_check("Q76 : plancher ET plafond au bord le plus proche (%.1f / %.1f px)" % [bord.x, bord.y],
		is_equal_approx(bord.x, 468.0) and is_equal_approx(bord.y, 468.0))
	var coin := Reglages.bornes_de_portee(true, true, 1.5, 0.15)
	_check("le coin (--portee-coin) : la règle de L1, un plancher au coin sans plafond (%.1f px)" % coin.x,
		is_equal_approx(coin.x, PorteeEcran.portee_minimale(PorteeEcran.VUE_UNIQUE, 1.5, 0.15, CameraIso.TANGAGE_DEG))
		and is_inf(coin.y))
	_check("le coin ne vaut JAMAIS en ligne, hors ligne le choix local",
		not Reglages.regle_du_coin(true, true) and Reglages.regle_du_coin(false, true) and not Reglages.regle_du_coin(false, false))
	_check("le coin est éteint par défaut", not bool(reglages.get("_portee_coin_locale")))
	var source := FileAccess.get_file_as_string("res://settings_manager.gd")
	_check("--sans-portee-ecran ne vaut qu'en build de débogage",
		source.contains("OS.is_debug_build() and _arguments().has(DRAPEAU_SANS_PORTEE_ECRAN)"))
	_check("--portee-coin ne vaut qu'en build de débogage",
		source.contains("_portee_coin_locale = OS.is_debug_build() and _arguments().has(DRAPEAU_PORTEE_COIN)"))
	reglages.accorder_au_mode(true)
	var attendu := PorteeEcran.portee_au_bord(PorteeEcran.VUE_UNIQUE, Reglages.ZOOM_DUEL_DEFAUT,
		Reglages.DECALAGE_VISEE_DEFAUT, CameraIso.TANGAGE_DEG)
	_check("en ligne, plancher et plafond se dérivent des constantes du duel (%.1f / %.1f px)" % [WeaponData.portee_plancher,
		WeaponData.portee_plafond], is_equal_approx(WeaponData.portee_plancher, attendu)
		and is_equal_approx(WeaponData.portee_plafond, attendu))
	# En ligne, même une machine qui voudrait le coin garde la règle du jeu.
	reglages.set("_portee_coin_locale", true)
	reglages.accorder_au_mode(true)
	_check("en ligne, le coin demandé en local est ignoré (%.1f px)" % WeaponData.portee_plafond,
		is_equal_approx(WeaponData.portee_plafond, attendu))
	reglages.accorder_au_mode(false)
	_check("hors ligne, le coin demandé vaut : plancher au coin, sans plafond (%.1f px)" % WeaponData.portee_plancher,
		WeaponData.portee_plancher > 700.0 and is_inf(WeaponData.portee_plafond))
	reglages.set("_portee_coin_locale", false)
	reglages.accorder_au_mode(false)


## Les dix classes : chacune porte exactement au bord le plus proche (Q76), quelle que soit sa portée de la 0.7.1, et
## l'échelle du cookie dit la même portée.
func _classes(main: Node) -> Array:
	var classes: Array = main._classes
	_check("le catalogue porte dix classes", classes.size() == 10, str(classes.size()))
	var bord := WeaponData.portee_plancher
	_check("plancher et plafond égaux : une seule portée pour toutes les classes (%.1f px)" % bord,
		is_equal_approx(WeaponData.portee_plancher, WeaponData.portee_plafond))
	for c: WeaponData in classes:
		var propre := WeaponData.TAILLE_COOKIE_REFERENCE * 0.5 * c.torch_scale * WeaponData.facteur_portee
		var tex := c.get_torch_texture()
		var par_cookie := c.echelle_torche() * float(tex.get_width()) * 0.5 if tex != null else -1.0
		_check("%s : portée %.1f = le bord (%.1f), la 0.7.1 portait à %.1f (%+.1f px), et le cookie l'étale jusque-là (%.1f)"
			% [c.slug(), c.portee_torche(), bord, propre, bord - propre, par_cookie],
			is_equal_approx(c.portee_torche(), bord) and is_equal_approx(propre, c.portee_sans_ecran())
			and absf(par_cookie - c.portee_torche()) < 0.01)
	return classes


# --- En jeu, sur les vraies caméras -------------------------------------------------------------------

func _en_jeu() -> void:
	print("\n--- En jeu : écran scindé à 45° B, puis vue unique ---")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var reseau := root.get_node("NetworkManager")
	main.ui._intended_mode = int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
	main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(main))
	var pres := root.get_node_or_null("Presentation3D")
	var reglages := root.get_node("GameSettings")
	if pres == null or not bool(reglages.mode_iso):
		_check("la vue iso est allumée", false)
		return
	var classes := _classes(main)
	# Une seule portée pour tous les modes : en écran scindé, la portée est celle de la VUE UNIQUE (Q15 révisée : les deux
	# écrans n'ont plus le même zoom — la portée, elle, ne doit pas suivre l'écran).
	var plancher_scinde := WeaponData.portee_plancher
	var attendu_vu := PorteeEcran.portee_au_bord(PorteeEcran.VUE_UNIQUE, float(reglages.call("zoom_de_la_vue_unique")),
		float(reglages.decalage_visee), CameraIso.TANGAGE_DEG)
	_check("écran scindé : la portée est celle de la vue unique (%.1f px)" % plancher_scinde,
		is_equal_approx(plancher_scinde, attendu_vu) and is_equal_approx(WeaponData.portee_plafond, attendu_vu))
	# Le joueur ne vise plus tout seul (la souris du headless tirerait sa visée) ; on la pose.
	for p in [main.p1, main.p2]:
		(p as Node).set_physics_process(false)
	# Au milieu de la carte : la caméra est libre (la formule ne couvre pas la caméra arrêtée au bord).
	var centre: Vector2 = main._carte_px.get_center()
	main.p1.global_position = centre
	main.p2.global_position = centre + Vector2(35, 35)
	for pid in 2:
		await _mesurer(main, pres, pid, classes, "scindé")
	# Un zoom de ×1,25 RÉGLÉ par le joueur (il vaut alors pour les deux écrans, vue unique comprise) : la portée se DÉRIVE
	# du zoom de la vue unique ; aucun nombre ne la cale sur ×1,5. Depuis Q15 révisée, `accorder_au_mode` recalcule le zoom
	# local depuis le réglage et l'écran : c'est donc le réglage qu'on pose, et non `_zoom_local` (qui serait écrasé).
	var choisi_avant: float = reglages.get("_zoom_duel_choisi")
	var regle_avant: bool = reglages.get("_zoom_duel_regle")
	reglages.set("_zoom_duel_choisi", 1.25)
	reglages.set("_zoom_duel_regle", true)
	reglages.accorder_au_mode(false, true)
	main.cam1.zoom = Vector2.ONE * float(reglages.zoom_duel)
	main.cam2.zoom = Vector2.ONE * float(reglages.zoom_duel)
	_check("×1,25 réglé : la portée suit le zoom de la vue unique (%.1f px, 468 × 1,5 / 1,25 = 561,6)"
		% WeaponData.portee_plancher, absf(WeaponData.portee_plancher - 561.6) < 0.5)
	for pid in 2:
		await _mesurer(main, pres, pid, classes, "scindé ×1,25")
	reglages.set("_zoom_duel_choisi", choisi_avant)
	reglages.set("_zoom_duel_regle", regle_avant)
	reglages.accorder_au_mode(false)
	main.cam1.zoom = Vector2.ONE * float(reglages.zoom_duel)
	main.cam2.zoom = Vector2.ONE * float(reglages.zoom_duel)
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()
	for i in 4:
		await process_frame
	_check("passer à la vue unique ne change pas la portée (%.1f px, %.1f en écran scindé)" % [WeaponData.portee_plancher,
		plancher_scinde], is_equal_approx(WeaponData.portee_plancher, plancher_scinde))
	# La vue unique au zoom de la vue unique (le banc de l'écran scindé l'a laissée à ×1,25) : c'est là que la règle se lit.
	reglages.accorder_au_mode(false, false)
	main.cam1.zoom = Vector2.ONE * float(reglages.zoom_duel)
	main.cam2.zoom = Vector2.ONE * float(reglages.zoom_duel)
	await _mesurer(main, pres, 0, classes, "vue unique")


## Huit visées, puis — en vue unique — le haut et le bas de l'écran : la formule dit le bord mesuré sur la caméra ; la
## lumière que la lampe pose ne sort pas de l'écran de la vue unique et en atteint le bord le plus proche ; en écran
## scindé, elle en dépasse le bord le plus proche de ce qui sépare les deux vues.
func _mesurer(main: Node, pres: Node, pid: int, classes: Array, mode: String) -> void:
	var joueur: Node2D = main.p1 if pid == 0 else main.p2
	var cam: Camera2D = main.cam1 if pid == 0 else main.cam2
	var unique := mode == "vue unique"
	var angles: Array[float] = []
	for k in 8:
		angles.append(TAU * float(k) / 8.0 + 0.3)
	if unique:
		# Les visées DU SOL qui se lisent vers le haut et vers le bas de l'écran (`CameraIso.stick_au_sol`).
		for ecran: Vector2 in [Vector2.UP, Vector2.DOWN]:
			angles.append(CameraIso.stick_au_sol(ecran, float(main.lacet_de_la_vue(pid))).angle())
	var sortie_max := -INF
	var au_plus_proche := INF
	var bord_haut_bas := 0.0
	var pire_ecart := 0.0
	var mesures := 0
	for n in angles.size():
		var angle: float = angles[n]
		joueur.rotation = angle
		var vue_2d := (cam.custom_viewport as Viewport).get_visible_rect().size
		main._regard_decalage[pid] = RegardDuel.decalage_vise(Vector2.RIGHT.rotated(angle),
			reglages_decalage(), vue_2d, cam.zoom.y)
		for i in 3:
			joueur.rotation = angle
			await process_frame
		var proj: Callable = pres.projecteur_ecran(pid)
		var ecran: Viewport = pres.viewport_ecran(pid)
		if not proj.is_valid() or ecran == null:
			_check("%s J%d : la vue projette" % [mode, pid + 1], false)
			return
		var taille := ecran.get_visible_rect().size
		var p := joueur.global_position
		var u := Vector2.RIGHT.rotated(angle)
		var s0: Vector2 = proj.call(p)
		var d: Vector2 = proj.call(p + u * 100.0) - s0
		# Le sol → l'écran est affine (caméra orthographique) : la sortie de l'écran se résout exactement.
		var k_sortie := INF
		for axe in 2:
			if absf(d[axe]) > 1e-6:
				var borne := taille[axe] if d[axe] > 0.0 else 0.0
				k_sortie = minf(k_sortie, (borne - s0[axe]) / d[axe])
		var au_bord := 100.0 * k_sortie
		# La visée AU SOL, dans les axes de la caméra : à l'écran, la profondeur est raccourcie de sin θ.
		var au_sol := Vector2(d.x, d.y / sin(deg_to_rad(CameraIso.TANGAGE_DEG)))
		var formule := PorteeEcran.distance_au_bord(au_sol, taille, cam.zoom.y, reglages_decalage(), CameraIso.TANGAGE_DEG)
		pire_ecart = maxf(pire_ecart, absf(formule - au_bord))
		au_plus_proche = minf(au_plus_proche, au_bord)
		if n >= 8:
			bord_haut_bas = maxf(bord_haut_bas, au_bord)
		var lampe := joueur.get_node("Flashlight") as PointLight2D
		for c: WeaponData in classes:
			joueur.equip_weapon(c)
			var posee := float(lampe.texture.get_width()) * lampe.texture_scale * 0.5
			sortie_max = maxf(sortie_max, posee - au_bord)
			if n >= 8 and absf(posee - au_bord) > 1.0:
				sortie_max = maxf(sortie_max, 1e9)
			mesures += 1
	var portee := WeaponData.portee_plancher
	if unique:
		_check("%s, J%d (lacet %.0f°) : dans %d visées, la lumière des 10 classes ne sort de l'écran nulle part (au plus %+.2f "
			% [mode, pid + 1, main.lacet_de_la_vue(pid), angles.size(), sortie_max] + "px), et atteint le haut et le bas de "
			+ "l'écran à 1 px près (bord à %.1f px, portée %.1f)" % [bord_haut_bas, portee],
			mesures == 10 * angles.size() and sortie_max <= 1.0 and absf(bord_haut_bas - portee) < 1.0)
	else:
		_check("%s, J%d (lacet %.0f°) : les 10 classes portent à %.1f px ; le bord le plus proche de cette vue est à %.1f px "
			% [mode, pid + 1, main.lacet_de_la_vue(pid), portee, au_plus_proche] + "(une seule portée pour tous les modes)",
			mesures == 80 and au_plus_proche < portee + 1.0)
	_check("%s, J%d : la formule dit la distance au bord mesurée sur la caméra (écart max %.2f px)"
		% [mode, pid + 1, pire_ecart], pire_ecart < 1.0)


func reglages_decalage() -> float:
	return float(root.get_node("GameSettings").decalage_visee)


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
