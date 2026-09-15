## ISO5 — la killcam, le rejeu et les entrées dans la vue iso (brief d'Adrien, étape F).
##
## Ce que cette suite prouve, sans fenêtre, dans une vraie manche en écran scindé iso puis sur le VRAI
## chemin de fin de manche (`GameState._do_end_round`) :
## - la visée souris par la caméra iso : projection aller-retour monde → écran → sol à moins de 0,5 px,
##   dans la vue de chaque joueur, en écran scindé puis en vue unique ; la commande de visée est la même
##   direction du monde qu'en vue de dessus ; le stick est tourné du lacet (0° : l'identité, prouvée par
##   le vrai chemin de `LocalInputProvider`) ; rien de la vue ne voyage sur le fil ;
## - pendant la killcam, les fantômes nommés `GhostP1`/`GhostP2` portent les corps voxel : visibles alors
##   que les sprites des joueurs sont cachés, à la place du fantôme, de la classe et dans les états de
##   l'instantané rejoué, composés comme le fantôme 2D (aucune part éclairée, sa silhouette dans chaque
##   vue qui voit sa couche), son sprite retiré des lightmaps ;
## - le zoom de la killcam (0,7 à 2,8) devient la taille orthographique de la caméra iso, autour du même
##   point ;
## - le voile de killcam lit la vue iso (calque plein écran partageant le matériau du voile 2D, retiré des
##   lightmaps) ;
## - les gadgets recréés par le rejeu gardent leur miroir ;
## - l'extinction rend les couches du fantôme et du voile.
##
## Ce qu'elle ne prouve pas : l'image. Le banc `tools/banc_iso.gd --killcam` la mesure en vraie fenêtre.
extends SceneTree

const PLANCHER := 30
const TOLERANCE_PX := 0.5

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
	print("=== ISO5 — LA KILLCAM, LE REJEU ET LES ENTRÉES DANS LA VUE ISO ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	_le_fil()
	_le_lacet()

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
	var p := root.get_node_or_null("Presentation3D") as Presentation3D
	_check("la vue iso est allumée en écran scindé", p != null and bool(p.get("_actif")) and bool(p.get("_scinde")))
	if p == null:
		reglages.mode_iso = false
		_sortir()
		return

	print("\n[Les entrées, écran scindé]")
	await _les_entrees(main, p)
	print("\n[La killcam, par _do_end_round]")
	await _la_killcam(main, p)

	# L'extinction rend tout.
	var trace := main.ghost_p1.get_node("VisualColored") as CanvasItem
	reglages.mode_iso = false
	for i in 4:
		await process_frame
	_check("à l'extinction, le sprite du fantôme retrouve sa couche (1)", trace.visibility_layer == 1,
		str(trace.visibility_layer))
	_check("à l'extinction, le voile de killcam 2D retrouve sa couche (1)",
		(main.ui.killcam_overlay as CanvasItem).visibility_layer == 1)
	_check("à l'extinction, plus de voile iso", p.voile_de_killcam(0) == null and p.voile_de_killcam(1) == null)
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	_sortir()


## Rien de la vue ne voyage : aucun RPC dans le code de la vue iso ni dans la visée, `NetworkInputProvider`
## ignore tout de l'iso, la commande garde sa forme et le protocole sa version.
func _le_fil() -> void:
	for chemin in ["res://presentation_3d.gd", "res://miroirs_iso.gd", "res://camera_iso.gd", "res://local_input_provider.gd"]:
		var texte := FileAccess.get_file_as_string(chemin)
		_check("%s n'émet rien sur le fil (ni rpc, ni multiplayer)" % chemin.get_file(),
			texte != "" and not texte.contains("rpc") and not texte.contains("multiplayer"))
	var reseau := FileAccess.get_file_as_string("res://network_input_provider.gd")
	_check("NetworkInputProvider ignore tout de la vue iso",
		reseau != "" and not reseau.to_lower().contains("iso") and not reseau.contains("Presentation3D"))
	var version = (load("res://protocol.gd") as GDScript).get_script_constant_map().get("VERSION")
	_check("Protocol.VERSION reste 18", version == 18, str(version))


## Le stick tourné du lacet : sa droite vise la droite de l'écran, son bas le bas de l'écran, à tout lacet.
func _le_lacet() -> void:
	var justes := 0
	for lacet in [0.0, 30.0, 90.0, -45.0]:
		var base := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(1920, 1080), CameraIso.TANGAGE_DEG, lacet).basis
		for stick: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
			var d := CameraIso.stick_au_sol(stick, lacet)
			var ecran := Vector2(d.x * base.x.x + d.y * base.x.z, -(d.x * base.y.x + d.y * base.y.z))
			var ok := ecran.normalized().distance_to(stick) < 1e-4
			if ok:
				justes += 1
			else:
				printerr("    lacet %s, stick %s → écran %s" % [lacet, stick, ecran])
	_check("le stick tourné du lacet vise la même direction à l'écran (4 lacets, 2 axes)", justes == 8, "%d/8" % justes)
	_check("à 0° (valeur actée), le stick est inchangé", CameraIso.stick_au_sol(Vector2(0.3, -0.9), 0.0) == Vector2(0.3, -0.9))


