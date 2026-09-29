extends SceneTree

## Chantier des lumières de la 0.8.0, L2 — la lumière part de la lampe tenue par le modèle 3D, pas du centre du corps.
##
## Ce qu'elle garde :
## - la lentille 2D (`_lentille`) se DÉRIVE du squelette voxel, et la torche y est la même pour les dix
##   classes (aucune n'en redéfinit la place) ;
## - EN JEU, écran scindé à 45° B : pour J1 et J2, dans huit visées, la lampe 2D (lightmap) est au point du sol où finit
##   le fût de la torche voxel (`VoxelCorps.pointe_torche`), à moins d'un demi-pixel ;
## - en vue unique, la lumière 3D miroir de la torche part du même point, à la hauteur de la lentille ;
## - face à un mur, la lampe recule sur le rayon qui mène à la lentille et ne finit jamais dans le mur ; la rétrodiffusion
##   garde sa place d'avant (18 px devant) ;
## - rien sur le fil : `Protocol.VERSION` reste 19.
##
## Lancer : godot --headless --path . --script res://tools/test_lampe_modele.gd

var _failures := 0
## `Player.LENTILLE_LAMPE`, lu par le script : nommer `Player` compilerait `player.gd` avant les autoloads.
var _lentille := Vector2.ZERO
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
	print("=== LA LUMIÈRE PART DE LA LAMPE DU MODÈLE (L2) ===")
	await process_frame
	_lentille = (load("res://player.gd") as GDScript).get_script_constant_map()["LENTILLE_LAMPE"]
	_constantes()
	await _en_jeu()
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _constantes() -> void:
	print("\n--- La lentille, dérivée du squelette ---")
	var s := VoxelCatalogue.SQUELETTE
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var attendu := Vector2((float(s["avant_main"]) + float(s["torche"]["longueur"])) * tuile, -float(s["ecart_main"]) * tuile)
	_check("Player.LENTILLE_LAMPE = bout du fût (avant_main + longueur), à gauche (ecart_main) : %s" % str(_lentille),
		_lentille.is_equal_approx(attendu))
	var memes := true
	for slug in VoxelCatalogue.slugs():
		var f := VoxelCatalogue.fiche(slug)
		for cle in ["avant_main", "ecart_main", "y_main"]:
			memes = memes and is_equal_approx(float(f[cle]), float(s[cle]))
		memes = memes and (f["torche"] as Dictionary) == (s["torche"] as Dictionary)
	_check("la torche est au même endroit pour les dix classes", memes)
	var proto := FileAccess.get_file_as_string("res://protocol.gd")
	_check("rien sur le fil : Protocol.VERSION reste 19", proto.contains("const VERSION := 19"))


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
	if pres == null or not bool(root.get_node("GameSettings").mode_iso):
		_check("la vue iso est allumée", false)
		return
	var joueurs: Array = [main.p1, main.p2]
	for p in joueurs:
		(p as Node).set_physics_process(false)
	var centre: Vector2 = main._carte_px.get_center()
	main.p1.global_position = centre
	main.p2.global_position = centre + Vector2(-140, 70)
	for pid in 2:
		var j: Node2D = joueurs[pid]
		_allumer(j)
		var pire := 0.0
		var vus := 0
		for k in 8:
			var angle := TAU * float(k) / 8.0 + 0.2
			j.rotation = angle
			await process_frame
			await process_frame
			var corps: Node3D = pres._voxels[pid]
			var pointe: Dictionary = corps.call("pointe_torche")
			if pointe.is_empty():
				continue
			vus += 1
			var p3: Vector3 = pointe["position"]
			var lampe := (j.get_node("Flashlight") as Node2D).global_position
			pire = maxf(pire, Vector2(p3.x, p3.z).distance_to(lampe))
		_check("J%d (lacet %.0f°) : dans 8 visées, la lampe 2D est au bout du fût voxel (écart max %.3f px)"
			% [pid + 1, main.lacet_de_la_vue(pid), pire], vus == 8 and pire < 0.5, "%d visées lues" % vus)
	# Vue unique : la lumière 3D miroir. ⚠️ Éteinte par défaut en jeu (`Presentation3D.poser_lumiere_3d`, que seuls
	# les bancs appellent) ; allumée ici pour garder ce qu'elle ferait.
	pres.call("poser_lumiere_3d", true)
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()
	for i in 4:
		await process_frame
	var j1: Node2D = main.p1
	_allumer(j1)
	j1.rotation = 0.7
	for i in 3:
		await process_frame
	var lumieres: Node = pres.get("_lumieres")
	var lampe1 := j1.get_node("Flashlight") as Light2D
	var spot: Node3D = null
	if lumieres != null:
		spot = (lumieres.get("_pool") as Dictionary).get(lampe1.get_instance_id(), null)
	var pointe1: Dictionary = pres._voxels[0].call("pointe_torche")
	if spot == null or pointe1.is_empty():
		_check("vue unique : la lumière 3D de la torche existe", false, "spot %s, pointe %s" % [spot, pointe1])
	else:
		var p3: Vector3 = pointe1["position"]
		var s := spot.global_position
		_check("vue unique : la lumière 3D part de la lentille — au sol (%.3f px) et en hauteur (%.2f contre %.2f px)"
			% [Vector2(s.x, s.z).distance_to(lampe1.global_position), s.y, p3.y],
			Vector2(s.x, s.z).distance_to(lampe1.global_position) < 0.01 and absf(s.y - p3.y) < 0.01)
		_check("debout, la lentille est à hauteur de main (%.1f px) : au-dessus du muret (%.1f), sous le canon de jeu (%.1f)"
			% [p3.y, MursBas.hauteur_mur(), MursBas.hauteur_de_posture(false)],
			p3.y > MursBas.hauteur_mur() and p3.y < MursBas.hauteur_de_posture(false))
	await _mur(main, j1)


