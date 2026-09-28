extends "res://tools/photographe.gd"

## Q39 SUR IMAGE — son propre corps, aujourd'hui (la silhouette de soi) et à l'essai (`--corps-soi-sombre`), AU MÊME INSTANT.
## Une séance du photographe (dont elle reprend la fenêtre, l'horloge fixe, les marionnettes et la capture), héritière de la
## règle de `photo_essais.gd` (graine, repos en images de jeu, congé de l'intro), pour la session cloud corps-sombre.
##
## ⚠️ **L'essai bascule EN DIRECT, jeu en pause** — ni deux lancements, ni leur bruit. Pour chaque prise : le jeu gelé, on
## capture le défaut, puis on pose la variante CORPS_SOI_SOMBRE sur le matériau des deux corps (`IsoMateriaux.accorder_corps`
## sous `VoxelCatalogue.forcer_soi_sombre = 1`) et sa direction de lumière (`MannequinIso.direction_dominante`, le calcul de
## `Presentation3D._suivre` recopié), on capture l'essai, on rend le shader d'hier et on recapture le défaut (le bruit, qui
## doit être nul) ; puis chaque corps caché à son tour (la place qu'il occupe, ce qu'il y a derrière lui). Une prise =
## `<classe>_<scene>_<etat>.png`, états `defaut`, `essai`, `defaut2`, `sans1` (J1 caché), `sans2` (J2 caché).
##
## Les scènes (Cloître, la place du duel du photographe, lacet du jeu — 45° B —, zoom du duel) :
##   noir    — torches éteintes, J2 hors de la carte : on ne se voit que par son repère ;
##   torche  — sa torche vers le mur haut, à 1,5 case : la rétrodiffusion, sa pleine lumière à soi ;
##   vide    — sa torche vers le sud, dos au mur : le corps au bord de sa propre lumière ;
##   adverse — sa torche éteinte, J2 à 2,6 cases qui le braque : la torche d'en face ;
##   lisiere — la même, J2 le braque de biais : J1 au bord du cône adverse ;
##   fusee   — sa torche éteinte, une fusée lancée devant lui, prise 1,5 s après le lancer ;
##   scinde_noir — l'écran scindé, les deux torches éteintes : chacun ne doit voir que son propre repère ;
##   scinde  — l'écran scindé, J2 (vue de l'autre côté, lacet B) braque J1 de biais, les deux torches allumées : la vue de
##             l'adversaire se compare au pixel, et chaque joueur se voit dans sa couleur.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_corps_sombre.tscn -- --no-eos --led-murs-fige --sortie=user://corps_sombre
##
## Il EXIGE une vraie fenêtre, comme le photographe. `docs/iso/cloud/corps-sombre/lancer.sh` le lance ; `mesurer.py` mesure.

const CARTE := "res://assets/maps/map_001_le_cloitre.json"
const REPOS_IMAGES := 90
const AGE_FUSEE := 90
const CLASSES_DEFAUT := "pistolet,pompe,fumiste,spectre"

