extends "res://tools/photo_ecart.gd"

## LE SOL MARQUÉ, SUR IMAGE — une séance du photographe, héritière de `photo_ecart.gd` (graine, repos en images de jeu,
## LED figées, congé de l'intro), pour l'essai `--sol-marque-essai` (`arena_decor.gd`, ISO14). Aucun défaut ne change.
##
## Chaque prise est TRIPLE, au même instant, jeu en pause : A (les marques), B (les marques retirées : `poser_marques(false)`
## et le décor recuit), A' (les marques remises). A − B, c'est l'essai et lui seul ; A − A', c'est le bruit du protocole.
## Il faut donc lancer AVEC le drapeau : sans lui, la table n'est pas posée et A = B.
##
## Les scènes, sur le Cloître, au cadrage du jeu (1920×1080, lacet 45° B, zoom du duel) :
##   gravats, eclats, chaine, cadre, bande, lettres — J1 à ~2,5 cases d'une marque de la famille, torche vers elle ;
##   noir     — la scène des gravats, torches éteintes (le noir absolu : 0 pixel allumé en A, B et A') ;
##   scinde   — l'écran scindé, J1 devant un tas de gravats, J2 au DEMI-TOUR de J1, devant le jumeau du tas par le
##              demi-tour (la vue de J2 est prise depuis le côté opposé, lacet B : c'est le demi-tour, pas le miroir, qui
##              lui montre ce que J1 voit) — la symétrie mesurée à l'image ;
##   contraste4, contraste7 — J2, torche éteinte, debout sur des marques à 4 puis 7 cases dans le cône de J1 : quatre prises,
##              marques × J2 (présent, puis sorti de la carte), pour mesurer le contraste du corps sur sol marqué et nu.
##
##     GODOT_ARGS= xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_sol_marque.tscn -- \
##         --no-eos --led-murs-fige --sol-marque-essai --sortie=user://sol-marque/seul [--scenes=…] [autres essais…]
##
## `docs/iso/cloud/sol-marque/lancer.sh` fait les lancements ; `mesurer.py` mesure et monte la planche.

## [J1 en cases, visée] par scène de famille (les marques visées : `ArenaDecor.SOL_MARQUE_ESSAI["map_001"]`).
const SCENES_FAMILLES := {
	"gravats": [Vector2(10, 14.6), Vector2.UP],    # le tas au pied sud du pilier nord-ouest, (10, 12)
	"eclats": [Vector2(5.5, 9.1), Vector2.UP],     # les éclats de (5,5, 6,5)
	"chaine": [Vector2(5.5, 22.4), Vector2.DOWN],  # la chaîne de (5,5, 25)
	"cadre": [Vector2(14.5, 7.6), Vector2.UP],     # le cadre du « DEATHMATCH » nord, (14,5, 5)
	"bande": [Vector2(12.3, 7.3), Vector2.RIGHT],  # la bande de l'axe, (14,5, 8)
	"lettres": [Vector2(7.2, 10), Vector2.LEFT],   # « B-07 », (4,5, 10)
}
## [J1, J2] en cases : J2 debout sur des marques, dans le cône de J1.
const SCENES_CONTRASTE := {
	"contraste4": [Vector2(5.5, 10.5), Vector2(5.5, 6.5)],  # J2 sur les éclats de (5,5, 6,5), à 4 cases
	"contraste7": [Vector2(6, 10.6), Vector2(6, 3.6)],  # J2 sur les gravats du mur nord, (6, 3), à 7 cases
}

