## ISO4 — les objets debout, le leurre, la balle, le viseur et la ligne de visée dans la vue iso (brief
## long d'Adrien, étape E).
##
## Ce que cette suite prouve, sans fenêtre, dans une vraie manche en écran scindé iso :
## - chaque gadget qui a un corps dans le jeu reçoit son voxel (`VoxelObjet`), à sa place et de son slug ;
##   les nappes et volumes restent à plat (aucun miroir) ;
## - le leurre reçoit le corps voxel de la classe de son poseur (`VoxelCorps`) ;
## - la fusée n'a de miroir qu'une fois posée ;
## - chaque miroir lit sa lumière dans un capteur par vue, sur la couche des objets de cette vue, hors
##   des masques des lightmaps, avec le masque et la courbe du sprite remplacé ;
## - les sprites remplacés sortent des lightmaps, et les retrouvent à l'extinction ;
## - le viseur et la ligne de visée ont leur quad dans la vue de leur joueur, et sortent des lightmaps ;
## - un gadget recréé par le rejeu (`is_replay`) reçoit son miroir comme en direct ;
## - aucune `Light3D`.
##
## Ce qu'elle ne prouve pas : l'image — qu'un objet ne cache jamais un corps, que le voxel s'éclaire comme
## son sprite. Le banc `tools/banc_iso.gd --objets` le mesure en vraie fenêtre.
extends SceneTree

const PLANCHER := 30

const GADGETS := {
	"mine": "res://gadget_mine.gd",
	"torche_fantome": "res://gadget_torche_fantome.gd",
	"voile": "res://gadget_voile.gd",
	"ombre": "res://gadget_ombre.gd",
	"gresillement": "res://gadget_gresillement.gd",
	"leurre": "res://gadget_leurre.gd",
}

var _failures := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ %s" % label)
	else:
		_failures += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ISO4 — LES OBJETS DEBOUT DANS LA VUE ISO ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	_les_slugs()

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	reglages.mode_iso = true
	main._on_replay_requested()
	_check("la manche iso démarre", await _depart_fini(main))
	for i in 3:
		await process_frame
	var p := root.get_node_or_null("Presentation3D")
	_check("la vue iso est allumée en écran scindé", p != null and bool(p.get("_actif")) and bool(p.get("_scinde")))
	if p == null:
		reglages.mode_iso = false
		_sortir()
		return
	var miroirs = p.get("_miroirs")
	_check("la présentation porte ses miroirs (MiroirsIso)", miroirs is MiroirsIso)
	if not miroirs is MiroirsIso:
		reglages.mode_iso = false
		_sortir()
		return

	var poses := await _poser_les_gadgets(main)
	_les_miroirs(main, miroirs, poses)
	_les_capteurs(main, miroirs, poses)
	await _la_fusee(main, miroirs)
	await _les_quads(main, miroirs)
	await _le_rejeu(main, miroirs)
	_check("aucune Light3D dans la vue iso", p.find_children("*", "Light3D", true, false).is_empty())

	# L'extinction rend tout.
	var leurre: Node = poses["leurre"]
	reglages.mode_iso = false
	for i in 4:
		await process_frame
	_check("à l'extinction, plus aucun miroir", (miroirs as MiroirsIso).nombre_de_miroirs() == 0)
	var rendus := 0
	for slug in poses:
		for nom in MiroirsIso.SPRITES_REMPLACES[slug]:
			var s := (poses[slug] as Node).get_node_or_null(NodePath(nom)) as CanvasItem
			if s != null and s.visibility_layer != Presentation3D.COUCHE_HORS_VUE:
				rendus += 1
	_check("à l'extinction, chaque sprite remplacé retrouve sa couche", rendus == _sprites_attendus(poses),
		"%d/%d" % [rendus, _sprites_attendus(poses)])
	_check("à l'extinction, le leurre est de nouveau vu par l'adversaire en 2D (couche de sa vue)",
		(leurre.get_node("Visuel") as CanvasItem).visibility_layer == GadgetBase.couche_de_vue(1 - int(leurre.get("poseur_id"))))
	_check("à l'extinction, la ligne de visée et le viseur de J1 reviennent dans sa vue (couche 2)",
		(main.p1.aim_line as CanvasItem).visibility_layer == 2
		and (main.p1.get_node("Viseur") as CanvasItem).visibility_layer == 2)
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	_sortir()