## Face à un mur : la lampe recule sur son rayon, jamais dans le mur.
func _mur(main: Node, j: Node2D) -> void:
	var espace := j.get_world_2d().direct_space_state
	var depart := j.global_position
	var mur := Vector2.ZERO
	var direction := Vector2.RIGHT
	for k in 8:
		direction = Vector2.RIGHT.rotated(TAU * float(k) / 8.0)
		var q := PhysicsRayQueryParameters2D.create(depart, depart + direction * 2000.0, MapGeometry.WALL_LAYER)
		q.exclude = [j.get_rid()]
		var coup := espace.intersect_ray(q)
		if not coup.is_empty():
			mur = coup["position"]
			break
	if mur == Vector2.ZERO:
		_check("un mur à viser", false)
		return
	var lampe := j.get_node("Flashlight") as Node2D
	var retro := j.get_node("BodyLight") as Node2D
	# Au large d'abord : la lampe à sa place, la rétrodiffusion à la sienne.
	j.rotation = direction.angle()
	j.call("_rapprocher_la_lampe")
	_check("au large : la lampe à la lentille, la rétrodiffusion à 18 px devant",
		lampe.position.is_equal_approx(_lentille) and is_equal_approx(retro.position.x, 18.0))
	for d in [18.0, 15.0]:
		j.global_position = mur - direction * d
		await physics_frame
		j.call("_rapprocher_la_lampe")
		var dedans := _dans_un_mur(espace, lampe.global_position, j.get_rid())
		var sur_le_rayon := lampe.position.normalized().is_equal_approx(_lentille.normalized())
		_check("à %.0f px d'un mur : la lampe recule (%.1f px du centre, hors du mur), sur son rayon" % [d, lampe.position.length()],
			not dedans and sur_le_rayon and lampe.position.length() < _lentille.length() + 0.01)
		_check("à %.0f px d'un mur : la rétrodiffusion recule comme avant (%.1f px)" % [d, retro.position.x],
			retro.position.x <= 18.0 and retro.position.x >= 4.0 and not _dans_un_mur(espace, retro.global_position, j.get_rid()))
	j.global_position = depart


func _dans_un_mur(espace: PhysicsDirectSpaceState2D, p: Vector2, soi: RID) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.exclude = [soi]
	q.collision_mask = MapGeometry.WALL_LAYER
	return not espace.intersect_point(q, 1).is_empty()


func _allumer(j: Node2D) -> void:
	j.set("flashlight_on", true)
	var l := j.get_node("Flashlight") as Light2D
	l.enabled = true
	l.energy = 2.5


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
