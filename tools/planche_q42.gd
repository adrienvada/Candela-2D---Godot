extends "res://tools/photographe.gd"
## Q42 — LE CORPS IGNORE SA PROPRE OMBRE : la planche avant / après (2026-09-29).
##
## Le vrai `main.tscn`, en ÉCRAN SCINDÉ (les deux vues iso, 45° B : J1 à 45°, J2 à 225°), la vraie torche du porteur,
## les vrais capteurs de corps. Le porteur est le Parasite (torche allumée) ; la cible est de la classe X, torche éteinte,
## posée dans l'axe du faisceau à la moitié de la portée (`mi`), tournée de θ par rapport à la direction « vers la torche ».
## Les deux rôles s'échangent : `--porteurs=0,1` (J1 porte et regarde J2, puis J2 porte et regarde J1) — c'est la
## preuve d'équité : la même règle des deux côtés, chacun dans SA vue.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . --resolution 1920x1080 res://tools/planche_q42.tscn -- \
##     --sortie=<dossier> --led-murs-fige=0.5 --no-eos [--classes=fumiste,incendiaire,occulteur] [--images] [--zoom=1.5]
##
## Autres drapeaux : `--orientations=profil_d,face` (parmi `ORIENTATIONS`), `--porteurs=0,1`, `--taille=960x540` (les prises
## chiffrées n'ont pas besoin de pixels : ~0,25 s par image sous llvmpipe, contre plusieurs secondes à 1920×1080), `--mur` (un
## mur d'essai entre la torche et la cible), `--lampes=F,H,B` (ne garder que la torche, le halo, la rétrodiffusion), `--dessus`
## (la vue de dessus : les textures de `vp1`, `vp2` et de la racine, à comparer pixel à pixel entre deux arbres).
## Avant / après : lancer la même planche dans l'arbre de la base et dans celui de la branche.
##
## ## Q55 — le capteur de SOI (2026-09-29)
## Le même banc lit aussi ce que le corps reçoit dans SA PROPRE vue (`soi_mean`, `soi_max` du journal : le capteur du corps
## de la cible dans la vue de la cible, éclairé par la torche du porteur) : avec `--mur`, un mur entre les deux doit le noircir
## chez J1 comme chez J2. `--vue-unique=0|1` ne regarde que la vue de J1 (l'hôte, l'entraînement) ou celle de J2 (le client) :
## lancer alors `--porteurs=1` (respectivement `--porteurs=0`), puisque la cible est le joueur regardé. `--soi` écrit, pour
## chaque prise d'image, le corps découpé dans SA vue (`_soi_vue`), son capteur (`_soi_capteur`) et la vue entière réduite
## (`_soi_cadre`). `--distance=<px>` remplace la moitié de la portée (le halo et la rétrodiffusion se lisent de près).
## `--mutuel` : la torche de la cible reste allumée aussi (par défaut, seule celle du porteur l'est) — pour lire si la torche
## PROPRE éclaire le capteur de soi. Mesuré : la torche allumée et sa rétrodiffusion l'éclairent à elles seules (0,914, un mur entre
## les deux torches), et la torche adverse s'y ajoute jusqu'à la saturation (1,000, sans mur) — un mur ne retire donc que la part
## de la torche ADVERSE.
##
## ## Ce qu'il écrit
## - `journal.json` : pour chaque prise, le niveau que LIT le corps dans le capteur de la vue du porteur (moyenne et
##   maximum de l'anneau où le shader des corps lit, `rayon_lu_px`), et celui de son capteur dans SA propre vue ;
## - avec `--images` : le corps découpé dans la vue du porteur (`vue`), le capteur brut (`capteur`), et, pour deux prises,
##   la lightmap entière de chaque vue (`lightmap`) — l'ombre au sol de l'étoile doit y être la même avant et après.
##
## ## Le même instant
## Comme `planche_q33` des sessions cloud (dont il reprend les précautions, sans en hériter) : respiration des torches
## figée (`noise.frequency = 0`), poussière du faisceau coupée, corps reposés à leur position et à leur visée EXACTES
## avant chaque rendu (`frame_pre_draw`), caméras sans lissage. La respiration du bandeau LED se tient par le drapeau du
## jeu `--led-murs-fige=0.5`.