func _les_entrees(main: Node, p: Presentation3D) -> void:
	for joueur in [main.p1, main.p2]:
		(joueur as Node).set_physics_process(false)
	for i in 3:
		await process_frame
	var pire := 0.0
	var dans_sa_vue := true
	for pid in 2:
		var joueur: Node2D = main.p1 if pid == 0 else main.p2
		var cadre: Rect2 = p._cadre(pid)
		for decalage: Vector2 in [Vector2.ZERO, Vector2(130.0, -90.0), Vector2(-210.0, 160.0)]:
			var w := joueur.global_position + decalage
			var ecran: Vector2 = p.projecteur_ecran(pid).call(w) + cadre.position
			var sol = p.point_au_sol(joueur, ecran)
			pire = maxf(pire, (sol as Vector2).distance_to(w) if sol is Vector2 else INF)
			# La même position de souris lue par l'AUTRE joueur tombe ailleurs : chacun vise par sa vue.
			var autre: Node2D = main.p2 if pid == 0 else main.p1
			var sol_autre = p.point_au_sol(autre, ecran)
			dans_sa_vue = dans_sa_vue and sol_autre is Vector2 and (sol_autre as Vector2).distance_to(w) > 10.0
	_check("écran scindé : monde → écran → sol à moins de %.1f px, dans la vue de chaque joueur" % TOLERANCE_PX,
		pire < TOLERANCE_PX, "écart max %.4f px" % pire)
	_check("écran scindé : chaque joueur vise par SA caméra, dans son cadre", dans_sa_vue)

	# La commande : la direction du monde vers le point visé, la même qu'en vue de dessus.
	var prov := main.p1.input_provider as LocalInputProvider
	var cible: Vector2 = main.p1.global_position + Vector2(170.0, 60.0)
	var ecran_cible: Vector2 = p.projecteur_ecran(0).call(cible) + p._cadre(0).position
	var vise = prov.cible_de_la_souris(ecran_cible)
	var visee_iso: Vector2 = main.p1.global_position.direction_to(vise) if vise is Vector2 else Vector2.ZERO
	var visee_2d: Vector2 = main.p1.global_position.direction_to(cible)
	_check("la commande de visée souris en iso est la direction du monde qu'aurait la vue de dessus",
		absf(visee_iso.angle_to(visee_2d)) < 0.005 and visee_iso.length() > 0.99,
		"%s contre %s" % [visee_iso, visee_2d])

	# Le stick, par le vrai chemin de LocalInputProvider : à 0° la commande est celle de l'Input Map.
	Input.action_press("p1_aim_right", 1.0)
	Input.action_press("p1_aim_down", 0.5)
	var brut := Input.get_vector(prov.action_aim_left, prov.action_aim_right, prov.action_aim_up, prov.action_aim_down)
	var par_le_chemin := prov.get_aim_direction(main.p1.global_position)
	Input.action_release("p1_aim_right")
	Input.action_release("p1_aim_down")
	_check("le stick en vue iso : la commande est exactement celle de la vue de dessus (lacet 0°)",
		brut.length() > 0.1 and par_le_chemin == brut, "%s contre %s" % [par_le_chemin, brut])
	for joueur in [main.p1, main.p2]:
		(joueur as Node).set_physics_process(true)