func _les_slugs() -> void:
	for slug in VoxelCatalogueObjets.OBJETS:
		var g := GadgetBase.new()
		g.slug = slug
		_check("« %s » a un corps : il reçoit un miroir" % slug, MiroirsIso.slug_objet(g) == slug)
		g.free()
	for slug in VoxelCatalogueObjets.SLUGS_SANS_VOXEL:
		var g := GadgetBase.new()
		g.slug = slug
		_check("« %s » reste à plat dans la lightmap" % slug, MiroirsIso.slug_objet(g) == "")
		g.free()
	_check("les couches des objets sortent des lightmaps avec celles des corps (128 et 256)",
		(Presentation3D.COUCHES_CAPTEURS & MiroirsIso.couche_objets(0)) != 0
		and (Presentation3D.COUCHES_CAPTEURS & MiroirsIso.couche_objets(1)) != 0
		and MiroirsIso.couche_objets(0) == 128 and MiroirsIso.couche_objets(1) == 256)


func _poser_les_gadgets(main: Node) -> Dictionary:
	var poses := {}
	var x := 300.0
	var numero := 900
	for slug in GADGETS:
		var g: GadgetBase = (load(GADGETS[slug]) as GDScript).new()
		g.slug = slug
		g.name = "GadgetJ1_%d" % numero
		g.poseur_id = 0
		g.classe_du_poseur = main.p1.current_weapon
		g.position = Vector2(x, 420.0)
		g.rotation = 0.3
		main.bullet_container.add_child(g)
		poses[slug] = g
		x += 70.0
		numero += 1
	for i in 3:
		await process_frame
	return poses


func _les_miroirs(main: Node, miroirs: MiroirsIso, poses: Dictionary) -> void:
	var justes := 0
	for slug in poses:
		var g: Node2D = poses[slug]
		var voxel: Node3D = miroirs.miroir_de(g)
		var bon_type := voxel is VoxelCorps if slug == "leurre" else voxel is VoxelObjet
		var bon_slug := false
		if voxel is VoxelObjet:
			bon_slug = (voxel as VoxelObjet).slug() == slug
		elif voxel is VoxelCorps:
			bon_slug = (voxel as VoxelCorps).slug() == String((main.p1.current_weapon as ClassData).slug())
		var place := voxel != null and Vector2(voxel.global_position.x, voxel.global_position.z).distance_to(g.global_position) < 0.05
		if bon_type and bon_slug and place:
			justes += 1
		else:
			printerr("    %s : type=%s slug=%s place=%s" % [slug, bon_type, bon_slug, place])
	_check("chaque gadget posé a son miroir, de son slug et à sa place (le leurre : le corps de la classe du poseur)",
		justes == poses.size(), "%d/%d" % [justes, poses.size()])
	var retires := 0
	for slug in poses:
		for nom in MiroirsIso.SPRITES_REMPLACES[slug]:
			var s := (poses[slug] as Node).get_node_or_null(NodePath(nom)) as CanvasItem
			if s != null and s.visibility_layer == Presentation3D.COUCHE_HORS_VUE:
				retires += 1
	_check("les sprites remplacés sortent des lightmaps", retires > 0 and retires == _sprites_attendus(poses),
		"%d/%d" % [retires, _sprites_attendus(poses)])
	var toile := (poses["voile"] as Node).get_node_or_null(^"Visuel") as CanvasItem
	_check("la toile du voile reste à plat dans la lightmap", toile != null and toile.visibility_layer != Presentation3D.COUCHE_HORS_VUE)
	_check("les voxels sont tous sous la scène iso (aucun nœud 3D sous le jeu)",
		main.find_children("*", "VoxelObjet", true, false).is_empty() and main.find_children("*", "VoxelCorps", true, false).is_empty())