const SLUGS := ["pistolet", "fusil", "pompe", "arbalete", "occulteur", "fumiste", "incendiaire", "sentinelle",
	"allumeur", "spectre"]
## θ : la visée de la cible = la direction « vers la torche » tournée de θ. 270° et 315° sont les deux où le Fumiste,
## l'Incendiaire et l'Occulteur restaient noirs (rapport `cloud-ombre-orientation`) : la torche vient du côté de l'arme.
const ORIENTATIONS := {"face": 0.0, "diag_face_g": 45.0, "profil_g": 90.0, "diag_dos_g": 135.0, "dos": 180.0,
	"diag_dos_d": 225.0, "profil_d": 270.0, "diag_face_d": 315.0}
const ORIENTATIONS_DEFAUT := ["face", "profil_g", "dos", "profil_d", "diag_face_d"]
const CLASSES_IMAGES := ["fumiste", "incendiaire", "occulteur"]
const IMAGES_POSE := 8
const IMAGES_REPOS := 30
const DECOUPE_PX := 240

var _iso: Presentation3D
var _journal: Array = []
var _j1 := Vector2.ZERO
var _axe := Vector2.RIGHT
var _portee := 0.0
## Les poses exactes des deux corps au prochain rendu : [position, visée].
var _poses := [[Vector2.ZERO, Vector2.RIGHT], [Vector2.ZERO, Vector2.RIGHT]]
var _derniere_place := ""
var _images := false
var _lightmaps_prises := 0
## `--lampes=F,H,B` : ne garder que ces lumières allumées (F la torche, H le halo de proximité, B la rétrodiffusion) — pour
## savoir laquelle fait quoi. Vide : toutes, comme le jeu.
var _lampes := ""
## `--mur` : un mur posé exprès (occluder à la couche du décor, dans le monde partagé) entre la torche et la cible, pour prouver
## qu'il ombre toujours le capteur — et lire ce que reçoit le capteur de la cible dans SA propre vue.
var _mur_pose := false
var _mur: LightOccluder2D
## `--dessus` : la vue de dessus (`--2d`, débogage), sans capteur — ce que les lightmaps et la racine dessinent d'un duel où
## les étoiles doivent ombrer comme avant. Écrit la texture de chaque vue du duel (`vp1`, `vp2`) et, une fois, celle de la racine
## en vue unique, pour comparer deux arbres pixel à pixel.
var _dessus := false
## Q55 — `--soi` : les images du corps dans SA propre vue. `--vue-unique=N` : la vue iso de N seul (-1 : écran scindé).
## `--distance=` : l'écart torche → cible en px (0 : la moitié de la portée).
var _soi_images := false
var _vue_unique_id := -1
var _distance_px := 0.0
var _mutuel := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_q42 : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://q42")
	_images = _drapeau(args, "--images")
	_lampes = _valeur(args, "--lampes", "")
	_mur_pose = _drapeau(args, "--mur")
	_dessus = _drapeau(args, "--dessus")
	_soi_images = _drapeau(args, "--soi")
	_vue_unique_id = int(_valeur(args, "--vue-unique", "-1"))
	_distance_px = float(_valeur(args, "--distance", "0"))
	_mutuel = _drapeau(args, "--mutuel")
	var classes_voulues := _valeur(args, "--classes", "").strip_edges()
	var classes: Array = SLUGS if classes_voulues == "" else Array(classes_voulues.split(","))
	var orientations_voulues := _valeur(args, "--orientations", "").strip_edges()
	var orientations: Array = ORIENTATIONS_DEFAUT if orientations_voulues == "" \
		else Array(orientations_voulues.split(","))
	var porteurs: Array = []
	for p in _valeur(args, "--porteurs", "0,1").split(","):
		porteurs.append(int(p))
	_taille = _lire_taille(_valeur(args, "--taille", "1920x1080"))
	print("=== Planche Q42 : le corps ignore sa propre ombre ===")
	_poser_la_fenetre()
	AudioServer.set_bus_mute(0, true)
	var intro_vue_avant: bool = GameSettings.intro_vue
	GameSettings.intro_vue = true
	if _dessus:
		GameSettings.mode_iso = false
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	GameSettings.intro_vue = intro_vue_avant
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = true
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
		await _attendre_disparition(allumage, 3.0)

	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 120.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	_prendre_les_commandes()
	var f0 := Engine.get_process_frames()
	var t_dec := Time.get_ticks_msec()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 180.0):
		print("  décompte : %d images en %.1f s, reste %.2f s" % [Engine.get_process_frames() - f0,
			float(Time.get_ticks_msec() - t_dec) / 1000.0, _main.countdown_left])
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_torches(true)
	_sans_hud = true
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	await _passer_sur_la_carte_des_murs_bas()
	if not _dessus:
		_iso = Presentation3D.instance()
		if _iso == null:
			printerr("✗ aucune Presentation3D : la vue iso n'est pas en place")
			_sortir(1)
			return
		if _iso.viewport_ecran(0) == null or _iso.viewport_ecran(1) == null:
			printerr("✗ les deux vues iso ne sont pas regardées (écran scindé attendu)")
			_sortir(1)
			return
		if _vue_unique_id >= 0 and not await _passer_en_vue_unique(_vue_unique_id):
			_sortir(1)
			return
		RenderingServer.frame_pre_draw.connect(_avant_le_rendu)
	elif Presentation3D.instance() != null and bool(Presentation3D.instance().get("_actif")):
		printerr("✗ --dessus : la vue iso est allumée malgré mode_iso = faux")
		_sortir(1)
		return
	_equiper(0, "pistolet")
	_equiper(1, "pistolet")
	_portee = float(_main.p1.current_weapon.portee_torche())
	if not _choisir_j1(_portee):
		_sortir(1)
		return
	print("  J1 %s, axe %s, portée %.0f px, zoom caméra %s, lacet %s %s" % [str(_j1), str(_axe), _portee,
		str(_main.cam1.zoom), str(GameSettings.lacet_duel), GameSettings.option_lacet])
	print("  ZOOM_DUEL_DEFAUT = %s, zoom appliqué = %s" % [str(GameSettings.ZOOM_DUEL_DEFAUT), str(GameSettings.zoom_duel)])

	for porteur in porteurs:
		var cible: int = 1 - porteur
		print("\n=== porteur J%d (vue de J%d), cible J%d ===" % [porteur + 1, porteur + 1, cible + 1])
		# Le porteur est TOUJOURS le Parasite : la phase d'avant a pu l'équiper d'une autre classe, comme cible.
		_equiper(porteur, "pistolet")
		for slug in classes:
			_equiper(cible, slug)
			for o in orientations:
				var images_ici: bool = (_images or _soi_images) and (slug in CLASSES_IMAGES) \
					and (o in ["profil_d", "diag_face_d", "face"])
				await _scene(porteur, slug, String(o), images_ici)
	_equiper(0, "pistolet")
	_equiper(1, "pistolet")

	var f := FileAccess.open("%s/journal.json" % _dossier, FileAccess.WRITE)
	f.store_string(JSON.stringify({"j1": [_j1.x, _j1.y], "axe": [_axe.x, _axe.y], "portee": _portee,
		"fenetre": [_taille.x, _taille.y], "commit": _commit(), "zoom": _main.cam1.zoom.x,
		"lacet": GameSettings.lacet_duel, "option_lacet": GameSettings.option_lacet,
		"rayon_lu_px": _rayon_lu(), "orientations": ORIENTATIONS, "prises": _journal}, "  "))
	f.close()
	print("\n%d prise(s) dans %s" % [_journal.size(), ProjectSettings.globalize_path(_dossier)])
	_sortir(0)


