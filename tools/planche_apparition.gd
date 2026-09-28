extends "res://tools/planche_orientation.gd"
## L'OMBRE DES CLASSES, SUITE — OÙ UN CORPS APPARAÎT, et ce que la voie (d) y change (session cloud ombre-orientation,
## 2026-09-27). Hérite de `planche_orientation.gd` (mêmes places, même mise en scène) ; trois parties, un processus :
##
## 1. `balayage` — le capteur de J2 SANS ombre propre (occluder caché), tous les 2 px de `b15` à `noir` le long de l'axe :
##    son profil 64 points. Avec la géométrie de l'occluder, il suffit à prédire le maximum de l'anneau de n'importe
##    quelle classe dans n'importe quelle orientation, donc où son premier pixel s'allume (`analyse_orientation.py`).
## 2. `recherche` — à l'IMAGE, pour quelques cas (`--cas=pompe:profil_d,occulteur:diag_face_d,…`) et chaque mode de
##    `--ombre-compensee` (0 aujourd'hui, 1, 2) : la plus grande distance à J1 où le corps de J2 montre au moins un pixel
##    allumé, par dichotomie au pixel entre `b10` et `noir`. Compté contre le « zéro » (voir `_trois_images`) :
##    masque = |silhouette − zéro| > 2, visible = masque ∧ réel plus clair que le zéro sur un canal.
## 3. `planche` — les dix classes (orientation `--orientation-planche`, profil de la base par défaut) aux places `b10`
##    et `mi`, en trois modes, plus la silhouette et le vide : de quoi dire ce que la compensation change au pixel.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/planche_apparition.tscn -- \
##     --sortie=user://appar45 --led-murs-fige=0.5 [--lacet=0] [--cas=…] [--sans-planche] [--sans-balayage]

const MODES_D := [0, 1, 2]
const CAS_DEFAUT := "pistolet:profil_g,pompe:profil_g,pompe:profil_d,occulteur:profil_g,spectre:profil_g,arbalete:dos"
const DEMI_FENETRE := 110

var _planche := true
var _balayage := true
## Le corps de J2 rendu OPAQUE dans la prise réelle, sa lumière intacte (voir `_avant_le_rendu`).
var _opaque := false
## Le corps de J2 opaque et SANS lumière lue (capteur coupé, lumière reçue 0) : la référence du compte.
var _zero := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_apparition : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://appar")
	_planche = not _drapeau(args, "--sans-planche")
	_balayage = not _drapeau(args, "--sans-balayage")
	var cas := Array(_valeur(args, "--cas", CAS_DEFAUT).split(","))
	var o_planche := _valeur(args, "--orientation-planche", "profil_g")
	var seules := _valeur(args, "--classes", "").strip_edges()
	var slugs: Array = SLUGS if seules == "" else Array(seules.split(","))
	print("=== Planche de l'apparition (ombre des classes) ===")
	if not await _mettre_en_scene():
		return
	var d_b10 := _de(_positions["b10"]).distance_to(_j1)
	var d_noir := _de(_positions["noir"]).distance_to(_j1)
	var d_b15 := _de(_positions["b15"]).distance_to(_j1)

	# 1. Le balayage sans ombre propre.
	if _balayage:
		print("\n=== balayage ===")
		await _mode_d_ombre("pistolet", "sans")
		_theta = 90.0
		var d := floorf(d_b15)
		while d <= d_noir:
			var p2 := _j1 + _axe * d
			await _tenir(p2, 6)
			var niv := _niveau(1)
			_journal.append({"partie": "balayage", "distance": d, "corps": [p2.x, p2.y], "niveau": niv[0],
				"niveau_max": niv[1], "profil": _profil(1),
				"torche": [_main.p1.flashlight.global_position.x, _main.p1.flashlight.global_position.y]})
			d += 2.0
		print("  %d points de %.0f à %.0f px" % [_journal.size(), d_b15, d_noir])

	# 2. Les recherches à l'image.
	for c in cas:
		var bouts: PackedStringArray = String(c).split(":")
		var slug := bouts[0]
		var o := bouts[1] if bouts.size() > 1 else "profil_g"
		_theta = float(ORIENTATIONS[o])
		print("\n=== recherche %s %s ===" % [slug, o])
		await _mode_d_ombre(slug, "etoile")
		for m in MODES_D:
			await _rechercher(slug, o, m, d_b10, d_noir)
	OmbreCompensee.mode_force = -1

	# 3. La planche.
	if _planche:
		_theta = float(ORIENTATIONS[o_planche])
		for slug in slugs:
			print("\n=== planche %s ===" % slug)
			await _mode_d_ombre(slug, "etoile")
			for scene in ["b10", "mi"]:
				await _prises_planche(slug, o_planche, scene)
	OmbreCompensee.mode_force = -1
	await _mode_d_ombre("pistolet", "etoile")

	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"j1": [_j1.x, _j1.y], "axe": [_axe.x, _axe.y], "positions": _positions,
		"fenetre": [_taille.x, _taille.y], "commit": _commit(), "lacet": GameSettings.lacet_duel,
		"option_lacet": GameSettings.option_lacet, "rayon_lu_px": _rayon_lu(), "orientations": ORIENTATIONS,
		"prises": _journal}, "  "))
	f.close()
	print("\n%d ligne(s) dans %s" % [_journal.size(), ProjectSettings.globalize_path(_dossier)])
	_sortir(0)


