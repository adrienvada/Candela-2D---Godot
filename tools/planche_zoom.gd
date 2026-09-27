extends "res://tools/photographe.gd"

## Q15 — la planche du zoom du duel (session cloud zoom-2, 2026-09-27). **Un outil de prise de vues, rien de plus :
## il ne change rien au jeu.** Il montre à Adrien le duel au zoom de l'exécution (`--zoom=X`, le drapeau de débogage
## du jeu, lu par `GameSettings`) et en relève les chiffres avec les formules mêmes du jeu.
##
## Hérite du photographe pour sa fenêtre retaillée, son horloge fixe, ses marionnettes, ses bascules vue unique /
## écran scindé et sa capture. Ne reprend PAS son `_zoom` : on laisse le jeu poser le sien, c'est lui qu'on juge.
##
## ⚠️ **Le rendu reste celui du joueur** (`rendu_racine_autorise` laissé vrai, contrairement au photographe) : en vue
## unique la racine rend le duel aux pixels de la fenêtre, et la capture est la fenêtre, HUD compris.
##
## ⚠️ **Une carte par lancement** (`--cartes=res://…json`). Poser une seconde carte dans la même manche
## (`rebuild_arena()` une deuxième fois) la laisse faiblement éclairée PARTOUT — sol et murs à ~18/255 au lieu du
## noir — quel que soit l'ordre des cartes (constaté le 2026-09-27, voir le rapport). Le jeu ne change jamais de carte
## en pleine manche ; l'outil, si. D'où un lancement par couple (zoom, carte).
##
## Pour la carte :
## - la scène : J1 sur un sol dégagé près du centre, visée choisie pour que son faisceau ait la place ; J2 AU BORD DU
##   CÔNE de J1 (0,65 × le demi-angle, 0,8 × la portée), torche allumée, qui regarde de côté. Les positions ne
##   dépendent PAS du zoom : les quatre exécutions montrent le même instant ;
## - trois images : la vue unique, l'écran scindé au même instant, un recadrage 1:1 autour de J2 ;
## - les mesures (JSON), par la caméra iso réellement posée (`CameraIso.vers_ecran` / `vers_sol`).
##
## Lancer (cloud) :
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
##         godot --fixed-fps 60 --path . res://tools/planche_zoom.tscn -- --zoom=1.5 --sortie=/chemin/absolu

const CARTES_DEFAUT := "res://assets/maps/map_001_le_cloitre.json"
## Images de jeu laissées entre la pose de la scène et la prise : le joueur tourne vers sa visée, le regard décalé
## se lisse (~120 ms aux deux tiers), la lightmap suit. Sous `--fixed-fps 60`, 90 images = 1,5 s de jeu.
const REPOS_IMAGES := 90

