extends "res://tools/planche_q33.gd"
## L'OMBRE DES CLASSES — d'où vient l'écart du capteur entre les dix classes (session cloud ombre-classes, 2026-09-27).
##
## La planche Q33 (dont ce banc hérite, sans toucher à ses prises) a trouvé qu'au même endroit, sous la même torche
## (Parasite), le capteur du corps de J2 lit une lumière différente selon sa classe. Hypothèse de Beauté : l'ombre que
## chaque corps jette sur son PROPRE capteur a la forme de sa silhouette. Ce banc la met à l'épreuve, dans UN processus :
## les mêmes places, trouvées une fois avec le Parasite et l'ombre d'aujourd'hui, puis pour chaque classe et chaque
## mode d'ombre de J2 :
##   `etoile`  l'occluder d'aujourd'hui (l'étoile de la silhouette) ;
##   `rond12`  `--ombre-ronde` (le disque du torse, 12), par `Charte.ombre_ronde_forcee` ;
##   `rond18`  `--ombre-ronde=18` (le cercle d'avant le 2026-08-26) ;
##   `sans`    l'occluder de J2 caché : aucune ombre propre (le capteur de la voie « b », mais sans ombre au sol) ;
##   `couche`  l'étoile gardée, sa `visibility_layer` à 0 : si le moteur trie les occluders par le masque de la vue,
##             le capteur ne la voit plus et la vue principale si — la voie « b » pour de vrai. Mesuré, pas supposé.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/planche_ombre.tscn -- \
##     --sortie=user://ombre --led-murs-fige=0.5 [--classes=pistolet,fusil] [--sans-images]
##
## Le journal (`journal.json`) porte, pour chaque prise : le niveau (moyenne de l'anneau lu), son maximum, le PROFIL de
## l'anneau (64 points, dans le repère du monde), l'occluder de J2 en coordonnées du monde et la position de la torche
## de J1 : de quoi refaire le calcul géométrique hors du jeu (`docs/iso/cloud/ombre-classes/analyse_ombre.py`).

const MODES := ["etoile", "rond12", "rond18", "sans", "couche"]
const SCENES := ["mi", "b15", "b10"]
## Les images : deux places, les modes qui répondent aux trois voies.
const SCENES_IMAGES := ["mi", "b10"]
const MODES_IMAGES := ["etoile", "rond12", "sans", "couche"]

var _images := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_ombre : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://ombre")
	_images = not _drapeau(args, "--sans-images")
	var seules := _valeur(args, "--classes", "").strip_edges()
	var slugs: Array = SLUGS if seules == "" else Array(seules.split(","))
	print("=== Planche de l'ombre des classes ===")
	_poser_la_fenetre()
	await _lire_l_horloge()
	AudioServer.set_bus_mute(0, true)
	VoxelCatalogue.forcer_detail = 0
	Charte.ombre_ronde_forcee = -1.0
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = true
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.terminee.emit()
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
		await _attendre_disparition(allumage, 3.0)
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
	_sans_hud = true
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	await _passer_sur_la_carte_des_murs_bas()
	_iso = Presentation3D.instance()
	if _iso == null:
		printerr("✗ aucune Presentation3D : la vue iso n'est pas en place")
		_sortir(1)
		return
	RenderingServer.frame_pre_draw.connect(_avant_le_rendu)
	for j in [_main.p1, _main.p2]:
		(j.noise as FastNoiseLite).frequency = 0.0
	await _basculer_detail(0)

	_equiper(0, "pistolet")
	_equiper(1, "pistolet")
	var arme = _main.p1.current_weapon
	var portee: float = float(arme.portee_torche())
	if not _choisir_j1(portee):
		_sortir(1)
		return
	print("  J1 %s, axe %s, portée %.0f px, lacet %s %s" % [str(_j1), str(_axe), portee,
		str(GameSettings.lacet_duel), GameSettings.option_lacet])
	await _trouver_les_positions(portee)

	for slug in slugs:
		print("\n--- %s ---" % slug)
		for mode in MODES:
			await _mode_d_ombre(slug, mode)
			for scene in SCENES:
				await _mesure(slug, mode, scene)
		# Le contrôle : l'étoile reprise en fin de classe, après tous les autres modes. Si le mode laissait une trace
		# (un occluder resté caché, une couche restée à 0), elle se lirait ici.
		await _mode_d_ombre(slug, "etoile")
		await _mesure(slug, "etoile", "b10", "ctl")
	await _mode_d_ombre("pistolet", "etoile")

	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"j1": [_j1.x, _j1.y], "axe": [_axe.x, _axe.y], "positions": _positions,
		"fenetre": [_taille.x, _taille.y], "commit": _commit(), "lacet": GameSettings.lacet_duel,
		"option_lacet": GameSettings.option_lacet, "rayon_lu_px": _rayon_lu(),
		"prises": _journal}, "  "))
	f.close()
	print("\n%d prise(s) dans %s" % [_journal.size(), ProjectSettings.globalize_path(_dossier)])
	_sortir(0)


