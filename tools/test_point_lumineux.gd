extends SceneTree

## Chantier des lumières de la 0.8.0, L3 — le point lumineux à la lentille de la torche tenue (Q46).
##
## Ce qu'elle garde (headless : sans pixel ; l'occultation par le corps et les murs se prouve à l'image,
## `tools/banc_lumieres.gd --plans=l3`) :
## - allumé par défaut, `--sans-point-lumineux` en build de débogage seulement ;
## - la formule d'orientation du shader EST celle de `IsoVolumes.visibilite_lentille` (mêmes bornes) ;
## - de face pleine, de dos nulle, pour la caméra de J1 comme pour celle de J2 (45° B) — et à situation miroir, la même ;
## - EN JEU, écran scindé : la lampe allumée pose deux lueurs au bout du fût voxel de CHAQUE joueur, orientées comme la
##   torche, à l'énergie de la lampe ; lampe éteinte, plus rien ;
## - une image seulement : couper toutes les lueurs ne change ni les lumières 2D ni rien de ce que lit la simulation.
##
## Lancer : godot --headless --path . --script res://tools/test_point_lumineux.gd

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
	print("=== LE POINT LUMINEUX À LA LENTILLE (L3) ===")
	await process_frame
	_regles()
	await _en_jeu()
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _regles() -> void:
	print("\n--- La règle et la formule ---")
	var v := IsoVolumes.new()
	_check("allumé par défaut", v.point_lumineux)
	v.free()
	var source := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("--sans-point-lumineux ne vaut qu'en build de débogage",
		source.contains("elif arg == DRAPEAU_SANS_POINT_LUMINEUX and OS.is_debug_build():"))
	var shader := FileAccess.get_file_as_string("res://halo_iso.gdshaderinc")
	_check("le shader recopie les bornes de `visibilite_lentille` (%.2f, %.2f)" % [IsoVolumes.LENTILLE_DOS, IsoVolumes.LENTILLE_FACE],
		shader.contains("const float LENTILLE_DOS = %s;" % _nombre(IsoVolumes.LENTILLE_DOS))
		and shader.contains("const float LENTILLE_FACE = %s;" % _nombre(IsoVolumes.LENTILLE_FACE))
		and shader.contains("smoothstep(LENTILLE_DOS, LENTILLE_FACE, dot(normalize(direction_lentille), normalize(INV_VIEW_MATRIX[2].xyz)))"))
	_check("les autres lueurs ne sont pas pesées (`lentille_orientee` faux par défaut)",
		shader.contains("uniform bool lentille_orientee = false;"))
	# Les caméras de J1 (45°) et J2 (225°) : même tangage, lacet opposé.
	for lacet in [45.0, 225.0]:
		var t := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(957, 1080), CameraIso.TANGAGE_DEG, lacet)
		var vers_camera := t.basis.z
		var au_sol := Vector3(vers_camera.x, 0.0, vers_camera.z).normalized()
		var de_cote := au_sol.cross(Vector3.UP)
		var face := IsoVolumes.visibilite_lentille(au_sol, vers_camera)
		var dos := IsoVolumes.visibilite_lentille(-au_sol, vers_camera)
		var cote := IsoVolumes.visibilite_lentille(de_cote, vers_camera)
		_check("lacet %.0f° : de face %.2f (pleine), de profil %.2f (un filet), de dos %.2f (rien)" % [lacet, face, cote, dos],
			is_equal_approx(face, 1.0) and is_zero_approx(dos) and cote > 0.05 and cote < 0.4)
	var t1 := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(957, 1080), CameraIso.TANGAGE_DEG, 45.0)
	var t2 := CameraIso.transform_pour(Transform2D.IDENTITY, Vector2(957, 1080), CameraIso.TANGAGE_DEG, 225.0)
	var ecart := 0.0
	for k in 16:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(k) / 16.0)
		# La situation miroir : la visée de J2 tournée de 180° comme sa caméra.
		ecart = maxf(ecart, absf(IsoVolumes.visibilite_lentille(d, t1.basis.z)
			- IsoVolumes.visibilite_lentille(d.rotated(Vector3.UP, PI), t2.basis.z)))
	_check("équité : à situation miroir, J1 et J2 voient la même lentille (écart %.6f)" % ecart, ecart < 1e-5)


func _nombre(x: float) -> String:
	var s := "%.1f" % x
	return s


