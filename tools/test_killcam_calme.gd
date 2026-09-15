## La killcam calme — chantier ISO11, L2 (retour d'Adrien au test 1 : « la killcam : les zooms sont intempestifs et
## chaotiques »).
##
## Ce que cette suite prouve, sans fenêtre, sur le VRAI chemin de fin de manche (`GameState._do_end_round`) et en
## mesurant la caméra à chaque image du rejeu :
## - le cadrage (`killcam_cadrage.gd`) : borné au zoom du duel, contenant toutes les positions, un mouvement
##   monotone qui s'arrête au bout de sa durée ;
## - pendant la killcam, la caméra part d'où était celle du duel (aucun saut à la première image), ne fait qu'UN
##   mouvement de zoom (monotone), ne saute jamais d'une image à l'autre, ne porte ni secousse ni décalage de
##   visée, garde les deux fantômes dans le cadre, puis ne bouge plus ;
## - le regard du duel ne touche pas la caméra du rejeu, même quand le joueur rejoué tourne sur lui-même ;
## - la sortie de la killcam rend la caméra au regard du duel.
##
## Ce qu'elle ne prouve pas : l'image. La bande de trente images du photographe (`killcam-bande`) la montre.
extends SceneTree

const PLANCHER := 16
## Le plus grand pas de caméra toléré d'une image à la suivante, en pixels de monde. Sans fenêtre, une image dure
## très peu : ce plafond ne se lit qu'avec le contrôle du départ (aucun saut à la première image) et celui du
## mouvement unique.
const PAS_MAX_PX := 12.0
const PAS_ZOOM_MAX := 0.02

var _failures := 0
var _verifications := 0


## Le mouvement en cours, ou un dictionnaire vide — y compris sur un `GameState` d'avant L2, que la suite doit
## pouvoir mesurer sans planter pour prouver qu'elle le voit.
func _cadre_de(main: Node) -> Dictionary:
	var c: Variant = main.get("_killcam_cadre")
	return c if c is Dictionary else {}


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
	print("=== ISO11, L2 — LA KILLCAM CALME ===")
	await process_frame
	_le_cadrage()

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	main._on_replay_requested()
	_check("la manche démarre", await _depart_fini(main))
	await _la_killcam(main)
	_sortir()


## Le module seul : la cible, le mouvement.
func _le_cadrage() -> void:
	print("\n[Le cadrage, calcul pur]")
	var C: GDScript = load("res://killcam_cadrage.gd")
	var vue := Vector2(1920.0, 1080.0)
	var loin := PackedVector2Array([Vector2(0, 0), Vector2(3000, 0)])
	var pres := PackedVector2Array([Vector2(0, 0), Vector2(10, 10)])
	var c_loin: Dictionary = C.cible(loin, vue, 1.5)
	# Une vue assez grande pour que la boîte minimale (200 px + marges) y tienne au-delà de la borne haute.
	var c_pres: Dictionary = C.cible(pres, Vector2(4000.0, 3000.0), 1.5)
	_check("deux joueurs loin : le zoom tombe à sa borne basse (0,7 × le duel)",
		is_equal_approx(float(c_loin["zoom"]), 0.7 * 1.5), str(c_loin))
	_check("deux joueurs collés : le zoom s'arrête à sa borne haute (1,3 × le duel)",
		is_equal_approx(float(c_pres["zoom"]), 1.3 * 1.5), str(c_pres))
	_check("le centre du cadrage est le centre de la boîte", (c_loin["centre"] as Vector2) == Vector2(1500, 0))
	_check("sans position, aucun cadrage", C.cible(PackedVector2Array(), vue, 1.5).is_empty())

	var cadre: Dictionary = C.preparer(Vector2(100, 100), 1.5, loin, vue, 1.5)
	var zooms: Array[float] = []
	var fin: Array = []
	for i in 200:
		fin = C.avancer(cadre, 1.0 / 60.0)
		zooms.append(float(fin[1]))
	var monotone := true
	for i in range(1, zooms.size()):
		monotone = monotone and zooms[i] <= zooms[i - 1] + 1e-6
	_check("le mouvement est monotone et arrive sur la cible", monotone and (fin[0] as Vector2) == Vector2(1500, 0)
		and is_equal_approx(float(fin[1]), float(c_loin["zoom"])))
	var encore: Array = C.avancer(cadre, 5.0)
	_check("arrivé au bout, il n'en bouge plus", encore == fin)
	var depart: Dictionary = C.preparer(Vector2(100, 100), 1.5, loin, vue, 1.5)
	_check("à t = 0, il est exactement sur la caméra du duel",
		C.avancer(depart, 0.0) == [Vector2(100, 100), 1.5])