# ---------------------------------------------------------------------------
# LA MISE EN SCÈNE
# ---------------------------------------------------------------------------

func _equiper(pid: int, slug: String) -> void:
	var joueur = _main.p1 if pid == 0 else _main.p2
	var i := SLUGS.find(slug)
	for k in 10:
		var c = _main.weapon_for_index(k)
		if c is ClassData and String((c as ClassData).slug()) == slug:
			i = k
			break
	joueur.equip_weapon(_main.weapon_for_index(i))


func _rayon_lu() -> float:
	return minf(Presentation3D.RAYON_CORPS_PX + 1.0, CapteurCorps.RAYON_PX - 3.0)


## Un porteur sur la carte du duel d'où l'axe de visée traverse du sol libre, sans mur ni muret, sur toute la portée
## et au-delà (la règle de `planche_q33`).
func _choisir_j1(portee: float) -> bool:
	var t := MursBas.TUILE
	_axe = _la_visee()
	var grille := Vector2(MapCodec.get_grid_size(MapData.current_map_data)) * t
	var meilleur := Vector2.INF
	var y := 4.0 * t
	while y < grille.y - 4.0 * t:
		var x := 4.0 * t
		while x < grille.x - 4.0 * t:
			var p := Vector2(x, y)
			if _ligne_libre(p, p + _axe * (portee + 160.0)):
				var d := p.distance_to(grille * 0.5 - _axe * portee * 0.5)
				if meilleur == Vector2.INF or d < meilleur.distance_to(grille * 0.5 - _axe * portee * 0.5):
					meilleur = p
			x += t * 0.5
		y += t * 0.5
	if meilleur == Vector2.INF:
		printerr("✗ aucune ligne de sol libre de %.0f px sur la carte du duel" % (portee + 160.0))
		return false
	_j1 = meilleur
	return true