var _mesures: Array[Dictionary] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_zoom : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://planche_zoom")
	_taille = _lire_taille(_valeur(args, "--taille", "1920x1080"))
	var cartes := _valeur(args, "--cartes", CARTES_DEFAUT).split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))

	print("=== planche du zoom ===")
	_poser_la_fenetre()
	await _lire_l_horloge()
	AudioServer.set_bus_mute(0, true)

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	var manquants: Array[String] = Commun.preconditions_manquantes(_ui, _main)
	manquants.append_array(preconditions_manquantes(_ui, _main))
	if not manquants.is_empty():
		printerr("✗ le jeu a changé sous l'outil : ", manquants)
		_sortir(1)
		return
	_main.archiver_les_matchs = false
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null:
		allumage.queue_free()

	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 20.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	_prendre_les_commandes()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0):
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_torches(true)

	var zoom := float(_main.cam1.zoom.y)
	print("  zoom posé par le jeu : cam1 ×%.3f, cam2 ×%.3f, GameSettings.zoom_duel ×%.3f, lacet %.1f° option %s, décalage %.2f"
		% [zoom, _main.cam2.zoom.y, GameSettings.zoom_duel, GameSettings.lacet_duel, GameSettings.option_lacet,
		GameSettings.decalage_visee])
	var etiquette := "z%03d" % int(round(zoom * 100.0))
	if get_window().size.y != 1080:
		etiquette += "-%dp" % get_window().size.y

	for chemin in cartes:
		if not await _poser_la_carte(chemin):
			continue
		var nom := chemin.get_file().get_basename()
		var scene := _choisir_la_scene()
		if scene.is_empty():
			printerr("  ✗ %s : aucune scène valable" % nom)
			continue
		var tenir := _tenir.bind(scene)
		# 1. La vue unique.
		_vue_unique()
		await _tenir_pendant(tenir, REPOS_IMAGES)
		var m := _mesurer(scene, false)
		m["carte"] = nom
		m["zoom"] = zoom
		var img: Image = await Commun.capturer(get_tree(), 8000)
		if img != null:
			_enregistrer(img, "%s-%s-unique" % [etiquette, nom])
			var j2: Vector2 = m["j2_ecran"]
			_enregistrer(_recadrer(img, j2 * float(img.get_height()) / 1080.0, 320),
				"%s-%s-corps" % [etiquette, nom])
			m["image_px"] = [img.get_width(), img.get_height()]
		# 2. L'écran scindé, au même instant.
		_deux_vues()
		await _tenir_pendant(tenir, REPOS_IMAGES)
		m["scinde"] = _mesurer(scene, true)
		var img2: Image = await Commun.capturer(get_tree(), 8000)
		if img2 != null:
			_enregistrer(img2, "%s-%s-scinde" % [etiquette, nom])
		_vue_unique()
		_mesures.append(m)
		print("  · %s : corps %s px, torche %.0f px à l'écran, carte visible %.0f %%"
			% [nom, str(m["corps_px"]), m["torche_ecran_max_px"], 100.0 * float(m["carte_visible"])])

	var f := FileAccess.open("%s/mesures-%s-%s.json" % [_dossier, etiquette, cartes[0].get_file().get_basename()], FileAccess.WRITE)
	f.store_string(JSON.stringify(_mesures, "  "))
	f.close()
	print("mesures écrites : %s (%s)" % [ProjectSettings.globalize_path(_dossier), etiquette])
	_sortir(0)


func _poser_la_carte(chemin: String) -> bool:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK or not (json.data is Dictionary):
		printerr("  ✗ carte illisible : %s" % chemin)
		return false
	MapData.current_map_data = MapCodec.validate(json.data as Dictionary)["data"]
	_main.rebuild_arena()
	await _attendre_images(5)
	return true


## La scène, indépendante du zoom. J1 : sols dégagés en anneaux autour du centre de la carte ; pour chacun, les seize
## directions dont le rayon reste libre au-delà de la portée de la torche, et où J2 (au bord du cône) tient sur un sol
## libre, sans mur entre eux. Parmi elles, celle qui va le plus vers le haut-droite de L'ÉCRAN (−35°) : le faisceau
## part dans le cadre, vers la dimension la plus courte de l'image (la hauteur), c'est le cas serré.
func _choisir_la_scene() -> Dictionary:
	var arme: WeaponData = _main.p1.current_weapon
	var portee := arme.portee_torche()
	var demi := arme.demi_angle_torche()
	var data: Dictionary = MapData.current_map_data
	var centre := Vector2(MapCodec.get_grid_size(data)) * Vector2(CandelaTileSet.TILE_SIZE) * 0.5
	var iso := Presentation3D.instance()
	for anneau in 20:
		var essais := 1 if anneau == 0 else 8 * anneau
		var meilleure := {}
		var meilleur_ecart := INF
		for k in essais:
			var p := centre + Vector2.RIGHT.rotated(TAU * float(k) / float(essais)) * (35.0 * anneau)
			if not _sol_libre(p):
				continue
			for i in 16:
				var dir := Vector2.RIGHT.rotated(TAU * float(i) / 16.0)
				# Le cône entier dégagé (l'axe et ses deux bords), murs hauts et murets : sans quoi la torche
				# butte sur un pilier et l'image ne montre plus sa portée.
				var degage := true
				for bord in [0.0, -demi, demi]:
					var bout: Vector2 = p + dir.rotated(bord) * (portee + 60.0)
					if _mur_entre(p, bout) or _muret_entre(p, bout):
						degage = false
				if not degage:
					continue
				var p2 := p + dir.rotated(0.65 * demi) * (0.8 * portee)
				if not _sol_libre(p2) or _mur_entre(p, p2) or _muret_entre(p, p2):
					continue
				var a := iso.angle_ecran(0, p, p + dir) if iso != null else dir.angle()
				if is_nan(a):
					a = dir.angle()
				var ecart := absf(angle_difference(a, deg_to_rad(-35.0)))
				if ecart < meilleur_ecart:
					meilleur_ecart = ecart
					meilleure = {"p1": p, "v1": dir, "p2": p2, "v2": dir.rotated(PI * 0.55),
						"portee": portee, "demi_angle_deg": rad_to_deg(demi), "arme": arme.slug(),
						"angle_ecran_deg": rad_to_deg(a)}
		if not meilleure.is_empty():
			return meilleure
	return {}