var _torche_j2 := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche du sol marqué exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	if not ArenaDecor.sol_marque_actif():
		printerr("✗ lancer avec --sol-marque-essai : sans lui, la table n'est pas posée et A = B")
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://sol-marque")
	_scenes = _valeur(args, "--scenes",
		"gravats,eclats,chaine,cadre,bande,lettres,noir,scinde,contraste4,contraste7").split(",")
	_sans_hud = true
	_carte_duel = CARTE_ESSAIS
	_zoom = 1.0
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Le sol marqué ===")
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
	var decor := _decor()
	print("  marques posées sur la carte : %d" % (decor.get("_marques") as Array).size() if decor != null else "  ! pas de décor")

	for nom in _scenes:
		if SCENES_FAMILLES.has(nom):
			_poser(_px(SCENES_FAMILLES[nom][0]), SCENES_FAMILLES[nom][1])
			print("SCENE %s : J1 %s · sol libre %s" % [nom, str(_j1), str(_sol_libre(_j1))])
			await _trois_prises(nom, true, "vue")
		elif nom == "noir":
			_poser(_px(SCENES_FAMILLES["gravats"][0]), SCENES_FAMILLES["gravats"][1])
			print("SCENE noir : J1 %s, torches éteintes" % str(_j1))
			await _trois_prises(nom, false, "vue")
		elif nom == "scinde":
			# J2 au demi-tour de J1 sur le Cloître ((x, y) → (29 − x, 29 − y)), visée retournée.
			var j1: Vector2 = SCENES_FAMILLES["gravats"][0]
			_poser(_px(j1), Vector2.UP, _px(Vector2(29.0 - j1.x, 29.0 - j1.y)), Vector2.DOWN)
			print("SCENE scinde : J1 %s · J2 %s" % [str(_j1), str(_j2)])
			_deux_vues()
			await _trois_prises(nom, true, "ecran")
			_vue_unique()
		elif SCENES_CONTRASTE.has(nom):
			await _contraste(nom)
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


func _px(cases: Vector2) -> Vector2:
	return (cases + Vector2(0.5, 0.5)) * float(CandelaTileSet.TILE_SIZE.x)


func _decor() -> Node:
	return _main.arena.get_node_or_null("ArenaDecor") if is_instance_valid(_main.arena) else null


## Pose (ou retire) les marques et recuit le décor, jeu en pause : les copies par vue reçoivent la texture d'elles-mêmes ;
## la peinture iso la reprend dans son `_process`, arrêté par la pause — appelé ici à la main.
func _marques(avec: bool) -> void:
	var decor := _decor()
	if decor == null:
		printerr("  ✗ pas de décor : bascule impossible")
		return
	await decor.poser_marques(avec)
	for n in get_tree().root.find_children("*", "SubViewport", true, false):
		if n.get_script() == preload("res://peinture_iso.gd"):
			n._process(0.0)
	await _attendre_images(4)


## A, B, A' au même instant (voir l'en-tête).
func _trois_prises(nom: String, allumees: bool, source: String) -> void:
	_torches_allumees = allumees
	_torches(allumees)
	for i in REPOS_IMAGES:
		_tenir()
		await get_tree().process_frame
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	_ecrire_prise(await _capturer(source), nom + "_A")
	await _marques(false)
	_ecrire_prise(await _capturer(source), nom + "_B")
	await _marques(true)
	_ecrire_prise(await _capturer(source), nom + "_A2")
	get_tree().paused = false
	_torches_allumees = true
	_torches(true)


## Le contraste d'un corps adverse, torche éteinte, sur sol marqué et nu : J2 présent (marques, puis sans), puis J2 sorti de
## la carte (marques, puis sans). Le masque du corps se lit dans la différence J2 présent − J2 absent.
func _contraste(nom: String) -> void:
	var places: Array = SCENES_CONTRASTE[nom]
	_torche_j2 = false
	for present in [true, false]:
		if present:
			_poser(_px(places[0]), Vector2.UP, _px(places[1]), Vector2.UP)
		else:
			_poser(_px(places[0]), Vector2.UP)
		print("SCENE %s : J1 %s · J2 %s" % [nom, str(_j1), str(_j2) if present else "hors carte"])
		for i in REPOS_IMAGES:
			_tenir()
			await get_tree().process_frame
		_tenir()
		get_tree().paused = true
		await _attendre_images(3)
		var suffixe := "_j2" if present else "_vide"
		_ecrire_prise(await _capturer("vue"), nom + suffixe + "_A")
		await _marques(false)
		_ecrire_prise(await _capturer("vue"), nom + suffixe + "_B")
		await _marques(true)
		get_tree().paused = false
	_torche_j2 = true


## Le maintien de `photo_essais.gd`, et la torche de J2 éteinte pour les scènes de contraste (le corps au bord de la
## lumière de J1, pas dans la sienne).
func _tenir() -> void:
	super._tenir()
	if not _torche_j2 and _pantins.size() > 1:
		_pantins[1].torche = false
		Input.action_release("p2_torch")
		if is_instance_valid(_main.p2):
			_main.p2.flashlight_on = false