func _ligne_libre(a: Vector2, b: Vector2) -> bool:
	if not _sol_libre(a) or _mur_entre(a, b):
		return false
	var n := int(a.distance_to(b) / 8.0) + 1
	for m in _main.murs_bas as Array:
		var r := (m as Rect2).grow(24.0)
		for k in n + 1:
			if r.has_point(a.lerp(b, float(k) / float(n))):
				return false
	return true


## Pose le porteur à sa place, visée dans l'axe, et la cible à `d` px dans l'axe, tournée de θ.
func _poser(porteur: int, d: float, theta: float) -> void:
	var cible := 1 - porteur
	var p_porteur = _main.p1 if porteur == 0 else _main.p2
	var p_cible = _main.p2 if porteur == 0 else _main.p1
	var visee_cible := (-_axe).rotated(deg_to_rad(theta))
	_poses[porteur] = [_j1, _axe]
	_poses[cible] = [_j1 + _axe * d, visee_cible]
	p_porteur.global_position = _j1
	_viser(porteur, _axe)
	p_cible.global_position = _j1 + _axe * d
	_viser(cible, visee_cible)
	p_cible.global_rotation = visee_cible.angle()
	p_porteur.global_rotation = _axe.angle()
	if _pantins.size() > 1:
		_pantins[porteur].torche = true
		_pantins[cible].torche = _mutuel
	if _mutuel:
		Input.action_press("p1_torch" if cible == 0 else "p2_torch")
	else:
		Input.action_release("p1_torch" if cible == 0 else "p2_torch")
	Input.action_press("p1_torch" if porteur == 0 else "p2_torch")
	p_cible.flashlight_on = _mutuel
	_vivants()


