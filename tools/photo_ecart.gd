extends "res://tools/photo_essais.gd"

## L'ÉCART DU JEU À SES ILLUSTRATIONS — une séance du photographe, héritière de `photo_essais.gd` (dont elle reprend le
## maintien des joueurs, la graine, le repos en images de jeu et le congé de l'intro), pour poser en face de chacune des
## vingt illustrations `assets/ui/ill_*.png` la scène du jeu qui lui ressemble le plus. Aucun défaut du jeu ne change :
## un lancement = un état des drapeaux (le jeu par défaut, puis tous les essais allumés), et `docs/iso/cloud/
## ecart-illustrations/lancer.sh` fait les deux (plus un témoin, pour le bruit entre deux lancements).
##
## Les scènes, sur le Cloître (seule carte qui porte à la fois pochoirs, tuyaux et enseignes), toutes au cadrage du jeu
## (1920×1080, lacet 45° B, zoom du duel), jeu en pause au moment de la prise :
##   duel     — J1 face au mur haut intérieur, J2 debout dans son cône (amical, intro_prix, créer/rejoindre local) ;
##   noir     — la même, torches éteintes (intro_extinction) ;
##   scinde   — l'écran scindé, J1 et J2 de part et d'autre du mur haut (ecran_scinde) ;
##   sol      — J1 devant le pochoir « ZONE 1 » (créer/rejoindre local) ;
##   mur      — J1 devant la face la plus meublée de tuyaux (amical_ligne, rejoindre_ligne) ;
##   arena    — J1 devant l'enseigne « ARENA » que sa caméra dessine (accueil, intro_seuil) ;
##   zone     — J1 devant la peinture « ZONE » (amical) ;
##   impacts  — trois tirs dans la face des tuyaux, étincelles en l'air (competitif, intro_allumage) ;
##   fusee1/2 — une fusée lancée vers le mur haut, prise à 1,5 s puis 4 s de jeu (creer_ligne) ;
##   entrainement — le mode solo, la cible (entrainement).
## Les scènes qui laissent des traces (impacts, fusée) viennent après les autres ; l'entraînement, qui change de carte, en
## dernier.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_ecart.tscn -- --no-eos --led-murs-fige --sortie=user://ecart/defaut [drapeaux d'essai…]
##
## Il EXIGE une vraie fenêtre, comme le photographe.