## J2 de la classe `slug`, son ombre dans le mode demandé. Toujours rééquipé : l'occluder se pose à l'équipement.
func _mode_d_ombre(slug: String, mode: String) -> void:
	match mode:
		"rond12":
			Charte.ombre_ronde_forcee = 12.0
		"rond18":
			Charte.ombre_ronde_forcee = 18.0
		_:
			Charte.ombre_ronde_forcee = -1.0
	_equiper(1, slug)
	var occ := _main.p2.get_node("LightOccluder2D") as LightOccluder2D
	occ.visible = mode != "sans"
	occ.visibility_layer = 0 if mode == "couche" else 1
	Charte.ombre_ronde_forcee = -1.0


func _rayon_lu() -> float:
	return minf(Presentation3D.RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0)


## Les 64 points de l'anneau lu (luminance Rec. 709, comme `_niveau`), dans l'ordre des angles du MONDE.
func _profil(j: int) -> Array:
	var c = _iso._capteurs[0][j]
	if c == null:
		return []
	var img: Image = (c as CapteurCorps).get_texture().get_image()
	var texels_par_px := float(CapteurCorps.TAILLE) / CapteurCorps.MONDE_PX
	var r := _rayon_lu() * texels_par_px
	var centre := Vector2(img.get_width(), img.get_height()) * 0.5
	var out := []
	for a in 64:
		var q := centre + Vector2.from_angle(TAU * float(a) / 64.0) * r
		var px := img.get_pixelv(Vector2i(q))
		out.append(snappedf(px.r * 0.2126 + px.g * 0.7152 + px.b * 0.0722, 0.0001))
	return out


## La part du disque entier du capteur (rayon 18) qui reçoit de la lumière, et sa moyenne.
func _disque(j: int) -> Array:
	var c = _iso._capteurs[0][j]
	if c == null:
		return [-1.0, -1.0]
	var img: Image = (c as CapteurCorps).get_texture().get_image()
	var texels_par_px := float(CapteurCorps.TAILLE) / CapteurCorps.MONDE_PX
	var r := (CapteurCorps.RAYON_PX - 1.0) * texels_par_px
	var centre := Vector2(img.get_width(), img.get_height()) * 0.5
	var n := 0
	var eclaires := 0
	var somme := 0.0
	for y in range(int(centre.y - r), int(centre.y + r) + 1):
		for x in range(int(centre.x - r), int(centre.x + r) + 1):
			if Vector2(x, y).distance_to(centre) > r:
				continue
			var px := img.get_pixel(x, y)
			var v := px.r * 0.2126 + px.g * 0.7152 + px.b * 0.0722
			n += 1
			somme += v
			if v > 0.01:
				eclaires += 1
	return [float(eclaires) / float(n), somme / float(n)]


func _mesure(slug: String, mode: String, scene: String, suffixe := "") -> void:
	if not _positions.has(scene):
		return
	var p2 := _de(_positions[scene])
	var place := p2
	await _tenir(p2, IMAGES_POSE if place == _derniere_place else IMAGES_REPOS)
	_derniere_place = place
	var niv := _niveau(1)
	var disque := _disque(1)
	var occ := _main.p2.get_node("LightOccluder2D") as LightOccluder2D
	var poly := []
	for p in occ.occluder.polygon:
		var w: Vector2 = occ.global_transform * p
		poly.append([snappedf(w.x, 0.001), snappedf(w.y, 0.001)])
	var torche: Vector2 = _main.p1.flashlight.global_position
	var nom := "%s_%s_%s%s" % [slug, scene, mode, ("_" + suffixe) if suffixe != "" else ""]
	var ligne := {"classe": slug, "scene": scene, "mode": mode, "controle": suffixe != "", "niveau": niv[0],
		"niveau_max": niv[1], "profil": _profil(1), "disque_eclaire": disque[0], "disque_moyen": disque[1],
		"occluder": poly, "occluder_visible": occ.visible, "occluder_couche": occ.visibility_layer,
		"torche": [torche.x, torche.y], "torche_rotation": _main.p1.flashlight.global_rotation,
		"corps": [p2.x, p2.y], "j2_rotation": _main.p2.global_rotation}
	if _images and suffixe == "" and scene in SCENES_IMAGES and mode in MODES_IMAGES:
		var img: Image = await _capturer("vue")
		if img != null:
			img.save_png("%s/%s.png" % [_dossier, nom])
			var cam := _iso._camera_de(0)
			var logique := _iso.viewport_ecran(0).get_visible_rect().size
			var taille := Vector2(img.get_size())
			var ecran: Vector2 = cam.vers_ecran(p2, logique, 16.0) * taille / logique
			var ecran_j1: Vector2 = cam.vers_ecran(_j1, logique, 16.0) * taille / logique
			ligne.merge({"fichier": nom + ".png", "ecran": [ecran.x, ecran.y], "ecran_j1": [ecran_j1.x, ecran_j1.y],
				"taille": [img.get_width(), img.get_height()]})
	_journal.append(ligne)
	print("  · %s  capteur %.4f (max %.3f)  disque éclairé %.3f" % [nom, niv[0], niv[1], disque[0]])
