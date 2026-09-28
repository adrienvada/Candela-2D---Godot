extends "res://tools/photo_ecart.gd"

## LES MURS MEUBLÉS EN ESSAI (`--murs-meubles-essai`, `murs_meubles_iso.gd`) — une séance du photographe, héritière de
## `photo_ecart.gd` (graine, repos en images de jeu, LED figées, congé de l'intro en planches, maintien des joueurs).
##
## Sur le Cloître, au cadrage du jeu (1920×1080, lacet 45° B, zoom du duel), pour CHAQUE famille (portes, grilles, boîtiers,
## faisceaux) : J1 à 3,2 cases d'un objet de la famille que sa caméra dessine, torche dessus à 18° de biais ; puis, dans le
## MÊME lancement et jeu en pause (même instant), torches allumées puis éteintes :
##   A  — les murs meublés cachés (le jeu sans eux) ;  B — montrés ;  A2 — cachés de nouveau (le bruit, et le « A' » du noir) ;
##   M  — leur emprise (l'instrument `emprise_preuve` des deux shaders : les objets en blanc), pour compter SUR eux.
## `CADRE <famille> x0,y0 x1,y1` : la boîte de l'objet à l'écran, pour que la planche le recadre à 1:1 et à ×3.
## Puis `sym` : l'écran scindé, J1 devant l'objet de la scène des faisceaux, J2 à son image par le demi-tour (option B : sa
## caméra est à 225°), torches allumées — A, B, M ; la planche compare les deux moitiés. Et `ensemble` : une vue large,
## B et A (tous les essais allumés quand le lancement les porte).
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_murs_meubles.tscn -- --murs-meubles-essai --no-eos --led-murs-fige --sortie=user://mm/seul
##
## Il EXIGE une vraie fenêtre, comme le photographe.

const MursMeublesIsoT := preload("res://murs_meubles_iso.gd")
const CARTE_MEUBLES := "res://assets/maps/map_001_le_cloitre.json"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche des murs meublés exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	if not MursMeublesIsoT.essai_actif():
		printerr("✗ lancer avec --murs-meubles-essai : la séance cache et montre les murs meublés au même instant")
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://murs_meubles")
	_scenes = _valeur(args, "--scenes", "portes,grilles,boitiers,faisceaux,sym,ensemble").split(",")
	_sans_hud = true
	_carte_duel = CARTE_MEUBLES
	_zoom = 1.0
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Les murs meublés ===")
	print("  drapeaux : %s" % " ".join(args))
	_poser_la_fenetre()
	await _lire_l_horloge()
	if _pas_fixe <= 0.0:
		printerr("✗ lancer avec --fixed-fps 60")
		_sortir(1)
		return
	_mute_avant = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = false
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	# L'intro en planches d'un user:// neuf couvrirait chaque prise : congédiée (piège payé deux fois la nuit du 27/09).
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.emit_signal("terminee")
	await _traiter_l_allumage([] as Array[Dictionary])
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
	_vue_unique()
	await _passer_sur_la_carte_des_murs_bas()
	var reglages := get_node_or_null(^"/root/GameSettings")
	var lacet := float(reglages.call("lacet_de", 0)) if reglages != null else 0.0
	var lacet2 := float(reglages.call("lacet_de", 1)) if reglages != null else 0.0
	print("  lacet de J1 : %s° · de J2 : %s° · zoom caméra : %s" % [str(lacet), str(lacet2), str(_main.cam1.zoom.x)])
	var iso := Presentation3D.instance()
	var noeuds: Array = iso.get("_noeuds_murs_meubles") if iso != null else []
	print("  nœuds des murs meublés : %s" % str(noeuds.map(func(n: Node) -> String: return String(n.name))))
	if noeuds.is_empty():
		printerr("✗ aucun nœud de murs meublés dans la scène iso")
		_sortir(1)
		return

	var c := MursMeublesIsoT.construire(MapData.current_map_data)
	var pose_faisceau := {}
	for famille in MursMeublesIsoT.FAMILLES:
		var pose := _devant(c, famille, lacet)
		if famille == "faisceaux":
			pose_faisceau = pose
		if not _scenes.has(famille):
			continue
		if pose.is_empty():
			printerr("  ! aucun objet « %s » dessiné au lacet %s° devant un sol libre" % [famille, str(lacet)])
			continue
		_poser(pose["j1"], pose["visee"])
		print("SCENE %s : face %s, s %.1f · J1 %s" % [famille, str(pose["n"]), float(pose["objet"]["s"]), str(_j1)])
		for allumees in [true, false]:
			await _serie("%s_%s" % [famille, "allumees" if allumees else "eteintes"], allumees, "vue")
		_cadre(famille, pose["objet"])

	# --- sym : l'écran scindé, J2 à l'image de J1 par le demi-tour.
	if _scenes.has("sym") and not pose_faisceau.is_empty():
		var dim := Vector2(EnseignesIsoT.cases_carte(MapData.current_map_data)) * float(CandelaTileSet.TILE_SIZE.x)
		var p1: Vector2 = pose_faisceau["j1"]
		var v1: Vector2 = pose_faisceau["visee"]
		_poser(p1, v1, dim - p1, -v1)
		print("SCENE sym : J1 %s visée %s · J2 %s visée %s" % [str(_j1), str(v1), str(_j2), str(-v1)])
		_deux_vues()
		await _serie("sym", true, "ecran", false)
		_vue_unique()

	# --- ensemble : une vue large (la face des tuyaux de `photo_essais.gd`, reculée), B puis A.
	if _scenes.has("ensemble"):
		var face := _choisir_la_face(MapData.current_map_data)
		if not face.is_empty():
			var n: Vector2 = face["n"]
			var tg := Vector2(-n.y, n.x)
			var t := float(CandelaTileSet.TILE_SIZE.x)
			var pied := n * float(face["d"]) + tg * ((float(face["s0"]) + float(face["s1"])) * 0.5)
			_poser(pied + n * (3.2 * t) + tg * 20.0, (-n).rotated(deg_to_rad(20.0)))
			print("SCENE ensemble : face %s · J1 %s" % [str(face["cle"]), str(_j1)])
			await _serie("ensemble", true, "vue", false)

	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


