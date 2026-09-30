extends SceneTree

## L'ALLÈGEMENT DE LA 0.8.0 — le rayon dans l'air (Q41) taillé à son cône (Adrien, 2026-09-30, 15:36 : « Oui allège d'abord
## avant de publier la 0.8 »). Voir `IsoVolumes._tailler_faisceau_air`.
##
## Les couches du rayon étaient des carrés posés sur la texture de la lampe à son échelle ; ce sont désormais des éventails qui
## ne couvrent que là où le cookie peut dessiner. Leur juge garde son disque : taillé, il changeait la fumée (voir
## `IsoVolumes.faisceau_juge_taille`, une option éteinte). Ce que cette garde tient (headless : sans pixel ; l'image se prouve
## sous Xvfb, `tools/loupe_faisceau_taille.gd` et `tools/faisceau_taille/preuve.py`) :
## - la règle : couches taillées par défaut, juge en disque par défaut ; `--faisceau-air-carre` et `--faisceau-juge-taille`
##   en build de débogage seulement ; le juge taillé (l'option) n'est pas réécrit par `_poser_juge` (sinon le maillage
##   changerait deux fois par image) ;
## - **l'enveloppe CONTIENT le cookie, au texel près**, pour les dix cookies livrés : recalculée ici TEXEL PAR TEXEL, sans le
##   code du jeu (chaque texel non nul, élargi du demi-texel que lit le filtre bilinéaire), aucun secteur ne va plus loin que
##   l'enveloppe que le jeu pose ;
## - **l'éventail contient l'enveloppe** (chaque corde reste au-delà de son arc) et **l'éventail du juge contient l'enveloppe
##   dilatée** de la parallaxe (des points promenés à la distance de dilatation autour du bord de l'enveloppe, dans seize
##   directions, y tombent tous) ;
## - le gain est réel : l'éventail couvre une petite part du carré d'avant (sinon « taillé » ne taillerait rien), et en PLAGES
##   de quelques degrés, pas un triangle par degré (tous se touchent à la lampe : un bloc de pixels que plusieurs triangles
##   recouvrent passe dans le shader une fois par triangle — à un triangle par degré, l'éventail n'allégeait rien, mesuré) ;
## - EN JEU (écran scindé, 45° B) : les couches portent l'éventail, tourné comme la lampe ; un point du cône ramené dans le
##   repère du maillage y tombe, un point derrière la lampe n'y tombe pas (le sens de la rotation) ; le juge garde son disque,
##   sans rotation ; `faisceau_taille` basculé sur place rend les carrés d'avant, puis les éventails ; l'option du juge
##   basculée sur place lui pose l'éventail dilaté à la portée, puis lui rend son disque.
##
## Lancer : godot --headless --path . --script res://tools/test_allegement_faisceau.gd

const COOKIES := ["pompe", "arbalete", "pistolet", "fusil", "allumeur", "incendiaire", "fumiste", "occulteur", "spectre",
	"sentinelle"]
## La part la plus grande du carré d'avant (côté 2 en unités locales, aire 4) que l'éventail d'un cookie peut couvrir. Mesurée
## le 2026-09-30 : du Terrassier (cône de 60°) à ~0,18, au Braconnier (10°) à ~0,05 ; la borne garde le gain.
const PART_MAX_DU_CARRE := 0.25
## Le plus de triangles qu'un éventail de couche peut compter : des PLAGES (dix degrés au plus), pas un triangle par degré — tous
## se touchent à la lampe, et un bloc de pixels que plusieurs triangles recouvrent passe dans le shader une fois par triangle.
const TRIANGLES_MAX := 60

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
	print("=== L'ALLÈGEMENT DE LA 0.8.0 : LE RAYON TAILLÉ À SON CÔNE ===")
	await process_frame
	_regles()
	_enveloppes()
	await _en_jeu()
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _regles() -> void:
	print("\n--- La règle ---")
	var v := IsoVolumes.new()
	_check("couches taillées par défaut", v.faisceau_taille)
	_check("juge en disque par défaut (le juge taillé est une option : il change la fumée)", not v.faisceau_juge_taille)
	v.free()
	var source := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("--faisceau-air-carre ne vaut qu'en build de débogage",
		source.contains("elif arg == DRAPEAU_FAISCEAU_CARRE and OS.is_debug_build():\n\t\t\tfaisceau_taille = false"))
	_check("--faisceau-juge-taille ne vaut qu'en build de débogage",
		source.contains("elif arg == DRAPEAU_FAISCEAU_JUGE_TAILLE and OS.is_debug_build():\n\t\t\tfaisceau_juge_taille = true"))
	_check("`_poser_juge` ne pose ni disque ni échelle sur un juge taillé",
		source.contains("\tif not e.get(\"juge_taille\", false):\n\t\tjuge.mesh = _disque() if ajuste else _plan\n"
			+ "\t\tjuge.scale = Vector3(demi * 2.0, 1.0, demi * 2.0)\n"))
	var i_poser := source.find("\t_poser_couches(e, lampe.global_position, rayon")
	var i_tailler := source.find("\t_tailler_faisceau_air(e, lampe.texture, rayon, lampe.global_rotation)")
	_check("le rayon est taillé APRÈS `_poser_couches` (position, échelle et uniformes restent les siens)",
		i_poser > 0 and i_tailler > i_poser)


