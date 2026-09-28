extends "res://tools/photo_sol_marque.gd"

## LE SOL MARQUÉ DANS LE NOIR, SUR LES SIX CARTES — une séance du photographe, héritière de `photo_sol_marque.gd` (la prise
## triple A / B / A' au même instant, jeu en pause), pour le défaut de l'évaluation 11 (`docs/iso/cloud/ecart-11/RAPPORT.md`
## § 4 : torches éteintes, des points jaunes sur le liseré du sommet d'un mur haut, attribués au sol marqué). Aucun défaut ne
## change ; il faut lancer AVEC `--sol-marque-essai` (sans lui, A = B).
##
## Pour chaque carte livrée demandée (`--cartes=`, par défaut les six), la mise en scène du duel du photographe
## (`_mise_en_scene_du_duel` : J1 à 3,5 cases au sud de la face sud du plus large mur haut intérieur, torche au nord ; J2 à
## 0,6 × 2,6 cases de lui, comme l'évaluation 11), et les scènes demandées (`--scenes=`) :
##   noir          — vue unique, torches éteintes ;
##   noir_scinde   — écran scindé, J2 au DEMI-TOUR de J1 (la vue de J2 est prise depuis le côté opposé, lacet B), torches
##                   éteintes ;
##   allume        — vue unique, torches allumées ;
##   allume_scinde — écran scindé, torches allumées.
## Et, une fois par carte, la PEINTURE iso de la carte (`peinture_iso.gd`, la texture que les murs divisent) avec et sans
## les marques : `<carte>_peinture_A.png`, `<carte>_peinture_B.png` — ce que les murs lisent, au texel près.
##
## `--par=<carte>` pose d'abord une autre carte, vue iso allumée (le chemin de l'évaluation 11 : le Cloître, puis la Croisée) ;
## `--temoin` permet de lancer SANS `--sol-marque-essai` (A = B : le témoin d'un autre lancement).
##
##     GODOT_ARGS= xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_sol_marque_noir.tscn \
##         -- --no-eos --led-murs-fige --sol-marque-essai --sortie=user://sol-marque-2/seul [--cartes=…] [--scenes=…] [essais…]
##
## Il EXIGE une vraie fenêtre, comme le photographe.