const EnseignesIsoT := preload("res://enseignes_iso.gd")
## Les âges de la fusée pris, en images de jeu après le lancer (1,5 s et 4 s à 60 Hz).
const AGES_FUSEE := [90, 240]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260927")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche de l'écart exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://ecart")
	_scenes = _valeur(args, "--scenes",
		"duel,noir,scinde,sol,mur,arena,zone,impacts,fusee,entrainement").split(",")
	_sans_hud = true
	_carte_duel = CARTE_ESSAIS
	_zoom = 1.0
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== L'écart aux illustrations ===")
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
	await _passer_sur_la_carte_des_murs_bas()
	var reglages := get_node_or_null(^"/root/GameSettings")
	var lacet := float(reglages.call("lacet_de", 0)) if reglages != null else 0.0
	print("  lacet de J1 : %s° · zoom caméra : %s" % [str(lacet), str(_main.cam1.zoom.x)])
	var t := float(CandelaTileSet.TILE_SIZE.x)

	# --- duel, noir, scinde
	var scene: Dictionary = _scene_duel
	if not scene.has("rect"):
		printerr("✗ le Cloître n'a pas de mur haut intérieur (%s)" % scene.get("mur", "?"))
		_sortir(1)
		return
	var j1_duel: Vector2 = scene["p1"]
	_poser(j1_duel, Vector2.UP, j1_duel + Vector2(0.6 * t, -2.6 * t), Vector2.RIGHT)
	print("SCENE duel : J1 %s · J2 %s" % [str(_j1), str(_j2)])
	if _scenes.has("duel"):
		await _une_prise("duel", true)
	if _scenes.has("noir"):
		await _une_prise("noir", false)
	if _scenes.has("scinde"):
		_poser(j1_duel, Vector2.UP, scene["p2"], Vector2.DOWN)
		_deux_vues()
		await _une_prise("scinde", true, "ecran")
		_vue_unique()

	# --- sol : le pochoir « ZONE 1 », la règle de `photo_essais.gd`.
	var centre := (POCHOIR_CASE + Vector2(0.5, 0.5)) * t
	var visee_sol := Vector2.UP
	var j1_sol := centre + Vector2(0.0, 2.5 * t)
	if not _sol_libre(j1_sol):
		j1_sol = centre - Vector2(0.0, 2.5 * t)
		visee_sol = Vector2.DOWN
	if _scenes.has("sol"):
		_poser(j1_sol, visee_sol)
		print("SCENE sol : J1 %s" % str(_j1))
		await _une_prise("sol", true)

	# --- mur : la face des tuyaux (règle de `photo_tuyaux.gd`), cône à 20° de biais.
	var face := _choisir_la_face(MapData.current_map_data)
	var j1_mur := Vector2.ZERO
	var visee_mur := Vector2.UP
	if not face.is_empty():
		var n: Vector2 = face["n"]
		var tg := Vector2(-n.y, n.x)
		var milieu := (float(face["s0"]) + float(face["s1"])) * 0.5
		var pied := n * float(face["d"]) + tg * milieu
		j1_mur = pied + n * (3.2 * t) + tg * 20.0
		visee_mur = (-n).rotated(deg_to_rad(20.0))
	if _scenes.has("mur"):
		if face.is_empty():
			printerr("  ! aucune face meublée : pas de scène mur")
		else:
			_poser(j1_mur, visee_mur)
			print("SCENE mur : face %s · J1 %s" % [str(face["cle"]), str(_j1)])
			await _une_prise("mur", true)

	# --- arena, zone : devant une enseigne que la caméra de J1 dessine (règle de `photo_enseignes.gd`). La géométrie
	# des enseignes se calcule sans le drapeau : le jeu par défaut est pris au MÊME endroit, mur nu.
	for sorte in ["ARENA", "ZONE"]:
		var nom := String(sorte).to_lower()
		if not _scenes.has(nom):
			continue
		var place := _devant_l_enseigne(sorte, lacet)
		if place.is_empty():
			printerr("  ! aucune enseigne « %s » dessinée au lacet %s°" % [sorte, str(lacet)])
			continue
		_poser(place["j1"], place["visee"])
		print("SCENE %s : « %s » · J1 %s" % [nom, place["sorte"], str(_j1)])
		await _une_prise(nom, true)

	# --- impacts : trois tirs dans la face des tuyaux, étincelles encore en l'air.
	if _scenes.has("impacts") and not face.is_empty():
		_poser(j1_mur, (-(face["n"] as Vector2)).rotated(deg_to_rad(8.0)))
		for i in REPOS_IMAGES:
			_tenir()
			await get_tree().process_frame
		for salve in 3:
			_tenir()
			if is_instance_valid(_main.p1):
				_main.p1.shoot()
			for i in 21:
				_tenir()
				await get_tree().process_frame
		print("SCENE impacts : J1 %s" % str(_j1))
		await _geler_et_prendre("impacts", "vue")

	# --- fusée : lancée vers le mur haut depuis la place du duel, J2 hors de la carte.
	if _scenes.has("fusee"):
		_poser(j1_duel + Vector2(0.0, 1.5 * t), Vector2.UP)
		for i in REPOS_IMAGES:
			_tenir()
			await get_tree().process_frame
		if is_instance_valid(_main.p1):
			_main.p1.lancer_fusee()
		var ecoulees := 0
		for k in AGES_FUSEE.size():
			while ecoulees < int(AGES_FUSEE[k]):
				_tenir()
				await get_tree().process_frame
				ecoulees += 1
			print("SCENE fusee%d : %d images après le lancer" % [k + 1, ecoulees])
			await _geler_et_prendre("fusee%d" % (k + 1), "vue")

	# --- entraînement : le mode solo, la cible ; il change de carte, donc en dernier.
	if _scenes.has("entrainement"):
		_torches(false)
		_main._on_training_requested()
		_prendre_les_commandes()
		_vue_unique()
		_torches(true)
		for i in REPOS_IMAGES * 2:
			_vivants()
			await get_tree().process_frame
		print("SCENE entrainement")
		get_tree().paused = true
		await _attendre_images(3)
		_ecrire_prise(await _capturer("vue"), "entrainement")
		get_tree().paused = false

	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


func _poser(j1: Vector2, visee_j1: Vector2, j2 := Vector2.INF, visee_j2 := Vector2.RIGHT) -> void:
	_j1 = j1
	_visee_j1 = visee_j1
	_j2_present = j2 != Vector2.INF
	if _j2_present:
		_j2 = j2
		_visee_j2 = visee_j2


## Une prise : torches dans l'état demandé, repos, gel, trois images, la prise.
func _une_prise(nom: String, allumees: bool, source := "vue") -> void:
	_torches_allumees = allumees
	_torches(allumees)
	for i in REPOS_IMAGES:
		_tenir()
		await get_tree().process_frame
	await _geler_et_prendre(nom, source)
	_torches_allumees = true
	_torches(true)


func _geler_et_prendre(nom: String, source: String) -> void:
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	_ecrire_prise(await _capturer(source), nom)
	get_tree().paused = false


## La place de J1 devant la première enseigne de la sorte que la caméra dessine (`photo_enseignes.gd`, biais 18°).
func _devant_l_enseigne(sorte: String, lacet: float) -> Dictionary:
	var c := EnseignesIsoT.construire(MapData.current_map_data)
	for e in c["enseignes"]:
		var f: Dictionary = c["faces"][int(e["face"])]
		if not String(e["sorte"]).begins_with(sorte) or not TuyauxIsoT.face_dessinee(f["n"], lacet):
			continue
		var n: Vector2 = f["n"]
		var tg := Vector2(-n.y, n.x)
		var pied := n * float(f["d"]) + tg * float(e["s"])
		return {"j1": pied + n * (3.2 * float(CandelaTileSet.TILE_SIZE.x)) + tg * 20.0,
			"visee": (-n).rotated(deg_to_rad(18.0)), "sorte": e["sorte"]}
	return {}