## Le mur d'essai : perpendiculaire à l'axe, à mi-chemin, assez large pour couper le cône.
func _placer_le_mur(d: float) -> void:
	if _mur == null:
		_mur = LightOccluder2D.new()
		_mur.name = "MurDEssaiQ42"
		var forme := OccluderPolygon2D.new()
		forme.polygon = PackedVector2Array([Vector2(-6, -110), Vector2(6, -110), Vector2(6, 110), Vector2(-6, 110)])
		forme.cull_mode = OccluderPolygon2D.CULL_DISABLED
		_mur.occluder = forme
		_mur.occluder_light_mask = 1
		_main.arena.add_child(_mur)
	_mur.global_position = _j1 + _axe * d * 0.5
	_mur.global_rotation = _axe.angle()


func _tenir(porteur: int, d: float, theta: float, n: int) -> void:
	for i in n:
		if _mur_pose:
			_placer_le_mur(d)
		_poser(porteur, d, theta)
		for j in [_main.p1, _main.p2]:
			j.set("_dust_accum", -1.0e9)
			j.velocity = Vector2.ZERO
			if _lampes != "":
				j.flashlight.visible = _lampes.contains("F")
				j.ambient_light.visible = _lampes.contains("H")
				j.body_light.visible = _lampes.contains("B")
		for cam in [_main.cam1, _main.cam2]:
			if is_instance_valid(cam):
				cam.reset_smoothing()
		await get_tree().process_frame


## Le niveau que lit le corps `j` dans le capteur de la vue `v` : [moyenne de l'anneau, maximum de l'anneau].
## La luminance est celle du shader des corps (`pate_luminance`, Rec. 709).
func _niveau(v: int, j: int) -> Array:
	var c = _iso._capteurs[v][j]
	if c == null:
		return [-1.0, -1.0]
	var img: Image = (c as CapteurCorps).get_texture().get_image()
	var texels_par_px := float(CapteurCorps.TAILLE) / CapteurCorps.MONDE_PX
	var r := _rayon_lu() * texels_par_px
	var centre := Vector2(img.get_width(), img.get_height()) * 0.5
	var somme := 0.0
	var n := 0
	var haut := 0.0
	for a in 64:
		var q := centre + Vector2.from_angle(TAU * (float(a) + 0.5) / 64.0) * r
		var px := img.get_pixelv(Vector2i(q))
		var v_lum := px.r * 0.2126 + px.g * 0.7152 + px.b * 0.0722
		somme += v_lum
		haut = maxf(haut, v_lum)
		n += 1
	return [somme / float(n), haut]


## Juste avant le rendu, après le `_process` de la présentation : les corps à leur pose EXACTE.
func _avant_le_rendu() -> void:
	if _iso == null or not is_instance_valid(_iso):
		return
	for j in 2:
		var voxel := _iso._voxels[j] as VoxelCorps
		if voxel != null and _iso._corps[j].visible:
			var etat: Dictionary = _iso.etat_du_corps(j, _main.p1 if j == 0 else _main.p2)
			etat["position"] = _poses[j][0]
			etat["visee"] = _poses[j][1]
			etat["vitesse"] = Vector2.ZERO
			etat["t"] = 0.0
			voxel.poser(etat)