func _en_jeu() -> void:
	print("\n--- En jeu : écran scindé à 45° B ---")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var reseau := root.get_node("NetworkManager")
	main.ui._intended_mode = int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
	main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(main))
	var pres := root.get_node_or_null("Presentation3D")
	var miroirs: Object = pres.get("_miroirs") if pres != null else null
	var volumes: Node = miroirs.get("volumes") if miroirs != null else null
	if volumes == null:
		_check("les volumes iso existent", false)
		return
	var joueurs: Array = [main.p1, main.p2]
	for p in joueurs:
		(p as Node).set_physics_process(false)
	var centre: Vector2 = main._carte_px.get_center()
	main.p1.global_position = centre
	main.p2.global_position = centre + Vector2(-140, 70)
	for pid in 2:
		var j: Node2D = joueurs[pid]
		var lampe := j.get_node("Flashlight") as Light2D
		j.set("flashlight_on", true)
		lampe.enabled = true
		lampe.energy = 2.5
		j.rotation = 0.9
		await process_frame
		await process_frame
		var e: Dictionary = (volumes.get("_suivis") as Dictionary).get(volumes.call("_cle", j, IsoVolumes.CLE_LENTILLE_JOUEUR), {})
		var pointe: Dictionary = pres._voxels[pid].call("pointe_torche")
		if e.is_empty() or pointe.is_empty():
			_check("J%d : la lampe allumée pose le point" % (pid + 1), false, "suivi %s, pointe %s" % [e.keys(), pointe])
			continue
		var noeuds: Array = e["noeuds"]
		var attendu: Vector3 = (pointe["position"] as Vector3) + (pointe["direction"] as Vector3) * IsoVolumes.AVANT_DU_VERRE_PX
		var tous := noeuds.size() == 2
		for mi: MeshInstance3D in noeuds:
			tous = tous and mi.visible and mi.global_position.distance_to(attendu) < 0.01
		_check("J%d : deux lueurs au bout du fût, visibles" % (pid + 1), tous)
		var orientees := true
		for m: ShaderMaterial in e["mats"]:
			orientees = orientees and bool(m.get_shader_parameter("lentille_orientee")) \
				and (m.get_shader_parameter("direction_lentille") as Vector3).is_equal_approx(pointe["direction"])
		_check("J%d : orientées comme la torche (`lentille_orientee`)" % (pid + 1), orientees)
		_check("J%d : le cœur à l'énergie de la lampe" % (pid + 1),
			is_equal_approx(float((e["mats"][1] as ShaderMaterial).get_shader_parameter("intensite")), 1.0))
		lampe.energy = 1.25
		await process_frame
		_check("J%d : lampe à moitié (grésillement), point à moitié" % (pid + 1),
			is_equal_approx(float((e["mats"][1] as ShaderMaterial).get_shader_parameter("intensite")), 0.5))
		j.set("flashlight_on", false)
		lampe.enabled = false
		await process_frame
		await process_frame
		_check("J%d : lampe éteinte, plus de point" % (pid + 1),
			not (volumes.get("_suivis") as Dictionary).has(volumes.call("_cle", j, IsoVolumes.CLE_LENTILLE_JOUEUR)))
	# Une image seulement : sans lui, les lumières 2D restent ce qu'elles sont.
	var j1: Node2D = main.p1
	j1.set("flashlight_on", true)
	(j1.get_node("Flashlight") as Light2D).enabled = true
	(j1.get_node("Flashlight") as Light2D).energy = 2.5
	await process_frame
	var avant := _lumieres_2d(main)
	volumes.set("point_lumineux", false)
	await process_frame
	await process_frame
	_check("éteint sur place : le point part", not (volumes.get("_suivis") as Dictionary).has(
		volumes.call("_cle", j1, IsoVolumes.CLE_LENTILLE_JOUEUR)))
	_check("une image seulement : les lumières 2D ne bougent pas", _lumieres_2d(main) == avant)
	volumes.set("point_lumineux", true)


func _lumieres_2d(main: Node) -> Array:
	var out := []
	for l in main.find_children("*", "Light2D", true, false):
		var lum := l as Light2D
		out.append([lum.name, lum.enabled, snappedf(lum.energy, 0.0001), lum.global_position.snapped(Vector2.ONE * 0.01)])
	return out


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