func _les_capteurs(main: Node, miroirs: MiroirsIso, poses: Dictionary) -> void:
	var masques := [(main.vp1 as SubViewport).canvas_cull_mask, (main.vp2 as SubViewport).canvas_cull_mask]
	var justes := 0
	var total := 0
	for slug in poses:
		var g: Node = poses[slug]
		var capteurs: Array = miroirs.capteurs_de(g)
		for id in 2:
			total += 1
			var c = capteurs[id]
			if c == null:
				continue
			var cap := c as CapteurCorps
			var shader: Shader = (cap.matiere() as ShaderMaterial).shader
			var masque_attendu := MapGeometry.WALL_LAYER
			var shader_attendu: Shader = MiroirsIso.SHADER_OBJET
			if slug == "leurre":
				if id == int(g.get("poseur_id")):
					masque_attendu = 4
				else:
					masque_attendu = CanauxLumiere.masque_vue_adverse(int(g.get("poseur_id")))
					shader_attendu = CapteurCorps.SHADER_ADVERSE
			if cap.couche() == MiroirsIso.couche_objets(id) and (masques[0] & cap.couche()) == 0 \
					and (masques[1] & cap.couche()) == 0 and cap.masque_lumiere() == masque_attendu \
					and shader == shader_attendu:
				justes += 1
			else:
				printerr("    %s vue %d : couche=%d masque=%d shader=%s" % [slug, id + 1, cap.couche(), cap.masque_lumiere(), shader.resource_path])
	_check("un capteur par vue pour chaque miroir, sur la couche des objets hors des lightmaps, avec le masque et la courbe du sprite remplacé",
		justes == total, "%d/%d" % [justes, total])
	# Raccords de la vague « grand budget » — l'encre des arêtes d'ISO7 et d'ISO Corps (vague 5) sur les
	# objets debout et le leurre, par le même crochet que les corps (`IsoMateriaux.accorder_corps`).
	var encres := 0
	for slug in poses:
		var voxel: Node3D = miroirs.miroir_de(poses[slug] as Node)
		var mat: ShaderMaterial = voxel.call("materiau") if voxel != null else null
		if mat != null and is_equal_approx(float(mat.get_shader_parameter("encre_arete")),
				IsoMateriaux.ENCRE_VOXEL_PX if IsoMateriaux.beaute_active() else 0.0) \
				and is_equal_approx(float(mat.get_shader_parameter("encre_reste")), IsoMateriaux.ENCRE_VOXEL_RESTE):
			encres += 1
		else:
			printerr("    %s : encre absente du matériau du miroir" % slug)
	_check("les miroirs des objets et du leurre portent l'encre des arêtes des corps (IsoMateriaux.accorder_corps)",
		encres == poses.size(), "%d/%d" % [encres, poses.size()])
	# Et la température de la lumière sur les nuages : la teinte chaude du sol et des murs (ISO7).
	var volumes := IsoVolumes.new()
	var mat_volume: ShaderMaterial = volumes.call("_materiau_volume")
	_check("les nuages prennent la température de la lumière du sol (IsoMateriaux.TEMPERATURE)",
		is_equal_approx(float(mat_volume.get_shader_parameter("temperature")),
			IsoMateriaux.TEMPERATURE if IsoMateriaux.beaute_active() else 0.0)
		and (IsoVolumes.SHADER_VOLUME as Shader).code.contains("pate_temperature(c, temperature)"))
	volumes.free()