func _scene(porteur: int, slug: String, orientation: String, images: bool) -> void:
	var cible := 1 - porteur
	var theta := float(ORIENTATIONS[orientation])
	var d := _portee * 0.5 if _distance_px <= 0.0 else _distance_px
	# Une nouvelle classe ou un nouveau porteur demande un long repos (le corps reconstruit, les effacements qui remontent) ;
	# un simple changement d'orientation, quelques images : la rotation est posée, le capteur suit la place.
	var place := "%d/%s" % [porteur, slug]
	seed(42)
	var t0 := Time.get_ticks_msec()
	var n_images := IMAGES_POSE if place == _derniere_place else IMAGES_REPOS
	await _tenir(porteur, d, theta, n_images)
	_derniere_place = place
	print("    (%d images en %.1f s : %.2f s par image)" % [n_images, float(Time.get_ticks_msec() - t0) / 1000.0,
		float(Time.get_ticks_msec() - t0) / 1000.0 / float(n_images)])
	if _dessus:
		await _photographier_dessus(porteur, slug, orientation)
		return
	var vue := _niveau(porteur, cible)
	var soi := _niveau(cible, cible)
	var lampe = _main.p1.flashlight if porteur == 0 else _main.p2.flashlight
	var ligne := {"porteur": porteur, "cible": cible, "classe": slug, "orientation": orientation, "theta": theta, "mur": _mur_pose,
		"distance": d, "vue_mean": vue[0], "vue_max": vue[1], "soi_mean": soi[0], "soi_max": soi[1],
		"energie_torche": lampe.energy, "lampe_x": lampe.position.x, "torche_active": lampe.enabled,
		"vue_unique": _vue_unique_id, "lampes": _lampes}
	if images:
		var base := "%s_%s_J%d%s" % [slug, orientation, porteur + 1, "_mur" if _mur_pose else ""]
		if _images and _iso.viewport_ecran(porteur) != null:
			await _photographier(porteur, cible, base)
		if _soi_images and _iso.viewport_ecran(cible) != null:
			await _photographier_soi(cible, base)
	for k in 2:
		var jj = _main.p1 if k == 0 else _main.p2
		ligne["etat_J%d" % (k + 1)] = {"F": [jj.flashlight.enabled, jj.flashlight.visible, jj.flashlight.energy],
			"H": [jj.ambient_light.enabled, jj.ambient_light.visible, jj.ambient_light.energy],
			"B": [jj.body_light.enabled, jj.body_light.visible, jj.body_light.energy], "eblouissement": jj.dazzle_amount,
			"flashlight_on": jj.flashlight_on}
	_journal.append(ligne)
	print("  · J%d porte, cible %-12s %-12s vue %.4f (max %.4f)   soi %.4f (max %.4f)   torche %.3f (x %.1f)" % [
		porteur + 1, slug, orientation, vue[0], vue[1], soi[0], soi[1], lampe.energy, lampe.position.x])


## Q55 — le corps de la cible dans SA propre vue : le corps découpé, son capteur de soi, la vue entière réduite de moitié.
func _photographier_soi(cible: int, base: String) -> void:
	await RenderingServer.frame_post_draw
	var ecran_vue := _iso.viewport_ecran(cible)
	var img: Image = ecran_vue.get_texture().get_image()
	var cam := _iso._camera_de(cible)
	var logique := ecran_vue.get_visible_rect().size
	var taille := Vector2(img.get_size())
	var cible_px: Vector2 = (_poses[cible][0] as Vector2)
	var ecran: Vector2 = cam.vers_ecran(cible_px, logique, 16.0) * taille / logique
	var x0 := clampi(int(ecran.x) - DECOUPE_PX / 2, 0, maxi(0, img.get_width() - DECOUPE_PX))
	var y0 := clampi(int(ecran.y) - DECOUPE_PX / 2, 0, maxi(0, img.get_height() - DECOUPE_PX))
	img.get_region(Rect2i(x0, y0, DECOUPE_PX, DECOUPE_PX)).save_png("%s/%s_soi_vue.png" % [_dossier, base])
	var entiere := img.duplicate() as Image
	entiere.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	entiere.save_png("%s/%s_soi_cadre.png" % [_dossier, base])
	var c = _iso._capteurs[cible][cible]
	if c != null:
		(c as CapteurCorps).get_texture().get_image().save_png("%s/%s_soi_capteur.png" % [_dossier, base])


## Q55 — la vue iso d'UN seul joueur, comme en ligne ou à l'entraînement : l'autre vue est cachée, ses capteurs s'en vont,
## et le jeu se range tout seul (`_accorder_rendu_aux_vues`, puis la présentation à l'image suivante).
func _passer_en_vue_unique(n: int) -> bool:
	var autre := (_main.vp2 if n == 0 else _main.vp1).get_parent() as Control
	if autre != null:
		autre.hide()
	_ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	_ui._voile_scinde = false
	if _ui.hud_panneau_p2 != null:
		_ui.hud_panneau_p2.visible = false
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	await _attendre_images(20)
	if _iso.viewport_ecran(n) == null or _iso.viewport_ecran(1 - n) != null:
		printerr("✗ --vue-unique=%d : la vue de J%d seule n'est pas en place" % [n, n + 1])
		return false
	print("  · vue unique de J%d : %d capteur(s) vivant(s)" % [n + 1, _iso.get("_capteurs").reduce(
		func(a, ligne): return a + ligne.filter(func(c): return c != null and is_instance_valid(c)).size(), 0)])
	return true