## La mise en scène de `planche_orientation` (la même, sans ses prises) : la manche, la vue iso, les places.
func _mettre_en_scene() -> bool:
	_poser_la_fenetre()
	await _lire_l_horloge()
	AudioServer.set_bus_mute(0, true)
	VoxelCatalogue.forcer_detail = 0
	Charte.ombre_ronde_forcee = -1.0
	OmbreCompensee.mode_force = 0
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
		return false
	_prendre_les_commandes()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0):
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return false
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
		return false
	RenderingServer.frame_pre_draw.connect(_avant_le_rendu)
	for j in [_main.p1, _main.p2]:
		(j.noise as FastNoiseLite).frequency = 0.0
	await _basculer_detail(0)
	_equiper(0, "pistolet")
	_equiper(1, "pistolet")
	var portee: float = float(_main.p1.current_weapon.portee_torche())
	if not _choisir_j1(portee):
		_sortir(1)
		return false
	print("  J1 %s, axe %s, portée %.0f px, lacet %s %s" % [str(_j1), str(_axe), portee,
		str(GameSettings.lacet_duel), GameSettings.option_lacet])
	_theta = 90.0
	await _trouver_les_positions(portee)
	return true


## ⚠️ **Le corps de J2 est rendu opaque dans la prise réelle.** Hors de la lumière, un corps s'EFFACE (son opacité suit
## celle de son sprite de vue de dessus) et laisse voir le sol derrière lui : au premier essai, des « pixels visibles »
## s'allumaient à 390 px, capteur à 0, et le Parasite « apparaissait » à 393 px dans un mode et à 331 px dans l'autre,
## pour un facteur identique. L'effacement est une règle de la vue de dessus, pas de l'ombre propre : ici, on mesure la
## seule décision de l'éclairage du corps (le shader, capteur actif), opacité 1 et sans liseré de silhouette.
func _avant_le_rendu() -> void:
	super._avant_le_rendu()
	if not (_opaque or _zero) or _iso == null:
		return
	var mat := _iso._mat_corps[1] as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("capteur_actif", not _zero)
		mat.set_shader_parameter("lumiere_recue", 0.0)
		for k in [1, 2]:
			mat.set_shader_parameter("opacite_%d" % k, 1.0)
			mat.set_shader_parameter("silhouette_%d" % k, Color(0, 0, 0, 0))


## Trois images au même instant : le zéro (corps opaque, aucune lumière lue), la silhouette (corps en pleine lumière),
## le réel (corps opaque, sa lumière lue).
##
## ⚠️ **Le zéro, pas le vide.** Le second essai comptait encore des pixels à 377-393 px, capteur à 0, et pas les mêmes
## d'un mode à l'autre pour un même facteur : le masque « silhouette − vide » prenait aussi le sol autour du corps (son
## ombre de contact n'existe pas quand il est caché), un sol faiblement éclairé qui bouge d'une prise à l'autre. Contre
## le même corps, opaque, sans lumière lue, le masque est le corps seul, et un pixel « visible » est un pixel que la
## lecture du capteur a rendu plus clair — la seule chose que la voie (d) change.
func _trois_images(p2: Vector2) -> Array:
	await _tenir(p2, 6)
	_zero = true
	await _tenir(p2, 3)
	var vide: Image = await _capturer("vue")
	_zero = false
	_sil_corps[1] = true
	await _tenir(p2, 3)
	var sil: Image = await _capturer("vue")
	_sil_corps[1] = false
	_opaque = true
	await _tenir(p2, 3)
	var reel: Image = await _capturer("vue")
	_opaque = false
	return [vide, sil, reel]


func _ecran(p2: Vector2, img: Image) -> Vector2:
	var cam := _iso._camera_de(0)
	var logique := _iso.viewport_ecran(0).get_visible_rect().size
	return cam.vers_ecran(p2, logique, 16.0) * Vector2(img.get_size()) / logique


## [silhouette, visibles, visibles sur sol noir, plus haut canal du corps] dans la fenêtre autour de J2.
func _compter(p2: Vector2, images: Array) -> Array:
	var vide: Image = images[0]
	var sil: Image = images[1]
	var reel: Image = images[2]
	if vide == null or sil == null or reel == null:
		return [-1, -1, -1, -1]
	var c := Vector2i(_ecran(p2, reel))
	var n_sil := 0
	var n_vis := 0
	var n_noir := 0
	var haut := 0
	for y in range(maxi(0, c.y - DEMI_FENETRE), mini(reel.get_height(), c.y + DEMI_FENETRE)):
		for x in range(maxi(0, c.x - DEMI_FENETRE), mini(reel.get_width(), c.x + DEMI_FENETRE)):
			var v := vide.get_pixel(x, y)
			var s := sil.get_pixel(x, y)
			if maxf(maxf(absf(s.r - v.r), absf(s.g - v.g)), absf(s.b - v.b)) * 255.0 <= 2.0:
				continue
			n_sil += 1
			var r := reel.get_pixel(x, y)
			var rm := int(round(maxf(maxf(r.r, r.g), r.b) * 255.0))
			var hausse := int(round(maxf(maxf(r.r - v.r, r.g - v.g), r.b - v.b) * 255.0))
			if hausse > 0:
				n_vis += 1
				haut = maxi(haut, rm)
				if maxf(maxf(v.r, v.g), v.b) == 0.0:
					n_noir += 1
	return [n_sil, n_vis, n_noir, haut]


