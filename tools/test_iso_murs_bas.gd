## ISO3b — les murs bas et les postures dans la vue iso du duel (brief long d'Adrien, étape D).
##
## `main` a apporté les murs bas et l'accroupi (chantier MURS BAS, MB0 à MB3d). La vue iso doit en
## hériter sans rien réécrire : les murets extrudés à leur hauteur, la zone morte telle que la vue de
## dessus la dessine — dans la lightmap que la vue iso projette au sol, et sur les capteurs qui
## éclairent les corps —, et la posture sur les corps voxel.
##
## Ce que cette suite prouve, sans fenêtre, sur la carte d'essai des murs bas :
## - chaque mur bas de la carte est un muret iso à 0,40 tuile, sur le rectangle exact que la balle et
##   la lumière lisent ; les murs hauts restent à 1,25 tuile ; les hauteurs viennent de map_geometry.gd ;
## - en vue iso, la zone morte se pousse au viewport qui rend le MONDE 2D (la lightmap), plus à
##   l'écran 3D, et le sol et le décor de chaque lightmap la reçoivent dans le repère de celle-ci ;
## - les quatre capteurs la reçoivent dans leur propre écran, jugée au centre du corps et à la hauteur
##   de sa posture, comme le sprite qu'ils remplacent ; leurs shaders portent la règle ;
## - la posture du joueur arrive au corps voxel : accroupi (et sa bascule), enjambement déduit de la
##   position, posture reposée par le rejeu (`poser_posture`) ;
## - `progres_enjambement` : zéro hors des murets, croissant le long de la traversée, dans les deux sens ;
## - aucune `Light3D`.
##
## Ce qu'elle ne prouve pas : l'accord au pixel entre la règle et l'image — le banc
## `tools/banc_murs_bas.gd --iso` le mesure en vraie fenêtre.
extends SceneTree