func _la_fusee(main: Node, miroirs: MiroirsIso) -> void:
	main._do_spawn_fusee(0, Vector2(500.0, 520.0), 0.0, 4242)
	var f := main.bullet_container.get_node_or_null(^"FuseeJ1_4242") as Node
	for i in 2:
		await process_frame
	_check("la fusée est lancée", f != null)
	if f == null:
		return
	f.set("_atterrie", false)
	for i in 2:
		await process_frame
	_check("en vol, la fusée n'a pas de miroir", miroirs.miroir_de(f) == null)
	f.call("forcer_age", 0.5)
	for i in 2:
		await process_frame
	var voxel: Node3D = miroirs.miroir_de(f)
	_check("posée, la fusée a son miroir", voxel is VoxelObjet and (voxel as VoxelObjet).slug() == "fusee")
	_check("posée, son cœur et son corps sortent des lightmaps",
		(f.get_node("Coeur") as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE
		and (f.get_node("Corps") as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE)


func _les_quads(main: Node, miroirs: MiroirsIso) -> void:
	# ⚠️ **Les joueurs figés le temps de la mesure.** Relu juste après `process_frame`, un viseur a déjà
	# tourné avec la physique de l'image, et son quad sera reposé par la présentation (dernière du
	# `_process`) avant le rendu — pas encore au moment de la lecture. Vert seul, rouge dans le lot, dont
	# le foyer déplafonne la cadence (premier lot d'ISO4) : on mesure donc des joueurs qui ne bougent plus.
	for joueur in [main.p1, main.p2]:
		(joueur as Node).set_physics_process(false)
		(joueur as Node).set_process(false)
	for i in 3:
		await process_frame
	for j in 2:
		var joueur: Node = main.p1 if j == 0 else main.p2
		var q: Dictionary = miroirs.quads_du_joueur(j)
		var calque := Presentation3D._calque_de(j)
		_check("J%d : la ligne de visée et le viseur ont leur quad au calque de sa vue (%d)" % [j + 1, calque],
			q.has("ligne") and q.has("viseur") and (q["ligne"] as MeshInstance3D).layers == calque
			and (q["viseur"] as MeshInstance3D).layers == calque)
		_check("J%d : la ligne de visée et le viseur sortent des lightmaps" % (j + 1),
			(joueur.aim_line as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE
			and (joueur.get_node("Viseur") as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE)
		var viseur := joueur.get_node("Viseur") as Node2D
		var mi: MeshInstance3D = q["viseur"]
		_check("J%d : le quad du viseur est posé au sol, sous le viseur" % (j + 1),
			Vector2(mi.global_position.x, mi.global_position.z).distance_to(viseur.global_position) < 0.05
			and absf(mi.global_position.y - MiroirsIso.HAUTEUR_QUAD_PX) < 0.01)
	for joueur in [main.p1, main.p2]:
		(joueur as Node).set_physics_process(true)
		(joueur as Node).set_process(true)
	# Le contrôle (b) du noir absolu retire ces quads avec le reste de la 2D, puis les rend.
	miroirs.masquer_les_quads(true)
	for i in 2:
		await process_frame
	var caches := true
	for j in 2:
		for mi in miroirs.quads_du_joueur(j).values():
			caches = caches and not (mi as MeshInstance3D).visible
	_check("masquer_les_quads garde cachés viseurs et lignes de visée (contrôle (b) du noir absolu)", caches)
	miroirs.masquer_les_quads(false)
	for i in 2:
		await process_frame
	_check("et les rend quand le contrôle est fini", (miroirs.quads_du_joueur(0)["viseur"] as MeshInstance3D).visible)


func _le_rejeu(main: Node, miroirs: MiroirsIso) -> void:
	var g: GadgetBase = (load(GADGETS["mine"]) as GDScript).new()
	g.slug = "mine"
	g.name = "GadgetJ2_990"
	g.poseur_id = 1
	g.is_replay = true
	g.position = Vector2(640.0, 600.0)
	main.bullet_container.add_child(g)
	for i in 2:
		await process_frame
	_check("un gadget recréé par le rejeu reçoit son miroir comme en direct", miroirs.miroir_de(g) is VoxelObjet)
	var n := miroirs.nombre_de_miroirs()
	g.queue_free()
	for i in 3:
		await process_frame
	_check("un gadget libéré perd son miroir", miroirs.nombre_de_miroirs() == n - 1)


static func _sprites_attendus(poses: Dictionary) -> int:
	var n := 0
	for slug in poses:
		for nom in MiroirsIso.SPRITES_REMPLACES[slug]:
			if (poses[slug] as Node).get_node_or_null(NodePath(nom)) != null:
				n += 1
	return n


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