## Pour chaque cookie livré : l'enveloppe recalculée texel par texel, puis les deux éventails.
func _enveloppes() -> void:
	print("\n--- L'enveloppe et les éventails, pour les dix cookies livrés ---")
	var n := IsoVolumes.SECTEURS_FAISCEAU
	var pas := TAU / float(n)
	for slug: String in COOKIES:
		var tex := load("res://assets/torche/cookie_%s.png" % slug) as Texture2D
		var img := tex.get_image() if tex != null else null
		if img == null:
			_check("%s : le cookie se lit" % slug, false)
			continue
		if img.is_compressed():
			img.decompress()
		var t0 := Time.get_ticks_usec()
		var env := IsoVolumes.enveloppe_de_l_image(img)
		var duree_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var exacte := _enveloppe_exacte(img, n)
		var pire := -INF
		var secteur := -1
		for s in n:
			if exacte[s] - env[s] > pire:
				pire = exacte[s] - env[s]
				secteur = s
		_check("%s : l'enveloppe du jeu contient le cookie texel par texel (%d secteurs, pire marge %+.5f au secteur %d ; calculée en %.1f ms)"
			% [slug, n, -pire, secteur, duree_ms], pire <= 0.0)
		var eventail := IsoVolumes.eventail(env)
		var pts := _par_secteur(eventail, n)
		var corde_ok := true
		var detail := ""
		for s in n:
			if env[s] <= 0.0:
				continue
			# L'arc de l'enveloppe (unités locales ; le maillage en vaut la moitié), de bord à bord du secteur : dans l'éventail.
			for f: float in [0.0, 0.25, 0.5, 0.75, 0.999]:
				var q := Vector2.from_angle(pas * (float(s) + f)) * env[s] * (1.0 - 1e-6)
				if not _dans(pts, q * 0.5, n):
					corde_ok = false
					detail = "secteur %d : le point de l'arc à %.3f du secteur, rayon %.5f, est dehors" % [s, f, env[s]]
					break
			if not corde_ok:
				break
		_check("%s : l'arc de l'enveloppe est dans l'éventail, secteur par secteur (chaque corde au-delà)" % slug, corde_ok, detail)
		# Le carré d'avant est le plan de côté 1 : son aire vaut 1 dans le repère du maillage.
		var aire := _aire(eventail)
		_check("%s : l'éventail couvre %.3f du carré d'avant (≤ %.2f), en %d triangles (≤ %d : des plages, pas un par degré)"
			% [slug, aire.x, PART_MAX_DU_CARRE, int(aire.y), TRIANGLES_MAX],
			aire.x > 0.0 and aire.x <= PART_MAX_DU_CARRE and int(aire.y) <= TRIANGLES_MAX)
		# Le juge : l'enveloppe dilatée de la parallaxe, pour une portée au bord de l'écran (728 px) et une courte (192 px).
		for portee: float in [728.0, 192.0]:
			var d := IsoVolumes.decalage_du_juge() / portee
			var juge := _par_secteur(IsoVolumes.eventail(IsoVolumes.enveloppe_dilatee(env, d)), n)
			var hors := 0
			var exemple := ""
			for s in n:
				if env[s] <= 0.0:
					continue
				# Le bord du secteur de l'enveloppe (l'arc et les deux rayons), promené de `d` dans seize directions.
				var bords: Array[Vector2] = []
				for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
					bords.append(Vector2.from_angle(pas * (float(s) + f)) * env[s])
				for f in [0.0, 0.25, 0.5, 0.75]:
					bords.append(Vector2.from_angle(pas * float(s)) * env[s] * f)
					bords.append(Vector2.from_angle(pas * float(s + 1)) * env[s] * f)
				for q: Vector2 in bords:
					for k in 16:
						var p := q + Vector2.from_angle(TAU * float(k) / 16.0) * d
						if not _dans(juge, p * 0.5, n):
							hors += 1
							if exemple.is_empty():
								exemple = "secteur %d, point (%.4f, %.4f)" % [s, p.x, p.y]
			_check("%s : l'éventail du juge contient l'enveloppe dilatée de la parallaxe (portée %.0f px, %d point(s) dehors)"
				% [slug, portee, hors], hors == 0, exemple)