var _j1 := Vector2.ZERO
var _visee_j1 := Vector2.UP
var _j2 := Vector2.ZERO
var _visee_j2 := Vector2.RIGHT
var _j2_present := true
var _torche1 := true
var _torche2 := true
var _scenes := PackedStringArray()
var _shaders_hier: Array = []
## Le define posé par la bascule : `CORPS_SOI_SOMBRE`, ou `--define-temoin=NOM` (un define qu'aucun code ne lit : le témoin
## de la bascule elle-même, qui doit ne rien changer).
var _define_essai := "CORPS_SOI_SOMBRE"
## Q39 (2) — `--fondu` : après l'essai A, l'essai B (`--corps-soi-sombre=fondu`, CORPS_SOI_SOMBRE + CORPS_SOI_FONDU), pris
## au même instant (`<prise>_fondu.png`). Et, dans les deux cas, la pré-passe suit la couleur comme au jeu
## (`IsoMateriaux.accorder_passe_profondeur`, le correctif de Beauté) : c'est ce que le jeu rend sous le drapeau.
var _fondu := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche du corps sombre exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	if args.has(VoxelCatalogue.DRAPEAU_SOI_SOMBRE) or args.has(VoxelCatalogue.DRAPEAU_SOI_FONDU):
		printerr("✗ lancer SANS --corps-soi-sombre : la séance bascule l'essai elle-même, au même instant")
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://corps_sombre")
	_define_essai = _valeur(args, "--define-temoin", "CORPS_SOI_SOMBRE")
	_fondu = args.has("--fondu")
	_scenes = _valeur(args, "--scenes", "noir,torche,vide,adverse,lisiere,fusee,scinde,scinde_noir").split(",")
	var classes := _valeur(args, "--classes", CLASSES_DEFAUT).split(",")
	_sans_hud = true
	_carte_duel = CARTE
	_zoom = 1.0
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Q39 — le corps de soi, aujourd'hui et sombre ===")
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
	print("  lacet de J1 : %s° · de J2 : %s° · zoom caméra : %s" % [
		str(reglages.call("lacet_de", 0)) if reglages != null else "?",
		str(reglages.call("lacet_de", 1)) if reglages != null else "?", str(_main.cam1.zoom.x)])
	var scene: Dictionary = _scene_duel
	if not scene.has("rect"):
		printerr("✗ le Cloître n'a pas de mur haut intérieur (%s)" % scene.get("mur", "?"))
		_sortir(1)
		return
	var t := float(CandelaTileSet.TILE_SIZE.x)
	var base: Vector2 = scene["p1"]

	for slug in classes:
		var arme := _classe(String(slug))
		if arme == null:
			printerr("  ! classe inconnue : %s" % slug)
			continue
		_main.p1.equip_weapon(arme)
		print("CLASSE %s (%s)" % [slug, _nom_arme(arme)])
		var p := String(slug)
		if _scenes.has("noir"):
			_regler(base, Vector2.UP, false, Vector2.INF, Vector2.RIGHT, false)
			await _prise(p + "_noir", "vue")
		if _scenes.has("torche"):
			_regler(base, Vector2.UP, true, Vector2.INF, Vector2.RIGHT, false)
			await _prise(p + "_torche", "vue")
		if _scenes.has("vide"):
			_regler(base, Vector2.DOWN, true, Vector2.INF, Vector2.RIGHT, false)
			await _prise(p + "_vide", "vue")
		# J2 au nord-est, à 2,6 cases : il braque J1 droit, puis de biais (J1 au bord de son cône).
		var j2 := base + Vector2(0.6 * t, 2.6 * t)
		var vers_j1 := (base - j2).normalized()
		if _scenes.has("adverse"):
			_regler(base, Vector2.UP, false, j2, vers_j1, true)
			await _prise(p + "_adverse", "vue")
		if _scenes.has("lisiere"):
			_regler(base, Vector2.UP, false, j2, vers_j1.rotated(deg_to_rad(24.0)), true)
			await _prise(p + "_lisiere", "vue")
		if _scenes.has("scinde"):
			_regler(base, Vector2.UP, true, j2, vers_j1.rotated(deg_to_rad(24.0)), true)
			_deux_vues()
			await _prise(p + "_scinde", "ecran")
			_vue_unique()
		if _scenes.has("scinde_noir"):
			# Les deux torches éteintes, en écran scindé : chacun ne doit voir que SON repère.
			_regler(base, Vector2.UP, false, j2, vers_j1.rotated(deg_to_rad(24.0)), false)
			_deux_vues()
			await _prise(p + "_scinde_noir", "ecran")
			_vue_unique()
		if _scenes.has("fusee"):
			_regler(base + Vector2(0.0, 1.5 * t), Vector2.UP, false, Vector2.INF, Vector2.RIGHT, false)
			for i in REPOS_IMAGES:
				_tenir()
				await get_tree().process_frame
			_main.p1.lancer_fusee()
			for i in AGE_FUSEE:
				_tenir()
				await get_tree().process_frame
			await _geler_et_basculer(p + "_fusee", "vue")
			# La fusée brûle encore : la laisser s'éteindre avant la classe suivante.
			for i in 600:
				_tenir()
				await get_tree().process_frame

	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