func _la_killcam(main: Node) -> void:
	print("\n[La killcam, par _do_end_round]")
	var rejeu := root.get_node("ReplaySystem")
	# Un duel qui BOUGE, et un J1 qui tourne sur lui-même : le regard du duel avancerait sa caméra vers une visée
	# qui change sans cesse — exactement ce qui ne doit plus rien faire pendant le rejeu.
	for joueur in [main.p1, main.p2]:
		(joueur as Node).set_physics_process(false)
	var depart_p1: Vector2 = main.p1.global_position
	for i in 150:
		main.p1.global_position = depart_p1 + Vector2(sin(i * 0.05) * 120.0, 0.0)
		main.p1.rotation = i * 0.35
		main.p2.rotation = -i * 0.2
		await physics_frame
	main._do_end_round(0)
	var fin := Time.get_ticks_msec() + 15000
	var avant_pos: Vector2 = main.cam1.global_position
	var avant_zoom: float = main.cam1.zoom.y
	while not (bool(rejeu.get("playing_back")) and main.current_snap != null):
		if Time.get_ticks_msec() > fin:
			break
		avant_pos = main.cam1.global_position
		avant_zoom = main.cam1.zoom.y
		await process_frame
	_check("la killcam joue", bool(rejeu.get("playing_back")))
	if not bool(rejeu.get("playing_back")):
		return
	_check("le regard du duel est tenu à l'écart du rejeu", main.get("_killcam_cadrage_tenu") == true)

	var positions: Array[Vector2] = []
	var zooms: Array[float] = []
	var offsets_nuls := true
	var hors_pendant := 0
	var hors_apres := 0
	var pire_hors := 0.0
	var boite := Rect2()
	var boite_posee := false
	var rotations_rejouees := 0.0
	var rotation_prec: float = main.p1.rotation
	var vue_node := main.cam1.custom_viewport as Viewport
	var vue: Vector2 = vue_node.get_visible_rect().size if vue_node != null else Vector2(1920.0, 1080.0)
	while bool(rejeu.get("playing_back")) and Time.get_ticks_msec() < fin + 20000:
		await process_frame
		if not bool(rejeu.get("playing_back")):
			break
		positions.append(main.cam1.global_position)
		zooms.append(main.cam1.zoom.y)
		offsets_nuls = offsets_nuls and main.cam1.offset == Vector2.ZERO and main.cam2.offset == Vector2.ZERO
		rotations_rejouees += absf(angle_difference(rotation_prec, main.p1.rotation))
		rotation_prec = main.p1.rotation
		var demi: Vector2 = vue * 0.5 / main.cam1.zoom.y
		var cadre := Rect2(main.cam1.global_position - demi, demi * 2.0)
		var fini := float(_cadre_de(main).get("t", 0.0)) >= 1.0
		for g: Node2D in [main.ghost_p1, main.ghost_p2]:
			if not boite_posee:
				boite = Rect2(g.global_position, Vector2.ZERO)
				boite_posee = true
			boite = boite.expand(g.global_position)
			if not cadre.has_point(g.global_position):
				var proche := Vector2(clampf(g.global_position.x, cadre.position.x, cadre.end.x),
					clampf(g.global_position.y, cadre.position.y, cadre.end.y))
				if fini:
					hors_apres += 1
					pire_hors = maxf(pire_hors, proche.distance_to(g.global_position))
				else:
					hors_pendant += 1
	_check("assez d'images de rejeu mesurées (%d ≥ 30)" % positions.size(), positions.size() >= 30)
	if positions.size() < 30:
		return
	_check("le joueur rejoué tourne pendant la mesure (le regard aurait eu de quoi bouger)",
		rotations_rejouees > 1.0, "%.2f rad" % rotations_rejouees)
	_check("aucun saut à la première image : la killcam part de la caméra du duel",
		positions[0].distance_to(avant_pos) < PAS_MAX_PX and absf(zooms[0] - avant_zoom) < PAS_ZOOM_MAX,
		"%.1f px, zoom %.3f → %.3f" % [positions[0].distance_to(avant_pos), avant_zoom, zooms[0]])
	var pas_max := 0.0
	var pas_zoom_max := 0.0
	var montees := 0
	var descentes := 0
	for i in range(1, positions.size()):
		pas_max = maxf(pas_max, positions[i].distance_to(positions[i - 1]))
		var dz := zooms[i] - zooms[i - 1]
		pas_zoom_max = maxf(pas_zoom_max, absf(dz))
		if dz > 1e-5:
			montees += 1
		elif dz < -1e-5:
			descentes += 1
	_check("aucun saut d'une image à l'autre (pas max %.2f px ≤ %.0f, zoom %.4f ≤ %.2f)"
		% [pas_max, PAS_MAX_PX, pas_zoom_max, PAS_ZOOM_MAX], pas_max <= PAS_MAX_PX and pas_zoom_max <= PAS_ZOOM_MAX)
	_check("un seul mouvement de zoom (%d montées, %d descentes)" % [montees, descentes],
		montees == 0 or descentes == 0)
	_check("ni secousse ni recul pendant le rejeu", offsets_nuls)
	var cadre_vise := _cadre_de(main)
	print("    vue %s ; cible zoom %.3f centre %s ; boîte des fantômes %s ; hors cadre pendant le mouvement %d, après %d (pire %.1f px)"
		% [vue, float(cadre_vise.get("cible_zoom", 0.0)), cadre_vise.get("cible_centre"), boite, hors_pendant,
			hors_apres, pire_hors])
	_check("le mouvement fini, les deux fantômes restent dans le cadre", hors_apres == 0,
		"%d image(s) hors cadre, pire %.1f px" % [hors_apres, pire_hors])
	var cadre_final := _cadre_de(main)
	if float(cadre_final.get("t", 0.0)) >= 1.0:
		var immobile := true
		var n := positions.size()
		for i in range(maxi(1, n - 10), n):
			immobile = immobile and positions[i] == positions[i - 1] and zooms[i] == zooms[i - 1]
		_check("le mouvement fini, la caméra ne bouge plus", immobile)

	# Le gel de fin prolonge le rejeu : la caméra y reste.
	var gel_pos: Vector2 = main.cam1.global_position
	for i in 10:
		await process_frame
	_check("après la lecture, tant que la killcam n'est pas quittée, la caméra reste",
		main.get("_killcam_cadrage_tenu") != true or main.cam1.global_position == gel_pos)
	main._abort_killcam()
	_check("quitter la killcam rend la caméra au regard du duel", main.get("_killcam_cadrage_tenu") == false)
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)


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