## L'enveloppe EXACTE, texel par texel, sans le code du jeu : chaque texel d'alpha non nul, élargi d'un demi-texel (la portée du
## filtre bilinéaire), étend chaque secteur qu'il touche jusqu'à son coin le plus loin (plafonné à 1, où la couche se tait).
func _enveloppe_exacte(img: Image, n: int) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(n)
	env.fill(0.0)
	var a := img.duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	var w := a.get_width()
	var h := a.get_height()
	var data := a.get_data()
	var utile := a.get_used_rect()
	var pas := TAU / float(n)
	for y in range(utile.position.y, utile.end.y):
		for x in range(utile.position.x, utile.end.x):
			if data[(y * w + x) * 4 + 3] == 0:
				continue
			var x0 := (float(x) - 0.5) * 2.0 / float(w) - 1.0
			var x1 := (float(x) + 1.5) * 2.0 / float(w) - 1.0
			var y0 := (float(y) - 0.5) * 2.0 / float(h) - 1.0
			var y1 := (float(y) + 1.5) * 2.0 / float(h) - 1.0
			var loin := minf(1.0, sqrt(maxf(x0 * x0, x1 * x1) + maxf(y0 * y0, y1 * y1)))
			if x0 <= 0.0 and x1 >= 0.0 and y0 <= 0.0 and y1 >= 0.0:
				for s in n:
					env[s] = maxf(env[s], loin)
				continue
			# Les angles des quatre coins, ramenés au plus près de celui du premier : l'arc qu'ils couvrent.
			var ref := atan2(y0, x0)
			var lo := 0.0
			var hi := 0.0
			for c in [Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
				var dlt := angle_difference(ref, atan2(c.y, c.x))
				lo = minf(lo, dlt)
				hi = maxf(hi, dlt)
			var s0 := int(floor((ref + lo) / pas))
			var s1 := int(floor((ref + hi) / pas))
			for s in range(s0, s1 + 1):
				var k := posmod(s, n)
				env[k] = maxf(env[k], loin)
	return env


## Les triangles d'un éventail, relus DANS LE MAILLAGE et rangés par secteur de 1° : pour chaque secteur, les deux sommets de
## bord [A, B] (x, z du maillage) du triangle qui le couvre, ou [] si aucun. Chaque triangle est (lampe, A, B), A et B sur des
## bords de secteur, A avant B dans le sens des angles.
func _par_secteur(m: ArrayMesh, n: int) -> Array:
	var out := []
	out.resize(n)
	for s in n:
		out[s] = []
	if m.get_surface_count() == 0:
		return out
	var tableaux := m.surface_get_arrays(0)
	var v: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX]
	var pas := TAU / float(n)
	for t in range(0, idx.size(), 3):
		var a := Vector2(v[idx[t + 1]].x, v[idx[t + 1]].z)
		var b := Vector2(v[idx[t + 2]].x, v[idx[t + 2]].z)
		var s := posmod(int(round(fposmod(a.angle(), TAU) / pas)), n)
		var fin := posmod(int(round(fposmod(b.angle(), TAU) / pas)), n)
		while s != fin:
			out[s] = [a, b]
			s = (s + 1) % n
	return out