func _classe(slug: String) -> WeaponData:
	for c in _main.get("_classes"):
		if (c as WeaponData).slug() == slug:
			return c
	return null


func _regler(j1: Vector2, v1: Vector2, torche1: bool, j2: Vector2, v2: Vector2, torche2: bool) -> void:
	_j1 = j1
	_visee_j1 = v1
	_torche1 = torche1
	_j2_present = j2 != Vector2.INF
	if _j2_present:
		_j2 = j2
		_visee_j2 = v2
	_torche2 = torche2 and _j2_present


## Repos, puis la prise gelée et basculée.
func _prise(nom: String, source: String) -> void:
	for i in REPOS_IMAGES:
		_tenir()
		await get_tree().process_frame
	await _geler_et_basculer(nom, source)


func _geler_et_basculer(nom: String, source: String) -> void:
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	var iso := Presentation3D.instance()
	if iso == null:
		printerr("  ✗ pas de présentation iso")
		get_tree().paused = false
		return
	_ecrire_prise(await _capturer(source), nom + "_defaut")
	_essai(iso, true)
	await _attendre_images(3)
	_ecrire_prise(await _capturer(source), nom + "_essai")
	_essai(iso, false)
	if _fondu:
		_essai(iso, true, true)
		await _attendre_images(3)
		_ecrire_prise(await _capturer(source), nom + "_fondu")
		_essai(iso, false)
	await _attendre_images(3)
	_ecrire_prise(await _capturer(source), nom + "_defaut2")
	var corps: Array = iso.get("_corps")
	for j in 2:
		if j == 1 and not _j2_present:
			continue
		var avant: bool = (corps[j] as Node3D).visible
		(corps[j] as Node3D).visible = false
		await _attendre_images(3)
		_ecrire_prise(await _capturer(source), nom + "_sans%d" % (j + 1))
		(corps[j] as Node3D).visible = avant
	await _attendre_images(2)
	get_tree().paused = false


## L'essai posé ou retiré sur les deux corps, jeu gelé : la variante du shader et la direction de la lumière, telles que
## `accorder_corps` et `Presentation3D._suivre` les poseraient sous `--corps-soi-sombre`.
func _essai(iso: Presentation3D, allume: bool, fondu := false) -> void:
	var mats: Array = iso.get("_mat_corps")
	if allume:
		_shaders_hier.clear()
		VoxelCatalogue.forcer_soi_sombre = 1
		VoxelCatalogue.forcer_soi_fondu = 1 if fondu else 0
		var lampes := MannequinIso.lampes_du_jeu(_main)
		for j in mats.size():
			var m := mats[j] as ShaderMaterial
			_shaders_hier.append(m.shader if m != null else null)
			if m == null:
				continue
			# La variante seule, pas `accorder_corps` : celui-ci repose aussi l'encre et le modelé, que le jeu règle autrement
			# après la construction — l'appeler ici changeait les arêtes des DEUX corps dans les deux vues (vu à la première
			# séance : 791 pixels du corps de J1 changés dans la vue de J2). En jeu, `accorder_corps` pose la variante à la
			# construction, avant ces réglages : la variante seule est ce que le jeu rend sous le drapeau.
			var sh := IsoMateriaux.variante_definie(m.shader, _define_essai)
			if fondu:
				sh = IsoMateriaux.variante_definie(sh, "CORPS_SOI_FONDU")
			_changer_de_shader(m, sh)
			_accorder_pre_passe(m)
			var joueur: Node2D = _main.p1 if j == 0 else _main.p2
			var dir := Presentation3D.direction_du_lisere(joueur, lampes)
			m.set_shader_parameter("soi_lumiere", dir)
			var q := PhysicsRayQueryParameters2D.create(joueur.global_position, joueur.global_position
				+ Vector2.RIGHT.rotated(joueur.rotation) * 18.0, MapGeometry.WALL_LAYER)
			var coup := joueur.get_world_2d().direct_space_state.intersect_ray(q)
			print("  essai J%d en %s : lumière dominante %s ; appel du mannequin %s ; rayon vers l'avant sans exclusion : %s" % [
				j + 1, str(joueur.global_position), str(dir), str(MannequinIso.direction_dominante(joueur.global_position, lampes,
				MannequinIso.occultation(joueur))), str(coup.get("collider")) if not coup.is_empty() else "rien"])
	else:
		VoxelCatalogue.forcer_soi_sombre = 0
		VoxelCatalogue.forcer_soi_fondu = 0
		for j in mats.size():
			var m := mats[j] as ShaderMaterial
			if m != null and j < _shaders_hier.size():
				_changer_de_shader(m, _shaders_hier[j])
				_accorder_pre_passe(m)