func _mesurer_a(slug: String, o: String, m: int, d: float) -> Array:
	var p2 := _j1 + _axe * d
	var imgs := await _trois_images(p2)
	var compte := _compter(p2, imgs)
	var niv := _niveau(1)
	var mat := _iso._mat_corps[1] as ShaderMaterial
	var comp = mat.get_shader_parameter("compensation_ombre") if mat != null else null
	_journal.append({"partie": "recherche", "classe": slug, "orientation": o, "mode_d": m, "distance": d,
		"corps": [p2.x, p2.y], "silhouette": compte[0], "visibles": compte[1], "visibles_sur_noir": compte[2],
		"haut": compte[3], "niveau": niv[0], "niveau_max": niv[1],
		"compensation": float(comp) if comp != null else 1.0, "opacite": mat.get_shader_parameter("opacite_1")})
	print("    %s %s d%d  %.1f px : silhouette %d, visibles %d (sur noir %d, haut %d), capteur %.4f max %.4f, ×%s"
		% [slug, o, m, d, compte[0], compte[1], compte[2], compte[3], niv[0], niv[1], str(comp)])
	return compte


## La plus grande distance (au pixel) où le corps montre au moins un pixel allumé.
func _rechercher(slug: String, o: String, m: int, d_min: float, d_max: float) -> void:
	OmbreCompensee.mode_force = m
	var lo := d_min
	var hi := d_max
	var au_bas := await _mesurer_a(slug, o, m, lo)
	if int(au_bas[1]) <= 0:
		_journal.append({"partie": "apparition", "classe": slug, "orientation": o, "mode_d": m, "distance": -1.0,
			"note": "aucun pixel dès b10"})
		print("  ✗ %s %s d%d : aucun pixel dès b10" % [slug, o, m])
		return
	while hi - lo > 1.0:
		var mid := roundf((lo + hi) * 0.5)
		if mid <= lo or mid >= hi:
			break
		var r := await _mesurer_a(slug, o, m, mid)
		if int(r[1]) > 0:
			lo = mid
		else:
			hi = mid
	_journal.append({"partie": "apparition", "classe": slug, "orientation": o, "mode_d": m, "distance": lo,
		"distance_eteint": hi})
	print("  → %s %s d%d : dernier pixel allumé à %.0f px, éteint à %.0f px" % [slug, o, m, lo, hi])


## Les images de la planche : vide et silhouette une fois, puis le réel dans les trois modes.
func _prises_planche(slug: String, o: String, scene: String) -> void:
	var p2 := _de(_positions[scene])
	OmbreCompensee.mode_force = 0
	await _tenir(p2, IMAGES_REPOS)
	var imgs := await _trois_images(p2)
	var base := "%s_%s_%s" % [slug, scene, o]
	imgs[0].save_png("%s/%s_zero.png" % [_dossier, base])
	imgs[1].save_png("%s/%s_sil.png" % [_dossier, base])
	# Le sol seul (corps caché) : pour « rien de plus clair que la surface qui le porte ».
	_cache_corps[1] = true
	await _tenir(p2, 3)
	var sol: Image = await _capturer("vue")
	_cache_corps[1] = false
	sol.save_png("%s/%s_vide.png" % [_dossier, base])
	var ecran := _ecran(p2, imgs[2])
	for m in MODES_D:
		OmbreCompensee.mode_force = m
		_opaque = true
		await _tenir(p2, 6)
		var reel: Image = await _capturer("vue")
		_opaque = false
		reel.save_png("%s/%s_d%d.png" % [_dossier, base, m])
		var mat := _iso._mat_corps[1] as ShaderMaterial
		var comp = mat.get_shader_parameter("compensation_ombre")
		var niv := _niveau(1)
		var compte := _compter(p2, [imgs[0], imgs[1], reel])
		_journal.append({"partie": "planche", "classe": slug, "orientation": o, "scene": scene, "mode_d": m,
			"fichier": "%s_d%d.png" % [base, m], "vide": base + "_vide.png", "zero": base + "_zero.png", "sil": base + "_sil.png",
			"ecran": [ecran.x, ecran.y], "niveau": niv[0], "niveau_max": niv[1],
			"compensation": float(comp) if comp != null else 1.0, "silhouette": compte[0], "visibles": compte[1],
			"haut": compte[3]})
		print("  · %s d%d  capteur %.4f  ×%s  visibles %d/%d  haut %d" % [base, m, niv[0], str(comp), compte[1],
			compte[0], compte[3]])
	OmbreCompensee.mode_force = 0