const PLANCHER := 24
const CARTE := "res://tools/cartes/murs_bas_essai.json"

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
	print("=== ISO3b — LES MURS BAS ET LES POSTURES DANS LA VUE ISO ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	var Pres: GDScript = load("res://presentation_3d.gd")
	var data := _carte()
	_les_boites(data)
	_le_progres(Pres)

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	reglages.mode_iso = true
	main._on_replay_requested()
	_check("la manche iso démarre", await _depart_fini(main))
	# La carte d'essai, posée sous la manche lancée : le chemin de tools/banc_murs_bas.gd.
	root.get_node("MapData").current_map_data = data
	main.rebuild_arena()
	for i in 4:
		await process_frame
	var p := root.get_node_or_null("Presentation3D")
	_check("la vue iso est allumée en écran scindé", p != null and bool(p.get("_actif")) and bool(p.get("_scinde")))
	if p == null:
		reglages.mode_iso = false
		_sortir()
		return
	_check("la carte d'essai porte ses cinq murs bas", (main.murs_bas as Array).size() == 5,
		"%d" % (main.murs_bas as Array).size())
	_la_scene_extrudee(p)
	_la_zone_morte_du_monde(main, p)
	_la_zone_morte_des_capteurs(main, p)
	_les_postures(main, p)
	_check("aucune Light3D dans la vue iso", p.find_children("*", "Light3D", true, false).is_empty())

	reglages.mode_iso = false
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	_sortir()


func _carte() -> Dictionary:
	var json := JSON.new()
	var lisible := json.parse(FileAccess.get_file_as_string(CARTE)) == OK
	var lu: Dictionary = MapCodec.validate(json.data as Dictionary) if lisible else {}
	_check("la carte d'essai des murs bas se lit (%s)" % CARTE, bool(lu.get("ok", false)))
	return lu.get("data", {})


func _les_boites(data: Dictionary) -> void:
	var tuile := float(CandelaTileSet.TILE_SIZE.y)
	var murs := IsoGeometrie.build_meshes(data, StandardMaterial3D.new())
	var bas: Array = []
	var hauts: Array = []
	for b in murs.get_children():
		if String(b.name).begins_with("MurBas"):
			bas.append(b)
		elif String(b.name).begins_with("MurHaut"):
			hauts.append(b)
	var rects := MapGeometry.rects_monde(data, MapGeometry.Kind.LOW_WALLS)
	_check("un muret iso par rectangle de mur bas de la carte (5)", rects.size() == 5 and bas.size() == rects.size(),
		"%d murets pour %d rectangles" % [bas.size(), rects.size()])
	_check("les murets à 0,40 tuile (%.1f px), la hauteur de map_geometry.gd" % [0.4 * tuile],
		is_equal_approx(MapGeometry.HAUTEUR_MUR_BAS, 0.4) and not bas.is_empty()
		and bas.all(func(b): return is_equal_approx((b as Node3D).scale.y, MapGeometry.HAUTEUR_MUR_BAS * tuile)))
	_check("les murs hauts à 1,25 tuile (%.2f px)" % [1.25 * tuile],
		is_equal_approx(MapGeometry.HAUTEUR_MUR_HAUT, 1.25) and not hauts.is_empty()
		and hauts.all(func(b): return is_equal_approx((b as Node3D).scale.y, MapGeometry.HAUTEUR_MUR_HAUT * tuile)))
	var couverts := 0
	for r: Rect2 in rects:
		for b in bas:
			var n := b as Node3D
			if Vector2(n.position.x, n.position.z).distance_to(r.get_center()) < 0.01 \
					and Vector2(n.scale.x, n.scale.z).distance_to(r.size) < 0.01:
				couverts += 1
				break
	_check("chaque muret iso couvre exactement le rectangle que la balle et la lumière lisent (rects_monde)",
		couverts == rects.size(), "%d/%d" % [couverts, rects.size()])
	_check("les hauteurs viennent de map_geometry.gd, plus d'une valeur locale",
		IsoGeometrie.source_des_hauteurs() == "map_geometry.gd", IsoGeometrie.source_des_hauteurs())
	murs.free()


func _le_progres(Pres: GDScript) -> void:
	var minimum := float(Pres.get_script_constant_map()["PROGRES_ENJAMBEMENT_MIN"])
	var r := Rect2(200.0, 100.0, 35.0, 140.0)
	var murs := [r]
	var R := MursBas.RAYON_ENCOMBREMENT
	var y := r.get_center().y
	_check("hors de tout muret, aucun enjambement",
		Pres.progres_enjambement(Vector2(0.0, y), Vector2.RIGHT, murs, false) == 0.0)
	_check("poussé contre un muret sans y être monté, le geste commence",
		is_equal_approx(Pres.progres_enjambement(Vector2(0.0, y), Vector2.RIGHT, murs, true), minimum))
	var suite: Array = []
	var x := r.position.x - R + 1.0
	while x <= r.end.x + R - 1.0:
		suite.append(Pres.progres_enjambement(Vector2(x, y), Vector2.RIGHT, murs, false))
		x += 4.0
	var croissant := suite.size() > 10
	for i in range(1, suite.size()):
		croissant = croissant and float(suite[i]) >= float(suite[i - 1])
	_check("d'ouest en est, le progrès croît le long de la traversée", croissant, str(suite))
	var milieu := float(Pres.progres_enjambement(r.get_center(), Vector2.RIGHT, murs, false))
	_check("entrée près de 0, milieu à 0,5, sortie près de 1",
		float(suite[0]) < 0.05 and absf(milieu - 0.5) < 0.01 and float(suite[-1]) > 0.95,
		"%.3f / %.3f / %.3f" % [float(suite[0]), milieu, float(suite[-1])])
	_check("dans l'autre sens, le même point est une entrée",
		float(Pres.progres_enjambement(Vector2(r.end.x + R - 1.0, y), Vector2.LEFT, murs, false)) < 0.05)


func _la_scene_extrudee(p: Node) -> void:
	var murs := p.get_node_or_null("SceneIso/Murs")
	var bas := 0
	if murs != null:
		for b in murs.get_children():
			if String(b.name).begins_with("MurBas"):
				bas += 1
	_check("en jeu, la scène iso porte les cinq murets de la carte", bas == 5, "%d" % bas)


func _la_zone_morte_du_monde(main: Node, p: Node) -> void:
	var arene := main.arena as Node2D
	for pid in 2:
		var vp: SubViewport = main.vp1 if pid == 0 else main.vp2
		var ecran: Node = main._viewport_du_joueur(pid)
		_check("J%d : en iso, l'écran est la vue 3D, et le monde 2D se rend dans sa lightmap" % (pid + 1),
			main.has_method("_viewport_du_monde") and main._viewport_du_monde(pid) == vp
			and ecran == p.parent_ecran(pid) and ecran != vp)
	main._pousser_zone_morte()
	for pid in 2:
		var vp: SubViewport = main.vp1 if pid == 0 else main.vp2
		var xf: Transform2D = vp.get_final_transform() * vp.get_canvas_transform()
		var u: Dictionary = MursBasRendu.uniformes_de_vue(xf * arene.global_transform, main.murs_bas,
			Rect2(Vector2.ZERO, Vector2(vp.size)))
		var mats: Array = main._materiaux_zone_morte[pid]
		var justes := 0
		for m in mats:
			var sm := m as ShaderMaterial
			if int(sm.get_shader_parameter("mb_nb_murs")) == int(u["nb"]) \
					and sm.get_shader_parameter("mb_murs") == u["murs"] \
					and is_equal_approx(float(sm.get_shader_parameter("mb_zone_morte")), float(u["l_sol"])):
				justes += 1
		_check("J%d : le sol et le décor de sa lightmap reçoivent la zone morte dans le repère de la lightmap" % (pid + 1),
			int(u["nb"]) > 0 and not mats.is_empty() and justes == mats.size(),
			"%d/%d matériaux justes, %d murs dans le champ" % [justes, mats.size(), int(u["nb"])])


func _la_zone_morte_des_capteurs(main: Node, p: Node) -> void:
	var arene := main.arena as Node2D
	var joueurs := [main.p1, main.p2]
	_check("la poussée des capteurs est branchée juste avant le rendu",
		RenderingServer.frame_pre_draw.is_connected(Callable(p, "_pousser_zone_morte_capteurs")))
	joueurs[0].poser_posture(false)
	joueurs[1].poser_posture(true)
	p._pousser_zone_morte_capteurs()
	var capteurs: Array = p.capteurs()
	var justes := 0
	var vus := 0
	for id in 2:
		for j in 2:
			var c = capteurs[id][j]
			if c == null:
				continue
			vus += 1
			var cap := c as CapteurCorps
			var xf: Transform2D = cap.get_final_transform() * cap.get_canvas_transform()
			var u: Dictionary = MursBasRendu.uniformes_de_vue(xf * arene.global_transform, main.murs_bas,
				Rect2(Vector2.ZERO, Vector2(cap.size)))
			var m := cap.matiere() as ShaderMaterial
			var zone := float(u["l_accroupi"]) if j == 1 else 0.0
			if bool(m.get_shader_parameter("mb_au_centre")) \
					and (m.get_shader_parameter("mb_centre") as Vector2).distance_to(xf * (joueurs[j] as Node2D).global_position) < 0.01 \
					and is_equal_approx(float(m.get_shader_parameter("mb_zone_morte")), zone) \
					and int(m.get_shader_parameter("mb_nb_murs")) == int(u["nb"]) \
					and m.get_shader_parameter("mb_murs") == u["murs"]:
				justes += 1
	_check("les quatre capteurs reçoivent la zone morte dans leur écran, au centre du corps, à la hauteur de sa posture (J2 accroupi, J1 debout)",
		vus == 4 and justes == 4, "%d/%d" % [justes, vus])
	for chemin in ["res://capteur_adverse.gdshader", "res://capteur_local.gdshader"]:
		var texte := FileAccess.get_file_as_string(chemin)
		_check("%s porte la règle de la zone morte" % chemin.get_file(),
			texte.contains("#include \"res://murs_bas_zone.gdshaderinc\"")
			and texte.contains("mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)"))
	joueurs[1].poser_posture(false)


func _les_postures(main: Node, p: Node) -> void:
	var j2: Node2D = main.p2
	var depart := j2.global_position
	j2.set_physics_process(false)
	j2.poser_posture(false)
	var debout: Dictionary = p.etat_du_corps(1, j2)
	_check("debout : le corps n'est pas accroupi", debout["accroupi"] == false)
	j2.poser_posture(true)
	var bascule: Dictionary = p.etat_du_corps(1, j2)
	_check("à la bascule, le corps est accroupi et t repart de zéro (transition de %d ms)" % roundi(VoxelCorps.DUREE_TRANSITION_ACCROUPI * 1000.0),
		bascule["accroupi"] == true and float(bascule["t"]) < VoxelCorps.DUREE_TRANSITION_ACCROUPI, "t=%.3f" % float(bascule["t"]))
	j2.poser_posture(false)
	var loin: Dictionary = p.etat_du_corps(1, j2)
	_check("loin des murets, aucun enjambement", float(loin["enjambe"]) == 0.0, "%.3f" % float(loin["enjambe"]))
	var r: Rect2 = main.murs_bas[0]
	j2.global_position = r.get_center()
	var dessus: Dictionary = p.etat_du_corps(1, j2)
	_check("posé sur un muret, le corps enjambe (progrès dans ]0, 1])",
		float(dessus["enjambe"]) > 0.0 and float(dessus["enjambe"]) <= 1.0, "%.3f" % float(dessus["enjambe"]))
	j2.global_position = depart
	# La killcam repose la posture enregistrée sur les joueurs (`game_state.gd`, `poser_posture` depuis
	# `Snapshot.pN_accroupi`) : le corps la lit comme en direct.
	j2.poser_posture(true)
	_check("la posture reposée par le rejeu est celle que lit le corps", p.etat_du_corps(1, j2)["accroupi"] == true)
	(p.get("_voxels")[1] as VoxelCorps).poser(p.etat_du_corps(1, j2))
	j2.poser_posture(false)
	j2.set_physics_process(true)


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


func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
