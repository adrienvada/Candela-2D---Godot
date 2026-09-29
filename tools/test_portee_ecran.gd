extends SceneTree

## Chantier des lumières de la 0.8.0, L1 — la torche porte au moins jusqu'au bord de l'écran de son porteur (Q45).
##
## Ce qu'elle garde :
## - la formule (`PorteeEcran`) : le coin est le pire cas, le lacet ne change rien, la vue scindée est couverte par
##   la vue unique ; la portée SUIT le zoom (×1,5 aujourd'hui, ×1,25 à l'essai de Q15) — elle n'est calée sur aucun ;
## - la règle (`GameSettings`) : allumée par défaut, la même EN LIGNE quoi que dise la machine, éteinte seulement hors
##   ligne en débogage ; plancher et échelle du cookie disent la même portée, pour les dix classes ;
## - EN JEU, sur les vraies caméras iso : en écran scindé à 45° B (J1 et J2) puis en vue unique, dans huit directions
##   de visée, pour les dix classes, la lumière que la lampe pose (`texture_scale` × cookie) va au moins jusqu'au
##   point du sol où la visée sort de l'écran — et la formule dit cette distance.
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
	print("=== PORTÉE DES TORCHES : AU MOINS LE BORD DE L'ÉCRAN (L1) ===")
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
		var p := PorteeEcran.portee_minimale(PorteeEcran.VUE_UNIQUE, zoom, d, tangage)
		var pire := 0.0
		var pire_scinde := 0.0
		for k in 720:
			var u := Vector2.RIGHT.rotated(TAU * float(k) / 720.0)
			pire = maxf(pire, PorteeEcran.distance_au_bord(u, PorteeEcran.VUE_UNIQUE, zoom, d, tangage))
			pire_scinde = maxf(pire_scinde, PorteeEcran.distance_au_bord(u, scindee, zoom, d, tangage))
		_check("×%.2f : la portée minimale (%.0f px) couvre toutes les directions (pire %.0f px, au coin)" % [zoom, p, pire],
			p >= pire - 1e-3 and p - pire < 2.0)
		_check("×%.2f : la vue unique couvre l'écran scindé (%.0f ≥ %.0f px)" % [zoom, p, pire_scinde], p >= pire_scinde)
	var a := PorteeEcran.portee_minimale(PorteeEcran.VUE_UNIQUE, 1.5, 0.15, tangage)
	var b := PorteeEcran.portee_minimale(PorteeEcran.VUE_UNIQUE, 1.25, 0.15, tangage)
	_check("elle SUIT le zoom : ×1,25 porte plus loin que ×1,5, dans le rapport des zooms (%.0f / %.0f)" % [b, a],
		is_equal_approx(b / a, 1.5 / 1.25))
	var droite := PorteeEcran.distance_au_bord(Vector2.RIGHT, PorteeEcran.VUE_UNIQUE, 1.5, 0.15, tangage)
	var attendu := 0.5 * 720.0 * sin(deg_to_rad(tangage)) * 1920.0 / 1080.0 + 0.15 * 720.0
	_check("vers la droite de l'écran : demi-largeur au sol + décalage (%.1f px)" % droite, is_equal_approx(droite, attendu))


# --- La règle, dans GameSettings ----------------------------------------------------------------------

func _regle() -> void:
	print("\n--- La règle ---")
	var reglages := root.get_node("GameSettings")
	_check("allumée par défaut", bool(reglages.get("_portee_ecran_locale")))
	_check("en ligne, toujours — quoi que dise la machine", Reglages.portee_ecran_du_duel(true, false))
	_check("hors ligne, le choix local", not Reglages.portee_ecran_du_duel(false, false))
	_check("éteinte : pas de plancher", Reglages.plancher_de_portee(false, 1.5, 0.15) == 0.0)
	var source := FileAccess.get_file_as_string("res://settings_manager.gd")
	_check("--sans-portee-ecran ne vaut qu'en build de débogage",
		source.contains("OS.is_debug_build() and _arguments().has(DRAPEAU_SANS_PORTEE_ECRAN)"))
	reglages.accorder_au_mode(true)
	var attendu := PorteeEcran.portee_minimale(PorteeEcran.VUE_UNIQUE, Reglages.ZOOM_DUEL_DEFAUT,
		Reglages.DECALAGE_VISEE_DEFAUT, CameraIso.TANGAGE_DEG)
	_check("en ligne, le plancher se dérive des constantes du duel (%.1f px)" % WeaponData.portee_plancher,
		is_equal_approx(WeaponData.portee_plancher, attendu))
	reglages.accorder_au_mode(false)


## Les dix classes : la portée et l'échelle du cookie disent la même chose, et le plancher ne raccourcit rien.
func _classes(main: Node) -> Array:
	var classes: Array = main._classes
	_check("le catalogue porte dix classes", classes.size() == 10, str(classes.size()))
	var plancher := WeaponData.portee_plancher
	for c: WeaponData in classes:
		var propre := WeaponData.TAILLE_COOKIE_REFERENCE * 0.5 * c.torch_scale * WeaponData.facteur_portee
		var tex := c.get_torch_texture()
		var par_cookie := c.echelle_torche() * float(tex.get_width()) * 0.5 if tex != null else -1.0
		_check("%s : portée %.0f = max(propre %.0f, plancher %.0f), et le cookie l'étale jusque-là (%.0f)"
			% [c.slug(), c.portee_torche(), propre, plancher, par_cookie],
			is_equal_approx(c.portee_torche(), maxf(propre, plancher)) and absf(par_cookie - c.portee_torche()) < 0.01)
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
	# Une seule portée pour tous les modes : en écran scindé, le plancher est celui de la VUE UNIQUE (Q15 révisée :
	# les deux écrans n'ont plus le même zoom — la portée, elle, ne doit pas suivre l'écran).
	var plancher_scinde := WeaponData.portee_plancher
	var attendu_vu := PorteeEcran.portee_minimale(PorteeEcran.VUE_UNIQUE, float(reglages.call("zoom_de_la_vue_unique")),
		float(reglages.decalage_visee), CameraIso.TANGAGE_DEG)
	_check("écran scindé : le plancher est celui de la vue unique (%.1f px)" % plancher_scinde,
		is_equal_approx(plancher_scinde, attendu_vu))
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
	_check("×1,25 : le plancher monte avec l'écran (%.0f px)" % WeaponData.portee_plancher,
		WeaponData.portee_plancher > 800.0)
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
	await _mesurer(main, pres, 0, classes, "vue unique")


func _mesurer(main: Node, pres: Node, pid: int, classes: Array, mode: String) -> void:
	var joueur: Node2D = main.p1 if pid == 0 else main.p2
	var cam: Camera2D = main.cam1 if pid == 0 else main.cam2
	var pire_marge := INF
	var pire_ecart := 0.0
	var mesures := 0
	for k in 8:
		var angle := TAU * float(k) / 8.0 + 0.3
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
		var lampe := joueur.get_node("Flashlight") as PointLight2D
		for c: WeaponData in classes:
			joueur.equip_weapon(c)
			var posee := float(lampe.texture.get_width()) * lampe.texture_scale * 0.5
			pire_marge = minf(pire_marge, posee - au_bord)
			mesures += 1
	_check("%s, J%d (lacet %.0f°) : dans 8 visées, les 10 classes posent de la lumière jusqu'au bord de l'écran (marge la plus courte %.0f px)"
		% [mode, pid + 1, main.lacet_de_la_vue(pid), pire_marge], mesures == 80 and pire_marge >= 0.0)
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