## Change le shader d'un matériau en reposant chacun de ses paramètres : en jeu, la variante est posée à la construction,
## AVANT que les capteurs et la lightmap ne soient réglés ; changée en direct, elle doit les retrouver tous.
func _changer_de_shader(m: ShaderMaterial, sh: Shader) -> void:
	var valeurs := {}
	for u in m.shader.get_shader_uniform_list():
		var nom := String(u["name"])
		valeurs[nom] = m.get_shader_parameter(nom)
	m.shader = sh
	for nom in valeurs:
		if valeurs[nom] != null:
			m.set_shader_parameter(nom, valeurs[nom])


## La pré-passe suit la couleur (`IsoMateriaux.accorder_passe_profondeur`), ses paramètres reposés comme ceux de la couleur :
## jeu gelé, la présentation ne les réécrit pas avant la prise.
func _accorder_pre_passe(m: ShaderMaterial) -> void:
	var mp := m.get_meta(IsoMateriaux.MATERIAU_PROFONDEUR, null) as ShaderMaterial
	if mp == null:
		return
	var valeurs := {}
	for u in mp.shader.get_shader_uniform_list():
		valeurs[String(u["name"])] = mp.get_shader_parameter(String(u["name"]))
	IsoMateriaux.accorder_passe_profondeur(m)
	for nom in valeurs:
		if valeurs[nom] != null:
			mp.set_shader_parameter(nom, valeurs[nom])


func _ecrire_prise(img: Image, cle: String) -> void:
	if img == null:
		printerr("  ✗ prise %s perdue" % cle)
		return
	img.convert(Image.FORMAT_RGB8)
	var chemin := ProjectSettings.globalize_path("%s/%s.png" % [_dossier, cle])
	img.save_png(chemin)
	print("PRISE %s %dx%d %s" % [cle, img.get_width(), img.get_height(), chemin])


func _tenir() -> void:
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2):
		return
	_main.p1.global_position = _j1
	_viser(0, _visee_j1)
	if _j2_present:
		_main.p2.global_position = _j2
		_viser(1, _visee_j2)
	else:
		_main.p2.global_position = _j1 + Vector2(0.0, 4000.0)
		_viser(1, Vector2.RIGHT)
	if _pantins.size() > 1:
		_pantins[0].torche = _torche1
		_pantins[1].torche = _torche2
	for paire in [["p1_torch", _torche1, _main.p1], ["p2_torch", _torche2, _main.p2]]:
		if paire[1]:
			Input.action_press(paire[0])
		else:
			Input.action_release(paire[0])
			paire[2].flashlight_on = false
	_vivants()