## Le corps découpé dans la vue du porteur, le capteur brut, et — deux fois — les lightmaps entières.
func _photographier(porteur: int, cible: int, base: String) -> void:
	await RenderingServer.frame_post_draw
	var ecran_vue := _iso.viewport_ecran(porteur)
	var img: Image = ecran_vue.get_texture().get_image()
	var cam := _iso._camera_de(porteur)
	var logique := ecran_vue.get_visible_rect().size
	var taille := Vector2(img.get_size())
	var cible_px: Vector2 = (_poses[cible][0] as Vector2)
	var ecran: Vector2 = cam.vers_ecran(cible_px, logique, 16.0) * taille / logique
	var x0 := clampi(int(ecran.x) - DECOUPE_PX / 2, 0, maxi(0, img.get_width() - DECOUPE_PX))
	var y0 := clampi(int(ecran.y) - DECOUPE_PX / 2, 0, maxi(0, img.get_height() - DECOUPE_PX))
	var coupe := img.get_region(Rect2i(x0, y0, DECOUPE_PX, DECOUPE_PX))
	coupe.save_png("%s/%s_vue.png" % [_dossier, base])
	# La vue entière, réduite de moitié : le cadrage.
	var entiere := img.duplicate() as Image
	entiere.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	entiere.save_png("%s/%s_cadre.png" % [_dossier, base])
	var c = _iso._capteurs[porteur][cible]
	if c != null:
		(c as CapteurCorps).get_texture().get_image().save_png("%s/%s_capteur.png" % [_dossier, base])
	if _lightmaps_prises < 2:
		_lightmaps_prises += 1
		_main.vp1.get_texture().get_image().save_png("%s/%s_lightmap1.png" % [_dossier, base])
		_main.vp2.get_texture().get_image().save_png("%s/%s_lightmap2.png" % [_dossier, base])


## La vue de dessus : la texture de chaque vue du duel, puis — pour la première prise — celle de la racine en vue unique,
## qui adopte alors le monde du duel (`GameState._rendre_dans_la_racine`) : l'ombre au sol et sur les sprites doit y être
## la même avant et après Q42.
func _photographier_dessus(porteur: int, slug: String, orientation: String) -> void:
	await RenderingServer.frame_post_draw
	var base := "dessus_%s_%s_J%d" % [slug, orientation, porteur + 1]
	_main.vp1.get_texture().get_image().save_png("%s/%s_vp1.png" % [_dossier, base])
	_main.vp2.get_texture().get_image().save_png("%s/%s_vp2.png" % [_dossier, base])
	_journal.append({"porteur": porteur, "classe": slug, "orientation": orientation, "dessus": true})
	print("  · dessus J%d porte, cible %-12s %-12s : vp1 et vp2 écrites" % [porteur + 1, slug, orientation])
	if _lightmaps_prises == 0:
		_lightmaps_prises = 1
		# Vue unique : la racine rend le duel. On laisse le jeu se ranger tout seul (`_vue_unique` du photographe).
		_vue_unique()
		await _tenir(porteur, _portee * 0.5, float(ORIENTATIONS[orientation]), 10)
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("%s/%s_racine.png" % [_dossier, base])
		print("    · vue unique : la racine (adoptée : %s) écrite" % str(_main.get("_rendu_racine")))
		_deux_vues()
		await _tenir(porteur, _portee * 0.5, float(ORIENTATIONS[orientation]), 10)