const CARTES := ["arene_circulaire", "default", "map_001_le_cloitre", "map_002_l_usine", "map_003_la_croisee",
	"map_004_le_bunker"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la séance du noir exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	if not ArenaDecor.sol_marque_actif() and not args.has("--temoin"):
		printerr("✗ lancer avec --sol-marque-essai : sans lui, la table n'est pas posée et A = B")
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://sol-marque-2")
	_scenes = _valeur(args, "--scenes", "noir,noir_scinde,allume,allume_scinde").split(",")
	var cartes := _valeur(args, "--cartes", ",".join(CARTES)).split(",")
	var par := _valeur(args, "--par", "")
	_sans_hud = true
	_carte_duel = CARTE_ESSAIS
	_zoom = 1.0
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Le sol marqué dans le noir ===")
	print("  drapeaux : %s" % " ".join(args))
	_poser_la_fenetre()
	await _lire_l_horloge()
	if _pas_fixe <= 0.0:
		printerr("✗ lancer avec --fixed-fps 60 : sans horloge fixe, deux lancements ne gèlent pas au même instant")
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
	var reglages := get_node_or_null(^"/root/GameSettings")
	var lacet := float(reglages.call("lacet_de", 0)) if reglages != null else 0.0
	print("  lacet de J1 : %s°" % str(lacet))

	var t := float(CandelaTileSet.TILE_SIZE.x)
	for carte in cartes:
		# `--par=<carte>` : cette carte d'abord, vue iso allumée et tenue quelques images, PUIS la carte photographiée — le
		# chemin de `photo_ecart.gd` à l'évaluation 11 (le Cloître, puis la Croisée). Sans lui, la carte est posée directement.
		if par != "" and await _poser_la_carte("res://assets/maps/%s.json" % par):
			_poser(_scene_duel["p1"], Vector2.UP)
			for i in 30:
				_tenir()
				await get_tree().process_frame
			print("PAR %s, vue iso tenue 30 images" % par)
		if not await _poser_la_carte("res://assets/maps/%s.json" % carte, par == ""):
			continue
		var decor := _decor()
		print("CARTE %s : %d marques · %s" % [carte, (decor.get("_marques") as Array).size() if decor != null else -1,
			_scene_duel.get("mur", "?")])
		var p1: Vector2 = _scene_duel["p1"]
		var grille := Vector2(MapCodec.get_grid_size(MapData.current_map_data)) * t
		for nom in _scenes:
			var allumees := nom.begins_with("allume")
			if nom.ends_with("_scinde"):
				_poser(p1, Vector2.UP, grille - p1, Vector2.DOWN)
				_deux_vues()
				print("SCENE %s_%s : J1 %s · J2 %s" % [carte, nom, str(_j1), str(_j2)])
				await _trois_prises("%s_%s" % [carte, nom], allumees, "ecran")
				_vue_unique()
			else:
				_poser(p1, Vector2.UP, p1 + Vector2(0.6 * t, -2.6 * t), Vector2.RIGHT)
				print("SCENE %s_%s : J1 %s · J2 %s" % [carte, nom, str(_j1), str(_j2)])
				await _trois_prises("%s_%s" % [carte, nom], allumees, "vue")
		# Après les scènes : la première prise A de la carte est ainsi celle de la cuisson INITIALE du décor.
		await _vider_la_peinture(carte)
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


## Pose une carte livrée et recalcule la mise en scène du duel (le geste de `photo_ecart.gd` à l'évaluation 11).
## ⚠️ `fraiche` : la présentation iso ne refait PAS sa peinture quand la carte change vue allumée (`presentation_3d.gd`,
## `_process` : les murs seulement ; RAPPORT sol-marque-2 § 1) — les murs de la nouvelle carte diviseraient par la peinture
## de l'ancienne. Le banc la refait donc lui-même (`_poser_peinture`, le geste de `_allumer`), sauf pour montrer le défaut.
func _poser_la_carte(chemin: String, fraiche := true) -> bool:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK or not (json.data is Dictionary):
		printerr("  ! carte illisible : %s" % chemin)
		return false
	var data: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]
	MapData.current_map_data = data
	_main.rebuild_arena()
	await _attendre_images(5)
	var iso := Presentation3D.instance()
	if fraiche and iso != null and bool(iso.get("_actif")):
		iso.call("_poser_peinture")
		await _attendre_images(5)
	_scene_duel = _mise_en_scene_du_duel(data)
	return true


## La peinture iso de la carte, avec puis sans les marques, puis les marques remises : ce que les murs divisent.
func _vider_la_peinture(carte: String) -> void:
	# Relue après chaque attente : un changement de vue (scindée → unique) éteint et rallume la présentation, qui refait
	# alors sa peinture — la sous-vue d'avant l'attente peut être libérée (vu au premier lancement des six cartes).
	await _attendre_images(3)
	var peinture := _la_peinture()
	if peinture == null:
		printerr("  ! pas de peinture iso")
		return
	var img := peinture.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s_peinture_A.png" % [_dossier, carte]))
	await _marques(false)
	peinture = _la_peinture()
	if peinture == null:
		printerr("  ! pas de peinture iso")
		await _marques(true)
		return
	img = peinture.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s_peinture_B.png" % [_dossier, carte]))
	await _marques(true)
	# Ce que le matériau des murs lit VRAIMENT : le cadre de la peinture qu'il divise, face à la grille de la carte posée.
	var iso := Presentation3D.instance()
	var mat: ShaderMaterial = iso.get("_mat_mur") if iso != null else null
	var grille := Vector2(MapCodec.get_grid_size(MapData.current_map_data)) * float(CandelaTileSet.TILE_SIZE.x)
	print("PEINTURE %s %dx%d cadre %s · lue par les murs : taille %s · carte posée : %s px (+ 2 cases de bordure)" % [carte,
		img.get_width(), img.get_height(), str(peinture.cadre),
		str(mat.get_shader_parameter("peinture_taille_px")) if mat != null else "?", str(grille)])


## La peinture que la présentation iso tient en ce moment (celle que les murs lisent), ou `null`.
func _la_peinture() -> SubViewport:
	var iso := Presentation3D.instance()
	return iso.peinture() if iso != null else null
