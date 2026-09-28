extends "res://tools/planche_ombre.gd"
## L'OMBRE DES CLASSES, SUITE — l'orientation de J2 sous la torche de J1 (session cloud ombre-orientation, 2026-09-27).
##
## `planche_ombre.gd` (dont ce banc hérite sans toucher à ses prises) a mesuré l'écart du capteur entre les dix classes
## avec J2 DE PROFIL seulement. Ici, les mêmes places (trouvées de la même façon : Parasite, de profil, ombre
## d'aujourd'hui), puis pour chaque classe J2 tourné de huit façons par rapport à la torche :
##   θ = 0 `face` (il regarde la torche), 45 `diag_face_g`, 90 `profil_g` (la torche à sa gauche — le profil de la base),
##   135 `diag_dos_g`, 180 `dos`, 225 `diag_dos_d`, 270 `profil_d`, 315 `diag_face_d`.
## La visée de J2 est la direction « vers la torche » tournée de θ (sens du repère de Godot, y vers le bas).
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/planche_orientation.tscn -- \
##     --sortie=user://orient45 --led-murs-fige=0.5 [--lacet=0] [--classes=pistolet,pompe]
##
## ⚠️ **La rotation de J2 est POSÉE à chaque image, pas laissée à la visée.** Le joueur tourne vers sa visée par
## `lerp_angle` à 18 par seconde : à 60 images par seconde il lui reste 12 % de l'angle après six images — assez pour
## qu'un demi-tour ne soit pas fini au moment de la prise. L'occluder est enfant du joueur : c'est sa rotation qui
## compte, et le corps voxel est déjà reposé à la visée exacte (`_avant_le_rendu`).
##
## Sans ombre propre (`sans`), la classe et l'orientation ne changent rien au capteur (la base l'a constaté pour la
## classe) : `sans` n'est pris que pour le Parasite dans les huit orientations, plus deux classes de contrôle.

const ORIENTATIONS := {"face": 0.0, "diag_face_g": 45.0, "profil_g": 90.0, "diag_dos_g": 135.0, "dos": 180.0,
	"diag_dos_d": 225.0, "profil_d": 270.0, "diag_face_d": 315.0}
const SCENES_O := ["b10", "mi"]
const CLASSES_SANS := ["pistolet", "pompe", "spectre"]

var _theta := 90.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_orientation : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://orient")
	_images = _drapeau(args, "--images")
	var seules := _valeur(args, "--classes", "").strip_edges()
	var slugs: Array = SLUGS if seules == "" else Array(seules.split(","))
	print("=== Planche de l'orientation (ombre des classes) ===")
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
	_theta = 90.0
	await _trouver_les_positions(portee)

	for scene in SCENES_O:
		print("\n=== place %s ===" % scene)
		# Sans ombre propre : la référence du calcul géométrique, et la preuve qu'orientation et classe n'y changent rien.
		for slug in CLASSES_SANS:
			await _mode_d_ombre(slug, "sans")
			for o in ORIENTATIONS:
				if slug != "pistolet" and not (o in ["face", "profil_g", "dos"]):
					continue
				await _mesure_o(slug, "sans", scene, o)
		for slug in slugs:
			print("--- %s ---" % slug)
			await _mode_d_ombre(slug, "etoile")
			for o in ORIENTATIONS:
				await _mesure_o(slug, "etoile", scene, o)
			# Le contrôle : la première orientation reprise après les sept autres (une rotation mal suivie s'y lirait).
			await _mesure_o(slug, "etoile", scene, "face", "ctl")
	await _mode_d_ombre("pistolet", "etoile")

	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"j1": [_j1.x, _j1.y], "axe": [_axe.x, _axe.y], "positions": _positions,
		"fenetre": [_taille.x, _taille.y], "commit": _commit(), "lacet": GameSettings.lacet_duel,
		"option_lacet": GameSettings.option_lacet, "rayon_lu_px": _rayon_lu(), "orientations": ORIENTATIONS,
		"prises": _journal}, "  "))
	f.close()
	print("\n%d prise(s) dans %s" % [_journal.size(), ProjectSettings.globalize_path(_dossier)])
	_sortir(0)


## La visée de J2 : la direction vers la torche de J1, tournée de θ.
func _visee_j2() -> Vector2:
	return (-_axe).rotated(deg_to_rad(_theta))


func _poser(p2: Vector2, j2_dans_le_cadre := true) -> void:
	super._poser(p2, j2_dans_le_cadre)
	var v := _visee_j2()
	_poses[1][1] = v
	_viser(1, v)
	_main.p2.global_rotation = v.angle()


func _mesure_o(slug: String, mode: String, scene: String, orientation: String, suffixe := "") -> void:
	_theta = float(ORIENTATIONS[orientation])
	var n := _journal.size()
	await _mesure(slug, mode, scene, ("%s_%s" % [orientation, suffixe]) if suffixe != "" else orientation)
	if _journal.size() > n:
		var l: Dictionary = _journal[-1]
		l["orientation"] = orientation
		l["theta"] = _theta
		l["controle"] = suffixe != ""
		l["visee_j2"] = [_visee_j2().x, _visee_j2().y]