## Le point `p` (repère du maillage, x et z) est-il dans l'éventail ? Le triangle de son secteur, puis sa corde.
func _dans(tris: Array, p: Vector2, n: int) -> bool:
	if p.length() < 1e-9:
		return true
	var s := posmod(int(floor(fposmod(p.angle(), TAU) / (TAU / float(n)))), n)
	var t: Array = tris[s]
	if t.is_empty():
		return false
	var a: Vector2 = t[0]
	var b: Vector2 = t[1]
	return (b - a).cross(p - a) >= -1e-9


## L'aire de l'éventail, en unités du maillage (le carré d'avant y vaut 1), et le nombre de ses triangles.
func _aire(m: ArrayMesh) -> Vector2:
	if m.get_surface_count() == 0:
		return Vector2.ZERO
	var tableaux := m.surface_get_arrays(0)
	var v: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX]
	var s := 0.0
	for t in range(0, idx.size(), 3):
		var a := Vector2(v[idx[t + 1]].x, v[idx[t + 1]].z)
		var b := Vector2(v[idx[t + 2]].x, v[idx[t + 2]].z)
		s += absf(a.cross(b)) * 0.5
	return Vector2(s, idx.size() / 3)


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
	for p in [main.p1, main.p2]:
		(p as Node).set_physics_process(false)
	var lampes: Array = [main.p1.get_node("Flashlight"), main.p2.get_node("Flashlight")]
	# Lampes éteintes : l'enveloppe se prépare déjà (au décompte), jamais à l'image où la lampe s'allume.
	for l: PointLight2D in lampes:
		l.enabled = false
	await process_frame
	var prets := true
	for l: PointLight2D in lampes:
		prets = prets and IsoVolumes._enveloppes.has(l.texture) and IsoVolumes._eventails.has(l.texture)
	_check("lampes éteintes, l'enveloppe et l'éventail de chaque cookie sont déjà prêts", prets)
	var centre: Vector2 = main._carte_px.get_center()
	main.p1.global_position = centre
	main.p2.global_position = centre + Vector2(-140, 70)
	for pid in 2:
		var j: Node2D = [main.p1, main.p2][pid]
		var lampe: PointLight2D = lampes[pid]
		for angle in [0.9, -2.3]:
			j.rotation = angle
			j.set("flashlight_on", true)
			lampe.enabled = true
			lampe.energy = 2.5
			await process_frame
			await process_frame
			var e: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
			if e.is_empty():
				_check("J%d (visée %.1f) : le rayon est posé" % [pid + 1, angle], false)
				continue
			_verifier_taille(e, lampe, "J%d, visée %.1f rad" % [pid + 1, angle], volumes, false)
		# Sur place : les carrés d'avant, puis les éventails.
		volumes.set("faisceau_taille", false)
		await process_frame
		var e2: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		var carres := not e2.is_empty()
		if carres:
			for mi: MeshInstance3D in e2["noeuds"]:
				carres = carres and mi.mesh is PlaneMesh and mi.rotation == Vector3.ZERO
			var juge: MeshInstance3D = e2.get("juge")
			# Le juge d'avant : le disque ajusté (forme 5, le défaut depuis la 0.7.0), sans rotation.
			carres = carres and juge != null and juge.mesh == volumes.call("_disque") and juge.rotation == Vector3.ZERO
		_check("J%d : `faisceau_taille` coupé sur place, les carrés d'avant reviennent (plan, disque, sans rotation)" % (pid + 1),
			carres)
		volumes.set("faisceau_taille", true)
		await process_frame
		var e3: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e3.is_empty():
			_verifier_taille(e3, lampe, "J%d, rétabli sur place" % (pid + 1), volumes, false)
		# L'option du juge taillé, sur place : l'éventail dilaté, puis le disque rendu.
		volumes.set("faisceau_juge_taille", true)
		await process_frame
		var e4: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e4.is_empty():
			_verifier_taille(e4, lampe, "J%d, option du juge taillé" % (pid + 1), volumes, true)
		volumes.set("faisceau_juge_taille", false)
		await process_frame
		var e5: Dictionary = volumes.call("suivi_de", j, IsoVolumes.CLE_FAISCEAU_AIR)
		if not e5.is_empty():
			_verifier_taille(e5, lampe, "J%d, option rendue" % (pid + 1), volumes, false)
		j.set("flashlight_on", false)
		lampe.enabled = false
		await process_frame
		await process_frame
	main.queue_free()
	await process_frame