## La place de J1 devant un objet de la famille que la caméra de ce lacet dessine, sur un sol libre, torche à 18° de biais
## (la règle de `photo_enseignes.gd`). L'objet le plus proche du centre de la carte d'abord.
func _devant(c: Dictionary, famille: String, lacet: float) -> Dictionary:
	var t := float(CandelaTileSet.TILE_SIZE.x)
	var centre: Vector2 = (c["taille_px"] as Vector2) * 0.5
	var candidats: Array = []
	for o in c["objets"]:
		if o["famille"] != famille or not TuyauxIsoT.face_dessinee(o["n"], lacet):
			continue
		var n: Vector2 = o["n"]
		var tg := Vector2(-n.y, n.x)
		var pied := n * float(o["d"]) + tg * float(o["s"])
		candidats.append([pied.distance_to(centre), o, pied])
	candidats.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for cand in candidats:
		var o: Dictionary = cand[1]
		var n: Vector2 = o["n"]
		var tg := Vector2(-n.y, n.x)
		var j1: Vector2 = cand[2] + n * (3.2 * t) + tg * 20.0
		if _sol_libre(j1):
			return {"j1": j1, "visee": (-n).rotated(deg_to_rad(18.0)), "objet": o, "n": n}
	return {}


## Une série au même instant : A (cachés), B (montrés), A2 (cachés), M (emprise). `avec_a2` faux : A, B, M seulement.
func _serie(cle: String, allumees: bool, source: String, avec_a2 := true) -> void:
	_torches_allumees = allumees
	_torches(allumees)
	for i in REPOS_IMAGES:
		_tenir()
		await get_tree().process_frame
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	_montrer(false)
	await _attendre_images(3)
	_ecrire_prise(await _capturer(source), cle + "__A")
	_montrer(true)
	await _attendre_images(3)
	_ecrire_prise(await _capturer(source), cle + "__B")
	if avec_a2:
		_montrer(false)
		await _attendre_images(3)
		_ecrire_prise(await _capturer(source), cle + "__A2")
		_montrer(true)
	_emprise(true)
	await _attendre_images(3)
	_ecrire_prise(await _capturer(source), cle + "__M")
	_emprise(false)
	await _attendre_images(3)
	get_tree().paused = false
	_torches_allumees = true
	_torches(true)


func _montrer(visibles: bool) -> void:
	var iso := Presentation3D.instance()
	for n in (iso.get("_noeuds_murs_meubles") as Array):
		(n as Node3D).visible = visibles


func _emprise(active: bool) -> void:
	var iso := Presentation3D.instance()
	for m in (iso.get("_mats_murs_meubles") as Dictionary).values():
		(m as ShaderMaterial).set_shader_parameter("emprise_preuve", active)


## La boîte de l'objet à l'écran : ses huit coins (emprise × saillie) projetés par la caméra de J1.
func _cadre(famille: String, o: Dictionary) -> void:
	var iso := Presentation3D.instance()
	var cam = iso.call("_camera_de", 0) if iso != null else null
	var vue: Viewport = iso.viewport_ecran(0) if iso != null else null
	if cam == null or vue == null:
		return
	var logique := vue.get_visible_rect().size
	var em := MursMeublesIsoT.emprise(famille, int(o["variante"]))
	var saillie: float = MursMeublesIsoT.SAILLIES[famille]
	var n: Vector2 = o["n"]
	var mini := Vector2(INF, INF)
	var maxi := Vector2(-INF, -INF)
	for ds in [-em[0], em[0]]:
		for y in [em[1], em[2]]:
			for e in [0.0, saillie]:
				var q := MursMeublesIsoT.point(n, float(o["d"]), float(o["s"]) + ds, y, e)
				var p: Vector2 = cam.vers_ecran(Vector2(q.x, q.z), logique, q.y) * Vector2(_taille) / logique
				mini = mini.min(p)
				maxi = maxi.max(p)
	print("CADRE %s %.1f,%.1f %.1f,%.1f" % [famille, mini.x, mini.y, maxi.x, maxi.y])