## Un muret coupe-t-il le segment ? `murs_bas` porte leurs rectangles en pixels du monde ; échantillonné tous les
## 5 px, avec 12 px de marge (le corps).
func _muret_entre(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 5.0) + 1
	for r in _main.murs_bas as Array:
		var g := (r as Rect2).grow(12.0)
		for i in n + 1:
			if g.has_point(a.lerp(b, float(i) / float(n))):
				return true
	return false


func _tenir(scene: Dictionary) -> void:
	_main.p1.global_position = scene["p1"]
	_main.p2.global_position = scene["p2"]
	_viser(0, scene["v1"])
	_viser(1, scene["v2"])
	_vivants()


func _tenir_pendant(tenir: Callable, images: int) -> void:
	for i in images:
		tenir.call()
		await get_tree().process_frame
	tenir.call()


## Les chiffres, par la caméra iso de J1 telle qu'elle est posée à cette image. Unités : pixels LOGIQUES de la vue
## (1080 lignes en vue unique ; la fenêtre les rastérise à sa résolution, `stretch = keep`, donc ×4/3 sur 1440).
func _mesurer(scene: Dictionary, scinde: bool) -> Dictionary:
	var iso := Presentation3D.instance()
	var cam: CameraIso = iso._camera_de(0)
	var vue: Viewport = iso.viewport_ecran(0)
	var taille: Vector2 = vue.get_visible_rect().size
	var ecran := Rect2(Vector2.ZERO, taille)
	var proj := func(p: Vector2, h: float) -> Vector2: return cam.vers_ecran(p, taille, h)
	var p1: Vector2 = scene["p1"]
	var v1: Vector2 = scene["v1"]
	var portee: float = scene["portee"]
	var out := {"vue_px": [taille.x, taille.y], "cam_size": cam.size, "zoom_cam2d": _main.cam1.zoom.y}

	# Le corps de J2 : la boîte de ses maillages voxel, projetée.
	var boite := Rect2()
	var premier := true
	var ancre: Node3D = iso._corps[1]
	for mi in ancre.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		for c in 8:
			var coin := aabb.get_endpoint(c)
			var e: Vector2 = proj.call(Vector2(coin.x, coin.z), coin.y)
			if premier:
				boite = Rect2(e, Vector2.ZERO)
				premier = false
			else:
				boite = boite.expand(e)
	out["corps_px"] = [snappedf(boite.size.x, 0.1), snappedf(boite.size.y, 0.1)]
	out["j2_ecran"] = proj.call(scene["p2"], 0.0)
	out["j1_ecran"] = proj.call(p1, 0.0)
	# La zone de touche (18 px de rayon) au sol, à l'écran.
	var touche := Rect2(proj.call(p1 + Vector2(18, 0), 0.0), Vector2.ZERO)
	for i in 32:
		touche = touche.expand(proj.call(p1 + Vector2.RIGHT.rotated(TAU * i / 32.0) * 18.0, 0.0))
	out["touche_px"] = [snappedf(touche.size.x, 0.1), snappedf(touche.size.y, 0.1)]

	# La torche : sa portée le long de la visée, et au plus long (la direction qui tombe à l'horizontale de l'écran).
	out["torche_monde_px"] = portee
	out["torche_visee_px"] = snappedf((proj.call(p1 + v1 * portee, 0.0) - proj.call(p1, 0.0)).length(), 0.1)
	var plus_long := 0.0
	for i in 72:
		plus_long = maxf(plus_long, (proj.call(p1 + Vector2.RIGHT.rotated(TAU * i / 72.0) * portee, 0.0) - proj.call(p1, 0.0)).length())
	out["torche_ecran_max_px"] = snappedf(plus_long, 0.1)
	out["torche_part_demi_largeur"] = snappedf(plus_long / (taille.x * 0.5), 0.001)
	out["bout_du_cone_a_l_ecran"] = ecran.has_point(proj.call(p1 + v1 * portee, 0.0))

	# L'empreinte au sol de l'écran, et la part de la carte qu'elle couvre.
	var coins := PackedVector2Array()
	for c in [Vector2.ZERO, Vector2(taille.x, 0), taille, Vector2(0, taille.y)]:
		coins.append(cam.vers_sol(c, taille))
	var carte: Rect2 = _main._carte_px
	var rect_carte := PackedVector2Array([carte.position, Vector2(carte.end.x, carte.position.y), carte.end,
		Vector2(carte.position.x, carte.end.y)])
	var dedans := 0.0
	for poly in Geometry2D.intersect_polygons(coins, rect_carte):
		dedans += absf(_aire(poly))
	out["empreinte"] = Array(coins).map(func(v: Vector2) -> Array: return [snappedf(v.x, 0.1), snappedf(v.y, 0.1)])
	out["empreinte_aire"] = absf(_aire(coins))
	out["carte_px"] = [carte.size.x, carte.size.y]
	out["carte_visible"] = snappedf(dedans / maxf(carte.get_area(), 1.0), 0.001)

	# Jusqu'où l'écran montre le sol depuis J1, direction par direction (0° = la visée) : au-delà, une lumière est
	# hors champ. Comparé à la portée de chaque classe : un adversaire qui vous éclaire depuis plus loin que ça
	# vous voit sans que sa source soit à votre écran.
	var portees := {}
	for c in 360 / 45:
		var a := deg_to_rad(45.0 * c)
		var d := v1.rotated(a)
		var t := 0.0
		while t < 4000.0 and ecran.has_point(proj.call(p1 + d * t, 0.0)):
			t += 2.0
		portees[str(45 * c)] = t
	out["regard_px"] = portees
	var classes := []
	for w in _main._classes:
		classes.append({"slug": (w as WeaponData).slug(), "portee": (w as WeaponData).portee_torche(),
			"demi_angle_deg": (w as WeaponData).torch_angle_deg})
	out["classes"] = classes
	out["j1"] = [p1.x, p1.y]
	out["j2"] = [(scene["p2"] as Vector2).x, (scene["p2"] as Vector2).y]
	out["visee"] = [v1.x, v1.y]
	out["angle_ecran_deg"] = scene["angle_ecran_deg"]
	out["arme"] = scene["arme"]
	out["demi_angle_deg"] = scene["demi_angle_deg"]
	return out


static func _aire(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


func _recadrer(img: Image, centre: Vector2, cote: int) -> Image:
	var x := clampi(int(centre.x) - cote / 2, 0, maxi(img.get_width() - cote, 0))
	var y := clampi(int(centre.y) - cote / 2, 0, maxi(img.get_height() - cote, 0))
	return img.get_region(Rect2i(x, y, cote, cote))


func _enregistrer(img: Image, nom: String) -> void:
	var chemin := "%s/%s.jpg" % [_dossier, nom]
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(chemin, 0.85)
	print("  → %s" % chemin)