## Les couches portent l'éventail du cookie, tourné comme la lampe ; un point du cône (repris du cookie lui-même) tombe dans le
## maillage de chaque couche, un point derrière la lampe n'y tombe pas ; le juge garde son disque, ou, avec l'option
## (`juge_taille`), porte l'éventail dilaté à la portée.
func _verifier_taille(e: Dictionary, lampe: PointLight2D, qui: String, volumes: Node, juge_taille: bool) -> void:
	var n := IsoVolumes.SECTEURS_FAISCEAU
	var eventail: ArrayMesh = IsoVolumes._eventails.get(lampe.texture)
	var noeuds: Array = e["noeuds"]
	var portee := 0.5 * float(lampe.texture.get_width()) * lampe.texture_scale
	var ok := eventail != null and noeuds.size() == int(IsoVolumes.VOLUME_FAISCEAU_AIR["couches"])
	var devant := true
	var derriere := true
	var pts := _par_secteur(eventail, n) if eventail != null else []
	var img := lampe.texture.get_image()
	# Le point le plus loin du cookie sur son axe, et le même derrière la lampe, en unités locales.
	var axe := _plus_loin_sur_l_axe(img)
	for mi: MeshInstance3D in noeuds:
		ok = ok and mi.mesh == eventail and is_equal_approx(mi.rotation.y, -lampe.global_rotation) \
			and is_zero_approx(mi.rotation.x) and is_zero_approx(mi.rotation.z)
		var mat := mi.material_override as ShaderMaterial
		var r := float(mat.get_shader_parameter("nuage_rayon"))
		var angle := float(mat.get_shader_parameter("nuage_angle"))
		var centre: Vector2 = mat.get_shader_parameter("nuage_centre")
		# Le monde que le shader associe à ce point du cookie : d = R(angle)·local, px = centre + r·d.
		for local: Vector2 in [Vector2(axe, 0.0), Vector2(axe * 0.5, 0.0)]:
			var monde := centre + local.rotated(angle) * r
			var dans_le_maillage: Vector3 = mi.global_transform.affine_inverse() * Vector3(monde.x, mi.global_position.y, monde.y)
			devant = devant and _dans(pts, Vector2(dans_le_maillage.x, dans_le_maillage.z), n)
		var dos := centre + Vector2(-0.5, 0.0).rotated(angle) * r
		var dos_m: Vector3 = mi.global_transform.affine_inverse() * Vector3(dos.x, mi.global_position.y, dos.y)
		derriere = derriere and not _dans(pts, Vector2(dos_m.x, dos_m.z), n)
	_check("%s : les couches portent l'éventail du cookie, tourné comme la lampe" % qui, ok)
	_check("%s : un point du cône (l'axe, à %.2f puis à mi-chemin) tombe dans chaque couche" % [qui, axe], devant)
	_check("%s : un point derrière la lampe n'y tombe pas (le sens de la rotation)" % qui, derriere)
	var juge: MeshInstance3D = e.get("juge")
	if not juge_taille:
		# Le juge d'avant : le disque ajusté (forme 5, le défaut depuis la 0.7.0), sans rotation — la fumée lit son pochoir.
		_check("%s : le juge garde son disque, visible et sans rotation" % qui,
			juge != null and juge.visible and juge.mesh == volumes.call("_disque") and juge.rotation == Vector3.ZERO)
		return
	var attendu: ArrayMesh = (IsoVolumes._eventails_juge.get(lampe.texture, {}) as Dictionary).get(maxi(1, int(floor(portee))))
	_check("%s : le juge porte l'éventail dilaté à la portée (%.0f px), visible, tourné et à l'échelle" % [qui, portee],
		juge != null and juge.visible and attendu != null and juge.mesh == attendu
		and is_equal_approx(juge.rotation.y, -lampe.global_rotation)
		and juge.scale.is_equal_approx(Vector3(portee * 2.0, 1.0, portee * 2.0)))


## Le texel non nul le plus loin sur l'axe du cookie (+x depuis le centre), en unités locales.
func _plus_loin_sur_l_axe(img: Image) -> float:
	var a := img.duplicate() as Image
	if a.is_compressed():
		a.decompress()
	var y := a.get_height() / 2
	for x in range(a.get_width() - 1, a.get_width() / 2, -1):
		if a.get_pixel(x, y).a > 0.0:
			return (float(x) + 0.5) * 2.0 / float(a.get_width()) - 1.0
	return 0.5


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