func _la_killcam(main: Node, p: Presentation3D) -> void:
	var rejeu := root.get_node("ReplaySystem")
	main._do_spawn_gadget(0, main.p1.global_position + Vector2(90.0, 0.0), 0.0, "torche_fantome", 9101)
	var pose: Node = main.bullet_container.get_node_or_null(^"GadgetJ1_9101")
	_check("un gadget est posé par le vrai chemin avant la killcam (torche fantôme)", pose != null)
	if pose != null:
		# Charge constante, comme le banc de cadence : la durée de vie du profil de la classe tuerait le
		# gadget avant la fenêtre du rejeu.
		pose.set("duree_vie", 0.0)
	await create_timer(1.2).timeout
	main._do_end_round(0)
	var fin := Time.get_ticks_msec() + 12000
	while not (bool(rejeu.get("playing_back")) and main.current_snap != null and main.ghost_p1.visible):
		if Time.get_ticks_msec() > fin:
			break
		await process_frame
	_check("la killcam joue (ReplaySystem.playing_back, instantané, fantômes montrés)",
		bool(rejeu.get("playing_back")) and main.current_snap != null and main.ghost_p1.visible)
	for i in 3:
		await process_frame
	if not bool(rejeu.get("playing_back")):
		return
	_check("la killcam passe la vue iso en vue unique", bool(p.get("_actif")) and not bool(p.get("_scinde")))
	_check("les fantômes sont nommés explicitement (GhostP1, GhostP2)",
		main.ghost_p1.name == "GhostP1" and main.ghost_p2.name == "GhostP2")
	_check("les sprites des vrais joueurs sont cachés par le rejeu", not main.p1.visual.visible and not main.p2.visual.visible)

	var snap = main.current_snap
	var corps: Array = p.get("_corps")
	var voxels: Array = p.get("_voxels")
	var etats: Array = p.get("_etats_fantomes")
	var mats: Array = p.get("_mat_corps")
	var profondeurs: Array = p.get("_mat_profondeur")
	for j in 2:
		var fantome: Node2D = main.ghost_p1 if j == 0 else main.ghost_p2
		var n := "p%d_" % (j + 1)
		if not fantome.visible:
			_check("J%d : fantôme caché (mort dans le rejeu), corps caché" % (j + 1), not (corps[j] as Node3D).visible)
			continue
		_check("J%d : le fantôme porte le corps (fantome_montre)" % (j + 1), p.fantome_montre(j) == fantome)
		_check("J%d : le corps voxel reste visible pendant la lecture, sprite du joueur caché" % (j + 1),
			(corps[j] as Node3D).visible)
		var voxel := voxels[j] as VoxelCorps
		var pos := voxel.global_position
		_check("J%d : le corps est posé à la place du fantôme" % (j + 1),
			Vector2(pos.x, pos.z).distance_to(fantome.global_position) < 0.05,
			"%s contre %s" % [pos, fantome.global_position])
		_check("J%d : le corps est de la classe de l'instantané rejoué" % (j + 1),
			voxel.slug() == Presentation3D.slug_de_la_classe(snap.get(n + "weapon")), voxel.slug())
		var e: Dictionary = etats[j]
		_check("J%d : posture et torche du corps sont celles de l'instantané" % (j + 1),
			bool(e.get("accroupi", not snap.get(n + "accroupi"))) == bool(snap.get(n + "accroupi"))
			and bool(e.get("torche", not snap.get(n + "light"))) == bool(snap.get(n + "light")))
		var trace := fantome.get_node("VisualColored") as Polygon2D
		# ISO6 — la couleur atténuée sur l'étalon du fantôme 2D (`Presentation3D.ATTENUATION_FANTOME`), la
		# couverture inchangée. La constante est relue ICI dans la fourchette mesurée : un retour à 1,0 (le
		# fantôme quatre fois trop clair) rougit.
		var k := Presentation3D.ATTENUATION_FANTOME
		var attendue := Color(trace.color.r * k, trace.color.g * k, trace.color.b * k,
			trace.color.a * Presentation3D.opacite_rendue(trace))
		_check("J%d : l'atténuation du fantôme iso est dans la fourchette de l'étalon 2D (0,24 à 0,27, ISO5)" % (j + 1),
			k >= 0.2 and k <= 0.3, str(k))
		var composes := true
		for m in [mats[j], profondeurs[j]]:
			for vue in [1, 2]:
				composes = composes and is_equal_approx(float((m as ShaderMaterial).get_shader_parameter("opacite_%d" % vue)), 0.0) \
					and ((m as ShaderMaterial).get_shader_parameter("silhouette_%d" % vue) as Color).is_equal_approx(attendue)
		_check("J%d : composé comme le fantôme 2D — aucune part éclairée, sa silhouette (a=%.2f) dans les deux vues, sur les deux passes"
			% [j + 1, attendue.a], composes and attendue.a > 0.3)
		_check("J%d : le sprite du fantôme et son pointeur sortent des lightmaps" % (j + 1),
			trace.visibility_layer == Presentation3D.COUCHE_HORS_VUE
			and (trace.get_node("DirPointer") as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE
			and p.couche_d_origine(trace) == 1)
	_check("une silhouette de fantôme est transparente dans une vue dont le masque ne voit pas sa couche",
		Presentation3D.silhouette_du_fantome(main.ghost_p1.get_node("VisualColored"), 1, ~1).a == 0.0)

	# Le voile de killcam lit la vue iso.
	var voile := p.voile_de_killcam(0)
	var voile_2d := main.ui.killcam_overlay as CanvasItem
	_check("le voile de killcam iso est posé et montré avec le voile 2D", voile != null and voile.visible and voile_2d.visible)
	_check("il partage le matériau du voile 2D (mêmes uniformes poussés par ui.gd)",
		voile != null and (voile.get_child(0) as CanvasItem).material == voile_2d.material)
	_check("en vue unique, il s'attache à la fenêtre, sous les calques du jeu",
		voile != null and voile.get_parent() == p and voile.layer < 1)
	_check("le voile 2D sort de la lightmap (il y lirait le sol projeté, pas la vue)",
		voile_2d.visibility_layer == Presentation3D.COUCHE_HORS_VUE)

	# Les gadgets rejoués gardent leur miroir. ⚠️ Sans impact enregistré, la fenêtre du rejeu commence ~180
	# images avant la fin de l'enregistrement, donc un peu AVANT la pose : la copie n'apparaît qu'une fois
	# le rejeu arrivé à l'instant de la pose. On l'attend, puis on laisse la présentation la suivre.
	var miroirs := p.get("_miroirs") as MiroirsIso
	var rejoues := 0
	var avec_miroir := 0
	var fin_rejeu := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < fin_rejeu and bool(rejeu.get("playing_back")):
		if main.bullet_container.get_children().any(func(c): return "is_replay" in c and bool(c.get("is_replay"))):
			break
		await process_frame
	for i in 3:
		await process_frame
	for c in main.bullet_container.get_children():
		if "is_replay" in c and bool(c.get("is_replay")) and MiroirsIso.slug_objet(c) != "":
			rejoues += 1
			if miroirs.miroir_de(c) != null:
				avec_miroir += 1
	_check("les gadgets recréés par la killcam ont leur miroir", rejoues > 0 and avec_miroir == rejoues,
		"%d/%d" % [avec_miroir, rejoues])

	# La souris en vue unique, pendant la killcam.
	var w: Vector2 = main.ghost_p1.global_position + Vector2(-60.0, 45.0)
	var ecran: Vector2 = p.projecteur_ecran(0).call(w)
	var sol = p.point_au_sol(main.p1, ecran)
	_check("vue unique : monde → écran → sol à moins de %.1f px" % TOLERANCE_PX,
		sol is Vector2 and (sol as Vector2).distance_to(w) < TOLERANCE_PX, str(sol))
	_check("vue unique : le joueur dont la vue n'est pas regardée garde la visée de la vue de dessus",
		p.point_au_sol(main.p2, ecran) == null)

	# Le zoom de la killcam devient la taille orthographique, autour du même point. Le jeu est suspendu le
	# temps de la mesure : sinon la killcam réécrit le zoom à chaque image.
	main.set_process(false)
	var camera: CameraIso = p.get("_camera")
	var vue: SubViewport = main.vp1
	var justes := 0
	for z in [0.7, 1.0, 2.8]:
		main.cam1.zoom = Vector2(z, z)
		for i in 4:
			await process_frame
		var taille := Vector2(vue.size_2d_override) if vue.size_2d_override != Vector2i.ZERO else Vector2(vue.size)
		var attendue := CameraIso.taille_orthographique(CameraIso.TANGAGE_DEG, taille.y / z)
		var centre := CameraIso.centre_de_vue(vue.canvas_transform, taille)
		var sous_la_camera := camera.vers_sol(taille * 0.5, taille)
		var ok := absf(camera.size - attendue) < 0.01 and centre.distance_to(main.cam1.get_screen_center_position()) < 1.0 \
			and sous_la_camera.distance_to(centre) < TOLERANCE_PX
		if ok:
			justes += 1
		else:
			printerr("    zoom %.1f : size %.3f pour %.3f ; centre %s, caméra 2D %s, sous la caméra iso %s"
				% [z, camera.size, attendue, centre, main.cam1.get_screen_center_position(), sous_la_camera])
	main.set_process(true)
	_check("le zoom de la killcam (0,7 / 1 / 2,8) devient la taille orthographique, autour du même point",
		justes == 3, "%d/3" % justes)


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
